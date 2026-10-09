import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device has a network connection (F-112). A best guess: a captive portal still
/// counts as online, so network errors are handled where they happen too.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) => r.any((c) => c != ConnectivityResult.none);
  try {
    yield online(await connectivity.checkConnectivity());
  } on Object {
    yield true;
  }
  yield* connectivity.onConnectivityChanged.map(online);
});

/// Offline only when we are sure; unknown counts as online so nothing is blocked needlessly.
final isOfflineProvider = Provider<bool>(
  (ref) => ref.watch(onlineProvider).maybeWhen(data: (online) => !online, orElse: () => false),
);
