import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'app_icons.dart';

/// Empty or error state: icon, one sentence, one action (UX_UI_SPEC.md §6).
class StateMessage extends StatelessWidget {
  const StateMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  const StateMessage.error({
    required String message,
    String actionLabel = 'Try again',
    VoidCallback? onAction,
    Key? key,
  }) : this(
         icon: AppIcons.error,
         message: message,
         actionLabel: onAction == null ? null : actionLabel,
         onAction: onAction,
         key: key,
       );

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: IconSizes.xl, color: c.textTertiary),
            const SizedBox(height: Space.l),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TypeScale.body.copyWith(color: c.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Space.l),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton lines shown for the moment a document or price is loading.
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({this.lines = 8, super.key});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Loading',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines; i++)
            Container(
              height: Space.l,
              margin: const EdgeInsets.only(bottom: Space.m),
              width: i % 4 == 3 ? 180 : double.infinity,
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: Radii.smAll),
            ),
        ],
      ),
    );
  }
}

enum BannerTone { info, warning, success }

/// A one-line inline banner: offline, permission denied, purchase pending (UX_UI_SPEC.md §6).
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    required this.message,
    this.icon,
    this.tone = BannerTone.info,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final IconData? icon;
  final BannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      BannerTone.info => (c.primaryContainer, c.onPrimaryContainer),
      BannerTone.warning => (c.warningContainer, c.warning),
      BannerTone.success => (c.primaryContainer, c.success),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
        decoration: BoxDecoration(color: bg, borderRadius: Radii.mdAll),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: IconSizes.s),
              const SizedBox(width: Space.m),
            ],
            Expanded(
              child: Text(message, style: TypeScale.bodySmall.copyWith(color: c.textPrimary)),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

/// Shows a short message in a floating snackbar (4 s, one optional action).
void showMessage(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: action != null && onAction != null
            ? SnackBarAction(label: action, onPressed: onAction)
            : null,
      ),
    );
}
