import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../design/components/app_icons.dart';
import '../../../design/components/dialogs.dart';
import '../../../design/components/list_row.dart';
import '../../../design/components/states.dart';
import '../../../design/theme/app_colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../premium/entitlement_controller.dart';
import '../../shell/tab_page.dart';
import '../application/downloads_controller.dart';
import '../domain/catalogue.dart';
import 'audio_widgets.dart';

/// Downloads (S-54, F-065): storage used, downloads by album with Remove, Remove all, and
/// "Download over Wi-Fi only". A lapsed Premium user is told why the files now stream (A-05).
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final catalogue = ref.watch(catalogueProvider);
    final downloads = ref.watch(downloadsProvider);
    final controller = ref.read(downloadsProvider.notifier);
    final premium = ref.watch(isPremiumProvider);
    final wifiOnly = ref.watch(wifiOnlyProvider);

    final done = downloads.values.where((d) => d.status == DownloadStatus.done).length;
    final active = downloads.values.where((d) => d.isActive).length;
    final albums = [
      for (final a in catalogue.albums)
        if (a.tracks.any((t) => downloads.containsKey(t.id))) a,
    ];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Downloads')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.x3),
          children: [
            const SizedBox(height: Space.l),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.l),
              child: _StorageCard(bytes: controller.bytesUsed(), recordings: done, active: active),
            ),
            if (!premium && done > 0)
              Padding(
                padding: const EdgeInsets.only(left: Space.l, top: Space.l, right: Space.l),
                child: InlineBanner(
                  icon: AppIcons.premium,
                  tone: BannerTone.warning,
                  message:
                      'Without Premium, these recordings stream instead of playing from your '
                      'device. Remove them to free up space, or renew Premium to listen offline.',
                  actionLabel: 'Premium',
                  onAction: () => context.push(Routes.premium),
                ),
              ),
            const SectionHeader('Settings'),
            RowGroup(
              children: [
                SwitchListTile.adaptive(
                  value: wifiOnly,
                  onChanged: ref.read(wifiOnlyProvider.notifier).set,
                  title: Text(
                    'Download over Wi-Fi only',
                    style: TypeScale.body.copyWith(color: c.textPrimary),
                  ),
                  subtitle: Text(
                    'Recordings are 1 to 50 MB each.',
                    style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
            SectionHeader(albums.isEmpty ? 'Downloaded' : 'By album'),
            if (albums.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.l),
                child: Text(
                  premium
                      ? 'Nothing downloaded yet. Open an album and tap ⬇ next to a track, or '
                            'Download all, to listen without a connection.'
                      : 'Premium members can download any of the '
                            '${catalogue.allTracks.length} recordings to listen without a '
                            'connection.',
                  style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
                ),
              )
            else
              RowGroup(
                children: [
                  for (final a in albums)
                    _AlbumDownloads(album: a, downloads: downloads, bytes: controller.bytesUsed(a)),
                ],
              ),
            if (albums.isNotEmpty) ...[
              const SizedBox(height: Space.xxl),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: c.error),
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Remove all downloads?',
                      message:
                          'Every downloaded recording will be removed from this device. '
                          'They will stream when you play them.',
                      confirmLabel: 'Remove all',
                    );
                    if (ok) await controller.removeAll();
                  },
                  icon: const Icon(AppIcons.delete),
                  label: const Text('Remove all downloads'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.bytes, required this.recordings, required this.active});

  final int bytes;
  final int recordings;
  final int active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.mdAll),
      child: Row(
        children: [
          const IconTile(AppIcons.storage),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recordings == 0 ? 'No storage used' : '${formatBytes(bytes)} used',
                  style: TypeScale.titleSmall.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  [
                    '${plural(recordings, 'recording')} on this device',
                    if (active > 0) '$active downloading',
                  ].join(' · '),
                  style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumDownloads extends ConsumerWidget {
  const _AlbumDownloads({required this.album, required this.downloads, required this.bytes});

  final Album album;
  final Map<int, DownloadState> downloads;
  final int bytes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final done = album.tracks.where((t) => downloads[t.id]?.status == DownloadStatus.done).length;
    final active = album.tracks.where((t) => downloads[t.id]?.isActive ?? false).length;
    final details = [
      '$done of ${album.tracks.length}',
      if (bytes > 0) formatBytes(bytes),
      if (active > 0) '$active downloading',
    ].join(' · ');
    return Row(
      children: [
        Expanded(
          child: ListRow(
            title: album.title,
            subtitle: details,
            leading: AlbumArt(album: album, size: Space.x4),
            onTap: () => context.push(Routes.album(album.id)),
            showChevron: false,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: c.error),
          onPressed: () async {
            final ok = await confirmAction(
              context,
              title: 'Remove downloads?',
              message: 'The downloaded tracks of ${album.title} will be removed from this device.',
              confirmLabel: 'Remove',
            );
            if (ok) await ref.read(downloadsProvider.notifier).removeAlbum(album);
          },
          child: Text('Remove', semanticsLabel: 'Remove ${album.title} downloads'),
        ),
        const SizedBox(width: Space.s),
      ],
    );
  }
}
