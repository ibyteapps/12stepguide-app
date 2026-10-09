import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/platform/connectivity.dart';
import '../../core/prefs/key_value_store.dart';
import '../../design/components/app_icons.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../audio/presentation/mini_player.dart';
import '../premium/entitlement_controller.dart';
import '../premium/offers.dart';
import '../premium/purchase_service.dart';
import '../support/review_prompt.dart';
import 'app_drawer.dart';
import 'shell_scaffold_key.dart';

/// The four tabs (D-001) with a bottom bar on phones and a rail on tablets, the drawer, and the
/// mini-player above the bar (UNIFIED_PRODUCT_SPEC §3).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    (label: 'Steps', icon: AppIcons.steps),
    (label: 'Readings', icon: AppIcons.readings),
    (label: 'Big Book', icon: AppIcons.bigBook),
    (label: 'Audio', icon: AppIcons.audio),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowPaywall();
      _maybeAskForReview();
    });
  }

  /// The system review prompt on launch 7, 15 and 30 (A-26), on a tab list, never over reading
  /// or listening, a few seconds after the app opens.
  Future<void> _maybeAskForReview() async {
    final launch = ref.read(launchInfoProvider).launchCount;
    if (!ReviewCadence.shouldAsk(launchCount: launch, store: ref.read(kvStoreProvider))) return;
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    // Only from a tab's root, with nothing pushed over it.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    await ref.read(reviewPromptProvider)(launch);
  }

  /// The automatic paywall on launch 2, 20 and 50 for free users (A-25). Only from the shell, so
  /// never during onboarding or the welcome-back screen, and only when the store can sell.
  Future<void> _maybeShowPaywall() async {
    final launch = ref.read(launchInfoProvider).launchCount;
    final store = ref.read(kvStoreProvider);
    if (!PaywallCadence.shouldShow(
      launchCount: launch,
      premium: ref.read(isPremiumProvider),
      store: store,
    )) {
      return;
    }
    // Give the store a moment to answer, so a Premium user is never shown the paywall.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || ref.read(isPremiumProvider)) return;
    if (ref.read(purchaseServiceProvider).status == StoreStatus.unavailable) return;
    await PaywallCadence.markShown(store, launch);
    if (mounted) await context.push(Routes.paywall);
  }

  void _select(WidgetRef ref, int index) {
    HapticFeedback.selectionClick();
    // Tapping the current tab returns it to its root, as both native apps do.
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
    ref.read(kvStoreProvider).setInt(PrefKeys.lastTab, index);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the connection watch running for the whole session, so "offline" is known before
    // any audio or link needs it (F-112).
    ref.listen(onlineProvider, (_, _) {});
    // The store check runs from the start, so Premium is right before any advert or paywall.
    ref.listen(purchaseServiceProvider, (_, _) {});
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= Breakpoints.medium;
    final c = context.colors;

    final body = Column(
      children: [
        Expanded(child: navigationShell),
        // With the rail there is no tab bar below to keep it clear of the home indicator.
        if (useRail) const SafeArea(top: false, child: MiniPlayer()) else const MiniPlayer(),
      ],
    );

    // Android back from a tab root goes to Steps first, then leaves the app (S-04).
    final canLeave = navigationShell.currentIndex == 0;
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(ref, 0);
      },
      child: Scaffold(
        key: shellScaffoldKey,
        backgroundColor: c.bg,
        drawer: const AppDrawer(),
        drawerEdgeDragWidth: Theme.of(context).platform == TargetPlatform.iOS ? 0 : null,
        body: useRail
            ? Row(
                children: [
                  SafeArea(
                    right: false,
                    child: NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (i) => _select(ref, i),
                      extended: false,
                      leading: Padding(
                        padding: const EdgeInsets.only(bottom: Space.l),
                        child: IconButton(
                          icon: const Icon(AppIcons.menu),
                          tooltip: 'Menu',
                          onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
                        ),
                      ),
                      destinations: [
                        for (final d in AppShell.destinations)
                          NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: c.divider),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: useRail
            ? null
            : NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (i) => _select(ref, i),
                destinations: [
                  for (final d in AppShell.destinations)
                    NavigationDestination(icon: Icon(d.icon), label: d.label),
                ],
              ),
      ),
    );
  }
}
