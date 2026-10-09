import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/appearance/appearance_screen.dart';
import '../features/audio/presentation/album_screen.dart';
import '../features/audio/presentation/audio_screen.dart';
import '../features/audio/presentation/downloads_screen.dart';
import '../features/audio/presentation/player_screen.dart';
import '../features/big_book/big_book_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/welcome_back_screen.dart';
import '../features/premium/paywall_screen.dart';
import '../features/premium/premium_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/readings/readings_screen.dart';
import '../features/reminders/quote_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/shell_scaffold_key.dart';
import '../features/sobriety/recovery_date_screen.dart';
import '../features/steps/steps_screen.dart';
import '../features/support/about_screen.dart';
import '../features/support/other_apps_screen.dart';
import 'routes.dart';

/// The route table (FLUTTER_ARCHITECTURE.md §6): four tab branches with their own back stacks,
/// and everything else pushed over the shell on the root navigator.
GoRouter buildRouter({required String initialLocation, List<NavigatorObserver>? observers}) {
  GoRoute root(String path, Widget Function(GoRouterState s) build, {bool dialog = false}) =>
      GoRoute(
        path: path,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => dialog
            ? MaterialPage(fullscreenDialog: true, key: state.pageKey, child: build(state))
            : MaterialPage(key: state.pageKey, child: build(state)),
      );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    observers: observers,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.steps, builder: (_, _) => const StepsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.readings, builder: (_, _) => const ReadingsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.bigBook, builder: (_, _) => const BigBookScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.audio,
                builder: (_, _) => const AudioScreen(),
                routes: [
                  GoRoute(
                    path: 'album/:albumId',
                    builder: (_, s) =>
                        AlbumScreen(albumId: int.parse(s.pathParameters['albumId']!)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      root(Routes.readPath, (s) => ReaderScreen(docId: s.uri.queryParameters['id'] ?? '')),
      root(Routes.onboarding, (_) => const OnboardingScreen()),
      root(Routes.welcomeBack, (_) => const WelcomeBackScreen()),
      root(Routes.recoveryDate, (_) => const RecoveryDateScreen()),
      root(Routes.player, (_) => const PlayerScreen(), dialog: true),
      root(Routes.premium, (_) => const PremiumScreen()),
      root(Routes.paywall, (_) => const PaywallScreen(), dialog: true),
      root(Routes.reminders, (_) => const RemindersScreen()),
      root(Routes.appearance, (_) => const AppearanceScreen()),
      root(Routes.downloads, (_) => const DownloadsScreen()),
      root(Routes.otherApps, (_) => const OtherAppsScreen()),
      root(Routes.about, (_) => const AboutScreen()),
      root(Routes.quote, (_) => const QuoteScreen(), dialog: true),
    ],
  );
}
