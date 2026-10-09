import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/app/app.dart';
import 'package:twelve_step_guide/core/config/app_env.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('the shell shows four tabs and the Steps list', (tester) async {
    await pumpApp(tester);
    for (final tab in ['Steps', 'Readings', 'Big Book', 'Audio']) {
      expect(find.text(tab), findsWidgets);
    }
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(Banner), findsNothing);
  });

  testWidgets('dev and staging builds carry an environment banner', (tester) async {
    for (final env in [AppEnv.dev, AppEnv.staging]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(tester, env: env);
      final banner = tester.widget<Banner>(find.byType(Banner));
      expect(banner.message, env.name.toUpperCase());
    }
  });

  testWidgets('tablets get a navigation rail instead of the bottom bar', (tester) async {
    await pumpApp(tester, size: tablet);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('switching tabs remembers the last tab', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.text('Readings').last);
    await tester.pumpAndSettle();
    expect(find.text('Daily Reflections'), findsOneWidget);
    expect(app.store.getInt(PrefKeys.lastTab), 1);
  });

  testWidgets('the drawer lists every destination from the old Settings tabs', (tester) async {
    await pumpApp(tester);
    await openDrawer(tester);
    for (final item in [
      'Premium',
      'Reminders',
      'Appearance',
      'Downloads',
      'Contact us',
      'Rate the app',
      'Tell a friend',
      'Follow us on Facebook',
      'Our other apps',
      'Privacy policy',
      'Terms of use',
    ]) {
      await tester.scrollUntilVisible(
        find.text(item),
        48,
        scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)),
      );
      expect(find.text(item), findsOneWidget, reason: item);
    }
    expect(find.text('About · Version 2.0.0 (100)'), findsOneWidget);
    expect(find.text('Free · Go Premium – from £1.99'), findsOneWidget);
  });

  testWidgets('a misconfigured build explains itself', (tester) async {
    await tester.pumpWidget(const ConfigErrorApp(message: 'Build with config/prod.json.'));
    expect(find.text('This build is misconfigured'), findsOneWidget);
    expect(find.text('Build with config/prod.json.'), findsOneWidget);
  });
}
