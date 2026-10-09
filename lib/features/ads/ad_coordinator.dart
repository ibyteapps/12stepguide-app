import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Decides and shows interstitials around content opens. Completed in P4.
class AdCoordinator {
  const AdCoordinator();

  /// Called before a document opens or a track starts. Never blocks navigation for long.
  Future<void> beforeContentOpen() async {}
}

final adCoordinatorProvider = Provider<AdCoordinator>((ref) => const AdCoordinator());
