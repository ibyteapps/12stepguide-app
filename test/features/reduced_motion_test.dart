import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';

import '../helpers/test_app.dart';

/// With "Remove animations" (Android) or Reduce Motion (iOS) on, paged screens jump instead of
/// sliding. Found by the Android emulator smoke test, which runs with animations off: a
/// zero-length page animation is an error.
void main() {
  const prefs = {PrefKeys.coachMarkSeen: true};

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(
    () =>
        TestWidgetsFlutterBinding.instance.platformDispatcher.clearAccessibilityFeaturesTestValue(),
  );

  testWidgets('Steps: the Traditions segment', (tester) async {
    await pumpApp(tester, prefs: prefs);
    await tester.tap(find.text('Traditions'));
    await tester.pumpAndSettle();
    expect(find.text('Tradition 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Big Book: the 2nd-edition stories', (tester) async {
    await pumpApp(tester, location: '/big-book', prefs: prefs);
    await tester.tap(find.textContaining('2nd ed.'));
    await tester.pumpAndSettle();
    expect(find.text("The Doctor's Nightmare"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding: Next', (tester) async {
    await pumpApp(tester, location: '/onboarding', prefs: {PrefKeys.onboardingDone: false});
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text("What's inside"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
