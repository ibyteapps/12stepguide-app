# 12 Step Guide — Implementation Plan

A phased build of the unified app. Each phase ends with tests green and **both** an Android
and an iOS build from CI. Nothing is built until its decisions in `OPEN_QUESTIONS.md` are
approved. Progress is tracked against `FEATURE_MATRIX.md`: a row is ✅ only when its acceptance
criteria pass on both platforms.

---

## 1. Phase overview

```
P0 Repo, toolchain, CI ─► P1 Foundations ─┬─► P2 Reading ──────────┐
                                          ├─► P3 Audio ────────────┼─► P7 Hardening ─► P8 Release
                                          ├─► P4 Premium & ads ────┤
                                          ├─► P5 Reminders ────────┤
                                          └─► P6 Drawer & support ─┘
```
P2–P6 depend only on P1 and can overlap. P4's ad placements touch P2 and P3 screens, so P4
lands after the screens exist (its gateways can be built in parallel). P7 needs everything.

| Phase | Blocking decisions | Delivers |
|---|---|---|
| P0 | Repo created (done) | Flutter project, flavours, CI |
| P1 | A-09 (A-08 and A-23 decided: D-002, D-003) | Design system, shell and drawer skeleton, prefs, logging, legacy bridge, migration runner, content pipeline |
| P2 | A-07, A-19, A-02 (A-01 and A-03 decided: D-001, D-005) | Steps, Traditions, Readings, Big Book, Reader, Aa sheet, recovery date, onboarding, welcome back, appearance |
| P3 | A-05, A-24, A-20 | Audio library, album, player, mini-player, background audio, downloads |
| P4 | A-04, A-06, A-10, A-11, A-15, A-25, A-26 | Purchases, entitlement, paywall, restore, consent, ads |
| P5 | A-12, A-13, A-17, A-18 | Reminders, quote screen, notification routing, iOS reminder migration |
| P6 | A-14, Q-P4, Q-P5, Q-T1 | Contact, rate, share, other apps, about, legal, privacy options, analytics wiring |
| P7 | — | Accessibility, tablets, performance, integration tests, device upgrade tests, store assets |
| P8 | Q-T2 (signing) | Internal → beta → phased production release |

---

## 2. Phases in detail

### P0 — Repository, toolchain, CI
**Work**
- `flutter create` (Flutter 3.47.7) in `Websites/12StepGuide/app` with org `com.ibyteapps` and
  the exact ids; `.fvmrc`; analysis options; README; planning documents
  moved into the repo.
- Flavours `dev` / `staging` / `prod` on both platforms (Android product flavours; iOS schemes,
  build configurations and xcconfigs); one `lib/main.dart`; `config/*.example.json`;
  `.gitignore` for real configs, keys, Firebase files, `z.txt`.
- GitHub Actions: `ci.yml`, `android.yml`, `ios.yml` (FLUTTER_ARCHITECTURE §14).

**Acceptance criteria**
- `flutter analyze` clean; `flutter test` passes (placeholder tests).
- CI produces an Android `dev` debug APK and an iOS `prod --no-codesign` build.
- App ids, version `2.0.0+100`, minimum OS and target SDKs are verified in the built artefacts
  by a CI script.

**Checkpoint:** CI green on both build workflows.

### P1 — Foundations
**Work**
- `design/`: tokens, light/dark themes, components, golden harness, the contrast test, and the
  "no raw colours" test.
- `app/`: router (StatefulShellRoute, 4 empty branches), shell (bottom bar / rail), drawer with
  placeholder pages, mini-player slot.
- `core/`: config, logging with redaction, `Result`, prefs store, connectivity.
- `LegacyMigrationPlugin` (Swift + Kotlin) and `LegacyBridge`; migration runner with steps
  m001, m003, m005, m006, m009, m010 (the rest land with their features); fixture-based tests.
- Content: the Markdown conversion is **done** (`content/`, 207 documents, word-for-word
  check passing). Remaining: `tool/build_content_index.py` → `assets/content_index.json`, the
  `MarkdownView` renderer, `tool/build_catalogue.py` → `assets/audio/catalogue.json`, and
  content-integrity tests.

**Acceptance criteria**
- Every document in the index loads and renders in a test; every anchor and internal link
  resolves.
- Catalogue = 11 albums / 138 tracks, ids identical to `main.db`.
- Theme switching works across the empty shell; goldens recorded for components in both themes.
- Migration fixtures (MIGRATION_PLAN §11) pass for the steps in this phase; running twice is a
  no-op.

**Checkpoint:** unit + widget + golden tests green; Android and iOS builds green.

### P2 — Reading experience
**Work:** Steps (Steps | Traditions, Conclusion), Readings (recovery card, Daily Reflections,
prayers, readings, sobriety tips), Big Book (3 segments, grids, continue reading), Reader
(native rendering, links, positions, prev/next, banner slot), Aa sheet, Appearance page,
recovery date screen (m002), cheer sound, onboarding (4 pages + consent hand-off placeholder),
Welcome back.

**Acceptance criteria (per FEATURE_MATRIX rows F-001…F-054, F-100…F-103)**
- Every prayer, reading, guide, chapter and story from both apps is reachable, with unified
  titles.
- Text size steps reproduce the old sizes (migration table) and respect system text scaling.
- Sobriety count is correct across DST, leap years and time-zone changes (unit tests), and an
  Android fixture's date appears unchanged.
- Each screen has loading/empty/error/success states covered by widget tests in both themes and
  at 2.0× text.

**Checkpoint:** tests green; both builds green; owner review build (TestFlight internal + Play
internal) for look and feel.

### P3 — Audio
**Work:** `AudioEngine` (just_audio + audio_service + audio_session), library, album screen,
full player with transcripts and Aa, mini-player, lock-screen controls, auto-advance and loop,
resume position (if A-20), downloads (`background_downloader`), Downloads page, m008 (iOS file
discovery), offline handling.

**Acceptance criteria (F-006, F-060…F-069)**
- Streams all 11 albums; plays, seeks ±10 s, previous/next (BUG-05 fixed), loops.
- Keeps playing with the screen locked on both platforms; media controls work on the lock
  screen / notification; pauses on headphone unplug and on calls.
- Download, queue (max 2), progress, resume after kill, Wi-Fi-only (if A-20), delete per album
  and all; iOS fixture files are recognised in place.
- Offline: downloaded tracks play in airplane mode (Premium); others show the offline message.

**Checkpoint:** tests green; both builds green; real-device background playback test on one
iPhone and one Android phone.

### P4 — Premium and ads
**Work:** `PurchaseGateway` (StoreKit 2 / Billing 8), `Entitlement`, paywall and Premium page,
restore, "manage subscription", legacy flags (m004), donations not consumed (A-04), StoreKit
configuration file, UMP consent and privacy-options row, `AdPolicy`, `AdGateway`, banners,
interstitials, app-open ads, Meta mediation if chosen.

**Acceptance criteria (F-070…F-079b, F-045, F-068)**
- `AdPolicy` unit tests cover every rule in UNIFIED_PRODUCT_SPEC §2.4, including Premium, no
  consent, first launch, paywall, player, cooldowns and counters across restarts.
- Sandbox: subscribe with trial, renew, expire, refund (iOS); buy each donation, reinstall and
  restore (Android licence tester); legacy-flag fixtures grant Premium offline.
- Premium removes every ad surface at once, with no restart.
- Dev and staging builds show only Google test ads (asserted in CI by config check).

**Checkpoint:** tests green; both builds green; sandbox purchase run-through recorded.

### P5 — Reminders
**Work:** `ReminderSchedule`, scheduler, Reminders page, permission flows, quote screen,
notification routing (cold and warm start), "we miss you" (A-13), morning/night reminders only if A-18,
iOS migration m007 via the native channel, FCM if A-17.

**Acceptance criteria (F-090…F-098)**
- Schedule unit tests: ranges, wrap past midnight, 64-limit, DST transitions, time-zone change.
- iOS fixture with legacy pending requests → exactly one set of new requests, legacy ones gone.
- Android 13+ permission denied → switch off + warning card; granted → notifications arrive
  (inexact, within a few minutes).
- Tapping an hourly reminder opens the quote screen from a killed app.

**Checkpoint:** tests green; both builds green; 24-hour soak on one device per platform.

### P6 — Drawer, support and services
**Work:** drawer header (status + price), Premium entry, Help & support (contact per A-14, rate,
share, Facebook), Our other apps (per platform), About (disclaimer, licences), Privacy policy
and Terms links, Privacy & ad choices, Firebase Analytics screen tracking and consent mode,
Crashlytics with redaction, in-app review cadence (A-26), paywall cadence (A-25).

**Acceptance criteria (F-024, F-080…F-089, F-110…F-117)**
- Every drawer item works on both platforms; external links open correctly offline/online.
- No personal data in analytics or crash reports (test inspects logged parameters).

**Checkpoint:** tests green; both builds green.

### P7 — Hardening
**Work:** VoiceOver and TalkBack passes on UJ-1…UJ-12; tablet layouts (rail, two-pane);
performance (cold start < 2 s on a mid-range Android; scrolling at 60/120 fps; app size
budget ≤ 40 MB download); integration tests on CI emulator/simulator; device upgrade tests from
the live store builds (MIGRATION_PLAN §11); store assets (screenshots light/dark, phone/tablet),
privacy label and Data safety drafts; release notes.

**Acceptance criteria**
- All FEATURE_MATRIX rows ✅ or ✖ (owner-approved drop).
- Accessibility checklist (UX_UI_SPEC §9) signed off.
- Upgrade tests pass for every fixture scenario on real devices.

**Checkpoint:** release candidate builds on both platforms.

### P8 — Release
Internal → closed beta → iOS phased release / Android staged rollout with the gates in
MIGRATION_PLAN §10. Rollback plan armed (native rollback branches built and run before 100 %).

---

## 3. Testing checkpoints (every phase)
1. `flutter analyze` + format check.
2. Unit, widget and golden tests (Linux CI).
3. Android build (`android.yml`) and iOS build (`ios.yml`) both green.
4. Feature-matrix rows for the phase updated (☐ → ◐ → ✅) in the same pull request.
5. Short written phase report to the owner: what changed, screenshots, what needs a decision.

---

## 4. Definition of done for a feature row
- Behaviour matches the "Unified Flutter behaviour" column and the screen spec.
- Works in light and dark, at 1.0× and 2.0× text, on a phone and a tablet size, on iOS and
  Android.
- States (loading/empty/error/success) covered by widget tests.
- Semantic labels present; contrast test passes.
- Analytics/crash privacy rules respected.
- Row ticked ✅ with a link to the PR.

---

## 5. Release-readiness checklist

**Identity and versions**
- [ ] Bundle id / applicationId unchanged; version 2.0.0 (≥ 100) on both
- [ ] Signing: iOS distribution certificate and profile; Android upload key + Play App Signing verified with an internal-track update over the live app
- [ ] Firebase config files for the production apps in place (not committed)

**Data and migration**
- [ ] All migration fixtures pass; re-run safe; legacy data checksum unchanged
- [ ] Device upgrade tests from the live store builds (iOS and Android) pass
- [ ] iOS reminder migration verified: no duplicates after update
- [ ] iOS downloads recognised in place

**Purchases**
- [ ] iOS: `annual` subscribe/trial/renew/expire/restore in sandbox; legacy donor restore
- [ ] Android: donation purchase not consumed; restore on reinstall; legacy flag honoured; "Lost your supporter status?" flow works
- [ ] Paywall copy matches store terms (price from the store, trial wording, auto-renew text, Terms and Privacy links)

**Ads and privacy**
- [ ] UMP form shows in UK/EEA (tested via VPN); privacy-options row works
- [ ] Production builds use live units; dev/staging use test units
- [ ] No ads on first launch, onboarding, paywall, purchase flow or over the full player
- [ ] App Store privacy label and Play Data safety updated to match the SDKs
- [ ] `PrivacyInfo.xcprivacy` present; Play foreground-service declaration (media playback) submitted

**Audio and reminders**
- [ ] Background playback, lock-screen controls, interruptions on both platforms
- [ ] All 138 tracks reachable (scripted HEAD check against the audio host before release)
- [ ] Reminders fire on time over 24 h; permission-denied path correct

**Quality**
- [ ] Crash-free sessions ≥ 99.5 % in beta
- [ ] Accessibility sign-off (VoiceOver, TalkBack, 200 % text, contrast)
- [ ] Tablet and landscape layouts checked
- [ ] All FEATURE_MATRIX rows ✅ / ✖
- [ ] Release notes for both stores (new look, dark mode, Traditions on iOS, audio and reminders on Android, minimum OS change)
- [ ] Store listings: names (A-02), descriptions (correct audio hours), screenshots, disclaimer
- [ ] Native rollback branches build and run (Android: Billing 8 + targetSdk 36)
- [ ] Toolkit server keeps `/universal/1/mail.php` working for the old iOS app (R-07)
