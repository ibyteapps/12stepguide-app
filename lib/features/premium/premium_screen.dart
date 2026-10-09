import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/links/links.dart';
import '../../design/components/app_icons.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../shell/tab_page.dart';
import 'entitlement.dart';
import 'entitlement_controller.dart';
import 'premium_offer.dart';
import 'purchase_service.dart';

/// Premium (S-51, F-079, F-079a): what it gives and how to get it for free users; the plan,
/// renewal or "Lifetime", and Manage subscription for Premium users.
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final e = ref.watch(entitlementProvider);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Premium')),
      body: ContentWidth(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.xxl, Space.l, Space.xxl, Space.x3),
          children: [
            if (e.isPremium) _Status(entitlement: e) else const _Intro(),
            const SizedBox(height: Space.l),
            const PremiumBenefits(),
            const SizedBox(height: Space.xxl),
            if (e.isPremium) const _PremiumActions() else const PremiumPurchasePanel(),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            '12 Step Guide Premium',
            style: TypeScale.headline.copyWith(color: c.textPrimary),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'Everything in the app stays free. Premium removes the adverts and lets you listen '
          'offline.',
          style: TypeScale.body.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = entitlement;
    final (title, detail) = switch (e.kind) {
      PremiumKind.annual => (
        'Annual subscription',
        e.renewsAt == null
            ? 'Active'
            : 'Active until ${DateFormat('d MMMM y').format(e.renewsAt!)}. It renews '
                  'automatically unless you cancel it.',
      ),
      PremiumKind.lifetime => ('Lifetime supporter', 'Premium is yours for good. Thank you.'),
      PremiumKind.none => ('', ''),
    };
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(color: c.surfaceBrand, borderRadius: Radii.lgAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.verified, color: c.onSurfaceBrand, size: IconSizes.l),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have Premium',
                  style: TypeScale.overline.copyWith(color: c.onSurfaceBrand),
                ),
                const SizedBox(height: Space.xxs),
                Semantics(
                  header: true,
                  child: Text(title, style: TypeScale.title.copyWith(color: c.onSurfaceBrand)),
                ),
                const SizedBox(height: Space.xs),
                Text(detail, style: TypeScale.bodySmall.copyWith(color: c.onSurfaceBrand)),
                if (e.alsoLegacySupporter) ...[
                  const SizedBox(height: Space.s),
                  Text(
                    'You have also supported us in the past. Thank you — that support is '
                    'remembered: if you cancel, Premium stays.',
                    style: TypeScale.bodySmall.copyWith(color: c.onSurfaceBrand),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumActions extends ConsumerWidget {
  const _PremiumActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(entitlementProvider);
    final s = ref.watch(purchaseServiceProvider);
    final isIOS = ref.watch(isIOSStoreProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e.kind == PremiumKind.annual)
          OutlinedButton.icon(
            onPressed: () => ref
                .read(linkOpenerProvider)
                .open(isIOS ? AppLinks.appleSubscriptions : AppLinks.playSubscriptions),
            icon: const Icon(AppIcons.openExternal),
            label: const Text('Manage subscription'),
          ),
        Center(
          child: TextButton.icon(
            onPressed: s.busy ? null : ref.read(purchaseServiceProvider.notifier).restore,
            icon: const Icon(AppIcons.restore),
            label: const Text('Restore purchases'),
          ),
        ),
      ],
    );
  }
}
