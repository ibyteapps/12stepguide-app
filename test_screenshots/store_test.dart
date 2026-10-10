// Store screenshots: the real app screens, rendered at each store's device size with real
// fonts and the device's safe areas, written as raw PNGs for tool/store_screenshots.py, which
// adds the status bar, the device frame and the caption.
//
//   flutter test test_screenshots/store_test.dart
//   python3 tool/store_screenshots.py
//
// Output: build/store_raw/<device>/<shot>.png and manifest.json (build/ is not committed).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/features/reminders/quote_screen.dart';

import '../test/helpers/test_app.dart';
import 'review_test.dart' show downloads, play, tapText;
import 'screenshot_harness.dart';

/// A store device: logical screen size, pixel ratio, platform and safe areas (logical px).
class StoreDevice {
  const StoreDevice(
    this.id,
    this.size,
    this.ratio,
    this.platform, {
    required this.top,
    required this.bottom,
  });

  final String id;
  final Size size;
  final double ratio;
  final TargetPlatform platform;
  final double top;
  final double bottom;

  bool get wide => size.width >= 840;
}

/// iPhone 16/17 Pro Max class (App Store 6.9"), iPad Pro 13", a typical Android phone, and
/// 7" and 10" Android tablets in portrait.
const storeDevices = [
  StoreDevice('iphone-6.9', Size(440, 956), 3, TargetPlatform.iOS, top: 62, bottom: 34),
  StoreDevice('ipad-13', Size(1032, 1376), 2, TargetPlatform.iOS, top: 24, bottom: 20),
  StoreDevice(
    'android-phone',
    Size(411.43, 914.29),
    2.625,
    TargetPlatform.android,
    top: 28,
    bottom: 24,
  ),
  StoreDevice('android-tablet-7', Size(600, 960), 2, TargetPlatform.android, top: 24, bottom: 24),
  StoreDevice('android-tablet-10', Size(800, 1280), 2, TargetPlatform.android, top: 24, bottom: 24),
];

typedef Shot = ({
  String id,
  String location,
  Map<String, Object> prefs,
  ThemeMode theme,
  Future<void> Function(WidgetTester tester, TestApp app)? act,
});

const _seen = {PrefKeys.coachMarkSeen: true};
const _premium = {
  PrefKeys.coachMarkSeen: true,
  PrefKeys.legacyLifetime: true,
  PrefKeys.legacySource: 'ios-donation',
};

/// The eight store shots, in listing order. Wide screens open a reading beside its list.
List<Shot> shotsFor(StoreDevice d) => [
  (
    id: '01-steps',
    location: '/steps',
    prefs: _seen,
    theme: ThemeMode.light,
    act: d.wide ? (t, _) => tapText(t, 'Step 4') : null,
  ),
  (
    id: '02-step-guide',
    location: d.wide ? '/readings' : '/read?id=steps%2F04-step-4',
    prefs: {..._seen, PrefKeys.sobrietyDate: '2019-03-14'},
    theme: ThemeMode.light,
    act: d.wide ? (t, _) => tapText(t, 'Just for Today') : null,
  ),
  (
    id: '03-big-book',
    location: '/big-book',
    prefs: _seen,
    theme: ThemeMode.light,
    act: d.wide ? (t, _) => tapText(t, 'Chapter 5: How It Works') : null,
  ),
  (
    id: '04-audio',
    location: '/audio',
    prefs: _premium,
    theme: ThemeMode.light,
    act: (t, app) async {
      downloads(app, 1, done: 34);
      downloads(app, 3, done: 4);
      await play(app, 1, 5, seconds: 740);
      if (d.wide) await tapText(t, 'Joe & Charlie - Big Book Study');
    },
  ),
  (
    id: '05-listen',
    location: '/player',
    prefs: _seen,
    theme: ThemeMode.dark,
    act: (t, app) => play(app, 2, 5, seconds: 1210),
  ),
  (
    id: '06-recovery',
    location: d.wide ? '/recovery-date' : '/readings',
    prefs: {..._seen, PrefKeys.sobrietyDate: '2019-03-14'},
    theme: ThemeMode.light,
    act: null,
  ),
  (id: '07-reminders', location: '/quote', prefs: _seen, theme: ThemeMode.light, act: null),
  (
    id: '08-dark',
    location: d.wide ? '/big-book' : '/read?id=big-book%2F06-chapter-5-how-it-works',
    prefs: {..._seen, PrefKeys.bigBookSegment: 2},
    theme: ThemeMode.dark,
    act: d.wide ? (t, _) => tapText(t, 'He Sold Himself Short') : null,
  ),
];

Future<void> capture(WidgetTester tester, StoreDevice device, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(appBoundaryKey));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: device.ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

void main() {
  setUpAll(loadFonts);
  // Cached asset futures belong to the previous test's fake-async zone and never complete in
  // the next test, so each test loads its documents afresh.
  setUp(rootBundle.clear);

  for (final device in storeDevices) {
    final shots = shotsFor(device);
    final dir = 'build/store_raw/${device.id}';

    for (final shot in shots) {
      testWidgets('${device.id} ${shot.id}', (tester) async {
        debugDefaultTargetPlatformOverride = device.platform;
        debugDisableShadows = false;
        final insets = FakeViewPadding(
          top: device.top * device.ratio,
          bottom: device.bottom * device.ratio,
        );
        tester.view.padding = insets;
        tester.view.viewPadding = insets;
        try {
          final app = await pumpApp(
            tester,
            location: shot.location,
            prefs: shot.prefs,
            size: device.size,
            ratio: device.ratio,
            themeMode: shot.theme,
            overrides: [
              quoteOfTheHourProvider.overrideWith(
                (ref) => 'Humility is not thinking less of yourself, but thinking of yourself less',
              ),
            ],
          );
          await settleForCapture(tester);
          await shot.act?.call(tester, app);
          await settleForCapture(tester);
          await capture(tester, device, '$dir/${shot.id}.png');
        } finally {
          debugDefaultTargetPlatformOverride = null;
          debugDisableShadows = true;
        }
      });
    }

    test('${device.id} manifest', () {
      final manifest = {
        'device': device.id,
        'platform': device.platform.name,
        'ratio': device.ratio,
        'logical': [device.size.width, device.size.height],
        'safeTop': device.top,
        'safeBottom': device.bottom,
        'shots': [
          for (final s in shots)
            {
              'id': s.id,
              'theme': s.theme.name,
              // White status-bar icons over dark screens and the blue quote screen.
              'lightStatusBar': s.theme == ThemeMode.dark || s.location == '/quote',
            },
        ],
      };
      File('$dir/manifest.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
    });
  }
}
