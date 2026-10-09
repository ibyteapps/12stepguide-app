import 'package:flutter/painting.dart';

/// Every colour value in the app (UX_UI_SPEC.md §3). Widgets never use these directly: they
/// read the semantic roles from `AppColors` (lib/design/theme/app_colors.dart), so light and dark
/// stay consistent. test/design/no_raw_values_test.dart fails if a `Color(0x…)` appears anywhere
/// else under lib/.
abstract final class Brand {
  static const navy = Color(0xFF1E2134);
  static const guideBlue = Color(0xFF2451C7);
  static const sky = Color(0xFF80EEFF);
  static const coral = Color(0xFFE5534B);
  static const paper = Color(0xFFFBF8F1);
}

abstract final class LightTokens {
  static const bg = Color(0xFFF6F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEEF1F7);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const surfaceReader = Color(0xFFFBF8F1);
  static const surfaceBrand = Color(0xFF1E2134);
  static const onSurfaceBrand = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF161A26);
  static const textSecondary = Color(0xFF4A5163);
  static const textTertiary = Color(0xFF626A7D);
  static const textDisabled = Color(0xFF9AA1B2);
  static const primary = Color(0xFF2451C7);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFE2E9FB);
  static const onPrimaryContainer = Color(0xFF0F2462);
  static const secondary = Color(0xFF0B7285);
  static const highlight = Color(0xFFE5534B);
  static const highlightText = Color(0xFFB42318);
  static const success = Color(0xFF1E7A46);
  static const warning = Color(0xFF8A5A00);
  static const warningContainer = Color(0xFFFFF4DC);
  static const error = Color(0xFFB3261E);
  static const outline = Color(0xFF8E95A6);
  static const divider = Color(0xFFE2E5EC);
  static const scrim = Color(0x66000000);
  static const shadow = Color(0xFF0B1E5C);
  static const navSurface = Color(0xFFFFFFFF);
  static const navIndicator = Color(0xFFE2E9FB);
  static const navSelected = Color(0xFF0F2462);
  static const navUnselected = Color(0xFF626A7D);
}

abstract final class DarkTokens {
  static const bg = Color(0xFF0E1017);
  static const surface = Color(0xFF161923);
  static const surfaceAlt = Color(0xFF1F2330);
  static const surfaceRaised = Color(0xFF252A38);
  static const surfaceReader = Color(0xFF14161C);
  static const surfaceBrand = Color(0xFF1E2134);
  static const onSurfaceBrand = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFFECEEF4);
  static const textSecondary = Color(0xFFB6BCCB);
  static const textTertiary = Color(0xFF959CAE);
  static const textDisabled = Color(0xFF5F6678);
  static const primary = Color(0xFF93B1FF);
  static const onPrimary = Color(0xFF0A1A4A);
  static const primaryContainer = Color(0xFF22356E);
  static const onPrimaryContainer = Color(0xFFDCE5FF);
  static const secondary = Color(0xFF6FD6E8);
  static const highlight = Color(0xFFFF8A80);
  static const highlightText = Color(0xFFFF9E95);
  static const success = Color(0xFF6FD39B);
  static const warning = Color(0xFFF2C46D);
  static const warningContainer = Color(0xFF332A14);
  static const error = Color(0xFFFF8A80);
  static const outline = Color(0xFF6B7285);
  static const divider = Color(0xFF2A2F3D);
  static const scrim = Color(0x99000000);
  static const shadow = Color(0xFF000000);
  static const navSurface = Color(0xFF161923);
  static const navIndicator = Color(0xFF22356E);
  static const navSelected = Color(0xFFDCE5FF);
  static const navUnselected = Color(0xFF959CAE);
}

/// Big Book card borders sweep guide blue → teal → coral across a collection (UX_UI_SPEC §3.2,
/// replacing the native apps' RGB sweep).
abstract final class CardStrokeTokens {
  static const light = [Color(0xFF2451C7), Color(0xFF0B7285), Color(0xFFE5534B)];
  static const dark = [Color(0xFF93B1FF), Color(0xFF6FD6E8), Color(0xFFFF8A80)];
}

/// Colours that look the same in both themes: the brand gradient behind the quote screen and
/// the scrim under album artwork text.
abstract final class FixedTokens {
  static const brandGradient = [Color(0xFF1E2134), Color(0xFF2451C7)];
  static const artworkScrim = Color(0x73000000); // 45 % black
  static const white = Color(0xFFFFFFFF);
  static const transparent = Color(0x00000000);
}

/// Parses the album gradient colours from the catalogue ("#RRGGBB").
Color colorFromHex(String hex) {
  final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
  return Color(0xFF000000 | value);
}
