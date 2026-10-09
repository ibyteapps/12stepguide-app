import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/config/app_env.dart';

/// The app root.
///
/// P0 placeholder: P1 replaces the home page with the router, the shell (four tabs and the
/// drawer, D-001) and the design-token themes.
class TwelveStepGuideApp extends StatelessWidget {
  const TwelveStepGuideApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: '12 Step Guide',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: const _PlaceholderHome(),
    );
    if (config.env == AppEnv.prod) return app;
    // Marks dev and staging builds so a screenshot can never be mistaken for the store app.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        message: config.env.name.toUpperCase(),
        location: BannerLocation.topEnd,
        child: app,
      ),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '12 Step Guide',
                  style: textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 2.0 is being built.',
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the app when the build's flavour and config disagree.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _ConfigErrorPage(message: message),
    );
  }
}

class _ConfigErrorPage extends StatelessWidget {
  const _ConfigErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This build is misconfigured',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SelectableText(message),
            ],
          ),
        ),
      ),
    );
  }
}
