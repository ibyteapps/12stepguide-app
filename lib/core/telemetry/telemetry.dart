import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../logging/log.dart';

/// Analytics and crash reporting behind one interface (FLUTTER_ARCHITECTURE §10.6).
///
/// Privacy rules: no user content, sobriety date, email or free text. Allowed: app version,
/// flavour, screen path (no document text), album/track ids, entitlement type. No custom events
/// in 2.0 beyond screen views (purchase events come from Firebase's automatic logging).
abstract interface class Telemetry implements LogSink {
  void screen(String path);
  Future<void> setAppVersion(String version);
  Future<void> setEntitlement(String type);

  /// Google consent mode, from the UMP answer (A-11).
  Future<void> setAdConsent({required bool granted});
  void fatal(Object error, StackTrace? stack);
}

class NoTelemetry implements Telemetry {
  const NoTelemetry();
  @override
  void screen(String path) {}
  @override
  Future<void> setAppVersion(String version) async {}
  @override
  Future<void> setEntitlement(String type) async {}
  @override
  Future<void> setAdConsent({required bool granted}) async {}
  @override
  void fatal(Object error, StackTrace? stack) {}
  @override
  void breadcrumb(String message) {}
  @override
  void nonFatal(Object error, StackTrace? stack, {String? reason}) {}
}

/// An error as text with personal data removed; Crashlytics records its `toString()`.
class RedactedError implements Exception {
  RedactedError(Object error) : text = '${error.runtimeType}: ${Log.redact('$error')}';

  final String text;

  @override
  String toString() => text;
}

class FirebaseTelemetry implements Telemetry {
  FirebaseTelemetry({required this.analyticsOn, required this.crashesOn});

  final bool analyticsOn;
  final bool crashesOn;
  final _analytics = FirebaseAnalytics.instance;
  final _crashlytics = FirebaseCrashlytics.instance;
  String? _lastScreen;

  Future<void> start({required String flavor}) async {
    await _analytics.setAnalyticsCollectionEnabled(analyticsOn);
    await _crashlytics.setCrashlyticsCollectionEnabled(crashesOn);
    await _crashlytics.setCustomKey('flavor', flavor);
  }

  @override
  Future<void> setAppVersion(String version) => _crashlytics.setCustomKey('version', version);

  @override
  void screen(String path) {
    if (!analyticsOn || path == _lastScreen) return;
    _lastScreen = path;
    unawaited(_analytics.logScreenView(screenName: path, screenClass: 'Flutter'));
  }

  @override
  Future<void> setEntitlement(String type) async {
    await _crashlytics.setCustomKey('entitlement', type);
    if (analyticsOn) await _analytics.setUserProperty(name: 'entitlement', value: type);
  }

  @override
  Future<void> setAdConsent({required bool granted}) => _analytics.setConsent(
    adStorageConsentGranted: granted,
    adUserDataConsentGranted: granted,
    adPersonalizationSignalsConsentGranted: granted,
    analyticsStorageConsentGranted: true,
  );

  @override
  void fatal(Object error, StackTrace? stack) {
    if (!crashesOn) return;
    unawaited(_crashlytics.recordError(RedactedError(error), stack, fatal: true));
  }

  @override
  void breadcrumb(String message) {
    if (crashesOn) unawaited(_crashlytics.log(message));
  }

  @override
  void nonFatal(Object error, StackTrace? stack, {String? reason}) {
    if (!crashesOn) return;
    unawaited(_crashlytics.recordError(RedactedError(error), stack, reason: reason));
  }

  /// Debug builds never report crashes (they would drown the real ones).
  static bool get crashesAllowed => !kDebugMode;
}
