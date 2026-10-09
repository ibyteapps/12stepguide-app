import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// A pill-shaped segmented control (UX_UI_SPEC.md §6): `surfaceAlt` track, `surface` thumb.
/// Used for Steps | Traditions and the three Big Book collections. Each segment is a
/// selectable button for screen readers.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.shortLabels,
    super.key,
  });

  final List<String> labels;

  /// Used when the full labels do not fit (narrow phones, large text).
  final List<String>? shortLabels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final perSegment = constraints.maxWidth / labels.length;
        final longest = labels.map((l) => l.length).reduce((a, b) => a > b ? a : b);
        final useShort = shortLabels != null && longest * 8.5 * textScale > perSegment - Space.l;
        final shown = useShort ? shortLabels! : labels;
        return Container(
          padding: const EdgeInsets.all(Space.xs),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: Radii.pillAll),
          child: Row(
            children: [
              for (var i = 0; i < shown.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: labels[i],
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: AnimatedContainer(
                        duration: Motion.of(context, Motion.medium),
                        curve: Motion.standard,
                        constraints: const BoxConstraints(minHeight: Space.x4),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.s),
                        decoration: BoxDecoration(
                          color: i == selected ? c.surface : c.surfaceAlt.withAlpha(0),
                          borderRadius: Radii.pillAll,
                          boxShadow: i == selected
                              ? [
                                  BoxShadow(
                                    color: c.shadow.withAlpha(20),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          shown[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TypeScale.label.copyWith(
                            fontSize: 14,
                            color: i == selected ? c.textPrimary : c.textSecondary,
                            fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
