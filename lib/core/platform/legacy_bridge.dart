import 'package:flutter/services.dart';

import '../logging/log.dart';

/// A pending notification the native iOS app scheduled.
class LegacyNotification {
  const LegacyNotification({required this.id, this.hour, this.minute, this.action});

  factory LegacyNotification.fromMap(Map<Object?, Object?> map) => LegacyNotification(
    id: map['id']! as String,
    hour: map['hour'] as int?,
    minute: map['minute'] as int?,
    action: map['action'] as String?,
  );

  final String id;

  /// From the request's calendar trigger, never parsed from the id (MIGRATION_PLAN §6).
  final int? hour;
  final int? minute;
  final String? action;
}

/// A file the native iOS app left in its Documents folder.
class LegacyFile {
  const LegacyFile({required this.name, required this.bytes, required this.path});

  factory LegacyFile.fromMap(Map<Object?, Object?> map) => LegacyFile(
    name: map['name']! as String,
    bytes: (map['bytes']! as num).toInt(),
    path: map['path']! as String,
  );

  final String name;
  final int bytes;
  final String path;
}

/// Read-only access to what the native app left on the device (FLUTTER_ARCHITECTURE.md §10.8).
///
/// Implemented in Swift (`ios/Runner/LegacyMigrationPlugin.swift`) and Kotlin
/// (`android/.../LegacyMigrationPlugin.kt`). Apart from [cancelNotifications] and
/// [excludeFromBackup], nothing here changes legacy data.
abstract interface class LegacyBridge {
  /// iOS: the standard `NSUserDefaults` domain. Android: the default SharedPreferences file.
  /// Values are `bool`, `int`, `double`, `String`, or a millisecond timestamp for iOS dates.
  Future<Map<String, Object?>> readPrefs();

  /// iOS only; empty elsewhere.
  Future<List<LegacyNotification>> pendingNotifications();

  /// iOS only: removes pending and delivered legacy notifications with these ids.
  Future<void> cancelNotifications(List<String> ids);

  /// iOS only: files in `Documents`.
  Future<List<LegacyFile>> listDocuments();

  /// iOS only: marks a file as not backed up to iCloud (it can be downloaded again).
  Future<void> excludeFromBackup(String path);
}

class MethodChannelLegacyBridge implements LegacyBridge {
  const MethodChannelLegacyBridge();

  static const _channel = MethodChannel('com.ibyteapps.aa12stepguide/legacy');

  @override
  Future<Map<String, Object?>> readPrefs() async {
    final result = await _channel.invokeMapMethod<String, Object?>('readLegacyPrefs');
    return result ?? const {};
  }

  @override
  Future<List<LegacyNotification>> pendingNotifications() async {
    final result = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'pendingLegacyNotifications',
    );
    return [
      for (final m in result ?? const <Map<Object?, Object?>>[]) LegacyNotification.fromMap(m),
    ];
  }

  @override
  Future<void> cancelNotifications(List<String> ids) =>
      _channel.invokeMethod<void>('cancelLegacyNotifications', {'ids': ids});

  @override
  Future<List<LegacyFile>> listDocuments() async {
    final result = await _channel.invokeListMethod<Map<Object?, Object?>>('listLegacyDownloads');
    return [for (final m in result ?? const <Map<Object?, Object?>>[]) LegacyFile.fromMap(m)];
  }

  @override
  Future<void> excludeFromBackup(String path) async {
    try {
      await _channel.invokeMethod<void>('excludeFromBackup', {'path': path});
    } on PlatformException catch (error) {
      Log.w('excludeFromBackup failed: ${error.code}');
    }
  }
}

/// A bridge with nothing on it: a fresh install, tests, and platforms without legacy data.
class EmptyLegacyBridge implements LegacyBridge {
  const EmptyLegacyBridge();

  @override
  Future<Map<String, Object?>> readPrefs() async => const {};
  @override
  Future<List<LegacyNotification>> pendingNotifications() async => const [];
  @override
  Future<void> cancelNotifications(List<String> ids) async {}
  @override
  Future<List<LegacyFile>> listDocuments() async => const [];
  @override
  Future<void> excludeFromBackup(String path) async {}
}
