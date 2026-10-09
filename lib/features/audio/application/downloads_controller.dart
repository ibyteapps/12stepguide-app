import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/prefs/key_value_store.dart';
import '../data/download_gateway.dart';
import '../domain/catalogue.dart';

enum DownloadStatus { none, queued, downloading, done, failed }

@immutable
class DownloadState {
  const DownloadState(this.status, {this.progress = 0, this.failure});

  static const none = DownloadState(DownloadStatus.none);
  static const done = DownloadState(DownloadStatus.done, progress: 1);

  final DownloadStatus status;
  final double progress;
  final DownloadFailure? failure;

  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.downloading;
}

final audioFilesProvider = Provider<AudioFiles>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

final downloadGatewayProvider = Provider<DownloadGateway>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

/// Download state for every track (F-065), kept in step with the files on disk.
class DownloadsController extends Notifier<Map<int, DownloadState>> {
  StreamSubscription<DownloadEvent>? _sub;

  Catalogue get _catalogue => ref.read(catalogueProvider);
  AudioFiles get _files => ref.read(audioFilesProvider);
  KeyValueStore get _store => ref.read(kvStoreProvider);

  @override
  Map<int, DownloadState> build() {
    final gateway = ref.watch(downloadGatewayProvider);
    _sub?.cancel();
    _sub = gateway.events.listen(_onEvent);
    ref.onDispose(() => _sub?.cancel());
    final files = ref.watch(audioFilesProvider);
    // Files on disk are the truth; the saved list only says which tracks to check.
    final saved = ref.read(kvStoreProvider).getStringList(PrefKeys.downloadedTracks) ?? const [];
    final result = <int, DownloadState>{};
    for (final id in saved.map(int.tryParse).whereType<int>()) {
      final track = ref.read(catalogueProvider).track(id);
      if (track != null && files.hasFile(track)) result[id] = DownloadState.done;
    }
    unawaited(_restoreActive(gateway));
    return result;
  }

  Future<void> _restoreActive(DownloadGateway gateway) async {
    try {
      final active = await gateway.active();
      if (active.isEmpty) return;
      state = {
        ...state,
        for (final id in active)
          if (state[id]?.status != DownloadStatus.done)
            id: const DownloadState(DownloadStatus.queued),
      };
    } on Object {
      // Not available in tests or before the downloader starts.
    }
  }

  void _onEvent(DownloadEvent e) {
    final next = Map.of(state);
    switch (e.kind) {
      case DownloadEventKind.queued:
        next[e.trackId] = const DownloadState(DownloadStatus.queued);
      case DownloadEventKind.progress:
        next[e.trackId] = DownloadState(DownloadStatus.downloading, progress: e.progress);
      case DownloadEventKind.complete:
        final track = _catalogue.track(e.trackId);
        // Never shows ✓ for a partial or missing file (UNIFIED_PRODUCT_SPEC §8).
        if (track != null && _files.hasFile(track)) {
          next[e.trackId] = DownloadState.done;
          _persist(next);
        } else {
          next[e.trackId] = const DownloadState(
            DownloadStatus.failed,
            failure: DownloadFailure.other,
          );
        }
      case DownloadEventKind.failed:
        next[e.trackId] = DownloadState(DownloadStatus.failed, failure: e.failure);
      case DownloadEventKind.canceled:
        next.remove(e.trackId);
    }
    state = next;
  }

  void _persist(Map<int, DownloadState> s) {
    final ids = [
      for (final e in s.entries)
        if (e.value.status == DownloadStatus.done) '${e.key}',
    ];
    unawaited(_store.setStringList(PrefKeys.downloadedTracks, ids));
  }

  bool isDownloaded(int trackId) => state[trackId]?.status == DownloadStatus.done;

  /// Queues a download. Callers check Premium first (A-05).
  Future<void> download(Track track) async {
    final current = state[track.id];
    if (current != null && (current.isActive || current.status == DownloadStatus.done)) return;
    state = {...state, track.id: const DownloadState(DownloadStatus.queued)};
    final wifiOnly = _store.getBool(PrefKeys.wifiOnly) ?? true;
    final ok = await ref
        .read(downloadGatewayProvider)
        .enqueue(track, _catalogue.streamUrl(track), wifiOnly: wifiOnly);
    if (!ok) {
      state = {
        ...state,
        track.id: const DownloadState(DownloadStatus.failed, failure: DownloadFailure.other),
      };
    }
  }

  Future<void> downloadAll(Album album) async {
    for (final t in album.tracks) {
      await download(t);
    }
  }

  Future<void> remove(Track track) async {
    if (state[track.id]?.isActive ?? false) {
      await ref.read(downloadGatewayProvider).cancel(track.id);
    }
    await _files.delete(track);
    final next = Map.of(state)..remove(track.id);
    state = next;
    _persist(next);
  }

  Future<void> removeAlbum(Album album) async {
    for (final t in album.tracks) {
      if (state.containsKey(t.id)) await remove(t);
    }
  }

  Future<void> removeAll() async {
    for (final id in state.keys.toList()) {
      final t = _catalogue.track(id);
      if (t != null) await remove(t);
    }
  }

  /// Marks files found on disk as downloaded (the iOS migration, m008).
  void adopt(Iterable<int> trackIds) {
    final next = {...state, for (final id in trackIds) id: DownloadState.done};
    state = next;
    _persist(next);
  }

  int downloadedCount(Album album) =>
      album.tracks.where((t) => state[t.id]?.status == DownloadStatus.done).length;

  /// Bytes used by downloaded recordings.
  int bytesUsed([Album? album]) {
    var total = 0;
    for (final e in state.entries) {
      if (e.value.status != DownloadStatus.done) continue;
      final t = _catalogue.track(e.key);
      if (t == null || (album != null && t.albumId != album.id)) continue;
      total += _files.sizeOf(t);
    }
    return total;
  }
}

final downloadsProvider = NotifierProvider<DownloadsController, Map<int, DownloadState>>(
  DownloadsController.new,
);

/// "Download over Wi-Fi only" (A-20, default on).
class WifiOnlyController extends Notifier<bool> {
  @override
  bool build() => ref.watch(kvStoreProvider).getBool(PrefKeys.wifiOnly) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(kvStoreProvider).setBool(PrefKeys.wifiOnly, value);
  }
}

final wifiOnlyProvider = NotifierProvider<WifiOnlyController, bool>(WifiOnlyController.new);
