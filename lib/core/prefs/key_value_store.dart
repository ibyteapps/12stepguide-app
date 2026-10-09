import 'package:shared_preferences/shared_preferences.dart';

/// Small synchronous key–value storage for settings and bookkeeping (FLUTTER_ARCHITECTURE.md §9).
///
/// The app writes only its own prefixed keys (see [PrefKeys]); the native apps' data is read
/// through the legacy bridge and never touched (MIGRATION_PLAN.md §1).
abstract interface class KeyValueStore {
  String? getString(String key);
  int? getInt(String key);
  bool? getBool(String key);
  double? getDouble(String key);
  List<String>? getStringList(String key);
  bool containsKey(String key);
  Set<String> get keys;

  Future<void> setString(String key, String value);
  Future<void> setInt(String key, int value);
  Future<void> setBool(String key, bool value);
  Future<void> setDouble(String key, double value);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}

/// The production store: `SharedPreferencesWithCache`, loaded once at start-up so reads are
/// synchronous afterwards.
class SharedPrefsStore implements KeyValueStore {
  SharedPrefsStore._(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<SharedPrefsStore> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    return SharedPrefsStore._(prefs);
  }

  @override
  String? getString(String key) => _prefs.getString(key);
  @override
  int? getInt(String key) => _prefs.getInt(key);
  @override
  bool? getBool(String key) => _prefs.getBool(key);
  @override
  double? getDouble(String key) => _prefs.getDouble(key);
  @override
  List<String>? getStringList(String key) => _prefs.getStringList(key);
  @override
  bool containsKey(String key) => _prefs.containsKey(key);
  @override
  Set<String> get keys => _prefs.keys;
  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  @override
  Future<void> setDouble(String key, double value) => _prefs.setDouble(key, value);
  @override
  Future<void> setStringList(String key, List<String> value) => _prefs.setStringList(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// In-memory store for tests and previews.
class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, Object>? initial]) : _values = {...?initial};

  final Map<String, Object> _values;

  Map<String, Object> get values => Map.unmodifiable(_values);

  @override
  String? getString(String key) => _values[key] as String?;
  @override
  int? getInt(String key) => _values[key] as int?;
  @override
  bool? getBool(String key) => _values[key] as bool?;
  @override
  double? getDouble(String key) => _values[key] as double?;
  @override
  List<String>? getStringList(String key) => (_values[key] as List<String>?)?.toList();
  @override
  bool containsKey(String key) => _values.containsKey(key);
  @override
  Set<String> get keys => _values.keys.toSet();
  @override
  Future<void> setString(String key, String value) async => _values[key] = value;
  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;
  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;
  @override
  Future<void> setDouble(String key, double value) async => _values[key] = value;
  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = List<String>.of(value);
  @override
  Future<void> remove(String key) async => _values.remove(key);
}

/// Every key the app writes. Prefixes follow MIGRATION_PLAN.md §1.
abstract final class PrefKeys {
  // App
  static const launchCount = 'app.launchCount';
  static const lastTab = 'app.lastTab';
  static const firstLaunchAt = 'app.firstLaunchAt';
  static const lastOpenedAt = 'app.lastOpenedAt';

  // Onboarding and upgrade
  static const onboardingDone = 'onboarding.done';
  static const welcomeBackPending = 'onboarding.welcomeBackPending';

  // Appearance and reading
  static const themeMode = 'appearance.theme';
  static const textStep = 'reader.textStep';
  static const readingPositions = 'reader.positions';
  static const lastRead = 'reader.lastRead';
  static const coachMarkSeen = 'reader.coachMarkSeen';
  static const stepsSegment = 'steps.segment';
  static const bigBookSegment = 'bigBook.segment';

  // Sobriety
  static const sobrietyDate = 'sobriety.date';

  // Premium
  static const legacyLifetime = 'premium.legacyLifetime';
  static const legacySource = 'premium.legacySource';
  static const premiumCache = 'premium.cache';
  static const paywallShownAtLaunches = 'premium.paywallShownAt';

  // Ads
  static const contentOpenCount = 'ads.contentOpenCount';
  static const lastAppOpenAt = 'ads.lastAppOpenAt';

  // Review
  static const reviewPromptCount = 'review.promptCount';
  static const reviewRated = 'review.rated';
  static const reviewPromptedAtLaunches = 'review.promptedAt';

  // Reminders
  static const hourlyEnabled = 'reminders.hourly.enabled';
  static const hourlyStart = 'reminders.hourly.start';
  static const hourlyEnd = 'reminders.hourly.end';
  static const nudgesEnabled = 'reminders.nudges.enabled';

  // Audio
  static const trackPositions = 'audio.positions';
  static const lastTrack = 'audio.lastTrack';
  static const transcriptStep = 'audio.transcriptStep';
  static const wifiOnly = 'downloads.wifiOnly';
  static const downloadedTracks = 'downloads.tracks';

  // Migration
  static const migrationVersion = 'migration.version';
  static const migrationCompletedAt = 'migration.completedAt';
  static const migrationSummary = 'migration.summary';
  static String migrationStep(String id) => 'migration.step.$id';
}
