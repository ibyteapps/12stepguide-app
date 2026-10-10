import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../app/routes.dart';
import '../../core/logging/log.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../premium/entitlement_controller.dart';
import 'ad_coordinator.dart';
import 'ad_gateway.dart';
import 'consent_controller.dart';

/// Where a banner may appear (UNIFIED_PRODUCT_SPEC §2.4).
enum BannerPlacement { reader, player, quote }

/// An adaptive banner for free users, under the content and never over text or controls, with
/// a "Remove ads" link to the paywall (F-075). Takes no space until an advert has loaded.
class BannerSlot extends ConsumerWidget {
  const BannerSlot({required this.placement, super.key});

  final BannerPlacement placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(isPremiumProvider);
    final consent = ref.watch(consentProvider);
    final unit = ref.watch(adUnitsProvider).banner;
    final enabled = ref.watch(adGatewayProvider) is! NoAds;
    if (premium || !consent.canRequestAds || unit == null || !enabled) {
      return const SizedBox.shrink();
    }
    // Sized to the space it sits in (the reader pane on a tablet), not the whole screen.
    return LayoutBuilder(
      key: ValueKey('banner-${placement.name}'),
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return _Banner(unit: unit, width: width.truncate());
      },
    );
  }
}

class _Banner extends StatefulWidget {
  const _Banner({required this.unit, required this.width});

  final String unit;

  /// The width available to the banner, in logical pixels.
  final int width;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  BannerAd? _ad;
  bool _loaded = false;

  /// Bumped on every load, so an older load that finishes late is dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(widget.width);
  }

  @override
  void didUpdateWidget(_Banner old) {
    super.didUpdateWidget(old);
    if (old.width != widget.width || old.unit != widget.unit) _load(widget.width);
  }

  Future<void> _load(int width) async {
    final generation = ++_generation;
    final previous = _ad;
    _ad = null;
    _loaded = false; // Runs from initState or didUpdateWidget; a build follows.
    await previous?.dispose();
    if (width <= 0) return;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null || generation != _generation) return;
    final ad = BannerAd(
      adUnitId: widget.unit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (mounted && identical(loaded, _ad)) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (failed, error) {
          Log.w('Banner failed to load: ${error.code}');
          failed.dispose();
          if (mounted && identical(failed, _ad)) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    final c = context.colors;
    return SafeArea(
      top: false,
      child: ColoredBox(
        color: c.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, thickness: 1, color: c.divider),
            SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
            // Compact to look at, but the touch target stays 48 dp (padded tap target).
            TextButton(
              onPressed: () => context.push(Routes.paywall),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: Space.m),
                textStyle: TypeScale.caption,
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: const Text('Remove ads'),
            ),
          ],
        ),
      ),
    );
  }
}
