# Literature content (Markdown)

Every HTML document from the two native apps, redone as standard Markdown (decision D-003).
The app bundles the folders marked **shipped**. The originals are kept, unchanged, in
`content-source/html/` (`android/` = Android assets, `ios/` = iOS bundle).

Regenerate and verify:

```bash
python3 tool/html_to_markdown.py --check
```

`--check` compares every output file with its source, word for word and in order. The only
words allowed to differ are printed page numbers, which move into page markers. Last run:
**207 documents, 0 differences.**

## Folders

| Folder | Docs | Shipped | Source | Notes |
|---|---|---|---|---|
| `steps/` | 14 | ✓ | Android `guide/tape1–14` (2024 text, D-002) | Introduction, Steps 1–12, Conclusion (the Conclusion was hidden in both apps) |
| `traditions/` | 12 | ✓ | Android `guide/tradition1–12` | New on iOS |
| `big-book/` | 14 | ✓ | Android `aa/tape1–14` | Android text includes the Bill's Story paragraph iOS lacks (p. 15) |
| `stories-1st-edition/` | 29 | ✓ | Android `aa/stories1/` | |
| `stories-2nd-edition/` | 40 | ✓ | Android `aa/stories2/` | |
| `prayers/` | 6 | ✓ | Android `aa/` | |
| `readings/` | 8 | ✓ | Android `aa/` | |
| `sobriety-tips/` | 4 | ✓ | Android `aa/x*.html` | New on iOS |
| `transcripts/joe-and-charlie/` | 34 | ✓ | iOS `JoeAndCharlie/` | Front matter links each to its audio track (`track_id`, `audio_file`) |
| `transcripts/big-book/` | 14 | ✓ | iOS `AABigBook/` (the copies the iOS app actually loads) | Same |
| `archive/ios-original-step-guides/` | 14 | — | iOS `guide/gtape1–14` | The original iOS step text, replaced by D-002 |
| `archive/ios-text-variants/` | 1 | — | iOS `aa/tape2.html` | iOS copies whose words differ from the shipped Android text; only Bill's Story does |
| `archive/unused-android/`, `archive/unused-ios/`, `archive/unused-ios-transcripts/` | 5 / 10 / 2 | — | Leftover pages neither app ever showed | Kept so nothing is lost (A-09) |

## File format

```markdown
---
id: "big-book/06-chapter-5-how-it-works"
title: "Chapter 5: How It Works"
collection: "big-book"
order: 6
pages: "58–71"
source: "android/aa/tape6.html"
---

# Chapter 5

## HOW IT WORKS

<!-- page 58 -->

Rarely have we seen a person fail who has thoroughly followed our path…
```

- **Front matter** (YAML): `id` (stable; the app keys reading positions on it), `title` (the list
  title), `collection`, `order`. Where they apply: `subtitle` (step or tradition wording),
  `pages`, `aliases`, `album_id` / `track_id` / `audio_file` (transcripts), and `source` (the
  original file).
- **Headings:** the document's own printed headings. The first is `#`, the rest `##`. The list
  title in the app comes from `title`, not from the heading.
- **Line breaks** in prayers, poems and verse are CommonMark hard breaks (a trailing `\`).
- **Page numbers:** `<!-- page N -->` sits where printed page N begins (795 markers across the
  Big Book and the stories). A marker can sit mid-sentence when the page turned mid-sentence.
  Ordinary Markdown viewers hide them; the app shows a discreet page indicator.
- **Lists:** numbered runs (Steps in "How It Works", the Twelve Traditions) are real ordered
  lists.
- **Tables:** GFM tables (the resentment list in Chapter 5); a line break inside a cell is
  `<br>`.
- **Footnote asterisks** in the Big Book are escaped (`\*`) so they print as asterisks.
- **Typographic ligatures** (`ﬁ`, `ﬂ`) were normalised to plain letters. The text was not
  otherwise changed.

The app reads these files with the maintained `markdown` package (CommonMark + GFM tables) and
renders them with its own widgets: themed, scalable, selectable and screen-reader friendly
(`FLUTTER_ARCHITECTURE.md` §8).

## Known source issues (converted faithfully, not yet fixed)

These are in the original HTML and appear the same in today's apps. Fixing them means editing the
literature, so each needs a deliberate clean-up pass approved by the owner.

1. **Chapter 10 "To Employers"** (`big-book/11-…`) also contains Chapter 11 and "Doctor Bob's
   Nightmare" after p. 150, duplicating two other documents.
2. **Line-end hyphenation left in the text**: 134 places such as "Cathe- dral" and "appre-
   ciation" in the Big Book and the stories.
3. **Footnotes sit where the printed page ended**, sometimes mid-sentence (e.g. "Now We Are
   Thousands", p. 392–393).
4. **Missing spaces before an italic word** in five 2nd-edition stories: "anybody*forget*",
   "remember*what*", "bring*that*", "right*people*", "wanting*to*" (stories 25, 32, 37, 38,
   40).
5. **"11 Sought through prayer…"** has no full stop after the number in the Big Book audio
   transcript (`transcripts/big-book/06-…`).
6. **The Introduction (step guides) says "on the Google Play Store by clicking here"**, which
   will read oddly on iPhone. It also gives the personal address `ibyteapps@gmail.com` (Q-C2).
7. **The "Preface" is the fourth-edition (2001) preface** ("This fourth edition includes the
   Twelve Concepts…"), and **"The Preamble"** wording differs from the A.A. Preamble. See the
   rights note in `OPEN_QUESTIONS.md` (Q-L2).
8. The Android list of 1st-edition stories named 30 files, but only 29 exist. All 29 are here
   (Q-C3 resolved).
