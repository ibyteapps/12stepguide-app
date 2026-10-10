import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/components/states.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';

/// A list beside the selected item on expanded widths (F-101, UX_UI_SPEC.md §8): Steps,
/// Readings and Big Book show the reading on the right, Audio shows the album.
///
/// Below [Breakpoints.expanded] only the list is shown and items open as pages, as on a phone.
/// The [ListDetailScope] tells list rows (and `ContentOpener`) whether to select in place.
///
/// The list keeps its state (scroll position, chosen segment) when the window changes between
/// the two layouts, and an item open beside the list stays open, as its own page, when the
/// window becomes too narrow for two panes (a rotation, or Split View on iPad).
class ListDetail extends StatefulWidget {
  const ListDetail({
    required this.list,
    required this.detail,
    required this.pageRoute,
    required this.placeholderIcon,
    required this.placeholderMessage,
    super.key,
  });

  final Widget list;
  final Widget Function(BuildContext context, String id) detail;

  /// The route that shows an item as its own page, used when the panes collapse.
  final String Function(String id) pageRoute;
  final IconData placeholderIcon;
  final String placeholderMessage;

  /// Width of the list column; the rest goes to the detail.
  static double listWidth(double total) => total >= 1200 ? 420 : 380;

  @override
  State<ListDetail> createState() => _ListDetailState();
}

class _ListDetailState extends State<ListDetail> {
  String? _selected;
  bool? _wasExpanded;

  /// Moves the list between the two layouts without rebuilding it.
  final _listKey = GlobalKey(debugLabel: 'ListDetail.list');

  void _select(String id) => setState(() => _selected = id);

  /// The panes have just collapsed: carry the open item over as a page.
  void _collapse() {
    final id = _selected;
    if (id == null) return;
    _selected = null; // Called while building; the list-only layout is what gets built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.push(widget.pageRoute(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= Breakpoints.expanded;
        if (_wasExpanded == true && !expanded) _collapse();
        _wasExpanded = expanded;
        final list = KeyedSubtree(key: _listKey, child: widget.list);
        if (!expanded) return list;
        final listWidth = ListDetail.listWidth(constraints.maxWidth);
        return ListDetailScope(
          selected: _selected,
          select: _select,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: listWidth, child: list),
              VerticalDivider(width: 1, thickness: 1, color: c.divider),
              Expanded(
                child: _selected == null
                    ? ColoredBox(
                        color: c.bg,
                        child: StateMessage(
                          icon: widget.placeholderIcon,
                          message: widget.placeholderMessage,
                        ),
                      )
                    // A new key per item, so each reading starts from its own saved position.
                    : KeyedSubtree(
                        key: ValueKey(_selected),
                        child: widget.detail(context, _selected!),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Present only while a [ListDetail] shows its two panes.
class ListDetailScope extends InheritedWidget {
  const ListDetailScope({
    required this.selected,
    required this.select,
    required super.child,
    super.key,
  });

  final String? selected;
  final ValueChanged<String> select;

  static ListDetailScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ListDetailScope>();

  /// The scope without subscribing to it (for tap handlers).
  static ListDetailScope? find(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ListDetailScope>();

  /// Whether [id] is the item shown in the detail pane.
  static bool isSelected(BuildContext context, String id) => maybeOf(context)?.selected == id;

  @override
  bool updateShouldNotify(ListDetailScope old) => old.selected != selected;
}
