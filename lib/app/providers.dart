import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/links/links.dart';
import '../core/platform/legacy_bridge.dart';
import '../core/prefs/key_value_store.dart';
import '../core/telemetry/telemetry.dart';
import '../features/audio/domain/catalogue.dart';
import '../features/content/domain/content_index.dart';

/// Cross-feature providers (FLUTTER_ARCHITECTURE.md §3). Values loaded at start-up are
/// overridden in `bootstrap`; tests override them with fakes.

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

final kvStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

final contentIndexProvider = Provider<ContentIndex>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

final catalogueProvider = Provider<Catalogue>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

/// The 61 hourly quotes (assets/quotes.txt).
final quotesProvider = Provider<List<String>>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

final linkOpenerProvider = Provider<LinkOpener>((ref) => const UrlLauncherOpener());

final legacyBridgeProvider = Provider<LegacyBridge>((ref) => const MethodChannelLegacyBridge());

/// The current time. Tests replace it to check day counts, cadences and schedules.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Facts about this launch, fixed for the session.
class LaunchInfo {
  const LaunchInfo({
    required this.launchCount,
    required this.isFirstLaunch,
    required this.isUpgrade,
    required this.version,
    required this.buildNumber,
  });

  /// 1 on the very first launch.
  final int launchCount;
  final bool isFirstLaunch;

  /// The native app's data was found on this device.
  final bool isUpgrade;
  final String version;
  final String buildNumber;
}

final launchInfoProvider = Provider<LaunchInfo>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

/// The current route path (e.g. `/player`), for rules that depend on the screen in front, such
/// as where an app-open advert may not appear. Bootstrap reads it from the router.
final currentLocationProvider = Provider<String Function()>(
  (ref) =>
      () => '',
);

/// Analytics and crash reporting; off unless bootstrap found Firebase values for this build.
final telemetryProvider = Provider<Telemetry>((ref) => const NoTelemetry());
