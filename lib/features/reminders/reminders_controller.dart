import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/logging/log.dart';
import '../../core/prefs/key_value_store.dart';
import 'notifications_gateway.dart';
import 'reminder_schedule.dart';

final notificationsGatewayProvider = Provider<NotificationsGateway>(
  (ref) => const NoNotifications(),
);

@immutable
class RemindersState {
  const RemindersState({required this.settings, this.permissionDenied = false});

  final ReminderSettings settings;

  /// A reminder is on but the system blocks this app's notifications: the page explains and
  /// offers Open settings (S-52).
  final bool permissionDenied;
}

/// Reminder settings and the scheduler (S-52, F-090, F-094, F-098). Every change reschedules at
/// once, by comparing what should exist with what is pending, so a narrowed window never
/// leaves old hours behind (BUG-23).
class RemindersController extends Notifier<RemindersState> {
  KeyValueStore get _store => ref.read(kvStoreProvider);
  NotificationsGateway get _gateway => ref.read(notificationsGatewayProvider);

  @override
  RemindersState build() {
    final store = ref.watch(kvStoreProvider);
    return RemindersState(
      settings: ReminderSettings(
        hourlyEnabled: store.getBool(PrefKeys.hourlyEnabled) ?? false,
        start:
            ClockTime.tryParse(store.getString(PrefKeys.hourlyStart)) ??
            ReminderSettings.defaultStart,
        end: ClockTime.tryParse(store.getString(PrefKeys.hourlyEnd)) ?? ReminderSettings.defaultEnd,
        nudgesEnabled: store.getBool(PrefKeys.nudgesEnabled) ?? true,
      ),
    );
  }

  ReminderSettings get settings => state.settings;

  /// Turns the hourly reminder on or off. Turning it on asks for permission first; if the user
  /// refuses, it stays off and the result is false (S-52).
  Future<bool> setHourly(bool on) async {
    if (on && !await _ensurePermission()) {
      state = RemindersState(settings: settings, permissionDenied: true);
      return false;
    }
    await _save(settings.copyWith(hourlyEnabled: on));
    return true;
  }

  Future<void> setStart(ClockTime start) => _save(settings.copyWith(start: start));

  /// The last reminder: only the hour counts; it fires at the start minute.
  Future<void> setEnd(ClockTime end) => _save(settings.copyWith(end: ClockTime(end.hour, 0)));

  Future<void> setNudges(bool on) => _save(settings.copyWith(nudgesEnabled: on));

  /// Onboarding's "Turn on reminders" (F-002, F-097).
  Future<bool> turnOnHourlyFromOnboarding() => setHourly(true);

  Future<void> openSystemSettings() => _gateway.openSettings();

  Future<bool> _ensurePermission() async {
    try {
      if (await _gateway.permissionGranted()) return true;
      return await _gateway.requestPermission();
    } on Object catch (error) {
      Log.w('Notification permission check failed: ${error.runtimeType}');
      return false;
    }
  }

  Future<void> _save(ReminderSettings next) async {
    state = RemindersState(settings: next, permissionDenied: state.permissionDenied);
    await _store.setBool(PrefKeys.hourlyEnabled, next.hourlyEnabled);
    await _store.setString(PrefKeys.hourlyStart, next.start.storage);
    await _store.setString(PrefKeys.hourlyEnd, next.end.storage);
    await _store.setBool(PrefKeys.nudgesEnabled, next.nudgesEnabled);
    await reschedule();
  }

  /// On every app open: re-arms the "we miss you" nudges (they count from now), re-applies the
  /// schedule (a reinstall, a restore or a time-zone change), and notices a revoked permission.
  Future<void> onAppOpen() async {
    await reschedule();
    await refreshPermission();
  }

  Future<void> refreshPermission() async {
    final anyOn = settings.hourlyEnabled || settings.nudgesEnabled;
    var denied = false;
    if (anyOn) {
      try {
        denied = !await _gateway.permissionGranted();
      } on Object {
        denied = false;
      }
    }
    // The nudges are on by default; their missing permission is only worth a warning when the
    // user has asked for hourly reminders.
    state = RemindersState(settings: settings, permissionDenied: denied && settings.hourlyEnabled);
  }

  /// Schedules what is wanted and not yet pending (or pending in an older form), and cancels
  /// what is pending but no longer wanted.
  Future<void> reschedule() async {
    // Until the iOS reminder migration has cancelled the native app's requests, scheduling new
    // ones would double them; one missing day is better (MIGRATION_PLAN §6, step 5).
    if (_store.getString(PrefKeys.migrationStep('m007')) == 'failed') return;
    final wanted = ReminderSchedule.build(settings, ref.read(clockProvider)());
    try {
      final zone = await _gateway.currentZone();
      final pending = await _gateway.pendingIds();
      final record = _record();
      final next = <String, String>{};
      for (final r in wanted) {
        final sig = '${r.signature}|$zone';
        next['${r.id}'] = sig;
        if (pending.contains(r.id) && record['${r.id}'] == sig) continue;
        if (pending.contains(r.id)) await _gateway.cancel(r.id);
        await _gateway.schedule(r);
      }
      final wantedIds = {for (final r in wanted) r.id};
      for (final id in pending) {
        if (ReminderSchedule.ownedIds.contains(id) && !wantedIds.contains(id)) {
          await _gateway.cancel(id);
        }
      }
      await _store.setString(PrefKeys.remindersScheduled, jsonEncode(next));
    } on Object catch (error, stack) {
      Log.e('Rescheduling reminders failed', error, stack);
    }
  }

  Map<String, String> _record() {
    final raw = _store.getString(PrefKeys.remindersScheduled);
    if (raw == null) return const {};
    try {
      return (jsonDecode(raw) as Map<String, Object?>).map((k, v) => MapEntry(k, '$v'));
    } on Object {
      return const {};
    }
  }
}

final remindersProvider = NotifierProvider<RemindersController, RemindersState>(
  RemindersController.new,
);
