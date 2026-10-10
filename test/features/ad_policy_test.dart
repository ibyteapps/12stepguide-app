// AdPolicy (UNIFIED_PRODUCT_SPEC §2.4, A-10) and the coordinator that applies it.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/app/providers.dart';
import 'package:twelve_step_guide/app/routes.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/features/ads/ad_coordinator.dart';
import 'package:twelve_step_guide/features/ads/ad_policy.dart';
import 'package:twelve_step_guide/features/ads/consent_controller.dart';

import '../helpers/fakes.dart';

final now = DateTime(2026, 10, 9, 10);

AdFacts facts({
  bool premium = false,
  bool canRequestAds = true,
  int launchCount = 5,
  bool audioPlaying = false,
  bool purchaseInProgress = false,
  String location = '/steps',
}) => AdFacts(
  premium: premium,
  canRequestAds: canRequestAds,
  launchCount: launchCount,
  now: now,
  audioPlaying: audioPlaying,
  purchaseInProgress: purchaseInProgress,
  location: location,
);

void main() {
  group('interstitials: every 3rd content open', () {
    test('opens 1 and 2 count, the 3rd shows', () {
      var count = 0;
      final shows = <bool>[];
      for (var i = 0; i < 3; i++) {
        final d = AdPolicy.onContentOpen(facts(), count);
        count = d.count;
        shows.add(d.show);
      }
      expect(shows, [false, false, true]);
    });

    test('counted across sessions: a saved count of 2 shows on the next open', () {
      expect(AdPolicy.onContentOpen(facts(), 2).show, isTrue);
    });

    test('an ad that was not ready leaves the count, so the next open shows', () {
      expect(AdPolicy.onContentOpen(facts(), 3), (count: 4, show: true));
    });

    test('never for Premium users, and the counter does not move', () {
      expect(AdPolicy.onContentOpen(facts(premium: true), 2), (count: 2, show: false));
    });

    test('never before consent allows ads (A-11)', () {
      expect(AdPolicy.onContentOpen(facts(canRequestAds: false), 2), (count: 2, show: false));
    });

    test('never on the first launch, but the open still counts', () {
      expect(AdPolicy.onContentOpen(facts(launchCount: 1), 2), (count: 3, show: false));
    });

    test('never while audio plays', () {
      expect(AdPolicy.onContentOpen(facts(audioPlaying: true), 2), (count: 3, show: false));
    });
  });

  group('app-open adverts', () {
    final loaded = now.subtract(const Duration(minutes: 5));

    test('allowed when every rule is met', () {
      expect(AdPolicy.mayShowAppOpen(facts(), loadedAt: loaded), isTrue);
    });

    test('at least 45 s apart', () {
      final recent = now.subtract(const Duration(seconds: 44));
      final older = now.subtract(const Duration(seconds: 45));
      expect(AdPolicy.mayShowAppOpen(facts(), lastShownAt: recent, loadedAt: loaded), isFalse);
      expect(AdPolicy.mayShowAppOpen(facts(), lastShownAt: older, loadedAt: loaded), isTrue);
    });

    test('a loaded advert older than 4 hours is stale', () {
      final stale = now.subtract(const Duration(hours: 4));
      expect(AdPolicy.mayShowAppOpen(facts(), loadedAt: stale), isFalse);
      expect(AdPolicy.mayShowAppOpen(facts()), isFalse, reason: 'nothing loaded');
    });

    test('never over onboarding, welcome back, paywall, Premium, the player or a quote', () {
      for (final route in [
        Routes.onboarding,
        Routes.welcomeBack,
        Routes.paywall,
        Routes.premium,
        Routes.player,
        Routes.quote,
      ]) {
        expect(
          AdPolicy.mayShowAppOpen(facts(location: route), loadedAt: loaded),
          isFalse,
          reason: route,
        );
      }
    });

    test('never on the first launch, during a purchase, for Premium or without consent', () {
      for (final f in [
        facts(launchCount: 1),
        facts(purchaseInProgress: true),
        facts(premium: true),
        facts(canRequestAds: false),
      ]) {
        expect(AdPolicy.mayShowAppOpen(f, loadedAt: loaded), isFalse);
      }
    });
  });

  group('banners', () {
    test('free users with consent only', () {
      expect(AdPolicy.mayShowBanner(facts()), isTrue);
      expect(AdPolicy.mayShowBanner(facts(premium: true)), isFalse);
      expect(AdPolicy.mayShowBanner(facts(canRequestAds: false)), isFalse);
    });
  });

  group('AdCoordinator', () {
    setUp(() => AdCoordinator.resumeSettle = Duration.zero);

    ({ProviderContainer container, MemoryStore store, FakeAdGateway ads}) setUpCoordinator({
      Map<String, Object> prefs = const {},
      bool consent = true,
      int launchCount = 5,
      String location = '/steps',
    }) {
      final store = MemoryStore({...prefs});
      final ads = FakeAdGateway()..appOpenLoaded = now.subtract(const Duration(minutes: 1));
      final container = ProviderContainer(
        overrides: [
          kvStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => now),
          adGatewayProvider.overrideWithValue(ads),
          consentGatewayProvider.overrideWithValue(NoConsent(allowAds: consent)),
          currentLocationProvider.overrideWithValue(() => location),
          launchInfoProvider.overrideWithValue(
            LaunchInfo(
              launchCount: launchCount,
              isFirstLaunch: launchCount == 1,
              isUpgrade: false,
              version: '2.0.0',
              buildNumber: '100',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, store: store, ads: ads);
    }

    test('shows on the 3rd open, resets, and persists the count', () async {
      final t = setUpCoordinator();
      await t.container.read(consentProvider.notifier).gather();
      final c = t.container.read(adCoordinatorProvider);
      await c.beforeContentOpen();
      await c.beforeContentOpen();
      expect(t.ads.shown, isEmpty);
      expect(t.store.getInt(PrefKeys.contentOpenCount), 2);
      await c.beforeContentOpen();
      expect(t.ads.shown, ['interstitial']);
      expect(t.store.getInt(PrefKeys.contentOpenCount), 0);
    });

    test('nothing before consent is resolved', () async {
      final t = setUpCoordinator(prefs: {PrefKeys.contentOpenCount: 2});
      await t.container.read(adCoordinatorProvider).beforeContentOpen();
      expect(t.ads.shown, isEmpty);
      expect(t.store.getInt(PrefKeys.contentOpenCount), 2);
    });

    test('Premium users never see one (legacy lifetime flag)', () async {
      final t = setUpCoordinator(
        prefs: {
          PrefKeys.contentOpenCount: 2,
          PrefKeys.legacyLifetime: true,
          PrefKeys.legacySource: 'android-donation',
        },
      );
      await t.container.read(consentProvider.notifier).gather();
      await t.container.read(adCoordinatorProvider).beforeContentOpen();
      expect(t.ads.shown, isEmpty);
    });

    test('app-open: shows, records the time and restarts the content counter', () async {
      final t = setUpCoordinator(prefs: {PrefKeys.contentOpenCount: 2});
      await t.container.read(consentProvider.notifier).gather();
      await t.container.read(adCoordinatorProvider).maybeShowAppOpen();
      expect(t.ads.shown, ['appOpen']);
      expect(t.store.getInt(PrefKeys.lastAppOpenAt), now.millisecondsSinceEpoch);
      expect(t.store.getInt(PrefKeys.contentOpenCount), 0);
      // A second return straight away is too soon.
      await t.container.read(adCoordinatorProvider).maybeShowAppOpen();
      expect(t.ads.shown, ['appOpen']);
    });

    test('app-open: the migrated iOS timestamp is honoured (m005)', () async {
      final t = setUpCoordinator(
        prefs: {
          PrefKeys.lastAppOpenAt: now.subtract(const Duration(seconds: 20)).millisecondsSinceEpoch,
        },
      );
      await t.container.read(consentProvider.notifier).gather();
      await t.container.read(adCoordinatorProvider).maybeShowAppOpen();
      expect(t.ads.shown, isEmpty);
    });

    test('app-open: never over the full player', () async {
      final t = setUpCoordinator(location: Routes.player);
      await t.container.read(consentProvider.notifier).gather();
      await t.container.read(adCoordinatorProvider).maybeShowAppOpen();
      expect(t.ads.shown, isEmpty);
    });
  });
}
