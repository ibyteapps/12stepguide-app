import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../ads/ad_coordinator.dart';
import '../audio/application/player_controller.dart';
import '../content/domain/content_index.dart';
import '../shell/list_detail.dart';

/// Opens a document from any list. One place for the double-tap guard (F-009), the
/// interstitial rule before content (UNIFIED_PRODUCT_SPEC §2.4), and the tablet list-detail
/// layout (F-101).
class ContentOpener {
  ContentOpener(this._ref);

  final Ref _ref;
  DateTime? _last;

  /// Ignores a second tap within this window, so one tap opens one screen.
  static const guard = Duration(milliseconds: 600);

  Future<void> open(BuildContext context, DocEntry entry, {bool replace = false}) async {
    // Already beside the list: nothing to open, and no advert for it.
    if (ListDetailScope.find(context)?.selected == entry.id) return;
    final now = _ref.read(clockProvider)();
    if (_last != null && now.difference(_last!) < guard) return;
    _last = now;
    // No interstitial over a recording that is playing (UNIFIED_PRODUCT_SPEC §2.4).
    await _ref
        .read(adCoordinatorProvider)
        .beforeContentOpen(audioPlaying: _ref.read(playerProvider).playing);
    if (!context.mounted) return;
    // On a tablet the reading opens beside the list (F-101).
    final pane = ListDetailScope.find(context);
    if (pane != null) {
      pane.select(entry.id);
      return;
    }
    if (replace) {
      context.pushReplacement(Routes.read(entry.id));
    } else {
      await context.push(Routes.read(entry.id));
    }
  }
}

final contentOpenerProvider = Provider<ContentOpener>(ContentOpener.new);
