import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A dialog action that looks right on both platforms: a Cupertino action inside the iOS alert,
/// a text button in the Material one.
Widget adaptiveAction(
  BuildContext context,
  String label,
  VoidCallback onPressed, {
  bool destructive = false,
}) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDestructiveAction: destructive,
      child: Text(label),
    );
  }
  final c = context.colors;
  return TextButton(
    onPressed: onPressed,
    style: destructive ? TextButton.styleFrom(foregroundColor: c.error) : null,
    child: Text(label),
  );
}

/// Asks before something that cannot be undone. True when the user confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message),
      actions: [
        adaptiveAction(context, 'Cancel', () => Navigator.of(context).pop(false)),
        adaptiveAction(
          context,
          confirmLabel,
          () => Navigator.of(context).pop(true),
          destructive: destructive,
        ),
      ],
    ),
  );
  return ok ?? false;
}
