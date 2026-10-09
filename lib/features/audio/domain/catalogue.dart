import 'dart:convert';

/// One recording (ids as in the native app's main.db).
class Track {
  const Track({
    required this.id,
    required this.albumId,
    required this.number,
    required this.title,
    required this.file,
    required this.seconds,
    required this.sizeLabel,
    this.approxBytes,
  });

  final int id;
  final int albumId;

  /// Position in the album, from 1.
  final int number;
  final String title;

  /// File name on the server and on disk, e.g. `joeandcharlie01.mp3`.
  final String file;
  final int seconds;
  final String sizeLabel;
  final int? approxBytes;

  Duration get duration => Duration(seconds: seconds);
}

class Album {
  const Album({
    required this.id,
    required this.title,
    required this.shortName,
    required this.folder,
    required this.hasTranscripts,
    required this.seconds,
    required this.gradient,
    required this.tracks,
  });

  final int id;
  final String title;
  final String shortName;

  /// Server folder (`variable` in main.db).
  final String folder;
  final bool hasTranscripts;
  final int seconds;

  /// "#RRGGBB" start and end colours of the artwork tile.
  final List<String> gradient;
  final List<Track> tracks;

  Duration get duration => Duration(seconds: seconds);
}

/// The bundled audio catalogue (A-24: shipped with the app). The base URL and file layout are
/// fixed: https://scripts.12stepapp.com/tracks/{folder}/{file} (FLUTTER_ARCHITECTURE §0).
class Catalogue {
  Catalogue({required this.baseUrl, required List<Album> albums})
    : albums = List.unmodifiable(albums),
      _tracks = {
        for (final a in albums)
          for (final t in a.tracks) t.id: t,
      },
      _albums = {for (final a in albums) a.id: a};

  factory Catalogue.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    final albums = <Album>[];
    for (final a in (json['albums']! as List<Object?>).cast<Map<String, Object?>>()) {
      final albumId = a['id']! as int;
      albums.add(
        Album(
          id: albumId,
          title: a['title']! as String,
          shortName: a['shortName']! as String,
          folder: a['folder']! as String,
          hasTranscripts: a['hasTranscripts']! as bool,
          seconds: a['seconds']! as int,
          gradient: (a['gradient']! as List<Object?>).cast<String>(),
          tracks: [
            for (final t in (a['tracks']! as List<Object?>).cast<Map<String, Object?>>())
              Track(
                id: t['id']! as int,
                albumId: albumId,
                number: t['number']! as int,
                title: t['title']! as String,
                file: t['file']! as String,
                seconds: t['seconds']! as int,
                sizeLabel: t['sizeLabel']! as String,
                approxBytes: t['approxBytes'] as int?,
              ),
          ],
        ),
      );
    }
    return Catalogue(baseUrl: json['baseUrl']! as String, albums: albums);
  }

  final String baseUrl;
  final List<Album> albums;
  final Map<int, Track> _tracks;
  final Map<int, Album> _albums;

  Track? track(int id) => _tracks[id];
  Album? album(int id) => _albums[id];
  Iterable<Track> get allTracks => _tracks.values;

  Uri streamUrl(Track track) =>
      Uri.parse('$baseUrl${_albums[track.albumId]!.folder}/${track.file}');

  /// Total listening time, for honest store and onboarding copy (~94 hours, R-11).
  Duration get totalDuration => Duration(seconds: albums.fold(0, (s, a) => s + a.seconds));
}
