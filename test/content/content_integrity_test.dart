// Every shipped document is indexed, loads and parses, and keeps its page markers
// (IMPLEMENTATION_PLAN P1 acceptance).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/features/content/domain/content_index.dart';
import 'package:twelve_step_guide/features/content/domain/document_parser.dart';

void main() {
  final index = ContentIndex.fromJsonString(File('assets/content_index.json').readAsStringSync());

  test('collection sizes match both native apps', () {
    final expected = {
      Collections.steps: 14, // Introduction, Steps 1–12, Conclusion (D-008 / A-07)
      Collections.traditions: 12,
      Collections.readings: 8,
      Collections.prayers: 6,
      Collections.sobrietyTips: 4,
      Collections.bigBook: 14,
      Collections.stories1: 29,
      Collections.stories2: 40,
      Collections.joeAndCharlie: 34,
      Collections.bigBookAudio: 14,
    };
    expected.forEach((collection, count) {
      expect(index.inCollection(collection), hasLength(count), reason: collection);
    });
    expect(index.documents, hasLength(175));
  });

  test('every document is declared as a bundled asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final doc in index.documents) {
      final folder = doc.path.substring(0, doc.path.lastIndexOf('/') + 1);
      expect(pubspec, contains('- $folder\n'), reason: folder);
    }
  });

  test('titles are unique within a collection and carry no "AA" prefix (D-005)', () {
    for (final c in Collections.bigBookTabs + [Collections.steps, Collections.readings]) {
      final titles = index.inCollection(c).map((d) => d.title).toList();
      expect(titles.toSet(), hasLength(titles.length), reason: c);
    }
    for (final doc in index.documents) {
      if (doc.collection.startsWith('transcripts')) continue; // recording titles, unchanged
      expect(doc.title, isNot(startsWith('AA ')), reason: doc.id);
    }
  });

  group('every document parses', () {
    for (final doc in index.documents) {
      test(doc.id, () {
        final source = File(doc.path).readAsStringSync();
        final parsed = parseDocument(source);
        expect(parsed.blocks, isNotEmpty);

        final text = parsed.plainText;
        expect(text, isNot(contains('<!--')));
        expect(text, isNot(contains('')));
        expect(text, isNot(contains('<br')));

        // Every printed page marker survives as a page block or an inline page run.
        final markers = RegExp(r'<!-- page (\d+) -->').allMatches(source).length;
        var found = 0;
        void count(List<DocBlock> blocks) {
          for (final b in blocks) {
            switch (b) {
              case PageBreakBlock():
                found++;
              case ParagraphBlock(:final runs) || HeadingBlock(:final runs):
                found += runs.whereType<PageRun>().length;
              case ListBlock(:final items):
                items.forEach(count);
              case QuoteBlock(:final children):
                count(children);
              case TableBlock() || RuleBlock():
                break;
            }
          }
        }

        count(parsed.blocks);
        expect(found, markers);
      });
    }
  });

  test('page ranges in the index come from the markers', () {
    final chapter5 = index.byId('big-book/06-chapter-5-how-it-works')!;
    expect(chapter5.firstPage, 58);
    expect(chapter5.lastPage, 71);
    expect(chapter5.pages, '58–71');
  });

  test('neighbours stay inside the collection', () {
    final step1 = index.inCollection(Collections.steps)[1];
    expect(index.previous(step1)!.title, 'Introduction');
    expect(index.next(step1)!.title, 'Step 2');
    expect(index.next(index.inCollection(Collections.steps).last), isNull);
  });

  test('every audio transcript points at a catalogue track', () {
    final catalogue = File('assets/audio/catalogue.json').readAsStringSync();
    for (final doc in index.documents.where((d) => d.trackId != null)) {
      expect(catalogue, contains('"id": ${doc.trackId},'), reason: doc.id);
      expect(catalogue, contains('"file": "${doc.audioFile}"'), reason: doc.id);
    }
  });
}
