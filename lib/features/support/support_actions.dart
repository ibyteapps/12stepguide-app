import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/links/links.dart';
import '../../core/logging/log.dart';
import '../../design/components/dialogs.dart';
import '../../design/components/states.dart';
import '../premium/entitlement_controller.dart';

/// Help & support actions from the drawer (UNIFIED_PRODUCT_SPEC S-55, D-008 / A-14).
class SupportActions {
  const SupportActions(this._ref);

  final Ref _ref;

  /// Opens the email app addressed to support, with the details support needs to help.
  /// If no email app is set up, offers to copy the address instead. [intro] starts the message
  /// (the "Lost your supporter status?" link asks for the Google Play order number).
  Future<void> contact(
    BuildContext context, {
    String subject = '12 Step Guide support',
    String intro = '',
  }) async {
    final info = _ref.read(launchInfoProvider);
    final entitlement = _ref.read(entitlementProvider);
    final platform = kIsWeb
        ? 'web'
        : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    final body =
        '$intro\n\n\n— Please keep the details below; they help us help you —\n'
        'App: 12 Step Guide ${info.version} (${info.buildNumber})\n'
        'Device: $platform\n'
        'Premium: ${entitlement.analyticsType}\n';
    final opened = await _ref
        .read(linkOpenerProvider)
        .email(to: AppLinks.supportEmail, subject: subject, body: body);
    if (!opened && context.mounted) {
      await showAdaptiveDialog<void>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: const Text('No email app found'),
          content: const Text('Write to us at ${AppLinks.supportEmail} from any email account.'),
          actions: [
            adaptiveAction(context, 'Close', () => Navigator.of(context).pop()),
            adaptiveAction(context, 'Copy address', () {
              Clipboard.setData(const ClipboardData(text: AppLinks.supportEmail));
              Navigator.of(context).pop();
              showMessage(context, 'Email address copied');
            }),
          ],
        ),
      );
    }
  }

  /// "Rate the app": opens this app's store page (F-081).
  Future<void> rate() async {
    try {
      await InAppReview.instance.openStoreListing(appStoreId: AppLinks.appStoreId);
    } on Object catch (error) {
      Log.w('openStoreListing failed: $error');
      await _ref.read(linkOpenerProvider).open(AppLinks.thisAppReviewPage);
    }
  }

  /// "Tell a friend": both store links (F-085), with no "AA" in the wording (D-005).
  Future<void> tellAFriend(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text:
            "I'm using 12 Step Guide, a free companion for working the Steps, with the Big "
            'Book and recovery audio. You can get it here:\n\n'
            'iPhone and iPad: ${AppLinks.appStorePage}\n'
            'Android: ${AppLinks.playPage}',
        subject: '12 Step Guide',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> open(String url) => _ref.read(linkOpenerProvider).open(url);
}

final supportActionsProvider = Provider<SupportActions>(SupportActions.new);
