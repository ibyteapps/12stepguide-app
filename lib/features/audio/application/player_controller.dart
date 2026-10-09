import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/platform/connectivity.dart';
import '../../ads/ad_coordinator.dart';
import '../../premium/entitlement_controller.dart';
import '../data/audio_engine.dart';
import '../domain/catalogue.dart';
import 'artwork.dart';
import 'downloads_controller.dart';
import 'track_positions.dart';

final audioEngineProvider = Provider<AudioEngine>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

enum PlayOutcome {
  started,

  /// Offline and the track is not on the device (S-41: "Connect to the internet to play this
  /// track").
  offline,
}

/// What the player screens show, and the actions behind their buttons
/// (FLUTTER_ARCHITECTURE §11, "Play a track").
class PlayerController extends Notifier<PlayerSnapshot> {
  late AudioEngine _engine;
  int? _savedTrackId;
  Duration _savedAt = Duration.zero;

  /// While playing, the position is saved this often (and on pause), so a resume is never far off
  /// even if the app is closed from the app switcher.
  static const saveEvery = Duration(seconds: 5);

  @override
  PlayerSnapshot build() {
    _engine = ref.watch(audioEngineProvider);
    final listenable = _engine.snapshot;
    void listener() => _onSnapshot(listenable.value);
    listenable.addListener(listener);
    ref.onDispose(() => listenable.removeListener(listener));
    return listenable.value;
  }

  TrackPositions get _positions => ref.read(trackPositionsProvider);

  void _onSnapshot(PlayerSnapshot next) {
    final previous = state;
    final item = next.current;
    if (item != null) {
      final id = item.track.id;
      if (id != _savedTrackId) {
        // A new track: nothing to save yet. (Its position can briefly read 0 or the old track's
        // value while the player switches, so the periodic save below is the record.)
        _savedTrackId = id;
        _savedAt = next.position;
      } else if ((previous.playing && !next.playing) ||
          (next.playing && (next.position - _savedAt).abs() >= saveEvery)) {
        _savedAt = next.position;
        unawaited(_positions.save(item.track, next.position));
      }
    } else {
      _savedTrackId = null;
    }
    state = next;
  }

  /// A track's source: the downloaded file when it is on the device and the user has Premium
  /// (A-05), otherwise the stream.
  bool isLocal(Track track) {
    if (!ref.read(isPremiumProvider)) return false;
    if (ref.read(downloadsProvider)[track.id]?.status != DownloadStatus.done) return false;
    return ref.read(audioFilesProvider).hasFile(track);
  }

  /// Plays [album] from track [index] and loops the album (F-062, F-064). Returns [PlayOutcome]
  /// so the caller can explain why nothing started.
  Future<PlayOutcome> playAlbum(Album album, int index) async {
    final track = album.tracks[index];
    final current = state.current;
    if (current != null && current.track.id == track.id && state.status != EngineStatus.error) {
      if (!state.playing) await _engine.play();
      return PlayOutcome.started;
    }
    final offline = ref.read(isOfflineProvider);
    if (offline && !isLocal(track)) return PlayOutcome.offline;

    // The interstitial rule applies to starting a recording, never to one already playing
    // (F-068): next, previous and the lock-screen controls never show an ad.
    if (!state.playing) await ref.read(adCoordinatorProvider).beforeContentOpen();

    final art = await ref.read(artworkProvider).uriFor(album);
    final catalogue = ref.read(catalogueProvider);
    final files = ref.read(audioFilesProvider);
    // Offline, the queue holds only what can play: the album's downloaded tracks.
    final playable = [
      for (final t in album.tracks)
        if (!offline || isLocal(t)) t,
    ];
    final items = [
      for (final t in playable)
        QueueItem(
          track: t,
          album: album,
          uri: isLocal(t) ? files.fileFor(t).uri : catalogue.streamUrl(t),
          artUri: art,
        ),
    ];
    final start = _positions.resumeFor(track) ?? Duration.zero;
    _savedTrackId = track.id;
    _savedAt = start;
    await _engine.playQueue(items, playable.indexOf(track), start: start);
    return PlayOutcome.started;
  }

  Future<void> toggle() async {
    if (state.playing) {
      await _engine.pause();
    } else if (state.status == EngineStatus.error) {
      await retry();
    } else {
      await _engine.play();
    }
  }

  Future<PlayOutcome> retry() async {
    final item = state.current;
    if (item == null) return PlayOutcome.started;
    if (ref.read(isOfflineProvider) && !item.isLocal) return PlayOutcome.offline;
    await _engine.retry();
    return PlayOutcome.started;
  }

  Future<void> seek(Duration position) => _engine.seek(position);
  Future<void> back10() => _engine.seekBy(const Duration(seconds: -10));
  Future<void> forward10() => _engine.seekBy(const Duration(seconds: 10));
  Future<void> next() => _engine.skipToNext();
  Future<void> previous() => _engine.skipToPrevious();

  /// The mini-player's ✕: remembers where the track was, then stops and clears the queue.
  Future<void> stop() async {
    final item = state.current;
    if (item != null) await _positions.save(item.track, state.position);
    _savedTrackId = null;
    await _engine.stop();
  }
}

final playerProvider = NotifierProvider<PlayerController, PlayerSnapshot>(PlayerController.new);
