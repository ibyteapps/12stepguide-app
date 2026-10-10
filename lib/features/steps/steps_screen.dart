import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/prefs/key_value_store.dart';
import '../../design/components/app_icons.dart';
import '../../design/components/list_row.dart';
import '../../design/components/segmented_tabs.dart';
import '../../design/tokens/spacing.dart';
import '../content/domain/content_index.dart';
import '../reader/content_opener.dart';
import '../reader/reader_screen.dart';
import '../shell/list_detail.dart';
import '../shell/tab_page.dart';

/// Steps tab (S-10): Steps | Traditions (D-001), remembering the last segment.
class StepsScreen extends ConsumerStatefulWidget {
  const StepsScreen({super.key});

  @override
  ConsumerState<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends ConsumerState<StepsScreen> {
  late int _segment = ref.read(kvStoreProvider).getInt(PrefKeys.stepsSegment) ?? 0;
  late final PageController _pages = PageController(initialPage: _segment);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _select(int i, {bool animate = true}) {
    setState(() => _segment = i);
    ref.read(kvStoreProvider).setInt(PrefKeys.stepsSegment, i);
    if (animate && _pages.hasClients) {
      _pages.showPage(context, i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(contentIndexProvider);
    return TabPage(
      title: 'Steps',
      body: ListDetail(
        placeholderIcon: AppIcons.steps,
        placeholderMessage: 'Choose a step or a tradition to read it here.',
        detail: (context, id) => ReaderScreen(docId: id, embedded: true),
        pageRoute: Routes.read,
        list: Column(
          children: [
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.l, Space.xs, Space.l, Space.s),
                child: SegmentedTabs(
                  labels: const ['Steps', 'Traditions'],
                  selected: _segment,
                  onChanged: _select,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => _select(i, animate: false),
                children: [
                  _DocList(entries: index.inCollection(Collections.steps), kind: _Kind.steps),
                  _DocList(
                    entries: index.inCollection(Collections.traditions),
                    kind: _Kind.traditions,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Kind { steps, traditions }

class _DocList extends ConsumerWidget {
  const _DocList({required this.entries, required this.kind});

  final List<DocEntry> entries;
  final _Kind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opener = ref.read(contentOpenerProvider);
    return ContentWidth(
      child: ListView(
        key: PageStorageKey(kind),
        padding: const EdgeInsets.only(top: Space.s, bottom: Space.x3),
        children: [
          RowGroup(
            children: [
              for (final e in entries)
                ListRow(
                  title: e.title,
                  subtitle: _subtitle(e),
                  leading: _badge(e),
                  selected: ListDetailScope.isSelected(context, e.id),
                  onTap: () => opener.open(context, e),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String? _subtitle(DocEntry e) {
    if (e.subtitle != null) return e.subtitle;
    if (e.order == 0) return 'How to use this guide';
    if (e.title == 'Conclusion') return 'Where the journey goes from here';
    return null;
  }

  Widget _badge(DocEntry e) {
    if (kind == _Kind.steps && e.order == 0) return const NumberBadge(icon: AppIcons.intro);
    if (kind == _Kind.steps && e.title == 'Conclusion') {
      return const NumberBadge(icon: AppIcons.conclusion);
    }
    return NumberBadge(number: e.order);
  }
}
