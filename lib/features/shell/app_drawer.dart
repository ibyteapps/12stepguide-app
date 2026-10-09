import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/links/links.dart';
import '../../design/components/app_icons.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../ads/consent_controller.dart';
import '../premium/entitlement.dart';
import '../premium/entitlement_controller.dart';
import '../premium/offers.dart';
import '../support/support_actions.dart';

/// The drawer: everything that was on the native apps' Settings tabs (UNIFIED_PRODUCT_SPEC §3.4).
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final info = ref.watch(launchInfoProvider);
    final support = ref.read(supportActionsProvider);
    final privacyOptions = ref.watch(privacyOptionsRequiredProvider);

    void go(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    void act(Future<void> Function() action) {
      Navigator.of(context).pop();
      action();
    }

    return Drawer(
      width: (MediaQuery.sizeOf(context).width * 0.85).clamp(0, Space.drawer),
      child: SafeArea(
        child: Column(
          children: [
            const _DrawerHeader(),
            Divider(height: 1, color: c.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: Space.s),
                children: [
                  const _Group('Your app'),
                  _Item(AppIcons.premium, 'Premium', () => go(Routes.premium)),
                  _Item(AppIcons.reminders, 'Reminders', () => go(Routes.reminders)),
                  _Item(AppIcons.appearance, 'Appearance', () => go(Routes.appearance)),
                  _Item(AppIcons.downloads, 'Downloads', () => go(Routes.downloads)),
                  const _Group('Help & support'),
                  _Item(AppIcons.contact, 'Contact us', () {
                    final root = Navigator.of(context, rootNavigator: true).context;
                    act(() => support.contact(root));
                  }),
                  _Item(AppIcons.rate, 'Rate the app', () => act(support.rate)),
                  Builder(
                    builder: (itemContext) => _Item(AppIcons.share, 'Tell a friend', () {
                      final root = Navigator.of(context, rootNavigator: true).context;
                      Navigator.of(context).pop();
                      support.tellAFriend(itemContext.mounted ? itemContext : root);
                    }),
                  ),
                  _Item(
                    AppIcons.facebook,
                    'Follow us on Facebook',
                    () => act(() => support.open(AppLinks.facebook)),
                    external: true,
                  ),
                  _Item(AppIcons.otherApps, 'Our other apps', () => go(Routes.otherApps)),
                  const _Group('Privacy & legal'),
                  if (privacyOptions)
                    _Item(
                      AppIcons.privacyChoices,
                      'Privacy & ad choices',
                      () => act(() => ref.read(consentProvider.notifier).showPrivacyOptions()),
                    ),
                  _Item(
                    AppIcons.privacyPolicy,
                    'Privacy policy',
                    () => act(() => support.open(AppLinks.privacyPolicy)),
                    external: true,
                  ),
                  _Item(
                    AppIcons.terms,
                    'Terms of use',
                    () => act(() => support.open(AppLinks.terms)),
                    external: true,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.divider),
            _Item(
              AppIcons.about,
              'About · Version ${info.version} (${info.buildNumber})',
              () => go(Routes.about),
              quiet: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends ConsumerWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final entitlement = ref.watch(entitlementProvider);
    final offer = ref.watch(headlineOfferProvider);
    final status = switch (entitlement.kind) {
      PremiumKind.lifetime => 'Premium · lifetime',
      // StoreKit tells the app when the current period ends, not whether it will renew.
      PremiumKind.annual when entitlement.renewsAt != null =>
        'Premium · until ${DateFormat('d MMM').format(entitlement.renewsAt!)}',
      PremiumKind.annual => 'Premium',
      PremiumKind.none => offer == null ? 'Free · Go Premium' : 'Free · Go Premium – $offer',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.xl, Space.l, Space.l),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: Radii.mdAll,
            child: Image.asset(
              'assets/images/app-icon.png',
              width: Space.x5,
              height: Space.x5,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('12 Step Guide', style: TypeScale.title.copyWith(color: c.textPrimary)),
                const SizedBox(height: Space.xs),
                Semantics(
                  button: true,
                  child: InkWell(
                    borderRadius: Radii.pillAll,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(Routes.premium);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs),
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        borderRadius: Radii.pillAll,
                      ),
                      child: Text(
                        status,
                        style: TypeScale.label.copyWith(color: c.onPrimaryContainer),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.xs),
    child: Semantics(
      header: true,
      child: Text(
        title.toUpperCase(),
        style: TypeScale.overline.copyWith(color: context.colors.textTertiary),
      ),
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, this.onTap, {this.external = false, this.quiet = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool external;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      minTileHeight: Space.row,
      leading: Icon(icon, color: quiet ? c.textTertiary : c.textSecondary),
      title: Text(
        label,
        style: (quiet ? TypeScale.bodySmall : TypeScale.body).copyWith(
          color: quiet ? c.textTertiary : c.textPrimary,
        ),
      ),
      trailing: external
          ? Icon(AppIcons.openExternal, size: IconSizes.s, color: c.textTertiary)
          : null,
      onTap: onTap,
    );
  }
}
