import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/prefs/key_value_store.dart';

/// Where the user stopped reading a document (A-19, F-046).
@immutable
class ReadingPosition {
  const ReadingPosition({
    required this.offset,
    required this.fraction,
    required this.textStep,
    required this.savedAt,
    this.page,
  });

  factory ReadingPosition.fromJson(Map<String, Object?> j) => ReadingPosition(
    offset: (j['o']! as num).toDouble(),
    fraction: (j['f']! as num).toDouble(),
    textStep: j['s']! as int,
    savedAt: DateTime.fromMillisecondsSinceEpoch(j['t']! as int),
    page: j['p'] as int?,
  );

  /// Scroll offset in logical pixels at [textStep].
  final double offset;

  /// 0–1 through the document, used when the text size has changed since.
  final double fraction;
  final int textStep;
  final DateTime savedAt;

  /// The printed page at the top of the screen, when the document has page numbers.
  final int? page;

  bool get finished => fraction >= 0.97;

  Map<String, Object?> toJson() => {
    'o': offset.roundToDouble(),
    'f': double.parse(fraction.toStringAsFixed(4)),
    's': textStep,
    't': savedAt.millisecondsSinceEpoch,
    if (page != null) 'p': page,
  };
}

/// Saved positions for every document, keyed by document id. Bounded to the 300 most recent.
class ReadingPositions extends Notifier<Map<String, ReadingPosition>> {
  static const _max = 300;

  @override
  Map<String, ReadingPosition> build() {
    final raw = ref.watch(kvStoreProvider).getString(PrefKeys.readingPositions);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, Object?>;
      return {
        for (final e in map.entries)
          e.key: ReadingPosition.fromJson(e.value! as Map<String, Object?>),
      };
    } on Object {
      return const {};
    }
  }

  Future<void> save(String docId, ReadingPosition position) async {
    final next = {...state, docId: position};
    if (next.length > _max) {
      final oldest = next.entries.toList()
        ..sort((a, b) => a.value.savedAt.compareTo(b.value.savedAt));
      for (final e in oldest.take(next.length - _max)) {
        next.remove(e.key);
      }
    }
    state = next;
    await ref
        .read(kvStoreProvider)
        .setString(
          PrefKeys.readingPositions,
          jsonEncode({for (final e in next.entries) e.key: e.value.toJson()}),
        );
  }

  /// The most recently read, unfinished document among [docIds] ("Continue reading").
  String? latestUnfinished(Iterable<String> docIds) {
    final ids = docIds.toSet();
    final candidates =
        state.entries
            .where((e) => ids.contains(e.key) && !e.value.finished && e.value.fraction > 0.02)
            .toList()
          ..sort((a, b) => b.value.savedAt.compareTo(a.value.savedAt));
    return candidates.isEmpty ? null : candidates.first.key;
  }
}

final readingPositionsProvider = NotifierProvider<ReadingPositions, Map<String, ReadingPosition>>(
  ReadingPositions.new,
);
