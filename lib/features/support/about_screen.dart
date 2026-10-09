import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/links/links.dart';
import '../../design/components/app_icons.dart';
import '../../design/components/list_row.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../shell/tab_page.dart';

/// About (S-57): name, version and build, the disclaimer, credits and open-source licences.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const disclaimer =
      '12 Step Guide is not affiliated with or endorsed by Alcoholics Anonymous or A.A. World '
      'Services, Inc.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final info = ref.watch(launchInfoProvider);
    final opener = ref.read(linkOpenerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ContentWidth(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.all(Space.xxl),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: Radii.lgAll,
                child: Image.asset(
                  'assets/images/app-icon.png',
                  width: 88,
                  height: 88,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            const SizedBox(height: Space.l),
            Text(
              '12 Step Guide',
              textAlign: TextAlign.center,
              style: TypeScale.headline.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Version ${info.version} (${info.buildNumber})',
              textAlign: TextAlign.center,
              style: TypeScale.bodySmall.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: Space.xxl),
            Text(
              disclaimer,
              textAlign: TextAlign.center,
              style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.l),
            Text(
              'Made by iByte Apps Limited, United Kingdom. The step guides were written by a '
              'long-term sober member. Recordings are streamed from our server; your recovery '
              'date, reading positions and settings stay on this device.',
              textAlign: TextAlign.center,
              style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.xxl),
            RowGroup(
              margin: EdgeInsets.zero,
              children: [
                ListRow(
                  title: 'Privacy policy',
                  leading: const IconTile(AppIcons.privacyPolicy),
                  trailing: const Icon(AppIcons.openExternal, size: IconSizes.s),
                  onTap: () => opener.open(AppLinks.privacyPolicy),
                ),
                ListRow(
                  title: 'Terms of use',
                  leading: const IconTile(AppIcons.terms),
                  trailing: const Icon(AppIcons.openExternal, size: IconSizes.s),
                  onTap: () => opener.open(AppLinks.terms),
                ),
                ListRow(
                  title: 'Open-source licences',
                  leading: const IconTile(AppIcons.about),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: '12 Step Guide',
                    applicationVersion: '${info.version} (${info.buildNumber})',
                    applicationLegalese: '© iByte Apps Limited',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
