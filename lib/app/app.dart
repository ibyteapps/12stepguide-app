import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_env.dart';
import '../design/components/text_scale.dart';
import '../design/tokens/spacing.dart';
import '../design/theme/app_theme.dart';
import '../features/appearance/appearance_controller.dart';
import 'providers.dart';

/// The app root: themes from the design tokens, the router, and the system text size capped at
/// 2.0× for UI chrome (the reader restores the full size).
class TwelveStepGuideApp extends ConsumerWidget {
  const TwelveStepGuideApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appearanceProvider.select((s) => s.themeMode));
    final env = ref.watch(appConfigProvider).env;
    return MaterialApp.router(
      title: '12 Step Guide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: router,
      scaffoldMessengerKey: ref.watch(messengerKeyProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        Widget app = UnclampedTextScale(
          scaler: media.textScaler,
          child: MediaQuery(
            data: media.copyWith(textScaler: media.textScaler.clamp(maxScaleFactor: 2)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
        // Marks dev and staging builds so a screenshot can never be mistaken for the store app.
        if (env != AppEnv.prod) {
          app = Banner(
            message: env.name.toUpperCase(),
            location: BannerLocation.topEnd,
            child: app,
          );
        }
        return app;
      },
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
      theme: AppTheme.light(),
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
          padding: const EdgeInsets.all(Space.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This build is misconfigured', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Space.m),
              SelectableText(message),
            ],
          ),
        ),
      ),
    );
  }
}
