import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/ad_units.dart';
import '../../core/logging/log.dart';

/// Full-screen adverts behind one interface (FLUTTER_ARCHITECTURE §10.4). Banners are widgets
/// (banner_slot.dart). Nothing here decides *whether* to show; that is `AdPolicy`.
abstract interface class AdGateway {
  /// Starts the SDK (after consent) and preloads one interstitial and one app-open advert.
  Future<void> start();

  bool get interstitialReady;

  /// Shows the loaded interstitial and completes when it is dismissed. False if none was ready;
  /// navigation never waits for a load.
  Future<bool> showInterstitial();

  /// When the loaded app-open advert arrived (it goes stale after 4 hours), or null.
  DateTime? get appOpenLoadedAt;
  Future<bool> showAppOpen();

  /// Replaces an app-open advert loaded longer ago than [maxAge] with a fresh one.
  void dropStaleAppOpen(Duration maxAge);
}

/// No adverts: Premium, tests, and builds without units.
class NoAds implements AdGateway {
  const NoAds();
  @override
  Future<void> start() async {}
  @override
  bool get interstitialReady => false;
  @override
  Future<bool> showInterstitial() async => false;
  @override
  DateTime? get appOpenLoadedAt => null;
  @override
  Future<bool> showAppOpen() async => false;
  @override
  void dropStaleAppOpen(Duration maxAge) {}
}

class GoogleAdGateway implements AdGateway {
  GoogleAdGateway(this.units, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AdUnits units;
  final DateTime Function() _clock;
  bool _started = false;

  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;
  bool _loadingAppOpen = false;
  int _retry = 0;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await MobileAds.instance.initialize();
    // Video adverts are always silent and never duck the recording that is playing (F-076).
    await MobileAds.instance.setAppMuted(true);
    await MobileAds.instance.setAppVolume(0);
    _loadInterstitial();
    _loadAppOpen();
  }

  Duration get _backoff => Duration(seconds: [10, 30, 60, 120][_retry.clamp(0, 3)]);

  void _loadInterstitial() {
    final unit = units.interstitial;
    if (unit == null || _loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _retry = 0;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          Log.w('Interstitial failed to load: ${error.code}');
          _retry++;
          Timer(_backoff, _loadInterstitial);
        },
      ),
    );
  }

  void _loadAppOpen() {
    final unit = units.appOpen;
    if (unit == null || _loadingAppOpen || _appOpen != null) return;
    _loadingAppOpen = true;
    AppOpenAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingAppOpen = false;
          _appOpen = ad;
          _appOpenLoadedAt = _clock();
        },
        onAdFailedToLoad: (error) {
          _loadingAppOpen = false;
          Log.w('App-open advert failed to load: ${error.code}');
          Timer(_backoff, _loadAppOpen);
        },
      ),
    );
  }

  @override
  bool get interstitialReady => _interstitial != null;

  @override
  Future<bool> showInterstitial() {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return Future.value(false);
    }
    _interstitial = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        Log.w('Interstitial failed to show: ${error.code}');
        if (!done.isCompleted) done.complete(false);
        _loadInterstitial();
      },
    );
    unawaited(ad.show());
    return done.future;
  }

  @override
  DateTime? get appOpenLoadedAt => _appOpen == null ? null : _appOpenLoadedAt;

  @override
  Future<bool> showAppOpen() {
    final ad = _appOpen;
    if (ad == null) {
      _loadAppOpen();
      return Future.value(false);
    }
    _appOpen = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(true);
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        _loadAppOpen();
      },
    );
    unawaited(ad.show());
    return done.future;
  }

  @override
  void dropStaleAppOpen(Duration maxAge) {
    final at = _appOpenLoadedAt;
    if (_appOpen != null && at != null && _clock().difference(at) >= maxAge) {
      _appOpen!.dispose();
      _appOpen = null;
      _loadAppOpen();
    }
  }
}
