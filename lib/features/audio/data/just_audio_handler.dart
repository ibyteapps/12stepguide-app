import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/logging/log.dart';
import 'audio_engine.dart';

/// Background audio (FLUTTER_ARCHITECTURE §10.1): just_audio plays, audio_service runs the
/// Android media service and the iOS Now Playing / remote commands (fixes BUG-07), and
/// audio_session handles calls, Siri and unplugged headphones.
class JustAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements AudioEngine {
  JustAudioHandler() {
    _player.playbackEventStream.listen(_onEvent, onError: _onError);
    _player.currentIndexStream.listen(_onIndex);
    _player.durationStream.listen((d) => _update(duration: d));
    _player.positionStream.listen((p) => _update(position: p));
    _player.bufferedPositionStream.listen((b) => _update(buffered: b));
  }

  static const _skipInterval = Duration(seconds: 10);

  final _player = AudioPlayer();
  final _snapshot = ValueNotifier<PlayerSnapshot>(PlayerSnapshot.empty);
  List<QueueItem> _items = const [];

  /// Starts the media service. Called once from bootstrap.
  static Future<JustAudioHandler> start() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    return AudioService.init(
      builder: JustAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'playback',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationChannelDescription: 'Controls for the recording that is playing',
        androidNotificationIcon: 'drawable/ic_notification',
        androidStopForegroundOnPause: true,
        fastForwardInterval: _skipInterval,
        rewindInterval: _skipInterval,
      ),
    );
  }

  @override
  ValueListenable<PlayerSnapshot> get snapshot => _snapshot;

  void _update({Duration? position, Duration? buffered, Duration? duration}) {
    _snapshot.value = _snapshot.value.copyWith(
      position: position,
      buffered: buffered,
      duration: duration,
    );
  }

  void _onIndex(int? index) {
    if (index == null || index >= _items.length) return;
    mediaItem.add(_mediaItem(_items[index]));
    _snapshot.value = _snapshot.value.copyWith(index: index, position: Duration.zero);
  }

  void _onEvent(PlaybackEvent event) {
    final playing = _player.playing;
    final status = switch (_player.processingState) {
      ProcessingState.idle => EngineStatus.idle,
      ProcessingState.loading => EngineStatus.loading,
      ProcessingState.buffering => EngineStatus.buffering,
      ProcessingState.ready => EngineStatus.ready,
      ProcessingState.completed => EngineStatus.completed,
    };
    _snapshot.value = _snapshot.value.copyWith(
      playing: playing,
      status: status,
      clearError: status != EngineStatus.idle,
    );
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.fastForward,
        ],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [1, 2, 3],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  void _onError(Object error, StackTrace stack) {
    // Server unreachable or a missing file (UNIFIED_PRODUCT_SPEC §8). The album and track ids
    // are logged, never anything about the user.
    final item = _snapshot.value.current;
    Log.e(
      'Playback failed for album ${item?.album.id} track ${item?.track.id}',
      error is PlayerException ? 'PlayerException ${error.code}' : error.runtimeType,
      stack,
    );
    _snapshot.value = _snapshot.value.copyWith(
      playing: false,
      status: EngineStatus.error,
      errorMessage: item?.isLocal ?? false
          ? "This download couldn't be played. Try again."
          : "Couldn't reach the audio server. Try again.",
    );
  }

  MediaItem _mediaItem(QueueItem item) => MediaItem(
    id: '${item.track.id}',
    album: item.album.title,
    title: '${item.track.number}. ${item.track.title}',
    artist: item.album.shortName,
    duration: item.track.duration,
    artUri: item.artUri,
    extras: {'trackId': item.track.id, 'albumId': item.album.id},
  );

  @override
  Future<void> playQueue(List<QueueItem> items, int index, {Duration start = Duration.zero}) async {
    _items = List.unmodifiable(items);
    final media = [for (final i in items) _mediaItem(i)];
    queue.add(media);
    mediaItem.add(media[index]);
    _snapshot.value = PlayerSnapshot(
      queue: _items,
      index: index,
      status: EngineStatus.loading,
      position: start,
    );
    try {
      await _player.setAudioSources(
        [for (var i = 0; i < items.length; i++) AudioSource.uri(items[i].uri, tag: media[i])],
        initialIndex: index,
        initialPosition: start,
      );
      // End of the album loops back to the first track, as today (F-064).
      await _player.setLoopMode(LoopMode.all);
      unawaited(_player.play());
    } on Object catch (error, stack) {
      _onError(error, stack);
    }
  }

  @override
  Future<void> retry() async {
    final s = _snapshot.value;
    if (s.index == null || _items.isEmpty) return;
    await playQueue(_items, s.index!, start: s.position);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    _items = const [];
    queue.add(const []);
    mediaItem.add(null);
    _snapshot.value = PlayerSnapshot.empty;
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> seekBy(Duration delta) async {
    final duration = _player.duration ?? Duration.zero;
    var target = _player.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    await _player.seek(target);
  }

  @override
  Future<void> fastForward() => seekBy(_skipInterval);

  @override
  Future<void> rewind() => seekBy(-_skipInterval);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    final index = _player.currentIndex ?? 0;
    // From the first track, "previous" is the last track (BUG-05 jumped to count - 2).
    final target = index == 0 ? _items.length - 1 : index - 1;
    await _player.seek(Duration.zero, index: target);
  }

  @override
  Future<void> skipToIndex(int index) => _player.seek(Duration.zero, index: index);

  @override
  Future<void> skipToQueueItem(int index) => skipToIndex(index);

  @override
  Future<void> onTaskRemoved() => stop();
}
