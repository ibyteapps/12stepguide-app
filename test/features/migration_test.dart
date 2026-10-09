// Migration fixtures (MIGRATION_PLAN.md §11): each legacy scenario, run twice, legacy data never
// changed.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/app/bootstrap.dart';
import 'package:twelve_step_guide/core/platform/legacy_bridge.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/features/migration/migration.dart';

import '../helpers/test_app.dart';

class FixtureBridge implements LegacyBridge {
  FixtureBridge(Map<String, Object?> prefs, {this.throws = false})
    : prefs = Map.unmodifiable(prefs);

  final Map<String, Object?> prefs;
  final bool throws;
  final cancelled = <String>[];

  @override
  Future<Map<String, Object?>> readPrefs() async {
    if (throws) throw StateError('channel down');
    return prefs;
  }

  @override
  Future<List<LegacyNotification>> pendingNotifications() async => const [];
  @override
  Future<void> cancelNotifications(List<String> ids) async => cancelled.addAll(ids);
  @override
  Future<List<LegacyFile>> listDocuments() async => const [];
  @override
  Future<void> excludeFromBackup(String path) async {}
}

class _Boom extends MigrationStep {
  const _Boom();
  @override
  String get id => 'm999';
  @override
  Set<LegacyPlatform> get platforms => LegacyPlatform.values.toSet();
  @override
  Future<void> run(MigrationContext ctx) => throw StateError('boom');
}

final now = DateTime(2026, 10, 9, 10);

Future<MigrationOutcome> migrate(
  KeyValueStore store,
  LegacyBridge bridge,
  LegacyPlatform platform, {
  List<MigrationStep>? steps,
}) => MigrationRunner(
  store: store,
  bridge: bridge,
  platform: platform,
  steps: steps ?? migrationSteps(testCatalogue),
  now: now,
).run();

MigrationSummary summary(KeyValueStore store) => MigrationSummary.fromJson(
  jsonDecode(store.getString(PrefKeys.migrationSummary)!) as Map<String, Object?>,
);

void main() {
  test('new user: nothing migrated, onboarding still shown', () async {
    final store = MemoryStore();
    final outcome = await migrate(store, FixtureBridge({}), LegacyPlatform.ios);
    expect(outcome.isUpgrade, isFalse);
    expect(store.getBool(PrefKeys.onboardingDone), isNull);
    expect(store.getBool(PrefKeys.welcomeBackPending), isNull);
    expect(store.getInt(PrefKeys.migrationVersion), 1);
  });

  test('unrelated system keys do not make a new user look like an upgrade', () async {
    final store = MemoryStore();
    final outcome = await migrate(
      store,
      FixtureBridge({'AppleLanguages': 'en', 'flutter.something': 1, 'app.launchCount': 3}),
      LegacyPlatform.ios,
    );
    expect(outcome.isUpgrade, isFalse);
  });

  group('iOS', () {
    test('subscriber: cached annual Premium, text size, launches, welcome back', () async {
      final store = MemoryStore();
      final bridge = FixtureBridge({
        'launchcount': 23,
        'launchCount': -1,
        'FLAG_ONBOARDING_UPDATE_SHOWN': true,
        'KEY_DATA_INT_FONT_SIZE': 24,
        'annual_PURCHASED': true,
        'KEY_SUBSCRIPTION_EXPIRY': '3 Mar 2027',
        'KEY_DATA_INT_TAP_COUNT': 17,
        'LastShownAppOpenAd': 1760000000000,
      });
      final outcome = await migrate(store, bridge, LegacyPlatform.ios);
      expect(outcome.isUpgrade, isTrue);
      expect(outcome.failed, isEmpty);
      expect(store.getInt(PrefKeys.launchCount), 23);
      expect(store.getBool(PrefKeys.onboardingDone), isTrue);
      expect(store.getInt(PrefKeys.textStep), 6);
      expect(jsonDecode(store.getString(PrefKeys.premiumCache)!), containsPair('annual', true));
      expect(store.getBool(PrefKeys.legacyLifetime), isNull);
      expect(store.getInt(PrefKeys.contentOpenCount), 17 % 3);
      expect(store.getInt(PrefKeys.lastAppOpenAt), 1760000000000);
      expect(store.getBool(PrefKeys.welcomeBackPending), isTrue);
      expect(summary(store).premium, 'annual');
      expect(summary(store).textSize, isTrue);
    });

    test('legacy donor: lifetime Premium that is never cleared', () async {
      final store = MemoryStore();
      await migrate(
        store,
        FixtureBridge({
          'launchcount': 4,
          'com.ibyteapps.aa12stepguide.donatetier10_PURCHASED': true,
        }),
        LegacyPlatform.ios,
      );
      expect(store.getBool(PrefKeys.legacyLifetime), isTrue);
      expect(store.getString(PrefKeys.legacySource), 'ios-donation');
      expect(summary(store).premium, 'lifetime');
    });

    test('font sizes map to the 8-step scale', () {
      expect(TextSizeStep.fromIosPixels(0), 3);
      expect(TextSizeStep.fromIosPixels(18), 3);
      expect(TextSizeStep.fromIosPixels(24), 6);
      expect(TextSizeStep.fromIosPixels(30), 8);
      expect(TextSizeStep.fromIosPixels(21), 4); // nearest: 20
    });
  });

  group('Android', () {
    test('donor with a sobriety date and larger text', () async {
      final store = MemoryStore();
      await migrate(
        store,
        FixtureBridge({
          'mKeyStepDatalaunchCount_aa12stepguide_aa12stepguide': 41,
          'onBoardingShown': true,
          'myAppDay': 1,
          'myAppMonth': 11,
          'myAppYear': 2012,
          'mKeyStepDatahtmlsize_aa12stepguide': 3,
          'donatetier2_aa12stepguidepurchased_aa12stepguide': true,
          'mKeyStepDatatimeShownLiterature_aa12stepguide_aa12stepguide': 8,
          'mKeyStepDatarate_shown_aa12stepguide': 2,
          'ratedapp_aa12stepguide': true,
          '2131230979COUNT_TIPPED_aa12stepguide': 2,
          'tabno': 3,
          'accountid': -1,
        }),
        LegacyPlatform.android,
      );
      expect(store.getInt(PrefKeys.launchCount), 41);
      expect(store.getString(PrefKeys.sobrietyDate), '2012-11-01');
      expect(store.getInt(PrefKeys.textStep), 6);
      expect(store.getBool(PrefKeys.legacyLifetime), isTrue);
      expect(store.getString(PrefKeys.legacySource), 'android-donation');
      expect(store.getInt(PrefKeys.contentOpenCount), 2);
      expect(store.getInt(PrefKeys.reviewPromptCount), 2);
      expect(store.getBool(PrefKeys.reviewRated), isTrue);
      expect(store.getBool(PrefKeys.coachMarkSeen), isTrue);
      final s = summary(store);
      expect(s.sobrietyDate, isTrue);
      expect(s.premium, 'lifetime');
      expect(s.platform, LegacyPlatform.android);
    });

    test('a future date is clamped to today; an impossible one is left unset', () async {
      final future = MemoryStore();
      await migrate(
        future,
        FixtureBridge({'myAppDay': 1, 'myAppMonth': 1, 'myAppYear': 2030}),
        LegacyPlatform.android,
      );
      expect(future.getString(PrefKeys.sobrietyDate), '2026-10-09');

      final impossible = MemoryStore();
      await migrate(
        impossible,
        FixtureBridge({'myAppDay': 31, 'myAppMonth': 2, 'myAppYear': 2020}),
        LegacyPlatform.android,
      );
      expect(impossible.getString(PrefKeys.sobrietyDate), isNull);
    });

    test('a date never set (0) stays unset', () async {
      final store = MemoryStore();
      await migrate(
        store,
        FixtureBridge({'myAppDay': 0, 'myAppMonth': 0, 'myAppYear': 0, 'onBoardingShown': true}),
        LegacyPlatform.android,
      );
      expect(store.getString(PrefKeys.sobrietyDate), isNull);
    });

    test('zoom steps 0 / 3 / 6 map to 3 / 6 / 8', () {
      expect(TextSizeStep.fromAndroidZoom(0), 3);
      expect(TextSizeStep.fromAndroidZoom(3), 6);
      expect(TextSizeStep.fromAndroidZoom(6), 8);
    });
  });

  group('runner', () {
    test('running twice is a no-op and the welcome screen is offered once', () async {
      final store = MemoryStore();
      final bridge = FixtureBridge({'launchcount': 9, 'KEY_DATA_INT_FONT_SIZE': 30});
      await migrate(store, bridge, LegacyPlatform.ios);
      await store.setBool(PrefKeys.welcomeBackPending, false); // seen
      await store.setInt(PrefKeys.textStep, 2); // user changed it since
      final before = Map.of(store.values);
      await migrate(store, bridge, LegacyPlatform.ios);
      expect(store.values, before);
      expect(store.getInt(PrefKeys.textStep), 2);
    });

    test('a failing step is recorded, retried next launch, and blocks nothing', () async {
      final store = MemoryStore();
      final bridge = FixtureBridge({'launchcount': 3, 'KEY_DATA_INT_FONT_SIZE': 30});
      final steps = [...migrationSteps(testCatalogue), const _Boom()];
      final first = await migrate(store, bridge, LegacyPlatform.ios, steps: steps);
      expect(first.failed, ['m999']);
      expect(store.getInt(PrefKeys.textStep), 8);
      expect(store.getString(PrefKeys.migrationStep('m999')), 'failed');
      final second = await migrate(store, bridge, LegacyPlatform.ios, steps: steps);
      expect(second.failed, ['m999']);
    });

    test('an unreadable legacy store never stops the app', () async {
      final store = MemoryStore();
      final outcome = await migrate(store, FixtureBridge({}, throws: true), LegacyPlatform.ios);
      expect(outcome.isUpgrade, isFalse);
      expect(outcome.failed, ['snapshot']);
    });

    test('the legacy data itself is never modified', () async {
      final prefs = {'launchcount': 5, 'annual_PURCHASED': true};
      final bridge = FixtureBridge(prefs);
      await migrate(MemoryStore(), bridge, LegacyPlatform.ios);
      expect(bridge.prefs, prefs);
      expect(bridge.cancelled, isEmpty);
    });
  });

  group('launch preparation', () {
    test('counts launches on top of the migrated count', () async {
      final store = MemoryStore();
      final launch = await prepareLaunch(
        store: store,
        bridge: FixtureBridge({'launchcount': 23}),
        steps: migrationSteps(testCatalogue),
        clock: () => now,
      );
      // Tests run as Android, so the iOS key is not recognised: a first launch.
      expect(launch.launchCount, 1);
      expect(store.getString(PrefKeys.firstLaunchAt), isNotNull);
    });
  });
}
