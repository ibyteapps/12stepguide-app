import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/app/app.dart';
import 'package:twelve_step_guide/core/config/app_config.dart';
import 'package:twelve_step_guide/core/config/app_env.dart';

void main() {
  testWidgets('prod build shows the app with no environment banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TwelveStepGuideApp(config: AppConfig(env: AppEnv.prod)),
    );
    expect(find.text('12 Step Guide'), findsOneWidget);
    expect(find.byType(Banner), findsNothing);
  });

  testWidgets('dev and staging builds carry an environment banner', (
    tester,
  ) async {
    for (final env in [AppEnv.dev, AppEnv.staging]) {
      await tester.pumpWidget(TwelveStepGuideApp(config: AppConfig(env: env)));
      final banner = tester.widget<Banner>(find.byType(Banner));
      expect(banner.message, env.name.toUpperCase());
    }
  });

  testWidgets('a misconfigured build explains itself', (tester) async {
    await tester.pumpWidget(
      const ConfigErrorApp(message: 'Build with config/prod.json.'),
    );
    expect(find.text('This build is misconfigured'), findsOneWidget);
    expect(find.text('Build with config/prod.json.'), findsOneWidget);
  });
}
