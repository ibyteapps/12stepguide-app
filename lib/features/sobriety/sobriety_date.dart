import 'package:intl/intl.dart';

/// Recovery-date arithmetic on calendar dates (fixes BUG-10: the native Android app counted
/// milliseconds between local midnights, which is a day off across a DST change).
///
/// Dates are compared as calendar days in UTC, so time zones, travel and DST never change the
/// count, and leap days are counted like any other day.
abstract final class SobrietyDate {
  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Whole days from [since] to [now]. Never negative: a device clock that moves backwards
  /// shows 0, not a negative number (UNIFIED_PRODUCT_SPEC §8).
  static int days(DateTime since, DateTime now) {
    final diff = _day(now).difference(_day(since)).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Years, months and days between the two dates, counting whole calendar months.
  static ({int years, int months, int days}) breakdown(DateTime since, DateTime now) {
    final from = _day(since);
    final to = _day(now);
    if (!to.isAfter(from)) return (years: 0, months: 0, days: 0);
    var months = (to.year - from.year) * 12 + to.month - from.month;
    if (to.day < from.day) months--;
    final anchor = _addMonths(from, months);
    final days = to.difference(anchor).inDays;
    return (years: months ~/ 12, months: months % 12, days: days);
  }

  /// [d] plus [months], clamping the day to the target month's length (31 Jan + 1 month =
  /// 28/29 Feb).
  static DateTime _addMonths(DateTime d, int months) {
    final total = d.year * 12 + (d.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(year, month, d.day > lastDay ? lastDay : d.day);
  }

  /// "1 November 2012".
  static String formatLong(DateTime d) => DateFormat('d MMMM y').format(d);

  /// ISO calendar date for storage: "2012-11-01".
  static String toIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? fromIso(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    if (date.year != y || date.month != mo || date.day != d) return null;
    return date;
  }

  /// "1 day", "12 days", "1,234 days".
  static String daysLabel(int days) =>
      '${NumberFormat.decimalPattern('en_GB').format(days)} ${days == 1 ? 'day' : 'days'}';

  /// "2 years, 3 months, 4 days" (zero parts left out).
  static String breakdownLabel(({int years, int months, int days}) b) {
    String part(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';
    final parts = [
      if (b.years > 0) part(b.years, 'year'),
      if (b.months > 0) part(b.months, 'month'),
      if (b.days > 0 || (b.years == 0 && b.months == 0)) part(b.days, 'day'),
    ];
    return parts.join(', ');
  }
}
