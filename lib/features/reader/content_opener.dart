import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../ads/ad_coordinator.dart';
import '../content/domain/content_index.dart';

/// Opens a document from any list. One place for the double-tap guard (F-009) and the
/// interstitial rule before content (UNIFIED_PRODUCT_SPEC §2.4).
class ContentOpener {
  ContentOpener(this._ref);

  final Ref _ref;
  DateTime? _last;

  /// Ignores a second tap within this window, so one tap opens one screen.
  static const guard = Duration(milliseconds: 600);

  Future<void> open(BuildContext context, DocEntry entry, {bool replace = false}) async {
    final now = _ref.read(clockProvider)();
    if (_last != null && now.difference(_last!) < guard) return;
    _last = now;
    await _ref.read(adCoordinatorProvider).beforeContentOpen();
    if (!context.mounted) return;
    if (replace) {
      context.pushReplacement(Routes.read(entry.id));
    } else {
      await context.push(Routes.read(entry.id));
    }
  }
}

final contentOpenerProvider = Provider<ContentOpener>(ContentOpener.new);
