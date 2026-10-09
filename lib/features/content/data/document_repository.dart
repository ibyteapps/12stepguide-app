import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/content_index.dart';
import '../domain/document_parser.dart';

/// Loads and parses a bundled document. Parsed documents are kept while they are on screen.
final documentProvider = FutureProvider.autoDispose.family<ParsedDocument, String>((
  ref,
  docId,
) async {
  final entry = ref.watch(contentIndexProvider).byId(docId);
  if (entry == null) throw DocumentNotFound(docId);
  final source = await rootBundle.loadString(entry.path);
  return parseDocument(source);
});

class DocumentNotFound implements Exception {
  const DocumentNotFound(this.docId);
  final String docId;
  @override
  String toString() => 'DocumentNotFound($docId)';
}

/// Index entry lookup for screens.
final docEntryProvider = Provider.family<DocEntry?, String>(
  (ref, docId) => ref.watch(contentIndexProvider).byId(docId),
);
