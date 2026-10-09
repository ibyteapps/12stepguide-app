import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/app_icons.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../shell/tab_page.dart';
import 'entitlement_controller.dart';
import 'premium_offer.dart';

/// The paywall (F-078): shown on demand (drawer, a download button, "Remove ads") and on launch
/// 2, 20 and 50 for free users (A-25). Close is always visible; it closes itself once Premium
/// is unlocked.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    ref.listen(isPremiumProvider, (was, now) {
      if (now && !(was ?? false)) {
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
          if (context.mounted) Navigator.of(context).maybePop();
        });
      }
    });
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: c.bg,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 520,
        child: ListView(
          padding: const EdgeInsets.only(left: Space.xxl, right: Space.xxl, bottom: Space.x3),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: Radii.lgAll,
                child: Image.asset(
                  'assets/images/app-icon.png',
                  width: Space.x5 * 2,
                  height: Space.x5 * 2,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            const SizedBox(height: Space.l),
            Semantics(
              header: true,
              child: Text(
                'Go Premium',
                textAlign: TextAlign.center,
                style: TypeScale.headline.copyWith(color: c.textPrimary),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Everything stays free. Premium takes the adverts away and lets you listen offline.',
              textAlign: TextAlign.center,
              style: TypeScale.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.xl),
            const PremiumBenefits(),
            const SizedBox(height: Space.xl),
            const PremiumPurchasePanel(),
          ],
        ),
      ),
    );
  }
}
