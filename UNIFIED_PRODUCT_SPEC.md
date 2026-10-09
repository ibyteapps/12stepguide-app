# 12 Step Guide — Unified Product Specification

The single product that ships to both stores as version 2.0. It contains every working feature
of both native apps (`FEATURE_MATRIX.md`), arranged so that neither audience loses its way
around. Items marked **[A-xx]** depend on an owner decision in `OPEN_QUESTIONS.md`. The
recommended option is written here so the spec reads as one product.

---

## 1. Product principles

1. **Nothing working is lost.** Every row in the feature matrix maps to a screen below.
2. **Familiar first, better second.** Tab order, card grids, step lists and wording stay
   recognisable. The look modernises; the workflows don't move.
3. **Reading and listening are the product.** Ads and prompts never interrupt reading text,
   never stop audio that is playing, and never appear on first launch.
4. **Works offline.** All literature is bundled. Audio streams when online and plays offline
   when downloaded.
5. **No account, no server of our own** for 2.0 **[A-15]**. Everything a user has lives on the
   device; purchases are verified with the stores.
6. **Same app on both platforms**, with native conventions only where they help: system date
   and time pickers, share sheet, store review dialog, back gesture, haptics.

---

## 2. Premium and monetisation rules

### 2.1 What Premium gives [A-05]
| | Free | Premium |
|---|---|---|
| All literature, steps, traditions, readings | ✓ | ✓ |
| Streaming audio | ✓ (with ads) | ✓ |
| Audio downloads, offline listening | — | ✓ |
| Reminders | ✓ | ✓ |
| Adverts | Banner, interstitial, app-open | None |

### 2.2 How a user becomes Premium [A-04, A-06]
| Platform | Product | Sold in 2.0 | Premium for |
|---|---|---|---|
| iOS | `annual` subscription, 7-day free trial | Yes | While active (incl. trial and billing grace) |
| iOS | `com.ibyteapps.aa12stepguide.donatetier5 / 10 / 20` | No (restore only) | Lifetime |
| Android | `donatetier1 / 2 / 3` | Yes, as "Support the app — lifetime Premium" | Lifetime |
| Android | `annual` subscription (optional, new) | Only if A-06 approves | While active |

Entitlement is computed by one `Entitlement` service from: the stores (StoreKit 2 transactions
on iOS; Play `queryPurchases` on Android) **plus** the flag migrated from the native app
(`MIGRATION_PLAN.md` §5). A legacy lifetime flag is never cleared by the app.

### 2.3 Paywall cadence [A-25]
- Never on first launch or during onboarding.
- Shown once automatically on launch 2, 20 and 50 (the iOS rule), on both platforms, for free
  users only. Close is always visible.
- Shown on demand from: drawer header, Premium page, a download button, "Download all", and the
  "Remove ads" link under banners.

### 2.4 Ad rules [A-10]
| Format | Where | Pacing | Never |
|---|---|---|---|
| Interstitial | Before opening a guide, reading, Big Book document, or starting a track | Every 3rd content open, counted across sessions; the counter restarts after an app-open ad | On first launch, external links, store links, Daily Reflections, closing a screen, or while audio plays |
| Banner (adaptive) | Reader bottom, full player, quote screen | Always for free users | Over text or controls; in onboarding, paywall, drawer pages |
| App-open | Returning to the app | ≥ 45 s since the last app-open ad (persisted), loaded ad < 4 h old | First launch, onboarding, paywall/purchase flow, full player, a notification tap that opens a quote |

All video ads are muted. Ads load only after consent is resolved [A-11].

---

## 3. Navigation

### 3.1 Primary navigation (approved, D-001)
Bottom navigation bar (phones), navigation rail (tablets and landscape ≥ 600 dp):

| # | Tab | Icon | Contains | Where it came from |
|---|---|---|---|---|
| 1 | **Steps** | footsteps / list-numbered | Segments **Steps** · **Traditions** | iOS "The Steps" + Android "Steps" and "Traditions" |
| 2 | **Readings** | open book with bookmark | Your recovery card, Daily Reflections, Prayers, Readings, Sobriety tips | iOS "Literature" + Android "Readings" |
| 3 | **Big Book** | book | Segments **Big Book** · **Stories, 1st ed.** · **Stories, 2nd ed.** | Both "Big Book" tabs |
| 4 | **Audio** | headphones | Albums → tracks → player | iOS "Audio Books" |

**Why four, not five.** Settings is not daily functionality, so it goes to the drawer as the
brief asks. Traditions sits beside Steps (same kind of content, same list layout), which keeps
the tab bar uncluttered for iOS users who never had it. Every daily-use destination is still one
tap away. The order matches iOS exactly and Android's apart from Traditions.

A **classic layout** switch (as in 12 Step Toolkit's D-011) is not recommended here: the new
arrangement already matches both old tab orders [A-21].

### 3.2 App bar
Every tab root has: ☰ menu (opens the drawer) · tab title · contextual action (Big Book:
"Continue reading" when there is one; Audio: "Downloads"). Detail screens get a back button
and no ☰.

### 3.3 Mini-player
A 64 dp bar above the tab bar whenever a track is loaded: title, album, play/pause, progress
hairline. Tap → full player. Swipe down / ✕ stops playback and hides it.

### 3.4 Drawer
Modal navigation drawer, opened from ☰ or an edge swipe (Android). On iOS the edge swipe stays
"back", so the drawer opens from ☰ only.

```
┌──────────────────────────────────┐
│  [icon] 12 Step Guide            │
│  Free · Go Premium – £16.99/yr ▸ │  ← or "Premium · renews 3 Mar" / "Premium · lifetime"
├──────────────────────────────────┤
│  YOUR APP                        │
│  ★  Premium                      │
│  🔔 Reminders                    │
│  ◐  Appearance                   │
│  ⬇  Downloads                    │
├──────────────────────────────────┤
│  HELP & SUPPORT                  │
│  ✉  Contact us                   │
│  ☆  Rate the app                 │
│  ↗  Tell a friend                │
│  f  Follow us on Facebook        │
│  ▦  Our other apps               │
├──────────────────────────────────┤
│  PRIVACY & LEGAL                 │
│  ⚙  Privacy & ad choices         │  ← only where UMP requires it (UK/EEA)
│  🔒 Privacy policy  ↗            │
│  §  Terms of use  ↗              │
├──────────────────────────────────┤
│  About · Version 2.0.0 (100)     │
└──────────────────────────────────┘
```
Not included, because the app has none of them: Account, Profile, Sign out, Delete account.

---

## 4. Screen map

```
Splash (S-01)
├─ Consent form (UMP, UK/EEA only) (S-02a)
├─ Onboarding ×4 (first run) (S-02)
├─ Welcome to the new 12 Step Guide (upgraders, once) (S-03)
└─ Shell (S-04) ── Drawer (S-50)
   ├─ Steps (S-10)
   │   ├─ [Steps] Introduction, Step 1–12, Conclusion → Reader (S-11)
   │   └─ [Traditions] Tradition 1–12 → Reader (S-11)
   ├─ Readings (S-20)
   │   ├─ Your recovery card → Recovery date (S-21)
   │   ├─ Daily Reflections ↗ (browser)
   │   ├─ Prayers ×6 → Reader
   │   ├─ Readings ×8 → Reader
   │   └─ Sobriety tips ×4 → Reader
   ├─ Big Book (S-30)
   │   ├─ [Big Book] 14 → Reader
   │   ├─ [Stories, 1st ed.] 29 → Reader
   │   └─ [Stories, 2nd ed.] 40 → Reader
   └─ Audio (S-40)
       └─ Album (S-41) ×11 → Full player (S-42) ⇄ Mini-player (S-43)

Reader (S-11) ── Aa sheet (S-12)
Drawer (S-50)
├─ Premium (S-51) ── Paywall (S-51b)
├─ Reminders (S-52) ── time pickers
├─ Appearance (S-53)
├─ Downloads (S-54)
├─ Contact us (S-55)
├─ Our other apps (S-56)
├─ Privacy & ad choices (S-59, UMP form)
├─ Privacy policy ↗ / Terms ↗
└─ About (S-57)
Notification tap: hourly → Quote (S-60); we-miss-you → Shell; (morning → "On Awakening", night → "When We Retire" only if A-18)
```

---

## 5. Screen-by-screen requirements

Every screen has light and dark variants, supports text scaling up to 200 % without clipping,
and has all four states where they apply: **loading**, **empty**, **error**, **success**.

### S-01 Splash
Native splash (logo on brand background, light and dark). Hands over as soon as the first frame
is ready; migration runs behind it (§9 of MIGRATION_PLAN). Error: if migration throws, the app
still starts and the error is reported to Crashlytics (no user data in the report).

### S-02 Onboarding (first run only)
1. **Welcome** — "Welcome to 12 Step Guide. A companion for working the Steps, written by a
   long-term sober member." 
2. **What's inside** — the steps and traditions, the Big Book and both editions' stories, 90+
   hours of recovery audio.
3. **Reminders** — explains the hourly consciousness reminder; buttons **Turn on reminders**
   (system permission prompt, then hourly 08:00–22:00 on) / **Not now**.
4. **Free, with ads** — "The app is free and ad-supported. Premium removes ads and lets you
   download audio." Buttons **Start** / **See Premium** (opens paywall, then returns).

Skip on every page. Page dots. Swipe and buttons both work. Shown once (`onboarding.done`).
**S-02a Consent** — the Google UMP form appears before the first ad request where required.
It is a Google-rendered form; the app shows a neutral background behind it.

### S-03 Welcome to the new 12 Step Guide (upgraders, once)
Full screen, warm and reassuring: "Welcome back — this is the new version of 12 Step Guide."
Then a checklist of what came across, showing only the lines that apply: "Your recovery date
(N days)", "Your reminders", "N downloaded tracks", "Your Premium / supporter status". Then
"What's new": dark mode, Traditions (iOS users) / audiobooks and reminders (Android users).
One button: **Continue**.

### S-04 Shell
Tabs (§3.1), mini-player (§3.3), drawer (§3.4). Remembers the last tab across launches. Android
back from a tab root goes to Steps, then exits. Each tab keeps its own back stack.

### S-10 Steps
- Segmented control **Steps | Traditions** (remembers the choice).
- **Steps list:** Introduction ("How to use this guide"), Step 1–12 (number badge, "Step n",
  the step's wording as a two-line subtitle), Conclusion **[A-07]**.
- **Traditions list:** Tradition 1–12 with the short-form tradition text as a subtitle.
- Tap → (ad rule) → Reader.
- States: always populated (bundled). If a content file fails to parse at build time the build
  fails, so there is no runtime empty state.

### S-11 Reader
- App bar: back, title (collapses on scroll), **Aa** (S-12).
- Body: rendered natively from the Markdown source (D-003): headings, paragraphs, emphasis,
  lists, tables, block quotes; printed page numbers shown as a discreet page indicator.
  Comfortable measure (max ~70 characters per line on tablets), paper surface colour.
- Links: external → in-app browser tab; `mailto:` → mail app; in-document anchors → scroll;
  store links → store.
- Remembers the scroll position per document **[A-19]**.
- Banner ad pinned under the content for free users with "Remove ads" text link beside it.
- Prev / Next document buttons at the end of each document, same collection **[A-19]**.
- States: loading (skeleton lines for < 300 ms content parse); error ("This reading couldn't be
  opened" + Back) only if an asset is missing.
- Accessibility: headings exposed as headings; text selectable; respects system text size on
  top of the in-app size.

### S-12 Appearance sheet ("Aa")
Bottom sheet: text size slider (8 steps; default = step 3, 18 pt), live preview line, theme
Light / Dark / System (shared with S-53), reading font Sans / Serif **[A-19]**. Changes apply
instantly and persist.

### S-20 Readings
1. **Your recovery** card: if a date is set → "N days" (large), "Sober since 1 November 2012",
   tap the number → cheer sound (F-053). If not set → "Set your recovery date" button.
2. **Daily Reflections ↗** — "Opens the official aa.org page".
3. **Prayers** — Serenity Prayer, Serenity Prayer (Extended), Third Step, Seventh Step,
   Eleventh Step, The Lord's Prayer.
4. **Readings** — How It Works, The Twelve Traditions, The Promises, The Preamble, Just for
   Today, On Awakening, When We Retire, A Vision for You **[D-005 naming]**.
5. **Sobriety tips** — How to use the Big Book, How to find a sponsor, Sobriety & recovery,
   12 years on.
Section headers are real headings for screen readers.

### S-21 Recovery date
- Shows the date, total days, and "X years, Y months, Z days".
- **Change date** → system date picker (no future dates). **Clear date** → confirm dialog.
- Footer link: "Get Sober Today for detailed stats" → store page.
- Edge cases: date today → "Day 1" wording (0 days shown as "Today"); time-zone travel and DST
  never change the count (calendar-date arithmetic); leap days handled.

### S-30 Big Book
- Segmented control: **Big Book · Stories, 1st ed. · Stories, 2nd ed.** (full labels on wide
  screens, short ones on narrow, as iOS does today). Swipe between segments.
- Grid of cards: `#n`, title, page range (hidden when unknown). The colour accent sweeps across
  the collection, echoing the old gradient borders, from tokens.
- "Continue reading: Chapter 5 – How It Works" chip at the top when there is a saved position.

### S-40 Audio
- List of 11 albums: artwork tile (gradient from the album palette + short name), title, track
  count, total length, "Downloaded n/N" badge, now-playing equaliser on the current album.
- Offline: banner "You're offline — downloaded tracks still play" and non-downloaded albums dim
  but stay tappable.

### S-41 Album
- Header: artwork, title, track count, duration; buttons **Play all**, **Download all**
  (Premium; free users see the lock and the paywall), **Remove downloads** (when any are
  downloaded).
- Track rows: number (or equaliser if playing), title, duration, download control
  (download ⬇ / queued ◔ / progress ring / downloaded ✓ / failed ⟳).
- Tap row → (ad rule) → starts playback and opens the full player.
- States: offline and not downloaded → snackbar "Connect to the internet to play this track";
  server unreachable → "Couldn't reach the audio server. Try again." with Retry.

### S-42 Full player
- Drag-down sheet. Artwork or transcript area; title "n. Track title", album.
- Transcript (Joe & Charlie, Big Book albums): scrollable text with Aa size control.
- Controls: scrubber with elapsed/remaining, ⟲10, previous, play/pause, next, 10⟳.
- Buffering spinner on the play button; after 3 s: "Buffering — slow connection".
- Banner for free users under the controls (never over them).
- Lock screen / notification shade: title, album, artwork, play/pause, ±10 s, previous/next.
- End of album loops to track 1 (existing behaviour). Previous on track 1 goes to the last
  track (fixes BUG-05).
- Resume position per track is remembered **[A-20]**.

### S-43 Mini-player — see §3.3.

### S-50 Drawer — see §3.4.

### S-51 Premium
- **Free user:** benefits list (no ads, download any of the 138 tracks for offline listening,
  support future free apps), price from the store, **Start free trial** (iOS, when the trial is
  available) or **Subscribe** / **Support the app** (Android tiers), **Restore purchases**, Terms
  and Privacy links. Legacy supporters who also subscribe see the existing "You have also
  supported us in the past…" note.
- **Premium user:** status ("Annual · renews 3 March 2027" / "Lifetime supporter"),
  **Manage subscription** (opens the store's subscription page), Restore purchases.
- States: loading prices (shimmer); store unavailable ("Purchases aren't available right now.
  Try again later."); purchase pending (Android "pending" state banner); success
  ("Premium unlocked"); cancelled (no message); error (store message + Retry).

### S-52 Reminders
- **Hourly consciousness reminder** switch; From / Until time pickers (whole hours, plus the
  minute of "From", as today); summary "15 reminders a day".
- **On awakening** and **Night review** (switch + time each) — only if A-18 approves; they exist
  in the iOS code today but no user can reach them.
- **We miss you** switch (3- and 7-day nudges) **[A-13]**.
- If notification permission is denied: inline warning card with **Open settings**.
- Android 13+: first switch-on asks for permission; if refused, the switch returns to off.
- Saving reschedules immediately; summary text updates.

### S-53 Appearance
Theme (System / Light / Dark), reading text size (same slider as S-12), reading font
**[A-19]**, preview card.

### S-54 Downloads
Total storage used, list by album with sizes, **Remove** per album, **Remove all** (confirm),
"Download over Wi-Fi only" switch (default on) **[A-20]**. Free users with leftover downloads (lapsed
Premium) see the A-05 explanation.

### S-55 Help & support
**[A-14]** Contact us (recommended: email composer to the support address with app version,
platform and OS pre-filled; fallback "Copy email address"). Also: Rate the app (store page),
Tell a friend (share sheet with both store links), Follow us on Facebook.

### S-56 Our other apps
Cards for the platform's list (iOS: 12 Step Toolkit, Speaker Tapes, Sober Today, The Big Book,
Joe & Charlie; Android: AA Big Book reader, Joe & Charlie Free, Sober Today, 12 Step Toolkit,
Meeting Finder **[Q-P4]**), plus "More from iByte Apps". Opens the store; never an ad.

### S-57 About
App name, version and build, "12 Step Guide is not affiliated with or endorsed by Alcoholics
Anonymous or A.A. World Services, Inc." (from the store description), credits, open-source
licences (Flutter `LicensePage`).

### S-59 Privacy & ad choices
Opens the UMP privacy-options form. Only listed when UMP reports it is required.

### S-60 Quote of the hour
Opened from the hourly notification. Calm full-screen card on the brand gradient: the quote
(random from the 61) and **Close**, as today; **Another** and **Share** only if A-20 approves.
Banner for free users at the bottom.
Works from a cold start (the notification payload routes here after splash/migration).

---

## 6. Unified user journeys

| # | Journey | Steps | Success state |
|---|---|---|---|
| UJ-1 | New user, first launch | Splash → consent (if required) → onboarding (reminders opt-in) → Steps | Steps list; no ad yet |
| UJ-2 | Upgrading iOS user | Splash (migration) → Welcome back (date n/a, reminders, downloads, Premium) → last tab (Steps) | Their reminders still fire, downloads still play, Premium intact |
| UJ-3 | Upgrading Android user | Splash (migration) → Welcome back (recovery date, supporter status, what's new: audio, reminders, dark mode) → Steps | Recovery date and ad-free status intact |
| UJ-4 | Read a step | Steps → Step 4 → (ad rule) → Reader → Aa → larger text | Text larger everywhere afterwards |
| UJ-5 | Read the Big Book | Big Book → Stories 2nd ed. → story → Reader → back → "Continue reading" chip | Resumes at the saved position |
| UJ-6 | Set recovery date | Readings → Set recovery date → pick → Readings card shows days | Day count correct in any time zone |
| UJ-7 | Listen | Audio → album → track → player → lock phone | Playback continues; lock-screen controls work |
| UJ-8 | Download (free user) | Album → ⬇ → paywall → subscribe/support → download starts automatically | Track ✓; plays in airplane mode |
| UJ-9 | Hourly reminder | Reminders → on → 08:00–22:00 → notification at 09:00 → tap → Quote of the hour | Quote shown, even from a cold start |
| UJ-10 | Restore | New phone → Drawer → Premium → Restore | Premium active (iOS always; Android see A-04) |
| UJ-11 | Contact | Drawer → Contact us → mail composer with diagnostics | Email ready to send |
| UJ-12 | Change theme | Drawer → Appearance → Dark | Whole app, reader and player switch |

---

## 7. Reminder rules
- Times use the device's current time zone. "08:00" stays 08:00 after travel and across DST.
- Hourly: one notification per hour from the start hour to the end hour inclusive, at the start
  minute. If end < start, the range wraps past midnight (iOS today would crash on that; the new
  app accepts it). Maximum 24 a day.
- Android: inexact alarms (no exact-alarm permission). Delivery may be a few minutes late;
  documented in Reminders ("Android may deliver these a few minutes late to save battery").
- iOS limit of 64 pending requests: the schedule uses repeating daily triggers (≤ 24 + 2 + 2).
- Notification channels on Android: `reminders_hourly`, `reminders_daily`, `nudges`, `playback`.
- Content: titles and bodies as today ("Hourly Consciousness Reminder" / "Tap to reveal this
  hour's quote"; "We miss you" / "It's been 3 days since you used the app"; and, if A-18,
  "Time for your morning inventory" / "Time for your night inventory"). The apostrophe typo
  "This Hours'" is fixed. "We miss you" fires at 10:00 local time, not at midnight as today.

---

## 8. Global edge cases and state handling

| Situation | Behaviour |
|---|---|
| No network | Literature unaffected. Audio: offline banner; downloaded tracks play; streaming shows "You're offline". Daily Reflections/links: "You're offline" snackbar. Ads silently absent. Paywall: "Connect to the internet to see prices" |
| Slow network | Buffering indicator; downloads continue in background and resume after restarts |
| Audio server down / 404 | Track row shows "Unavailable — try again later"; Crashlytics non-fatal with the album/track id (no user data) |
| Storage full during download | Download fails with "Not enough storage"; partial file removed |
| App killed during download | Background downloader resumes or marks failed; never shows ✓ for a partial file (size check) |
| Purchase pending (Android) | "Payment pending" banner on Premium page; entitlement not granted until completed |
| Purchase refunded/revoked | Entitlement removed at next check; downloads stay on disk but follow the A-05 rule |
| Subscription in billing grace | Premium kept (StoreKit 2 / Play state) |
| Consent not given (UK/EEA) | Non-personalised or no ads per UMP; content fully usable |
| Notification permission denied | Reminder switches show the warning card; nothing scheduled |
| Time zone or DST change | Reminders re-armed on app resume and on time-zone change; day count unaffected |
| Date set in the future (clock wrong) | Picker forbids future; if device clock moves backwards, show "0 days" not negative |
| Very large text size | Layouts reflow; grids drop to one column; no clipped buttons |
| Tablet / landscape | Navigation rail; list + reader side by side in Steps, Readings, Big Book |
| Migration failure | App opens normally; each failed migration step is retried next launch; never deletes legacy data |
| Ad fails to load | Content opens immediately (no waiting on ads) |

---

## 9. Not in 2.0 (recorded so nobody adds them by accident)
Accounts, sync, search **[A-20]**, playback speed and sleep timer **[A-20]**, favourites
(F-069, never worked), sponsorship features, community, in-app chat, server-driven content.
