import 'package:markdown/markdown.dart' as md;

/// A document turned into blocks the reader can lay out one by one (FLUTTER_ARCHITECTURE §8).
///
/// Pure Dart, so every shipped document is parsed in a unit test.
class ParsedDocument {
  const ParsedDocument(this.blocks);

  final List<DocBlock> blocks;

  /// The printed page in effect at the start of each block (null before the first marker).
  List<int?> get pageAtBlock {
    final pages = <int?>[];
    int? current;
    for (final b in blocks) {
      pages.add(current);
      current = b.lastPage ?? current;
    }
    return pages;
  }

  /// The plain text of the whole document (search-free; used for tests and word counts).
  String get plainText => blocks.map((b) => b.plainText).join('\n');
}

// --- Blocks ---------------------------------------------------------------------------------

sealed class DocBlock {
  const DocBlock();

  String get plainText;

  /// The last printed page marker inside this block, if any.
  int? get lastPage => null;
}

class HeadingBlock extends DocBlock {
  const HeadingBlock(this.level, this.runs);
  final int level;
  final List<InlineRun> runs;
  @override
  String get plainText => runs.map((r) => r.plainText).join();
  @override
  int? get lastPage => _lastPageIn(runs);
}

class ParagraphBlock extends DocBlock {
  const ParagraphBlock(this.runs);
  final List<InlineRun> runs;
  @override
  String get plainText => runs.map((r) => r.plainText).join();
  @override
  int? get lastPage => _lastPageIn(runs);
}

/// A printed page number on a line of its own: the page starts here.
class PageBreakBlock extends DocBlock {
  const PageBreakBlock(this.page);
  final int page;
  @override
  String get plainText => '';
  @override
  int? get lastPage => page;
}

class ListBlock extends DocBlock {
  const ListBlock({required this.ordered, required this.start, required this.items});
  final bool ordered;
  final int start;

  /// Each item is a list of blocks (usually one paragraph).
  final List<List<DocBlock>> items;
  @override
  String get plainText => items.map((i) => i.map((b) => b.plainText).join('\n')).join('\n');
  @override
  int? get lastPage {
    int? last;
    for (final item in items) {
      for (final b in item) {
        last = b.lastPage ?? last;
      }
    }
    return last;
  }
}

class QuoteBlock extends DocBlock {
  const QuoteBlock(this.children);
  final List<DocBlock> children;
  @override
  String get plainText => children.map((b) => b.plainText).join('\n');
  @override
  int? get lastPage {
    int? last;
    for (final b in children) {
      last = b.lastPage ?? last;
    }
    return last;
  }
}

class TableBlock extends DocBlock {
  const TableBlock({required this.header, required this.rows});
  final List<List<InlineRun>> header;
  final List<List<List<InlineRun>>> rows;
  @override
  String get plainText =>
      [header.map(_plain).join(' | '), for (final r in rows) r.map(_plain).join(' | ')].join('\n');
}

class RuleBlock extends DocBlock {
  const RuleBlock();
  @override
  String get plainText => '';
}

// --- Inline runs ----------------------------------------------------------------------------

sealed class InlineRun {
  const InlineRun();
  String get plainText;
}

class TextRun extends InlineRun {
  const TextRun(this.text, {this.bold = false, this.italic = false, this.href});
  final String text;
  final bool bold;
  final bool italic;
  final String? href;
  @override
  String get plainText => text;
}

class LineBreakRun extends InlineRun {
  const LineBreakRun();
  @override
  String get plainText => '\n';
}

/// A printed page number inside running text (the page turned mid-sentence).
class PageRun extends InlineRun {
  const PageRun(this.page);
  final int page;
  @override
  String get plainText => '';
}

String _plain(List<InlineRun> runs) => runs.map((r) => r.plainText).join();

int? _lastPageIn(List<InlineRun> runs) {
  int? last;
  for (final r in runs) {
    if (r is PageRun) last = r.page;
  }
  return last;
}

// --- Parser ---------------------------------------------------------------------------------

/// Page markers are swapped for private-use characters before parsing, so they survive the
/// Markdown parser wherever they sit (between paragraphs or mid-word).
const _open = '';
const _close = '';
final _pageComment = RegExp(r'<!-- page (\d+) -->');
final _marker = RegExp('$_open(\\d+)$_close');
final _onlyMarker = RegExp('^\\s*$_open(\\d+)$_close\\s*\$');
final _brTag = RegExp(r'<br\s*/?>', caseSensitive: false);

ParsedDocument parseDocument(String source) {
  var body = source;
  if (body.startsWith('---\n')) {
    final end = body.indexOf('\n---\n', 4);
    if (end > 0) body = body.substring(end + 5);
  }
  body = body.replaceAllMapped(_pageComment, (m) => '$_open${m[1]}$_close');
  final document = md.Document(
    extensionSet: md.ExtensionSet.commonMark,
    blockSyntaxes: const [md.TableSyntax()],
    encodeHtml: false,
  );
  final nodes = document.parse(body);
  return ParsedDocument(_blocks(nodes));
}

List<DocBlock> _blocks(List<md.Node> nodes) {
  final out = <DocBlock>[];
  for (final node in nodes) {
    if (node is md.Element) {
      out.addAll(_block(node));
    } else if (node is md.Text) {
      // Raw text at block level (an HTML block): keep any page marker, drop the rest.
      final m = _onlyMarker.firstMatch(node.text);
      if (m != null) out.add(PageBreakBlock(int.parse(m[1]!)));
    }
  }
  return out;
}

List<DocBlock> _block(md.Element e) {
  switch (e.tag) {
    case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
      return [HeadingBlock(int.parse(e.tag.substring(1)), _inline(e.children))];
    case 'p':
      final text = e.textContent;
      final only = _onlyMarker.firstMatch(text);
      if (only != null) return [PageBreakBlock(int.parse(only[1]!))];
      final runs = _inline(e.children);
      if (runs.every((r) => r is PageRun || (r is TextRun && r.text.trim().isEmpty))) {
        return [
          for (final r in runs)
            if (r is PageRun) PageBreakBlock(r.page),
        ];
      }
      return [ParagraphBlock(runs)];
    case 'ol' || 'ul':
      final items = <List<DocBlock>>[];
      for (final child in e.children ?? const <md.Node>[]) {
        if (child is md.Element && child.tag == 'li') {
          final inner = child.children ?? const <md.Node>[];
          final hasBlocks = inner.any(
            (n) => n is md.Element && const {'p', 'ol', 'ul', 'blockquote'}.contains(n.tag),
          );
          items.add(hasBlocks ? _blocks(inner) : [ParagraphBlock(_inline(inner))]);
        }
      }
      return [
        ListBlock(
          ordered: e.tag == 'ol',
          start: int.tryParse(e.attributes['start'] ?? '') ?? 1,
          items: items,
        ),
      ];
    case 'blockquote':
      return [QuoteBlock(_blocks(e.children ?? const []))];
    case 'hr':
      return const [RuleBlock()];
    case 'table':
      final header = <List<InlineRun>>[];
      final rows = <List<List<InlineRun>>>[];
      for (final section in e.children ?? const <md.Node>[]) {
        if (section is! md.Element) continue;
        for (final tr in section.children ?? const <md.Node>[]) {
          if (tr is! md.Element || tr.tag != 'tr') continue;
          final cells = [
            for (final cell in tr.children ?? const <md.Node>[])
              if (cell is md.Element) _inline(cell.children),
          ];
          if (section.tag == 'thead') {
            header.addAll(cells);
          } else {
            rows.add(cells);
          }
        }
      }
      return [TableBlock(header: header, rows: rows)];
    default:
      final children = e.children;
      if (children == null) return const [];
      return [ParagraphBlock(_inline(children))];
  }
}

List<InlineRun> _inline(
  List<md.Node>? nodes, {
  bool bold = false,
  bool italic = false,
  String? href,
}) {
  final out = <InlineRun>[];
  for (final node in nodes ?? const <md.Node>[]) {
    if (node is md.Text) {
      _addText(out, node.text, bold: bold, italic: italic, href: href);
    } else if (node is md.Element) {
      switch (node.tag) {
        case 'strong':
          out.addAll(_inline(node.children, bold: true, italic: italic, href: href));
        case 'em':
          out.addAll(_inline(node.children, bold: bold, italic: true, href: href));
        case 'a':
          out.addAll(
            _inline(node.children, bold: bold, italic: italic, href: node.attributes['href']),
          );
        case 'br':
          out.add(const LineBreakRun());
        case 'code':
          _addText(out, node.textContent, bold: bold, italic: italic, href: href);
        default:
          out.addAll(_inline(node.children, bold: bold, italic: italic, href: href));
      }
    }
  }
  return out;
}

void _addText(
  List<InlineRun> out,
  String text, {
  required bool bold,
  required bool italic,
  String? href,
}) {
  // Inline HTML that survives parsing: line breaks inside table cells.
  final parts = text.split(_brTag);
  for (var p = 0; p < parts.length; p++) {
    if (p > 0) out.add(const LineBreakRun());
    var rest = parts[p];
    while (rest.isNotEmpty) {
      final m = _marker.firstMatch(rest);
      if (m == null) {
        out.add(TextRun(rest, bold: bold, italic: italic, href: href));
        break;
      }
      if (m.start > 0) {
        out.add(TextRun(rest.substring(0, m.start), bold: bold, italic: italic, href: href));
      }
      out.add(PageRun(int.parse(m[1]!)));
      rest = rest.substring(m.end);
    }
  }
}
