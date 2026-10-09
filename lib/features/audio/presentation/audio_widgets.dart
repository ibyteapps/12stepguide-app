import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/connectivity.dart';
import '../../../design/components/app_icons.dart';
import '../../../design/components/dialogs.dart';
import '../../../design/components/states.dart';
import '../../../design/theme/app_colors.dart';
import '../../../design/tokens/color_tokens.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../premium/entitlement_controller.dart';
import '../application/downloads_controller.dart';
import '../data/download_gateway.dart';
import '../domain/catalogue.dart';

// --- Formatting -----------------------------------------------------------------------------

/// "4:05" or "1:02:09", for the scrubber.
String formatClock(Duration d) {
  final s = d.inSeconds.abs();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

/// "11 h 7 min", "47 min", for album and track lengths.
String formatLength(Duration d) {
  final minutes = (d.inSeconds / 60).round();
  if (minutes < 60) return '${minutes < 1 ? 1 : minutes} min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "245.3 MB", "1.24 GB" (decimal units, as the store and the native app's labels use).
String formatBytes(int bytes) {
  if (bytes >= 1000000000) return '${(bytes / 1e9).toStringAsFixed(2)} GB';
  if (bytes >= 1000000) return '${(bytes / 1e6).toStringAsFixed(1)} MB';
  if (bytes >= 1000) return '${(bytes / 1e3).round()} KB';
  return '$bytes bytes';
}

String plural(int n, String one, [String? many]) => n == 1 ? '$n $one' : '$n ${many ?? '${one}s'}';

// --- Artwork --------------------------------------------------------------------------------

/// An album's artwork, drawn from its palette (UX_UI_SPEC §6): large tiles carry the short name
/// on a scrim, as the lock-screen image does; small tiles carry a monogram.
class AlbumArt extends StatelessWidget {
  const AlbumArt({required this.album, required this.size, super.key});

  final Album album;
  final double size;

  static String monogram(String shortName) {
    final words = shortName
        .replaceAll('.', '')
        .split(' ')
        .where((w) => w.isNotEmpty && w != '&' && w != 'The')
        .toList();
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final large = size >= 120;
    final radius = BorderRadius.circular(size >= 120 ? Radii.lg : Radii.sm);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colorFromHex(album.gradient.first), colorFromHex(album.gradient.last)],
    );
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(gradient: gradient, borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: large
            ? Column(
                children: [
                  const Spacer(flex: 58),
                  Expanded(
                    flex: 42,
                    child: Container(
                      width: double.infinity,
                      color: FixedTokens.artworkScrim,
                      padding: EdgeInsets.symmetric(horizontal: size * 0.067),
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          album.shortName,
                          maxLines: 1,
                          style: TypeScale.title.copyWith(
                            color: FixedTokens.white,
                            fontWeight: FontWeight.w700,
                            fontSize: size * 0.11,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ColoredBox(
                color: FixedTokens.artworkScrim,
                child: Center(
                  child: Text(
                    monogram(album.shortName),
                    style: TypeScale.titleSmall.copyWith(
                      color: FixedTokens.white,
                      fontWeight: FontWeight.w700,
                      fontSize: size * 0.34,
                      height: 1,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The now-playing mark on an album or track row.
class NowPlayingMark extends StatelessWidget {
  const NowPlayingMark({this.playing = true, super.key});

  final bool playing;

  @override
  Widget build(BuildContext context) => Semantics(
    label: playing ? 'Now playing' : 'Paused',
    child: Icon(AppIcons.equaliser, color: context.colors.primary, size: IconSizes.m),
  );
}

// --- Downloads ------------------------------------------------------------------------------

/// Starts a download after the Premium and connection checks (A-05, F-065). Free users see the
/// paywall.
Future<void> requestDownload(BuildContext context, WidgetRef ref, List<Track> tracks) async {
  if (!ref.read(isPremiumProvider)) {
    await context.push(Routes.paywall);
    return;
  }
  if (ref.read(isOfflineProvider)) {
    showMessage(context, 'Connect to the internet to download.');
    return;
  }
  final controller = ref.read(downloadsProvider.notifier);
  for (final t in tracks) {
    await controller.download(t);
  }
}

String failureMessage(DownloadFailure? failure) => switch (failure) {
  DownloadFailure.storageFull => "There isn't enough space on this device.",
  DownloadFailure.network => 'The connection dropped.',
  DownloadFailure.server => "Couldn't reach the audio server.",
  _ => 'Something went wrong.',
};

/// The per-track download control (S-41): ⬇ / queued / progress ring / ✓ / failed ⟳.
class DownloadControl extends ConsumerWidget {
  const DownloadControl({required this.track, super.key});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(downloadsProvider.select((s) => s[track.id])) ?? DownloadState.none;
    final controller = ref.read(downloadsProvider.notifier);
    final title = track.title;

    switch (state.status) {
      case DownloadStatus.none:
        return IconButton(
          icon: Icon(AppIcons.download, color: c.textSecondary),
          tooltip: 'Download $title',
          onPressed: () => requestDownload(context, ref, [track]),
        );
      case DownloadStatus.queued:
        return IconButton(
          icon: Icon(AppIcons.pending, color: c.textSecondary),
          tooltip: 'Waiting to download $title. Cancel',
          onPressed: () => controller.remove(track),
        );
      case DownloadStatus.downloading:
        final percent = (state.progress * 100).round();
        return IconButton(
          tooltip: 'Downloading $title, $percent%. Cancel',
          onPressed: () => controller.remove(track),
          icon: SizedBox.square(
            dimension: IconSizes.m,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: state.progress > 0 ? state.progress : null,
                  strokeWidth: 2.5,
                  color: c.primary,
                  backgroundColor: c.surfaceAlt,
                ),
                Icon(AppIcons.stop, size: IconSizes.s * 0.6, color: c.primary),
              ],
            ),
          ),
        );
      case DownloadStatus.done:
        return IconButton(
          icon: Icon(AppIcons.downloaded, color: c.success),
          tooltip: '$title is downloaded. Remove download',
          onPressed: () async {
            final ok = await confirmAction(
              context,
              title: 'Remove this download?',
              message: '"$title" will stream again when you play it.',
              confirmLabel: 'Remove',
            );
            if (ok) await controller.remove(track);
          },
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: Icon(AppIcons.retry, color: c.warning),
          tooltip: 'Download of $title failed. Try again',
          onPressed: () {
            showMessage(context, '${failureMessage(state.failure)} Trying again.');
            controller.download(track);
          },
        );
    }
  }
}
