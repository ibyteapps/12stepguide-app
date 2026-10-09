// P3 journeys: browse the library, play a track (UJ-7), the mini-player, offline, downloads
// (UJ-8) and the Downloads page (S-54).
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/features/audio/application/downloads_controller.dart';
import 'package:twelve_step_guide/features/audio/application/player_controller.dart';
import 'package:twelve_step_guide/features/audio/data/audio_engine.dart';
import 'package:twelve_step_guide/features/audio/data/download_gateway.dart';
import 'package:twelve_step_guide/features/audio/presentation/mini_player.dart';

import '../helpers/test_app.dart';

const premium = {PrefKeys.legacyLifetime: true, PrefKeys.legacySource: 'ios-donation'};

Future<void> waitForTranscript(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Audio tab lists the 11 albums with their lengths', (tester) async {
    await pumpApp(tester, location: '/audio');
    expect(find.text('Audio'), findsWidgets);
    expect(find.text('Joe & Charlie - Big Book Study'), findsOneWidget);
    expect(find.textContaining('34 tracks'), findsOneWidget);
    expect(find.textContaining('11 ALBUMS'), findsOneWidget);
  });

  testWidgets('play a track: the player opens with the transcript, then the mini-player', (
    tester,
  ) async {
    final app = await pumpApp(tester, location: '/audio/album/1');
    expect(find.text('Play all'), findsOneWidget);
    await tester.tap(find.text('AA History - Part 2'));
    await tester.pumpAndSettle();
    await waitForTranscript(tester);

    expect(app.audio.calls.single, startsWith('playQueue'));
    expect(find.byTooltip('Close player'), findsWidgets);
    expect(find.textContaining('NOW PLAYING'), findsOneWidget);
    expect(find.bySemanticsLabel('Transcript'), findsOneWidget);
    expect(find.byTooltip('Text size and theme'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pumpAndSettle();
    expect(app.audio.calls.last, 'pause');
    await tester.tap(find.byTooltip('Back 10 seconds'));
    await tester.tap(find.byTooltip('Next track'));
    await tester.pumpAndSettle();
    expect(app.audio.calls.sublist(app.audio.calls.length - 2), ['seekBy -10', 'next']);

    await tester.tap(find.byTooltip('Close player').first);
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.byTooltip('Stop and close player'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop and close player'));
    await tester.pumpAndSettle();
    expect(app.audio.calls.last, 'stop');
    expect(find.byTooltip('Stop and close player'), findsNothing);
  });

  testWidgets('albums without transcripts show the artwork', (tester) async {
    final app = await pumpApp(tester, location: '/audio/album/3');
    await tester.tap(find.text('Play all'));
    await tester.pumpAndSettle();
    expect(app.container.read(playerProvider).current!.album.id, 3);
    expect(find.bySemanticsLabel('Transcript'), findsNothing);
    expect(find.byTooltip('Text size and theme'), findsNothing);
  });

  testWidgets('a playback error offers Retry', (tester) async {
    final app = await pumpApp(tester, location: '/audio/album/3');
    await tester.tap(find.text('Play all'));
    await tester.pumpAndSettle();
    app.audio.emit(
      app.audio.value.copyWith(
        status: EngineStatus.error,
        playing: false,
        errorMessage: "Couldn't reach the audio server. Try again.",
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't reach the audio server. Try again."), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(app.audio.calls.last, 'retry');
  });

  testWidgets('offline: banner, and a track that is not downloaded explains itself', (
    tester,
  ) async {
    final app = await pumpApp(tester, location: '/audio', online: false);
    expect(find.textContaining("You're offline"), findsOneWidget);
    await tester.tap(find.text('Speaker Tapes - Bill W'));
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsOneWidget);
    await tester.tap(find.text('The History of the Big Book'));
    await tester.pumpAndSettle();
    expect(find.text('Connect to the internet to play this track.'), findsOneWidget);
    expect(app.audio.calls, isEmpty);
  });

  testWidgets('free users meet the paywall when they download', (tester) async {
    final app = await pumpApp(tester, location: '/audio/album/3');
    await tester.tap(find.text('Download all'));
    await tester.pumpAndSettle();
    expect(find.text('Go Premium'), findsOneWidget);
    expect(find.text('Give £1.99'), findsOneWidget);
    expect(app.downloads.enqueued, isEmpty);
  });

  testWidgets('Premium: Download all queues the album, progress shows, Remove clears it', (
    tester,
  ) async {
    final app = await pumpApp(tester, location: '/audio/album/11', prefs: premium);
    await tester.tap(find.text('Download all'));
    await tester.pumpAndSettle();
    expect(app.downloads.enqueued, hasLength(5));
    expect(find.text('Downloading…'), findsOneWidget);
    expect(find.byTooltip(RegExp('^Waiting to download')), findsNWidgets(5));

    final album = testCatalogue.album(11)!;
    for (final t in album.tracks) {
      writeTrackFile(app.audioDir, t);
      app.downloads.emit(DownloadEvent(t.id, DownloadEventKind.complete, progress: 1));
    }
    await tester.pumpAndSettle();
    expect(find.byTooltip(RegExp('is downloaded')), findsNWidgets(5));
    expect(find.text('Download all'), findsNothing);

    await tester.tap(find.text('Remove downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(app.container.read(downloadsProvider), isEmpty);
  });

  testWidgets('Downloads page: storage, per album, Wi-Fi only, remove all', (tester) async {
    final dir = tempAudioDir();
    final album = testCatalogue.album(3)!;
    for (final t in album.tracks.take(2)) {
      writeTrackFile(dir, t, bytes: 2000000);
    }
    final app = await pumpApp(
      tester,
      location: '/downloads',
      audioDir: dir,
      prefs: {
        ...premium,
        PrefKeys.downloadedTracks: [for (final t in album.tracks.take(2)) '${t.id}'],
      },
    );
    expect(find.text('4.0 MB used'), findsOneWidget);
    expect(find.text('2 recordings on this device'), findsOneWidget);
    expect(find.text(album.title), findsOneWidget);

    await tester.tap(find.text('Download over Wi-Fi only'));
    await tester.pumpAndSettle();
    expect(app.store.getBool(PrefKeys.wifiOnly), isFalse);

    await tester.tap(find.text('Remove all downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove all'));
    await tester.pumpAndSettle();
    expect(find.text('No storage used'), findsOneWidget);
  });

  testWidgets('lapsed Premium: files stay and the page explains why they stream (A-05)', (
    tester,
  ) async {
    final dir = tempAudioDir();
    final track = testCatalogue.album(3)!.tracks.first;
    writeTrackFile(dir, track);
    await pumpApp(
      tester,
      location: '/downloads',
      audioDir: dir,
      prefs: {
        PrefKeys.downloadedTracks: ['${track.id}'],
      },
    );
    expect(find.textContaining('Without Premium, these recordings stream'), findsOneWidget);
  });
}
