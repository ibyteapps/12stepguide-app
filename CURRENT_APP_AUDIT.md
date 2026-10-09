# 12 Step Guide — Current App Audit

Audit of the two shipping native apps that the unified Flutter app replaces.
Written 9 October 2026, before any Flutter code exists.

**How this was done.** It is a source-only audit, as agreed: every Swift, Java and Kotlin file
was read, along with storyboards, layouts, navigation graphs, manifests, plists, the bundled
SQLite database, the HTML content, the store listings and the changelogs. Neither app was run.
Where behaviour depends on runtime state, that is said, and the finding is marked
*(inferred from code)*.

**Sources**

| | iOS | Android |
|---|---|---|
| Folder | `Work/Apple/12StepGuideAA/workspace` | `Work/Android/12 Step Guide AA/workspace` (latest; build 29, 30 Sep 2025) |
| Older copies read for history | `archived/workspace_1.20.zip` (diffed to find the AAWS-compliance change) | `Work/Android/12StepGuideAA/workspace` (build 22, Nov 2022, superseded) |
| Store listing checked | App Store id 1238097883 | Google Play `com.ibyteapps.aa12stepguide` |

Feature IDs (`F-xxx`) refer to `FEATURE_MATRIX.md`. Defect IDs (`BUG-xx`) are listed in §15.

---

## 1. Identity and release facts

| | iOS | Android |
|---|---|---|
| Store name | **12 Steps Guide** — subtitle "12 Steps Working & Audiobooks" | **12 Step Guide - AA** |
| Name under the icon | `12 Step Guide` (`PRODUCT_NAME`) | `12 Step Guide - AA` (`app_name`) |
| Bundle id / applicationId | `com.ibyteapps.aa12stepguide` | `com.ibyteapps.aa12stepguide` |
| Xcode target / module | `AA12StepGuide`, source folder `AAToolbox` | package `com.ibyteapps.aa12stepguide` |
| Shipped version | Store **1.51** (16 Oct 2021). The project file says `MARKETING_VERSION = 1.21`, `CURRENT_PROJECT_VERSION = 1.21`, so the archive on disk and the store number do not agree (see §17) | versionName **0.2.9**, versionCode **29** (store updated 30 Sep 2025) |
| Minimum OS | iOS 12.1 (iPhone + iPad; also offered on Apple-silicon Macs and visionOS through the store) | minSdk 23 (Android 6.0) |
| Target | Swift 5 / 4.2 mix, CocoaPods 1.11 | compileSdk 34, **targetSdk 36**, AGP 8.x, Java 8 source level |
| Devices | Universal (iPhone + iPad), all four orientations | Phones and tablets (`values-large`, `values-xlarge`), all orientations |
| Store rating | 4.8 ★ (429 ratings) | 4.7 ★ (~4,000 reviews), 100k+ installs |
| Age rating | 13+ | Not recorded on the page |
| Developer account | iByte Apps Limited (seller shown as Tushar Bhagat) | iByte Apps Limited |
| Firebase project | `aa-12-step-guide` (same project on both) | `aa-12-step-guide` |
| Website | None of its own. Privacy and terms live on `12steptoolkit.com` | Same |

**Lineage.** The iOS code is a fork of the 12 Step Toolkit iOS codebase ("AAToolbox"). It still
carries Toolkit leftovers that are compiled but not used (§16). The Android app was written
separately, in Java, from a Google navigation sample.

---

## 2. Architecture as built

### 2.1 iOS
- UIKit with storyboards (`Main.storyboard`, `Player.storyboard`), a `UINavigationController`
  rooted at `FirstVC`, which pushes `TabControllerVC` (a `UITabBarController` with 5 tabs).
- Global functions and constants in a 2,000-line `_Constants.swift`. State lives in
  `UserDefaults` through `getFlag`, `getKeyDataInt` and `getKeyDataString`.
- An event bus (`SwiftEventBus`) is used for cross-screen messages: reload audio, reload
  settings, interstitial finished.
- GRDB opens a bundled SQLite catalogue (`main.db`) that is copied to Documents on first run.
- Pods: Firebase Core/Analytics + Crashlytics 8.1, Google-Mobile-Ads 8.6 (pulls in UMP 2.0, never
  called), SwiftyStoreKit 0.16 (StoreKit 1), GRDB 5.8, lottie-ios 3.2, SwiftEntryKit 1.2.3
  (toasts and dialogs), OnboardKit, NewPopMenu, MarqueeLabel and SwiftEventBus.
- No unit or UI tests beyond the Xcode templates.

### 2.2 Android
- Java with a little Kotlin. A single `MainActivity` hosts five navigation graphs behind a
  `BottomNavigationView` (Google's multi-back-stack sample `NavigationExtensions.kt`).
- Fragments: `AlbumsFragment` (used twice, for Steps and for Traditions), `HomeFragment` (the
  Readings tab), `LiteratureFragment` (Big Book), `SettingFragment`, `StoreFragment`,
  `CalculatorFragment` and `ShowHtmlFragment`.
- State lives in the default `SharedPreferences`, keyed by `"mKeyStepData" + key + "_aa12stepguide"`
  and by flags suffixed `"_aa12stepguide"` (§7.2).
- Singletons `AdsSingleton`, `BillingSingleton` and `AppOpenManager`, plus GreenRobot EventBus.
- Dependencies: Play Billing 7.1, Play Services Ads 23.3, Meta Audience Network 6.17, Firebase
  Analytics/Crashlytics/Messaging, Material Dialogs, SmartTabLayout, Flexbox, Paper Onboarding,
  XTooltip and WorkManager (declared, unused).
- Two instrumented tests, `DeepLinkTest.kt` and `BottomNavigationTest.kt`, both left over from the
  Google sample. They test nothing in this app.

---

## 3. Screen inventory

### 3.1 iOS (`S-I-xx`)

| ID | Screen | Class / scene | Reached from | Notes |
|---|---|---|---|---|
| S-I-01 | Launch screen | `LaunchScreen.storyboard` (launch image) | Cold start | |
| S-I-02 | First-run onboarding (6 pages) | `OnboardViewController` via `FirstVC` | Launch count = 1 | Welcome, Audiobooks ×2, Big Book, Ad-supported, All set. A "Notifications" page is defined in code but is not in the page list |
| S-I-03 | "App updated" onboarding (5 pages) | same | Upgrading install without `FLAG_ONBOARDING_UPDATE_SHOWN` | App updated, Big Book, Dark mode, Ad-supported, All set |
| S-I-04 | Tab bar shell | `TabControllerVC` | after `FirstVC` | Nav bar title follows the tab; crossfade between tabs; animated "now playing" icon (Lottie) at top right when a track is loaded, which opens the player |
| S-I-05 | **The Steps** (tab 1) | `ToolboxVC` | Tab | Introduction + Steps 1–12, number icons, step text as subtitle |
| S-I-06 | **Literature** (tab 2) | `AALiteratureVC` | Tab | Sections: Daily Reflections (external link), Prayers (6), Readings (8), "Please support us by downloading our other apps" (5 App Store links) |
| S-I-07 | **Big Book** (tab 3) | `LitVC` | Tab | Segmented control: Big Book (14) / Stories Edition 1 (29) / Stories Edition 2 (40). Card grid with `#n`, title and page range; swipe left/right changes segment; labels shorten on narrow screens |
| S-I-08 | **Audio Books** (tab 4) | `AudioBooksVC` | Tab | 11 albums, gradient tile, short name, track count, now-playing animation |
| S-I-09 | Album / tracks | `TracksVC` | Album row | Header tile with ⋯ menu (Download all / Delete all offline / Play all), numbered tracks, per-track download button and progress ring |
| S-I-10 | Player (modal) | `PlayerVC` (`Player.storyboard`) | Track tap, now-playing icon | Transcript web view for the 2 albums that have one; Lottie animation otherwise; play/pause, ±10 s, previous/next, scrubber, times, font size, banner advert |
| S-I-11 | **Settings** (tab 5) | `SettingsVC` | Tab | Subscription status, Restore purchases, Notifications, Rate, More apps, Facebook, Contact, Tell a friend, Privacy policy, Terms of use |
| S-I-12 | Notifications | `NotificationsVC` | Settings | Only the **hourly reminder** (switch, start and end time) is visible. Cells for an on-awakening reminder, a night-time reminder and two sponsorship switches exist but are `hidden="YES"` in the storyboard, and the Settings summary shows only the hourly line, so no user can turn them on |
| S-I-13 | Time picker sheet | `NibExampleView` in SwiftEntryKit | Notifications | Hours and minutes |
| S-I-14 | Hourly quote reveal (modal) | `ShowNotificationVC` | Tapping an hourly notification | Blue screen, random line from `quotes.txt` (61 lines), close, banner advert |
| S-I-15 | Subscribe paywall (modal) | `SubscribeVC` | Settings, download gates, auto at launch 2/20/50 | Gradient, bullet list, price, Continue, Terms, Privacy, Close |
| S-I-16 | Contact developers | `ContactVC` | Settings | Email field + message, Send (posts to the server), version footer |
| S-I-17 | Reader | `ShowHTMLVC` | Steps, Literature, Big Book | WKWebView, Aa font-size dialog (Small / Medium / Large = 18 / 24 / 30 px), banner advert, dark-mode text colour |
| S-I-18 | Font-size dialog | SwiftEntryKit alert | Reader, player | |
| S-I-19 | "Subscribe now" confirmation | SwiftEntryKit alert | Download tapped by a free user | "This feature is only available to subscribed users… free 7-days subscription" |
| S-I-20 | Cancel-subscription instructions | SwiftEntryKit popup | Subscription cell "Want to cancel?" | Text steps for iOS Settings |
| S-I-21 | Toasts / top notes | SwiftEntryKit | Throughout | "Premium unlocked", "Nothing to restore", "Buffering - Poor Internet Connection", errors |
| — | Store review prompt | `SKStoreReviewController` | Launch 7, 15, 30; Settings → Rate | System controlled; may not appear |

### 3.2 Android (`S-A-xx`)

| ID | Screen | Class | Reached from | Notes |
|---|---|---|---|---|
| S-A-01 | Branded launch | `First` (theme `BrandedLaunch`) | Cold start | Increments the launch count, then routes |
| S-A-02 | Onboarding (3 pages) | `OnBoardingActivity` (Paper Onboarding) | First run (`onBoardingShown` false and launch count < 2) | "Hey there!", "Support Us", "Ad-Supported" |
| S-A-03 | Main shell | `MainActivity` | | Bottom nav with 5 tabs, hidden on detail screens; light status bar |
| S-A-04 | **Steps** (tab 1) | `AlbumsFragment` section 0 | Tab | Header "12 Step Guide - AA Free" / "… Pro"; Introduction + Steps 1–12, AA symbol / number icons |
| S-A-05 | **Traditions** (tab 2) | `AlbumsFragment` section 1 | Tab | Traditions 1–12 with the full tradition as subtitle |
| S-A-06 | **Readings** (tab 3, the "home" list) | `HomeFragment` | Tab | YOUR RECOVERY (Sober for, Sober since), Daily Reflection link, PRAYERS (6), READINGS (8), SOBRIETY TIPS (4) |
| S-A-07 | Calculator | `CalculatorFragment` | Sober since / Sober for rows | Recovery date, "Recovering since", day count, Change recovery date (date picker, max today), one-time hint, Sober Today promotion |
| S-A-08 | **Big Book** (tab 4) | `LiteratureFragment` | Tab | SmartTabLayout tabs: Big Book (14) / Stories Edition 1 (29) / Stories Edition 2 (40); Flexbox card grid; list animates in |
| S-A-09 | Reader | `ShowHtmlFragment` | Steps, Traditions, Readings, Big Book | WebView of `file:///android_asset/…`, font-size dialog (Normal / Larger / Largest = 100 / 130 / 160 % zoom), first-time tooltip, AdMob banner |
| S-A-10 | **Settings** (tab 5) | `SettingFragment` | Tab | UPGRADE APP ("Remove All Ads – £x"), APP SETTINGS (Rate, More apps, Contact, Tell a friend, Privacy), MORE FREE APPS (5 Play links), app version |
| S-A-11 | In-App Purchases | `StoreFragment` | Settings → Remove all ads | Donate Tier 1/2/3 ("Donate & remove ads for life"), price or "Purchased", explanatory footer |
| S-A-12 | Rate dialog | `AlertDialog` in `MainActivity` | 20 s after launch on launch 5, 11, then every 10th after 20 (max 6 times) | "Please Rate This App" → Play Store |
| S-A-13 | Hint dialog | Material Dialog | Calculator date picker | "To scroll back multiple years, tap the year number…" with "Don't show again" |
| S-A-14 | Email chooser | system | Settings → Contact | to `ibyteappsuk@gmail.com`, subject "12 Step Guide - AA Support", body with version |
| S-A-15 | Share sheet | system | Settings → Tell a friend | |

---

## 4. User journeys as built

**J1 – First launch (iOS).** Ads SDK starts → the system notification prompt appears immediately
(`AppDelegate`) → onboarding sheet (6 pages) → The Steps tab. The paywall opens by itself on
launch 2, 20 and 50 for free users. A store-review request follows on launch 7, 15 and 30. Because
the launch counter is incremented twice on the very first launch (`AppDelegate` and `FirstVC`), the
"launch 2" paywall is attempted during the first launch while the onboarding sheet is still up
(it probably fails to present), and the later prompts fire one real launch early (BUG-21).

**J1 – First launch (Android).** Branded launch → 3-page onboarding → Steps tab. A custom rate
dialog appears on launch 5, 11, 30, 40 and so on. Notification permission is never requested.

**J2 – Read a step guide.** Steps tab → step → (interstitial: iOS on every 2nd content tap;
Android on every 3rd opening; both counters persist across launches — see BUG-09) → reader with a banner → font size.

**J3 – Read the Big Book.** Big Book tab → segment → card → (interstitial) → reader.

**J4 – Prayers and readings.** iOS: Literature tab. Android: Readings tab. Same documents, with
different titles and order (F-021, F-022).

**J5 – Sobriety date (Android only).** Readings tab → "Tap To Set Recovery Date" → calculator →
date picker → the Readings tab then shows "Sober for N days" and "Sober since <date>". Tapping
"Sober for" once a date is set plays a cheer sound.

**J6 – Listen (iOS only).** Audio Books → album → track → (interstitial on every 2nd content tap) → player
opens and streams from the server → auto-advances through the album and loops. Subscribers can
download a track or a whole album; a downloaded track plays offline only while the subscription is
active.

**J7 – Hourly reminder (iOS only).** Settings → Notifications → switch on, pick start/end →
notification each hour on the start minute, "Tap To Reveal This Hours' Quote" → quote screen.

**J8 – Upgrade.** iOS: paywall → annual subscription with a 7-day free trial → receipt checked
against Apple's `verifyReceipt` from the device. Android: Settings → Remove all ads → Store →
Donate Tier 1/2/3 (one-off, consumed) → no ads.

**J9 – Restore.** iOS: Settings → Restore purchases (old donation tiers become "Lifetime
Upgrade"; the annual subscription is revalidated). Android: no button. Entitlement is rebuilt
from Play purchase history every time the app resumes.

**J10 – Contact.** iOS: in-app form posts to the Toolkit server. Android: hands off to an email
app.

---

## 5. Feature inventory (summary)

`FEATURE_MATRIX.md` holds the full list, 92 rows. In short:

- **On both:** step guides (Intro + 12), prayers, readings, Daily Reflections link, Big Book
  chapters, Personal Stories eds. 1 & 2, reader with font size, banner/interstitial/app-open ads,
  in-app purchases that remove ads, rate, more apps, share, privacy policy, Firebase Analytics and
  Crashlytics, onboarding, tablet support.
- **iOS only:** audiobooks (11 albums, 138 tracks, about 94 hours), downloads for subscribers,
  player with transcripts, hourly consciousness reminders with quote reveal, "we miss you" nudges
  (fresh installs only), annual subscription with free trial, restore purchases,
  subscription status, in-app contact form, Terms of use, Facebook link, dark mode, upgrade
  onboarding.
- **Android only:** Traditions guides (12), sobriety date + calculator, Sobriety Tips (4
  articles), the corrected Bill's Story text (a paragraph on p. 15 that iOS is missing), the
  expanded 2024 step-guide text, Meta Audience Network fallback ads, video ads muted, first-time
  font tooltip, double-tap guard.
- **Hidden or unreachable:** a "Conclusion" chapter (`tape14` / `gtape14`) shipped on both and
  linked from neither; iOS morning and night reminders, implemented in code but with their cells
  hidden in the storyboard; a favourites button outlet and a `favourites` table on iOS that nothing
  uses; Android's struck-through "extra price" in the store, which never gets a value.

---

## 6. Content inventory

| Collection | iOS | Android | Difference |
|---|---|---|---|
| Step guides | `guide/gtape1–13` (+ `gtape14` Conclusion, unlinked) — original text, ~1–4 KB each | `guide/tape1–13` (+ `tape14`, unlinked) — **rewritten and expanded in 2024** ("Elaborated all guides using open.ai", build 27), ~7–12 KB each | Different text. The author's voice and length differ. Owner decision needed (Q-C1) |
| Tradition guides | — | `guide/tradition1–12` (~9–12 KB each) | Android only |
| Big Book chapters | `aa/tape1–14` | `aa/tape1–14` | Android `tape2` (Bill's Story) has a paragraph iOS lacks (the "missing paragraph p.15" fix). Others differ only by `background: transparent` |
| Stories ed. 1 | 29 | 29 | Same. Android's file list names a 30th file that does not exist |
| Stories ed. 2 | 40 | 40 | `stories2_27` differs by a closing tag only |
| Prayers | 6 | 6 | Titles differ ("Extended Version" vs "Plus", "3rd" vs "Third") |
| Readings | 8 | 8 | Order and titles differ ("On Retiring" vs "When We Retire"; "Chapter 5: How It Works"; "The Promises (9th Step)") |
| Sobriety tips | — | 4 (`x*.html`) | Android only |
| Audio transcripts | Joe & Charlie (34) + Big Book audio (14) | — | iOS only |
| Hourly quotes | `quotes.txt`, 61 lines with emoji | — | iOS only |
| Sounds | `sounds/notification_1–4.mp3` (unused) | `notification_4.mp3` (cheer on "Sober for") | |
| Unused HTML | `about`, `sample`, `singleness`, `yellowcard`, `whatsnew`, `bigbookmod`, `bigbookmod4th`, `step12`, `terms`, `privacy` | `about`, `sample`, `singleness`, `yellowcard`, `whatsnew` | Toolkit leftovers. Not reachable from any screen |

Two further findings from converting every document to Markdown (`content/README.md`):
Android's and iOS's "Chapter 10: To Employers" file also contains Chapter 11 and "Doctor
Bob's Nightmare", so both are duplicated. The Big Book "Preface" is the **fourth-edition (2001)**
preface, not first-edition text (see Q-L2).

The content links out to Facebook, the App Store and Play developer pages, `dhamma.org`,
`silkworth.net/bb/appendix.html` and `mailto:ibyteapps@gmail.com`, and uses in-page anchors
(`#chapter1` and so on) in the Big Book transcripts. iOS loads HTML with `baseURL: nil`, so
`styles.css` never resolves and a tapped link opens **inside** the reader with no way back
(BUG-12). Android hands links to the system browser.

**Naming and AAWS.** iOS 1.21's only changes were the "AAWS Complaint Compliance" changelog
entry and a set of renames: "AA Speaker Tapes" → "Speaker Tapes", "Big Book - Alcoholics
Anonymous" → "The Big Book", "AA Daily Reflections" → "Daily Reflections", "AA Big Book" →
"The Big Book", "Recovery Box - AA 12 Step Toolkit" → "12 Step Toolkit". The store name became
"12 Steps Guide". Android was never brought into line: it still uses "12 Step Guide - AA", "AA
Big Book Text", "AA Preamble", "AA 12 Traditions" and the AA circle-and-triangle symbol as a list
icon. iOS 1.21 was itself only partly cleaned: the Big Book segment is still labelled "AA Big
Book", album 2's short name is "AA Big Book", onboarding says "AA Big Book", the Literature
header reads "Alcoholics Anonymous Literature" with "Opens Official AA Website", the share text
says "AA 12 Step Guide", and the symbol (`ic_sobersince`) sits beside "Introduction". What the complaint
actually required is unknown (Q-L1).

---

## 7. Local data and storage keys

Nothing is synced. There are no accounts and no server-side user data. Everything a user has is
on the device.

### 7.1 iOS — `NSUserDefaults` (standard domain, no prefix)

| Key | Type | Meaning |
|---|---|---|
| `launchcount` | Int | Launch counter (an older key `launchCount` is migrated and then set to −1). Incremented twice on a fresh install's first launch, so it reads real launches + 1 (BUG-21) |
| `KEY_DATA_INT_TAP_COUNT` | Int | Content-tap counter; an interstitial shows on even values. The launch-time reset writes `tapcount` instead, so it never resets (BUG-09) |
| `KEY_DATA_INT_FONT_SIZE` | Int | Reader font px: 18 / 24 / 30 (0 → 18) |
| `KEY_DATA_INT_CURRENT_ALBUM`, `…_CURRENT_TRACK`, `…_PLAYING_ALBUM`, `…_PLAYING_TRACK` | Int | Player selection (reset to −1 every launch) |
| `KEY_DATA_INT_PENDING_INTENT` | Int | Meant as "show the quote screen when The Steps loads"; nothing ever sets it to 1, so the path is dead |
| `FLAG_NOTIFICATIONS_HOURLY` | Bool | Hourly reminder on (set **true** on fresh install and on upgrade — see BUG-03) |
| `KEY_DATA_STRING_HOURLY_NOTIFICATION_START_TIME` / `…_END_TIME` | "HH:mm" | default "08:00" / "22:00" |
| `FLAG_NOTIFICATIONS_ON_AWAKENING`, `KEY_DATA_STRING_ON_AWAKENING_NOTIFICATION_TIME` | Bool, "HH:mm" | Morning reminder |
| `FLAG_NOTIFICATIONS_NIGHT_TIME`, `KEY_DATA_STRING_NIGHT_NOTIFICATION_TIME` | Bool, "HH:mm" | Night reminder |
| `FLAG_NOTIFICATIONS_SPONSORSHIP_STEP_COMMENTS`, `FLAG_NOTIFICATIONS_SPONSORSHIP_OTHER` | Bool | Toolkit leftovers |
| `FLAG_UPGRADE_1`, `FLAG_ONBOARDING_UPDATE_SHOWN`, `FLAG_IS_SHOWING_SUBSCRIPTION_SCREEN` | Bool | Upgrade bookkeeping; paywall-visible guard for app-open ads (persisted, so a kill while the paywall is open turns app-open ads off until the paywall is next shown — BUG-25) |
| `annual_PURCHASED` | Bool | Annual subscription active (refreshed by receipt validation) |
| `com.ibyteapps.aa12stepguide.donatetier5_PURCHASED`, `…donatetier10_PURCHASED`, `…donatetier20_PURCHASED` | Bool | Legacy lifetime supporters |
| `KEY_SUBSCRIPTION_DETAILS`, `KEY_SUBSCRIPTION_EXPIRY` | String | "Annual Subscription" / "Lifetime Upgrade", expiry text or "Never" |
| `annual` | String | Cached localised price |
| `LastShownAppOpenAd` | Date | App-open ad pacing (45 s) |
| `KEY_DATA_STRING_EMAIL` | String | Pre-fills the contact form (never written by this app — Toolkit leftover) |

**Files (Documents).** `main.db` (the audio catalogue plus per-track `offline` state: −1 not
downloaded, 0 queued, 1–99 progress, 100 done) and every downloaded `*.mp3`, stored flat as
`Documents/<file_name>`. Download state on screen comes from **file existence**
(`isTrackOffline()`), not from the database.

### 7.2 Android — default `SharedPreferences` (`com.ibyteapps.aa12stepguide_preferences.xml`)

| Key | Type | Meaning |
|---|---|---|
| `mKeyStepDatalaunchCount_aa12stepguide_aa12stepguide` | Int | Launch count (`KEY_INT_LAUNCH_COUNT` already carries the suffix, and `setKeyDataInt` appends it again) |
| `onBoardingShown` | Bool | Onboarding done |
| `myAppDay`, `myAppMonth` (1-based), `myAppYear` | Long | **Sobriety date** (0 = not set) |
| `canplayaudio`, `datafetched` | Bool | Whether a date is set / stale flag |
| `mKeyStepDatahtmlsize_aa12stepguide` | Int | Reader zoom step: 0 / 3 / 6 (→ 100 / 130 / 160 %) |
| `donatetier{1,2,3}_aa12stepguidepurchased_aa12stepguide` | Bool | Donation owned → **no ads** (rebuilt from purchase history on every resume) |
| `mKeyStepDatadonatetier{1,2,3}price_aa12stepguide` | String | Cached price |
| `mKeyStepDatarate_shown_aa12stepguide`, `ratedapp_aa12stepguide`, `rated` | Int/Bool | Rate-prompt bookkeeping |
| `mKeyStepDatatimeShownLiterature_aa12stepguide_aa12stepguide` | Int | Interstitial counter (every 3rd) |
| `mLastClickTime_aa12stepguide` | Long | Double-tap guard |
| `<viewId>COUNT_TIPPED_aa12stepguide`, `<viewId>LAST_TIPPED_aa12stepguide` | Int/Long | Font tooltip shown count (keys use generated view ids) |
| `2SHOWONCE_aa12stepguide` | Bool | Calculator hint dismissed |
| `tabno`, `accountid` | Int | Leftovers (no accounts exist) |

`allowBackup="true"`, so Android Auto Backup may restore these prefs on a new device.
`KEY_SERVER_SETTING_ADS_NETWORK` is read but never written, so it always defaults to AdMob-first.

---

## 8. Remote endpoints and integrations

| Endpoint / service | Used by | Purpose | State today |
|---|---|---|---|
| `https://scripts.12stepapp.com/tracks/{album.variable}/{file_name}` | iOS | Audio streaming and downloads (static MP3s) | Responds with binary content (checked 9 Oct 2026). Size and content type could not be confirmed from here. **Single point of failure for the whole audio feature** |
| `https://scripts.12steptoolkit.com/universal/1/mail.php` (POST, form-encoded, includes a shared `serversecret`) | iOS contact form | Sends support email | Not called (it would send an email). Lives on the **Toolkit** server: if the Toolkit's Laravel cut-over drops `/universal/1/`, the *current* iOS app's contact form breaks (Risk R-07) |
| `https://www.aa.org/pages/en_US/daily-reflection` | Both | Daily Reflections, opened in the browser | External |
| `https://www.12steptoolkit.com/privacy-policy-ibyte/`, `/terms-of-service/` (iOS); `/privacy` (Android) | Both | Legal | Policy loads and names "12 Step Guide". It does not describe advertising SDKs or analytics specifically |
| `https://www.facebook.com/12steptoolkit/` | iOS | "Like us on Facebook" | |
| App Store developer page `id901932809`, 5 App Store app ids | iOS | More apps / other apps | `1452072215` (12 Step Toolkit), `1335643834` (Speaker Tapes), `1239464706` (Sober Today), `1111214132` (The Big Book), `902251318` (Joe & Charlie) |
| Play: `pub:iByte Apps Limited`, `app.aabigbook.reader`, `com.ibyteapps.joeandcharliefree`, `com.ibyteapps.sobertoday`, `com.ibyteapps.aa12steptoolkit`, `com.ibyteapps.meetingfinder` | Android | More apps / more free apps | Meeting Finder: status unknown (Q-P4) |
| Apple `verifyReceipt` (production) with an app-specific shared secret | iOS | Subscription validation from the device | Apple deprecated this API in 2023 |
| Google Play Billing (purchase history query) | Android | Donation entitlement | `queryPurchaseHistoryAsync` **no longer exists in Billing 8** (§9.3) |
| Firebase Analytics, Crashlytics | Both | Automatic events, crashes | No custom events in either app |
| Firebase Cloud Messaging | Android only, in practice | Push | **iOS has no FirebaseMessaging library** (Podfile: Core + Crashlytics only). It registers with APNs, so the Toolkit "sponsorship" handlers in `AppDelegate` can never receive anything. Android includes `firebase-messaging` with no custom service: Firebase console notifications are displayed by the library's built-in service on Android 12 and below; on 13+ they need `POST_NOTIFICATIONS`, which is not declared. Whether console campaigns are sent is unknown (Q-P2) |
| AdMob | Both | Banner, interstitial, app-open | Live unit ids in source |
| Meta Audience Network | Android | Interstitial fallback (banner path is coded but never reached from the reader) | |

There is no API of this app's own and no deep links. The iOS `CFBundleURLTypes` hold a
Google Sign-In reversed client id and a LinkedIn scheme, both Toolkit leftovers that no code
handles.

---

## 9. Monetisation

### 9.1 Products

| Store | Product id | Type | Price (store, Oct 2026) | Sold in app? | Grants |
|---|---|---|---|---|---|
| App Store | `annual` | Auto-renewable subscription, 7-day free trial | £16.99 / yr (the description still says $19.99, the paywall placeholder $9.99) | **Yes** | No ads + downloads ("Unrestricted access to all new features") |
| App Store | `com.ibyteapps.aa12stepguide.donatetier5` / `donatetier10` / `donatetier20` | Non-consumable (inferred from restore handling) | Listed as "Donate £2.99 / £4.99 / £9.99" | **No** — restore only | "Lifetime Upgrade" = everything the subscription gives |
| Google Play | `donatetier1` / `donatetier2` / `donatetier3` | **In-app, consumed immediately after purchase** | Read from Play at runtime | Yes | "Donate & remove ads for life" |

### 9.2 Entitlement logic
- **iOS:** `getSubscribed()` is true if any `<product>_PURCHASED` flag is set. On every launch
  `validateReceipts()` calls Apple with the shared secret and sets or clears `annual_PURCHASED`.
  Legacy donation flags are never cleared once set. Restore converts any old tier into "Lifetime
  Upgrade".
- **iOS, on the first launch after an upgrade from an older version,** runs a silent
  `restorePurchasesOnUpdate()`. It can show an Apple ID sign-in prompt.
- **Android:** `getSubscribed()` is true if any donation flag is set. Three seconds after every
  resume, billing reconnects; when the history query succeeds it **clears all three flags**, then
  re-sets them from purchase history. Consumed purchases still appear in history, which is the
  only reason donors stay ad-free after reinstalling. Pending purchases are granted and consumed
  without checking the purchase state (BUG-26).

### 9.3 Consequence for the rebuild (critical)
Google Play Billing Library 8 removed purchase-history queries, and the current Flutter plugin
(`in_app_purchase_android` 0.5.x) is built on Billing 8. Play also requires every app update to
use Billing 8 or later from 2026. **Once the Flutter app ships, a donor's consumed purchase can no
longer be rediscovered from Play.** In-place updates keep the local flag, which the migration
reads. A donor who **reinstalls, or moves to a new phone**, loses ad-free status unless something
else holds the record. Options are in `MIGRATION_PLAN.md` §5 and decision **A-04**.

### 9.4 Ads

| Placement | iOS | Android |
|---|---|---|
| Interstitial before opening content | Steps, Prayers, Readings, Big Book, track play, player next/prev. Every **2nd** counted tap (`tapCount()`; meant to reset each launch but persists — BUG-09; in Literature it also counts taps on Daily Reflections and other-app rows — BUG-31) | Steps, Traditions, Readings **including the Daily Reflection link**, Big Book. Every **3rd** open, counter persisted; set back to 3 after an app-open ad |
| Interstitial network | AdMob | AdMob, falling back to Meta Audience Network (and back again) |
| Banner | Reader, player, quote screen | Reader |
| App-open | On becoming active, ≥ 45 s since the last one (cold start blocked by stamping the time at launch), not while the paywall is up. The intended 4-hour ad-expiry check does nothing (BUG-32) | On foreground (`ON_START`) when an ad is loaded and ≥ 20 s since the last (timestamp in memory). A fresh process has no ad loaded at its first foreground, so the first one comes on a later foreground; ad kept ≤ 4 h. Keeps showing after a mid-session donation until the process restarts (BUG-28) |
| Muting | — | `MobileAds.setAppVolume(0)` |
| Subscriber | No ads anywhere | No ads anywhere (`AppOpenManager` not created) |
| Consent | **None.** The UMP SDK is linked but never called; no ATT prompt and no `NSUserTrackingUsageDescription` | **None in code.** The changelog for build 26 says "Integrated UMP for GDPR", but no UMP call exists in the shipped source |
| Test devices | Hard-coded test device ids | Hard-coded test device ids |

---

## 10. Notifications (iOS only; Android has none)

| Reminder | Schedule | Text | Tap action |
|---|---|---|---|
| Hourly consciousness | One repeating calendar trigger per hour, start→end hour, at the start minute | "Hourly Consciousness Reminder" / "Tap To Reveal This Hours' Quote" | Quote reveal (S-I-14) |
| On awakening | Daily at time — **implemented but unreachable** (cell hidden) | "Reminder" / "Time For Your Morning Inventory" | Opens the app (no specific screen) |
| Night time | Daily at time — **implemented but unreachable** (cell hidden) | "Reminder" / "Time For Your Night Inventory" | Opens the app |
| We miss you | Fresh installs only: once, 3 and 7 days after install, at **00:00** (date-only calendar trigger with a year, so `repeats` never fires again) | "We Miss You" / "It's been 3 days since you used the app!" (and 7) | No `userInfo`; `AppDelegate` force-casts `userInfo["action"]`, so a tap probably crashes the app *(inferred)* (BUG-22) |
| Remote (FCM) | Server | — | Toolkit sponsorship handlers; otherwise default display |

Permission is requested at **every** launch from `AppDelegate`; the system only shows the prompt
the first time. Switching the hourly reminder on, or changing its window, only *adds* requests:
hours outside a narrowed window are never cancelled (BUG-23). The quote screen picks from index
1 onwards, so the first of the 61 quotes never shows, and a trailing newline can produce an empty
quote (BUG-24). Android declares no notification permission and schedules nothing.

---

## 11. Permissions and platform configuration

| | iOS | Android |
|---|---|---|
| Declared | Notifications (runtime), `NSFaceIDUsageDescription` (unused leftover), background modes `audio` + `remote-notification`, `aps-environment`, Sign in with Apple entitlement (unused leftover), `NSAllowsArbitraryLoads = YES` | `INTERNET`, `ACCESS_NETWORK_STATE`, `VIBRATE`, `com.android.vending.BILLING`, `AD_ID`, **`READ_PROFILE`** (unneeded), `requestLegacyExternalStorage`, `largeHeap`, `allowBackup="true"` |
| Missing | ATT usage string (not needed if ATT is not used); privacy manifest (`PrivacyInfo.xcprivacy`) | `POST_NOTIFICATIONS` (needed for any reminder on Android 13+) |
| Other config | No `SKAdNetworkItems` in Info.plist (AdMob recommends them) | Meta `ApplicationId` meta-data, `AutoLogAppEventsEnabled=false`, `AD_SERVICES_CONFIG` property, hard-coded `android:debuggable=false` |
| Required device capability | `armv7` (obsolete key) | — |

---

## 12. Analytics and crash reporting
Firebase Analytics (automatic screen and session events only) and Crashlytics on both. Android
writes breadcrumb logs to Crashlytics, including the account id (always −1) and subscription
state. No personal data is logged. iOS `GoogleService-Info.plist` has `IS_ANALYTICS_ENABLED =
false`, but analytics is still linked through `Firebase/Core`.

**Store privacy declarations do not match the code.** The App Store label says "Data Not
Collected" while Firebase Analytics, Crashlytics and AdMob are in the app. Play's Data safety form
says device ids are collected/shared and that "Data can't be deleted". Both must be corrected at
release (R-10).

---

## 13. Theming, accessibility, responsiveness

| | iOS | Android |
|---|---|---|
| Dark mode | Follows system (iOS 13+). Reader text turned white by CSS injection; tab and nav bars are system | **Light only** (`Theme.AppCompat.Light`) |
| Text scaling | UI labels: partly Dynamic Type via storyboards. Reader: fixed px choice (3 sizes) | Reader: 3 zoom steps. UI: sp |
| Screen reader | No custom labels; icons unlabelled | Generic content descriptions ("List", "Form") on tabs |
| Tablets | Universal, all orientations; Big Book segment labels adapt to width | `values-large/xlarge` dimens; same layouts |
| Colours | Hex constants (`#F06C64` pastel red, `#3FB8CD` pastel blue, `#265BD5` tint blue, 13 album gradients) | `colorPrimary #3F51B5`, accent `#0081F0`, `#F06C64`, greys |
| Icon | Light illustrated icon (books, headphones, aqua `#80EEFF`) | Navy book "12 Steps Guide" (`#1E2134`) on cream `#FFEDDB` |

---

## 14. Privacy and security findings

1. **Secrets in the client.** `_Constants.swift` holds the App Store shared secret used for
   receipt validation and the Toolkit server's `serverSecret`, and `ContactVC` sends the server
   secret in a form post. Both can be read out of any shipped iOS binary. Neither belongs in the
   new app (`FLUTTER_ARCHITECTURE.md` §9).
2. **No ad consent** for UK/EEA users on either platform (§9.4).
3. **ATS disabled** (`NSAllowsArbitraryLoads`) on iOS. Nothing in the app needs it: every host is
   HTTPS.
4. **Store privacy declarations wrong** (§12).
5. Live AdMob units used in debug builds (test-device ids are hard-coded instead of test units).
6. No user-generated content leaves the device. The only personal data is the sobriety date
   (Android, local) and the contact-form email address (iOS, sent to the Toolkit mailer).

---

## 15. Defect and technical-debt register

| ID | Platform | Defect | Effect | Disposition in Flutter |
|---|---|---|---|---|
| BUG-01 | iOS | Hourly notification request ids are `"HourNotification"+h+h`; `removeAppNotifications()` removes `"HourNotification"+h` | Notifications cannot be cleared by that path | New ids; migration cancels legacy ids (MIGRATION_PLAN §6) |
| BUG-02 | iOS | First hourly request is created **before** `body` and `userInfo` are set (content copied at init) *(inferred)* | Start-hour notification has no body; tapping it force-unwraps a nil `action` → likely crash | Fixed by design |
| BUG-03 | iOS | Fresh install and upgrade set `FLAG_NOTIFICATIONS_HOURLY = true` but schedule nothing until the user edits Notifications | UI shows "on" while nothing fires | Migration honours what is **actually pending**, not the flag (MIGRATION_PLAN §6) |
| BUG-04 | iOS | On-awakening, night-time and both sponsorship cells are `hidden` in the storyboard while the code still schedules them if their flags were ever on | Two reminder types exist in code that no user can reach | Decision A-18 |
| BUG-05 | iOS | Player "previous" from track 1 jumps to `count - 2` | Skips the last track | Fixed |
| BUG-06 | iOS | Every call to `FilesDownloader.download()` adds another 1-second repeating timer that is never stopped (called at launch, from the album screen and after each finished file) | Growing battery use and DB churn during a session | Replaced |
| BUG-07 | iOS | No lock-screen / Control Centre now-playing info or remote commands | Can't pause from lock screen | Added (required on Android anyway) |
| BUG-08 | iOS | Foreground remote-notification path never calls `completionHandler`; unreachable in practice because there is no FCM SDK | None today | N/A |
| BUG-09 | iOS | `KEY_DATA_INT_TAP_COUNT` reset uses the key `tapcount` | Counter persists across launches | Unified pacing |
| BUG-10 | Android | Sobriety day count uses `toDays(ms difference)` between local midnights | Off by one across a DST change | Calendar-date arithmetic |
| BUG-11 | Android | Readings rows pass the wrong title: Serenity Plus opens titled "Serenity Prayer", and all four Sobriety Tips open titled "A Vision For You" | Wrong reader titles | Titles from content index |
| BUG-12 | iOS | HTML loaded with `baseURL: nil`: stylesheets ignored, links open inside the reader with no back | Broken styling and navigation | Native rendering; external links → browser |
| BUG-13 | Android | Flags are cleared whenever the history query *succeeds*, even if it returns nothing (e.g. a different Google account is active) | A donor can lose ad-free status on that device | Store-of-record logic |
| BUG-14 | Android | App-open cooldown kept in memory only | Ad on nearly every foreground | Persisted cooldown |
| BUG-15 | Android | Rate dialog shows over whatever screen is open after 20 s | Interrupts reading | System review API at calm moments |
| BUG-16 | Both | "Conclusion" chapter unreachable | Hidden content | Surfaced (decision A-07) |
| BUG-17 | Both | Store text claims "150+ hours" of audio; the catalogue holds ~94 h | Misleading listing | Correct the listing (R-11) |
| BUG-18 | iOS | Downloaded tracks stream instead of playing locally once a subscription lapses | Uses data for files on the device | Decision A-05 |
| BUG-19 | Android | `getSubscribed()` debug "admin" switches left in (`subscribedMode`, `skuMode`) | Risk if flipped | Removed |
| BUG-20 | iOS | Notification permission requested at launch with no context | Lower opt-in | Primed in onboarding |
| BUG-21 | iOS | Launch count incremented twice on a fresh install's first launch | Paywall attempted during first launch; later cadences one launch early | One counter, seeded |
| BUG-22 | iOS | "We miss you" notifications fire at midnight, carry no `userInfo`, and the tap handler force-casts `userInfo["action"]` *(inferred crash)* | Midnight notification; tap may crash | A-13 |
| BUG-23 | iOS | Changing the hourly window never cancels hours outside the new window | More notifications than the user chose | Diff-based scheduler |
| BUG-24 | iOS | Quote picker skips index 0; trailing newline can yield an empty quote | One quote never shown; possible blank screen | All 61, no blanks |
| BUG-25 | iOS | `FLAG_IS_SHOWING_SUBSCRIPTION_SCREEN` persisted | App-open ads stop after a kill during the paywall | In-memory state |
| BUG-26 | Android | Pending purchases granted and consumed without checking `getPurchaseState` | Ad-free granted before payment completes | Pending state handled |
| BUG-27 | Android | Product loop `i <= size` in `getBillingData` throws `IndexOutOfBoundsException` after caching prices | An exception on every billing refresh (check Crashlytics for its frequency) | N/A |
| BUG-28 | Android | `AppOpenManager` is created at process start and never checks the subscription again | App-open ads continue after a mid-session donation until restart | Entitlement checked per show |
| BUG-29 | Android | Settings shows "Remove All Ads - 0" until prices load (stored-price default "0") | Wrong price text | Price from store or hidden |
| BUG-30 | Android | Settings "Rate" writes `rated`, the prompt checks `ratedapp` | Prompt keeps appearing after rating | One review state |
| BUG-31 | iOS | `tapCount()` runs before the section check in Literature | Taps on non-content rows advance the ad counter | `AdPolicy` counts content opens only |
| BUG-32 | iOS | App-open "4 hours" expiry check is ineffective | Stale ads may be shown | Expiry enforced |
| DEBT | Both | Global state, event buses, no tests, deprecated APIs (StoreKit 1, `verifyReceipt`, `onActivityResult`, `getDrawable`, AsyncTask-era patterns), dozens of unused libraries and leftovers | Maintenance cost | Not carried over |

---

## 16. Toolkit leftovers (compiled or bundled, not used)

**iOS:** `Structures.swift` (sponsorship/account models), `ShareText.swift` (record sharing),
`Hashids`, sponsorship notification flags and handlers, the hidden "My Account / Sign out" cell,
Face ID strings, the Sign in with Apple entitlement, the Google and LinkedIn URL schemes, step-4
inventory arrays, ten unused HTML files, `KEY_DATA_STRING_EMAIL`. Files outside the target:
`InventoryVC.swift`, `Sponsee.swift`, `ExampleViewController.swift`, `AALiteratureVC (1).swift`,
`Main copy.storyboard`.

**Android:** `accountid`, `tabno`, the sponsorship-review hint text, the `profeatures_extra`
price, WorkManager, `READ_PROFILE`, `org.apache.http.legacy`, the sample tests, and five unused
HTML files.

None of these is a user-visible feature. They are recorded so they are dropped deliberately
(decision A-09), not by accident.

---

## 17. Build status (from source, not executed)

- **iOS:** The project targets iOS 12.1 with CocoaPods 1.11, Swift 4.2/5, `armv7` capability
  and Firebase 8 / Google Mobile Ads 8. Current Xcode (26.x) no longer builds iOS 12 targets or
  `armv7`. The project would need pod and target updates before it compiles; it is not expected
  to build as-is. The version mismatch (project 1.21, store 1.51) suggests the version shipped
  as 1.51 was built from a slightly different project state than the one on disk (Q-P1).
- **Android:** Gradle files are current enough (compileSdk 34, targetSdk 36, Billing 7.1, Ads
  23.3), but `jcenter()` and `oss.sonatype` snapshot repositories are still declared and
  `com.github.*` artefacts rely on JitPack. Likely to build with Android Studio after repository
  clean-up; not verified. Note `compileSdk 34` with `targetSdk 36` is an unusual pairing.
- Neither project has CI.

---

## 18. Risks carried into the rebuild (summary)

`MIGRATION_PLAN.md` §9 has the full table.

- R-01 Android donors lose ad-free status after a reinstall (Billing 8). **High.**
- R-02 Audio host is a single static server with no monitoring; the whole audio feature depends
  on it. **High** for Android users, who will gain the feature.
- R-03 Minimum OS rises (iOS 12.1 → 15, Android 6 → 7): those users stay on the old version.
- R-04 AAWS naming compliance on Android is unresolved.
- R-05 Ad consent (UMP) will lower ad fill in the UK/EEA while consent is being given; this is
  required, not optional.
- R-06 Step-guide text differs between platforms, so one audience will see changed text.
- R-07 iOS contact form depends on the Toolkit server's `/universal/1/mail.php` path, which the
  Toolkit cut-over must keep or redirect.
- R-08 Version-number collision: iOS must ship above 1.51, Android above versionCode 29.
- R-09 Legacy notification schedules on iOS must be found and cancelled, or users get duplicate
  hourly notifications.
- R-10 Store privacy declarations need correcting.
