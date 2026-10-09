// Guards the identifiers that must never change (FLUTTER_ARCHITECTURE.md §0).
//
// These read the native project files as text, so a careless edit fails CI on every push,
// before any build runs. tool/ci/verify_build.py checks the same values in the built apps.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _appId = 'com.ibyteapps.aa12stepguide';

String _read(String path) => File(path).readAsStringSync();

String? _match(String text, String pattern) =>
    RegExp(pattern, multiLine: true).firstMatch(text)?.group(1);

void main() {
  group('version', () {
    test('pubspec version is at least 2.0.0+100', () {
      final version = _match(_read('pubspec.yaml'), r'^version:\s*(\S+)$');
      expect(version, isNotNull);
      final parts = version!.split('+');
      final semver = parts[0].split('.').map(int.parse).toList();
      final build = int.parse(parts[1]);
      // iOS shipped 1.51 and Android versionCode 29.
      expect(semver[0], greaterThanOrEqualTo(2));
      expect(build, greaterThanOrEqualTo(100));
    });
  });

  group('Android', () {
    final gradle = _read('android/app/build.gradle.kts');
    final manifest = _read('android/app/src/main/AndroidManifest.xml');

    test('applicationId and namespace', () {
      expect(_match(gradle, r'^\s*applicationId = "([^"]+)"'), _appId);
      expect(_match(gradle, r'^\s*namespace = "([^"]+)"'), _appId);
    });

    test('only dev changes the id', () {
      final suffixes = RegExp(r'applicationIdSuffix = "([^"]*)"')
          .allMatches(gradle)
          .map((m) => m.group(1))
          .toList();
      expect(suffixes, ['.dev']);
    });

    test('SDK levels', () {
      expect(_match(gradle, r'^\s*minSdk = (\d+)'), '24');
      expect(_match(gradle, r'^\s*targetSdk = (\d+)'), '36');
      expect(_match(gradle, r'^\s*compileSdk = (\d+)'), '36');
    });

    test('launcher activity keeps the native component name', () {
      // Home-screen icons point at com.ibyteapps.aa12stepguide.First.
      expect(manifest, contains('android:name=".First"'));
      expect(
        File('android/app/src/main/kotlin/com/ibyteapps/aa12stepguide/First.kt').existsSync(),
        isTrue,
      );
    });
  });

  group('iOS', () {
    final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');

    String bundleId(String flavor) =>
        _match(_read('ios/Flutter/$flavor.xcconfig'), r'^APP_BUNDLE_ID = (\S+)$')!;

    test('bundle ids per flavour', () {
      expect(bundleId('prod'), _appId);
      expect(bundleId('staging'), _appId);
      expect(bundleId('dev'), '$_appId.dev');
    });

    test('the app target takes its bundle id from the flavour', () {
      final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .allMatches(pbx)
          .map((m) => m.group(1))
          .toSet();
      expect(ids, {'"\$(APP_BUNDLE_ID)"', '$_appId.RunnerTests'});
    });

    test('every configuration targets iOS 15.0', () {
      final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);')
          .allMatches(pbx)
          .map((m) => m.group(1))
          .toSet();
      expect(targets, {'15.0'});
    });

    test('a scheme and three build configurations per flavour', () {
      for (final flavor in ['dev', 'staging', 'prod']) {
        expect(
          File('ios/Runner.xcodeproj/xcshareddata/xcschemes/$flavor.xcscheme').existsSync(),
          isTrue,
          reason: flavor,
        );
        for (final mode in ['Debug', 'Profile', 'Release']) {
          // Project, Runner and RunnerTests each have the configuration.
          expect('name = $mode-$flavor;'.allMatchesIn(pbx), 3, reason: '$mode-$flavor');
        }
      }
    });
  });
}

extension on String {
  int allMatchesIn(String text) => RegExp(RegExp.escape(this)).allMatches(text).length;
}
