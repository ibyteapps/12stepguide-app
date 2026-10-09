import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ad consent state (A-11). Completed with the Google UMP flow in P4.
class ConsentState {
  const ConsentState({this.canRequestAds = false, this.privacyOptionsRequired = false});

  final bool canRequestAds;
  final bool privacyOptionsRequired;
}

class ConsentController extends Notifier<ConsentState> {
  @override
  ConsentState build() => const ConsentState();

  Future<void> showPrivacyOptions() async {}
}

final consentProvider = NotifierProvider<ConsentController, ConsentState>(ConsentController.new);

/// Whether the drawer shows "Privacy & ad choices" (only where UMP requires it).
final privacyOptionsRequiredProvider = Provider<bool>(
  (ref) => ref.watch(consentProvider).privacyOptionsRequired,
);
