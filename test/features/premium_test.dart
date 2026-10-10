// Purchases and entitlement (MIGRATION_PLAN §5, F-070–F-079b), the paywall cadence (A-25) and
// the Premium page and paywall (S-51).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart' show PurchaseStatus;
import 'package:twelve_step_guide/app/providers.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/features/premium/entitlement.dart';
import 'package:twelve_step_guide/features/premium/entitlement_controller.dart';
import 'package:twelve_step_guide/features/premium/offers.dart';
import 'package:twelve_step_guide/features/premium/purchase_gateway.dart';
import 'package:twelve_step_guide/features/premium/purchase_service.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

final now = DateTime(2026, 10, 9, 10);

class _Shop {
  _Shop({Map<String, Object> prefs = const {}, bool ios = false, FakePurchaseGateway? gateway})
    : store = MemoryStore({...prefs}),
      gateway = gateway ?? FakePurchaseGateway() {
    container = ProviderContainer(
      overrides: [
        kvStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => now),
        purchaseGatewayProvider.overrideWithValue(this.gateway),
        purchaseSettleDelayProvider.overrideWithValue(Duration.zero),
        isIOSStoreProvider.overrideWithValue(ios),
      ],
    );
    addTearDown(container.dispose);
  }

  final MemoryStore store;
  final FakePurchaseGateway gateway;
  late final ProviderContainer container;

  PurchaseService get service => container.read(purchaseServiceProvider.notifier);
  PurchaseState get state => container.read(purchaseServiceProvider);
  Entitlement get entitlement => container.read(entitlementProvider);

  /// Starts the service as the app does and lets the launch check finish.
  Future<void> start() async {
    container
      ..listen(purchaseServiceProvider, (_, _) {})
      ..listen(entitlementProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

PurchaseEvent restored(String id, {DateTime? expires}) =>
    PurchaseEvent(id, PurchaseEventKind.restored, expiresAt: expires);

void main() {
  group('the launch check', () {
    test('nothing owned: free, and a stale cached subscription ends', () async {
      final shop = _Shop(
        prefs: {PrefKeys.premiumCache: '{"annual":true,"until":"2027-01-01T00:00:00.000"}'},
      );
      expect(shop.entitlement.kind, PremiumKind.annual, reason: 'cache bridges the start');
      await shop.start();
      expect(shop.entitlement.kind, PremiumKind.none);
      expect(shop.state.status, StoreStatus.ready);
    });

    test('an active annual subscription (StoreKit 2 current entitlements)', () async {
      final until = now.add(const Duration(days: 200));
      final shop = _Shop(
        ios: true,
        gateway: FakePurchaseGateway(owned: [restored(ProductIds.annual, expires: until)]),
      );
      await shop.start();
      expect(shop.entitlement.kind, PremiumKind.annual);
      expect(shop.entitlement.renewsAt, until);
      expect(shop.state.products.single.id, ProductIds.annual);
      expect(shop.state.trialEligible, isTrue);
    });

    test('a subscription in billing grace keeps Premium (StoreKit 2 still lists it)', () async {
      final shop = _Shop(
        ios: true,
        gateway: FakePurchaseGateway(
          owned: [restored(ProductIds.annual, expires: now.subtract(const Duration(days: 2)))],
        ),
      );
      await shop.start();
      expect(shop.entitlement.kind, PremiumKind.annual);
      expect(shop.entitlement.renewsAt, isNull, reason: 'no renewal date to show while in grace');
    });

    test('a Play purchase waiting for payment is pending, not owned', () {
      expect(eventKindFor(PurchaseStatus.restored, playPending: true), PurchaseEventKind.pending);
      expect(eventKindFor(PurchaseStatus.purchased, playPending: true), PurchaseEventKind.pending);
      expect(eventKindFor(PurchaseStatus.restored), PurchaseEventKind.restored);
      expect(eventKindFor(PurchaseStatus.canceled, playPending: true), PurchaseEventKind.canceled);
    });

    test('an old iOS tip restores lifetime Premium', () async {
      final shop = _Shop(
        ios: true,
        gateway: FakePurchaseGateway(owned: [restored('com.ibyteapps.aa12stepguide.donatetier10')]),
      );
      await shop.start();
      expect(shop.entitlement.kind, PremiumKind.lifetime);
      expect(shop.entitlement.lifetimeSource, LifetimeSource.store);
    });

    test('an Android donation kept by Play (not consumed, A-04) and the promo product', () async {
      for (final id in ['donatetier2', ProductIds.androidPromo]) {
        final shop = _Shop(gateway: FakePurchaseGateway(owned: [restored(id)]));
        await shop.start();
        expect(shop.entitlement.kind, PremiumKind.lifetime, reason: id);
      }
    });

    test('the legacy lifetime flag is never cleared by the store', () async {
      final shop = _Shop(
        prefs: {PrefKeys.legacyLifetime: true, PrefKeys.legacySource: 'android-donation'},
      );
      await shop.start();
      expect(shop.entitlement.kind, PremiumKind.lifetime);
      expect(shop.entitlement.lifetimeSource, LifetimeSource.androidDonation);
    });

    test('a subscriber who also donated sees the legacy-supporter note', () async {
      final shop = _Shop(
        ios: true,
        prefs: {PrefKeys.legacyLifetime: true, PrefKeys.legacySource: 'ios-donation'},
        gateway: FakePurchaseGateway(
          owned: [restored(ProductIds.annual, expires: now.add(const Duration(days: 3)))],
        ),
      );
      await shop.start();
      expect(shop.entitlement.kind, PremiumKind.annual);
      expect(shop.entitlement.alsoLegacySupporter, isTrue);
    });

    test('store unreachable: the cached answer stands', () async {
      final shop = _Shop(
        prefs: {PrefKeys.premiumCache: '{"lifetime":true}'},
        gateway: FakePurchaseGateway()..failRefresh = true,
      );
      await shop.start();
      expect(shop.entitlement.kind, PremiumKind.lifetime);
    });

    test('purchases unavailable: the page says so', () async {
      final shop = _Shop(gateway: FakePurchaseGateway(available: false));
      await shop.start();
      expect(shop.state.status, StoreStatus.unavailable);
    });

    test('Android sells the three tiers in price order', () async {
      final shop = _Shop();
      await shop.start();
      expect(shop.state.products.map((p) => p.id), ProductIds.androidTiers);
      expect(shop.container.read(headlineOfferProvider), 'from £1.99');
    });
  });

  group('buying', () {
    test('success: Premium at once, transaction completed, thank-you shown', () async {
      final shop = _Shop();
      await shop.start();
      await shop.service.buy(shop.state.products.first);
      expect(shop.state.busy, isTrue);
      shop.gateway.emit([
        const PurchaseEvent('donatetier1', PurchaseEventKind.purchased, needsCompletion: true),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(shop.entitlement.kind, PremiumKind.lifetime);
      expect(shop.gateway.completed, ['donatetier1']);
      expect(shop.state.feedback, PurchaseFeedback.success);
      expect(shop.state.busy, isFalse);
      expect(shop.store.getString(PrefKeys.premiumCache), contains('"lifetime":true'));
    });

    test('pending (Android): no Premium yet, the page explains (BUG-26)', () async {
      final shop = _Shop();
      await shop.start();
      shop.gateway.emit([const PurchaseEvent('donatetier1', PurchaseEventKind.pending)]);
      await Future<void>.delayed(Duration.zero);
      expect(shop.entitlement.isPremium, isFalse);
      expect(shop.entitlement.pending, isTrue);
      expect(shop.state.feedback, PurchaseFeedback.pending);
    });

    test('cancelled: no message; error: the store message', () async {
      final shop = _Shop();
      await shop.start();
      shop.gateway.emit([const PurchaseEvent('donatetier1', PurchaseEventKind.canceled)]);
      await Future<void>.delayed(Duration.zero);
      expect(shop.state.feedback, PurchaseFeedback.none);
      shop.gateway.emit([
        const PurchaseEvent('donatetier1', PurchaseEventKind.error, message: 'Card declined'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(shop.state.feedback, PurchaseFeedback.error);
      expect(shop.state.errorMessage, 'Card declined');
    });
  });

  group('restore (F-079)', () {
    test('finds a purchase', () async {
      final gateway = FakePurchaseGateway();
      final shop = _Shop(gateway: gateway);
      await shop.start();
      gateway.owned = [restored('donatetier3')];
      await shop.service.restore();
      expect(gateway.restores, 1);
      expect(shop.entitlement.kind, PremiumKind.lifetime);
      expect(shop.state.feedback, PurchaseFeedback.restored);
    });

    test('finds nothing', () async {
      final shop = _Shop();
      await shop.start();
      await shop.service.restore();
      expect(shop.state.feedback, PurchaseFeedback.nothingToRestore);
    });
  });

  group('paywall cadence (A-25)', () {
    test('launch 2, 20 and 50 only, once each, never for Premium', () {
      final store = MemoryStore();
      final shows = [
        for (var launch = 1; launch <= 60; launch++)
          if (PaywallCadence.shouldShow(launchCount: launch, premium: false, store: store)) launch,
      ];
      expect(shows, [2, 20, 50]);
      expect(PaywallCadence.shouldShow(launchCount: 2, premium: true, store: store), isFalse);
    });

    test('remembered once shown', () async {
      final store = MemoryStore();
      await PaywallCadence.markShown(store, 20);
      expect(PaywallCadence.shouldShow(launchCount: 20, premium: false, store: store), isFalse);
    });
  });

  group('screens', () {
    testWidgets('free user (Android): benefits, the three tiers, restore and legal links', (
      tester,
    ) async {
      final app = await pumpApp(tester, location: '/premium');
      expect(find.text('12 Step Guide Premium'), findsOneWidget);
      expect(find.text('No adverts'), findsOneWidget);
      expect(find.textContaining('138 recordings'), findsOneWidget);
      expect(find.text('Support the app — lifetime Premium'), findsOneWidget);
      await tester.ensureVisible(find.text('Give £4.99'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Give £4.99'));
      await tester.pump();
      expect(app.purchases.bought, ['donatetier2']);
      await tester.ensureVisible(find.text('Lost your supporter status?'));
      await tester.pumpAndSettle();
      expect(find.text('Restore purchases'), findsOneWidget);
      await tester.tap(find.text('Lost your supporter status?'));
      await tester.pumpAndSettle();
      expect(app.links.emails.single.subject, 'Supporter status');
      expect(app.links.emails.single.body, contains('GPA.'));
    });

    testWidgets('lifetime supporter sees the status, not the offer', (tester) async {
      await pumpApp(
        tester,
        location: '/premium',
        prefs: {PrefKeys.legacyLifetime: true, PrefKeys.legacySource: 'android-donation'},
      );
      expect(find.text('Lifetime supporter'), findsOneWidget);
      expect(find.text('Give £1.99'), findsNothing);
      expect(find.text('Manage subscription'), findsNothing);
    });

    testWidgets('the paywall shows itself on launch 2 and closes', (tester) async {
      final app = await pumpApp(tester, launchCount: 2);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Go Premium'), findsOneWidget);
      expect(app.store.getStringList(PrefKeys.paywallShownAtLaunches), ['2']);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Go Premium'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('no paywall on launch 2 when the store cannot sell', (tester) async {
      await pumpApp(tester, launchCount: 2, purchases: FakePurchaseGateway(available: false));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Go Premium'), findsNothing);
    });
  });
}
