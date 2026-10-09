import 'package:flutter/foundation.dart';

import '../domain/catalogue.dart';

/// One item in the play queue: where to play it from.
@immutable
class QueueItem {
  const QueueItem({required this.track, required this.album, required this.uri, this.artUri});

  final Track track;
  final Album album;

  /// A local file (downloaded and Premium, A-05) or the stream URL.
  final Uri uri;

  /// Album artwork for the lock screen and notification.
  final Uri? artUri;

  bool get isLocal => uri.scheme == 'file';
}

enum EngineStatus { idle, loading, buffering, ready, completed, error }

/// What the player is doing now (UNIFIED_PRODUCT_SPEC S-42, S-43).
@immutable
class PlayerSnapshot {
  const PlayerSnapshot({
    this.queue = const [],
    this.index,
    this.playing = false,
    this.status = EngineStatus.idle,
    this.position = Duration.zero,
    this.buffered = Duration.zero,
    this.duration,
    this.errorMessage,
  });

  static const empty = PlayerSnapshot();

  final List<QueueItem> queue;
  final int? index;
  final bool playing;
  final EngineStatus status;
  final Duration position;
  final Duration buffered;
  final Duration? duration;
  final String? errorMessage;

  QueueItem? get current =>
      index != null && index! >= 0 && index! < queue.length ? queue[index!] : null;

  bool get hasTrack => current != null;
  bool get isBuffering => status == EngineStatus.loading || status == EngineStatus.buffering;

  PlayerSnapshot copyWith({
    List<QueueItem>? queue,
    int? index,
    bool? playing,
    EngineStatus? status,
    Duration? position,
    Duration? buffered,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
  }) => PlayerSnapshot(
    queue: queue ?? this.queue,
    index: index ?? this.index,
    playing: playing ?? this.playing,
    status: status ?? this.status,
    position: position ?? this.position,
    buffered: buffered ?? this.buffered,
    duration: duration ?? this.duration,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// The playback engine behind the player screens (FLUTTER_ARCHITECTURE §10.1). The real one is
/// `JustAudioHandler` (just_audio + audio_service); tests use a fake.
abstract interface class AudioEngine {
  ValueListenable<PlayerSnapshot> get snapshot;

  /// Loads [queue] (an album, looping, F-064) and starts at [index] from [start].
  Future<void> playQueue(List<QueueItem> queue, int index, {Duration start = Duration.zero});

  Future<void> play();
  Future<void> pause();

  /// Stops playback and clears the queue (the mini-player's ✕).
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> seekBy(Duration delta);
  Future<void> skipToNext();

  /// From the first track, goes to the last one (fixes BUG-05).
  Future<void> skipToPrevious();
  Future<void> skipToIndex(int index);

  /// Reloads the current track after an error, from where it stopped.
  Future<void> retry();
}
