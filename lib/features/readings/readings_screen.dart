import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/links/links.dart';
import '../../design/components/app_icons.dart';
import '../../design/components/list_row.dart';
import '../../design/tokens/spacing.dart';
import '../content/domain/content_index.dart';
import '../reader/content_opener.dart';
import '../reader/reader_screen.dart';
import '../shell/list_detail.dart';
import '../shell/tab_page.dart';
import '../sobriety/recovery_card.dart';

/// Readings tab (S-20): your recovery, Daily Reflections, prayers, readings, sobriety tips.
class ReadingsScreen extends ConsumerWidget {
  const ReadingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(contentIndexProvider);
    final opener = ref.read(contentOpenerProvider);

    List<Widget> section(String title, String collection, IconData icon) => [
      SectionHeader(title),
      RowGroup(
        children: [
          for (final e in index.inCollection(collection))
            Builder(
              builder: (context) => ListRow(
                title: e.title,
                leading: IconTile(icon),
                selected: ListDetailScope.isSelected(context, e.id),
                onTap: () => opener.open(context, e),
              ),
            ),
        ],
      ),
    ];

    return TabPage(
      title: 'Readings',
      body: ListDetail(
        placeholderIcon: AppIcons.readings,
        placeholderMessage: 'Choose a prayer or a reading to read it here.',
        detail: (context, id) => ReaderScreen(docId: id, embedded: true),
        pageRoute: Routes.read,
        list: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.only(top: Space.s, bottom: Space.x3),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.l),
                child: RecoveryCard(),
              ),
              const SizedBox(height: Space.l),
              RowGroup(
                children: [
                  // No advert before an external link (F-020, BUG-31).
                  ListRow(
                    title: 'Daily Reflections',
                    subtitle: 'Opens the official aa.org page',
                    leading: const IconTile(AppIcons.dailyReflections),
                    trailing: const Icon(AppIcons.openExternal, size: IconSizes.s),
                    semanticsLabel: 'Daily Reflections, opens the official aa.org page',
                    onTap: () => ref.read(linkOpenerProvider).open(AppLinks.dailyReflections),
                  ),
                ],
              ),
              ...section('Prayers', Collections.prayers, AppIcons.prayer),
              ...section('Readings', Collections.readings, AppIcons.reading),
              ...section('Sobriety tips', Collections.sobrietyTips, AppIcons.tip),
            ],
          ),
        ),
      ),
    );
  }
}
