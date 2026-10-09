import 'package:flutter/services.dart' show appFlavor;

import 'app_env.dart';

/// Build-time configuration.
///
/// Values come from two places that must agree:
/// - the build flavour (`--flavor`), which picks the app id, name and native settings;
/// - `config/<env>.json` (`--dart-define-from-file`), which supplies the Dart-side values.
///
/// Keys are added here with the features that read them (FLUTTER_ARCHITECTURE.md §9).
class AppConfig {
  const AppConfig({required this.env});

  final AppEnv env;

  /// The configuration this binary was built with.
  static AppConfig fromBuild() =>
      AppConfig.resolve(flavor: appFlavor, envDefine: const String.fromEnvironment('ENV'));

  /// Checks the flavour and the config file against each other.
  ///
  /// - No flavour and no config (unit tests, a bare `flutter run` from an IDE): dev.
  /// - dev without a config file: allowed, dev has safe defaults.
  /// - staging or prod without a config file: refused, the build would ship missing values.
  /// - flavour and config naming different environments: refused, e.g. a prod app id with
  ///   dev values.
  static AppConfig resolve({required String? flavor, required String envDefine}) {
    final hasFlavor = flavor != null && flavor.isNotEmpty;
    final hasEnv = envDefine.isNotEmpty;

    final fromFlavor = hasFlavor ? AppEnv.tryParse(flavor) : null;
    if (hasFlavor && fromFlavor == null) {
      throw ConfigException('Unknown build flavour "$flavor". Use dev, staging or prod.');
    }
    final fromEnv = hasEnv ? AppEnv.tryParse(envDefine) : null;
    if (hasEnv && fromEnv == null) {
      throw ConfigException(
        'Unknown ENV "$envDefine" in the config file. Use dev, staging or prod.',
      );
    }

    if (fromFlavor != null && fromEnv != null && fromFlavor != fromEnv) {
      throw ConfigException(
        'The build flavour is ${fromFlavor.name} but the config file is for '
        '${fromEnv.name}. Build with --flavor ${fromFlavor.name} '
        '--dart-define-from-file=config/${fromFlavor.name}.json.',
      );
    }
    if (fromFlavor != null && fromEnv == null && fromFlavor != AppEnv.dev) {
      throw ConfigException(
        'This ${fromFlavor.name} build has no config. Build with '
        '--dart-define-from-file=config/${fromFlavor.name}.json.',
      );
    }

    return AppConfig(env: fromFlavor ?? fromEnv ?? AppEnv.dev);
  }
}

/// Thrown when the build's flavour and config file are missing or disagree.
class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}
