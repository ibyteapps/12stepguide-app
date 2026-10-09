import 'package:flutter/widgets.dart';

/// Spacing scale in logical pixels (UX_UI_SPEC.md §5).
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double x3 = 32;
  static const double x4 = 40;
  static const double x5 = 48;

  /// Screen side gutters.
  static const double gutterCompact = 16;
  static const double gutterWide = 24;

  /// Minimum touch target.
  static const double touch = 48;

  /// Minimum list row height.
  static const double row = 56;

  /// Reader text column on wide screens (about 70 characters at the default size).
  static const double readerMaxWidth = 680;

  /// Mini-player height.
  static const double miniPlayer = 64;

  /// Drawer width.
  static const double drawer = 304;

  static EdgeInsets gutter(double width) =>
      EdgeInsets.symmetric(horizontal: width >= 600 ? gutterWide : gutterCompact);
}

abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(lg));
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasised = Curves.easeInOutCubicEmphasized;

  /// A duration that collapses to zero when the user asks the system to reduce motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

/// Layout breakpoints (UX_UI_SPEC.md §8).
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;
}

/// Icon sizes.
abstract final class IconSizes {
  static const double s = 20;
  static const double m = 24;
  static const double l = 32;
  static const double xl = 48;
}
