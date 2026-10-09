# 12 Step Guide — Feature Matrix

Every feature found in either native app, side by side, with the behaviour the unified Flutter
app will have. **This is also the running checklist**: no feature counts as migrated until its
row reaches ✅, and nothing is built that is not in this table.

**Classes:** `BOTH` same on both · `DIFF` on both but behaves differently · `iOS` iOS only ·
`AND` Android only · `BROKEN` incomplete, broken or unused · `NATIVE` depends on native platform
behaviour.
**Decision:** `D-xxx` means the owner has decided (`DECISIONS.md`). `A-xx` means the unified
behaviour shown is a recommendation that still needs approval (`OPEN_QUESTIONS.md` §3). Rows without a decision follow directly from the brief (keep
everything, give Android the iOS extras).
**Status:** ☐ not started · ◐ in progress · ✅ built, tested on both platforms, cross-checked
against this row · ✖ dropped by owner decision (the row stays).

Source references are given as `File:line` or the class name. The audit (`CURRENT_APP_AUDIT.md`)
has the detail.

---

## 1. Launch, onboarding, shell

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-001 | Launch screen | Launch image storyboard | `BrandedLaunch` theme on `First` | DIFF · NATIVE | Different artwork | Native splash (flutter_native_splash) in brand colours, light and dark, then straight to the shell. No artificial delay. Uses the new icon mark | D-007 | ☐ |
| F-002 | First-run onboarding | 6 pages: Welcome, Audiobooks ×2, Big Book, Ad-supported, All set | 3 pages: Hey there, Support us, Ad-supported | DIFF | Content and length | One 4-page flow on both: Welcome → What's inside (steps, Big Book, audio) → Reminders (primes notification permission, F-064) → Ad-supported/Premium note. Skippable; shown once | — | ◐ |
| F-003 | "App updated" onboarding for upgraders | 5 pages when `FLAG_ONBOARDING_UPDATE_SHOWN` is false | — | iOS | | One "Welcome to the new 12 Step Guide" screen for **every** upgrading user on both platforms, saying their date, reminders, downloads and purchases came across. Shown once after migration | — | ◐ |
| F-004 | Launch counter | `launchcount` (counts the first launch twice) | `…launchCount…` key | DIFF | Keys differ; iOS value is launches + 1 | One counter, seeded from the legacy value so prompt cadences continue | — | ◐ |
| F-005 | Primary navigation | 5 tabs: The Steps, Literature, Big Book, Audio Books, Settings | 5 tabs: Steps, Traditions, Readings, Big Book, Settings | DIFF | Different sets | 4 tabs: **Steps** (Steps \| Traditions), **Readings**, **Big Book**, **Audio**. Settings and secondary items move to the drawer (F-080) | D-001 | ◐ |
| F-006 | Now-playing indicator | Animated icon in the nav bar opens the player | — | iOS | | Mini-player docked above the tab bar on every tab while a track is loaded; tap → full player | — | ☐ |
| F-007 | Tab transition | Crossfade | Fragment swap; per-tab back stacks | DIFF · NATIVE | | Per-tab back stacks (StatefulShellRoute); platform default transitions | — | ◐ |
| F-008 | Bottom bar hidden on detail screens | — | Hidden on reader, calculator, store | AND | | Hidden in the reader and full player (immersive reading); shown elsewhere | — | ◐ |
| F-015 | Free/Pro header on Steps and Traditions | — | "12 Step Guide - AA Free" / "… Pro" above the list | AND | | Status lives in the drawer header and Premium page; lists carry no header | D-001 | ◐ |
| F-009 | Double-tap guard | — | 300 ms | AND | | Navigation is debounced so one tap opens one screen | — | ◐ |

## 2. Steps and Traditions

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-010 | Steps list (Intro + 12) | Number icons, step text subtitle | Number icons, step text subtitle | BOTH | Icon art differs; iOS Intro uses the AA circle-triangle symbol | Same list, new number badges; no AA symbol | D-005 | ◐ |
| F-011 | Step guide text | Original text (`guide/gtape1–13`) | Expanded 2024 text (`guide/tape1–13`) | DIFF | Different text and length | Android's 2024 text on both platforms; the iOS original kept in `content/archive/` | D-002 | ◐ |
| F-012 | Conclusion chapter | `gtape14`, unlinked | `tape14`, unlinked | BROKEN | Hidden on both | Listed as the last row under Steps ("Conclusion") | A-07 | ◐ |
| F-013 | Traditions list + 12 guides | — | Tab with full tradition text as subtitles; `guide/tradition1–12` | AND | | "Traditions" segment inside the Steps tab, on both platforms | D-001 | ◐ |
| F-014 | Interstitial before a guide | Every 2nd content tap | Every 3rd open | DIFF | Pacing | Unified ad pacing (F-073) | A-10 | ☐ |

## 3. Readings (prayers, readings, tips)

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-020 | Daily Reflections link | Top of Literature, "Link – Opens Official AA Website" | Readings row "Today's AA Daily Reflection ↗" | DIFF | Placement, title | Row near the top of Readings: "Daily Reflections ↗ Opens aa.org". Opens the system browser (in-app browser tab), no ad before it | D-005 | ◐ |
| F-021 | Prayers (6) | Serenity, Serenity Extended Version, 3rd Step, 7th Step, 11th Step, Lord's Prayer | Serenity, Serenity Plus, Third Step, Seventh Step, Eleventh Step, The Lord's Prayer | DIFF | Titles | Same 6 documents; titles from one content index (iOS wording, "Serenity Prayer (Extended)") | — | ◐ |
| F-022 | Readings (8) | Preamble, How It Works, 12 Traditions, Promises, Just For Today, On Awakening, On Retiring, A Vision For You | How It Works, 12 Traditions, Promises (9th Step), Preamble, Just For Today, On Awakening, When We Retire, A Vision For You | DIFF | Order, titles | One order and one set of titles; "When We Retire" (the Big Book phrase) with "On Retiring" as a search alias | D-005 | ◐ |
| F-023 | Sobriety Tips (4) | — | How to use the Big Book, How to find a sponsor, Sobriety & Recovery, 12 Years On | AND | | Section "Sobriety tips" in Readings on both. Fixes BUG-11 (wrong titles) | — | ◐ |
| F-024 | Promote our other apps | Literature section, 5 App Store apps | Settings section, 5 Play apps incl. Meeting Finder | DIFF | Lists differ | "Our other apps" page from the drawer; one list per platform, from config; no ads before opening a store link | Q-P4 | ◐ |

## 4. Big Book

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-030 | Big Book chapters (14) | `aa/tape1–14` | `aa/tape1–14` | DIFF | Android Bill's Story has the restored p.15 paragraph | Android text (the corrected one) on both | — | ◐ |
| F-031 | Personal Stories, 1st edition (29) | ✓ | ✓ | BOTH | `stories1_30` unreachable on both | Same 29 (`stories1_30` was listed in Android's array but never existed — Q-C3 resolved) | — | ◐ |
| F-032 | Personal Stories, 2nd edition (40) | ✓ | ✓ | BOTH | | Same | — | ◐ |
| F-033 | Segment switcher | Segmented control + swipe; labels shrink on narrow screens | Swipeable tabs | DIFF · NATIVE | | Segmented control (Big Book · 1st ed. · 2nd ed.) with swipe between pages | — | ◐ |
| F-034 | Card grid with `#n`, title, page range | Gradient-coloured borders | Gradient-coloured borders | BOTH | | Same information; tokenised colours; adaptive column count (2 phone, 3–4 tablet) | — | ◐ |
| F-035 | "Pioneers" / "Pages –––" placeholders | Shown | Shown | BOTH | | Page range hidden when unknown (no "Pages –––") | — | ◐ |

## 5. Reader

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-040 | Render literature | WKWebView, HTML + injected CSS | WebView from assets | DIFF · NATIVE | | Native Flutter text rendered from the Markdown files in `content/`: selectable, screen-reader friendly, themed | D-003 | ◐ |
| F-041 | Text size | Small/Medium/Large = 18/24/30 px | Normal/Larger/Largest = 100/130/160 % | DIFF | Scales differ | One "Aa" sheet: 8-step size slider whose steps include both old scales; legacy choice migrated; also respects system text size | A-19 | ◐ |
| F-042 | Dark mode in reader | White text injected | — | iOS | | Full light/dark reader surfaces from tokens | — | ◐ |
| F-043 | Font-size tooltip | — | "Change font size from here", max 2 times | AND | | One-time coach mark on the Aa button the first time a reader opens | — | ◐ |
| F-044 | Links inside content | Open inside the reader (BUG-12) | Open in the browser | DIFF | | External → in-app browser tab; `mailto:` → mail; `#anchor` → scroll; store links → store | — | ◐ |
| F-045 | Banner ad in reader | Bottom | Bottom | BOTH | | Adaptive banner at the bottom, never covering text; free users only | A-10 | ☐ |
| F-046 | Reading position | — | — | — | | Remembers the scroll position per document; "Continue reading" chip at the top of Big Book | A-19 | ◐ |

## 6. Sobriety

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-050 | Sobriety date | — | `myAppDay/Month/Year` | AND | | "Your recovery" card at the top of Readings on both. Migrated from Android | — | ◐ |
| F-051 | Calculator screen | — | Recovering since + days; date picker max today; "Change recovery date" | AND | | Recovery date screen: since date, total days (plus years/months/days breakdown as secondary text), change date, clear date. Calendar-date maths (fixes BUG-10) | — | ◐ |
| F-052 | "Scroll back years" hint | — | Material dialog with "Don't show again" | AND | | Not needed: the date picker has a year selector | — | ◐ |
| F-053 | Cheer sound on "Sober for" | — | Plays `notification_4.mp3` | AND | | Kept: tapping the day count plays the cheer (respects silent mode) | — | ◐ |
| F-054 | Sober Today promotion | — | Banner + Play link in the calculator | AND | | Small "Get Sober Today for detailed stats" link on the recovery date screen (store link per platform) | — | ◐ |

## 7. Audio

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-060 | Audio library (11 albums, 138 tracks) | `AudioBooksVC` from bundled `main.db` | — | iOS | | Audio tab on both. Catalogue shipped as an asset generated from `main.db` | A-24 | ☐ |
| F-061 | Album screen | Tracks, download state, ⋯ menu: Download all / Delete offline / Play all | — | iOS | | Same actions, as visible buttons rather than a hidden menu | — | ☐ |
| F-062 | Streaming playback | From `scripts.12stepapp.com/tracks/…` | — | iOS | | Same URLs, unchanged. Buffering state and network error with retry | — | ☐ |
| F-063 | Player | Modal; play/pause, ±10 s, prev/next, scrubber, times, transcript (2 albums) or animation, font size, banner | — | iOS | | Same controls; transcript for Joe & Charlie and Big Book; artwork tile otherwise; ±10 s kept; fixes BUG-05 | — | ☐ |
| F-064 | Auto-advance + loop album | ✓ | — | iOS | | Kept | — | ☐ |
| F-065 | Downloads | Subscribers only; 2 at a time; progress ring; files in Documents | — | iOS | | Premium only; background downloads with progress; same Documents location on iOS so existing files are reused | A-05 | ☐ |
| F-066 | Offline play rule | Local file only while subscribed | — | iOS | | See A-05 | A-05 | ☐ |
| F-067 | Background audio | Background mode on; session mixes with other audio (`mixWithOthers`); no lock-screen controls (BUG-07) | — | iOS · NATIVE | | Background playback with lock-screen / notification media controls on both (required for Android); standard spoken-audio session that pauses other audio (difference from iOS today) | — | ☐ |
| F-068 | Ads around audio | Interstitial every 2nd play/next/prev; banner in player; playback paused for the ad | — | iOS | | Unified pacing (F-073); never interrupts audio already playing | A-10 | ☐ |
| F-069 | Favourites | Button outlet + `favourites` table, never wired | — | BROKEN | | Not built (no behaviour existed) | A-20 | ☐ |

## 8. Monetisation

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-070 | Premium definition | No ads + downloads | No ads | DIFF | | **Premium** = no ads + audio downloads, on both | A-05 | ☐ |
| F-071 | Annual subscription `annual` (7-day trial) | Sold | — | iOS | | Sold on iOS, same product id, StoreKit 2 | A-06 | ☐ |
| F-072 | Donation tiers | Old iOS tiers (`…donatetier5/10/20`): restore only, lifetime | `donatetier1/2/3`: sold, consumed, "remove ads for life" | DIFF | | iOS: legacy tiers keep lifetime Premium. Android: tiers keep being sold as "Support the app" and give lifetime Premium | A-04, A-06 | ☐ |
| F-073 | Interstitial pacing | Every 2nd counted tap (also counts non-content taps — BUG-31); AdMob only | Every 3rd open incl. the Daily Reflection link, persisted; AdMob → Meta fallback | DIFF | | Every 3rd content open, persisted, reset after an app-open ad; never before external links; AdMob only (Meta via AdMob mediation if wanted) | A-10 | ☐ |
| F-074 | App-open ads | ≥ 45 s since last, not on cold start, not over paywall | Every foreground, ≥ 20 s (in memory) | DIFF | | ≥ 45 s since last (persisted); never on first launch, onboarding, paywall, purchase flow or full player | A-10 | ☐ |
| F-075 | Banner ads | Reader, player, quote screen | Reader | DIFF | | Reader, player, quote screen | A-10 | ☐ |
| F-076 | Mute video ads | — | `setAppVolume(0)` | AND | | Kept on both (and never duck playing audio) | — | ☐ |
| F-077 | Ad consent | None | None (changelog says UMP; code doesn't) | BROKEN | | Google UMP consent at first launch for UK/EEA; "Privacy & ad choices" in the drawer; no ATT on iOS | A-11 | ☐ |
| F-078 | Paywall | Auto at launch 2, 20, 50; benefits list; price; terms/privacy links | Store list of tiers | DIFF | | One paywall screen per platform's products (§3 of the spec); auto-shown on iOS cadence on both, never on first launch | A-25 | ☐ |
| F-079 | Restore purchases | Settings row; toasts; silent restore on first launch after upgrade (may prompt Apple ID) | — (automatic) | iOS | | "Restore purchases" in the drawer and on the paywall, on both; StoreKit 2 check at launch never prompts sign-in | — | ☐ |
| F-079a | Subscription status | "Annual Subscription · Expires …", legacy-supporter note, cancel instructions | "Purchased" labels | DIFF | | Premium page: plan, renewal date or "Lifetime", legacy-supporter note, "Manage subscription" (opens store) | — | ☐ |
| F-079b | Receipt validation | `verifyReceipt` with shared secret, on device | Purchase history | DIFF · NATIVE | | iOS StoreKit 2 on-device verification (no secret); Android `queryPurchases` + migrated flag | A-15 | ☐ |

## 9. Drawer destinations (formerly Settings)

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-080 | Settings location | Tab | Tab | BOTH | | Drawer (all tabs); opens full pages | D-001 | ◐ |
| F-081 | Rate the app | Row + auto prompt at launch 7/15/30 | Row + custom dialog at launch 5/11/30/40… | DIFF | | Drawer row opens the store page. Auto prompt uses the system review API on iOS cadence, never over content | A-26 | ☐ |
| F-082 | More apps from developer | App Store developer page | Play developer search | BOTH | | Inside "Our other apps" | — | ◐ |
| F-083 | Facebook page | Row | — | iOS | | "Follow us on Facebook" in Help & support | — | ◐ |
| F-084 | Contact developers | In-app form → Toolkit `mail.php` | Email app → `ibyteappsuk@gmail.com` | DIFF | Mechanism and address | See A-14 | **A-14** | ☐ |
| F-085 | Tell a friend | Share text with both store links | Share text with Play link | DIFF | | Share sheet with both store links | — | ◐ |
| F-086 | Privacy policy | `…/privacy-policy-ibyte/` | `…/privacy` | DIFF | URL | One URL (iOS one) | Q-P5 | ◐ |
| F-087 | Terms of use | Settings + paywall | — | iOS | | Drawer + paywall, both | — | ◐ |
| F-088 | App version | Contact footer | Settings footer | DIFF | | About page + drawer footer | — | ◐ |
| F-089 | Hidden "My Account / Sign out" | Hidden row | — | BROKEN | | Not built (no accounts) | D-006 | ✖ |

## 10. Reminders

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-090 | Hourly consciousness reminder | Start/end hour, at start minute; default 08:00–22:00 | — | iOS | | Both platforms. Same defaults, same text. iOS state migrated from what is actually scheduled (BUG-03); Android starts off | A-12 | ☐ |
| F-091 | Quote reveal screen | Random line from `quotes.txt` (only 60 of 61 reachable; possible blank — BUG-24), banner | — | iOS | | All 61 quotes, never blank; banner for free users | — | ☐ |
| F-092 | On-awakening reminder | Implemented ("Time For Your Morning Inventory") but the cell is **hidden**, so no user can enable it | — | BROKEN | Unreachable | Not built unless A-18 approves (then: both platforms, tap opens "On Awakening") | A-18 | ☐ |
| F-093 | Night-time reminder | Implemented ("Time For Your Night Inventory") but the cell is **hidden** | — | BROKEN | Unreachable | Not built unless A-18 approves (then: tap opens "When We Retire") | A-18 | ☐ |
| F-094 | "We miss you" (3 and 7 days) | Fresh installs only; fires once at 00:00; tap likely crashes (BUG-22) | — | iOS · BROKEN | | Re-armed on every open so it fires after 3/7 days without use, at a daytime hour; switch in Reminders | A-13 | ☐ |
| F-095 | Sponsorship notification switches | Implemented, cells hidden, no feature behind them | — | BROKEN | | Not built | D-006 | ✖ |
| F-096 | Remote push (FCM) | None in practice: APNs registration only, no FCM SDK; Toolkit handlers unreachable | SDK with default display of console notifications (Android ≤ 12) | BROKEN · NATIVE | | Keep FCM display-only on both if campaigns are used; otherwise remove | **A-17** | ☐ |
| F-097 | Permission request | At every launch, no context | Never | DIFF · NATIVE | | Primed in onboarding (F-002) and when a reminder is first switched on; Android 13+ `POST_NOTIFICATIONS` | — | ☐ |
| F-098 | Hourly window changes | Narrowing the window leaves old hours scheduled (BUG-23) | — | BROKEN | | Scheduler diffs the wanted set against pending requests | — | ☐ |

## 11. Appearance, accessibility, devices

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-100 | Dark mode | Follows system | Light only | DIFF | | Light / Dark / System (default System) in Appearance | — | ◐ |
| F-101 | Tablet / iPad layout | Universal, all orientations | Large-screen dimens | BOTH · NATIVE | | Responsive: 2-pane where it helps (lists + reader on wide screens), navigation rail on tablets | — | ☐ |
| F-102 | Orientation | All | All | BOTH | | All on tablets; phones portrait + landscape | — | ◐ |
| F-103 | Screen reader & text scaling | Minimal | Minimal | BROKEN | | Full semantics and Dynamic Type / font scale support (UX spec §9) | — | ◐ |
| F-104 | Mac (Apple silicon) and visionOS availability | Offered by the store | — | iOS · NATIVE | | Keep "iPad apps on Mac" availability unless the owner opts out; smoke-test once | Q-P6 | ☐ |

## 12. Platform services

| ID | Feature | iOS | Android | Class | Differences | Unified Flutter behaviour | Decision | Status |
|---|---|---|---|---|---|---|---|---|
| F-110 | Firebase Analytics | Automatic | Automatic | BOTH | | Same project, same apps → continuity. No new custom events without approval | — | ☐ |
| F-111 | Crashlytics | ✓ | ✓ (with breadcrumbs) | BOTH | | ✓; breadcrumbs carry no personal data | — | ☐ |
| F-112 | Network reachability | `Reachability` before streaming | — | iOS | | Connectivity-aware audio and links, with offline banners | — | ☐ |
| F-113 | Backups | iCloud backs up Documents (downloads too) | `allowBackup=true` | NATIVE | | Downloads excluded from iCloud backup (re-downloadable); preferences backed up on both | — | ☐ |
| F-114 | URL schemes (Google, LinkedIn) | Declared, unused | — | BROKEN | | Not carried over | D-006 | ✖ |
| F-115 | Face ID string, Sign in with Apple entitlement | Declared, unused | — | BROKEN | | Not carried over | D-006 | ✖ |
| F-116 | Unused HTML pages | 10 files | 5 files | BROKEN | | Converted to Markdown in `content/archive/` for reference, not shipped | D-006 | ✖ |
| F-117 | Debug "admin" switches | `ADMIN_MODE` | `subscribedMode`, `skuMode` | BROKEN | | Replaced by the dev flavour and test ad units (flavours done in P0; test units with P4) | D-006 | ◐ |

---

## Count

92 rows (F-001 … F-117, numbered in blocks of ten per area). By class (a row can carry two):
DIFF 31, iOS 21, BROKEN 15, BOTH 12, AND 12, NATIVE 11.

**Not lost:** every iOS-only row and every Android-only row has a unified behaviour that keeps
it on both platforms, except the BROKEN rows, which had no working behaviour. Those are dropped
by D-006.
