import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../design/components/app_icons.dart';
import '../../../design/theme/app_colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../application/player_controller.dart';
import 'audio_widgets.dart';

/// The mini-player (S-43, UNIFIED_PRODUCT_SPEC §3.3): a 64 dp bar above the tabs whenever a
/// track is loaded. Tap opens the full player; ✕ or a swipe down stops playback and hides it.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(playerProvider.select((s) => s.current));
    return AnimatedSize(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: item == null ? const SizedBox(width: double.infinity) : const _Bar(),
    );
  }
}

class _Bar extends ConsumerWidget {
  const _Bar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(playerProvider);
    final item = s.current!;
    final player = ref.read(playerProvider.notifier);
    final total = (s.duration ?? item.track.duration).inMilliseconds;
    final progress = total <= 0 ? 0.0 : (s.position.inMilliseconds / total).clamp(0.0, 1.0);
    final title = '${item.track.number}. ${item.track.title}';

    return Dismissible(
      key: ValueKey('mini-${item.track.id}'),
      direction: DismissDirection.down,
      onDismissed: (_) => player.stop(),
      child: Material(
        color: c.surfaceRaised,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.divider)),
          ),
          child: SizedBox(
            height: Space.miniPlayer,
            child: Column(
              children: [
                ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: Space.xxs,
                    color: c.primary,
                    backgroundColor: c.surfaceRaised.withAlpha(0),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Now playing: $title, ${item.album.title}. Open player',
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: () => context.push(Routes.player),
                            child: Padding(
                              padding: const EdgeInsets.only(left: Space.l, right: Space.s),
                              child: Row(
                                children: [
                                  AlbumArt(album: item.album, size: Space.x4),
                                  const SizedBox(width: Space.m),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TypeScale.cardTitle.copyWith(color: c.textPrimary),
                                        ),
                                        Text(
                                          item.album.shortName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TypeScale.caption.copyWith(color: c.textSecondary),
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
                      if (s.isBuffering && !s.playing)
                        SizedBox.square(
                          dimension: Space.touch,
                          child: Center(
                            child: SizedBox.square(
                              dimension: IconSizes.s,
                              child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(
                            s.playing ? AppIcons.pause : AppIcons.play,
                            color: c.textPrimary,
                            fill: 1,
                          ),
                          tooltip: s.playing ? 'Pause' : 'Play',
                          onPressed: player.toggle,
                        ),
                      IconButton(
                        icon: Icon(AppIcons.close, color: c.textSecondary),
                        tooltip: 'Stop and close player',
                        onPressed: player.stop,
                      ),
                      const SizedBox(width: Space.xs),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
