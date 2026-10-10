import 'package:flutter/foundation.dart';

import '../../app/routes.dart';

/// Everything an advert decision depends on (UNIFIED_PRODUCT_SPEC §2.4, decision A-10).
@immutable
class AdFacts {
  const AdFacts({
    required this.premium,
    required this.canRequestAds,
    required this.launchCount,
    required this.now,
    this.audioPlaying = false,
    this.purchaseInProgress = false,
    this.location = '',
  });

  final bool premium;

  /// Consent resolved and ads allowed (A-11). Nothing loads before this.
  final bool canRequestAds;

  /// 1 on the first launch.
  final int launchCount;
  final DateTime now;
  final bool audioPlaying;
  final bool purchaseInProgress;

  /// The current route path, e.g. `/player`.
  final String location;

  bool get firstLaunch => launchCount <= 1;
}

/// Whether an advert may show. Pure and exhaustively unit-tested; every placement asks it, so no
/// placement can bypass the rules (FLUTTER_ARCHITECTURE §10.4).
abstract final class AdPolicy {
  /// An interstitial on every 3rd content open, counted across sessions.
  static const interstitialEvery = 3;

  /// App-open adverts at least this far apart (persisted).
  static const appOpenGap = Duration(seconds: 45);

  /// A loaded app-open advert older than this is stale and is not shown (AdMob guidance).
  static const appOpenMaxAge = Duration(hours: 4);

  /// Screens an app-open advert never covers: onboarding, the welcome-back screen, the paywall
  /// and Premium page (purchase flow), the full player, a quote opened from a notification, and
  /// Reminders (people come back to it from the system's notification settings).
  static const appOpenBlocked = {
    Routes.onboarding,
    Routes.welcomeBack,
    Routes.paywall,
    Routes.premium,
    Routes.player,
    Routes.quote,
    Routes.reminders,
  };

  static bool _eligible(AdFacts f) => !f.premium && f.canRequestAds;

  /// Banners (reader, full player, quote screen): always for free users once consent allows.
  static bool mayShowBanner(AdFacts f) => _eligible(f);

  /// Counts one content open (a document opening or a track starting) and decides. Returns the
  /// new counter and whether to show an interstitial. Free users only; the counter does not
  /// move for Premium users or before consent.
  static ({int count, bool show}) onContentOpen(AdFacts f, int count) {
    if (!_eligible(f)) return (count: count, show: false);
    final next = count + 1;
    if (f.firstLaunch || f.audioPlaying) {
      // Counted, but never shown on the first launch or over playing audio.
      return (count: next, show: false);
    }
    return (count: next, show: next >= interstitialEvery);
  }

  /// The counter after an interstitial or an app-open advert actually showed: both restart it,
  /// so the two never come close together.
  static const resetCount = 0;

  /// An app-open advert when the user returns to the app.
  static bool mayShowAppOpen(AdFacts f, {DateTime? lastShownAt, DateTime? loadedAt}) {
    if (!_eligible(f) || f.firstLaunch || f.purchaseInProgress) return false;
    if (appOpenBlocked.contains(f.location)) return false;
    if (loadedAt == null || f.now.difference(loadedAt) >= appOpenMaxAge) return false;
    if (lastShownAt != null && f.now.difference(lastShownAt) < appOpenGap) return false;
    return true;
  }
}
