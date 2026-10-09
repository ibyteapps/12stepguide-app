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

## D-005 — AAWS-compliant names on both platforms, no circle-and-triangle symbol
**Decided 2026-10-09 · Tushar** (was A-03)

Both platforms use the names iOS adopted in 1.21 for the 2021 "AAWS Complaint Compliance"
release. The places iOS 1.21 missed are renamed as well. The A.A. circle-and-triangle symbol
is not used anywhere in the app, its icons or its store artwork.

| Today | 2.0 |
|---|---|
| "AA Big Book", "AA Big Book Text", "Big Book - Alcoholics Anonymous" (segment, album short name, onboarding) | "The Big Book" |
| "Alcoholics Anonymous Literature" (iOS Literature header) | "Readings" (the tab, D-001) |
| "AA Daily Reflections", "Today's AA Daily Reflection ↗", "Link – Opens Official AA Website" | "Daily Reflections ↗" with "Opens the official aa.org page" |
| "AA Preamble", "AA 12 Traditions" (Android) | "The Preamble", "The Twelve Traditions" |
| "AA Speaker Tapes" | "Speaker Tapes" |
| "Recovery Box - AA 12 Step Toolkit" | "12 Step Toolkit" |
| "AA 12 Step Guide" (iOS share text) | "12 Step Guide" |
| Circle-and-triangle list icon (`ic_sobersince` beside "Introduction" on iOS; Android list icon) | Number badge / Material Symbol |

*What this commits us to:*
- App titles, headers, onboarding, share text, notifications and the drawer carry no "AA"
  prefix. The About page carries the disclaimer: "not affiliated with or endorsed by Alcoholics
  Anonymous or A.A. World Services, Inc." (UX_UI_SPEC §10).
- The literature and recordings keep their own titles and words: "Alcoholics Anonymous Number
  Three", the Joe and Charlie talks "AA History – Part 1–4", and the book's text are the names
  of the works, not app branding. Changing them would be a content edit (content/README.md).
- The name under the icon is a separate decision (A-02, still open; Android today shows
  "12 Step Guide - AA"). Until it is decided the prod builds keep each platform's current name.
- Android users will see renamed titles; the "What's new" text says so (MIGRATION_PLAN §8).
- The store listings should follow the same naming. That is done in App Store Connect and the
  Play Console, not in the app.
- FEATURE_MATRIX rows F-010, F-020 and F-022 now cite D-005.
