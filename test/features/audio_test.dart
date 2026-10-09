// P3 audio: source choice (A-05), offline rule (F-112), resume positions (A-20), downloads
// (F-065) and the iOS download migration (m008).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/app/providers.dart';
import 'package:twelve_step_guide/core/platform/connectivity.dart';
import 'package:twelve_step_guide/core/platform/legacy_bridge.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/features/audio/application/downloads_controller.dart';
import 'package:twelve_step_guide/features/audio/application/player_controller.dart';
import 'package:twelve_step_guide/features/audio/application/track_positions.dart';
import 'package:twelve_step_guide/features/audio/data/audio_engine.dart';
import 'package:twelve_step_guide/features/audio/data/download_gateway.dart';
import 'package:twelve_step_guide/features/audio/presentation/audio_widgets.dart';
import 'package:twelve_step_guide/features/migration/migration.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

final joeAndCharlie = testCatalogue.album(1)!;
final billW = testCatalogue.album(3)!;

class _Harness {
  _Harness({Map<String, Object>? prefs, this.online = true})
    : store = MemoryStore({...?prefs}),
      dir = tempAudioDir() {
    container = ProviderContainer(
      overrides: [
        kvStoreProvider.overrideWithValue(store),
        catalogueProvider.overrideWithValue(testCatalogue),
        clockProvider.overrideWithValue(() => testNow),
        onlineProvider.overrideWith((ref) => Stream.value(online)),
        audioEngineProvider.overrideWithValue(engine),
        downloadGatewayProvider.overrideWithValue(gateway),
        audioFilesProvider.overrideWithValue(AudioFiles(dir)),
      ],
    );
    addTearDown(container.dispose);
  }

  final MemoryStore store;
  final bool online;
  final String dir;
  final engine = FakeAudioEngine();
  final gateway = FakeDownloadGateway();
  late final ProviderContainer container;

  PlayerController get player => container.read(playerProvider.notifier);
  DownloadsController get downloads => container.read(downloadsProvider.notifier);

  /// Listens as the screens do (Riverpod pauses providers nobody listens to), and lets the
  /// connectivity stream deliver its value.
  Future<void> ready() async {
    container
      ..listen(onlineProvider, (_, _) {})
      ..listen(playerProvider, (_, _) {})
      ..listen(downloadsProvider, (_, _) {});
    await container.read(onlineProvider.future);
  }

  void download(int trackId) {
    writeTrackFile(dir, testCatalogue.track(trackId)!);
    container.read(downloadsProvider.notifier).adopt([trackId]);
  }
}

const premium = {PrefKeys.legacyLifetime: true, PrefKeys.legacySource: 'ios-donation'};

void main() {
  group('formatting', () {
    test('clock, length and bytes', () {
      expect(formatClock(const Duration(seconds: 245)), '4:05');
      expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 9)), '1:02:09');
      expect(formatLength(const Duration(minutes: 47)), '47 min');
      expect(formatLength(const Duration(hours: 11, minutes: 7)), '11 h 7 min');
      expect(formatBytes(245300000), '245.3 MB');
      expect(formatBytes(1240000000), '1.24 GB');
      expect(AlbumArt.monogram('Joe & Charlie'), 'JC');
      expect(AlbumArt.monogram('The Big Book'), 'BB');
      expect(AlbumArt.monogram('Bill W.'), 'BW');
      expect(AlbumArt.monogram('Bells'), 'B');
    });
  });

  group('track positions (A-20)', () {
    final track = joeAndCharlie.tracks.first; // 1177 s

    test('resume from where it was left', () async {
      final p = TrackPositions(MemoryStore());
      await p.save(track, const Duration(seconds: 300));
      expect(p.resumeFor(track), const Duration(seconds: 300));
    });

    test('the first seconds and the last 30 s are not worth resuming', () async {
      final p = TrackPositions(MemoryStore());
      await p.save(track, const Duration(seconds: 300));
      await p.save(track, const Duration(seconds: 3));
      expect(p.resumeFor(track), isNull);
      await p.save(track, const Duration(seconds: 300));
      await p.save(track, track.duration - const Duration(seconds: 10));
      expect(p.resumeFor(track), isNull);
    });

    test('a damaged value is ignored', () {
      final p = TrackPositions(MemoryStore({PrefKeys.trackPositions: '{oops'}));
      expect(p.resumeFor(track), isNull);
    });
  });

  group('playing (F-062, A-05, F-112)', () {
    test('streams from the fixed server URL', () async {
      final h = _Harness();
      await h.ready();
      expect(await h.player.playAlbum(joeAndCharlie, 0), PlayOutcome.started);
      final item = h.engine.value.current!;
      expect(
        item.uri.toString(),
        'https://scripts.12stepapp.com/tracks/joeandcharlie/joeandcharlie01.mp3',
      );
      expect(h.engine.value.queue, hasLength(joeAndCharlie.tracks.length));
    });

    test('a downloaded track plays from the device only with Premium', () async {
      final free = _Harness();
      await free.ready();
      free.download(joeAndCharlie.tracks[1].id);
      await free.player.playAlbum(joeAndCharlie, 1);
      expect(free.engine.value.current!.isLocal, isFalse, reason: 'lapsed Premium streams');

      final paid = _Harness(prefs: premium);
      await paid.ready();
      paid.download(joeAndCharlie.tracks[1].id);
      await paid.player.playAlbum(joeAndCharlie, 1);
      expect(paid.engine.value.current!.isLocal, isTrue);
      expect(paid.engine.value.current!.uri.path, endsWith('joeandcharlie02.mp3'));
    });

    test('offline: a track that is not on the device does not start', () async {
      final h = _Harness(online: false);
      await h.ready();
      expect(await h.player.playAlbum(joeAndCharlie, 0), PlayOutcome.offline);
      expect(h.engine.calls, isEmpty);
    });

    test('offline: the queue holds only the downloaded tracks', () async {
      final h = _Harness(online: false, prefs: premium);
      await h.ready();
      h
        ..download(joeAndCharlie.tracks[2].id)
        ..download(joeAndCharlie.tracks[5].id);
      expect(await h.player.playAlbum(joeAndCharlie, 5), PlayOutcome.started);
      final s = h.engine.value;
      expect(s.queue.map((q) => q.track.number), [3, 6]);
      expect(s.current!.track.number, 6);
    });

    test('resumes a track where it was left, and remembers the new position', () async {
      final track = joeAndCharlie.tracks.first;
      final h = _Harness();
      await TrackPositions(h.store).save(track, const Duration(seconds: 120));
      await h.ready();
      await h.player.playAlbum(joeAndCharlie, 0);
      expect(h.engine.calls.single, 'playQueue ${track.id} at 120s of 34');

      // Saved every 5 s while playing, and on pause.
      h.engine.emit(h.engine.value.copyWith(position: const Duration(seconds: 123)));
      expect(TrackPositions(h.store).resumeFor(track), const Duration(seconds: 120));
      h.engine.emit(h.engine.value.copyWith(position: const Duration(seconds: 126)));
      expect(TrackPositions(h.store).resumeFor(track), const Duration(seconds: 126));
      h.engine.emit(h.engine.value.copyWith(position: const Duration(seconds: 128)));
      await h.player.toggle();
      expect(TrackPositions(h.store).resumeFor(track), const Duration(seconds: 128));
    });

    test('tapping the playing track does not restart it', () async {
      final h = _Harness();
      await h.ready();
      await h.player.playAlbum(billW, 2);
      await h.player.toggle(); // pause
      await h.player.playAlbum(billW, 2);
      expect(h.engine.calls, ['playQueue ${billW.tracks[2].id} at 0s of 12', 'pause', 'play']);
    });

    test('stop remembers the position and clears the player', () async {
      final h = _Harness();
      await h.ready();
      await h.player.playAlbum(billW, 0);
      await h.engine.seek(const Duration(seconds: 600));
      await h.player.stop();
      expect(h.container.read(playerProvider).hasTrack, isFalse);
      expect(TrackPositions(h.store).resumeFor(billW.tracks.first), const Duration(seconds: 600));
    });

    test('retry offline on a streamed track explains instead of failing again', () async {
      final h = _Harness();
      await h.ready();
      await h.player.playAlbum(billW, 0);
      h.engine.emit(h.engine.value.copyWith(status: EngineStatus.error, playing: false));
      expect(await h.player.retry(), PlayOutcome.started);
      expect(h.engine.calls.last, 'retry');
    });
  });

  group('downloads (F-065)', () {
    test('queues with the Wi-Fi-only setting (A-20, on by default)', () async {
      final h = _Harness(prefs: premium);
      await h.ready();
      await h.downloads.download(billW.tracks.first);
      expect(h.gateway.enqueued, [billW.tracks.first.id]);
      expect(h.gateway.wifiOnly, [true]);
      expect(h.gateway.urls.single.toString(), endsWith('/tracks/aasbillw/aasbillw01.mp3'));
      expect(
        h.container.read(downloadsProvider)[billW.tracks.first.id]!.status,
        DownloadStatus.queued,
      );

      await h.container.read(wifiOnlyProvider.notifier).set(false);
      await h.downloads.download(billW.tracks[1]);
      expect(h.gateway.wifiOnly, [true, false]);
    });

    test('marked downloaded only when the file is really there', () async {
      final h = _Harness(prefs: premium);
      await h.ready();
      final a = billW.tracks[0], b = billW.tracks[1];
      await h.downloads.download(a);
      await h.downloads.download(b);
      writeTrackFile(h.dir, a);
      h.gateway
        ..emit(DownloadEvent(a.id, DownloadEventKind.progress, progress: 0.5))
        ..emit(DownloadEvent(a.id, DownloadEventKind.complete, progress: 1))
        ..emit(DownloadEvent(b.id, DownloadEventKind.complete, progress: 1));
      final s = h.container.read(downloadsProvider);
      expect(s[a.id]!.status, DownloadStatus.done);
      expect(s[b.id]!.status, DownloadStatus.failed, reason: 'no file, no ✓');
      expect(h.store.getStringList(PrefKeys.downloadedTracks), ['${a.id}']);
    });

    test('a failure keeps its reason; cancelling forgets the track', () async {
      final h = _Harness(prefs: premium);
      await h.ready();
      final t = billW.tracks[3];
      await h.downloads.download(t);
      h.gateway.emit(
        DownloadEvent(t.id, DownloadEventKind.failed, failure: DownloadFailure.storageFull),
      );
      expect(h.container.read(downloadsProvider)[t.id]!.failure, DownloadFailure.storageFull);
      h.gateway.emit(DownloadEvent(t.id, DownloadEventKind.canceled));
      expect(h.container.read(downloadsProvider).containsKey(t.id), isFalse);
    });

    test('remove deletes the file; the saved list never outlives the files', () async {
      final h = _Harness(prefs: premium);
      await h.ready();
      final a = billW.tracks[0], b = billW.tracks[1];
      h
        ..download(a.id)
        ..download(b.id);
      expect(h.downloads.downloadedCount(billW), 2);
      expect(h.downloads.bytesUsed(), 2048);
      await h.downloads.remove(a);
      expect(File('${h.dir}/${a.file}').existsSync(), isFalse);
      expect(h.store.getStringList(PrefKeys.downloadedTracks), ['${b.id}']);

      // Deleted behind the app's back: not shown as downloaded on the next start.
      File('${h.dir}/${b.file}').deleteSync();
      final again = _Harness(
        prefs: {
          ...premium,
          PrefKeys.downloadedTracks: ['${b.id}'],
        },
      );
      await again.ready();
      expect(again.container.read(downloadsProvider), isEmpty);
    });

    test('remove all', () async {
      final h = _Harness(prefs: premium);
      await h.ready();
      for (final t in billW.tracks.take(3)) {
        h.download(t.id);
      }
      await h.downloads.removeAll();
      expect(h.container.read(downloadsProvider), isEmpty);
      expect(Directory(h.dir).listSync(), isEmpty);
    });
  });

  group('m008: the native iOS app downloads', () {
    final first = joeAndCharlie.tracks.first; // 4.5 MB
    final second = joeAndCharlie.tracks[1];

    LegacyFile file(String name, int bytes) =>
        LegacyFile(name: name, bytes: bytes, path: '/Documents/$name');

    test('size check allows for the rounded labels and refuses truncated files', () {
      expect(DownloadsStep.sizeMatches(first, 4500000), isTrue);
      expect(DownloadsStep.sizeMatches(first, (4.5 * 1048576).round()), isTrue, reason: 'MiB');
      expect(DownloadsStep.sizeMatches(first, 4100000), isTrue);
      expect(DownloadsStep.sizeMatches(first, 2000000), isFalse);
      expect(DownloadsStep.sizeMatches(first, 0), isFalse);
    });

    test('adopts complete catalogue files, leaves everything else alone', () async {
      final store = MemoryStore();
      final bridge = _FilesBridge([
        file(first.file, 4510000),
        file(second.file, 1000), // partial
        file('main.db', 90000),
        file('notes.txt', 12),
      ]);
      await MigrationRunner(
        store: store,
        bridge: bridge,
        platform: LegacyPlatform.ios,
        steps: [DownloadsStep(testCatalogue)],
        now: testNow,
      ).run();
      expect(store.getStringList(PrefKeys.downloadedTracks), ['${first.id}']);
      expect(bridge.excluded, ['/Documents/${first.file}']);
      final summary = jsonDecode(store.getString(PrefKeys.migrationSummary)!) as Map;
      expect(summary['downloads'], 1);
      expect(store.getString(PrefKeys.migrationStep('m008')), 'done');
    });

    test('Android has no such step', () {
      expect(DownloadsStep(testCatalogue).platforms, {LegacyPlatform.ios});
    });
  });
}

class _FilesBridge extends EmptyLegacyBridge {
  _FilesBridge(this.files);

  final List<LegacyFile> files;
  final excluded = <String>[];

  @override
  Future<Map<String, Object?>> readPrefs() async => {'launchcount': 9};

  @override
  Future<List<LegacyFile>> listDocuments() async => files;

  @override
  Future<void> excludeFromBackup(String path) async => excluded.add(path);
}
