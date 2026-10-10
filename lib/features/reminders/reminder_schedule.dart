import 'package:flutter/foundation.dart';

/// A wall-clock time, "HH:mm" in storage (the native iOS app's format).
@immutable
class ClockTime {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// "08:00". Anything unreadable is null.
  static ClockTime? tryParse(String? value) {
    if (value == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (m == null) return null;
    final h = int.parse(m[1]!), min = int.parse(m[2]!);
    if (h > 23 || min > 59) return null;
    return ClockTime(h, min);
  }

  String get storage => '${_two(hour)}:${_two(minute)}';
  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => storage;
}

@immutable
class ReminderSettings {
  const ReminderSettings({
    this.hourlyEnabled = false,
    this.start = defaultStart,
    this.end = defaultEnd,
    this.nudgesEnabled = true,
  });

  /// The native app's defaults (F-090).
  static const defaultStart = ClockTime(8, 0);
  static const defaultEnd = ClockTime(22, 0);

  final bool hourlyEnabled;

  /// The first reminder; every reminder uses this minute.
  final ClockTime start;

  /// The last reminder's hour (its minute is the start minute).
  final ClockTime end;

  /// "We miss you" after 3 and 7 days without opening the app (A-13, on by default).
  final bool nudgesEnabled;

  /// Reminders a day: start hour to end hour inclusive, wrapping past midnight (max 24).
  int get hourlyCount => ((end.hour - start.hour) % 24) + 1;

  List<int> get hours => [for (var i = 0; i < hourlyCount; i++) (start.hour + i) % 24];

  ReminderSettings copyWith({
    bool? hourlyEnabled,
    ClockTime? start,
    ClockTime? end,
    bool? nudgesEnabled,
  }) => ReminderSettings(
    hourlyEnabled: hourlyEnabled ?? this.hourlyEnabled,
    start: start ?? this.start,
    end: end ?? this.end,
    nudgesEnabled: nudgesEnabled ?? this.nudgesEnabled,
  );
}

enum ReminderChannel {
  hourly('reminders_hourly', 'Hourly reminders'),
  nudges('nudges', 'We miss you');

  const ReminderChannel(this.id, this.label);

  final String id;
  final String label;
}

/// One notification the app wants scheduled.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.channel,
    required this.title,
    required this.body,
    this.payload,
    this.daily,
    this.at,
  }) : assert((daily == null) != (at == null));

  final int id;
  final ReminderChannel channel;
  final String title;
  final String body;

  /// Where a tap goes (`quote`), or null to just open the app.
  final String? payload;

  /// Repeats every day at this time…
  final ClockTime? daily;

  /// …or fires once at this local time.
  final DateTime? at;

  /// Identifies what was scheduled, so an unchanged reminder is not scheduled again and a
  /// changed one is replaced (fixes BUG-23).
  String get signature => '${channel.id}|$title|$body|$payload|${daily ?? at?.toIso8601String()}';
}

/// Turns settings into the notifications that should exist (UNIFIED_PRODUCT_SPEC §7). Pure.
abstract final class ReminderSchedule {
  /// Hourly reminders use ids 100–123 (100 + hour); nudges 200 and 201.
  static const hourlyBase = 100;
  static const nudge3 = 200;
  static const nudge7 = 201;
  static final ownedIds = {for (var h = 0; h < 24; h++) hourlyBase + h, nudge3, nudge7};

  static const hourlyTitle = 'Hourly Consciousness Reminder';
  static const hourlyBody = "Tap to reveal this hour's quote";
  static const quotePayload = 'quote';

  /// "We miss you" fires at 10:00 local time, not at midnight as before (A-13).
  static const nudgeTime = ClockTime(10, 0);

  static List<PlannedReminder> build(ReminderSettings s, DateTime now) => [
    if (s.hourlyEnabled)
      for (final h in s.hours)
        PlannedReminder(
          id: hourlyBase + h,
          channel: ReminderChannel.hourly,
          title: hourlyTitle,
          body: hourlyBody,
          payload: quotePayload,
          daily: ClockTime(h, s.start.minute),
        ),
    if (s.nudgesEnabled) ...[
      PlannedReminder(
        id: nudge3,
        channel: ReminderChannel.nudges,
        title: 'We miss you',
        body: "It's been 3 days since you used the app.",
        at: _daysLater(now, 3),
      ),
      PlannedReminder(
        id: nudge7,
        channel: ReminderChannel.nudges,
        title: 'We really miss you',
        body: "It's been 7 days since you used the app.",
        at: _daysLater(now, 7),
      ),
    ],
  ];

  /// Calendar days, so the time stays 10:00 across a daylight-saving change.
  static DateTime _daysLater(DateTime now, int days) =>
      DateTime(now.year, now.month, now.day + days, nudgeTime.hour, nudgeTime.minute);
}
