import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config/ad_units.dart';
import '../core/config/app_config.dart';
import '../core/config/app_env.dart';
import '../core/logging/log.dart';
import '../core/platform/legacy_bridge.dart';
import '../core/prefs/key_value_store.dart';
import '../features/ads/ad_coordinator.dart';
import '../features/ads/ad_gateway.dart';
import '../features/ads/consent_controller.dart';
import '../features/audio/application/artwork.dart';
import '../features/audio/application/downloads_controller.dart';
import '../features/audio/application/player_controller.dart';
import '../features/audio/data/audio_engine.dart';
import '../features/audio/data/download_gateway.dart';
import '../features/audio/data/just_audio_handler.dart';
import '../features/audio/domain/catalogue.dart';
import '../features/content/domain/content_index.dart';
import '../features/migration/migration.dart';
import '../features/premium/entitlement_controller.dart';
import '../features/premium/purchase_gateway.dart';
import '../features/premium/purchase_service.dart';
import '../features/reminders/notifications_gateway.dart';
import '../features/reminders/reminder_schedule.dart';
import '../features/reminders/reminders_controller.dart';
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

  final launch = await prepareLaunch(
    store: store,
    bridge: const MethodChannelLegacyBridge(),
    steps: migrationSteps(catalogue),
  );
  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
  final audio = await startAudio();
  final start = initialLocation(store);
  final router = buildRouter(initialLocation: start);

  // Reminders: a tap while the app runs opens the quote; a tap that launched the app opens it
  // over the first screen (UJ-9, "even from a cold start").
  final notifications = LocalNotificationsGateway(isIOS: isIOS);
  String? launchPayload;
  try {
    await notifications.init(
      onTap: (payload) {
        if (payload == ReminderSchedule.quotePayload) router.push(Routes.quote);
      },
    );
    launchPayload = await notifications.launchPayload();
  } on Object catch (error, stack) {
    Log.e('Notifications failed to start', error, stack);
  }

  final units = AdUnits.forBuild(config.env, isIOS: isIOS);
  if (config.env == AppEnv.prod && !units.isComplete) {
    Log.w('Some AdMob units are missing from config/prod.json; those formats stay off.');
  }

  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      kvStoreProvider.overrideWithValue(store),
      contentIndexProvider.overrideWithValue(index),
      catalogueProvider.overrideWithValue(catalogue),
      quotesProvider.overrideWithValue(quotes),
      audioEngineProvider.overrideWithValue(audio.engine),
      audioFilesProvider.overrideWithValue(audio.files),
      downloadGatewayProvider.overrideWithValue(audio.downloads),
      artworkProvider.overrideWithValue(audio.artwork),
      purchaseGatewayProvider.overrideWithValue(InAppPurchaseGateway(isIOS: isIOS)),
      consentGatewayProvider.overrideWithValue(const UmpConsentGateway()),
      notificationsGatewayProvider.overrideWithValue(notifications),
      adUnitsProvider.overrideWithValue(units),
      adGatewayProvider.overrideWithValue(GoogleAdGateway(units)),
      currentLocationProvider.overrideWithValue(
        () => router.routerDelegate.currentConfiguration.uri.path,
      ),
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
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: TwelveStepGuideApp(router: router),
    ),
  );

  // After the first frame: the store check (Premium may change), then consent, then adverts.
  container.listen(purchaseServiceProvider, (_, _) {});
  unawaited(startAds(container));

  // Reminders are re-armed on every open ("we miss you" counts from the last one).
  final reminders = container.read(remindersProvider.notifier);
  unawaited(reminders.onAppOpen());
  AppLifecycleListener(onResume: () => unawaited(reminders.onAppOpen()));
  if (launchPayload == ReminderSchedule.quotePayload && start != Routes.onboarding) {
    WidgetsBinding.instance.addPostFrameCallback((_) => router.push(Routes.quote));
  }
}

/// Consent first (A-11), and the advert SDK only for free users who may see adverts.
Future<void> startAds(ProviderContainer container) async {
  await container.read(consentProvider.notifier).gather();
  if (container.read(consentProvider).canRequestAds && !container.read(isPremiumProvider)) {
    await container.read(adCoordinatorProvider).start();
  }
}

/// Background audio and downloads (FLUTTER_ARCHITECTURE §10.1, §10.2). Downloads live where the
/// native apps kept them: iOS `Documents/{file}` (so its downloads are reused in place) and
/// Android `filesDir/audio/{file}`.
Future<({AudioEngine engine, AudioFiles files, DownloadGateway downloads, ArtworkSource artwork})>
startAudio() async {
  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
  final dir = isIOS
      ? (await getApplicationDocumentsDirectory()).path
      : '${(await getApplicationSupportDirectory()).path}/audio';
  final cache = (await getApplicationCacheDirectory()).path;

  AudioEngine engine;
  try {
    engine = await JustAudioHandler.start();
  } on Object catch (error, stack) {
    // Without the media service, audio still plays while the app is open.
    Log.e('Audio service failed to start', error, stack);
    engine = JustAudioHandler();
  }

  final downloads = BackgroundDownloaderGateway(isIOS: isIOS);
  try {
    await downloads.start();
  } on Object catch (error, stack) {
    Log.e('Downloader failed to start', error, stack);
  }
  return (
    engine: engine,
    files: AudioFiles(dir),
    downloads: downloads,
    artwork: BundledArtwork('$cache/artwork') as ArtworkSource,
  );
}

/// The steps the migration runs, in order (MIGRATION_PLAN §3).
List<MigrationStep> migrationSteps(Catalogue catalogue) => [
  const LaunchAndOnboardingStep(),
  const SobrietyDateStep(),
  const TextSizeStep(),
  const PremiumStep(),
  const AdPacingStep(),
  const ReviewStep(),
  const RemindersStep(),
  DownloadsStep(catalogue),
  const CoachMarkStep(),
];

/// Runs the migration (on iOS and Android only) and counts this launch.
Future<({int launchCount, bool isUpgrade})> prepareLaunch({
  required KeyValueStore store,
  required LegacyBridge bridge,
  required List<MigrationStep> steps,
  DateTime Function() clock = DateTime.now,
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
        steps: steps,
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
