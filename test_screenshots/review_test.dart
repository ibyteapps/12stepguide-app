// Design review renders: every main screen, light and dark, phone and tablet.
//   flutter test test_screenshots/review_test.dart --update-goldens
// Output: test_screenshots/review/<device>/<screen>.png (not committed).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/features/audio/application/downloads_controller.dart';
import 'package:twelve_step_guide/features/audio/application/player_controller.dart';
import 'package:twelve_step_guide/features/audio/data/download_gateway.dart';

import '../test/helpers/test_app.dart';
import 'screenshot_harness.dart';

typedef Scenario = ({
  String name,
  String location,
  Map<String, Object> prefs,
  Future<void> Function(WidgetTester tester, TestApp app)? act,
});

const _premium = {PrefKeys.legacyLifetime: true, PrefKeys.legacySource: 'ios-donation'};

/// Starts album [albumId] at [index], as a tap on the track would.
Future<void> play(TestApp app, int albumId, int index, {int seconds = 0}) async {
  await app.container.read(playerProvider.notifier).playAlbum(testCatalogue.album(albumId)!, index);
  app.audio.emit(app.audio.value.copyWith(position: Duration(seconds: seconds)));
}

/// Some tracks downloaded, one downloading, one waiting.
void downloads(TestApp app, int albumId, {int done = 3}) {
  final album = testCatalogue.album(albumId)!;
  for (final t in album.tracks.take(done)) {
    writeTrackFile(app.audioDir, t, bytes: t.approxBytes ?? 1000000);
  }
  app.container.read(downloadsProvider.notifier).adopt([
    for (final t in album.tracks.take(done)) t.id,
  ]);
  if (album.tracks.length > done + 1) {
    app.downloads
      ..emit(DownloadEvent(album.tracks[done].id, DownloadEventKind.progress, progress: 0.62))
      ..emit(DownloadEvent(album.tracks[done + 1].id, DownloadEventKind.queued));
  }
}

/// Taps the first widget showing [text], then lets it settle.
Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await settleForCapture(tester);
}

final scenarios = <Scenario>[
  (name: 'steps', location: '/steps', prefs: {}, act: null),
  (name: 'traditions', location: '/steps', prefs: {PrefKeys.stepsSegment: 1}, act: null),
  (
    name: 'readings',
    location: '/readings',
    prefs: {PrefKeys.sobrietyDate: '2019-03-14'},
    act: null,
  ),
  (name: 'readings-empty', location: '/readings', prefs: {}, act: null),
  (name: 'big-book', location: '/big-book', prefs: {}, act: null),
  (
    name: 'reader-step',
    location: '/read?id=steps%2F04-step-4',
    prefs: {PrefKeys.coachMarkSeen: true},
    act: null,
  ),
  (
    name: 'reader-chapter5',
    location: '/read?id=big-book%2F06-chapter-5-how-it-works',
    prefs: {PrefKeys.coachMarkSeen: true},
    act: null,
  ),
  (
    name: 'recovery-date',
    location: '/recovery-date',
    prefs: {PrefKeys.sobrietyDate: '2019-03-14'},
    act: null,
  ),
  (name: 'appearance', location: '/appearance', prefs: {}, act: null),
  (name: 'drawer', location: '/steps', prefs: {}, act: (tester, _) => openDrawer(tester)),
  (
    name: 'audio',
    location: '/audio',
    prefs: _premium,
    act: (tester, app) async {
      downloads(app, 1, done: 34);
      downloads(app, 3, done: 4);
      await play(app, 1, 5, seconds: 740);
    },
  ),
  (
    name: 'album',
    location: '/audio/album/1',
    prefs: _premium,
    act: (tester, app) async {
      downloads(app, 1);
      await play(app, 1, 1, seconds: 312);
    },
  ),
  (
    name: 'player-transcript',
    location: '/player',
    prefs: {},
    act: (tester, app) => play(app, 2, 5, seconds: 1210),
  ),
  (
    name: 'player-artwork',
    location: '/player',
    prefs: {},
    act: (tester, app) => play(app, 9, 1, seconds: 1622),
  ),
  (name: 'premium', location: '/premium', prefs: {}, act: null),
  (
    name: 'reminders',
    location: '/reminders',
    prefs: {PrefKeys.hourlyEnabled: true, PrefKeys.hourlyStart: '08:00'},
    act: null,
  ),
  (name: 'quote', location: '/quote', prefs: {}, act: null),
  (name: 'premium-lifetime', location: '/premium', prefs: _premium, act: null),
  (name: 'paywall', location: '/paywall', prefs: {}, act: null),
  (
    name: 'downloads',
    location: '/downloads',
    prefs: _premium,
    act: (tester, app) async {
      downloads(app, 1, done: 12);
      downloads(app, 7, done: 9);
    },
  ),
  (name: 'onboarding', location: '/onboarding', prefs: {PrefKeys.onboardingDone: false}, act: null),
  (
    name: 'steps-pane',
    location: '/steps',
    prefs: {PrefKeys.coachMarkSeen: true},
    act: (tester, _) => tapText(tester, 'Step 4'),
  ),
  (
    name: 'big-book-pane',
    location: '/big-book',
    prefs: {PrefKeys.coachMarkSeen: true},
    act: (tester, _) => tapText(tester, 'Chapter 5: How It Works'),
  ),
  (
    name: 'audio-pane',
    location: '/audio',
    prefs: _premium,
    act: (tester, app) async {
      downloads(app, 1);
      await play(app, 1, 1, seconds: 312);
      await tapText(tester, 'Joe & Charlie - Big Book Study');
    },
  ),
  (name: 'about', location: '/about', prefs: {}, act: null),
  (name: 'other-apps', location: '/other-apps', prefs: {}, act: null),
];

void main() {
  setUpAll(() async {
    await loadFonts();
  });
  // Cached asset futures belong to the previous test's fake-async zone and never complete in
  // the next test, so each test loads its documents afresh.
  setUp(rootBundle.clear);

  for (final device in [androidPhone, iphone, tablet10, ipad]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final s in scenarios) {
        testWidgets('${device.id} ${mode.name} ${s.name}', (tester) async {
          debugDefaultTargetPlatformOverride = device.platform;
          debugDisableShadows = false;
          try {
            final app = await pumpApp(
              tester,
              location: s.location,
              prefs: s.prefs,
              size: device.size,
              ratio: device.ratio,
              themeMode: mode,
            );
            await settleForCapture(tester);
            await s.act?.call(tester, app);
            await settleForCapture(tester);
            await expectLater(
              find.byKey(appBoundaryKey),
              matchesGoldenFile('review/${device.id}/${s.name}-${mode.name}.png'),
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
            debugDisableShadows = true;
          }
        });
      }
    }
  }
}
