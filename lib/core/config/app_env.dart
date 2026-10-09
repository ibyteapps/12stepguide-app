/// The three build environments (FLUTTER_ARCHITECTURE.md §9).
///
/// Each one is a build flavour on both platforms (`--flavor dev|staging|prod`) paired with
/// `config/<env>.json` (`--dart-define-from-file`).
enum AppEnv {
  /// Local development and CI artefacts. Separate app id (`….dev`), Google test ads.
  dev,

  /// Production app ids, Google test ads, analytics collection off. TestFlight internal and
  /// Play internal testing only.
  staging,

  /// The store build.
  prod;

  /// Parses a flavour or `ENV` value. Returns null for anything that is not exactly one of the
  /// three names, so a typo is caught rather than treated as dev.
  static AppEnv? tryParse(String? value) {
    for (final env in values) {
      if (env.name == value) return env;
    }
    return null;
  }

  /// Only prod may serve live ads; dev and staging always use Google's published test units.
  bool get usesTestAds => this != prod;
}
