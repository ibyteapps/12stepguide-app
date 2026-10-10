import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../design/components/app_icons.dart';
import '../../../design/components/states.dart';
import '../../../design/components/text_scale.dart';
import '../../../design/theme/app_colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../../ads/banner_slot.dart';
import '../../appearance/appearance_controller.dart';
import '../../appearance/text_size_sheet.dart';
import '../../content/data/document_repository.dart';
import '../../content/domain/content_index.dart';
import '../../content/presentation/document_blocks.dart';
import '../application/player_controller.dart';
import '../data/audio_engine.dart';
import 'audio_widgets.dart';

/// The full player (S-42, F-063): transcript (Joe & Charlie, Big Book) or artwork, the track,
/// scrubber, ⟲10 · previous · play/pause · next · 10⟳, buffering and error states, and the
/// banner under the controls. Drag the handle down to close.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  double _drag = 0;
  bool _slow = false;
  Timer? _slowTimer;

  /// After this long buffering, say the connection is slow (S-42).
  static const slowAfter = Duration(seconds: 3);

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  void _onBuffering(bool buffering) {
    _slowTimer?.cancel();
    if (buffering) {
      _slowTimer = Timer(slowAfter, () {
        if (mounted) setState(() => _slow = true);
      });
    } else if (_slow) {
      setState(() => _slow = false);
    }
  }

  void _close() {
    // Already on its way out (✕ was tapped, then playback stopped): nothing to close.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    ref.listen(playerProvider.select((s) => s.isBuffering), (_, b) => _onBuffering(b));
    // The ✕ on the mini-player or the notification stopped playback: nothing left to show.
    ref.listen(playerProvider.select((s) => s.hasTrack), (was, has) {
      if ((was ?? false) && !has) _close();
    });
    final item = ref.watch(playerProvider.select((s) => s.current));
    if (item == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(AppIcons.expand),
            tooltip: 'Close player',
            onPressed: _close,
          ),
        ),
        body: const StateMessage(icon: AppIcons.audio, message: 'Nothing is playing.'),
      );
    }

    final transcript = item.album.hasTranscripts
        ? ref.watch(contentIndexProvider).transcriptFor(item.track.id)
        : null;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= Breakpoints.expanded && size.width > size.height;

    final media = transcript != null
        ? _Transcript(entry: transcript)
        : LayoutBuilder(
            builder: (context, box) => Center(
              child: AlbumArt(
                album: item.album,
                size: math.max(120, math.min(360, math.min(box.maxWidth, box.maxHeight) - 48)),
              ),
            ),
          );
    final controls = _Controls(slow: _slow);

    return Transform.translate(
      offset: Offset(0, _drag),
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) =>
                    setState(() => _drag = math.max(0, _drag + d.delta.dy)),
                onVerticalDragEnd: (d) {
                  if (_drag > 120 || (d.primaryVelocity ?? 0) > 700) {
                    _close();
                  } else {
                    setState(() => _drag = 0);
                  }
                },
                child: _TopBar(
                  albumTitle: item.album.title,
                  showTextSize: transcript != null,
                  onClose: _close,
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(flex: 5, child: media),
                          Expanded(
                            flex: 4,
                            child: Center(child: SingleChildScrollView(child: controls)),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: media),
                          controls,
                        ],
                      ),
              ),
              const BannerSlot(placement: BannerPlacement.player),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.albumTitle, required this.showTextSize, required this.onClose});

  final String albumTitle;
  final bool showTextSize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        const SizedBox(height: Space.s),
        ExcludeSemantics(
          child: Container(
            width: Space.x4,
            height: Space.xs,
            decoration: BoxDecoration(color: c.outline, borderRadius: Radii.pillAll),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(AppIcons.expand),
                tooltip: 'Close player',
                onPressed: onClose,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('NOW PLAYING', style: TypeScale.overline.copyWith(color: c.textTertiary)),
                    Text(
                      albumTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TypeScale.label.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (showTextSize)
                IconButton(
                  icon: const Icon(AppIcons.textSize),
                  tooltip: 'Text size and theme',
                  onPressed: () => showTextSizeSheet(context),
                )
              else
                const SizedBox(width: Space.touch),
            ],
          ),
        ),
      ],
    );
  }
}

class _Transcript extends ConsumerWidget {
  const _Transcript({required this.entry});

  final DocEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final doc = ref.watch(documentProvider(entry.id));
    final step = ref.watch(appearanceProvider.select((s) => s.textStep));
    return Padding(
      padding: const EdgeInsets.only(left: Space.l, top: Space.s, right: Space.l),
      child: ClipRRect(
        borderRadius: Radii.mdAll,
        child: ColoredBox(
          color: c.surfaceReader,
          child: Semantics(
            label: 'Transcript',
            container: true,
            child: doc.when(
              data: (d) => ReadingTextScale(
                child: SelectionArea(
                  child: ListView.builder(
                    key: PageStorageKey('transcript-${entry.id}'),
                    padding: const EdgeInsets.all(Space.xl),
                    itemCount: d.blocks.length,
                    itemBuilder: (context, i) => DocBlockView(
                      block: d.blocks[i],
                      textStep: step,
                      onLink: (_) {},
                      isFirst: i == 0,
                    ),
                  ),
                ),
              ),
              loading: () =>
                  const Padding(padding: EdgeInsets.all(Space.xl), child: SkeletonLines()),
              error: (_, _) => const StateMessage(
                icon: AppIcons.error,
                message: "The transcript couldn't load.",
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.slow});

  final bool slow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(playerProvider);
    final player = ref.read(playerProvider.notifier);
    final item = s.current!;
    final error = s.status == EngineStatus.error;

    Future<void> retry() async {
      final outcome = await player.retry();
      if (outcome == PlayOutcome.offline && context.mounted) {
        showMessage(context, 'Connect to the internet to play this track.');
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.l, Space.xxl, Space.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              '${item.track.number}. ${item.track.title}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.title.copyWith(color: c.textPrimary),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            item.album.title,
            textAlign: TextAlign.center,
            style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.s),
          _Scrubber(snapshot: s),
          if (error)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: InlineBanner(
                icon: AppIcons.error,
                tone: BannerTone.warning,
                message: s.errorMessage ?? "Couldn't reach the audio server. Try again.",
                actionLabel: 'Retry',
                onAction: retry,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                iconSize: IconSizes.l,
                icon: Icon(AppIcons.back10, color: c.textPrimary),
                tooltip: 'Back 10 seconds',
                onPressed: player.back10,
              ),
              IconButton(
                iconSize: IconSizes.l,
                icon: Icon(AppIcons.previous, color: c.textPrimary),
                tooltip: 'Previous track',
                onPressed: player.previous,
              ),
              _PlayButton(snapshot: s, onPressed: error ? retry : player.toggle),
              IconButton(
                iconSize: IconSizes.l,
                icon: Icon(AppIcons.next, color: c.textPrimary),
                tooltip: 'Next track',
                onPressed: player.next,
              ),
              IconButton(
                iconSize: IconSizes.l,
                icon: Icon(AppIcons.forward10, color: c.textPrimary),
                tooltip: 'Forward 10 seconds',
                onPressed: player.forward10,
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            child: slow && s.isBuffering
                ? Padding(
                    padding: const EdgeInsets.only(top: Space.s),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        'Buffering — slow connection',
                        style: TypeScale.caption.copyWith(color: c.textSecondary),
                      ),
                    ),
                  )
                : const SizedBox(height: Space.s),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.snapshot, required this.onPressed});

  final PlayerSnapshot snapshot;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final playing = snapshot.playing;
    final dimension = Space.x5 + Space.l;
    return Semantics(
      button: true,
      label: snapshot.isBuffering ? 'Loading' : (playing ? 'Pause' : 'Play'),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: dimension,
        child: Material(
          color: c.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onPressed();
            },
            child: Center(
              child: snapshot.isBuffering && !playing
                  ? SizedBox.square(
                      dimension: IconSizes.l,
                      child: CircularProgressIndicator(strokeWidth: 3, color: c.onPrimary),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          playing ? AppIcons.pause : AppIcons.play,
                          size: IconSizes.l + Space.xs,
                          color: c.onPrimary,
                          fill: 1,
                        ),
                        if (snapshot.isBuffering)
                          SizedBox.square(
                            dimension: dimension - Space.s,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Scrubber extends ConsumerStatefulWidget {
  const _Scrubber({required this.snapshot});

  final PlayerSnapshot snapshot;

  @override
  ConsumerState<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends ConsumerState<_Scrubber> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.snapshot;
    final total = s.duration ?? s.current!.track.duration;
    final max = math.max(1, total.inMilliseconds).toDouble();
    final value = (_dragging ?? s.position.inMilliseconds.toDouble()).clamp(0, max).toDouble();
    final elapsed = Duration(milliseconds: value.round());
    final remaining = total - elapsed;
    final buffered = s.buffered.inMilliseconds.clamp(0, max).toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context)
              .copyWith(secondaryActiveTrackColor: c.primary.withAlpha(70)),
          child: Slider(
            value: value,
            max: max,
            secondaryTrackValue: buffered,
            semanticFormatterCallback: (v) =>
                '${formatClock(Duration(milliseconds: v.round()))} of ${formatClock(total)}',
            onChangeStart: (v) => setState(() => _dragging = v),
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) {
              setState(() => _dragging = null);
              ref.read(playerProvider.notifier).seek(Duration(milliseconds: v.round()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Text(
                  formatClock(elapsed),
                  style: TypeScale.caption.copyWith(
                    color: c.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  '-${formatClock(remaining)}',
                  style: TypeScale.caption.copyWith(
                    color: c.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
