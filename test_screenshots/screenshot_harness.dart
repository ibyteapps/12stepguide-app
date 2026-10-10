// Renders real app screens with real fonts, for design review and store screenshots.
//
// Not part of CI: run locally with
//   flutter test test_screenshots --update-goldens
// then compose the store images with tool/store_screenshots.py.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/design/components/states.dart';

/// Device profiles: logical size and pixel ratio of the store's required screenshot sizes.
class Device {
  const Device(this.id, this.size, this.ratio, this.platform);

  final String id;
  final Size size;
  final double ratio;
  final TargetPlatform platform;

  bool get isIOS => platform == TargetPlatform.iOS;
}

/// App Store: 6.9" iPhone 1320×2868, 13" iPad 2064×2752. Google Play: phone 1080×2400,
/// 7" tablet 1200×1920, 10" tablet 1600×2560.
const iphone = Device('iphone-6.9', Size(440, 956), 3, TargetPlatform.iOS);
const ipad = Device('ipad-13', Size(1032, 1376), 2, TargetPlatform.iOS);
const androidPhone = Device('android-phone', Size(411.43, 914.29), 2.625, TargetPlatform.android);
const tablet7 = Device('android-tablet-7', Size(600, 960), 2, TargetPlatform.android);
const tablet10 = Device('android-tablet-10', Size(800, 1280), 2, TargetPlatform.android);

bool _fontsLoaded = false;

/// Loads the bundled icon fonts and real text fonts (Flutter tests otherwise draw text as
/// boxes). Roboto stands in for Android's system font, Inter for SF Pro on iOS.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<Object?>;
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    final loader = FontLoader(entry['family']! as String);
    for (final font in (entry['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/sdk/flutter';
  final roboto = '$flutterRoot/bin/cache/artifacts/material_fonts';
  const inter = '/usr/share/fonts/opentype/inter';

  Future<ByteData> file(String path) async =>
      ByteData.sublistView(Uint8List.fromList(await File(path).readAsBytes()));

  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      if (File(f).existsSync()) loader.addFont(file(f));
    }
    await loader.load();
  }

  final robotoFiles = [
    for (final w in ['Regular', 'Medium', 'Bold', 'Italic', 'MediumItalic', 'BoldItalic', 'Light'])
      '$roboto/Roboto-$w.ttf',
  ];
  final interFiles = [
    for (final w in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'Italic',
      'SemiBoldItalic',
      'BoldItalic',
      'MediumItalic',
    ])
      '$inter/Inter-$w.otf',
  ];
  await family('Roboto', robotoFiles);
  for (final name in [
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
  ]) {
    await family(name, interFiles);
  }
  await family('NotoColorEmoji', ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf']);
}

/// Lets asset loads (documents, images) finish, decodes every image on screen, then settles.
Future<void> settleForCapture(WidgetTester tester) async {
  // Long documents (a Big Book chapter) take a few seconds to parse on a busy CI machine.
  for (var i = 0; i < 80; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(milliseconds: 50));
    // A few rounds first: a tap may still be on its way to opening a reading.
    if (i >= 6 && find.byType(SkeletonLines).evaluate().isEmpty) break;
  }
  final images = find.byType(Image).evaluate().toList();
  await tester.runAsync(() async {
    for (final element in images) {
      final widget = element.widget as Image;
      await precacheImage(widget.image, element);
    }
  });
  await tester.pumpAndSettle();
}
