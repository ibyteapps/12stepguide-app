import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/prefs/key_value_store.dart';
import '../../design/components/app_icons.dart';
import '../../design/components/segmented_tabs.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../content/domain/content_index.dart';
import '../reader/content_opener.dart';
import '../reader/reader_screen.dart';
import '../reader/reading_positions.dart';
import '../shell/list_detail.dart';
import '../shell/tab_page.dart';

/// Big Book tab (S-30): Big Book · Stories, 1st ed. · Stories, 2nd ed., as card grids, with
/// "Continue reading" when there is a saved position (F-033, F-034, F-046).
class BigBookScreen extends ConsumerStatefulWidget {
  const BigBookScreen({super.key});

  @override
  ConsumerState<BigBookScreen> createState() => _BigBookScreenState();
}

class _BigBookScreenState extends ConsumerState<BigBookScreen> {
  late int _segment = ref.read(kvStoreProvider).getInt(PrefKeys.bigBookSegment) ?? 0;
  late final PageController _pages = PageController(initialPage: _segment);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _select(int i, {bool animate = true}) {
    setState(() => _segment = i);
    ref.read(kvStoreProvider).setInt(PrefKeys.bigBookSegment, i);
    if (animate && _pages.hasClients) {
      _pages.animateToPage(i, duration: Motion.of(context, Motion.medium), curve: Motion.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(contentIndexProvider);
    final positions = ref.watch(readingPositionsProvider.notifier);
    ref.watch(readingPositionsProvider);
    final ids = [
      for (final c in Collections.bigBookTabs)
        for (final d in index.inCollection(c)) d.id,
    ];
    final resumeId = positions.latestUnfinished(ids);
    final resume = resumeId == null ? null : index.byId(resumeId);

    return TabPage(
      title: 'The Big Book',
      body: ListDetail(
        placeholderIcon: AppIcons.bigBook,
        placeholderMessage: 'Choose a chapter or a story to read it here.',
        detail: (context, id) => ReaderScreen(docId: id, embedded: true),
        list: Column(
          children: [
            ContentWidth(
              maxWidth: 960,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.l, Space.xs, Space.l, Space.s),
                child: Column(
                  children: [
                    SegmentedTabs(
                      labels: const ['Big Book', 'Stories, 1st ed.', 'Stories, 2nd ed.'],
                      shortLabels: const ['Big Book', '1st ed.', '2nd ed.'],
                      selected: _segment,
                      onChanged: _select,
                    ),
                    if (resume != null) ...[
                      const SizedBox(height: Space.s),
                      _ContinueChip(entry: resume),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => _select(i, animate: false),
                children: [
                  for (final c in Collections.bigBookTabs)
                    _Grid(key: PageStorageKey(c), entries: index.inCollection(c)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueChip extends ConsumerWidget {
  const _ContinueChip({required this.entry});

  final DocEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final position = ref.watch(readingPositionsProvider)[entry.id];
    final where = position?.page != null ? ' · page ${position!.page}' : '';
    return Semantics(
      button: true,
      label: 'Continue reading ${entry.title}$where',
      excludeSemantics: true,
      child: Material(
        color: c.primaryContainer,
        borderRadius: Radii.pillAll,
        child: InkWell(
          borderRadius: Radii.pillAll,
          onTap: () => ref.read(contentOpenerProvider).open(context, entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
            child: Row(
              children: [
                Icon(AppIcons.bookmark, color: c.onPrimaryContainer, size: IconSizes.s),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Continue reading: ',
                          style: TextStyle(fontWeight: FontWeight.w400),
                        ),
                        TextSpan(text: '${entry.title}$where'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.label.copyWith(color: c.onPrimaryContainer),
                  ),
                ),
                Icon(AppIcons.chevron, color: c.onPrimaryContainer, size: IconSizes.s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({required this.entries, super.key});

  final List<DocEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      // Columns follow the grid's own width, which is narrower beside a reading (F-101).
      builder: (context, constraints) => _grid(context, constraints.maxWidth, textScale),
    );
  }

  Widget _grid(BuildContext context, double width, double textScale) {
    final columns = textScale >= 1.6
        ? 1
        : width >= Breakpoints.expanded
        ? 4
        : width >= Breakpoints.medium
        ? 3
        : 2;
    return ContentWidth(
      maxWidth: 960,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.x3),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: Space.m,
          crossAxisSpacing: Space.m,
          mainAxisExtent: 132 * textScale.clamp(1.0, 1.5),
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) => _Card(entry: entries[i], index: i, count: entries.length),
      ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.entry, required this.index, required this.count});

  final DocEntry entry;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pages = entry.pages;
    final selected = ListDetailScope.isSelected(context, entry.id);
    return Semantics(
      button: true,
      selected: selected,
      label: '${entry.title}${pages != null ? ', pages $pages' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? c.primaryContainer : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: c.strokeAt(index, count), width: selected ? 2.5 : 1.5),
        ),
        child: InkWell(
          borderRadius: Radii.mdAll,
          onTap: () => ref.read(contentOpenerProvider).open(context, entry),
          child: Padding(
            padding: const EdgeInsets.all(Space.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${entry.order}', style: TypeScale.overline.copyWith(color: c.textTertiary)),
                const SizedBox(height: Space.xs),
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.cardTitle.copyWith(color: c.textPrimary),
                  ),
                ),
                // F-035: no "Pages –––" placeholder when the range is unknown.
                if (pages != null)
                  Text('Pages $pages', style: TypeScale.caption.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
