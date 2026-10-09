import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/prefs/key_value_store.dart';
import '../domain/catalogue.dart';

/// Where each recording was left, so it resumes there (A-20). Saved as a JSON map of track id →
/// seconds (`audio.positions`); at most one entry per track, so the size is bounded.
class TrackPositions {
  TrackPositions(this._store);

  final KeyValueStore _store;

  /// Positions this close to the start are not worth resuming.
  static const minimum = Duration(seconds: 5);

  /// A recording stopped this close to its end counts as finished and starts over next time.
  static const finishedWithin = Duration(seconds: 30);

  Map<String, int> _read() {
    final raw = _store.getString(PrefKeys.trackPositions);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, Object?>).map(
        (k, v) => MapEntry(k, (v! as num).toInt()),
      );
    } on Object {
      return {};
    }
  }

  /// Where to start [track]: the saved position, or null to start from the beginning.
  Duration? resumeFor(Track track) {
    final seconds = _read()['${track.id}'];
    if (seconds == null) return null;
    final position = Duration(seconds: seconds);
    return _worthKeeping(track, position) ? position : null;
  }

  Future<void> save(Track track, Duration position) async {
    final map = _read();
    if (_worthKeeping(track, position)) {
      if (map['${track.id}'] == position.inSeconds) return;
      map['${track.id}'] = position.inSeconds;
    } else {
      if (map.remove('${track.id}') == null) return;
    }
    await _store.setString(PrefKeys.trackPositions, jsonEncode(map));
  }

  bool _worthKeeping(Track track, Duration position) =>
      position >= minimum && position <= track.duration - finishedWithin;
}

final trackPositionsProvider = Provider<TrackPositions>(
  (ref) => TrackPositions(ref.watch(kvStoreProvider)),
);
