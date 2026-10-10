import 'package:flutter/material.dart';

import '../../design/components/states.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';

/// A list beside the selected item on expanded widths (F-101, UX_UI_SPEC.md §8): Steps,
/// Readings and Big Book show the reading on the right, Audio shows the album.
///
/// Below [Breakpoints.expanded] only the list is shown and items open as pages, as on a phone.
/// The [ListDetailScope] tells list rows (and `ContentOpener`) whether to select in place.
class ListDetail extends StatefulWidget {
  const ListDetail({
    required this.list,
    required this.detail,
    required this.placeholderIcon,
    required this.placeholderMessage,
    super.key,
  });

  final Widget list;
  final Widget Function(BuildContext context, String id) detail;
  final IconData placeholderIcon;
  final String placeholderMessage;

  /// Width of the list column; the rest goes to the detail.
  static double listWidth(double total) => total >= 1200 ? 420 : 380;

  @override
  State<ListDetail> createState() => _ListDetailState();
}

class _ListDetailState extends State<ListDetail> {
  String? _selected;

  void _select(String id) => setState(() => _selected = id);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < Breakpoints.expanded) return widget.list;
        final listWidth = ListDetail.listWidth(constraints.maxWidth);
        return ListDetailScope(
          selected: _selected,
          select: _select,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: listWidth, child: widget.list),
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
