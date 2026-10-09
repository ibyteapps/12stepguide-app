import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/prefs/key_value_store.dart';
import 'sobriety_date.dart';

/// The recovery date (F-050). Stored on the device only, as an ISO calendar date.
class SobrietyController extends Notifier<DateTime?> {
  @override
  DateTime? build() =>
      SobrietyDate.fromIso(ref.watch(kvStoreProvider).getString(PrefKeys.sobrietyDate));

  /// Sets the date; a future date (wrong device clock) is clamped to today.
  Future<void> set(DateTime date) async {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final value = day.isAfter(today) ? today : day;
    state = value;
    await ref.read(kvStoreProvider).setString(PrefKeys.sobrietyDate, SobrietyDate.toIso(value));
  }

  Future<void> clear() async {
    state = null;
    await ref.read(kvStoreProvider).remove(PrefKeys.sobrietyDate);
  }
}

final sobrietyProvider = NotifierProvider<SobrietyController, DateTime?>(SobrietyController.new);
