import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../../core/logging/log.dart';

/// Product ids (FLUTTER_ARCHITECTURE §0 — fixed; existing purchases depend on them).
abstract final class ProductIds {
  /// iOS auto-renewing subscription with a 7-day free trial (A-06: iOS only in 2.0).
  static const annual = 'annual';

  /// Old iOS tips: no longer sold, still restored as lifetime Premium.
  static const iosLegacyTiers = {
    'com.ibyteapps.aa12stepguide.donatetier5',
    'com.ibyteapps.aa12stepguide.donatetier10',
    'com.ibyteapps.aa12stepguide.donatetier20',
  };

  /// Android "Support the app — lifetime Premium", in price order. Not consumed (A-04).
  static const androidTiers = ['donatetier1', 'donatetier2', 'donatetier3'];

  /// A hidden Play product for promo codes to donors who lost their status (A-04). Recognised if
  /// the owner creates it; never sold.
  static const androidPromo = 'supporter_lifetime';

  static const lifetime = {...iosLegacyTiers, ...androidTiers, androidPromo};

  /// What each store is asked about.
  static Set<String> queried({required bool isIOS}) =>
      isIOS ? {annual} : {...androidTiers, androidPromo};

  /// What the Premium page sells.
  static List<String> forSale({required bool isIOS}) => isIOS ? const [annual] : androidTiers;
}

/// A product as the store prices it for this user.
@immutable
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.price,
    this.rawPrice = 0,
    this.currencyCode = '',
    this.details,
  });

  final String id;
  final String title;

  /// Localised, e.g. "£16.99".
  final String price;
  final double rawPrice;
  final String currencyCode;

  /// The plugin's object, needed to buy. Null in tests.
  final ProductDetails? details;
}

enum PurchaseEventKind { purchased, restored, pending, canceled, error }

/// One update from the store's purchase stream.
@immutable
class PurchaseEvent {
  const PurchaseEvent(
    this.productId,
    this.kind, {
    this.expiresAt,
    this.message,
    this.needsCompletion = false,
    this.raw,
  });

  final String productId;
  final PurchaseEventKind kind;

  /// Subscriptions: the end of the current period (StoreKit 2).
  final DateTime? expiresAt;

  /// Store error text, for the error state.
  final String? message;

  /// The transaction must be finished (iOS) or acknowledged (Android), or the store refunds it.
  final bool needsCompletion;
  final PurchaseDetails? raw;
}

/// The store behind one interface (FLUTTER_ARCHITECTURE §10.3), so the purchase logic is tested
/// with a fake.
abstract interface class PurchaseGateway {
  Stream<List<PurchaseEvent>> get events;
  Future<bool> isAvailable();
  Future<List<StoreProduct>> products(Set<String> ids);
  Future<void> buy(StoreProduct product);

  /// Asks the store what the user owns now, without any sign-in prompt; the answers arrive on
  /// [events] as `restored` before this completes. iOS: StoreKit 2 current entitlements.
  /// Android: Play's owned purchases.
  Future<void> refreshOwned();

  /// The "Restore purchases" button: on iOS it first syncs with the App Store (which may ask the
  /// user to sign in), then refreshes.
  Future<void> restore();
  Future<void> complete(PurchaseEvent event);

  /// iOS: whether the subscription's free trial is still open to this Apple account.
  Future<bool> isTrialEligible(String productId);
}

class InAppPurchaseGateway implements PurchaseGateway {
  InAppPurchaseGateway({required this.isIOS});

  final bool isIOS;
  final _iap = InAppPurchase.instance;

  @override
  late final Stream<List<PurchaseEvent>> events = _iap.purchaseStream
      .map((list) => [for (final p in list) _event(p)])
      .asBroadcastStream();

  PurchaseEvent _event(PurchaseDetails p) {
    final kind = switch (p.status) {
      PurchaseStatus.purchased => PurchaseEventKind.purchased,
      PurchaseStatus.restored => PurchaseEventKind.restored,
      PurchaseStatus.pending => PurchaseEventKind.pending,
      PurchaseStatus.canceled => PurchaseEventKind.canceled,
      PurchaseStatus.error => PurchaseEventKind.error,
    };
    DateTime? expires;
    if (p is SK2PurchaseDetails) {
      final ms = int.tryParse(p.expirationDate ?? '');
      if (ms != null) expires = DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return PurchaseEvent(
      p.productID,
      kind,
      expiresAt: expires,
      message: p.error?.message,
      needsCompletion: p.pendingCompletePurchase,
      raw: p,
    );
  }

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async {
    final response = await _iap.queryProductDetails(ids);
    if (response.error != null) {
      Log.w('Store product query failed: ${response.error!.code}');
    }
    return [
      for (final p in response.productDetails)
        StoreProduct(
          id: p.id,
          title: p.title,
          price: p.price,
          rawPrice: p.rawPrice,
          currencyCode: p.currencyCode,
          details: p,
        ),
    ];
  }

  @override
  Future<void> buy(StoreProduct product) async {
    // Subscriptions and lifetime products are both "non-consumable" to the plugin; on Android
    // that means the purchase is acknowledged and kept, never consumed (A-04).
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product.details!));
  }

  @override
  Future<void> refreshOwned() => _iap.restorePurchases();

  @override
  Future<void> restore() async {
    if (isIOS) {
      try {
        await AppStore().sync();
      } on Object catch (error) {
        // Cancelled sign-in or offline: still report what StoreKit already knows.
        Log.w('App Store sync failed: ${error.runtimeType}');
      }
    }
    await refreshOwned();
  }

  @override
  Future<void> complete(PurchaseEvent event) async {
    final raw = event.raw;
    if (raw != null && raw.pendingCompletePurchase) await _iap.completePurchase(raw);
  }

  @override
  Future<bool> isTrialEligible(String productId) async {
    if (!isIOS) return false;
    final platform = InAppPurchasePlatform.instance;
    if (platform is! InAppPurchaseStoreKitPlatform) return false;
    try {
      return await platform.isIntroductoryOfferEligible(productId);
    } on Object {
      return false;
    }
  }
}
