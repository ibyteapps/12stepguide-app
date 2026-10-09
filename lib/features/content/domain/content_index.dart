import 'dart:convert';

/// Collection ids, as in the documents' front matter and `assets/content_index.json`.
abstract final class Collections {
  static const steps = 'steps';
  static const traditions = 'traditions';
  static const readings = 'readings';
  static const prayers = 'prayers';
  static const sobrietyTips = 'sobriety-tips';
  static const bigBook = 'big-book';
  static const stories1 = 'stories-1st-edition';
  static const stories2 = 'stories-2nd-edition';
  static const joeAndCharlie = 'transcripts-joe-and-charlie';
  static const bigBookAudio = 'transcripts-big-book';

  static const bigBookTabs = [bigBook, stories1, stories2];
}

/// One document in the index: everything a list needs without opening the file.
class DocEntry {
  const DocEntry({
    required this.id,
    required this.collection,
    required this.order,
    required this.title,
    required this.path,
    this.subtitle,
    this.pages,
    this.aliases = const [],
    this.albumId,
    this.trackId,
    this.audioFile,
    this.firstPage,
    this.lastPage,
    this.words = 0,
  });

  factory DocEntry.fromJson(Map<String, Object?> json) => DocEntry(
    id: json['id']! as String,
    collection: json['collection']! as String,
    order: json['order']! as int,
    title: json['title']! as String,
    path: json['path']! as String,
    subtitle: json['subtitle'] as String?,
    pages: json['pages'] as String?,
    aliases: [...?(json['aliases'] as List<Object?>?)?.cast<String>()],
    albumId: json['album_id'] as int?,
    trackId: json['track_id'] as int?,
    audioFile: json['audio_file'] as String?,
    firstPage: json['firstPage'] as int?,
    lastPage: json['lastPage'] as int?,
    words: (json['words'] as int?) ?? 0,
  );

  final String id;
  final String collection;
  final int order;
  final String title;

  /// Asset path, e.g. `content/steps/01-step-1.md`.
  final String path;

  /// The Step or Tradition wording.
  final String? subtitle;

  /// Printed page range, e.g. "58–71".
  final String? pages;
  final List<String> aliases;
  final int? albumId;
  final int? trackId;
  final String? audioFile;
  final int? firstPage;
  final int? lastPage;
  final int words;

  /// Rough reading time at 200 words a minute.
  int get minutes => (words / 200).ceil().clamp(1, 999);
}

/// All shipped documents, in presentation order.
class ContentIndex {
  ContentIndex(List<DocEntry> documents)
    : documents = List.unmodifiable(documents),
      _byId = {for (final d in documents) d.id: d};

  factory ContentIndex.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    final docs = (json['documents']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(DocEntry.fromJson)
        .toList();
    return ContentIndex(docs);
  }

  final List<DocEntry> documents;
  final Map<String, DocEntry> _byId;

  DocEntry? byId(String id) => _byId[id];

  List<DocEntry> inCollection(String collection) =>
      documents.where((d) => d.collection == collection).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  DocEntry? next(DocEntry entry) => _neighbour(entry, 1);
  DocEntry? previous(DocEntry entry) => _neighbour(entry, -1);

  DocEntry? _neighbour(DocEntry entry, int delta) {
    final list = inCollection(entry.collection);
    final i = list.indexWhere((d) => d.id == entry.id);
    final j = i + delta;
    return i < 0 || j < 0 || j >= list.length ? null : list[j];
  }

  /// The transcript for an audio track, if it has one.
  DocEntry? transcriptFor(int trackId) {
    for (final d in documents) {
      if (d.trackId == trackId) return d;
    }
    return null;
  }
}
