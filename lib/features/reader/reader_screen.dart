import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/prefs/key_value_store.dart';
import '../../design/components/app_icons.dart';
import '../../design/components/states.dart';
import '../../design/components/text_scale.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../ads/banner_slot.dart';
import '../appearance/appearance_controller.dart';
import '../appearance/text_size_sheet.dart';
import '../content/data/document_repository.dart';
import '../content/domain/content_index.dart';
import '../content/domain/document_parser.dart';
import '../content/presentation/document_blocks.dart';
import 'content_opener.dart';
import 'reading_positions.dart';

/// The reader (S-11): native text from the Markdown source (D-003), the Aa sheet, the printed
/// page indicator, the saved reading position, previous/next at the end, and the banner slot.
class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({required this.docId, super.key});

  final String docId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final entry = ref.watch(docEntryProvider(docId));
    final document = ref.watch(documentProvider(docId));

    return Scaffold(
      backgroundColor: c.surfaceReader,
      appBar: AppBar(
        backgroundColor: c.surfaceReader,
        title: Text(entry?.title ?? ''),
        actions: [
          IconButton(
            key: const ValueKey('reader-aa'),
            icon: const Icon(AppIcons.textSize),
            tooltip: 'Text size and theme',
            onPressed: () => showTextSizeSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: entry == null
                ? const _Unavailable()
                : document.when(
                    data: (doc) => _ReaderBody(entry: entry, document: doc),
                    loading: () =>
                        const Padding(padding: EdgeInsets.all(Space.xxl), child: SkeletonLines()),
                    error: (_, _) => const _Unavailable(),
                  ),
          ),
          const BannerSlot(placement: BannerPlacement.reader),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) => StateMessage(
    icon: AppIcons.error,
    message: "This reading couldn't be opened.",
    actionLabel: 'Back',
    onAction: () => Navigator.of(context).maybePop(),
  );
}

class _ReaderBody extends ConsumerStatefulWidget {
  const _ReaderBody({required this.entry, required this.document});

  final DocEntry entry;
  final ParsedDocument document;

  @override
  ConsumerState<_ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends ConsumerState<_ReaderBody> {
  final _scroll = ScrollController();
  final _probes = <int, BuildContext>{};
  final _page = ValueNotifier<int?>(null);
  late final List<int?> _pageAtBlock = widget.document.pageAtBlock;
  late final ReadingPositions _positions;
  late final int _textStepAtOpen = ref.read(appearanceProvider).textStep;
  late final DateTime Function() _clock;
  late int _step = _textStepAtOpen;
  Timer? _saveTimer;
  bool _restored = false;

  bool get _hasPages => widget.entry.firstPage != null;

  @override
  void initState() {
    super.initState();
    // Read now: the position is saved again while the widget is being disposed, when ref can
    // no longer be used.
    _positions = ref.read(readingPositionsProvider.notifier);
    _clock = ref.read(clockProvider);
    _page.value = widget.entry.firstPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restore();
      _maybeShowCoachMark();
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _save();
    _scroll.dispose();
    _page.dispose();
    super.dispose();
  }

  void _restore() {
    if (_restored || !_scroll.hasClients) return;
    _restored = true;
    final saved = ref.read(readingPositionsProvider)[widget.entry.id];
    if (saved == null || saved.finished) return;
    final position = _scroll.position;
    final target = saved.textStep == _textStepAtOpen
        ? saved.offset
        : saved.fraction * position.maxScrollExtent;
    _scroll.jumpTo(target.clamp(0, math.max(position.maxScrollExtent, target)));
    // A long document builds lazily; settle once more after the jump.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && saved.textStep == _textStepAtOpen) {
        _scroll.jumpTo(saved.offset.clamp(0, _scroll.position.maxScrollExtent));
      }
      _updateVisible();
    });
  }

  void _maybeShowCoachMark() {
    final store = ref.read(kvStoreProvider);
    if (store.getBool(PrefKeys.coachMarkSeen) ?? false) return;
    store.setBool(PrefKeys.coachMarkSeen, true);
    // F-043: once, the first time a reader opens.
    showMessage(context, 'Tip: tap Aa at the top to change the text size and theme.');
  }

  void _save() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final max = position.maxScrollExtent;
    final fraction = max <= 0 ? 1.0 : (position.pixels / max).clamp(0.0, 1.0);
    _positions.save(
      widget.entry.id,
      ReadingPosition(
        offset: position.pixels,
        fraction: fraction,
        textStep: _step,
        savedAt: _clock(),
        page: _hasPages ? _page.value : null,
      ),
    );
  }

  /// Finds the first block under the top of the viewport to show its printed page.
  void _updateVisible() {
    if (!_hasPages || !mounted) return;
    final listBox = context.findRenderObject() as RenderBox?;
    if (listBox == null || !listBox.attached) return;
    final top = listBox.localToGlobal(Offset.zero).dy;
    int? best;
    for (final entry in _probes.entries) {
      final box = entry.value.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height > top + Space.l && (best == null || entry.key < best)) {
        best = entry.key;
      }
    }
    if (best == null) return;
    final block = widget.document.blocks[best];
    _page.value =
        (block is PageBreakBlock ? block.page : _pageAtBlock[best]) ?? widget.entry.firstPage;
  }

  void _onLink(String href) => ref.read(linkOpenerProvider).open(href);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final step = _step = ref.watch(appearanceProvider).textStep;
    final blocks = widget.document.blocks;
    final width = MediaQuery.sizeOf(context).width;
    final side = math.max(
      width >= Breakpoints.medium ? Space.gutterWide : Space.gutterCompact,
      (width - Space.readerMaxWidth) / 2,
    );

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollUpdateNotification) _updateVisible();
            if (n is ScrollEndNotification) {
              _saveTimer?.cancel();
              _saveTimer = Timer(const Duration(milliseconds: 400), _save);
            }
            return false;
          },
          child: ReadingTextScale(
            child: SelectionArea(
              child: Scrollbar(
                controller: _scroll,
                child: ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(side, Space.l, side, Space.x5 * 2),
                  itemCount: blocks.length + 1,
                  itemBuilder: (context, i) {
                    if (i == blocks.length) return _EndOfDocument(entry: widget.entry);
                    return _Probe(
                      index: i,
                      registry: _probes,
                      child: DocBlockView(
                        block: blocks[i],
                        textStep: step,
                        onLink: _onLink,
                        isFirst: i == 0,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (_hasPages)
          Positioned(
            right: Space.l,
            bottom: Space.l,
            child: ValueListenableBuilder<int?>(
              valueListenable: _page,
              builder: (context, page, _) => page == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      label: 'Page $page',
                      liveRegion: false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.m,
                          vertical: Space.xs,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface.withAlpha(235),
                          borderRadius: Radii.pillAll,
                          border: Border.all(color: c.divider),
                        ),
                        child: Text(
                          'p. $page',
                          style: TypeScale.label.copyWith(color: c.textSecondary),
                        ),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

/// Registers a block's context while it is built, so the reader can find the block at the top
/// of the screen without measuring the whole document.
class _Probe extends StatefulWidget {
  const _Probe({required this.index, required this.registry, required this.child});

  final int index;
  final Map<int, BuildContext> registry;
  final Widget child;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.registry[widget.index] = context;
  }

  @override
  void didUpdateWidget(_Probe old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      old.registry.remove(old.index);
      widget.registry[widget.index] = context;
    }
  }

  @override
  void dispose() {
    if (widget.registry[widget.index] == context) widget.registry.remove(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Previous / next in the same collection (A-19).
class _EndOfDocument extends ConsumerWidget {
  const _EndOfDocument({required this.entry});

  final DocEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final index = ref.watch(contentIndexProvider);
    final previous = index.previous(entry);
    final next = index.next(entry);
    final opener = ref.read(contentOpenerProvider);
    return Padding(
      padding: const EdgeInsets.only(top: Space.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: c.divider),
          const SizedBox(height: Space.l),
          if (next != null)
            FilledButton.tonal(
              onPressed: () => opener.open(context, next, replace: true),
              child: Text('Next: ${next.title}', overflow: TextOverflow.ellipsis),
            ),
          if (previous != null) ...[
            const SizedBox(height: Space.s),
            TextButton(
              onPressed: () => opener.open(context, previous, replace: true),
              child: Text('Previous: ${previous.title}', overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      ),
    );
  }
}
