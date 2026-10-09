// The app icon files that tool/build_icons.py generates (D-007) are all present, the right
// size and the right kind of PNG, and each flavour points at its own icon.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _flavors = ['dev', 'staging', 'prod'];
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

/// PNG colour types from the IHDR chunk.
const _grey = 0;
const _rgb = 2;
const _rgba = 6;

class _Png {
  _Png(this.width, this.height, this.colorType);

  factory _Png.read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    final bytes = file.readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    expect(bytes.sublist(12, 16), ascii.encode('IHDR'), reason: path);
    return _Png(data.getUint32(16), data.getUint32(20), bytes[25]);
  }

  final int width;
  final int height;
  final int colorType;
}

void main() {
  group('iOS', () {
    String iconSetFor(String flavor) =>
        RegExp(r'^APP_ICON_NAME = (\S+)$', multiLine: true)
            .firstMatch(
              File('ios/Flutter/$flavor.xcconfig').readAsStringSync(),
            )!
            .group(1)!;

    test('each flavour has its own icon set', () {
      expect(iconSetFor('prod'), 'AppIcon');
      expect(iconSetFor('staging'), 'AppIcon-staging');
      expect(iconSetFor('dev'), 'AppIcon-dev');
      expect(
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
        isNot(contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;')),
        reason: 'the target must take the icon set from the flavour',
      );
    });

    for (final flavor in _flavors) {
      test('$flavor icon set lists files that exist, 1024 px', () {
        final dir =
            'ios/Runner/Assets.xcassets/${iconSetFor(flavor)}.appiconset';
        final contents = jsonDecode(
          File('$dir/Contents.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final images = (contents['images'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (final image in images) {
          final png = _Png.read('$dir/${image['filename']}');
          expect([png.width, png.height], [1024, 1024]);
        }
        // App Store Connect rejects an icon with an alpha channel.
        expect(_Png.read('$dir/icon-1024.png').colorType, _rgb);
      });
    }

    test('prod has dark (transparent) and tinted (greyscale) variants', () {
      const dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      expect(_Png.read('$dir/icon-1024-dark.png').colorType, _rgba);
      expect(_Png.read('$dir/icon-1024-tinted.png').colorType, _grey);
    });
  });

  group('Android', () {
    test('adaptive icon with a monochrome layer for themed icons', () {
      for (final name in ['ic_launcher', 'ic_launcher_round']) {
        final xml = File('android/app/src/main/res/mipmap-anydpi-v26/$name.xml')
            .readAsStringSync();
        expect(xml, contains('@drawable/ic_launcher_background'));
        expect(xml, contains('@mipmap/ic_launcher_foreground'));
        expect(xml, contains('@mipmap/ic_launcher_monochrome'));
      }
      _densities.forEach((density, factor) {
        for (final layer in ['foreground', 'monochrome']) {
          final png = _Png.read(
            'android/app/src/main/res/mipmap-$density/ic_launcher_$layer.png',
          );
          expect(png.width, (108 * factor).round(), reason: '$density $layer');
          expect(png.colorType, _rgba);
        }
      });
    });

    test('the manifest names both icons', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
      expect(
        manifest,
        contains('android:roundIcon="@mipmap/ic_launcher_round"'),
      );
    });

    for (final flavor in _flavors) {
      test('$flavor has a background and classic icons for Android 7', () {
        final res = 'android/app/src/$flavor/res';
        expect(
          File('$res/drawable/ic_launcher_background.xml').existsSync(),
          isTrue,
        );
        _densities.forEach((density, factor) {
          for (final name in ['ic_launcher', 'ic_launcher_round']) {
            final png = _Png.read('$res/mipmap-$density/$name.png');
            expect(
              png.width,
              (48 * factor).round(),
              reason: '$flavor $density $name',
            );
          }
        });
      });
    }

    test(
      'flavour backgrounds differ, so a test build never looks like prod',
      () {
        final backgrounds = {
          for (final flavor in _flavors)
            File(
              'android/app/src/$flavor/res/drawable/ic_launcher_background.xml',
            ).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->'), ''),
        };
        expect(backgrounds, hasLength(3));
      },
    );
  });

  test('store icons', () {
    final appStore = _Png.read('assets/branding/store/app-store-1024.png');
    expect(
      [appStore.width, appStore.height, appStore.colorType],
      [1024, 1024, _rgb],
    );
    final play = _Png.read('assets/branding/store/google-play-512.png');
    expect([play.width, play.height], [512, 512]);
  });
}
