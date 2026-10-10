import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logging/log.dart';

/// Fixed addresses the app links to. They are the same in every environment.
abstract final class AppLinks {
  static const appStoreId = '1238097883';
  static const androidPackage = 'com.ibyteapps.aa12stepguide';
  static const appStorePage = 'https://apps.apple.com/app/id$appStoreId';
  static const playPage = 'https://play.google.com/store/apps/details?id=$androidPackage';

  // The address both native apps use today.
  static const dailyReflections = 'https://www.aa.org/pages/en_US/daily-reflection';
  // D-008 (Q-P5): today's iOS links.
  static const privacyPolicy = 'https://www.12steptoolkit.com/privacy-policy-ibyte/';
  static const terms = 'https://www.12steptoolkit.com/terms-of-service/';
  static const facebook = 'https://www.facebook.com/12steptoolkit/';
  // D-008 (Q-C2): today's Android support address.
  static const supportEmail = 'ibyteappsuk@gmail.com';

  static const appleDeveloper = 'https://apps.apple.com/developer/id901932809';
  static const playDeveloper = 'https://play.google.com/store/apps/developer?id=iByte+Apps+Limited';

  static const appleSubscriptions = 'https://apps.apple.com/account/subscriptions';
  static const playSubscriptions = 'https://play.google.com/store/account/subscriptions';

  static String appleApp(String id) => 'https://apps.apple.com/app/id$id';
  static String playApp(String package) => 'https://play.google.com/store/apps/details?id=$package';

  /// The review page of this app in the current platform's store.
  static String get thisAppReviewPage =>
      isApple ? 'https://apps.apple.com/app/id$appStoreId?action=write-review' : playPage;

  static bool get isApple =>
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
}

/// Opens links outside the app. Behind an interface so screens and tests never touch the
/// platform plugin directly.
abstract interface class LinkOpener {
  /// Web pages open in an in-app browser tab (UNIFIED_PRODUCT_SPEC §5, S-11); store and mail
  /// links hand off to their apps. Returns false if nothing could open it.
  Future<bool> open(String url);

  Future<bool> email({required String to, required String subject, required String body});
}

/// Web pages need a connection: offline, [onOffline] tells the user instead of opening a blank
/// browser tab (F-112, UNIFIED_PRODUCT_SPEC §6). Mail links go straight through.
class OfflineAwareLinkOpener implements LinkOpener {
  const OfflineAwareLinkOpener({
    required this.inner,
    required this.isOffline,
    required this.onOffline,
  });

  final LinkOpener inner;
  final bool Function() isOffline;
  final void Function() onOffline;

  static const message = "You're offline. Connect to the internet to open this page.";

  @override
  Future<bool> open(String url) async {
    final scheme = Uri.tryParse(url)?.scheme;
    if ((scheme == 'http' || scheme == 'https') && isOffline()) {
      onOffline();
      return false;
    }
    return inner.open(url);
  }

  @override
  Future<bool> email({required String to, required String subject, required String body}) =>
      inner.email(to: to, subject: subject, body: body);
}

class UrlLauncherOpener implements LinkOpener {
  const UrlLauncherOpener();

  @override
  Future<bool> open(String url) async {
    final uri = Uri.parse(url);
    final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
    final isStore = uri.host.endsWith('apps.apple.com') || uri.host.endsWith('play.google.com');
    try {
      return await launchUrl(
        uri,
        mode: isWeb && !isStore ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication,
      );
    } on Object catch (error) {
      Log.w('Could not open link ${uri.host}: $error');
      return false;
    }
  }

  @override
  Future<bool> email({required String to, required String subject, required String body}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      return await launchUrl(uri);
    } on Object catch (error) {
      Log.w('Could not open the mail app: $error');
      return false;
    }
  }
}
