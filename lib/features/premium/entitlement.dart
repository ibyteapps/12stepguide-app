import 'package:flutter/foundation.dart';

/// What a user has (UNIFIED_PRODUCT_SPEC §2.1): Premium = no adverts + audio downloads.
enum PremiumKind { none, annual, lifetime }

/// Where a lifetime entitlement came from, shown on the Premium page.
enum LifetimeSource { none, iosDonation, androidDonation, store }

@immutable
class Entitlement {
  const Entitlement({
    this.kind = PremiumKind.none,
    this.renewsAt,
    this.inTrial = false,
    this.willRenew = true,
    this.lifetimeSource = LifetimeSource.none,
    this.alsoLegacySupporter = false,
    this.pending = false,
  });

  static const free = Entitlement();

  final PremiumKind kind;

  /// Annual only: the next renewal or expiry date, when the store reports it.
  final DateTime? renewsAt;
  final bool inTrial;
  final bool willRenew;
  final LifetimeSource lifetimeSource;

  /// A subscriber who also donated in the past ("You have also supported us…", S-51).
  final bool alsoLegacySupporter;

  /// Android: a purchase is waiting for payment; Premium is not granted yet (BUG-26).
  final bool pending;

  bool get isPremium => kind != PremiumKind.none;

  /// For analytics: the type only, never anything personal (FLUTTER_ARCHITECTURE §10.6).
  String get analyticsType => kind.name;

  Entitlement copyWith({bool? pending}) => Entitlement(
    kind: kind,
    renewsAt: renewsAt,
    inTrial: inTrial,
    willRenew: willRenew,
    lifetimeSource: lifetimeSource,
    alsoLegacySupporter: alsoLegacySupporter,
    pending: pending ?? this.pending,
  );

  @override
  bool operator ==(Object other) =>
      other is Entitlement &&
      other.kind == kind &&
      other.renewsAt == renewsAt &&
      other.inTrial == inTrial &&
      other.willRenew == willRenew &&
      other.lifetimeSource == lifetimeSource &&
      other.alsoLegacySupporter == alsoLegacySupporter &&
      other.pending == pending;

  @override
  int get hashCode =>
      Object.hash(kind, renewsAt, inTrial, willRenew, lifetimeSource, alsoLegacySupporter, pending);
}

/// Combines the store's answer with the flag migrated from the native app (MIGRATION_PLAN §5.3):
/// premium = legacyLifetime ∨ storeLifetime ∨ storeSubscriptionActive. A legacy flag is never
/// cleared; refunds remove only what the store granted.
Entitlement combineEntitlement({
  required LifetimeSource legacy,
  required bool storeLifetime,
  required bool subscriptionActive,
  DateTime? renewsAt,
  bool inTrial = false,
  bool willRenew = true,
  bool pending = false,
}) {
  if (subscriptionActive) {
    return Entitlement(
      kind: PremiumKind.annual,
      renewsAt: renewsAt,
      inTrial: inTrial,
      willRenew: willRenew,
      alsoLegacySupporter: legacy != LifetimeSource.none || storeLifetime,
      pending: pending,
    );
  }
  if (legacy != LifetimeSource.none) {
    return Entitlement(kind: PremiumKind.lifetime, lifetimeSource: legacy, pending: pending);
  }
  if (storeLifetime) {
    return Entitlement(
      kind: PremiumKind.lifetime,
      lifetimeSource: LifetimeSource.store,
      pending: pending,
    );
  }
  return Entitlement(pending: pending);
}
