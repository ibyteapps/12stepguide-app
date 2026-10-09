import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/platform/connectivity.dart';
import '../../core/prefs/key_value_store.dart';
import '../../design/components/app_icons.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../audio/presentation/mini_player.dart';
import 'app_drawer.dart';
import 'shell_scaffold_key.dart';

/// The four tabs (D-001) with a bottom bar on phones and a rail on tablets, the drawer, and the
/// mini-player above the bar (UNIFIED_PRODUCT_SPEC §3).
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    (label: 'Steps', icon: AppIcons.steps),
    (label: 'Readings', icon: AppIcons.readings),
    (label: 'Big Book', icon: AppIcons.bigBook),
    (label: 'Audio', icon: AppIcons.audio),
  ];

  void _select(WidgetRef ref, int index) {
    HapticFeedback.selectionClick();
    // Tapping the current tab returns it to its root, as both native apps do.
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
    ref.read(kvStoreProvider).setInt(PrefKeys.lastTab, index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the connection watch running for the whole session, so "offline" is known before
    // any audio or link needs it (F-112).
    ref.listen(onlineProvider, (_, _) {});
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
                        for (final d in destinations)
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
                  for (final d in destinations)
                    NavigationDestination(icon: Icon(d.icon), label: d.label),
                ],
              ),
      ),
    );
  }
}
