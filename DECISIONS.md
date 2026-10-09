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
- The name under the icon is a separate decision (A-02). Built provisionally under D-008 as
  "12 Step Guide" on both platforms (Android dropped " - AA" in P4); revert in
  android/app/build.gradle.kts and tool/ci/verify_build.py if the owner prefers the old name.
- Android users will see renamed titles; the "What's new" text says so (MIGRATION_PLAN §8).
- The store listings should follow the same naming. That is done in App Store Connect and the
  Play Console, not in the app.
- FEATURE_MATRIX rows F-010, F-020 and F-022 now cite D-005.

## D-006 — Drop the non-working leftovers
**Decided 2026-10-09 · Tushar** (was A-09)

Nothing that does nothing in the native apps comes across: the hidden "My Account / Sign out"
row (F-089), the sponsorship notification switches (F-095), the Google and LinkedIn URL schemes
(F-114), the Face ID usage string and Sign in with Apple entitlement (F-115), and the iOS
`ADMIN_MODE` / Android `subscribedMode` and `skuMode` switches (F-117, replaced by the dev flavour).
The Android-only leftovers listed in CURRENT_APP_AUDIT.md (`accountid`, `tabno`,
`READ_PROFILE`, `org.apache.http.legacy`, WorkManager, the sample tests) go too.

*What this commits us to:*
- No user loses anything: none of these was reachable or working (CURRENT_APP_AUDIT.md).
- The migration runner does not read their legacy keys; they stay untouched on the device.
- The 15 unused HTML pages (F-116) are not shipped. They stay converted in `content/archive/`
  so nothing is lost and any of them can be brought back.

## D-007 — One new app icon on both platforms
**Decided 2026-10-09 · Tushar** (was A-22)

> "build new icons if you can"

2.0 gets a new icon, the same on iOS and Android, replacing the iOS "12 Step Guide" artwork and
the Android "A.A. 12 Steps Guide" book. It follows D-005: no circle-and-triangle symbol and no
"A.A." on the artwork.

*What this commits us to:*
- The icon is built from the brand anchors (UX_UI_SPEC §3.1), so existing users can still find
  it on their home screen: the Android navy book, the iOS sky blue, and the coral both apps use.
- The icon is drawn once in `tool/build_icons.py`, which writes the SVG masters to
  `assets/branding/` and every platform image, so a change is one edit and one command
  (UX_UI_SPEC §3.1.1).
- iOS gets light, dark and tinted variants. Android gets an adaptive icon with a monochrome
  layer for themed icons, plus classic images for Android 7.
- dev and staging builds carry a marked icon, so they can't be mistaken for the store app.
- The store listings need the new 1024 px icon too (App Store Connect, Play Console 512 px).

## D-008 — Provisional: the remaining recommendations, taken while the owner was away
**Taken 2026-10-09 · Claude, on the owner's instruction to keep going overnight** ("Don't stop
till you finish everything"). **Not yet confirmed by the owner.**

Each open decision was built the way `OPEN_QUESTIONS.md` §3 recommended. Nothing has reached a
user, so any line can still be changed; each is built behind one setting or one class, so a
change is small. When the owner confirms or changes a line, it gets its own D-number and this
entry stays as history.

| Was | Built as |
|---|---|
| A-02 | "12 Step Guide" under the icon on both platforms (Android drops " - AA") |
| A-04 | Android donors: legacy flag migrated; new donations **not consumed**; "Lost your supporter status?" opens an email to support. A hidden non-consumable `supporter_lifetime` is recognised as lifetime if the owner creates it in the Play Console for promo codes |
| A-05 | Premium = no ads + audio downloads on both. If Premium lapses, files stay on the device, tracks stream, and the Downloads page offers to remove them |
| A-06 | Android sells the three donation tiers as "Support the app — lifetime Premium". No Play subscription in 2.0 |
| A-07 | "Conclusion" is the last row under Steps |
| A-10 | Interstitial on every 3rd content open (persisted, reset after an app-open ad); app-open ≥ 45 s apart, never on first launch, onboarding, paywall, purchase flow or full player; banners in reader, player and quote screen; AdMob only |
| A-11 | Google UMP consent form where required (UK/EEA); no App Tracking Transparency prompt, so iOS ads are non-personalised where ATT would be needed |
| A-12 | iOS reminders: the new app keeps what each user actually receives (pending notifications), not the stored flag |
| A-13 | "We miss you" nudges after 3 and 7 days without opening the app, at 10:00, with a switch in Reminders (on by default) |
| A-14 | Contact us opens the email app with version and device details filled in, plus "Copy email address". The Toolkit `mail.php` form is not used |
| A-15 | No backend; purchases verified on device (StoreKit 2 / Play Billing) |
| A-16 | Minimum iOS 15 and Android 7 (API 24), as built in P0 |
| A-17 | Firebase Cloud Messaging removed (no console campaigns are known — Q-P2) |
| A-18 | Morning and night reminders left out (no user can reach them today) |
| A-19 | 8-step text size with the old sizes preserved, reading position per document, "Continue reading", previous/next at the end. No serif option |
| A-20 | Resume position per audio track and "Download over Wi-Fi only" included. Search, speed, sleep timer, favourites and quote "Another"/"Share" left out |
| A-21 | No classic-layout switch |
| A-24 | Audio catalogue bundled with the app |
| A-25 | Paywall shown automatically on launch 2, 20 and 50 on both, free users only |
| A-26 | System review prompt on launch 7, 15 and 30 on both; "Rate the app" in the drawer |
| Q-C2 | Support address `ibyteappsuk@gmail.com` (today's Android support address) |
| Q-P4 | "Our other apps" lists exactly what each app lists today, Meeting Finder included |
| Q-P5 | Privacy policy `https://www.12steptoolkit.com/privacy-policy-ibyte/`, terms `https://www.12steptoolkit.com/terms-of-service/` (today's iOS links) |
| Q-P6 | The iOS app stays available on Apple-silicon Macs (store default; nothing to build) |
