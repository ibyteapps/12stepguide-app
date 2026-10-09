import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'app_icons.dart';

/// A tappable list row: leading badge or icon, title, up to two lines of subtitle, and a
/// trailing chevron or state widget. The whole row is the touch target (UX_UI_SPEC.md §6).
class ListRow extends StatelessWidget {
  const ListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.subtitleMaxLines = 2,
    this.semanticsLabel,
    this.selected = false,
    this.dense = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final int subtitleMaxLines;
  final String? semanticsLabel;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final trailingWidget =
        trailing ??
        (showChevron && onTap != null
            ? Icon(AppIcons.chevron, color: c.textTertiary, size: IconSizes.m)
            : null);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Material(
        color: selected ? c.primaryContainer : c.surface.withAlpha(0),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: dense ? Space.touch : Space.row),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Space.l,
                vertical: dense ? Space.xs : Space.m,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: Space.l)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TypeScale.body.copyWith(
                            color: c.textPrimary,
                            fontWeight: subtitle != null ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: Space.xxs),
                          Text(
                            subtitle!,
                            maxLines: subtitleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingWidget != null) ...[const SizedBox(width: Space.s), trailingWidget],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rows grouped on a rounded surface, separated by hairlines (inset grouped list).
class RowGroup extends StatelessWidget {
  const RowGroup({required this.children, this.margin, super.key});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(height: 1, thickness: 1, indent: Space.l, color: c.divider));
      }
      items.add(children[i]);
    }
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: Space.l),
      child: ClipRRect(
        borderRadius: Radii.mdAll,
        child: ColoredBox(
          color: c.surface,
          child: Column(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}

/// A section header in a list ("PRAYERS"), exposed as a heading to screen readers.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.trailing, this.padding, super.key});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding:
          padding ?? const EdgeInsets.fromLTRB(Space.xxl + Space.xs, Space.xxl, Space.xxl, Space.s),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: TypeScale.overline.copyWith(color: c.textTertiary),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A 40 dp rounded square with a number or an icon (Steps, Traditions; UX_UI_SPEC §6).
class NumberBadge extends StatelessWidget {
  const NumberBadge({this.number, this.icon, this.text, super.key})
    : assert(number != null || icon != null || text != null);

  final int? number;
  final IconData? icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: Space.x4,
        height: Space.x4,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.primaryContainer, borderRadius: Radii.smAll),
        child: icon != null
            ? Icon(icon, color: c.onPrimaryContainer, size: IconSizes.s)
            : Text(
                text ?? '$number',
                style: TypeScale.titleSmall.copyWith(color: c.onPrimaryContainer),
              ),
      ),
    );
  }
}

/// A leading icon in a soft tile, for rows that are not numbered.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {this.color, this.background, super.key});

  final IconData icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: Space.x4,
        height: Space.x4,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background ?? c.surfaceAlt, borderRadius: Radii.smAll),
        child: Icon(icon, color: color ?? c.primary, size: IconSizes.s),
      ),
    );
  }
}
