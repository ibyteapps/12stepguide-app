import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/design/components/list_row.dart';
import 'package:twelve_step_guide/features/reader/reader_screen.dart';
import 'package:twelve_step_guide/features/shell/list_detail.dart';

import '../helpers/test_app.dart';

/// F-101: on expanded widths, readings and albums open beside their list.
void main() {
  const prefs = {PrefKeys.coachMarkSeen: true};

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Steps: a placeholder, then the step beside the list', (tester) async {
    await pumpApp(tester, size: tablet, ratio: 2, prefs: prefs);
    expect(find.text('Choose a step or a tradition to read it here.'), findsOneWidget);

    await tester.tap(find.text('Step 4'));
    await settle(tester);

    // The list is still there and the reading is embedded, not pushed as a page.
    expect(find.text('Step 1'), findsOneWidget);
    final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
    expect(reader.embedded, isTrue);
    expect(reader.docId, 'steps/04-step-4');
    expect(find.textContaining('Step 4 marks a major turning point'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    // The open step is marked in the list.
    final row = tester.widget<ListRow>(
      find.ancestor(of: find.text('Step 4'), matching: find.byType(ListRow)),
    );
    expect(row.selected, isTrue);
  });

  testWidgets('Big Book: a chapter opens beside the grid', (tester) async {
    await pumpApp(tester, location: '/big-book', size: tablet, ratio: 2, prefs: prefs);
    await tester.tap(find.text('Chapter 5: How It Works'));
    await settle(tester);
    final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
    expect(reader.docId, 'big-book/06-chapter-5-how-it-works');
    expect(find.textContaining('Rarely have we seen a person fail'), findsOneWidget);
  });

  testWidgets('Readings: a prayer opens beside the list', (tester) async {
    await pumpApp(tester, location: '/readings', size: tablet, ratio: 2, prefs: prefs);
    await tester.tap(find.text('Serenity Prayer'));
    await settle(tester);
    expect(tester.widget<ReaderScreen>(find.byType(ReaderScreen)).docId, startsWith('prayers/'));
  });

  testWidgets('Audio: an album opens beside the album list', (tester) async {
    await pumpApp(tester, location: '/audio', size: tablet, ratio: 2);
    expect(find.text('Choose an album to see its recordings here.'), findsOneWidget);
    await tester.tap(find.text('Joe & Charlie - Big Book Study'));
    await settle(tester);
    expect(find.text('Play all'), findsOneWidget);
    expect(find.text('AA History - Part 1'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('when the window narrows, the list keeps its segment and the open tradition '
      'stays open as a page', (tester) async {
    await pumpApp(tester, size: tablet, ratio: 2, prefs: prefs);
    await tester.tap(find.text('Traditions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tradition 2'));
    await settle(tester);
    expect(tester.widget<ReaderScreen>(find.byType(ReaderScreen)).embedded, isTrue);

    // A rotation or Split View makes the window too narrow for two panes.
    tester.view.physicalSize = const Size(700, 1366) * 2;
    await settle(tester);
    final page = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
    expect(page.embedded, isFalse);
    expect(page.docId, 'traditions/02-tradition-2');

    // Back to the list: still on Traditions, not Steps.
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('Tradition 1'), findsOneWidget);
    expect(find.text('Step 1'), findsNothing);

    // Wide again: two panes, still on Traditions.
    tester.view.physicalSize = tablet * 2;
    await settle(tester);
    expect(find.text('Tradition 1'), findsOneWidget);
    expect(find.text('Choose a step or a tradition to read it here.'), findsOneWidget);
  });

  testWidgets('a phone keeps one pane and opens readings as pages', (tester) async {
    await pumpApp(tester, prefs: prefs);
    expect(find.byType(ListDetailScope), findsNothing);
    await tester.tap(find.text('Step 4'));
    await settle(tester);
    expect(tester.widget<ReaderScreen>(find.byType(ReaderScreen)).embedded, isFalse);
  });
}
