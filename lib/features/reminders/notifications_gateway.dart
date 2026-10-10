import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../../core/logging/log.dart';
import 'reminder_schedule.dart';

/// Local notifications behind one interface (FLUTTER_ARCHITECTURE §10.5), so the scheduler and
/// the screens are tested with a fake.
abstract interface class NotificationsGateway {
  /// [onTap] receives the payload of a notification the user tapped while the app was running.
  Future<void> init({required void Function(String? payload) onTap});

  /// The payload of the notification that launched the app, if one did.
  Future<String?> launchPayload();
  Future<bool> permissionGranted();

  /// Reads the device's time zone (it may have changed since the last open) and returns its
  /// name. Schedules are keyed on it, so travelling re-anchors them to local time.
  Future<String> currentZone();

  /// Asks once (iOS alert; Android 13+ POST_NOTIFICATIONS). True when allowed.
  Future<bool> requestPermission();
  Future<Set<int>> pendingIds();
  Future<void> schedule(PlannedReminder reminder);
  Future<void> cancel(int id);

  /// The system's notification settings for this app.
  Future<void> openSettings();
}

class LocalNotificationsGateway implements NotificationsGateway {
  LocalNotificationsGateway({required this.isIOS});

  final bool isIOS;
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _system = MethodChannel('com.ibyteapps.aa12stepguide/system');

  @override
  Future<void> init({required void Function(String? payload) onTap}) async {
    tzdata.initializeTimeZones();
    await currentZone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        // Permission is asked when a reminder is first turned on, never at launch (F-097).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => onTap(r.payload),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      for (final c in ReminderChannel.values) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(c.id, c.label, importance: Importance.defaultImportance),
        );
      }
    }
  }

  @override
  Future<String> currentZone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object catch (error) {
      // Falls back to the last zone (UTC at first), which still fires on time if it never changes.
      Log.w('Local time zone unavailable: ${error.runtimeType}');
    }
    return tz.local.name;
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<bool> permissionGranted() async {
    if (isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final status = await ios?.checkPermissions();
      return status?.isEnabled ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<Set<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final p in pending) p.id};
  }

  @override
  Future<void> schedule(PlannedReminder r) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        r.channel.id,
        r.channel.label,
        icon: '@drawable/ic_notification',
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      ),
    );
    final now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime when;
    if (r.daily != null) {
      var next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        r.daily!.hour,
        r.daily!.minute,
      );
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      when = next;
    } else {
      final at = r.at!;
      when = tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour, at.minute);
    }
    await _plugin.zonedSchedule(
      id: r.id,
      title: r.title,
      body: r.body,
      payload: r.payload,
      scheduledDate: when,
      notificationDetails: details,
      // Inexact on Android: no exact-alarm permission; may arrive a few minutes late.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: r.daily != null ? DateTimeComponents.time : null,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> openSettings() async {
    if (isIOS) {
      await launchUrl(Uri.parse('app-settings:'));
      return;
    }
    try {
      await _system.invokeMethod<void>('openNotificationSettings');
    } on PlatformException catch (error) {
      Log.w('Could not open notification settings: ${error.code}');
    }
  }
}

/// Used where notifications cannot run (desktop, tests without a fake).
class NoNotifications implements NotificationsGateway {
  const NoNotifications();
  @override
  Future<void> init({required void Function(String? payload) onTap}) async {}
  @override
  Future<String?> launchPayload() async => null;
  @override
  Future<bool> permissionGranted() async => false;
  @override
  Future<String> currentZone() async => 'UTC';
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<Set<int>> pendingIds() async => const {};
  @override
  Future<void> schedule(PlannedReminder reminder) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> openSettings() async {}
}
