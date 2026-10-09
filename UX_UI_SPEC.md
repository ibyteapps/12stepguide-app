# 12 Step Guide — UX and UI Specification

The design system and interaction rules for the unified app. Every value here becomes a token in
`lib/design/` (`FLUTTER_ARCHITECTURE.md` §7); no screen may use a raw colour, size or duration.

---

## 1. Design direction

**Identity to keep.** The Android icon's navy book and the iOS app's bright, friendly blues; the
coral (`#F06C64`) both apps already use as the highlight; the card grid of the Big Book; numbered
step badges; the album gradients. Users should recognise the app at a glance.

**What changes.** Flat grey section bars and the 2016 list styling go. In their place: calm
surfaces, a warm paper tone for reading, clear type hierarchy, generous touch targets, proper
dark mode, and one consistent set of components on both platforms.

**Tone.** Quiet, warm, unhurried. This is a recovery app people open at difficult moments, so
there is no gamified pressure, no red badges and no countdowns. The sobriety day count is
celebrated, never streak-shamed.

---

## 2. Mobbin research — what influenced what

Patterns were used as evidence, not templates. Links open on Mobbin.

| Area | References | What we took | What we left |
|---|---|---|---|
| Drawer | [Wispr Flow](https://mobbin.com/screens/0518cf7e-c385-463c-b2bb-87b38788ae5f), [Monese](https://mobbin.com/screens/c6344a87-e145-4c60-86d4-78567fbb42ef), [Digg](https://mobbin.com/screens/5894fb1e-fd26-4325-97d7-4f750f143703), [Spotify](https://mobbin.com/screens/5867a8ca-fcc6-4749-b59e-ceccfa7493ff), [X](https://mobbin.com/screens/0c5b88b9-72cf-48ac-a4b2-6cc87b8b16cb) | Plan/status chip in the header (Wispr Flow's trial meter, Spotify's "Your Premium"); grouped items with dividers; legal links and app version in a quiet footer (Digg, Monese) | Profile avatars and social items — the app has no accounts |
| Reader appearance | [Apple Books](https://mobbin.com/screens/319ca8b6-3832-4a24-8daa-c71a1e468809), [Fable](https://mobbin.com/screens/2701e6f4-d7f5-40a0-82ef-50e4b7c37163), [Speechify](https://mobbin.com/screens/ca505ee0-0012-40b1-993b-075db533807d), [Matter](https://mobbin.com/screens/c9f61846-1003-48cf-acc9-df7c8c970ddc) | A bottom sheet opened from "Aa", holding text size (slider with small/large "A" ends), Light/Dark and a font choice in one place | Brightness sliders, page-curl and spacing/width controls — more options than the content needs |
| Audio player with transcript | [Brink](https://mobbin.com/screens/0c68aed6-765a-4380-a4ff-a88ef011ce6c), [ElevenReader](https://mobbin.com/screens/5c627524-cd63-4845-885a-77c7dace046c), [Blinkist](https://mobbin.com/screens/ea3a5a5a-2509-4c4e-b35e-69955e2349e4), [Spotify](https://mobbin.com/screens/45151021-58d3-42e8-9fc4-472608aef784) | Transcript fills the sheet with controls pinned below; large central play button flanked by skip buttons; elapsed/remaining under the scrubber; drag-down to dismiss to a mini-player (Blinkist) | Live word highlighting, AI chips, speed and sleep timer (A-20) |
| Track lists and downloads | [Spotify for Creators](https://mobbin.com/screens/94679e20-a0b8-4cc1-a4ed-320a624b62aa), [Brink downloads](https://mobbin.com/screens/82cad76c-9e62-4ef5-afe9-78ed0a524f6e), [Prime Video](https://mobbin.com/screens/4c30a68a-62ed-496a-97d2-7043021ff05c), [YouTube Music](https://mobbin.com/screens/cb4515c7-3fc4-4bd1-9cf3-3b2553b80c74) | Per-row download icon that turns into a progress ring and then a tick; visible "Play all" / "Download all" buttons instead of a hidden ⋯ menu; mini-player above the tab bar | Thumbnails per track (we have one artwork per album) |
| Home / continue | [Apple Books](https://mobbin.com/screens/fa54930d-72ec-44e1-b65d-f8b50aa6e173), [Blinkist](https://mobbin.com/screens/4d302c37-5af6-473a-b05d-e66fec6c0bbd) | "Continue" card at the top of the reading area | Recommendation carousels |
| Day counter | [QUITTR](https://mobbin.com/screens/555392f2-a9cd-44e0-b449-29645fe2d4e9), [Paired](https://mobbin.com/screens/a2faf5bf-cea6-470a-b558-5928fc0f63a5), [Numo](https://mobbin.com/screens/cae1eb96-5ca5-4496-9dc4-9aa305c289ef) | One large number as the hero, with the date under it; a years/months/days breakdown as quiet secondary boxes (Paired) | Streak flames, panic buttons and progress meters — wrong tone for this app |
| Paywall | [Pillow](https://mobbin.com/screens/73a2cafa-d97e-477b-9e00-1e276ef50151), [Jomo](https://mobbin.com/screens/355c903b-4580-4f82-bd8f-0c46195fa434), [Fixtured](https://mobbin.com/screens/0576cc85-bcfb-48ce-9115-cc4fbd774e02), [Liven](https://mobbin.com/screens/a612cffd-939d-471f-9b89-bf734058ab1a) | A trial timeline ("Today – full access · Day 5 – reminder · Day 7 – billing starts") (Pillow); honest "Cancel anytime"; Restore and Terms/Privacy always visible; close visible from the first frame | Fake discounts, review carousels, pre-selected toggles |
| Notification priming | [Turo](https://mobbin.com/flows/468fe59a-69ba-4e7f-a8fb-8c0ddc48bf71), [HelloFresh](https://mobbin.com/flows/b8c24066-cf86-473e-b353-519ffa22782f), [lululemon](https://mobbin.com/flows/68559489-94dd-47cd-b157-c17687bef70f) | A full onboarding page that explains *what* you'll get (with a sample notification), primary "Turn on reminders", secondary "Not now", before the system prompt | Marketing-offer framing |
| Reminder settings | [Babbel](https://mobbin.com/screens/3024f266-b88a-45e5-b95e-4774d782340a), [Me+](https://mobbin.com/screens/b56e6e4d-9fd4-4678-b945-82be56543aad), [CapWords](https://mobbin.com/screens/2a326162-3e73-4ab1-b47d-079d2dec227a), [Whering](https://mobbin.com/screens/66b9525c-a872-43c6-9870-ed12133c9af2) | Switch first, time revealed under it only when on; the system wheel/time picker in a sheet; a one-line summary of what will happen | Day-of-week selectors (reminders are daily, as today) |
| Offline/error | [Qantas](https://mobbin.com/screens/18f77caf-19d5-4199-98b4-a36f34096d23), [GoPay](https://mobbin.com/screens/95483b32-a4d7-4025-b6e7-64220245eff5), [Zomato](https://mobbin.com/screens/75f456ee-9a20-476e-9ff6-ba091ff27adb) | Icon + one plain sentence + one action ("Try again"); a transient snackbar for background failures | Illustrations heavy enough to need new artwork |

---

## 3. Colour tokens

Semantic roles, not colour names. All pairs used for text were checked against WCAG 2.2
(script in `tool/contrast_check.py`, which becomes a unit test).

### 3.1 Brand anchors
| Anchor | Hex | From |
|---|---|---|
| Book navy | `#1E2134` | Android icon cover |
| Guide blue | `#2451C7` | iOS tint `#265BD5`, deepened for AA contrast |
| Sky | `#80EEFF` | iOS icon background (decorative only) |
| Coral | `#E5534B` | Both apps' `#F06C64`, deepened for UI contrast |
| Paper | `#FBF8F1` | Book pages in the icon |

### 3.1.1 App icon (D-007)
The navy book of the old Android icon, with three paper-white steps on its cover and a coral
bookmark, on the sky-to-guide-blue gradient of the old iOS icon. No text and no A.A. symbol
(D-005). It is drawn once in `tool/build_icons.py`, which writes the SVG masters, the store
icons and every platform image; `assets/branding/preview.png` shows all variants.

| Variant | Where | Look |
|---|---|---|
| Light | iOS, App Store, Google Play | Navy book on sky → guide blue |
| Dark | iOS dark mode | Guide-blue book on the system's dark background |
| Tinted | iOS tinted mode | Greyscale; the system tints it |
| Adaptive | Android 8+ | Book as the foreground layer, inside the 66 dp safe circle; gradient background layer |
| Themed | Android 13+ | Monochrome book with the steps cut out |
| Classic | Android 7 | Rounded square and round versions of the adaptive icon |
| dev / staging | Test builds only | Same book on amber → coral (dev) or mint → teal (staging) |

### 3.2 Roles

| Token | Light | Dark | Used for |
|---|---|---|---|
| `bg` | `#F6F7FB` | `#0E1017` | Scaffold background |
| `surface` | `#FFFFFF` | `#161923` | Cards, sheets, lists |
| `surfaceAlt` | `#EEF1F7` | `#1F2330` | Grouped list backgrounds, segmented control track |
| `surfaceReader` | `#FBF8F1` (paper) | `#14161C` | Reader and transcript body |
| `surfaceBrand` | `#1E2134` | `#1E2134` | Recovery card, quote screen, splash |
| `onSurfaceBrand` | `#FFFFFF` | `#FFFFFF` | Text on brand surfaces (15.9 : 1) |
| `textPrimary` | `#161A26` | `#ECEEF4` | Body text, titles |
| `textSecondary` | `#4A5163` | `#B6BCCB` | Subtitles, step wording |
| `textTertiary` | `#626A7D` | `#959CAE` | Captions, page ranges, timestamps |
| `textDisabled` | `#9AA1B2` | `#5F6678` | Disabled labels (exempt from contrast rules; never the only cue) |
| `primary` | `#2451C7` | `#93B1FF` | Buttons, links, selected states |
| `onPrimary` | `#FFFFFF` | `#0A1A4A` | Text/icons on primary |
| `primaryContainer` | `#E2E9FB` | `#22356E` | Selected nav pill, chips, tonal buttons |
| `onPrimaryContainer` | `#0F2462` | `#DCE5FF` | Text on the above |
| `secondary` | `#0B7285` | `#6FD6E8` | Secondary accents (audio, download progress) |
| `highlight` | `#E5534B` | `#FF8A80` | Now-playing equaliser, day-count emphasis (non-text or large text only in light) |
| `highlightText` | `#B42318` | `#FF9E95` | When coral must be small text |
| `success` | `#1E7A46` | `#6FD39B` | Downloaded ✓, "Premium unlocked" |
| `warning` | `#8A5A00` | `#F2C46D` | Offline banner, permission warning |
| `error` | `#B3261E` | `#FF8A80` | Errors, destructive actions |
| `outline` | `#8E95A6` | `#6B7285` | Input borders, focus rings (≥ 3 : 1) |
| `divider` | `#E2E5EC` | `#2A2F3D` | Hairlines (decorative) |
| `scrim` | `#000000` @ 40 % | `#000000` @ 60 % | Behind drawer, sheets, dialogs |
| `navSurface` | `#FFFFFF` | `#161923` | Bottom bar / rail |
| `navIndicator` | `#E2E9FB` | `#22356E` | Selected pill |
| `navSelected` | `#0F2462` | `#DCE5FF` | Selected icon + label |
| `navUnselected` | `#626A7D` | `#959CAE` | Unselected icon + label (5.4 / 6.4 : 1) |
| `cardStroke(i,n)` | interpolation `#2451C7 → #0B7285 → #E5534B` | dark equivalents | Big Book card borders (replaces the old rgb sweep) |
| `albumGradient[1..11]` | the 11 legacy album gradients | same | Album artwork; text sits on a 45 % black bottom scrim (all 11 pass 3 : 1 for the large bold short name) |

### 3.3 Measured contrast (text pairs)

| Pair | Light | Dark |
|---|---|---|
| textPrimary on bg / surface / reader | 16.2 / 17.4 / 16.4 | 16.4 / 15.1 / 15.6 |
| textSecondary on surface / reader | 7.9 / 7.5 | 9.2 / 9.5 |
| textTertiary on surface / bg | 5.4 / 5.1 | 6.4 / 6.9 |
| primary on surface / bg / surfaceAlt | 6.8 / 6.4 / 6.0 | 8.3 / 9.0 / 7.4 |
| onPrimary on primary | 6.8 | 7.9 |
| onPrimaryContainer on primaryContainer | 11.9 | 9.3 |
| secondary on surface | 5.6 | 10.4 |
| highlightText on surface | 6.6 | 8.8 |
| success / warning / error on surface | 5.4 / 5.9 / 6.5 | 9.6 / 10.8 / 7.7 |
| outline on surface (non-text, needs 3 : 1) | 3.0 | 3.7 |

Every text pair meets AA (4.5 : 1); most meet AAA (7 : 1).

---

## 4. Typography

UI uses the platform system font (SF Pro on iOS, Roboto on Android), as both apps do today, so
the app still feels native and Dynamic Type works with no font files. Reading text defaults to
the same sans; a serif option (Source Serif 4, OFL, bundled ~400 KB) is offered only if A-19
approves.

| Token | Size / line height (sp) | Weight | Use |
|---|---|---|---|
| `display` | 48 / 52 | 700 | Day count on the recovery card |
| `headline` | 28 / 34 | 700 | Screen titles (large) |
| `title` | 20 / 26 | 600 | App bar titles, section titles in reader |
| `titleSmall` | 17 / 22 | 600 | List titles, card titles |
| `body` | 16 / 24 | 400 | UI body |
| `bodySmall` | 14 / 20 | 400 | Subtitles (step wording), captions |
| `label` | 13 / 16 | 600 | Buttons, chips, tab labels (12 on the tab bar) |
| `overline` | 12 / 16 | 600, +0.6 tracking, caps | Section headers in lists ("PRAYERS") |
| `reader` | **18** / 28 default (8 steps: 15, 16.5, **18**, 20, 22, 24, 27, 30) | 400 | Literature body |
| `readerHeading` | reader × 1.35 | 700 | Chapter headings |

The steps cover both old scales. iOS Small / Medium / Large (18 / 24 / 30 px) map to steps
3 / 6 / 8. Android Normal / Larger / Largest (100 / 130 / 160 % of the same 18 px base ≈ 18 / 23.4 /
28.8) map to the nearest steps, which are also 3 / 6 / 8, so both audiences keep the size they
chose. `MIGRATION_PLAN.md` §4 has the table. Text scaling from the OS multiplies on top, capped at
2.0× for UI chrome; reader text is uncapped.

---

## 5. Spacing, radius, elevation, motion

- **Spacing scale (dp):** 2, 4, 8, 12, 16, 20, 24, 32, 40, 48. Screen gutters 16 (phone) /
  24 (tablet). List row min height 56; touch targets ≥ 48 × 48.
- **Radius:** `sm` 8 (chips, inputs), `md` 12 (cards, tiles), `lg` 20 (sheets, paywall card),
  `pill` 999 (segmented control, nav indicator, primary buttons).
- **Elevation:** light mode uses shadow + surface; dark mode uses lighter surfaces instead of
  shadow.
  `e0` none · `e1` cards: y1 blur3 @ 8 % · `e2` mini-player, app bar on scroll: y2 blur8 @ 10 % ·
  `e3` sheets, drawer, dialogs: y8 blur24 @ 16 %. Dark: `surface`, `surfaceAlt`, `#252A38` for
  e1–e3.
- **Motion:** `fast` 120 ms (press states), `medium` 220 ms (sheets, segment changes), `slow`
  320 ms (player expand). Curves: standard `easeOutCubic`, emphasised `easeInOutCubicEmphasized`.
  All motion respects "Reduce motion": cross-fades replace slides and the equaliser stops
  animating.

---

## 6. Components

| Component | Spec |
|---|---|
| **App bar** | Large title on tab roots (collapses on scroll, iOS-style); standard on detail. ☰ leading on roots. Background `bg`, divider appears on scroll |
| **Bottom navigation** | 4 items, label always shown, `navIndicator` pill behind the selected icon, 80 dp tall + safe area. Tablet: `NavigationRail` with the same items and the ☰ at the top |
| **Drawer** | 304 dp wide (max 85 % of the screen); header with icon, app name and a Premium status chip; grouped list tiles 56 dp; footer About/version. `e3`, `scrim` |
| **Segmented control** | Pill track `surfaceAlt`, selected thumb `surface` + `e1`, label `titleSmall`; swipe-linked to its pages |
| **List row** | Leading badge (40 dp), title + up to 2 lines of subtitle, trailing chevron or state icon; 56–72 dp; whole row is the target |
| **Step badge** | 40 dp rounded square, `primaryContainer` with number in `onPrimaryContainer`; "Intro" and "End" variants with icons. Replaces both apps' number PNGs and the AA symbol |
| **Content card (Big Book)** | `surface`, radius `md`, 1.5 dp `cardStroke`, `#n` overline, title (3 lines max), page range caption |
| **Recovery card** | `surfaceBrand`, radius `lg`, `display` day count, date line, "Change" text button; empty state = "Set your recovery date" tonal button |
| **Album tile** | Square, radius `md`, album gradient, 45 % bottom scrim, short name in `onSurfaceBrand` bold; equaliser overlay when playing |
| **Track row** | Number / equaliser, title, duration, trailing download control (48 dp target): ⬇ → ◔ queued → ring with % → ✓ → ⟳ failed |
| **Mini-player** | 64 dp, `surface` + `e2`, artwork 40 dp, title/album, play/pause 48 dp, 2 dp progress line in `secondary` |
| **Full player** | Sheet with grabber; transcript or artwork; scrubber; 72 dp play button (`primary`), 48 dp skip/prev/next |
| **Buttons** | Filled (primary), Tonal (primaryContainer), Outlined, Text. Height 48, radius pill, `label` text. Destructive = Filled with `error` |
| **Banner ad slot** | Reserved height (adaptive banner height) so content never jumps; "Remove ads" text button beside or under it |
| **Dialogs** | Platform-adaptive (`AlertDialog.adaptive`): Cupertino on iOS, Material on Android. Title, one sentence, max two actions |
| **Bottom sheets** | Radius `lg` top, grabber, `e3`; used for Aa, time pickers, confirmations with context |
| **Snackbars** | Floating, above the mini-player; one line + optional action; 4 s |
| **Inline banners** | Offline (`warning`), permission denied (`warning`), purchase pending (`primaryContainer`) |
| **Empty / error state** | Icon (48 dp), one sentence (`body`), one action (Text or Tonal button) |
| **Loading** | Skeleton blocks for lists and cards; spinner only inside buttons and the play button |
| **Switch rows** | Platform-adaptive switch; time rows revealed under an enabled switch |
| **Time picker** | iOS: Cupertino wheel in a sheet. Android: Material time picker dialog |
| **Paywall** | Header (icon + "12 Step Guide Premium"), benefit rows with icons, trial timeline (iOS trial only), price line from the store, primary CTA, "Restore", "Terms · Privacy", visible close |

**Icons.** Material Symbols Rounded (variable font; one weight, 24 dp, optical size 24) on both
platforms for a consistent identity. The AA circle-triangle symbol is not used (D-005).

---

## 7. Light and dark themes

- Theme modes: **System** (default), Light, Dark. Stored in `appearance.theme`.
- Every component above reads tokens through `Theme.of(context).extension<AppColors>()`, so
  there is no hard-coded colour in a widget. A test scans `lib/` for `Color(0x` outside
  `lib/design/tokens/`.
- Native surfaces follow too: splash (light and dark), Android system bars (edge-to-edge,
  icon brightness from the theme), iOS status bar, notification accent colour, the player's
  media notification.
- Album artwork and the brand card look the same in both modes; only the surrounding surfaces
  change.
- **Golden tests** render every screen in light and dark at 1.0× and 2.0× text scale on a phone
  and a tablet size (`FLUTTER_ARCHITECTURE.md` §12).

---

## 8. Layout and responsiveness

| Width class | Navigation | Layout |
|---|---|---|
| Compact < 600 dp | Bottom bar | Single pane |
| Medium 600–839 dp | Navigation rail | Lists with 2–3 column grids; reader centred, max 680 dp |
| Expanded ≥ 840 dp | Navigation rail (expanded labels) | List + reader side by side in Steps, Readings and Big Book; Audio: albums + album detail |

Big Book grid columns: 2 compact, 3 medium, 4 expanded. Safe areas and display cut-outs are
respected; landscape phones keep the bottom bar.

---

## 9. Accessibility requirements (acceptance criteria per screen)

1. Text contrast ≥ 4.5 : 1 (≥ 3 : 1 for large text and UI boundaries) in both themes — tested.
2. Works at 200 % system text size: nothing clipped or overlapping; grids reflow.
3. Every interactive element has a semantic label; icon-only buttons have tooltips; download
   controls announce their state ("Downloaded", "Downloading 45 %").
4. Headings are marked as headings (screen readers can jump section to section in readings).
5. Focus order follows visual order; the drawer and sheets trap focus and return it on close.
6. Touch targets ≥ 48 × 48 dp.
7. No information by colour alone (download state uses icon + label; selected tab uses pill +
   weight).
8. Reduce Motion honoured; no auto-playing animation longer than 5 s without a pause.
9. Audio controls reachable from the lock screen and with VoiceOver/TalkBack.
10. Captions: transcripts exist for the Joe & Charlie and Big Book albums. Other speaker tapes
    have none (content limitation, noted in the album header).
11. Tested with VoiceOver and TalkBack on the five core journeys before release.

---

## 10. Content and microcopy

- Sentence case everywhere ("Set your recovery date", not "Tap To Set Recovery Date").
- Plain, kind wording; no blame ("Couldn't load this track. Try again." not "Error!").
- Titles follow the AAWS-compliant naming of iOS 1.21 on both platforms (D-005): no "AA" prefix
  in feature titles, "Daily Reflections", "The Big Book", "Speaker Tapes".
- Disclaimer in About and the store listings: "not affiliated with or endorsed by Alcoholics
  Anonymous or A.A. World Services, Inc."
- British English in UI copy (the company and the owner are in the UK). The literature keeps its
  original spelling.
