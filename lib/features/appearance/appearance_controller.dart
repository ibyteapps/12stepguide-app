import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/prefs/key_value_store.dart';
import '../../design/tokens/typography.dart';

@immutable
class AppearanceSettings {
  const AppearanceSettings({this.themeMode = ThemeMode.system, this.textStep = 3});

  final ThemeMode themeMode;

  /// Reading text size step, 1–8 (ReaderType.sizes).
  final int textStep;

  AppearanceSettings copyWith({ThemeMode? themeMode, int? textStep}) => AppearanceSettings(
    themeMode: themeMode ?? this.themeMode,
    textStep: textStep ?? this.textStep,
  );
}

/// Theme (System / Light / Dark) and reading text size, shared by the Aa sheet, the Appearance
/// page and the player transcript (UNIFIED_PRODUCT_SPEC S-12, S-53).
class AppearanceController extends Notifier<AppearanceSettings> {
  KeyValueStore get _store => ref.read(kvStoreProvider);

  @override
  AppearanceSettings build() {
    final store = ref.watch(kvStoreProvider);
    final mode = switch (store.getString(PrefKeys.themeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final step = (store.getInt(PrefKeys.textStep) ?? ReaderType.defaultStep).clamp(
      ReaderType.minStep,
      ReaderType.maxStep,
    );
    return AppearanceSettings(themeMode: mode, textStep: step);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _store.setString(PrefKeys.themeMode, mode.name);
  }

  Future<void> setTextStep(int step) async {
    final clamped = step.clamp(ReaderType.minStep, ReaderType.maxStep);
    state = state.copyWith(textStep: clamped);
    await _store.setInt(PrefKeys.textStep, clamped);
  }
}

final appearanceProvider = NotifierProvider<AppearanceController, AppearanceSettings>(
  AppearanceController.new,
);
