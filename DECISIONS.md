# DECISIONS.md

Owner decisions that settle questions from `OPEN_QUESTIONS.md`. Each entry records the
decision, the date, and what it commits the build to. To change one, add a new entry that
supersedes it; do not edit history.

---

## D-001 — Four tabs and a drawer
**Decided 2026-10-09 · Tushar** (was A-01)

Primary navigation is four tabs: **Steps** (with Steps and Traditions as segments),
**Readings**, **Big Book** and **Audio**. Settings and every secondary destination move into a
drawer: Premium, Reminders, Appearance, Downloads, Help & support, Our other apps, Privacy &
legal, About.

*What this commits us to:*
- Android users lose the separate Traditions tab; Traditions are one tap away inside Steps.
- iOS users lose the Settings tab; everything in it is in the drawer.
- No "classic layout" switch unless A-21 is reopened.
- `UNIFIED_PRODUCT_SPEC.md` §3 is the reference; FEATURE_MATRIX rows F-005, F-013, F-015, F-080.

## D-002 — Android's 2024 step guides on both platforms
**Decided 2026-10-09 · Tushar** (was A-08 / Q-C1)

The expanded step-guide text Android has shipped since build 27 (2024) is the text on both
platforms. The original iOS text is kept, converted, in `content/archive/ios-original-step-guides/`.

*What this commits us to:*
- iOS users will see longer, rewritten guides; this belongs in the iOS release notes.
- The Introduction mentions the Google Play Store and a personal email address. That wording
  needs a decision before release (content/README.md, known issue 6; Q-C2).

## D-003 — The literature becomes standard Markdown
**Decided 2026-10-09 · Tushar** (replaces the A-23 recommendation of pre-parsed JSON)

> "redo all html files and make them standard .md files"

Every HTML document from both apps is converted to a standard Markdown file
(CommonMark + GFM tables, YAML front matter) in `content/`. The originals stay in
`content-source/html/`. The app renders the Markdown natively. It does not use a web view.

*What this commits us to:*
- `tool/html_to_markdown.py` is the reproducible converter. `--check` proves every document
  keeps exactly the source's words, in order. The first run converted 207 documents with
  0 differences.
- The text was converted, not edited. Source defects (hyphenation artefacts, a duplicated chapter
  inside Chapter 10, footnotes mid-sentence, five missing spaces) are listed in
  `content/README.md` for a separate clean-up that needs your approval.
- Printed page numbers are kept as `<!-- page N -->` markers (795 of them), so the app can show
  page numbers and resume reading by page.
- The app gets the `markdown` parser package and its own renderer (`FLUTTER_ARCHITECTURE.md`
  §8). Neither app's HTML or CSS is shipped.

## D-004 — No newer iOS source
**Decided 2026-10-09 · Tushar** (was Q-P1)

There is no iOS project newer than `Work/Apple/12StepGuideAA/workspace`. It is treated as the
source of the live 1.51 build. The mismatch between the project's 1.21 and the store's 1.51
stays unexplained and does not matter: 2.0.0 is above both.
