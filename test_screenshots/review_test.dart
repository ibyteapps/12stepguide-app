// Design review renders: every main screen, light and dark, phone and tablet.
//   flutter test test_screenshots/review_test.dart --update-goldens
// Output: test_screenshots/review/<device>/<screen>.png (not committed).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';

import '../test/helpers/test_app.dart';
import 'screenshot_harness.dart';

typedef Scenario = ({
  String name,
  String location,
  Map<String, Object> prefs,
  Future<void> Function(WidgetTester tester)? act,
});

final scenarios = <Scenario>[
  (name: 'steps', location: '/steps', prefs: {}, act: null),
  (name: 'traditions', location: '/steps', prefs: {PrefKeys.stepsSegment: 1}, act: null),
  (
    name: 'readings',
    location: '/readings',
    prefs: {PrefKeys.sobrietyDate: '2019-03-14'},
    act: null,
  ),
  (name: 'readings-empty', location: '/readings', prefs: {}, act: null),
  (name: 'big-book', location: '/big-book', prefs: {}, act: null),
  (
    name: 'reader-step',
    location: '/read?id=steps%2F04-step-4',
    prefs: {PrefKeys.coachMarkSeen: true},
    act: null,
  ),
  (
    name: 'reader-chapter5',
    location: '/read?id=big-book%2F06-chapter-5-how-it-works',
    prefs: {PrefKeys.coachMarkSeen: true},
    act: null,
  ),
  (
    name: 'recovery-date',
    location: '/recovery-date',
    prefs: {PrefKeys.sobrietyDate: '2019-03-14'},
    act: null,
  ),
  (name: 'appearance', location: '/appearance', prefs: {}, act: null),
  (name: 'drawer', location: '/steps', prefs: {}, act: (tester) => openDrawer(tester)),
  (name: 'onboarding', location: '/onboarding', prefs: {PrefKeys.onboardingDone: false}, act: null),
  (name: 'about', location: '/about', prefs: {}, act: null),
  (name: 'other-apps', location: '/other-apps', prefs: {}, act: null),
];

void main() {
  setUpAll(() async {
    await loadFonts();
  });

  for (final device in [androidPhone, iphone, tablet10]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final s in scenarios) {
        testWidgets('${device.id} ${mode.name} ${s.name}', (tester) async {
          debugDefaultTargetPlatformOverride = device.platform;
          debugDisableShadows = false;
          try {
            await pumpApp(
              tester,
              location: s.location,
              prefs: s.prefs,
              size: device.size,
              ratio: device.ratio,
              themeMode: mode,
            );
            await settleForCapture(tester);
            await s.act?.call(tester);
            await settleForCapture(tester);
            await expectLater(
              find.byKey(appBoundaryKey),
              matchesGoldenFile('review/${device.id}/${s.name}-${mode.name}.png'),
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
            debugDisableShadows = true;
          }
        });
      }
    }
  }
}
