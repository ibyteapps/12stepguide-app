import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/key_value_store.dart';
import 'purchase_gateway.dart';
import 'purchase_service.dart';

/// The price line for the drawer header (S-50): "£16.99/yr" on iOS, "from £1.99" on Android.
/// Null until the store has answered.
final headlineOfferProvider = Provider<String?>((ref) {
  final s = ref.watch(purchaseServiceProvider);
  if (s.status != StoreStatus.ready || s.products.isEmpty) return null;
  final annual = s.product(ProductIds.annual);
  if (annual != null) return '${annual.price}/yr';
  final cheapest = [...s.products]..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
  return 'from ${cheapest.first.price}';
});

/// The paywall's automatic appearances (A-25): once each on launch 2, 20 and 50, for free users
/// only, never on the first launch or during onboarding (UNIFIED_PRODUCT_SPEC §2.3).
abstract final class PaywallCadence {
  static const launches = {2, 20, 50};

  static bool shouldShow({
    required int launchCount,
    required bool premium,
    required KeyValueStore store,
  }) {
    if (premium || !launches.contains(launchCount)) return false;
    final shown = store.getStringList(PrefKeys.paywallShownAtLaunches) ?? const [];
    return !shown.contains('$launchCount');
  }

  static Future<void> markShown(KeyValueStore store, int launchCount) async {
    final shown = store.getStringList(PrefKeys.paywallShownAtLaunches) ?? const [];
    await store.setStringList(PrefKeys.paywallShownAtLaunches, {...shown, '$launchCount'}.toList());
  }
}
