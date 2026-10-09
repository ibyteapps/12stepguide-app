import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/config/ad_units.dart';
import '../../core/logging/log.dart';
import '../../core/prefs/key_value_store.dart';
import '../premium/entitlement_controller.dart';
import '../premium/purchase_service.dart';
import 'ad_gateway.dart';
import 'ad_policy.dart';
import 'consent_controller.dart';

final adGatewayProvider = Provider<AdGateway>((ref) => const NoAds());

/// The ad unit ids of this build (test units outside prod). Empty in tests.
final adUnitsProvider = Provider<AdUnits>((ref) => const AdUnits());

/// Applies `AdPolicy` around content opens and app returns, and keeps the persisted counters
/// (UNIFIED_PRODUCT_SPEC §2.4).
class AdCoordinator {
  AdCoordinator(this._ref);

  final Ref _ref;
  AppLifecycleListener? _lifecycle;
  DateTime? _lastInterstitialAt;

  /// A stuck advert never holds navigation for longer than this.
  static const showTimeout = Duration(minutes: 2);

  AdGateway get _gateway => _ref.read(adGatewayProvider);
  KeyValueStore get _store => _ref.read(kvStoreProvider);
  DateTime _now() => _ref.read(clockProvider)();

  bool get _eligible => !_ref.read(isPremiumProvider) && _ref.read(consentProvider).canRequestAds;

  AdFacts _facts({bool audioPlaying = false}) => AdFacts(
    premium: _ref.read(isPremiumProvider),
    canRequestAds: _ref.read(consentProvider).canRequestAds,
    launchCount: _ref.read(launchInfoProvider).launchCount,
    now: _now(),
    audioPlaying: audioPlaying,
    purchaseInProgress:
        _ref.exists(purchaseServiceProvider) && _ref.read(purchaseServiceProvider).busy,
    location: _ref.read(currentLocationProvider)(),
  );

  /// Starts the advert SDK after consent, and the app-open check on every return to the app.
  Future<void> start() async {
    if (!_eligible) return;
    try {
      await _gateway.start();
    } on Object catch (error, stack) {
      Log.e('Advert SDK failed to start', error, stack);
      return;
    }
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(maybeShowAppOpen()));
  }

  void dispose() => _lifecycle?.dispose();

  /// Called before a document opens or a track starts. Counts the open and shows an
  /// interstitial on every 3rd, if one is loaded; never waits for one to load.
  Future<void> beforeContentOpen({bool audioPlaying = false}) async {
    if (!_eligible) return;
    final count = _store.getInt(PrefKeys.contentOpenCount) ?? 0;
    final decision = AdPolicy.onContentOpen(_facts(audioPlaying: audioPlaying), count);
    var next = decision.count;
    if (decision.show && _gateway.interstitialReady) {
      final shown = await _gateway.showInterstitial().timeout(showTimeout, onTimeout: () => true);
      if (shown) {
        next = AdPolicy.resetCount;
        _lastInterstitialAt = _now();
      }
    }
    await _store.setInt(PrefKeys.contentOpenCount, next);
  }

  /// On returning to the app (never on a cold start).
  Future<void> maybeShowAppOpen() async {
    if (!_eligible) return;
    _gateway.dropStaleAppOpen(AdPolicy.appOpenMaxAge);
    final saved = _store.getInt(PrefKeys.lastAppOpenAt);
    var last = saved == null ? null : DateTime.fromMillisecondsSinceEpoch(saved);
    // Coming back from an interstitial's link counts as a recent advert too.
    if (_lastInterstitialAt != null && (last == null || _lastInterstitialAt!.isAfter(last))) {
      last = _lastInterstitialAt;
    }
    final facts = _facts();
    if (!AdPolicy.mayShowAppOpen(facts, lastShownAt: last, loadedAt: _gateway.appOpenLoadedAt)) {
      return;
    }
    final shown = await _gateway.showAppOpen().timeout(showTimeout, onTimeout: () => true);
    if (shown) {
      await _store.setInt(PrefKeys.lastAppOpenAt, facts.now.millisecondsSinceEpoch);
      await _store.setInt(PrefKeys.contentOpenCount, AdPolicy.resetCount);
    }
  }
}

final adCoordinatorProvider = Provider<AdCoordinator>((ref) {
  final coordinator = AdCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
