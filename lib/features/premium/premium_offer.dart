import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/links/links.dart';
import '../../design/components/app_icons.dart';
import '../../design/components/states.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../support/support_actions.dart';
import 'purchase_gateway.dart';
import 'purchase_service.dart';

/// The benefits of Premium (UNIFIED_PRODUCT_SPEC §2.1).
class PremiumBenefits extends ConsumerWidget {
  const PremiumBenefits({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(catalogueProvider).allTracks.length;
    return Column(
      children: [
        const _Benefit(
          icon: AppIcons.noAds,
          title: 'No adverts',
          text: 'Read and listen without interruptions.',
        ),
        _Benefit(
          icon: AppIcons.downloads,
          title: 'Listen offline',
          text: 'Download any of the $tracks recordings and play them without a connection.',
        ),
        const _Benefit(
          icon: AppIcons.support,
          title: 'Support the app',
          text: 'Help keep the 12 Step Guide free for everyone and fund new free apps.',
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: Space.x4,
                height: Space.x4,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primaryContainer, borderRadius: Radii.smAll),
                child: Icon(icon, color: c.onPrimaryContainer, size: IconSizes.s),
              ),
            ),
            const SizedBox(width: Space.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TypeScale.titleSmall.copyWith(color: c.textPrimary)),
                  const SizedBox(height: Space.xxs),
                  Text(text, style: TypeScale.bodySmall.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the store sells, the buy buttons, Restore, the legal links and every state of a
/// purchase (S-51): loading, unavailable, pending, success, cancelled (silent) and error.
class PremiumPurchasePanel extends ConsumerWidget {
  const PremiumPurchasePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(purchaseServiceProvider);
    final service = ref.read(purchaseServiceProvider.notifier);
    final isIOS = ref.watch(isIOSStoreProvider);

    final Widget offer = switch (s.status) {
      StoreStatus.loading => const _PriceSkeleton(),
      StoreStatus.unavailable => InlineBanner(
        icon: AppIcons.error,
        tone: BannerTone.warning,
        message: "Purchases aren't available right now. Try again later.",
        actionLabel: 'Retry',
        onAction: service.loadProducts,
      ),
      StoreStatus.ready => isIOS ? _AnnualOffer(state: s) : _SupportTiers(state: s),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Feedback(state: s),
        offer,
        const SizedBox(height: Space.s),
        Center(
          child: TextButton.icon(
            onPressed: s.busy ? null : service.restore,
            icon: const Icon(AppIcons.restore),
            label: const Text('Restore purchases'),
          ),
        ),
        if (!isIOS)
          Center(
            child: TextButton(
              onPressed: () => ref
                  .read(supportActionsProvider)
                  .contact(
                    context,
                    subject: 'Supporter status',
                    intro:
                        'I supported the 12 Step Guide on Google Play before and no longer '
                        'have Premium. My Google Play order number (it starts with GPA.) is: ',
                  ),
              child: const Text('Lost your supporter status?'),
            ),
          ),
        const SizedBox(height: Space.s),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: () => ref.read(linkOpenerProvider).open(AppLinks.terms),
              child: Text('Terms of use', style: TypeScale.caption.copyWith(color: c.primary)),
            ),
            TextButton(
              onPressed: () => ref.read(linkOpenerProvider).open(AppLinks.privacyPolicy),
              child: Text('Privacy policy', style: TypeScale.caption.copyWith(color: c.primary)),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnnualOffer extends ConsumerWidget {
  const _AnnualOffer({required this.state});

  final PurchaseState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final annual = state.product(ProductIds.annual);
    if (annual == null) return const SizedBox.shrink();
    final trial = state.trialEligible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: state.busy
              ? null
              : () => ref.read(purchaseServiceProvider.notifier).buy(annual),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(Space.x5 + Space.xs)),
          child: state.busy
              ? SizedBox.square(
                  dimension: IconSizes.s,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary),
                )
              : Text(trial ? 'Start 7-day free trial' : 'Subscribe for ${annual.price} a year'),
        ),
        const SizedBox(height: Space.s),
        // Apple's required wording for an auto-renewing subscription.
        Text(
          trial
              ? 'Free for 7 days, then ${annual.price} a year. The subscription renews '
                    'automatically unless you cancel at least 24 hours before the end of the '
                    'current period. Manage or cancel it in your Apple account settings.'
              : '${annual.price} a year. The subscription renews automatically unless you cancel '
                    'at least 24 hours before the end of the current period. Manage or cancel it '
                    'in your Apple account settings.',
          textAlign: TextAlign.center,
          style: TypeScale.caption.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _SupportTiers extends ConsumerWidget {
  const _SupportTiers({required this.state});

  final PurchaseState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final tiers = [for (final id in ProductIds.androidTiers) ?state.product(id)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Support the app — lifetime Premium',
          textAlign: TextAlign.center,
          style: TypeScale.titleSmall.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'One payment, no subscription. Choose what you would like to give; every amount '
          'unlocks the same Premium, for good.',
          textAlign: TextAlign.center,
          style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.m),
        for (final (i, t) in tiers.indexed) ...[
          if (i > 0) const SizedBox(height: Space.s),
          // Equal choices, so equal buttons.
          FilledButton(
            onPressed: state.busy ? null : () => ref.read(purchaseServiceProvider.notifier).buy(t),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(Space.x5)),
            child: Text('Give ${t.price}'),
          ),
        ],
      ],
    );
  }
}

class _Feedback extends ConsumerWidget {
  const _Feedback({required this.state});

  final PurchaseState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (message, tone, icon) = switch (state.feedback) {
      PurchaseFeedback.none => (null, BannerTone.info, null),
      PurchaseFeedback.success => (
        'Premium unlocked. Thank you for supporting the app.',
        BannerTone.success,
        AppIcons.verified,
      ),
      PurchaseFeedback.restored => (
        'Your purchases are restored.',
        BannerTone.success,
        AppIcons.check,
      ),
      PurchaseFeedback.nothingToRestore => (
        'No purchases were found for this account.',
        BannerTone.info,
        AppIcons.restore,
      ),
      PurchaseFeedback.pending => (
        'Your payment is pending. Premium starts as soon as it goes through.',
        BannerTone.warning,
        AppIcons.pending,
      ),
      PurchaseFeedback.error => (
        state.errorMessage ?? 'The purchase did not go through.',
        BannerTone.warning,
        AppIcons.error,
      ),
    };
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: InlineBanner(message: message, tone: tone, icon: icon),
    );
  }
}

class _PriceSkeleton extends StatelessWidget {
  const _PriceSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading prices',
    child: Container(
      height: Space.x5 + Space.xs,
      decoration: BoxDecoration(color: context.colors.surfaceAlt, borderRadius: Radii.pillAll),
    ),
  );
}
