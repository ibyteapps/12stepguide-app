// P2 journeys: read a step (UJ-4), the Big Book with "Continue reading" (UJ-5), set a recovery
// date (UJ-6), change the theme (UJ-12), onboarding (UJ-1) and welcome back (UJ-2/3).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/features/reader/reading_positions.dart';

import '../helpers/test_app.dart';

Future<void> waitForDocument(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a step opens in the reader with its text, and Aa changes the size', (tester) async {
    final app = await pumpApp(tester, prefs: {PrefKeys.coachMarkSeen: true});
    await tester.tap(find.text('Step 4'));
    await tester.pumpAndSettle();
    await waitForDocument(tester);
    expect(find.textContaining('searching and fearless moral inventory'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing, reason: 'reader is immersive (F-008)');

    await tester.tap(find.byTooltip('Text size and theme'));
    await tester.pumpAndSettle();
    expect(find.text('READING TEXT SIZE'), findsOneWidget);
    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(app.store.getInt(PrefKeys.textStep), 8);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(app.store.getString(PrefKeys.themeMode), 'dark');
  });

  testWidgets('the first reader shows the text-size tip once (F-043)', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.text('Step 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tap Aa'), findsOneWidget);
    expect(app.store.getBool(PrefKeys.coachMarkSeen), isTrue);
  });

  testWidgets('the end of a step offers the next one', (tester) async {
    await pumpApp(
      tester,
      location: '/read?id=prayers%2F01-serenity-prayer',
      prefs: {PrefKeys.coachMarkSeen: true},
    );
    await waitForDocument(tester);
    expect(find.text('Next: Serenity Prayer (Extended)'), findsOneWidget);
    await tester.tap(find.text('Next: Serenity Prayer (Extended)'));
    await tester.pumpAndSettle();
    await waitForDocument(tester);
    expect(find.text('Serenity Prayer (Extended)'), findsWidgets);
  });

  testWidgets('Big Book shows "Continue reading" for an unfinished chapter', (tester) async {
    final positions = jsonEncode({
      'big-book/06-chapter-5-how-it-works': ReadingPosition(
        offset: 1200,
        fraction: 0.3,
        textStep: 3,
        savedAt: testNow,
        page: 61,
      ).toJson(),
    });
    await pumpApp(tester, location: '/big-book', prefs: {PrefKeys.readingPositions: positions});
    expect(find.textContaining('Chapter 5: How It Works · page 61'), findsOneWidget);
    expect(find.text('Pages 58–71'), findsOneWidget);
  });

  testWidgets('recovery card: empty state, then days after a date is set', (tester) async {
    final app = await pumpApp(tester, location: '/readings');
    expect(find.text('Set your recovery date'), findsOneWidget);
    await app.store.setString(PrefKeys.sobrietyDate, '2026-10-01');
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester, location: '/readings', prefs: {PrefKeys.sobrietyDate: '2026-10-01'});
    expect(find.text('8 days'), findsOneWidget);
    expect(find.text('Sober since 1 October 2026'), findsOneWidget);
  });

  testWidgets('recovery date screen clears the date after confirming', (tester) async {
    final app = await pumpApp(
      tester,
      location: '/recovery-date',
      prefs: {PrefKeys.sobrietyDate: '2025-10-09'},
    );
    expect(find.text('365 days'), findsOneWidget);
    expect(find.text('1 year'), findsOneWidget);
    await tester.tap(find.text('Clear date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear date').last);
    await tester.pumpAndSettle();
    expect(app.store.getString(PrefKeys.sobrietyDate), isNull);
  });

  testWidgets('Daily Reflections opens aa.org with no advert first', (tester) async {
    final app = await pumpApp(tester, location: '/readings');
    await tester.tap(find.text('Daily Reflections'));
    await tester.pumpAndSettle();
    expect(app.links.opened, ['https://www.aa.org/pages/en_US/daily-reflection']);
  });

  testWidgets('onboarding: four pages, then the Steps tab', (tester) async {
    final app = await pumpApp(
      tester,
      location: '/onboarding',
      prefs: {PrefKeys.onboardingDone: false},
    );
    expect(find.text('Welcome to 12 Step Guide'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text("What's inside"), findsOneWidget);
    expect(find.textContaining('hours of recovery audio'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('A reminder each hour'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Free, with ads'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(app.store.getBool(PrefKeys.onboardingDone), isTrue);
    expect(find.text('Introduction'), findsOneWidget);
  });

  testWidgets('welcome back lists only what came across', (tester) async {
    final app = await pumpApp(
      tester,
      location: '/welcome-back',
      prefs: {
        PrefKeys.welcomeBackPending: true,
        PrefKeys.sobrietyDate: '2012-11-01',
        PrefKeys.migrationSummary: jsonEncode({
          'platform': 'android',
          'sobriety': true,
          'premium': 'lifetime',
        }),
      },
    );
    expect(find.textContaining('Your recovery date'), findsOneWidget);
    expect(find.text('Your supporter status: Premium for life'), findsOneWidget);
    expect(find.text('Your reminders'), findsNothing);
    expect(find.text('Over 90 hours of recovery audio'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(app.store.getBool(PrefKeys.welcomeBackPending), isFalse);
    expect(find.text('Introduction'), findsOneWidget);
  });

  testWidgets('works at 2× text size without overflow', (tester) async {
    await pumpApp(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Big Book').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Readings').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
