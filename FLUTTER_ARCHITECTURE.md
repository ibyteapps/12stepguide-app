# 12 Step Guide — Flutter Architecture

How the unified app is built. It follows 12 Step Toolkit's stack and conventions (owner
decision, 9 Oct 2026), scaled down to an app that has no accounts, no sync and no API of its
own. Where this app deliberately differs from the Toolkit, the reason is given.

---

## 0. Fixed points

| | Value | Why it cannot change |
|---|---|---|
| iOS bundle id | `com.ibyteapps.aa12stepguide` | App Store listing 1238097883, the `annual` subscription and old donation tiers, Firebase iOS app, AdMob iOS app id |
| Android applicationId | `com.ibyteapps.aa12stepguide` | Play listing, donation products, Firebase Android app, AdMob Android app id; an update must replace the old app in place to read its preferences |
| Android launcher activity | `com.ibyteapps.aa12stepguide.First` | Home-screen icons store this component; the Flutter activity keeps the name |
| Product ids | `annual`, `com.ibyteapps.aa12stepguide.donatetier5/10/20` (iOS); `donatetier1/2/3` (Android) | Existing purchases |
| Firebase project | `aa-12-step-guide` | Analytics and crash history continuity |
| Audio URLs | `https://scripts.12stepapp.com/tracks/{variable}/{file_name}` | Server unchanged |
| iOS download location | `Documents/{file_name}` | Existing downloads are reused in place |
| Version | ≥ **2.0.0**, build ≥ **100** | iOS shipped 1.51; Android versionCode 29 |

`MIGRATION_PLAN.md` lists every legacy key that must be read.

---

## 1. Goals and non-goals

**Goals:** one codebase; every feature in `FEATURE_MATRIX.md`; offline-first literature; reliable
background audio; correct purchases; testable without a device for most logic; boring to
maintain.

**Non-goals (what "no enterprise abstraction" rules out):** no repository-per-table layering for
content that never changes; no code generation for state or JSON (the models are small); no
use-case classes that only forward a call; no server, no accounts; no plugin system.

---

## 2. Toolchain and platforms

| | Choice |
|---|---|
| Flutter / Dart | **3.47.7 / 3.13.5** (latest stable, 8 Oct 2026), pinned in `.fvmrc` (as the Toolkit does with FVM) and in CI. Re-checked at the start of implementation |
| iOS | Deployment target **15.0** (the current Firebase iOS SDK requires it; same as the Toolkit). Xcode 26, Swift Package Manager where plugins support it, CocoaPods otherwise |
| Android | **minSdk 24** (Flutter's floor), **targetSdk 36** and **compileSdk 36** (the live app already targets 36; Play requires 36 for updates from 31 Aug 2026), Kotlin DSL Gradle, AGP 9, Java 17, edge-to-edge |
| Devices | iPhone, iPad, Android phones and tablets; portrait and landscape |
| Lints | `flutter_lints` + the Toolkit's stricter rules (`avoid_print`, `unawaited_futures`, `prefer_final_locals`, `require_trailing_commas`) |

Impact of the minimum OS change is in `MIGRATION_PLAN.md` §8 (decision A-16).

---

## 3. Layers and the dependency rule

```
presentation  (widgets, screens)           ──►  application  (Riverpod controllers / notifiers)
application                                ──►  domain       (plain Dart models, policies, interfaces)
data          (repositories, platform IO)  ──►  domain       (implements the interfaces)
core          (logging, config, result types, platform channels) — used by data and application
design        (tokens, theme, components) — used by presentation only
```

- **Presentation** never touches a plugin directly. It watches providers and calls controller
  methods.
- **Domain** is pure Dart: `Entitlement`, `AdPolicy`, `ReminderSchedule`, `SobrietyDate`,
  `ContentIndex`, `Track`. These are where the rules live and are unit-tested without Flutter.
- **Data** wraps plugins behind small interfaces (`PurchaseGateway`, `AdGateway`,
  `NotificationScheduler`, `AudioEngine`, `DownloadStore`, `PrefsStore`, `LegacyBridge`) so
  tests use fakes.
- A feature may import `core`, `design`, `domain` and its own folder. Features talk to each
  other only through providers exposed in `app/providers.dart` (for example the reader asks the
  ads feature "may I show an interstitial?").

---

## 4. Folder structure

```
app/                                   ← repo root = Websites/12StepGuide/app
├─ lib/
│  ├─ main.dart                one entry point; the env comes from the flavour + config file
│  ├─ app/
│  │  ├─ bootstrap.dart        Firebase, error handlers, migration, consent, run app
│  │  ├─ app.dart              MaterialApp.router, themes
│  │  ├─ router.dart           go_router table + StatefulShellRoute
│  │  ├─ shell/                scaffold, bottom bar / rail, drawer, mini-player host
│  │  └─ providers.dart        cross-feature providers
│  ├─ core/
│  │  ├─ config/               Env, flavour, AppConfig (from --dart-define-from-file)
│  │  ├─ logging/              Log facade (debug console / Crashlytics breadcrumbs, redaction)
│  │  ├─ platform/             LegacyBridge (method channel), app info, connectivity
│  │  ├─ prefs/                PrefsStore + typed keys
│  │  └─ result.dart           sealed Result/Failure
│  ├─ design/
│  │  ├─ tokens/               color_tokens, typography, spacing, radii, elevation, motion
│  │  ├─ theme/                light/dark ThemeData + ThemeExtensions
│  │  └─ components/           buttons, rows, cards, badges, sheets, states, banners
│  ├─ features/
│  │  ├─ onboarding/           first run, welcome back, consent hand-off
│  │  ├─ steps/                Steps + Traditions lists
│  │  ├─ readings/             Readings list, recovery card
│  │  ├─ sobriety/             recovery date domain + screen
│  │  ├─ big_book/             segments + grids + continue reading
│  │  ├─ reader/               document view, Aa sheet, reading positions
│  │  ├─ audio/                catalogue, player, mini-player, downloads
│  │  ├─ premium/              entitlement, paywall, restore, legacy flags
│  │  ├─ ads/                  AdPolicy, AdGateway, banner widget, consent
│  │  ├─ reminders/            schedule domain, scheduler, settings, quote screen
│  │  ├─ appearance/           theme mode, text size, reading font
│  │  ├─ support/              contact, rate, share, other apps, about
│  │  └─ migration/            legacy snapshot → new prefs (idempotent steps)
│  └─ l10n/                    en-GB strings (ARB), ready for more languages
├─ content/                   the literature as standard Markdown (bundled as assets; archive/ is not)
├─ assets/
│  ├─ content_index.json       generated from the Markdown front matter (do not hand-edit)
│  ├─ audio/catalogue.json     generated from legacy main.db
│  ├─ quotes.txt               the 61 hourly quotes
│  ├─ sounds/cheer.mp3
│  └─ images/                  icon artwork, onboarding art
├─ content-source/             original HTML from both apps + legacy main.db (not bundled)
├─ tool/
│  ├─ html_to_markdown.py      HTML → Markdown, with a word-for-word check (done, D-003)
│  ├─ build_content_index.py   front matter → assets/content_index.json
│  ├─ build_catalogue.py       main.db → catalogue.json
│  └─ contrast_check.py        token contrast report (mirrored by a Dart test)
├─ test/ · integration_test/ · test_goldens/
├─ android/ · ios/            (incl. LegacyMigrationPlugin.kt / .swift)
├─ config/ dev.example.json · staging.example.json · prod.example.json   (real files gitignored)
├─ .github/workflows/ ci.yml · android.yml · ios.yml
└─ docs (the seven planning documents + DECISIONS.md)
```

---

## 5. State management — Riverpod 3

**Choice:** `flutter_riverpod` 3.4 with hand-written `Notifier` / `AsyncNotifier` classes, no
`riverpod_generator`.

**Why:** it is what 12 Step Toolkit uses, so there is one way of working across the owner's
apps; providers give dependency injection and test overrides for free (no separate DI
container); `AsyncValue` gives loading/error/data states that map one-to-one onto the
screen-state requirements; compile-time safe without code generation.

**Rules**
- One controller per screen or per long-lived concern (`PlayerController`,
  `EntitlementController`, `ReminderSettingsController`).
- Long-lived services (audio handler, purchase stream, ad gateway) are `keepAlive` providers
  created in `bootstrap` and overridden in tests.
- Widgets never hold business state in `StatefulWidget`s beyond ephemeral UI (scroll, focus).

---

## 6. Routing — go_router 18

- `StatefulShellRoute.indexedStack` with 4 branches (Steps, Readings, Big Book, Audio), each
  keeping its own stack; the shell paints the bottom bar or rail, the drawer and the
  mini-player.
- Drawer destinations are top-level routes pushed over the shell (`/premium`, `/reminders`,
  `/appearance`, `/downloads`, `/support`, `/other-apps`, `/about`).
- Detail routes: `/steps/:collection/:docId`, `/readings/:docId`, `/big-book/:collection/:docId`,
  `/audio/:albumId`, `/player` (modal sheet page), `/quote`, `/recovery-date`.
- Redirects: `/onboarding` until onboarding is done; `/welcome-back` once after a migration.
- **Notification taps** carry a route string in the payload (`/quote`, `/readings/aa__onawakening`
  …) and are routed after bootstrap, including from a cold start.
- **Deep links / universal links:** none exist today and none are added in 2.0. The router is
  ready for them.

---

## 7. Design system in code
`lib/design/tokens/*` holds the values in `UX_UI_SPEC.md` §3–5. `AppColors`, `AppType` and
`AppSpacing` are `ThemeExtension`s with `lerp` so theme changes animate. Components take no
colour parameters, only variants. A test fails if `Color(0x…)`, `TextStyle(fontSize:` or raw
`EdgeInsets` numbers appear outside `lib/design/`. The same lint-by-test approach is used in
the Toolkit.

---

## 8. Content

**Literature (decision D-003).** Every HTML document from both apps has been redone as a
standard Markdown file in `content/` (CommonMark + GFM tables, YAML front matter). The originals
are kept in `content-source/html/`, and `tool/html_to_markdown.py --check` proves no word was
lost. Conventions are in `content/README.md`. The Android text is used where the two apps
differ (D-002, F-030).

- **Bundling:** the shipped folders of `content/` are Flutter assets as they are, with no
  generated copy. `content/archive/` is not bundled.
- **Index:** `tool/build_content_index.py` reads the front matter into
  `assets/content_index.json` (id, title, subtitle, collection, order, pages, aliases, track
  ids), so lists never open a document. CI fails if the index is stale.
- **Parsing:** the maintained `markdown` package (dart-lang, CommonMark with the GitHub table
  extension) turns a document into an AST at open time, which is fast at these sizes.
- **Rendering:** our own `MarkdownView` maps AST nodes to design-system widgets: headings with
  heading semantics, paragraphs as selectable `Text.rich`, emphasis, hard breaks, ordered lists,
  tables, block quotes and links (external → in-app browser, `mailto:` → mail). The
  `<!-- page N -->` comments become a discreet page indicator and feed "Continue reading". The
  official `flutter_markdown` package is discontinued; its fork `flutter_markdown_plus` was
  considered, but a renderer of about 300 lines that we own is the only way to style page
  markers, apply our text-size steps and expose proper semantics.
- **The app ships no HTML engine**, so text scales, selects, themes and reads aloud properly.
- **Tests:** every index entry resolves to a document; every document parses; golden tests
  render one document of each collection in light and dark.

**Audio catalogue.** `tool/build_catalogue.py` reads the legacy `main.db` (11 albums, 138
tracks: id, album id, title, file name, length, size, transcript flag) into
`assets/audio/catalogue.json`. Ids are preserved so a migrated "current track" still points at
the same file. A remote catalogue is not needed for 2.0 (A-24); the loader is an interface, so a
remote JSON can be added later without touching screens.

**Quotes** — `assets/quotes.txt` (61 lines, emoji preserved).

---

## 9. Persistence, configuration and secrets

| Data | Store | Notes |
|---|---|---|
| Settings (theme, text size, font, reminders, onboarding flags, launch count, ad counters, last tab) | `shared_preferences` (`SharedPreferencesWithCache`, prefixed keys `app.*`) | Small, synchronous after start-up |
| Sobriety date | prefs (`sobriety.date` = ISO date) | Not a secret; local only; backed up with the app's prefs |
| Reading positions, track positions | prefs (JSON maps keyed by doc/track id) | Bounded size |
| Entitlement cache | prefs (`premium.*`) | Re-derived from the stores on every launch; the cache only bridges offline launches |
| Legacy lifetime flags | prefs (`premium.legacyLifetime` + source) | Written once by migration, never cleared |
| Downloads | Files: iOS `Documents/{file}`, Android `filesDir/audio/{file}`; the downloader's own task DB | Existence + size check is the truth, as in the native app |

**No SQL database.** Unlike the Toolkit, which must open its users' Room database in place, this
app has no user records. A database would be code without a job. `sqflite` is used only by the
build tool and by migration, which reads the legacy iOS `main.db` once (download states for the
welcome-back summary); the app does not depend on it at runtime.

**Secure storage.** The app holds no credentials or tokens, so `flutter_secure_storage` is not
included. If a server and token arrive later (A-15), it is the place for them.

**Config and environments.** `--dart-define-from-file=config/<env>.json` supplies: `ENV`,
AdMob unit ids, the support email, store URLs and the audio base URL. AdMob **application** ids
live in `AndroidManifest.xml` / `Info.plist` per flavour.

| Env | Android | iOS | Ads | Firebase | Distribution |
|---|---|---|---|---|---|
| dev | flavour `dev`, id `…aa12stepguide.dev`, name "12SG Dev" | scheme `dev`, bundle `…aa12stepguide.dev` | Google test units | dev apps in the same Firebase project | Local, CI artefacts |
| staging | flavour `staging`, production id, name "12SG Staging" | scheme `staging`, production bundle id | Google test units | production apps, analytics collection off | TestFlight internal, Play internal testing |
| prod | flavour `prod` | scheme `prod` | live units | production apps | Store |

**Never committed:** keystores, `key.properties`, App Store Connect API keys, real
`config/*.json`, Firebase service accounts. `google-services.json` / `GoogleService-Info.plist`
contain public identifiers only; they are generated by `flutterfire configure` and kept out of
git (owner preference, Q-T1). No App Store shared secret and no `serverSecret` is needed by the
new app.

---

## 10. Platform features

### 10.1 Audio — `just_audio` + `audio_service` + `audio_session`
- `just_audio` plays the HTTP stream or the local file; it handles buffering, seeking and the
  playlist (the album), and loops the album.
- `audio_service` runs the Android foreground media service and the notification controls, and
  publishes iOS Now Playing and remote commands (fixes BUG-07). It is the maintained,
  production-grade option; `just_audio_background` is still a beta.
- `audio_session` configures the `playback` category, handles interruptions (calls, Siri) and
  "becoming noisy" (headphones unplugged → pause).
- Source choice per track: local file if downloaded **and** Premium (A-05), otherwise the
  stream.

### 10.2 Downloads — `background_downloader` 9.6
iOS background `URLSession` and Android WorkManager behind one API. It handles progress,
resume after app kill, a concurrency limit (2, as today), Wi-Fi-only constraint, and retries.
Destination per platform as in §9. Downloaded audio is excluded from iCloud backup through a
one-line native call in the platform plugin (it is re-downloadable). Final size is checked
against the expected size before marking a track downloaded.

### 10.3 Purchases — `in_app_purchase` 3.3 (StoreKit 2 / Play Billing 8)
- `PurchaseGateway` wraps the plugin: product query, buy, restore, the purchase stream, and
  completing transactions.
- iOS uses **StoreKit 2** (`InAppPurchaseStoreKitPlatform.enableStoreKit2()`): transactions are
  signed by Apple and verified on device, so no shared secret and no `verifyReceipt`.
  Subscription status (active, grace, expired, revoked) comes from current entitlements.
- Android uses Billing 8 via the plugin: `queryPurchases` returns owned (unconsumed) items and
  active subscriptions. Consumed donations are invisible to it; see `MIGRATION_PLAN.md` §5 and
  decision A-04.
- **Why not RevenueCat:** this app never used it, the owner is moving his other apps off it, and
  with no server-side entitlement need, on-device verification is sufficient for 2.0. Server
  verification can be added behind `PurchaseGateway` later (A-15).
- `Entitlement` (domain) = store state ∪ legacy lifetime flags, with the cache rules in §9.

### 10.4 Ads and consent — `google_mobile_ads` 9.1 (UMP built in)
- `ConsentController` runs the UMP flow before any ad request (A-11), exposes
  `privacyOptionsRequired` for the drawer row, and passes consent through to Firebase Analytics
  consent mode.
- `AdPolicy` (pure Dart) decides *whether* an ad may show, from: Premium, consent, screen
  context, the persisted counters and timestamps (UNIFIED_PRODUCT_SPEC §2.4). It is unit-tested
  exhaustively; placements cannot bypass it.
- `AdGateway` preloads one interstitial and one app-open ad, shows adaptive banners, mutes
  video, and never blocks navigation on a missing ad.
- Meta Audience Network: dropped as a direct SDK. If the owner wants the revenue,
  `gma_mediation_meta` adds it as AdMob mediation with no app logic (A-10).
- Dev and staging always use Google's published test units.

### 10.5 Reminders — `flutter_local_notifications` 22 + `timezone` + `flutter_timezone`
- `ReminderSchedule` (domain) turns settings into a list of `(id, hour, minute, kind, route)`.
  The scheduler diffs it against pending requests and applies only the changes.
- `zonedSchedule` with daily repetition (`matchDateTimeComponents: time`), Android
  `inexactAllowWhileIdle` (no exact-alarm permission), channels per spec.
- Re-armed on app start, on resume after a time-zone change, and after a device reboot (the
  plugin's boot receiver).
- "We miss you" uses two one-shot notifications that are re-armed on every app open.
- `firebase_messaging` is included only if A-17 keeps remote campaigns. The app would then
  display them, with no custom handling.

### 10.6 Analytics and crash reporting — Firebase
- `firebase_core`, `firebase_analytics` (automatic events + screen views from the router
  observer), `firebase_crashlytics` (fatal and non-fatal, `FlutterError.onError` and
  `PlatformDispatcher.onError`).
- **Privacy rules:** no user content, no sobriety date, no email, no free text in events, logs
  or crash keys. Allowed keys: app version, flavour, screen route (without document text),
  album/track ids, entitlement *type* (free/annual/lifetime).
- No new custom events in 2.0 without approval. Purchase events come from Firebase's automatic
  in-app purchase logging.

### 10.7 Other packages
`url_launcher` (links, stores, mail), `share_plus` (tell a friend), `in_app_review` (system
review prompt), `package_info_plus` (version), `connectivity_plus` (offline banners),
`path_provider`, `intl`, `material_symbols_icons`. Dev: `flutter_native_splash`,
`flutter_launcher_icons`, `mocktail`, `flutter_lints`.

### 10.8 Platform channel — `LegacyMigrationPlugin` (owned native code)
One method channel, `com.ibyteapps.aa12stepguide/legacy`, implemented in Swift and Kotlin in
the Runner projects (the same pattern as the Toolkit):
- `readLegacyPrefs()` → iOS: the standard `NSUserDefaults` domain (unprefixed keys). Android:
  the default `SharedPreferences` file `com.ibyteapps.aa12stepguide_preferences`.
- `pendingLegacyNotifications()` / `cancelLegacyNotifications(ids)` (iOS).
- `listLegacyDownloads()` → files in `Documents` matching catalogue file names (iOS).
- `excludeFromBackup(path)` (iOS).

Read-only apart from the explicit cancel/exclude calls. Legacy data is never deleted.

---

## 11. Data flow examples

**Open a reading (free user):** `ReadingsScreen` tap → `ReaderController.open(docId)` →
`AdPolicy.mayShowInterstitial(context: contentOpen)` → if yes, `AdGateway.showInterstitial()`
(await dismissal or a 0 ms skip when not loaded) → `context.push('/readings/$docId')` →
`DocumentRepository.load(docId)` (asset JSON, cached) → `ReaderView` renders blocks →
`ReadingPositions.save` on scroll end.

**Play a track:** `AlbumScreen` tap → `PlayerController.playAlbum(albumId, index)` →
`AdPolicy` check → `AudioEngine.setPlaylist(sources)`, where each source is a local file if
downloaded and Premium, else the stream URL → `audio_service` publishes media info →
`MiniPlayer` and `PlayerSheet` watch `playbackStateProvider`.

**Purchase:** `PremiumScreen` → `PurchaseGateway.buy(productId)` → purchase stream → verify
(StoreKit 2 / Play) → `Entitlement` recomputed → `premiumProvider` updates → ads stop at once,
download buttons unlock, a pending download resumes.

---

## 12. Error handling and logging
- Data-layer methods return `Result<T, Failure>`. Failures are a small sealed set: `Offline`,
  `Server(code)`, `NotFound`, `StoreUnavailable`, `PurchaseCancelled`, `PurchasePending`,
  `StorageFull`, `PermissionDenied`, `Unexpected`. Controllers map them to the UI copy in the
  spec.
- `Log.d/i/w/e` — debug builds print to the console; release builds send `w`/`e` to Crashlytics
  as breadcrumbs or non-fatals. A redaction step strips anything that looks like an email
  address or a date of birth, and the privacy rules in §10.6 apply.
- No `print` (lint error).

---

## 13. Testing strategy

| Level | What | Tooling | Where it runs |
|---|---|---|---|
| Unit | `AdPolicy`, `Entitlement`, `ReminderSchedule` (DST, wrap past midnight, 64-limit), `SobrietyDate` (DST, leap years, future dates), migration mapping for every legacy key, text-size mapping, content index integrity, catalogue integrity, token contrast | `flutter_test`, `mocktail` | CI Linux |
| Widget | Every screen in loading / empty / error / success, light and dark, 1.0× and 2.0× text, phone and tablet sizes; semantics checks | `flutter_test` | CI Linux |
| Golden | Key screens and components in both themes | `matchesGoldenFile` (Linux-rendered baselines) | CI Linux |
| Integration | UJ-1 … UJ-12 on a real engine with fake gateways; migration from fixture legacy prefs (iOS and Android snapshots); notification routing from a cold start | `integration_test` | CI: Android emulator (Linux runner), iOS simulator (macOS runner) |
| Manual device | Purchases in sandbox / licence testers, real background audio, lock screen, reminders over a day, consent form in the EEA (VPN), VoiceOver / TalkBack passes | Checklist in IMPLEMENTATION_PLAN §6 | Owner + TestFlight / Play internal |

Coverage target: 90 % of `domain/` and `features/*/application`; widgets by screen-state coverage
rather than a percentage.

---

## 14. CI (GitHub Actions)
The repository is public, so GitHub-hosted runners (Linux and macOS) cost nothing. All three
workflows run on every push to `main` and on every pull request.
- `ci.yml` (Linux): `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`
  (including `test/fixed_identifiers_test.dart`, which reads the native project files), and
  `tool/html_to_markdown.py --check` followed by a check that `content/` is unchanged. P1 adds
  the content-index freshness check.
- `android.yml` (Linux): `dev` debug APK and `prod` release AAB, then
  `tool/ci/verify_build.py` checks the package name, version, SDK levels, launcher activity and
  label inside them (aapt2, bundletool). The AAB is debug-signed until the upload key is
  provided (Q-T2). Emulator integration tests join when P1 adds the first ones.
- `ios.yml` (macOS 26): `prod` release build without code signing and a `dev` simulator build,
  then the same check of bundle id, version, minimum iOS and display name. Simulator
  integration tests join with P1.
- Release signing and store upload (`flutter build ipa` + App Store Connect API key; Play
  service account) are added once the owner provides the secrets as GitHub encrypted secrets
  (Q-T2).

**Building locally** (each environment pairs a flavour with its config file; `AppConfig`
refuses a mismatch):
```bash
cp config/dev.example.json config/dev.json        # once per environment
flutter run --flavor dev --dart-define-from-file=config/dev.json
flutter build appbundle --flavor prod --dart-define-from-file=config/prod.json
flutter build ipa --flavor prod --dart-define-from-file=config/prod.json
```

---

## 15. Dependency register (versions at 9 Oct 2026)

| Package | Version | Purpose | Alternative considered |
|---|---|---|---|
| flutter_riverpod / riverpod | 3.4.3 | State + DI | Bloc (more ceremony); Provider (weaker async model) |
| go_router | 18.0.2 | Routing, shell routes | auto_route (code generation) |
| shared_preferences | 2.5.6 | Settings | Hive / Isar (unneeded) |
| just_audio | 0.10.6 | Playback | audioplayers (weaker playlist/seek) |
| audio_service | 0.18.19 | Background + media controls | just_audio_background (beta) |
| audio_session | 0.2.4 | Audio focus / interruptions | — |
| background_downloader | 9.6.4 | Background downloads | flutter_downloader (older, Android-centric) |
| in_app_purchase | 3.3.1 (android 0.5.3, storekit 0.4.13) | StoreKit 2 / Billing 8 | RevenueCat (not used by this app; owner moving away) |
| google_mobile_ads | 9.1.0 | Ads + UMP | — |
| gma_mediation_meta | 1.7.1 | Optional Meta mediation | Direct FAN SDK (no maintained Flutter plugin) |
| flutter_local_notifications | 22.3.1 | Reminders | awesome_notifications (heavier) |
| timezone / flutter_timezone | 0.11.1 / 5.1.1 | DST-correct schedules | — |
| firebase_core / analytics / crashlytics | 4.15.0 / 12.6.0 / 5.4.0 | Analytics, crashes | Sentry (would split history) |
| firebase_messaging | 16.7.0 | Only if A-17 | — |
| markdown | 7.3.1 | Parse the literature (CommonMark + GFM tables) | flutter_markdown (discontinued); flutter_markdown_plus (less control over semantics and page markers) |
| url_launcher | 6.3.3 | Links | — |
| share_plus | 13.3.1 | Share | — |
| in_app_review | 2.0.12 | Review prompt | — |
| package_info_plus | 10.2.2 | Version | — |
| connectivity_plus | 7.3.2 | Offline state | — |
| path_provider | 2.1.6 | Paths | — |
| intl | 0.20.3 | Dates, l10n | — |
| material_symbols_icons | 4.2960.0 | Icon set | — |
| dev: flutter_lints 6.0.0, mocktail 1.0.5, flutter_native_splash 2.4.8, flutter_launcher_icons 0.14.4 | | | |

Not used, on purpose: `dio` (no API; the plugins handle their own HTTP), `sqflite` at runtime,
`flutter_secure_storage` (nothing secret), `permission_handler` (notification permission comes
from `flutter_local_notifications`; nothing else needs a runtime permission), any state or JSON
code generator. If decision A-14 keeps the in-app contact form, `http` (or `dio`, as in the
Toolkit) is added for that single call.
