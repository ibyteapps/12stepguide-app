import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

import '../../../core/logging/log.dart';
import '../domain/catalogue.dart';

enum DownloadEventKind { queued, progress, complete, failed, canceled }

@immutable
class DownloadEvent {
  const DownloadEvent(this.trackId, this.kind, {this.progress = 0, this.failure});

  final int trackId;
  final DownloadEventKind kind;
  final double progress;
  final DownloadFailure? failure;
}

enum DownloadFailure { network, storageFull, server, other }

/// Where downloaded recordings live (FLUTTER_ARCHITECTURE §9): iOS `Documents/{file}`, the
/// native app's location, so its downloads are reused in place; Android `filesDir/audio/{file}`.
class AudioFiles {
  const AudioFiles(this.directory);

  final String directory;

  File fileFor(Track track) => File('$directory/${track.file}');

  /// The truth is on disk: a file that exists and is not empty (UNIFIED_PRODUCT_SPEC §8).
  bool hasFile(Track track) {
    final f = fileFor(track);
    try {
      return f.existsSync() && f.lengthSync() > 0;
    } on FileSystemException {
      return false;
    }
  }

  int sizeOf(Track track) {
    try {
      return fileFor(track).lengthSync();
    } on FileSystemException {
      return 0;
    }
  }

  /// Removing a file is quick, so it is done at once; the downloads list never shows a file
  /// that is already gone.
  Future<void> delete(Track track) async {
    final f = fileFor(track);
    try {
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException catch (error) {
      Log.w('Could not delete ${track.file}: ${error.osError?.errorCode}');
    }
  }
}

/// Background downloads behind one interface (FLUTTER_ARCHITECTURE §10.2), so the controller is
/// tested with a fake.
abstract interface class DownloadGateway {
  Stream<DownloadEvent> get events;

  /// Picks up downloads that carried on while the app was closed.
  Future<void> start();
  Future<bool> enqueue(Track track, Uri url, {required bool wifiOnly});
  Future<void> cancel(int trackId);

  /// Track ids with a download queued or running.
  Future<Set<int>> active();
}

/// background_downloader: iOS background URLSession, Android WorkManager; two at a time, as in
/// the native app; resumes after the app is killed.
class BackgroundDownloaderGateway implements DownloadGateway {
  BackgroundDownloaderGateway({required this.isIOS});

  final bool isIOS;
  final _events = StreamController<DownloadEvent>.broadcast();
  bool _started = false;

  static String taskId(int trackId) => 'track-$trackId';
  static int? trackIdOf(String taskId) =>
      taskId.startsWith('track-') ? int.tryParse(taskId.substring(6)) : null;

  @override
  Stream<DownloadEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final downloader = FileDownloader();
    await downloader.configure(
      globalConfig: (Config.holdingQueue, (2, null, null)),
      // Re-downloadable, so kept out of iCloud backups (F-113).
      iOSConfig: (Config.excludeFromCloudBackup, Config.always),
    );
    downloader.updates.listen(_onUpdate);
    await downloader.start(autoCleanDatabase: true);
  }

  void _onUpdate(TaskUpdate update) {
    final id = trackIdOf(update.task.taskId);
    if (id == null) return;
    switch (update) {
      case TaskProgressUpdate(:final progress):
        if (progress >= 0 && progress <= 1) {
          _events.add(DownloadEvent(id, DownloadEventKind.progress, progress: progress));
        }
      case TaskStatusUpdate(:final status, :final exception, :final responseStatusCode):
        switch (status) {
          case TaskStatus.enqueued:
            _events.add(DownloadEvent(id, DownloadEventKind.queued));
          case TaskStatus.running:
            _events.add(DownloadEvent(id, DownloadEventKind.progress));
          case TaskStatus.complete:
            _events.add(DownloadEvent(id, DownloadEventKind.complete, progress: 1));
          case TaskStatus.canceled:
            _events.add(DownloadEvent(id, DownloadEventKind.canceled));
          case TaskStatus.failed || TaskStatus.notFound:
            final failure = switch (exception) {
              TaskFileSystemException() => DownloadFailure.storageFull,
              TaskConnectionException() => DownloadFailure.network,
              TaskHttpException() => DownloadFailure.server,
              _ when (responseStatusCode ?? 0) >= 400 => DownloadFailure.server,
              _ => DownloadFailure.other,
            };
            Log.w('Download failed for track $id: $failure');
            _events.add(DownloadEvent(id, DownloadEventKind.failed, failure: failure));
          case TaskStatus.waitingToRetry || TaskStatus.paused:
            _events.add(DownloadEvent(id, DownloadEventKind.queued));
        }
    }
  }

  @override
  Future<bool> enqueue(Track track, Uri url, {required bool wifiOnly}) {
    final task = DownloadTask(
      taskId: taskId(track.id),
      url: url.toString(),
      filename: track.file,
      baseDirectory: isIOS ? BaseDirectory.applicationDocuments : BaseDirectory.applicationSupport,
      directory: isIOS ? '' : 'audio',
      updates: Updates.statusAndProgress,
      requiresWiFi: wifiOnly,
      retries: 2,
      allowPause: true,
      displayName: track.title,
    );
    return FileDownloader().enqueue(task);
  }

  @override
  Future<void> cancel(int trackId) async {
    await FileDownloader().cancelTaskWithId(taskId(trackId));
  }

  @override
  Future<Set<int>> active() async {
    final tasks = await FileDownloader().allTasks();
    return {for (final t in tasks) ?trackIdOf(t.taskId)};
  }
}
