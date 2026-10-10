import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../app/providers.dart';
import '../../core/logging/log.dart';
import '../../core/prefs/key_value_store.dart';

/// Asks the system for its review prompt; the system decides whether it actually appears.
final reviewRequesterProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) await review.requestReview();
  },
);

/// The automatic review prompt (A-26, F-081): the system review dialog on launch 7, 15 and 30,
/// once each, never for someone who already rated (Android's migrated flag, m006), and at most
/// three times in all. "Rate the app" in the drawer is always there.
abstract final class ReviewCadence {
  static const launches = {7, 15, 30};
  static const maxPrompts = 3;

  static bool shouldAsk({required int launchCount, required KeyValueStore store}) {
    if (store.getBool(PrefKeys.reviewRated) ?? false) return false;
    if ((store.getInt(PrefKeys.reviewPromptCount) ?? 0) >= maxPrompts) return false;
    if (!launches.contains(launchCount)) return false;
    final asked = store.getStringList(PrefKeys.reviewPromptedAtLaunches) ?? const [];
    return !asked.contains('$launchCount');
  }

  static Future<void> ask(Ref ref, {required int launchCount}) async {
    final store = ref.read(kvStoreProvider);
    final asked = store.getStringList(PrefKeys.reviewPromptedAtLaunches) ?? const [];
    await store.setStringList(
      PrefKeys.reviewPromptedAtLaunches,
      {...asked, '$launchCount'}.toList(),
    );
    await store.setInt(
      PrefKeys.reviewPromptCount,
      (store.getInt(PrefKeys.reviewPromptCount) ?? 0) + 1,
    );
    try {
      await ref.read(reviewRequesterProvider)();
    } on Object catch (error) {
      Log.w('Review prompt unavailable: ${error.runtimeType}');
    }
  }
}

/// Runs [ReviewCadence.ask] from widgets.
final reviewPromptProvider = Provider<Future<void> Function(int launchCount)>(
  (ref) =>
      (launchCount) => ReviewCadence.ask(ref, launchCount: launchCount),
);
