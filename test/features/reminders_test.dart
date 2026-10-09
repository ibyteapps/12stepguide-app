// Reminders (S-52, UNIFIED_PRODUCT_SPEC §7), the quote of the hour (S-60) and the iOS reminder
// migration (m007, MIGRATION_PLAN §6).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/app/providers.dart';
import 'package:twelve_step_guide/core/platform/legacy_bridge.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/features/migration/migration.dart';
import 'package:twelve_step_guide/features/reminders/reminder_schedule.dart';
import 'package:twelve_step_guide/features/reminders/reminders_controller.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

final now = DateTime(2026, 10, 9, 10, 30);

({ProviderContainer container, MemoryStore store, FakeNotifications notes}) setUpReminders({
  Map<String, Object> prefs = const {},
  FakeNotifications? notes,
}) {
  final store = MemoryStore({...prefs});
  final n = notes ?? FakeNotifications();
  final container = ProviderContainer(
    overrides: [
      kvStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => now),
      notificationsGatewayProvider.overrideWithValue(n),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, store: store, notes: n);
}

class _Bridge extends EmptyLegacyBridge {
  _Bridge(this.pending, {this.failCancel = false});

  final List<LegacyNotification> pending;
  final bool failCancel;
  final cancelled = <String>[];

  @override
  Future<Map<String, Object?>> readPrefs() async => {
    'launchcount': 40,
    'KEY_DATA_STRING_HOURLY_NOTIFICATION_START_TIME': '07:30',
    'KEY_DATA_STRING_HOURLY_NOTIFICATION_END_TIME': '21:00',
    'FLAG_NOTIFICATIONS_HOURLY': true,
  };

  @override
  Future<List<LegacyNotification>> pendingNotifications() async => pending;

  @override
  Future<void> cancelNotifications(List<String> ids) async {
    if (failCancel) throw StateError('notification centre unavailable');
    cancelled.addAll(ids);
  }
}

void main() {
  group('schedule (pure)', () {
    test('times parse from the native "HH:mm" and reject nonsense', () {
      expect(ClockTime.tryParse('08:00'), const ClockTime(8, 0));
      expect(ClockTime.tryParse('7:05'), const ClockTime(7, 5));
      expect(ClockTime.tryParse('25:00'), isNull);
      expect(ClockTime.tryParse(''), isNull);
      expect(const ClockTime(7, 5).storage, '07:05');
    });

    test('08:00 to 22:00 is 15 a day; a window past midnight wraps (no crash)', () {
      expect(const ReminderSettings().hourlyCount, 15);
      const late = ReminderSettings(start: ClockTime(22, 15), end: ClockTime(2, 0));
      expect(late.hours, [22, 23, 0, 1, 2]);
      const one = ReminderSettings(start: ClockTime(9, 0), end: ClockTime(9, 0));
      expect(one.hourlyCount, 1);
    });

    test('hourly reminders at the start minute, opening the quote', () {
      final planned = ReminderSchedule.build(
        const ReminderSettings(
          hourlyEnabled: true,
          start: ClockTime(8, 20),
          end: ClockTime(10, 0),
          nudgesEnabled: false,
        ),
        now,
      );
      expect(planned.map((r) => r.id), [108, 109, 110]);
      expect(planned.map((r) => r.daily), const [
        ClockTime(8, 20),
        ClockTime(9, 20),
        ClockTime(10, 20),
      ]);
      expect(planned.first.title, 'Hourly Consciousness Reminder');
      expect(planned.first.body, "Tap to reveal this hour's quote");
      expect(planned.first.payload, 'quote');
    });

    test('"we miss you" 3 and 7 days later at 10:00 (A-13)', () {
      final planned = ReminderSchedule.build(const ReminderSettings(), now);
      expect(planned.map((r) => r.id), [200, 201]);
      expect(planned[0].at, DateTime(2026, 10, 12, 10));
      expect(planned[1].at, DateTime(2026, 10, 16, 10));
      expect(planned[0].payload, isNull);
    });
  });

  group('scheduler', () {
    test('switching on asks permission, then schedules the window and the nudges', () async {
      final t = setUpReminders(notes: FakeNotifications(granted: false));
      final ok = await t.container.read(remindersProvider.notifier).setHourly(true);
      expect(ok, isTrue);
      expect(t.notes.permissionRequests, 1);
      expect(t.notes.scheduled.keys.where((id) => id < 200), hasLength(15));
      expect(t.notes.scheduled.keys, containsAll([200, 201]));
      expect(t.store.getBool(PrefKeys.hourlyEnabled), isTrue);
    });

    test('permission refused: the switch stays off and the page explains', () async {
      final t = setUpReminders(notes: FakeNotifications(granted: false, grantOnRequest: false));
      final ok = await t.container.read(remindersProvider.notifier).setHourly(true);
      expect(ok, isFalse);
      final s = t.container.read(remindersProvider);
      expect(s.settings.hourlyEnabled, isFalse);
      expect(s.permissionDenied, isTrue);
      expect(t.notes.scheduled.keys.where((id) => id < 200), isEmpty);
    });

    test('narrowing the window cancels the hours outside it (BUG-23)', () async {
      final t = setUpReminders();
      final c = t.container.read(remindersProvider.notifier);
      await c.setHourly(true);
      await c.setEnd(const ClockTime(12, 0));
      expect(t.notes.scheduled.keys.where((id) => id < 200).toList()..sort(), [
        108,
        109,
        110,
        111,
        112,
      ]);
      expect(t.notes.cancelled, containsAll([113, 120, 122]));
    });

    test('moving the start minute replaces every hourly reminder', () async {
      final t = setUpReminders();
      final c = t.container.read(remindersProvider.notifier);
      await c.setHourly(true);
      await c.setStart(const ClockTime(8, 30));
      expect(t.notes.scheduled[115]!.daily, const ClockTime(15, 30));
    });

    test('an unchanged schedule is left alone; a new time zone re-anchors it', () async {
      final t = setUpReminders();
      final c = t.container.read(remindersProvider.notifier);
      await c.setHourly(true);
      final calls = t.notes.scheduleCalls;
      await c.onAppOpen();
      expect(t.notes.scheduleCalls, calls, reason: 'nothing changed (nudges same day)');
      t.notes.zone = 'America/New_York';
      await c.onAppOpen();
      expect(t.notes.scheduleCalls, calls + 17);
    });

    test('switching off removes them all; nudges have their own switch', () async {
      final t = setUpReminders();
      final c = t.container.read(remindersProvider.notifier);
      await c.setHourly(true);
      await c.setHourly(false);
      await c.setNudges(false);
      expect(t.notes.scheduled, isEmpty);
    });

    test('nothing is scheduled while the iOS migration of reminders is failing', () async {
      final t = setUpReminders(prefs: {PrefKeys.migrationStep('m007'): 'failed'});
      await t.container.read(remindersProvider.notifier).onAppOpen();
      expect(t.notes.scheduled, isEmpty);
    });
  });

  group('m007: iOS reminders follow what users actually receive (A-12)', () {
    Future<MemoryStore> migrate(_Bridge bridge) async {
      final store = MemoryStore();
      await MigrationRunner(
        store: store,
        bridge: bridge,
        platform: LegacyPlatform.ios,
        steps: const [RemindersStep()],
        now: now,
      ).run();
      return store;
    }

    test('hourly requests pending: on, with the stored window, legacy ones cancelled', () async {
      final bridge = _Bridge(const [
        LegacyNotification(id: 'HourNotification88', hour: 8, minute: 0, action: 'x'),
        LegacyNotification(id: 'HourNotification99', hour: 9, minute: 0, action: 'x'),
        LegacyNotification(id: '3days'),
      ]);
      final store = await migrate(bridge);
      expect(store.getBool(PrefKeys.hourlyEnabled), isTrue);
      expect(store.getString(PrefKeys.hourlyStart), '07:30');
      expect(store.getString(PrefKeys.hourlyEnd), '21:00');
      expect(
        bridge.cancelled,
        containsAll(['HourNotification88', 'HourNotification2323', '3days']),
      );
      final summary = jsonDecode(store.getString(PrefKeys.migrationSummary)!) as Map;
      expect(summary['reminders'], isTrue);
    });

    test('the flag says on but nothing is pending (BUG-03): off, window kept', () async {
      final store = await migrate(_Bridge(const []));
      expect(store.getBool(PrefKeys.hourlyEnabled), isFalse);
      expect(store.getString(PrefKeys.hourlyStart), '07:30');
    });

    test('if cancelling fails, nothing is written and the step retries', () async {
      final store = await migrate(
        _Bridge(const [LegacyNotification(id: 'HourNotification88')], failCancel: true),
      );
      expect(store.getBool(PrefKeys.hourlyEnabled), isNull);
      expect(store.getString(PrefKeys.migrationStep('m007')), 'failed');
    });
  });

  group('screens', () {
    testWidgets('Reminders: switch on, the summary, and the Android note', (tester) async {
      final app = await pumpApp(tester, location: '/reminders');
      expect(find.text('A quote to pause on, once an hour'), findsOneWidget);
      await tester.tap(find.text('Hourly reminder'));
      await tester.pumpAndSettle();
      expect(find.textContaining('15 reminders a day'), findsOneWidget);
      expect(find.textContaining('a few minutes late'), findsOneWidget);
      expect(app.notifications.scheduled.keys.where((id) => id < 200), hasLength(15));
    });

    testWidgets('Reminders: blocked notifications show Open settings', (tester) async {
      final notes = FakeNotifications(granted: false);
      final app = await pumpApp(
        tester,
        location: '/reminders',
        notifications: notes,
        prefs: {PrefKeys.hourlyEnabled: true},
      );
      expect(find.textContaining('Notifications are turned off'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(app.notifications.settingsOpened, 1);
    });

    testWidgets('Quote of the hour: one of the 61, and Close', (tester) async {
      await pumpApp(tester, location: '/quote');
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toSet();
      expect(texts.intersection(testQuotes.toSet()), hasLength(1));
      expect(find.text('Close'), findsOneWidget);
      expect(testQuotes, hasLength(61));
    });
  });
}
