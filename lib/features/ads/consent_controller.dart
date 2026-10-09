import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/logging/log.dart';

/// Ad consent state (A-11).
@immutable
class ConsentState {
  const ConsentState({
    this.resolved = false,
    this.canRequestAds = false,
    this.privacyOptionsRequired = false,
  });

  /// The consent check has finished (whatever the answer). Ads never load before this.
  final bool resolved;
  final bool canRequestAds;

  /// The user is somewhere (UK/EEA) where they must be able to change their choice: the drawer
  /// shows "Privacy & ad choices".
  final bool privacyOptionsRequired;
}

/// Google's User Messaging Platform behind an interface, so tests never touch the SDK.
abstract interface class ConsentGateway {
  /// Updates the consent information and shows the form where it is required. Completes when
  /// the user has answered or no form is needed.
  Future<void> gather();
  Future<bool> canRequestAds();
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();
}

/// Used where ads cannot run (tests, desktop): consent resolved, no ads.
class NoConsent implements ConsentGateway {
  const NoConsent({this.allowAds = false});

  final bool allowAds;

  @override
  Future<void> gather() async {}
  @override
  Future<bool> canRequestAds() async => allowAds;
  @override
  Future<bool> privacyOptionsRequired() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
}

class UmpConsentGateway implements ConsentGateway {
  const UmpConsentGateway();

  @override
  Future<void> gather() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) Log.w('Consent form error ${error.errorCode}');
        });
        if (!done.isCompleted) done.complete();
      },
      (error) {
        // Offline or misconfigured: the SDK falls back to the last answer (canRequestAds).
        Log.w('Consent update failed ${error.errorCode}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((error) {
    if (error != null) Log.w('Privacy options error ${error.errorCode}');
  });
}

final consentGatewayProvider = Provider<ConsentGateway>((ref) => const NoConsent());

class ConsentController extends Notifier<ConsentState> {
  @override
  ConsentState build() => const ConsentState();

  /// Runs once at start-up, before any advert is requested (S-02a).
  Future<void> gather() async {
    final gateway = ref.read(consentGatewayProvider);
    try {
      await gateway.gather();
    } on Object catch (error) {
      Log.w('Consent gathering failed: ${error.runtimeType}');
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final gateway = ref.read(consentGatewayProvider);
    var can = false, options = false;
    try {
      can = await gateway.canRequestAds();
      options = await gateway.privacyOptionsRequired();
    } on Object catch (error) {
      Log.w('Consent status unavailable: ${error.runtimeType}');
    }
    state = ConsentState(resolved: true, canRequestAds: can, privacyOptionsRequired: options);
  }

  /// "Privacy & ad choices" in the drawer.
  Future<void> showPrivacyOptions() async {
    try {
      await ref.read(consentGatewayProvider).showPrivacyOptions();
    } on Object catch (error) {
      Log.w('Privacy options unavailable: ${error.runtimeType}');
    }
    await _refresh();
  }
}

final consentProvider = NotifierProvider<ConsentController, ConsentState>(ConsentController.new);

/// Whether the drawer shows "Privacy & ad choices" (only where UMP requires it).
final privacyOptionsRequiredProvider = Provider<bool>(
  (ref) => ref.watch(consentProvider).privacyOptionsRequired,
);
