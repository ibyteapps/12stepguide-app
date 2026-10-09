import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/platform/connectivity.dart';
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
import '../application/player_controller.dart';
import '../domain/catalogue.dart';
import 'audio_widgets.dart';

/// Starts [album] at [index] and opens the full player, or explains why it can't (S-41).
Future<void> playAndOpen(BuildContext context, WidgetRef ref, Album album, int index) async {
  final outcome = await ref.read(playerProvider.notifier).playAlbum(album, index);
  if (!context.mounted) return;
  switch (outcome) {
    case PlayOutcome.started:
      await context.push(Routes.player);
    case PlayOutcome.offline:
      showMessage(context, 'Connect to the internet to play this track.');
  }
}

/// An album (S-41, F-061): Play all, Download all, Remove downloads, and the tracks with their
/// download state. The native ⋯ menu's actions are visible buttons here.
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({required this.albumId, super.key});

  final int albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final album = ref.watch(catalogueProvider).album(albumId);
    if (album == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const StateMessage(icon: AppIcons.audio, message: "This album isn't available."),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(album.shortName)),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.x3),
          children: [
            _Header(album: album, wide: wide),
            if (ref.watch(isOfflineProvider))
              const Padding(
                padding: EdgeInsets.only(left: Space.l, right: Space.l, bottom: Space.s),
                child: InlineBanner(
                  icon: AppIcons.offline,
                  tone: BannerTone.warning,
                  message: "You're offline — downloaded tracks still play.",
                ),
              ),
            RowGroup(
              children: [
                for (var i = 0; i < album.tracks.length; i++) _TrackRow(album: album, index: i),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.album, required this.wide});

  final Album album;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final premium = ref.watch(isPremiumProvider);
    final downloads = ref.watch(downloadsProvider);
    final states = [for (final t in album.tracks) downloads[t.id]?.status];
    final done = states.where((s) => s == DownloadStatus.done).length;
    final active = states.where(
      (s) => s == DownloadStatus.queued || s == DownloadStatus.downloading,
    );
    final allDone = done == album.tracks.length;
    final total = album.tracks.length;

    final info = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Semantics(
          header: true,
          child: Text(
            album.title,
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: TypeScale.title.copyWith(color: c.textPrimary),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          '${plural(total, 'track')} · ${formatLength(album.duration)}'
          '${done > 0 ? ' · $done downloaded' : ''}',
          style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.l),
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => playAndOpen(context, ref, album, 0),
              icon: const Icon(AppIcons.playAll),
              label: const Text('Play all'),
            ),
            if (!allDone)
              OutlinedButton.icon(
                onPressed: active.isNotEmpty && premium
                    ? null
                    : () => requestDownload(context, ref, album.tracks),
                icon: Icon(premium ? AppIcons.download : AppIcons.lock),
                label: Text(active.isNotEmpty && premium ? 'Downloading…' : 'Download all'),
              ),
            if (done > 0 || active.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Remove downloads?',
                    message:
                        'The downloaded tracks of ${album.title} will be removed from this device. '
                        'They will stream when you play them.',
                    confirmLabel: 'Remove',
                  );
                  if (ok) await ref.read(downloadsProvider.notifier).removeAlbum(album);
                },
                icon: const Icon(AppIcons.delete),
                label: const Text('Remove downloads'),
              ),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.l, Space.xxl, Space.xxl),
      child: wide
          ? Row(
              children: [
                AlbumArt(album: album, size: 180),
                const SizedBox(width: Space.xxl),
                Expanded(child: info),
              ],
            )
          : Column(
              children: [
                AlbumArt(album: album, size: 180),
                const SizedBox(height: Space.l),
                info,
              ],
            ),
    );
  }
}

class _TrackRow extends ConsumerWidget {
  const _TrackRow({required this.album, required this.index});

  final Album album;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final track = album.tracks[index];
    final playing = ref.watch(
      playerProvider.select((s) => s.current?.track.id == track.id ? s.playing : null),
    );
    final offline = ref.watch(isOfflineProvider);
    final downloaded = ref.watch(
      downloadsProvider.select((s) => s[track.id]?.status == DownloadStatus.done),
    );
    final unavailable = offline && !downloaded;

    // Two touch targets: the row plays, the control downloads. Separate for screen readers too.
    return Opacity(
      opacity: unavailable ? 0.55 : 1,
      child: Material(
        color: playing != null ? c.primaryContainer : c.surface.withAlpha(0),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                selected: playing != null,
                label: [
                  'Track ${track.number}, ${track.title}',
                  formatLength(track.duration),
                  if (downloaded) 'downloaded',
                  if (playing != null) playing ? 'now playing' : 'paused',
                ].join(', '),
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => playAndOpen(context, ref, album, index),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Space.row),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.s, Space.m),
                      child: Row(
                        children: [
                          if (playing != null)
                            SizedBox.square(
                              dimension: Space.x4,
                              child: Center(child: NowPlayingMark(playing: playing)),
                            )
                          else
                            NumberBadge(number: track.number),
                          const SizedBox(width: Space.l),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  style: TypeScale.body.copyWith(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: Space.xxs),
                                Text(
                                  formatClock(track.duration),
                                  style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            DownloadControl(track: track),
            const SizedBox(width: Space.xs),
          ],
        ),
      ),
    );
  }
}
