import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/prefs/key_value_store.dart';
import 'entitlement.dart';

/// The user's Premium status. Starts from what is known on the device (the legacy lifetime flag
/// migrated from the native app, and the last answer from the store), so there is no flash of
/// adverts while the store is asked. `PurchaseService` (premium/purchase_service.dart) replaces it
/// with the store's answer on every launch and purchase.
class EntitlementController extends Notifier<Entitlement> {
  @override
  Entitlement build() {
    final store = ref.watch(kvStoreProvider);
    final legacy = legacySource(store);
    final cache = _readCache(store);
    return combineEntitlement(
      legacy: legacy,
      storeLifetime: cache?.lifetime ?? false,
      subscriptionActive: cache?.annualActive(ref.read(clockProvider)()) ?? false,
      renewsAt: cache?.until,
    );
  }

  static LifetimeSource legacySource(KeyValueStore store) {
    if (store.getBool(PrefKeys.legacyLifetime) != true) return LifetimeSource.none;
    return store.getString(PrefKeys.legacySource) == 'android-donation'
        ? LifetimeSource.androidDonation
        : LifetimeSource.iosDonation;
  }

  /// Applies the store's answer and remembers it for the next offline launch.
  Future<void> applyStore({
    required bool storeLifetime,
    required bool subscriptionActive,
    DateTime? renewsAt,
    bool inTrial = false,
    bool willRenew = true,
    bool pending = false,
  }) async {
    final store = ref.read(kvStoreProvider);
    state = combineEntitlement(
      legacy: legacySource(store),
      storeLifetime: storeLifetime,
      subscriptionActive: subscriptionActive,
      renewsAt: renewsAt,
      inTrial: inTrial,
      willRenew: willRenew,
      pending: pending,
    );
    await store.setString(
      PrefKeys.premiumCache,
      jsonEncode({
        'lifetime': storeLifetime,
        'annual': subscriptionActive,
        if (renewsAt != null) 'until': renewsAt.toIso8601String(),
        'checkedAt': ref.read(clockProvider)().toIso8601String(),
      }),
    );
  }

  void setPending(bool pending) => state = state.copyWith(pending: pending);

  static _Cache? _readCache(KeyValueStore store) {
    final raw = store.getString(PrefKeys.premiumCache);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, Object?>;
      return _Cache(
        lifetime: j['lifetime'] == true,
        annual: j['annual'] == true || j['type'] == 'annual',
        until: DateTime.tryParse((j['until'] as String?) ?? ''),
      );
    } on Object {
      return null;
    }
  }
}

class _Cache {
  const _Cache({required this.lifetime, required this.annual, this.until});

  final bool lifetime;
  final bool annual;
  final DateTime? until;

  /// The cache bridges offline launches only; an expiry date in the past ends it. Without a
  /// date, the cached state stands until the store answers.
  bool annualActive(DateTime now) => annual && (until == null || until!.isAfter(now));
}

final entitlementProvider = NotifierProvider<EntitlementController, Entitlement>(
  EntitlementController.new,
);

/// True when the user has Premium (no adverts, downloads allowed).
final isPremiumProvider = Provider<bool>((ref) => ref.watch(entitlementProvider).isPremium);
