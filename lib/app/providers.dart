import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/links/links.dart';
import '../core/platform/connectivity.dart';
import '../core/platform/legacy_bridge.dart';
import '../core/prefs/key_value_store.dart';
import '../core/telemetry/telemetry.dart';
import '../design/components/states.dart';
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

/// The app's snackbar host, for messages from code that has no `BuildContext`.
final messengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>(
  (ref) => GlobalKey<ScaffoldMessengerState>(debugLabel: 'messenger'),
);

/// Opens links on the device. Tests replace it.
final platformLinkOpenerProvider = Provider<LinkOpener>((ref) => const UrlLauncherOpener());

/// Opens links from every screen; offline, a web page shows "You're offline" instead (F-112).
final linkOpenerProvider = Provider<LinkOpener>(
  (ref) => OfflineAwareLinkOpener(
    inner: ref.watch(platformLinkOpenerProvider),
    isOffline: () => ref.read(isOfflineProvider),
    onOffline: () {
      final messenger = ref.read(messengerKeyProvider).currentState;
      if (messenger != null) showMessageOn(messenger, OfflineAwareLinkOpener.message);
    },
  ),
);

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
