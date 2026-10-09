import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../design/theme/app_colors.dart';
import '../../../design/tokens/spacing.dart';
import '../../../design/tokens/typography.dart';
import '../domain/document_parser.dart';

/// Renders one parsed block with the reader's text size (D-003: native text, no web view).
///
/// Used by the reader and the player transcript; both lay blocks out lazily in a list, so long
/// chapters open instantly.
class DocBlockView extends StatelessWidget {
  const DocBlockView({
    required this.block,
    required this.textStep,
    required this.onLink,
    this.isFirst = false,
    super.key,
  });

  final DocBlock block;
  final int textStep;
  final ValueChanged<String> onLink;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = ReaderType.body(textStep).copyWith(color: c.textPrimary);
    final em = ReaderType.sizeFor(textStep);
    return switch (block) {
      HeadingBlock(:final level, :final runs) => Padding(
        padding: EdgeInsets.only(top: isFirst ? 0 : em * 0.9, bottom: em * 0.6),
        child: Semantics(
          header: true,
          child: _RunsText(
            runs: runs,
            style: ReaderType.heading(textStep, top: level == 1).copyWith(color: c.textPrimary),
            onLink: onLink,
          ),
        ),
      ),
      ParagraphBlock(:final runs) => Padding(
        padding: EdgeInsets.only(bottom: em * 0.8),
        child: _RunsText(runs: runs, style: body, onLink: onLink),
      ),
      PageBreakBlock(:final page) => _PageDivider(page: page, textStep: textStep),
      ListBlock() => _ListBlockView(block: block as ListBlock, textStep: textStep, onLink: onLink),
      QuoteBlock(:final children) => Padding(
        padding: EdgeInsets.only(bottom: em * 0.8),
        child: Container(
          padding: EdgeInsets.only(left: em * 0.8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: c.primaryContainer, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final b in children) DocBlockView(block: b, textStep: textStep, onLink: onLink),
            ],
          ),
        ),
      ),
      TableBlock() => _TableView(block: block as TableBlock, textStep: textStep, onLink: onLink),
      RuleBlock() => Padding(
        padding: EdgeInsets.symmetric(vertical: em * 0.6),
        child: Divider(color: c.divider, height: 1, thickness: 1),
      ),
    };
  }
}

/// A run of inline text with emphasis, links, line breaks and mid-sentence page numbers.
class _RunsText extends StatefulWidget {
  const _RunsText({required this.runs, required this.style, required this.onLink});

  final List<InlineRun> runs;
  final TextStyle style;
  final ValueChanged<String> onLink;

  @override
  State<_RunsText> createState() => _RunsTextState();
}

class _RunsTextState extends State<_RunsText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final c = context.colors;
    final spans = <InlineSpan>[];
    for (final run in widget.runs) {
      switch (run) {
        case TextRun(:final text, :final bold, :final italic, :final href):
          TapGestureRecognizer? recognizer;
          if (href != null) {
            recognizer = TapGestureRecognizer()..onTap = () => widget.onLink(href);
            _recognizers.add(recognizer);
          }
          spans.add(
            TextSpan(
              text: text,
              recognizer: recognizer,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : null,
                fontStyle: italic ? FontStyle.italic : null,
                color: href != null ? c.primary : null,
                decoration: href != null ? TextDecoration.underline : null,
                decorationColor: href != null ? c.primary : null,
              ),
            ),
          );
        case LineBreakRun():
          spans.add(const TextSpan(text: '\n'));
        case PageRun(:final page):
          spans.add(
            TextSpan(
              text: ' p.$page ',
              semanticsLabel: 'page $page',
              style: TextStyle(
                color: c.textTertiary,
                fontSize: (widget.style.fontSize ?? 16) * 0.62,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
      }
    }
    return Text.rich(TextSpan(children: spans), style: widget.style);
  }
}

class _PageDivider extends StatelessWidget {
  const _PageDivider({required this.page, required this.textStep});

  final int page;
  final int textStep;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final em = ReaderType.sizeFor(textStep);
    return Semantics(
      label: 'Page $page',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(top: em * 0.2, bottom: em * 0.9),
        child: Row(
          children: [
            Expanded(child: Divider(color: c.divider, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.m),
              child: Text(
                'Page $page',
                style: ReaderType.caption(textStep).copyWith(color: c.textTertiary),
              ),
            ),
            Expanded(child: Divider(color: c.divider, height: 1)),
          ],
        ),
      ),
    );
  }
}

class _ListBlockView extends StatelessWidget {
  const _ListBlockView({required this.block, required this.textStep, required this.onLink});

  final ListBlock block;
  final int textStep;
  final ValueChanged<String> onLink;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = ReaderType.body(textStep).copyWith(color: c.textPrimary);
    final em = ReaderType.sizeFor(textStep);
    return Padding(
      padding: EdgeInsets.only(bottom: em * 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < block.items.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: em * 2,
                  child: Text(
                    block.ordered ? '${block.start + i}.' : '•',
                    style: style.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final b in block.items[i])
                        DocBlockView(block: b, textStep: textStep, onLink: onLink),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.block, required this.textStep, required this.onLink});

  final TableBlock block;
  final int textStep;
  final ValueChanged<String> onLink;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final em = ReaderType.sizeFor(textStep);
    final style = ReaderType.body(textStep)
        .copyWith(color: c.textPrimary, fontSize: em * 0.85, height: 1.35);
    final columns = block.header.isNotEmpty
        ? block.header.length
        : (block.rows.isEmpty ? 1 : block.rows.first.length);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth / columns).clamp(em * 9, em * 18);
        Widget cell(List<InlineRun> runs, {bool header = false}) => Padding(
          padding: EdgeInsets.all(em * 0.45),
          child: _RunsText(
            runs: runs,
            style: header ? style.copyWith(fontWeight: FontWeight.w700) : style,
            onLink: onLink,
          ),
        );
        return Padding(
          padding: EdgeInsets.only(bottom: em),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: FixedColumnWidth(columnWidth),
              border: TableBorder.all(color: c.divider),
              children: [
                if (block.header.isNotEmpty)
                  TableRow(
                    decoration: BoxDecoration(color: c.surfaceAlt),
                    children: [for (final h in block.header) cell(h, header: true)],
                  ),
                for (final row in block.rows)
                  TableRow(
                    children: [
                      for (var i = 0; i < columns; i++) cell(i < row.length ? row[i] : const []),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
