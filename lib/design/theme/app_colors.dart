import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';

/// The semantic colour roles (UX_UI_SPEC.md §3.2), read by every widget through
/// `context.colors`. Light and dark are the two instances; `lerp` animates theme changes.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceRaised,
    required this.surfaceReader,
    required this.surfaceBrand,
    required this.onSurfaceBrand,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.highlight,
    required this.highlightText,
    required this.success,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.outline,
    required this.divider,
    required this.scrim,
    required this.shadow,
    required this.navSurface,
    required this.navIndicator,
    required this.navSelected,
    required this.navUnselected,
    required this.cardStroke,
  });

  static const light = AppColors(
    bg: LightTokens.bg,
    surface: LightTokens.surface,
    surfaceAlt: LightTokens.surfaceAlt,
    surfaceRaised: LightTokens.surfaceRaised,
    surfaceReader: LightTokens.surfaceReader,
    surfaceBrand: LightTokens.surfaceBrand,
    onSurfaceBrand: LightTokens.onSurfaceBrand,
    textPrimary: LightTokens.textPrimary,
    textSecondary: LightTokens.textSecondary,
    textTertiary: LightTokens.textTertiary,
    textDisabled: LightTokens.textDisabled,
    primary: LightTokens.primary,
    onPrimary: LightTokens.onPrimary,
    primaryContainer: LightTokens.primaryContainer,
    onPrimaryContainer: LightTokens.onPrimaryContainer,
    secondary: LightTokens.secondary,
    highlight: LightTokens.highlight,
    highlightText: LightTokens.highlightText,
    success: LightTokens.success,
    warning: LightTokens.warning,
    warningContainer: LightTokens.warningContainer,
    error: LightTokens.error,
    outline: LightTokens.outline,
    divider: LightTokens.divider,
    scrim: LightTokens.scrim,
    shadow: LightTokens.shadow,
    navSurface: LightTokens.navSurface,
    navIndicator: LightTokens.navIndicator,
    navSelected: LightTokens.navSelected,
    navUnselected: LightTokens.navUnselected,
    cardStroke: CardStrokeTokens.light,
  );

  static const dark = AppColors(
    bg: DarkTokens.bg,
    surface: DarkTokens.surface,
    surfaceAlt: DarkTokens.surfaceAlt,
    surfaceRaised: DarkTokens.surfaceRaised,
    surfaceReader: DarkTokens.surfaceReader,
    surfaceBrand: DarkTokens.surfaceBrand,
    onSurfaceBrand: DarkTokens.onSurfaceBrand,
    textPrimary: DarkTokens.textPrimary,
    textSecondary: DarkTokens.textSecondary,
    textTertiary: DarkTokens.textTertiary,
    textDisabled: DarkTokens.textDisabled,
    primary: DarkTokens.primary,
    onPrimary: DarkTokens.onPrimary,
    primaryContainer: DarkTokens.primaryContainer,
    onPrimaryContainer: DarkTokens.onPrimaryContainer,
    secondary: DarkTokens.secondary,
    highlight: DarkTokens.highlight,
    highlightText: DarkTokens.highlightText,
    success: DarkTokens.success,
    warning: DarkTokens.warning,
    warningContainer: DarkTokens.warningContainer,
    error: DarkTokens.error,
    outline: DarkTokens.outline,
    divider: DarkTokens.divider,
    scrim: DarkTokens.scrim,
    shadow: DarkTokens.shadow,
    navSurface: DarkTokens.navSurface,
    navIndicator: DarkTokens.navIndicator,
    navSelected: DarkTokens.navSelected,
    navUnselected: DarkTokens.navUnselected,
    cardStroke: CardStrokeTokens.dark,
  );

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceRaised;
  final Color surfaceReader;
  final Color surfaceBrand;
  final Color onSurfaceBrand;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color highlight;
  final Color highlightText;
  final Color success;
  final Color warning;
  final Color warningContainer;
  final Color error;
  final Color outline;
  final Color divider;
  final Color scrim;
  final Color shadow;
  final Color navSurface;
  final Color navIndicator;
  final Color navSelected;
  final Color navUnselected;

  /// Three stops; `strokeAt` interpolates across a collection.
  final List<Color> cardStroke;

  /// Border colour for item [index] of [count] in a Big Book grid.
  Color strokeAt(int index, int count) {
    if (count <= 1) return cardStroke.first;
    final t = index / (count - 1);
    if (t <= 0.5) return Color.lerp(cardStroke[0], cardStroke[1], t * 2)!;
    return Color.lerp(cardStroke[1], cardStroke[2], (t - 0.5) * 2)!;
  }

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceReader: l(surfaceReader, other.surfaceReader),
      surfaceBrand: l(surfaceBrand, other.surfaceBrand),
      onSurfaceBrand: l(onSurfaceBrand, other.onSurfaceBrand),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      textDisabled: l(textDisabled, other.textDisabled),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      secondary: l(secondary, other.secondary),
      highlight: l(highlight, other.highlight),
      highlightText: l(highlightText, other.highlightText),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
      error: l(error, other.error),
      outline: l(outline, other.outline),
      divider: l(divider, other.divider),
      scrim: l(scrim, other.scrim),
      shadow: l(shadow, other.shadow),
      navSurface: l(navSurface, other.navSurface),
      navIndicator: l(navIndicator, other.navIndicator),
      navSelected: l(navSelected, other.navSelected),
      navUnselected: l(navUnselected, other.navUnselected),
      cardStroke: [
        for (var i = 0; i < cardStroke.length; i++) l(cardStroke[i], other.cardStroke[i]),
      ],
    );
  }
}

extension AppColorsContext on BuildContext {
  /// The semantic colours for the current theme.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  TextTheme get text => Theme.of(this).textTheme;
}
