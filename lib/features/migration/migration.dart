import 'dart:convert';

import '../../core/logging/log.dart';
import '../../core/platform/legacy_bridge.dart';
import '../../core/prefs/key_value_store.dart';
import '../../design/tokens/typography.dart';
import '../audio/domain/catalogue.dart';
import '../sobriety/sobriety_date.dart';
import 'legacy_keys.dart';

enum LegacyPlatform { ios, android }

/// What the native app left behind, read once at start-up (read only).
class LegacySnapshot {
  const LegacySnapshot({required this.platform, required this.prefs});

  final LegacyPlatform platform;
  final Map<String, Object?> prefs;

  /// Conservative upgrade detection (MIGRATION_PLAN §1.4): any recognised key means the native
  /// app ran here, so the user must not be treated as new.
  bool get isUpgrade {
    final keys = platform == LegacyPlatform.ios ? IosKeys.recognised : AndroidKeys.recognised;
    return keys.any(prefs.containsKey);
  }

  int? int_(String key) {
    final v = prefs[key];
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  bool bool_(String key) {
    final v = prefs[key];
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return false;
  }

  String? string_(String key) {
    final v = prefs[key];
    return v is String ? v : null;
  }
}

/// What came across, for the Welcome-back screen (S-03).
class MigrationSummary {
  MigrationSummary({required this.platform});

  factory MigrationSummary.fromJson(Map<String, Object?> j) =>
      MigrationSummary(
          platform: j['platform'] == 'android' ? LegacyPlatform.android : LegacyPlatform.ios,
        )
        ..sobrietyDate = j['sobriety'] == true
        ..reminders = j['reminders'] == true
        ..downloads = (j['downloads'] as int?) ?? 0
        ..premium = j['premium'] as String?
        ..textSize = j['textSize'] == true;

  final LegacyPlatform platform;
  bool sobrietyDate = false;
  bool reminders = false;
  int downloads = 0;

  /// "lifetime" or "annual", when Premium came across.
  String? premium;
  bool textSize = false;

  Map<String, Object?> toJson() => {
    'platform': platform.name,
    'sobriety': sobrietyDate,
    'reminders': reminders,
    'downloads': downloads,
    'premium': ?premium,
    'textSize': textSize,
  };
}

class MigrationContext {
  MigrationContext({
    required this.snapshot,
    required this.store,
    required this.bridge,
    required this.now,
    required this.summary,
  });

  final LegacySnapshot snapshot;
  final KeyValueStore store;
  final LegacyBridge bridge;
  final DateTime now;
  final MigrationSummary summary;
}

/// One idempotent migration step (MIGRATION_PLAN §3).
abstract class MigrationStep {
  const MigrationStep();

  String get id;
  Set<LegacyPlatform> get platforms;
  Future<void> run(MigrationContext ctx);
}

// --- Steps ----------------------------------------------------------------------------------

/// m001: launch counter and onboarding flags.
class LaunchAndOnboardingStep extends MigrationStep {
  const LaunchAndOnboardingStep();
  @override
  String get id => 'm001';
  @override
  Set<LegacyPlatform> get platforms => LegacyPlatform.values.toSet();

  @override
  Future<void> run(MigrationContext ctx) async {
    final s = ctx.snapshot;
    final legacyCount = s.platform == LegacyPlatform.ios
        ? [
            s.int_(IosKeys.launchCount) ?? 0,
            s.int_(IosKeys.launchCountOld) ?? 0,
          ].reduce((a, b) => a > b ? a : b)
        : s.int_(AndroidKeys.launchCount) ?? 0;
    final current = ctx.store.getInt(PrefKeys.launchCount) ?? 0;
    if (legacyCount > current) await ctx.store.setInt(PrefKeys.launchCount, legacyCount);
    // Any legacy data means this person already knows the app: no first-run onboarding.
    if (s.isUpgrade) await ctx.store.setBool(PrefKeys.onboardingDone, true);
  }
}

/// m002: the Android sobriety date (myAppDay / myAppMonth / myAppYear; month is 1-based).
class SobrietyDateStep extends MigrationStep {
  const SobrietyDateStep();
  @override
  String get id => 'm002';
  @override
  Set<LegacyPlatform> get platforms => {LegacyPlatform.android};

  @override
  Future<void> run(MigrationContext ctx) async {
    final s = ctx.snapshot;
    final d = s.int_(AndroidKeys.day) ?? 0;
    final m = s.int_(AndroidKeys.month) ?? 0;
    final y = s.int_(AndroidKeys.year) ?? 0;
    if (d < 1) return; // 0 = never set
    final date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d || y < 1900) {
      Log.w('m002: legacy sobriety date is not a real date; left unset');
      return;
    }
    final today = DateTime(ctx.now.year, ctx.now.month, ctx.now.day);
    final value = date.isAfter(today) ? today : date;
    await ctx.store.setString(PrefKeys.sobrietyDate, SobrietyDate.toIso(value));
    ctx.summary.sobrietyDate = true;
  }
}

/// m003: reader text size. iOS 18 / 24 / 30 px and Android 0 / 3 / 6 map to steps 3 / 6 / 8.
class TextSizeStep extends MigrationStep {
  const TextSizeStep();
  @override
  String get id => 'm003';
  @override
  Set<LegacyPlatform> get platforms => LegacyPlatform.values.toSet();

  static int fromIosPixels(int px) {
    if (px <= 0) return 3;
    var best = 1;
    for (var step = 1; step <= ReaderType.sizes.length; step++) {
      if ((ReaderType.sizes[step - 1] - px).abs() < (ReaderType.sizes[best - 1] - px).abs()) {
        best = step;
      }
    }
    return best;
  }

  static int fromAndroidZoom(int zoom) => switch (zoom) {
    <= 1 => 3,
    <= 4 => 6,
    _ => 8,
  };

  @override
  Future<void> run(MigrationContext ctx) async {
    final s = ctx.snapshot;
    final int? step;
    if (s.platform == LegacyPlatform.ios) {
      final px = s.int_(IosKeys.fontSize);
      step = px == null ? null : fromIosPixels(px);
    } else {
      final zoom = s.int_(AndroidKeys.textZoom);
      step = zoom == null ? null : fromAndroidZoom(zoom);
    }
    if (step == null) return;
    await ctx.store.setInt(PrefKeys.textStep, step);
    ctx.summary.textSize = step != ReaderType.defaultStep;
  }
}

/// m004: Premium. Legacy lifetime supporters keep Premium for good; a cached iOS subscription
/// bridges the first launch until StoreKit answers (MIGRATION_PLAN §5).
class PremiumStep extends MigrationStep {
  const PremiumStep();
  @override
  String get id => 'm004';
  @override
  Set<LegacyPlatform> get platforms => LegacyPlatform.values.toSet();

  @override
  Future<void> run(MigrationContext ctx) async {
    final s = ctx.snapshot;
    final ios = s.platform == LegacyPlatform.ios;
    final flags = ios ? IosKeys.donationFlags : AndroidKeys.donationFlags;
    if (flags.any(s.bool_)) {
      await ctx.store.setBool(PrefKeys.legacyLifetime, true);
      await ctx.store.setString(PrefKeys.legacySource, ios ? 'ios-donation' : 'android-donation');
      ctx.summary.premium = 'lifetime';
      return;
    }
    if (ios && s.bool_(IosKeys.annualPurchased)) {
      await ctx.store.setString(
        PrefKeys.premiumCache,
        jsonEncode({'annual': true, 'lifetime': false, 'source': 'legacy'}),
      );
      ctx.summary.premium = 'annual';
    }
  }
}

/// m005: advert pacing, so an upgrade does not bring an immediate advert.
class AdPacingStep extends MigrationStep {
  const AdPacingStep();
  @override
  String get id => 'm005';
  @override
  Set<LegacyPlatform> get platforms => LegacyPlatform.values.toSet();

  @override
  Future<void> run(MigrationContext ctx) async {
    final s = ctx.snapshot;
    final count = s.platform == LegacyPlatform.ios
        ? s.int_(IosKeys.tapCount)
        : s.int_(AndroidKeys.contentOpens);
    if (count != null) await ctx.store.setInt(PrefKeys.contentOpenCount, count.abs() % 3);
    if (s.platform == LegacyPlatform.ios) {
      final lastAppOpen = s.int_(IosKeys.lastAppOpenAd); // ms since epoch, from the bridge
      if (lastAppOpen != null && lastAppOpen > 0) {
        await ctx.store.setInt(PrefKeys.lastAppOpenAt, lastAppOpen);
      }
    }
  }
}

/// m006: rate-prompt bookkeeping (Android), so people who rated are not asked again.
class ReviewStep extends MigrationStep {
  const ReviewStep();
  @override
  String get id => 'm006';
  @override
  Set<LegacyPlatform> get platforms => {LegacyPlatform.android};

  @override
  Future<void> run(MigrationContext ctx) async {
    final s = ctx.snapshot;
    final shown = s.int_(AndroidKeys.rateShown);
    if (shown != null) await ctx.store.setInt(PrefKeys.reviewPromptCount, shown);
    if (s.bool_(AndroidKeys.ratedApp) || s.bool_(AndroidKeys.rated)) {
      await ctx.store.setBool(PrefKeys.reviewRated, true);
    }
  }
}

/// m007: the native iOS app's reminders (MIGRATION_PLAN §6). The setting follows what users
/// actually receive — hourly is on only if hourly requests are pending (A-12, BUG-03) — and the
/// stored window is kept. The native requests are then cancelled so nothing arrives twice. If
/// cancelling fails, nothing is written and the new app schedules nothing until a later launch
/// succeeds.
class RemindersStep extends MigrationStep {
  const RemindersStep();
  @override
  String get id => 'm007';
  @override
  Set<LegacyPlatform> get platforms => {LegacyPlatform.ios};

  /// Every identifier the native app could have used (MIGRATION_PLAN §6).
  static List<String> legacyIds() => [
    for (var h = 0; h < 24; h++) 'HourNotification$h$h',
    IosKeys.morningTime,
    IosKeys.nightTime,
    '3days',
    '7days',
  ];

  @override
  Future<void> run(MigrationContext ctx) async {
    final s = ctx.snapshot;
    final pending = await ctx.bridge.pendingNotifications();
    final hourlyOn = pending.any((n) => n.id.startsWith('HourNotification'));
    final start = _time(s.string_(IosKeys.hourlyStart)) ?? '08:00';
    final end = _time(s.string_(IosKeys.hourlyEnd)) ?? '22:00';
    // Morning and night reminders were unreachable (A-18): anything found is cancelled.
    await ctx.bridge.cancelNotifications({...legacyIds(), for (final n in pending) n.id}.toList());
    await ctx.store.setString(PrefKeys.hourlyStart, start);
    await ctx.store.setString(PrefKeys.hourlyEnd, end);
    await ctx.store.setBool(PrefKeys.hourlyEnabled, hourlyOn);
    ctx.summary.reminders = hourlyOn;
  }

  static String? _time(String? v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v?.trim() ?? '');
    if (m == null) return null;
    final h = int.parse(m[1]!), min = int.parse(m[2]!);
    if (h > 23 || min > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${m[2]}';
  }
}

/// m008: recordings the native iOS app downloaded into `Documents` (MIGRATION_PLAN §7). They stay
/// where they are and are marked downloaded, so nobody downloads them twice; from now on they are
/// kept out of iCloud backups. Anything that is not a catalogue file (`main.db`, unknown files) is
/// left alone.
class DownloadsStep extends MigrationStep {
  const DownloadsStep(this.catalogue);

  final Catalogue catalogue;

  @override
  String get id => 'm008';
  @override
  Set<LegacyPlatform> get platforms => {LegacyPlatform.ios};

  /// The catalogue sizes come from one-decimal "4.5 MB" labels, so the check allows for that
  /// rounding (and for MB/MiB) while still turning away a truncated file.
  static bool sizeMatches(Track track, int bytes) {
    if (bytes <= 0) return false;
    final approx = track.approxBytes;
    if (approx == null) return true;
    return bytes >= approx * 0.9 && bytes <= approx * 1.15;
  }

  @override
  Future<void> run(MigrationContext ctx) async {
    final byName = {for (final t in catalogue.allTracks) t.file: t};
    final found = <int>[];
    for (final file in await ctx.bridge.listDocuments()) {
      final track = byName[file.name];
      if (track == null || !sizeMatches(track, file.bytes)) continue;
      found.add(track.id);
      await ctx.bridge.excludeFromBackup(file.path);
    }
    final existing = ctx.store.getStringList(PrefKeys.downloadedTracks) ?? const [];
    await ctx.store.setStringList(
      PrefKeys.downloadedTracks,
      {...existing, for (final id in found) '$id'}.toList(),
    );
    ctx.summary.downloads = found.length;
  }
}

/// m010: the font-size tooltip was already shown (Android).
class CoachMarkStep extends MigrationStep {
  const CoachMarkStep();
  @override
  String get id => 'm010';
  @override
  Set<LegacyPlatform> get platforms => {LegacyPlatform.android};

  @override
  Future<void> run(MigrationContext ctx) async {
    final seen = ctx.snapshot.prefs.entries.any(
      (e) => e.key.endsWith(AndroidKeys.tooltipSuffix) && (e.value is int) && (e.value! as int) > 0,
    );
    if (seen) await ctx.store.setBool(PrefKeys.coachMarkSeen, true);
  }
}

// --- Runner ---------------------------------------------------------------------------------

class MigrationOutcome {
  const MigrationOutcome({required this.isUpgrade, required this.failed});

  final bool isUpgrade;
  final List<String> failed;
}

/// Runs each step not yet done, records `done`/`failed`, never stops the app, and never touches
/// legacy data beyond the explicit iOS notification cancel (MIGRATION_PLAN §3).
class MigrationRunner {
  MigrationRunner({
    required this.store,
    required this.bridge,
    required this.platform,
    required this.steps,
    required this.now,
  });

  final KeyValueStore store;
  final LegacyBridge bridge;
  final LegacyPlatform platform;
  final List<MigrationStep> steps;
  final DateTime now;

  static const version = 1;

  Future<MigrationOutcome> run() async {
    Map<String, Object?> prefs;
    try {
      prefs = await bridge.readPrefs();
    } on Object catch (error, stack) {
      Log.e('Migration: legacy prefs unreadable', error, stack);
      return const MigrationOutcome(isUpgrade: false, failed: ['snapshot']);
    }
    final snapshot = LegacySnapshot(platform: platform, prefs: prefs);
    final previous = store.getString(PrefKeys.migrationSummary);
    final summary = previous == null
        ? MigrationSummary(platform: platform)
        : MigrationSummary.fromJson(jsonDecode(previous) as Map<String, Object?>);
    final ctx = MigrationContext(
      snapshot: snapshot,
      store: store,
      bridge: bridge,
      now: now,
      summary: summary,
    );

    if (!snapshot.isUpgrade) {
      await store.setInt(PrefKeys.migrationVersion, version);
      return const MigrationOutcome(isUpgrade: false, failed: []);
    }

    final firstTime = store.getInt(PrefKeys.migrationVersion) == null;
    final failed = <String>[];
    for (final step in steps) {
      if (!step.platforms.contains(platform)) continue;
      final key = PrefKeys.migrationStep(step.id);
      if (store.getString(key) == 'done') continue;
      try {
        await step.run(ctx);
        await store.setString(key, 'done');
      } on Object catch (error, stack) {
        failed.add(step.id);
        await store.setString(key, 'failed');
        Log.e('Migration step ${step.id} failed; it will retry next launch', error, stack);
      }
    }
    await store.setString(PrefKeys.migrationSummary, jsonEncode(summary.toJson()));
    if (firstTime) {
      await store.setInt(PrefKeys.migrationVersion, version);
      await store.setString(PrefKeys.migrationCompletedAt, now.toIso8601String());
      await store.setBool(PrefKeys.welcomeBackPending, true);
    }
    return MigrationOutcome(isUpgrade: true, failed: failed);
  }
}
