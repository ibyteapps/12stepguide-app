import 'package:flutter/material.dart';

/// Where a banner may appear (UNIFIED_PRODUCT_SPEC §2.4).
enum BannerPlacement { reader, player, quote }

/// Reserved space for an adaptive banner with a "Remove ads" link. Completed in P4.
class BannerSlot extends StatelessWidget {
  const BannerSlot({required this.placement, super.key});

  final BannerPlacement placement;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
