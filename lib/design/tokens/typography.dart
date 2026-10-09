import 'package:flutter/painting.dart';

/// Type scale (UX_UI_SPEC.md §4). The UI uses the platform system font (SF Pro on iOS, Roboto on
/// Android), so no font family is set here. Colours come from the theme, not from these styles.
abstract final class TypeScale {
  static const display = TextStyle(fontSize: 48, height: 52 / 48, fontWeight: FontWeight.w700);
  static const headline = TextStyle(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700);
  static const title = TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600);
  static const titleSmall = TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  static const bodySmall = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const cardTitle = TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600);
  static const caption = TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400);
  static const button = TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600);
  static const label = TextStyle(fontSize: 13, height: 16 / 13, fontWeight: FontWeight.w600);
  static const navLabel = TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600);
  static const overline = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );
}

/// Reading text sizes. Eight steps; step 3 (18 pt) is the default. The steps include both
/// native apps' scales: iOS 18 / 24 / 30 px and Android 100 / 130 / 160 % of 18 px map to steps
/// 3 / 6 / 8 (MIGRATION_PLAN.md §4).
abstract final class ReaderType {
  static const List<double> sizes = [15, 16.5, 18, 20, 22, 24, 27, 30];
  static const int defaultStep = 3;
  static const int minStep = 1;
  static const int maxStep = 8;

  /// Line height multiplier (28 / 18 at the default size).
  static const double lineHeight = 28 / 18;

  /// Headings are 1.35 × the body size.
  static const double headingScale = 1.35;

  static double sizeFor(int step) => sizes[step.clamp(minStep, maxStep) - 1];

  static TextStyle body(int step) =>
      TextStyle(fontSize: sizeFor(step), height: lineHeight, fontWeight: FontWeight.w400);

  static TextStyle heading(int step, {bool top = false}) => TextStyle(
    fontSize: sizeFor(step) * (top ? headingScale * 1.15 : headingScale),
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static TextStyle caption(int step) =>
      TextStyle(fontSize: sizeFor(step) * 0.78, height: 1.3, fontWeight: FontWeight.w600);
}
