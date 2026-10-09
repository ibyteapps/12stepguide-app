import 'package:flutter/material.dart';

import '../../design/components/app_icons.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import 'shell_scaffold_key.dart';

/// A tab's root page: ☰ (compact layouts; the rail has its own), title, contextual actions
/// (UNIFIED_PRODUCT_SPEC §3.2).
class TabPage extends StatelessWidget {
  const TabPage({required this.title, required this.body, this.actions, super.key});

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.medium;
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: compact ? const MenuButton() : null,
        title: Semantics(header: true, child: Text(title)),
        actions: actions,
      ),
      body: body,
    );
  }
}

/// Opens the app drawer.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(AppIcons.menu),
    tooltip: 'Menu',
    onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
  );
}

/// Constrains page content to a readable width on tablets.
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, this.maxWidth = 720, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
