import 'package:flutter/widgets.dart';

/// UI chrome caps the system text size at 2.0× so controls never break; reading text is
/// uncapped (UX_UI_SPEC §4). The app root caps it and keeps the original here for the reader.
class UnclampedTextScale extends InheritedWidget {
  const UnclampedTextScale({required this.scaler, required super.child, super.key});

  final TextScaler scaler;

  static TextScaler of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UnclampedTextScale>()?.scaler ??
      MediaQuery.textScalerOf(context);

  @override
  bool updateShouldNotify(UnclampedTextScale old) => old.scaler != scaler;
}

/// Restores the user's full system text size for reading text below this widget.
class ReadingTextScale extends StatelessWidget {
  const ReadingTextScale({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: UnclampedTextScale.of(context)),
    child: child,
  );
}
