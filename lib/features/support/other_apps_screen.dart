import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/links/links.dart';
import '../../design/components/app_icons.dart';
import '../../design/components/list_row.dart';
import '../../design/tokens/spacing.dart';
import '../shell/tab_page.dart';

class _OtherApp {
  const _OtherApp(this.title, this.subtitle, this.url);
  final String title;
  final String subtitle;
  final String url;
}

/// Our other apps (S-56, F-024): what each native app lists today (D-008 / Q-P4). Opens the
/// store; never preceded by an advert.
class OtherAppsScreen extends ConsumerWidget {
  const OtherAppsScreen({super.key});

  static final _ios = [
    _OtherApp('12 Step Toolkit', 'Free 12 Step toolkit', AppLinks.appleApp('1452072215')),
    _OtherApp('Speaker Tapes', 'Free: 100+ audio tapes', AppLinks.appleApp('1335643834')),
    _OtherApp('Sober Today', 'Free recovery day counter', AppLinks.appleApp('1239464706')),
    _OtherApp('The Big Book', 'Big Book audiobook', AppLinks.appleApp('1111214132')),
    _OtherApp(
      'Joe & Charlie Big Book Study',
      'Audiobook with transcripts',
      AppLinks.appleApp('902251318'),
    ),
  ];

  static final _android = [
    _OtherApp(
      'Big Book e-Reader + Audio',
      'The Big Book, to read and to listen',
      AppLinks.playApp('app.aabigbook.reader'),
    ),
    _OtherApp(
      'Joe & Charlie Free',
      'Big Book study audio',
      AppLinks.playApp('com.ibyteapps.joeandcharliefree'),
    ),
    _OtherApp(
      'Sober Today',
      'Free recovery day counter',
      AppLinks.playApp('com.ibyteapps.sobertoday'),
    ),
    _OtherApp(
      '12 Step Toolkit',
      'Free 12 Step toolkit',
      AppLinks.playApp('com.ibyteapps.aa12steptoolkit'),
    ),
    _OtherApp(
      'Meeting Finder',
      'Find a meeting near you',
      AppLinks.playApp('com.ibyteapps.meetingfinder'),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = AppLinks.isApple ? _ios : _android;
    final opener = ref.read(linkOpenerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Our other apps')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: Space.l),
          children: [
            RowGroup(
              children: [
                for (final app in apps)
                  ListRow(
                    title: app.title,
                    subtitle: app.subtitle,
                    leading: const IconTile(AppIcons.otherApps),
                    trailing: const Icon(AppIcons.openExternal, size: IconSizes.s),
                    onTap: () => opener.open(app.url),
                  ),
              ],
            ),
            const SizedBox(height: Space.l),
            RowGroup(
              children: [
                ListRow(
                  title: 'More from iByte Apps',
                  leading: const IconTile(AppIcons.otherApps),
                  trailing: const Icon(AppIcons.openExternal, size: IconSizes.s),
                  onTap: () => opener.open(
                    AppLinks.isApple ? AppLinks.appleDeveloper : AppLinks.playDeveloper,
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
