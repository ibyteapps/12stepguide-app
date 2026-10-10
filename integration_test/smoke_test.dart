// On-device smoke test (P7): starts the real app with its real plugins on an iOS simulator or
// an Android emulator, as a first-time user would, and walks every tab and the main pages.
//
//   flutter test integration_test/smoke_test.dart --flavor dev \
//     --dart-define-from-file=config/dev.json -d <device>
//
// CI runs it in ios.yml (simulator) and android.yml (emulator). It fails on any Flutter error,
// so a plugin that breaks at start-up or a layout overflow on a real screen shows up here.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:twelve_step_guide/app/bootstrap.dart';

/// Pumps until [finder] matches, or fails after [timeout]. pumpAndSettle can't be used: the
/// now-playing equaliser and download rings animate for as long as they are on screen.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

Future<void> tapAndWait(WidgetTester tester, Finder target, Finder expected) async {
  await pumpUntil(tester, target);
  await tester.tap(target.first);
  await pumpUntil(tester, expected);
}

Future<void> back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pump(const Duration(milliseconds: 600));
}

Finder tab(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
  matching: find.text(label),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch: onboarding, every tab, a reading, an album, the drawer pages', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    await bootstrap();
    // bootstrap installs the app's own handler (logging); keep it and collect as well.
    final appHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      appHandler?.call(details);
    };

    // A fresh install starts with onboarding (S-02).
    await tapAndWait(tester, find.text('Skip'), find.text('Introduction'));

    // Steps (S-10) → a reading (S-11) and back.
    await tapAndWait(tester, find.text('Step 1'), find.textContaining('strong chance'));
    await back(tester);

    // Traditions segment.
    await tapAndWait(tester, find.text('Traditions'), find.text('Tradition 1'));

    // Readings (S-20).
    await tapAndWait(tester, tab('Readings'), find.text('Daily Reflections'));
    expect(find.text('Serenity Prayer'), findsOneWidget);

    // Big Book (S-30) → Chapter 5.
    await tapAndWait(tester, tab('Big Book'), find.text('Chapter 5: How It Works'));
    await tapAndWait(
      tester,
      find.text('Chapter 5: How It Works'),
      find.textContaining('Rarely have we seen'),
    );
    await back(tester);

    // Audio (S-40) → an album (S-41) → play the first recording, which streams from the audio
    // server through the background media service, then pause it.
    await tapAndWait(tester, tab('Audio'), find.text('Joe & Charlie - Big Book Study'));
    await tapAndWait(tester, find.text('Joe & Charlie - Big Book Study'), find.text('Play all'));
    await tapAndWait(tester, find.text('AA History - Part 1'), find.byTooltip('Close player'));
    await tester.pump(const Duration(seconds: 5));
    // Down to the mini-player, which stops playback and closes.
    await tapAndWait(
      tester,
      find.byTooltip('Close player'),
      find.byTooltip('Stop and close player'),
    );
    await tester.tap(find.byTooltip('Stop and close player').first);
    await tester.pump(const Duration(seconds: 1));
    await back(tester);

    // Drawer pages (S-50…S-57).
    for (final (item, expected) in [
      ('Reminders', 'Hourly reminder'),
      ('Appearance', 'READING TEXT SIZE'),
      ('Premium', 'Restore purchases'),
      ('Downloads', 'Download over Wi-Fi only'),
      ('Our other apps', '12 Step Toolkit'),
    ]) {
      await tester.tap(find.byTooltip('Menu').first);
      await tester.pump(const Duration(milliseconds: 600));
      final entry = find.descendant(of: find.byType(Drawer), matching: find.text(item));
      await tester.scrollUntilVisible(
        entry,
        48,
        scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)),
      );
      await tapAndWait(tester, entry, find.textContaining(expected));
      await back(tester);
    }

    FlutterError.onError = appHandler;
    expect(
      errors.map((e) => e.exceptionAsString()).toList(),
      isEmpty,
      reason: 'Flutter errors while using the app on a ${defaultTargetPlatform.name} device',
    );
  });
}
