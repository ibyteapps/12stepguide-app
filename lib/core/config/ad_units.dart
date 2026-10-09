import 'package:flutter/foundation.dart';

import 'app_env.dart';

/// AdMob ad unit ids for one platform (FLUTTER_ARCHITECTURE §9). Null means "no unit": that
/// format simply never loads.
@immutable
class AdUnits {
  const AdUnits({this.banner, this.interstitial, this.appOpen});

  final String? banner;
  final String? interstitial;
  final String? appOpen;

  /// Google's published test units, used by every dev and staging build.
  static const testAndroid = AdUnits(
    banner: 'ca-app-pub-3940256099942544/9214589741',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    appOpen: 'ca-app-pub-3940256099942544/9257395921',
  );
  static const testIOS = AdUnits(
    banner: 'ca-app-pub-3940256099942544/2435281174',
    interstitial: 'ca-app-pub-3940256099942544/4411468910',
    appOpen: 'ca-app-pub-3940256099942544/5575463023',
  );

  /// The live units come only from `config/prod.json` (gitignored), never from source.
  static const _liveAndroid = AdUnits(
    banner: String.fromEnvironment('ADMOB_ANDROID_BANNER'),
    interstitial: String.fromEnvironment('ADMOB_ANDROID_INTERSTITIAL'),
    appOpen: String.fromEnvironment('ADMOB_ANDROID_APP_OPEN'),
  );
  static const _liveIOS = AdUnits(
    banner: String.fromEnvironment('ADMOB_IOS_BANNER'),
    interstitial: String.fromEnvironment('ADMOB_IOS_INTERSTITIAL'),
    appOpen: String.fromEnvironment('ADMOB_IOS_APP_OPEN'),
  );

  /// The units this build uses: test units outside prod, so a test build can never earn from or
  /// be banned for its own clicks.
  static AdUnits forBuild(AppEnv env, {required bool isIOS}) {
    if (env.usesTestAds) return isIOS ? testIOS : testAndroid;
    return (isIOS ? _liveIOS : _liveAndroid)._withoutBlanks();
  }

  AdUnits _withoutBlanks() => AdUnits(
    banner: _blankToNull(banner),
    interstitial: _blankToNull(interstitial),
    appOpen: _blankToNull(appOpen),
  );

  static String? _blankToNull(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  bool get isComplete => banner != null && interstitial != null && appOpen != null;
}
