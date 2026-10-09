import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'app_colors.dart';

/// Builds the light and dark themes from the tokens (UX_UI_SPEC.md §3–7).
abstract final class AppTheme {
  static ThemeData light({TargetPlatform? platform}) =>
      _build(AppColors.light, Brightness.light, platform);

  static ThemeData dark({TargetPlatform? platform}) =>
      _build(AppColors.dark, Brightness.dark, platform);

  static ThemeData _build(AppColors c, Brightness brightness, TargetPlatform? platform) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.secondary,
      onSecondary: c.onPrimary,
      secondaryContainer: c.primaryContainer,
      onSecondaryContainer: c.onPrimaryContainer,
      tertiary: c.highlight,
      onTertiary: c.onSurfaceBrand,
      error: c.error,
      onError: c.onPrimary,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.outline,
      outlineVariant: c.divider,
      shadow: c.shadow,
      scrim: c.scrim,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.surface,
      inversePrimary: c.primaryContainer,
      surfaceTint: c.surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      platform: platform,
    );

    // The token sizes on top of the platform's typography, so the system font family (SF Pro or
    // Roboto) and its fallbacks are kept.
    final t = base.textTheme;
    TextStyle on(TextStyle? platform, TextStyle token, Color color) =>
        (platform ?? const TextStyle()).merge(token).copyWith(color: color);
    final textTheme = t.copyWith(
      displaySmall: on(t.displaySmall, TypeScale.display, c.textPrimary),
      headlineMedium: on(t.headlineMedium, TypeScale.headline, c.textPrimary),
      headlineSmall: on(t.headlineSmall, TypeScale.headline, c.textPrimary),
      titleLarge: on(t.titleLarge, TypeScale.title, c.textPrimary),
      titleMedium: on(t.titleMedium, TypeScale.titleSmall, c.textPrimary),
      titleSmall: on(t.titleSmall, TypeScale.titleSmall, c.textPrimary),
      bodyLarge: on(t.bodyLarge, TypeScale.body, c.textPrimary),
      bodyMedium: on(t.bodyMedium, TypeScale.bodySmall, c.textPrimary),
      bodySmall: on(t.bodySmall, TypeScale.bodySmall, c.textSecondary),
      labelLarge: on(t.labelLarge, TypeScale.label, c.textPrimary),
      labelMedium: on(t.labelMedium, TypeScale.navLabel, c.textPrimary),
      labelSmall: on(t.labelSmall, TypeScale.overline, c.textTertiary),
    );
    // Component themes use the token styles with the platform's font family.
    final family = t.bodyMedium?.fontFamily;
    final fallback = t.bodyMedium?.fontFamilyFallback;
    TextStyle fam(TextStyle s) => s.copyWith(fontFamily: family, fontFamilyFallback: fallback);
    TextStyle withColor(TextStyle s, Color color) => fam(s).copyWith(color: color);

    final overlay = brightness == Brightness.light
        ? SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: c.bg.withAlpha(0),
            systemNavigationBarColor: c.navSurface.withAlpha(0),
          )
        : SystemUiOverlayStyle.light.copyWith(
            statusBarColor: c.bg.withAlpha(0),
            systemNavigationBarColor: c.navSurface.withAlpha(0),
          );

    const pillShape = StadiumBorder();
    const buttonSize = Size(Space.touch, Space.touch);

    return base.copyWith(
      extensions: [c],
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.divider,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: c.textSecondary, size: IconSizes.m),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.textPrimary,
        surfaceTintColor: c.bg.withAlpha(0),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: c.divider,
        titleTextStyle: withColor(TypeScale.title, c.textPrimary),
        systemOverlayStyle: overlay,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.navSurface,
        surfaceTintColor: c.navSurface.withAlpha(0),
        indicatorColor: c.navIndicator,
        height: 72,
        elevation: 2,
        shadowColor: c.shadow.withAlpha(30),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? c.navSelected : c.navUnselected,
            size: IconSizes.m,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => fam(TypeScale.navLabel).copyWith(
            color: s.contains(WidgetState.selected) ? c.navSelected : c.navUnselected,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.navSurface,
        indicatorColor: c.navIndicator,
        selectedIconTheme: IconThemeData(color: c.navSelected),
        unselectedIconTheme: IconThemeData(color: c.navUnselected),
        selectedLabelTextStyle: fam(TypeScale.navLabel)
            .copyWith(color: c.navSelected, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: fam(TypeScale.navLabel).copyWith(color: c.navUnselected),
        labelType: NavigationRailLabelType.all,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: c.surface.withAlpha(0),
        width: Space.drawer,
        scrimColor: c.scrim,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        titleTextStyle: withColor(TypeScale.body, c.textPrimary),
        subtitleTextStyle: withColor(TypeScale.bodySmall, c.textSecondary),
        minVerticalPadding: Space.s,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.l),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: c.surface.withAlpha(0),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: buttonSize,
          shape: pillShape,
          textStyle: fam(TypeScale.button),
          padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: buttonSize,
          shape: pillShape,
          side: BorderSide(color: c.outline),
          textStyle: fam(TypeScale.button),
          padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: buttonSize,
          shape: pillShape,
          textStyle: fam(TypeScale.button),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.textPrimary, minimumSize: buttonSize),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: c.surface.withAlpha(0),
        modalBackgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
        showDragHandle: true,
        dragHandleColor: c.outline,
        modalBarrierColor: c.scrim,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: c.surface.withAlpha(0),
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        titleTextStyle: withColor(TypeScale.title, c.textPrimary),
        contentTextStyle: withColor(TypeScale.body, c.textSecondary),
        barrierColor: c.scrim,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: withColor(TypeScale.bodySmall, c.surface),
        actionTextColor: c.primaryContainer,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.outline,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfaceAlt,
        thumbColor: c.primary,
        overlayColor: c.primary.withAlpha(30),
        activeTickMarkColor: c.onPrimary,
        inactiveTickMarkColor: c.outline,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceAlt,
        circularTrackColor: c.surfaceAlt,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.primaryContainer,
        labelStyle: withColor(TypeScale.label, c.onPrimaryContainer),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.surfaceAlt,
          selectedBackgroundColor: c.surface,
          foregroundColor: c.textSecondary,
          selectedForegroundColor: c.textPrimary,
          side: BorderSide(color: c.divider),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: c.primary,
        scaffoldBackgroundColor: c.bg,
        barBackgroundColor: c.navSurface,
      ),
      splashFactory: platform == TargetPlatform.iOS ? NoSplash.splashFactory : null,
    );
  }
}
