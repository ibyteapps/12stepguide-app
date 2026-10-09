import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/logging/log.dart';

/// The cheer when the day count is tapped (F-053). Uses its own player and never takes over the
/// audio session, so it does not stop a recording that is playing.
abstract interface class CheerPlayer {
  Future<void> play();
}

class AssetCheerPlayer implements CheerPlayer {
  AudioPlayer? _player;

  @override
  Future<void> play() async {
    unawaited(HapticFeedback.mediumImpact());
    try {
      final player = _player ??= AudioPlayer(handleAudioSessionActivation: false);
      await player.setAsset('assets/sounds/cheer.mp3');
      await player.seek(Duration.zero);
      await player.play();
    } on Object catch (error) {
      Log.w('Cheer could not play: $error');
    }
  }
}

final cheerPlayerProvider = Provider<CheerPlayer>((ref) => AssetCheerPlayer());
