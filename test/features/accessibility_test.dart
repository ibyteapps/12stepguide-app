import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';

import '../helpers/test_app.dart';

/// UX_UI_SPEC §9 on the main screens, light and dark: every tap target is labelled and at least
/// 48 × 48 (Android) / 44 × 44 (iOS), and text has enough contrast.
void main() {
  const screens = {
    'Steps': '/steps',
    'Readings': '/readings',
    'Big Book': '/big-book',
    'Audio': '/audio',
    'Recovery date': '/recovery-date',
    'Reminders': '/reminders',
    'Appearance': '/appearance',
    'Premium': '/premium',
    'Downloads': '/downloads',
    'About': '/about',
    'Other apps': '/other-apps',
    'Reader': '/read?id=steps%2F04-step-4',
    'Quote of the hour': '/quote',
    'Paywall': '/paywall',
    'Onboarding': '/onboarding',
  };

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final MapEntry(key: name, value: location) in screens.entries) {
      testWidgets('$name (${mode.name}) meets the accessibility guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          location: location,
          themeMode: mode,
          prefs: {
            PrefKeys.sobrietyDate: '2019-03-14',
            PrefKeys.coachMarkSeen: true,
            if (location == '/onboarding') PrefKeys.onboardingDone: false,
          },
        );
        // Readings load their text asynchronously.
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }
}
