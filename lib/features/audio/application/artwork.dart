import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/log.dart';
import '../domain/catalogue.dart';

/// Album artwork for the lock screen and the media notification. The media session needs a
/// `file:` or `https:` URI, so the bundled images (`assets/images/albums/<id>.png`, made by
/// tool/build_album_art.py) are copied to a cache folder once.
abstract interface class ArtworkSource {
  Future<Uri?> uriFor(Album album);
}

class NoArtwork implements ArtworkSource {
  const NoArtwork();

  @override
  Future<Uri?> uriFor(Album album) async => null;
}

class BundledArtwork implements ArtworkSource {
  BundledArtwork(this.directory, {AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final String directory;
  final AssetBundle _bundle;
  final _cache = <int, Uri>{};

  static String assetFor(int albumId) => 'assets/images/albums/$albumId.png';

  @override
  Future<Uri?> uriFor(Album album) async {
    final cached = _cache[album.id];
    if (cached != null) return cached;
    try {
      final file = File('$directory/album-${album.id}.png');
      if (!file.existsSync() || file.lengthSync() == 0) {
        final data = await _bundle.load(assetFor(album.id));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      }
      return _cache[album.id] = file.uri;
    } on Object catch (error) {
      // Playback carries on without artwork.
      Log.w('Album artwork unavailable for album ${album.id}: ${error.runtimeType}');
      return null;
    }
  }
}

final artworkProvider = Provider<ArtworkSource>((ref) => const NoArtwork());
