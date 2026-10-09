import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/config/app_config.dart';
import '../core/logging/log.dart';
import '../core/platform/legacy_bridge.dart';
import '../core/prefs/key_value_store.dart';
import '../features/audio/domain/catalogue.dart';
import '../features/content/domain/content_index.dart';
import '../features/migration/migration.dart';
import 'app.dart';
import 'providers.dart';
import 'router.dart';
import 'routes.dart';

/// Starts the app (FLUTTER_ARCHITECTURE.md §4): error handlers, configuration, storage, bundled
/// data, the legacy migration, then the first screen. The native splash stays up meanwhile.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Log.e('Flutter error: ${details.exceptionAsString()}', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Log.e('Uncaught error', error, stack);
    return true;
  };

  final AppConfig config;
  try {
    config = AppConfig.fromBuild();
  } on ConfigException catch (error) {
    // A misbuilt binary says why on screen instead of running with the wrong ids or ads.
    runApp(ConfigErrorApp(message: error.message));
    return;
  }

  final store = await SharedPrefsStore.create();
  final results = await Future.wait([
    rootBundle.loadString('assets/content_index.json'),
    rootBundle.loadString('assets/audio/catalogue.json'),
    rootBundle.loadString('assets/quotes.txt'),
    PackageInfo.fromPlatform(),
  ]);
  final index = ContentIndex.fromJsonString(results[0] as String);
  final catalogue = Catalogue.fromJsonString(results[1] as String);
  final quotes = (results[2] as String)
      .split('\n')
      .map((q) => q.trim())
      .where((q) => q.isNotEmpty)
      .toList();
  final package = results[3] as PackageInfo;

  final launch = await prepareLaunch(store: store, bridge: const MethodChannelLegacyBridge());
  final router = buildRouter(initialLocation: initialLocation(store));

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        kvStoreProvider.overrideWithValue(store),
        contentIndexProvider.overrideWithValue(index),
        catalogueProvider.overrideWithValue(catalogue),
        quotesProvider.overrideWithValue(quotes),
        launchInfoProvider.overrideWithValue(
          LaunchInfo(
            launchCount: launch.launchCount,
            isFirstLaunch: launch.launchCount == 1,
            isUpgrade: launch.isUpgrade,
            version: package.version,
            buildNumber: package.buildNumber,
          ),
        ),
      ],
      child: TwelveStepGuideApp(router: router),
    ),
  );
}

/// The steps the migration runs, in order (MIGRATION_PLAN §3).
List<MigrationStep> migrationSteps() => const [
  LaunchAndOnboardingStep(),
  SobrietyDateStep(),
  TextSizeStep(),
  PremiumStep(),
  AdPacingStep(),
  ReviewStep(),
  CoachMarkStep(),
];

/// Runs the migration (on iOS and Android only) and counts this launch.
Future<({int launchCount, bool isUpgrade})> prepareLaunch({
  required KeyValueStore store,
  required LegacyBridge bridge,
  DateTime Function() clock = DateTime.now,
  List<MigrationStep>? steps,
}) async {
  var isUpgrade = false;
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.iOS => LegacyPlatform.ios,
    TargetPlatform.android => LegacyPlatform.android,
    _ => null,
  };
  if (platform != null && !kIsWeb) {
    try {
      final outcome = await MigrationRunner(
        store: store,
        bridge: bridge,
        platform: platform,
        steps: steps ?? migrationSteps(),
        now: clock(),
      ).run();
      isUpgrade = outcome.isUpgrade;
    } on Object catch (error, stack) {
      // The app always starts; failed steps retry next launch (UNIFIED_PRODUCT_SPEC S-01).
      Log.e('Migration failed', error, stack);
    }
  }
  final count = (store.getInt(PrefKeys.launchCount) ?? 0) + 1;
  await store.setInt(PrefKeys.launchCount, count);
  if (!store.containsKey(PrefKeys.firstLaunchAt)) {
    await store.setString(PrefKeys.firstLaunchAt, clock().toIso8601String());
  }
  await store.setString(PrefKeys.lastOpenedAt, clock().toIso8601String());
  return (launchCount: count, isUpgrade: isUpgrade);
}

/// Onboarding until it is done, Welcome back once after an upgrade, otherwise the last tab.
String initialLocation(KeyValueStore store) {
  if (!(store.getBool(PrefKeys.onboardingDone) ?? false)) return Routes.onboarding;
  if (store.getBool(PrefKeys.welcomeBackPending) ?? false) return Routes.welcomeBack;
  final tab = store.getInt(PrefKeys.lastTab) ?? 0;
  return Routes.tabs[tab.clamp(0, Routes.tabs.length - 1)];
}
