import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/features/sobriety/sobriety_date.dart';

void main() {
  group('day count uses calendar dates (BUG-10)', () {
    test('same day is 0', () {
      expect(SobrietyDate.days(DateTime(2026, 10, 9), DateTime(2026, 10, 9, 23, 59)), 0);
    });

    test('across the UK clocks going back is still whole days', () {
      // BST ends 25 Oct 2026; a millisecond count would be off by an hour.
      expect(SobrietyDate.days(DateTime(2026, 10, 24), DateTime(2026, 10, 26, 0, 30)), 2);
      expect(SobrietyDate.days(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    });

    test('leap years count 29 February', () {
      expect(SobrietyDate.days(DateTime(2024, 2, 28), DateTime(2024, 3, 1)), 2);
      expect(SobrietyDate.days(DateTime(2023, 2, 28), DateTime(2023, 3, 1)), 1);
    });

    test('never negative when the clock is behind the date', () {
      expect(SobrietyDate.days(DateTime(2026, 10, 10), DateTime(2026, 10, 9)), 0);
    });

    test('times of day do not matter', () {
      expect(SobrietyDate.days(DateTime(2026, 10, 8, 23, 59), DateTime(2026, 10, 9, 0, 1)), 1);
    });

    test('utc and local inputs agree', () {
      expect(SobrietyDate.days(DateTime.utc(2020, 1, 1), DateTime(2020, 1, 31)), 30);
    });
  });

  group('breakdown', () {
    test('years, months and days', () {
      final b = SobrietyDate.breakdown(DateTime(2019, 3, 14), DateTime(2026, 10, 9));
      expect((b.years, b.months, b.days), (7, 6, 25));
      expect(SobrietyDate.breakdownLabel(b), '7 years, 6 months, 25 days');
    });

    test('month ends clamp (31 Jan + 1 month)', () {
      final b = SobrietyDate.breakdown(DateTime(2026, 1, 31), DateTime(2026, 2, 28));
      expect((b.years, b.months, b.days), (0, 0, 28));
      final c = SobrietyDate.breakdown(DateTime(2026, 1, 31), DateTime(2026, 3, 31));
      expect((c.years, c.months, c.days), (0, 2, 0));
    });

    test('labels', () {
      expect(SobrietyDate.daysLabel(1), '1 day');
      expect(SobrietyDate.daysLabel(1234), '1,234 days');
      expect(SobrietyDate.breakdownLabel((years: 1, months: 0, days: 1)), '1 year, 1 day');
      expect(SobrietyDate.breakdownLabel((years: 0, months: 0, days: 0)), '0 days');
    });
  });

  group('storage format', () {
    test('ISO round trip', () {
      expect(SobrietyDate.toIso(DateTime(2012, 11, 1)), '2012-11-01');
      expect(SobrietyDate.fromIso('2012-11-01'), DateTime(2012, 11, 1));
    });

    test('rejects impossible dates', () {
      expect(SobrietyDate.fromIso('2023-02-29'), isNull);
      expect(SobrietyDate.fromIso('nonsense'), isNull);
      expect(SobrietyDate.fromIso(null), isNull);
    });

    test('long format', () {
      expect(SobrietyDate.formatLong(DateTime(2012, 11, 1)), '1 November 2012');
    });
  });
}
