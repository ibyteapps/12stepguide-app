import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/platform/connectivity.dart';
import '../../../design/components/app_icons.dart';
import '../../../design/components/list_row.dart';
import '../../../design/components/states.dart';
import '../../../design/theme/app_colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../shell/tab_page.dart';
import '../application/downloads_controller.dart';
import '../application/player_controller.dart';
import '../domain/catalogue.dart';
import 'audio_widgets.dart';

/// Audio tab (S-40, F-060): the 11 albums with length, downloads and what is playing.
class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider);
    final offline = ref.watch(isOfflineProvider);
    final hours = (catalogue.totalDuration.inMinutes / 60).round();

    return TabPage(
      title: 'Audio',
      // The tab's contextual action (UNIFIED_PRODUCT_SPEC §3.2).
      actions: [
        IconButton(
          icon: const Icon(AppIcons.downloads),
          tooltip: 'Downloads',
          onPressed: () => context.push(Routes.downloads),
        ),
      ],
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          children: [
            if (offline)
              const Padding(
                padding: EdgeInsets.only(left: Space.l, top: Space.s, right: Space.l),
                child: InlineBanner(
                  icon: AppIcons.offline,
                  tone: BannerTone.warning,
                  message: "You're offline — downloaded tracks still play.",
                ),
              ),
            SectionHeader('${catalogue.albums.length} albums · about $hours hours'),
            RowGroup(
              children: [
                for (final album in catalogue.albums) _AlbumRow(album: album, offline: offline),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumRow extends ConsumerWidget {
  const _AlbumRow({required this.album, required this.offline});

  final Album album;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final downloads = ref.watch(downloadsProvider);
    final downloaded = album.tracks
        .where((t) => downloads[t.id]?.status == DownloadStatus.done)
        .length;
    final playing = ref.watch(
      playerProvider.select((s) => s.current?.album.id == album.id ? s.playing : null),
    );
    final total = album.tracks.length;
    final details = '${plural(total, 'track')} · ${formatLength(album.duration)}';
    final badge = downloaded == 0
        ? null
        : downloaded == total
        ? 'Downloaded'
        : 'Downloaded $downloaded/$total';
    final dim = offline && downloaded == 0;

    return Opacity(
      opacity: dim ? 0.55 : 1,
      child: Semantics(
        button: true,
        label: [
          album.title,
          details,
          ?badge,
          if (playing != null) playing ? 'now playing' : 'paused',
          if (dim) 'not available offline',
        ].join(', '),
        excludeSemantics: true,
        child: InkWell(
          onTap: () => context.push(Routes.album(album.id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
            child: Row(
              children: [
                AlbumArt(album: album, size: Space.x5 + Space.l),
                const SizedBox(width: Space.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title,
                        style: TypeScale.body.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(details, style: TypeScale.bodySmall.copyWith(color: c.textSecondary)),
                      if (badge != null) ...[
                        const SizedBox(height: Space.xs),
                        Row(
                          children: [
                            Icon(AppIcons.downloaded, size: IconSizes.s * 0.8, color: c.success),
                            const SizedBox(width: Space.xs),
                            Text(badge, style: TypeScale.label.copyWith(color: c.success)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (playing != null) ...[
                  const SizedBox(width: Space.s),
                  NowPlayingMark(playing: playing),
                ],
                const SizedBox(width: Space.s),
                Icon(AppIcons.chevron, color: c.textTertiary, size: IconSizes.m),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
