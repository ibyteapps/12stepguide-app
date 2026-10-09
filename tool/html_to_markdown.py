#!/usr/bin/env python3
"""Convert the native apps' HTML literature into standard Markdown files.

Owner decision D-003 (9 Oct 2026): every HTML document from the two native apps is
redone as a plain CommonMark/GFM `.md` file. The originals stay, untouched, in
`content-source/html/` so any conversion can be re-checked or re-run.

    python3 tool/html_to_markdown.py            # write content/
    python3 tool/html_to_markdown.py --check    # also verify no words were lost

Conventions in the output (documented in content/README.md):
  * YAML front matter: id, title, collection, order, and where known pages,
    track ids and the source file(s).
  * One `#` heading per document (its title as printed), `##` for sub-headings.
  * Hard line breaks (prayers, poems, transcripts) are a trailing backslash.
  * Printed page numbers become `<!-- page N -->` comments placed where page N
    starts. They are invisible in ordinary Markdown viewers; the app shows them.
  * Tables are GFM tables; a line break inside a cell is `<br>`.
  * Text is converted, never edited: spelling, hyphenation artefacts and wording
    stay exactly as in the source. Known source defects are listed in
    content/README.md for a separate, deliberate clean-up.
"""
from __future__ import annotations

import argparse
import difflib
import html
import re
import shutil
import sqlite3
import sys
from dataclasses import dataclass, field
from pathlib import Path

from bs4 import BeautifulSoup, Comment, NavigableString, Tag

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "content-source" / "html"
OUT = ROOT / "content"
LEGACY_DB = ROOT / "content-source" / "audio" / "main.db"

TERMINAL = tuple('.!?:;"”’\')')
SKIP_TAGS = {"head", "title", "meta", "link", "script", "style", "noscript"}
BLOCK_TAGS = {
    "p", "div", "center", "dir", "pre", "section", "article", "body", "html",
    "td", "th", "tr", "tbody", "thead",
}

# ---------------------------------------------------------------------------
# HTML -> event stream
# ---------------------------------------------------------------------------


@dataclass
class Run:
    text: str
    bold: bool = False
    italic: bool = False
    link: str | None = None


BR = object()  # line-break marker inside a paragraph


@dataclass
class Block:
    kind: str  # para | heading | hr | page | table | list
    runs: list = field(default_factory=list)  # Run and BR
    level: int = 0
    page: int | None = None
    page_role: str = ""  # "label" (a printed page number) | "start" | "end"
    md: str = ""  # pre-rendered markdown (table/list)
    quote: bool = False


LIGATURES = {"\ufb00": "ff", "\ufb01": "fi", "\ufb02": "fl", "\ufb03": "ffi", "\ufb04": "ffl"}


def norm_space(s: str) -> str:
    s = s.replace("\xa0", " ").replace("\u200b", "")
    for k, v in LIGATURES.items():
        s = s.replace(k, v)
    return re.sub(r"[ \t\r\n\f\v]+", " ", s)


class Walker:
    def __init__(self) -> None:
        self.blocks: list[Block] = []
        self.cur: Block | None = None
        self.quote = 0

    # paragraph management -------------------------------------------------
    def _para(self) -> Block:
        if self.cur is None:
            self.cur = Block("para", quote=self.quote > 0)
        return self.cur

    def flush(self) -> None:
        if self.cur is not None:
            if any(isinstance(r, Run) and r.text.strip() for r in self.cur.runs):
                self.blocks.append(self.cur)
            self.cur = None

    def add_text(self, text, bold, italic, link):
        if not text:
            return
        self._para().runs.append(Run(text, bold, italic, link))

    def add_br(self):
        self._para().runs.append(BR)

    # walking -----------------------------------------------------------------
    def walk(self, node, bold=False, italic=False, link=None):
        for child in list(node.children):
            if isinstance(child, Comment):
                continue
            if isinstance(child, NavigableString):
                self.add_text(norm_space(str(child)), bold, italic, link)
                continue
            if not isinstance(child, Tag):
                continue
            name = child.name.lower()
            if name in SKIP_TAGS:
                continue
            classes = set(child.get("class") or [])
            if classes & {"text-bold", "bold"}:
                bold_here = True
            else:
                bold_here = False
            if name == "br":
                self.add_br()
            elif name in ("strong", "b"):
                self.walk(child, True, italic, link)
            elif name in ("em", "i"):
                self.walk(child, bold, True, link)
            elif name == "a":
                href = child.get("href")
                if href and not href.startswith("#"):
                    self.walk(child, bold, italic, href.strip())
                else:
                    self.walk(child, bold, italic, link)
            elif name == "button":
                txt = child.get_text(strip=True)
                self.flush()
                if txt.isdigit():
                    self.blocks.append(Block("page", page=int(txt), page_role="end"))
                else:
                    self.add_text(txt, bold, italic, link)
            elif name == "hr":
                self.flush()
                self.blocks.append(Block("hr"))
            elif re.fullmatch(r"h[1-6]", name):
                self.flush()
                self.cur = Block("heading", level=int(name[1]), quote=self.quote > 0)
                self.walk(child, True, italic, link)
                self.flush()
            elif name == "table":
                self.flush()
                widths = [len(tr.find_all(["td", "th"])) for tr in child.find_all("tr")]
                if widths and max(widths) <= 1:
                    # a one-column layout table: its content is ordinary text
                    self.walk(child, bold, italic, link)
                    self.flush()
                else:
                    self.blocks.append(Block("table", md=table_md(child)))
            elif name in ("ul", "ol"):
                self.flush()
                self.blocks.append(Block("list", md=list_md(child, ordered=name == "ol")))
            elif name == "blockquote":
                self.flush()
                self.quote += 1
                self.walk(child, bold, italic, link)
                self.flush()
                self.quote -= 1
            elif name in BLOCK_TAGS:
                self.flush()
                if name == "p" and re.fullmatch(r"\s*\d{1,3}\s*", child.get_text()):
                    self.blocks.append(
                        Block("page", page=int(child.get_text().strip()), page_role="label")
                    )
                    continue
                self.walk(child, bold or bold_here, italic, link)
                self.flush()
            else:  # span, font, u, sup, label, etc. -> inline passthrough
                self.walk(child, bold, italic, link)


# ---------------------------------------------------------------------------
# Inline markdown
# ---------------------------------------------------------------------------


def escape_inline(s: str) -> str:
    s = s.replace("\\", "\\\\")
    for ch in "*_`[]<":
        s = s.replace(ch, "\\" + ch)
    return s


def escape_line_start(line: str) -> str:
    if re.match(r"^(#{1,6}\s|>|[-+*]\s|=+\s*$|-{3,}\s*$)", line):
        return "\\" + line
    m = re.match(r"^(\d{1,9})([.)])(\s)", line)
    if m:
        return m.group(1) + "\\" + m.group(2) + line[len(m.group(1)) + 1:]
    return line


def runs_to_md(runs: list[Run], cell: bool = False) -> str:
    # merge neighbours with the same style
    merged: list[Run] = []
    for r in runs:
        if merged and (merged[-1].bold, merged[-1].italic, merged[-1].link) == (
            r.bold, r.italic, r.link
        ):
            merged[-1] = Run(merged[-1].text + r.text, r.bold, r.italic, r.link)
        else:
            merged.append(Run(r.text, r.bold, r.italic, r.link))
    out = []
    for r in merged:
        text = r.text
        if not text.strip():
            out.append(" " if text else "")
            continue
        lead = " " if text[0] == " " else ""
        trail = " " if text[-1] == " " else ""
        mark = "***" if (r.bold and r.italic) else "**" if r.bold else "*" if r.italic else ""
        raw = text.strip()
        if mark:
            # punctuation at the edges goes outside the markers, so CommonMark can always
            # open and close the emphasis ("He said**,**" would not render)
            m = re.match(r"^(\W*)(.*?)(\W*)$", raw, re.S)
            pre, mid, post = m.groups()
            if mid:
                core = f"{escape_inline(pre)}{mark}{escape_inline(mid)}{mark}{escape_inline(post)}"
            else:
                core = escape_inline(raw)
        else:
            core = escape_inline(raw)
        if cell:
            core = core.replace("|", "\\|")
        if r.link:
            core = f"[{core}]({r.link})"
        out.append(f"{lead}{core}{trail}")
    s = "".join(out)
    s = re.sub(r" {2,}", " ", s)
    return s.strip()


def plain(runs) -> str:
    return norm_space("".join(r.text for r in runs if isinstance(r, Run))).strip()


def table_md(table: Tag) -> str:
    rows = []
    for tr in table.find_all("tr"):
        cells = []
        for td in tr.find_all(["td", "th"]):
            w = Walker()
            w.walk(td)
            w.flush()
            parts = []
            for b in w.blocks:
                segs = split_segments(b.runs) if b.kind in ("para", "heading") else []
                parts.append("<br>".join(runs_to_md(s, cell=True) for s, _ in segs if plain(s)))
            cells.append("<br>".join(p for p in parts if p))
        if any(c.strip() for c in cells):
            rows.append(cells)
    if not rows:
        return ""
    width = max(len(r) for r in rows)
    rows = [r + [""] * (width - len(r)) for r in rows]
    lines = ["| " + " | ".join(rows[0]) + " |", "|" + "---|" * width]
    lines += ["| " + " | ".join(r) + " |" for r in rows[1:]]
    return "\n".join(lines)


def list_md(lst: Tag, ordered: bool) -> str:
    items = []
    n = 1
    for li in lst.find_all("li", recursive=False):
        w = Walker()
        w.walk(li)
        w.flush()
        text = " ".join(
            runs_to_md([r if isinstance(r, Run) else Run(" ") for r in b.runs]) for b in w.blocks
            if b.kind in ("para", "heading")
        )
        prefix = f"{n}. " if ordered else "- "
        items.append(prefix + text)
        n += 1
    return "\n".join(items)


# ---------------------------------------------------------------------------
# Paragraph segmentation (how a <br> becomes markdown)
# ---------------------------------------------------------------------------


def split_segments(runs):
    """Split runs on <br> groups. Returns [(segment_runs, number_of_brs_after_it)]."""
    segs, cur, pending = [], [], 0
    for r in runs:
        if r is BR:
            pending += 1
            continue
        if not r.text.strip() and (pending or not cur):
            continue  # whitespace around <br>s or at the start
        if pending:
            if cur:
                segs.append((cur, pending))
                cur = []
            pending = 0
        cur.append(r)
    if cur:
        segs.append((cur, 0))
    return [(s, c) for s, c in segs if plain(s)]


def joiner(prev: str, nxt: str, brs: int, family: str) -> str:
    """'para' | 'hard' | 'space' for the break between two segments."""
    if family == "verse":
        # prayers: one <br> is a line; a double <br> is a line when the next line carries on
        # (lower-case start) and a stanza break otherwise
        return "hard" if brs == 1 or nxt[:1].islower() else "para"
    if nxt[:1].islower() and not prev.rstrip().endswith(TERMINAL):
        return "space"  # a line wrapped in the source, even with a blank line
    if brs >= 2:
        return "para"
    if nxt[:1].islower():
        return "space"
    if prev.rstrip().endswith(TERMINAL):
        return "para"
    return "hard"


def is_all_bold(runs) -> bool:
    texty = [r for r in runs if isinstance(r, Run) and r.text.strip()]
    return bool(texty) and all(r.bold for r in texty)


# ---------------------------------------------------------------------------
# Document assembly
# ---------------------------------------------------------------------------


@dataclass
class Doc:
    source: Path
    out: Path
    meta: dict
    family: str = "prose"  # prose | verse
    paged: bool = False  # big book chapters and stories carry printed page numbers


def convert(doc: Doc) -> str:
    soup = BeautifulSoup(doc.source.read_text(encoding="utf-8", errors="replace"), "lxml")
    body = soup.body or soup
    w = Walker()
    w.walk(body)
    w.flush()
    blocks = w.blocks

    # 1. printed page labels are resolved after paragraphs are built (step 3)
    if not doc.paged:
        blocks = [b for b in blocks if b.kind != "page"]

    # 2. paragraphs -> segments -> markdown blocks -----------------------------
    md_blocks: list[tuple[str, str]] = []  # (kind, text)
    first_heading_done = False

    def add_heading(text_md: str, quote: bool):
        nonlocal first_heading_done
        level = "#" if not first_heading_done else "##"
        first_heading_done = True
        md_blocks.append(("heading", f"{level} {text_md.replace('**', '').strip()}"))

    for b in blocks:
        if b.kind == "page":
            md_blocks.append(("label-end" if b.page_role == "end" else "label", str(b.page)))
            continue
        if b.kind == "hr":
            md_blocks.append(("hr", "---"))
            continue
        if b.kind in ("table", "list"):
            if b.md:
                md_blocks.append((b.kind, b.md))
            continue
        segs = split_segments(b.runs)
        if b.kind == "heading":
            text = " ".join(runs_to_md(s) for s, _ in segs)
            if text.strip():
                add_heading(text, b.quote)
            continue
        # paragraph: decide each break
        paras: list[list[str]] = [[]]  # list of paragraphs, each a list of lines
        line_parts: list[str] = []
        prev_plain = ""
        for i, (seg, brs) in enumerate(segs):
            seg_md = runs_to_md(seg)
            seg_plain = plain(seg)
            if (
                is_all_bold(seg)
                and len(seg_plain) <= 120
                and not seg_plain.endswith(",")
                and not doc.meta.get("collection", "").startswith("transcripts")
                and (doc.family == "prose" or not first_heading_done)
                and not re.fullmatch(r"[\d\s]+", seg_plain)
                and re.search(r"[A-Za-z]", seg_plain)
            ):
                # a bold line on its own is a (sub)heading
                if line_parts:
                    paras[-1].append(" ".join(line_parts))
                    line_parts = []
                if paras[-1]:
                    paras.append([])
                md_blocks.extend(("para", fmt_para(p, b.quote)) for p in paras if p)
                paras = [[]]
                add_heading(seg_md, b.quote)
                prev_plain = ""
                continue
            if not line_parts and not paras[-1]:
                line_parts = [seg_md]
            else:
                j = joiner(prev_plain, seg_plain, segs[i - 1][1] if i else 0, doc.family)
                if j == "space":
                    line_parts.append(seg_md)
                elif j == "hard":
                    paras[-1].append(" ".join(line_parts))
                    line_parts = [seg_md]
                else:
                    paras[-1].append(" ".join(line_parts))
                    paras.append([])
                    line_parts = [seg_md]
            prev_plain = seg_plain
        if line_parts:
            paras[-1].append(" ".join(line_parts))
        md_blocks.extend(("para", fmt_para(p, b.quote)) for p in paras if p)

    # 3. printed page numbers -> page-start markers; re-join split paragraphs --
    if doc.paged:
        md_blocks = resolve_pages(md_blocks, doc)
    md_blocks = join_across_pages(md_blocks, doc.paged or doc.family == "prose")
    while md_blocks and md_blocks[-1][0] in ("hr", "page"):
        md_blocks.pop()

    md_blocks = numbered_lists([m for m in md_blocks if m[1].strip()])
    body_md = "\n\n".join(t for _, t in md_blocks).strip() + "\n"
    return front_matter(doc.meta) + "\n" + body_md


MERGE_EMPHASIS = re.compile(r"(?<=[^\s*\\])(\*{1,3}) \1(?=[^\s*])")


def fmt_para(lines: list[str], quote: bool) -> str:
    # "*the birth* *of our Society*" (two italic source lines joined) -> "*the birth of our Society*"
    lines = [MERGE_EMPHASIS.sub(" ", l) for l in lines]
    lines = [escape_line_start(l.strip()) for l in lines if l.strip()]
    text = " \\\n".join(lines)
    text = text.replace(" \\\n", "\\\n")
    if quote:
        text = "\n".join("> " + l for l in text.split("\n"))
    return text


PAGE_WARNINGS: list[str] = []


def resolve_pages(md_blocks, doc):
    """Printed page numbers (end-of-page labels, start-of-page labels, page-number buttons)
    become `<!-- page N -->` markers at the point where page N starts. Rules that only
    separated pages are dropped."""
    items = []
    for kind, text in md_blocks:
        if kind == "para" and re.fullmatch(r"\d{1,3}", text.strip()):
            kind = "label"
        items.append([kind, text])
    out = []
    first_page = None
    current = None  # page number currently being read
    after_rule = False
    for i, (kind, text) in enumerate(items):
        if kind in ("label", "label-end"):
            n = int(text)
            prev = next((k for k, _ in reversed(items[:i]) if k not in ("label", "label-end")), None)
            nxt = next((k for k, _ in items[i + 1:] if k not in ("label", "label-end")), None)
            if kind == "label-end" or (nxt == "hr" and prev != "hr"):
                start = n + 1
                first_page = n if first_page is None else first_page
            else:
                if prev != "hr" and nxt != "hr":
                    PAGE_WARNINGS.append(f"{doc.out.name}: page {n} has no rule next to it")
                start = n
                first_page = n - 1 if first_page is None else first_page
            if out and out[-1][0] == "page":
                out[-1] = ("page", start)
            else:
                out.append(("page", start))
            current = start
            continue
        if kind == "hr":
            after_rule = True
            continue
        if kind == "para":
            # a start-of-page number run into the text: "53 ficiency…"
            m = re.match(r"^(\d{1,3})\s+(?=\S)", text)
            if m and (
                (out and out[-1][0] == "page" and int(m.group(1)) == out[-1][1])
                or (after_rule and current is not None and int(m.group(1)) == current + 1)
            ):
                n = int(m.group(1))
                text = text[m.end():]
                if not (out and out[-1][0] == "page"):
                    out.append(("page", n))
                current = n
        after_rule = False
        out.append((kind, text))
    if first_page is not None:
        k = 0
        while k < len(out) and out[k][0] == "heading":
            k += 1
        if not (k < len(out) and out[k][0] == "page"):
            out.insert(k, ("page", first_page))
    # drop duplicate consecutive pages, render markers
    rendered = []
    for kind, val in out:
        if kind == "page":
            if rendered and rendered[-1][0] == "page":
                rendered[-1] = ("page", f"<!-- page {val} -->")
            else:
                rendered.append(("page", f"<!-- page {val} -->"))
        else:
            rendered.append((kind, val))
    return rendered


def _plain_md(t: str) -> str:
    t = re.sub(r"<!--.*?-->", "", t)
    return re.sub(r"[*\\>]", "", t).strip()


def join_across_pages(md_blocks, paged: bool):
    """Re-join a paragraph that the source split mid-sentence, usually at a page break.

    `para [page] para` is joined when the first part does not end a sentence or the second
    starts with a lower-case letter. Without a page marker the join only happens in paged
    documents and only for a lower-case continuation."""
    out = []
    i = 0
    while i < len(md_blocks):
        kind, text = md_blocks[i]
        if kind == "para" and out:
            # find previous para, possibly with one page marker in between
            if out[-1][0] == "page" and len(out) >= 2 and out[-2][0] == "para":
                marker = out[-1][1]
                prev = out[-2][1]
                pp, nn = _plain_md(prev), _plain_md(text)
                if (not pp.endswith(TERMINAL) or nn[:1].islower()) and not prev.startswith(">") \
                        and not text.startswith(">"):
                    sep_l = "" if re.search(r"[A-Za-z]-$", pp) and nn[:1].islower() else " "
                    out = out[:-2] + [("para", f"{prev}{sep_l}{marker}{sep_l}{text}")]
                    i += 1
                    continue
            elif paged and out[-1][0] == "para":
                pp, nn = _plain_md(out[-1][1]), _plain_md(text)
                if (nn[:1].islower() or nn[:1].isdigit()) and not pp.endswith(TERMINAL) \
                        and not out[-1][1].startswith(">") and not text.startswith(">"):
                    out[-1] = ("para", f"{out[-1][1]} {text}")
                    i += 1
                    continue
        out.append((kind, text))
        i += 1
    return out


def numbered_lists(md_blocks):
    """Runs of three or more paragraphs numbered 1., 2., 3. … become one ordered list."""
    out, i = [], 0
    pat = re.compile(r"^(\d{1,2})\\\. (.*)$", re.S)
    while i < len(md_blocks):
        kind, text = md_blocks[i]
        m = pat.match(text) if kind == "para" else None
        if m:
            j, items, expect = i, [], int(m.group(1))
            while j < len(md_blocks) and md_blocks[j][0] == "para":
                mm = pat.match(md_blocks[j][1])
                if not mm or int(mm.group(1)) != expect or "\n" in mm.group(2):
                    break
                items.append(f"{expect}. {mm.group(2)}")
                expect += 1
                j += 1
            if len(items) >= 3:
                out.append(("list", "\n".join(items)))
                i = j
                continue
        out.append((kind, text))
        i += 1
    return out


def front_matter(meta: dict) -> str:
    lines = ["---"]
    for k, v in meta.items():
        if v is None:
            continue
        if isinstance(v, list):
            lines.append(f"{k}:")
            lines.extend(f"  - {yaml_str(x)}" for x in v)
        elif isinstance(v, int):
            lines.append(f"{k}: {v}")
        else:
            lines.append(f"{k}: {yaml_str(v)}")
    lines.append("---")
    return "\n".join(lines) + "\n"


def yaml_str(v) -> str:
    s = str(v)
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# ---------------------------------------------------------------------------
# The manifest: every HTML file, where it goes, and its metadata
# ---------------------------------------------------------------------------


def slug(s: str) -> str:
    s = s.lower().replace("&", "and").replace("’", "").replace("'", "")
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s[:60].strip("-")


BIG_BOOK = [
    ("Preface & Doctor's Opinion", "Various"), ("Chapter 1: Bill's Story", "1–16"),
    ("Chapter 2: There Is a Solution", "17–29"), ("Chapter 3: More About Alcoholism", "30–43"),
    ("Chapter 4: We Agnostics", "44–57"), ("Chapter 5: How It Works", "58–71"),
    ("Chapter 6: Into Action", "72–88"), ("Chapter 7: Working With Others", "89–103"),
    ("Chapter 8: To Wives", "104–121"), ("Chapter 9: The Family Afterward", "122–135"),
    ("Chapter 10: To Employers", "136–150"), ("Chapter 11: A Vision for You", "151–164"),
    ("Doctor Bob's Nightmare", "171–181"), ("Alcoholics Anonymous Number Three", "182–192"),
]
STORIES_1 = [
    ("The Doctor's Nightmare", "183–193"), ("The Unbeliever", "194–205"), ("The European Drinker", "206–216"),
    ("A Feminine Victory", "217–225"), ("Our Southern Friend", "226–241"), ("A Business Man's Recovery", "242–251"),
    ("A Different Slant", "252–253"), ("Traveler, Editor, Scholar", "254–264"), ("The Back-Slider", "265–273"),
    ("Home Brewmeister", "274–281"), ("The Seventh Month Slip", "282–286"), ("My Wife and I", "287–295"),
    ("A Ward of the Probate Court", "296–302"), ("Riding the Rods", "303–316"), ("The Salesman", "317–324"),
    ("Fired Again", "325–331"), ("The Fearful One", "332–335"), ("Truth Freed Me!", "336–339"),
    ("Smile With Me, at Me", "340–347"), ("A Close Shave", "348–350"), ("Educated Agnostic", "351–356"),
    ("Another Prodigal Story", "357–363"), ("The Car Smasher", "364–369"), ("Hindsight", "370–374"),
    ("On His Way", "375–377"), ("An Alcoholic's Wife", "378–379"), ("An Artist's Concept", "380–385"),
    ("The Rolling Stone", "386–390"), ("Now We Are Thousands", "391–394"),
]
STORIES_2 = [
    ("Pioneers of A.A.", None), ("The Doctor's Nightmare", "171–182"), ("Alcoholics Anonymous Number Three", "182–192"),
    ("He Had to Be Shown", "193–209"), ("He Thought He Could Drink Like a Gentleman", "210–221"),
    ("Women Suffer Too", "222–229"), ("The European Drinker", "230–237"), ("The Vicious Cycle", "238–250"),
    ("The News Hawk", "251–260"), ("From Farm to City", "261–274"), ("The Man Who Mastered Fear", "275–286"),
    ("He Sold Himself Short", "287–296"), ("Home Brewmeister", "297–303"), ("The Keys of the Kingdom", "304–312"),
    ("They Stopped in Time", None), ("Rum, Radio and Rebellion", "317–329"), ("Fear of Fear", "330–335"),
    ("The Professor and the Paradox", "336–342"), ("A Flower of the South", "343–354"),
    ("Unto the Second Generation", "355–364"), ("His Conscience", "365–374"),
    ("The Housewife Who Drank at Home", "375–381"), ("It Might Have Been Worse", "382–392"),
    ("Physician, Heal Thyself!", "393–400"), ("Stars Don't Fall", "401–418"), ("Me, an Alcoholic?", "419–425"),
    ("New Vision for a Sculptor", "426–439"), ("They Lost Nearly All", None), ("Joe's Woes", "445–459"),
    ("Our Southern Friend", "460–470"), ("Jim's Story", "471–484"), ("Promoted to Chronic", "485–494"),
    ("The Prisoner Freed", "495–498"), ("There's Nothing the Matter With Me!", "499–508"),
    ("Desperation Drinking", "509–513"), ("Annie the Cop Fighter", "514–522"), ("The Career Officer", "523–531"),
    ("The Independent Blonde", "532–539"), ("He Who Loses His Life", "540–552"), ("Freedom From Bondage", "553–562"),
]
STEPS = [
    "We admitted we were powerless over alcohol—that our lives had become unmanageable.",
    "Came to believe that a Power greater than ourselves could restore us to sanity.",
    "Made a decision to turn our will and our lives over to the care of God as we understood Him.",
    "Made a searching and fearless moral inventory of ourselves.",
    "Admitted to God, to ourselves, and to another human being the exact nature of our wrongs.",
    "Were entirely ready to have God remove all these defects of character.",
    "Humbly asked Him to remove our shortcomings.",
    "Made a list of all persons we had harmed, and became willing to make amends to them all.",
    "Made direct amends to such people wherever possible, except when to do so would injure them or others.",
    "Continued to take personal inventory and when we were wrong promptly admitted it.",
    "Sought through prayer and meditation to improve our conscious contact with God, as we understood Him, praying only for knowledge of His will for us and the power to carry that out.",
    "Having had a spiritual awakening as the result of these Steps, we tried to carry this message to alcoholics, and to practice these principles in all our affairs.",
]
TRADITIONS = [
    "Our common welfare should come first; personal recovery depends upon A.A. unity.",
    "For our group purpose there is but one ultimate authority—a loving God as He may express Himself in our group conscience. Our leaders are but trusted servants; they do not govern.",
    "The only requirement for A.A. membership is a desire to stop drinking.",
    "Each group should be autonomous except in matters affecting other groups or A.A. as a whole.",
    "Each group has but one primary purpose—to carry its message to the alcoholic who still suffers.",
    "An A.A. group ought never endorse, finance or lend the A.A. name to any related facility or outside enterprise, lest problems of money, property and prestige divert us from our primary purpose.",
    "Every A.A. group ought to be fully self-supporting, declining outside contributions.",
    "Alcoholics Anonymous should remain forever nonprofessional, but our service centers may employ special workers.",
    "A.A., as such, ought never be organized; but we may create service boards or committees directly responsible to those they serve.",
    "Alcoholics Anonymous has no opinion on outside issues; hence the A.A. name ought never be drawn into public controversy.",
    "Our public relations policy is based on attraction rather than promotion; we need always maintain personal anonymity at the level of press, radio and films.",
    "Anonymity is the spiritual foundation of all our traditions, ever reminding us to place principles before personalities.",
]
PRAYERS = [
    ("serenity", "Serenity Prayer"), ("serenity_ex", "Serenity Prayer (Extended)"),
    ("3rdstep", "Third Step Prayer"), ("7thstep", "Seventh Step Prayer"),
    ("11thstep", "Eleventh Step Prayer"), ("lordsprayer", "The Lord's Prayer"),
]
READINGS = [
    ("howitworks", "How It Works", None), ("traditions", "The Twelve Traditions", None),
    ("promises", "The Promises", None), ("preamble", "The Preamble", None),
    ("justfortoday", "Just for Today", None), ("onawakening", "On Awakening", None),
    ("onretiring", "When We Retire", ["On Retiring"]), ("avisionforyou", "A Vision for You", None),
]
TIPS = [
    ("xhowtousethebigbook", "How to Use the Big Book"), ("xhowtofindasponsor", "How to Find a Sponsor"),
    ("xmeditation", "Sobriety & Recovery"), ("x12yearson", "12 Years On: My Experience"),
]
UNUSED_ANDROID = ["about", "sample", "singleness", "yellowcard", "whatsnew"]
UNUSED_IOS_ONLY = ["bigbookmod", "bigbookmod4th", "step12", "terms", "privacy"]


def build_manifest() -> list[Doc]:
    A, I = SRC / "android", SRC / "ios"
    docs: list[Doc] = []

    def add(src, collection, order, title, family="prose", paged=False, extra=None, sub=None):
        name = f"{order:02d}-{slug(title)}.md"
        folder = OUT / (sub or collection)
        meta = {"id": f"{collection}/{order:02d}-{slug(title)}", "title": title,
                "collection": collection, "order": order}
        if extra:
            meta.update(extra)
        meta["source"] = str(src.relative_to(SRC))
        docs.append(Doc(src, folder / name, meta, family, paged))

    # Steps (Android 2024 text, decision D-002) and the hidden Conclusion
    add(A / "guide/tape1.html", "steps", 0, "Introduction")
    for n in range(1, 13):
        add(A / f"guide/tape{n + 1}.html", "steps", n, f"Step {n}", extra={"subtitle": STEPS[n - 1]})
    add(A / "guide/tape14.html", "steps", 13, "Conclusion")
    for n in range(1, 13):
        add(A / f"guide/tradition{n}.html", "traditions", n, f"Tradition {n}",
            extra={"subtitle": TRADITIONS[n - 1]})
    for i, (title, pages) in enumerate(BIG_BOOK, 1):
        add(A / f"aa/tape{i}.html", "big-book", i, title, paged=True,
            extra={"pages": None if pages == "Various" else pages})
    for i, (title, pages) in enumerate(STORIES_1, 1):
        add(A / f"aa/stories1/stories1_{i}.html", "stories-1st-edition", i, title, paged=True,
            extra={"pages": pages})
    for i, (title, pages) in enumerate(STORIES_2, 1):
        add(A / f"aa/stories2/stories2_{i}.html", "stories-2nd-edition", i, title, paged=True,
            extra={"pages": pages})
    for i, (f, title) in enumerate(PRAYERS, 1):
        add(A / f"aa/{f}.html", "prayers", i, title, family="verse")
    for i, (f, title, aliases) in enumerate(READINGS, 1):
        add(A / f"aa/{f}.html", "readings", i, title, paged=f in ("howitworks", "avisionforyou"),
            extra={"aliases": aliases})
    for i, (f, title) in enumerate(TIPS, 1):
        add(A / f"aa/{f}.html", "sobriety-tips", i, title)

    # Audio transcripts (iOS), titled from the audio catalogue
    tracks = {}
    if LEGACY_DB.exists():
        con = sqlite3.connect(LEGACY_DB)
        for tid, album, title, fname in con.execute(
            "select id, album_id, title, file_name from tracks where album_id in (1, 2) order by id"
        ):
            tracks[fname.replace(".mp3", "")] = (tid, album, title)
    for n in range(1, 35):
        key = f"joeandcharlie{n:02d}"
        tid, _, title = tracks.get(key, (None, 1, f"Part {n}"))
        add(I / f"JoeAndCharlie/{key}.html", "transcripts-joe-and-charlie", n, title,
            extra={"album_id": 1, "track_id": tid, "audio_file": f"{key}.mp3"},
            sub="transcripts/joe-and-charlie")
    for n in range(1, 15):
        key = f"aabigbook{n:02d}"
        tid, _, title = tracks.get(key, (None, 2, f"Part {n}"))
        add(I / f"aabigbook-transcripts/{key}.html", "transcripts-big-book", n, title,
            extra={"album_id": 2, "track_id": tid, "audio_file": f"{key}.mp3"},
            sub="transcripts/big-book")

    # Archive: not shown in the app, kept so nothing is lost
    for n in range(1, 15):
        add(I / f"guide/gtape{n}.html", "archive-ios-step-guides", n - 1,
            "Introduction" if n == 1 else ("Conclusion" if n == 14 else f"Step {n - 1}"),
            sub="archive/ios-original-step-guides")
    for f in UNUSED_ANDROID:
        add(A / f"aa/{f}.html", "archive-unused", 0, f, sub="archive/unused-android")
    for f in UNUSED_ANDROID + UNUSED_IOS_ONLY:
        add(I / f"aa/{f}.html", "archive-unused", 0, f, sub="archive/unused-ios")
    for p in sorted((I / "aabigbook-transcripts-unused").glob("*.html")):
        add(p, "archive-unused", 0, p.stem, sub="archive/unused-ios-transcripts")
    return docs


def ios_variants() -> list[Doc]:
    """iOS copies of documents the app shows from the Android text (kept only if the words differ)."""
    A, I = SRC / "android", SRC / "ios"
    out = []
    pairs = [(f"aa/tape{i}.html", True) for i in range(1, 15)]
    pairs += [(f"aa/stories1/stories1_{i}.html", True) for i in range(1, 30)]
    pairs += [(f"aa/stories2/stories2_{i}.html", True) for i in range(1, 41)]
    pairs += [(f"aa/{f}.html", False) for f, _ in PRAYERS]
    pairs += [(f"aa/{f}.html", False) for f, _, _ in READINGS]
    for rel, paged in pairs:
        a, i = A / rel, I / rel
        if words_of_html(a) != words_of_html(i):
            name = rel.replace("aa/", "").replace("/", "-").replace(".html", ".md")
            out.append(Doc(i, OUT / "archive/ios-text-variants" / name,
                           {"id": f"archive-ios-variants/{name[:-3]}", "title": rel,
                            "collection": "archive-ios-text-variants", "order": 0,
                            "source": str(i.relative_to(SRC))},
                           "verse" if rel.split('/')[-1][:-5] in dict(PRAYERS) else "prose", paged))
    return out


# ---------------------------------------------------------------------------
# Verification: the same words, in the same order
# ---------------------------------------------------------------------------

WORD = re.compile(r"[A-Za-z0-9’'À-ɏ]+")


def words_of_html(path: Path) -> list[str]:
    soup = BeautifulSoup(path.read_text(encoding="utf-8", errors="replace"), "lxml")
    for t in soup(list(SKIP_TAGS)):
        t.decompose()
    for t in soup.find_all(list(BLOCK_TAGS | {"br", "hr", "li", "h1", "h2", "h3", "h4", "h5", "h6",
                                              "button", "blockquote", "table", "ul", "ol"})):
        t.insert_before(" ")
        t.insert_after(" ")
    body = soup.body or soup
    return [w.lower() for w in WORD.findall(norm_space(body.get_text("")).replace("'", "’"))]


def words_of_md(text: str) -> list[str]:
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
    text = re.sub(r"<!--.*?-->", " ", text)
    text = re.sub(r"\]\([^)]*\)", "] ", text)
    text = text.replace("<br>", " ")
    text = re.sub(r"^#+ ", "", text, flags=re.M)
    text = re.sub(r"^\d+\. ", "", text, flags=re.M)
    text = text.replace("*", "")
    text = re.sub(r"\\(.)", r"\1", text)
    text = re.sub(r"^\|[-|]+\|$", "", text, flags=re.M)
    return [w.lower() for w in WORD.findall(text.replace("'", "’"))]


def check(doc: Doc, md: str) -> list[str]:
    src = words_of_html(doc.source)
    dst = words_of_md(md)
    problems = []
    sm = difflib.SequenceMatcher(a=src, b=dst, autojunk=False)
    for op, a1, a2, b1, b2 in sm.get_opcodes():
        if op == "equal":
            continue
        removed, added = src[a1:a2], dst[b1:b2]
        # page numbers are moved into comments on purpose
        if all(w.isdigit() for w in removed) and not added:
            continue
        problems.append(f"{op}: -{removed[:12]} +{added[:12]}")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    if OUT.exists():
        for p in OUT.rglob("*.md"):
            if p.name != "README.md":
                p.unlink()
    docs = build_manifest() + ios_variants()
    failures = 0
    for doc in docs:
        md = convert(doc)
        doc.out.parent.mkdir(parents=True, exist_ok=True)
        doc.out.write_text(md, encoding="utf-8")
        if args.check:
            probs = check(doc, md)
            if probs:
                failures += 1
                print(f"✗ {doc.out.relative_to(ROOT)}")
                for p in probs[:6]:
                    print("    ", p)
    for w in PAGE_WARNINGS:
        print("  page note:", w)
    print(f"{len(docs)} documents written to {OUT.relative_to(ROOT)}"
          + (f"; {failures} with word differences" if args.check else ""))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
