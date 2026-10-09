# 12 Step Guide — Migration Plan

How the Flutter app replaces both native apps **as an in-place update** (same store listings,
same identifiers) without losing anyone's date, reminders, downloads, purchases or ad-free status,
and how to back out if it goes wrong.

---

## 1. Principles

1. **Update, never a new app.** Same bundle id, applicationId, product ids, Firebase apps and
   AdMob apps.
2. **Read legacy data; never modify or delete it.** The new app writes only its own keys
   (`app.*`, `premium.*`, `reminders.*`, `sobriety.*`, `reader.*`, `ads.*`). The single
   exception is cancelling the native app's pending iOS notifications (§6), which must happen or
   users get every reminder twice.
3. **Idempotent, step-wise, retryable.** Each migration step has an id, runs once, records
   `done` / `failed`, and a failed step retries on the next launch. One failed step never
   blocks the app or the other steps.
4. **Conservative upgrade detection.** If any recognised legacy key exists, treat the device as
   an upgrade (a false "new user" would hide someone's data behind onboarding).
5. **Tested with real legacy fixtures** before release (§11).

---

## 2. Identifiers and versions

| Item | iOS | Android | Action |
|---|---|---|---|
| App id | `com.ibyteapps.aa12stepguide` | `com.ibyteapps.aa12stepguide` | Keep |
| Signing | Existing team / distribution certificate | **Existing upload key** + Play App Signing | Owner provides access (Q-T2). Without the right Android key the update cannot be published |
| Version | 2.0.0, build 100 (store has 1.51; project file 1.21) | versionName 2.0.0, versionCode **100** (live: 29) | `pubspec.yaml: version: 2.0.0+100` |
| Display name | "12 Step Guide" | "12 Step Guide - AA" → "12 Step Guide" | A-02 |
| Store name | "12 Steps Guide" | "12 Step Guide - AA" | Listing text only, owner's call (A-02) |
| Firebase | `aa-12-step-guide` iOS app | `aa-12-step-guide` Android app | Same apps → analytics and Crashlytics continue |
| AdMob app ids | existing `~5296879139` | existing `~6070100472` | Same → reporting continuity |
| Ad units | existing banner/interstitial/app-open | existing (+ Meta placement ids) | Same units (via config) |
| Products | `annual`; `…donatetier5/10/20` | `donatetier1/2/3` | Same; A-06 may add an Android `annual` |
| Subscription group | unknown — needed for StoreKit testing and the "Manage" link | n/a | Q-S1 |
| URL schemes / deep links | Google + LinkedIn schemes (unused) | none | Dropped (D-006); no inbound links exist |
| Notification channel ids | n/a | none existed | New ids (no legacy settings to preserve) |
| Min OS | 12.1 → **15.0** | 23 → **24** | §8 |
| Launcher activity | n/a | `com.ibyteapps.aa12stepguide.First` | Keep: the Flutter activity is named `First`, so home-screen icons that point at this component survive the update (some launchers delete an icon whose activity disappears) |

---

## 3. Migration runner

`features/migration/` runs during splash, before the router decides on onboarding:

```
LegacyBridge.readSnapshot()          // native channel, read-only
  → isUpgrade? (any recognised key)
  → run steps m001…m010 that are not yet `done`
  → write `migration.version = 1`, `migration.completedAt`
  → if upgrade and not yet shown: route to Welcome back (S-03)
```

| Step | What | Platforms |
|---|---|---|
| m001 | Launch counter, onboarding flags → `app.launchCount`, `onboarding.done = true` | both |
| m002 | Sobriety date | Android |
| m003 | Reader text size | both |
| m004 | Premium: legacy lifetime flags + cached subscription state | both |
| m005 | Ad pacing counters and last app-open time | both |
| m006 | Rate-prompt bookkeeping | both |
| m007 | Reminders: read settings **and actual pending requests**, cancel legacy requests, write new settings | iOS |
| m008 | Downloads: discover existing files, mark downloaded, exclude from backup | iOS |
| m009 | Upgrade summary for the Welcome-back screen | both |
| m010 | Tooltip / coach-mark seen flags | Android |

---

## 4. Preference mapping

### 4.1 iOS (`NSUserDefaults`, standard domain — read through the native channel, because
`shared_preferences` only sees `flutter.`-prefixed keys)

| Legacy key | Type | New key | Rule |
|---|---|---|---|
| `launchcount` (and old `launchCount` if > 0) | Int | `app.launchCount` | Copy the larger (the iOS value is real launches + 1; harmless) |
| `FLAG_UPGRADE_1`, `FLAG_ONBOARDING_UPDATE_SHOWN`, `launchcount > 0` | Bool/Int | `onboarding.done = true` | Any present → upgrader |
| `KEY_DATA_INT_FONT_SIZE` | Int px | `reader.textStep` | 0 or 18 → 3; 24 → 6; 30 → 8; anything else → nearest |
| `FLAG_NOTIFICATIONS_HOURLY`, `KEY_DATA_STRING_HOURLY_NOTIFICATION_START_TIME`, `…_END_TIME` | Bool, "HH:mm" | `reminders.hourly.{enabled,start,end}` | See §6 |
| `FLAG_NOTIFICATIONS_ON_AWAKENING`, `KEY_DATA_STRING_ON_AWAKENING_NOTIFICATION_TIME` | Bool, "HH:mm" | `reminders.morning.{enabled,time}` | §6 |
| `FLAG_NOTIFICATIONS_NIGHT_TIME`, `KEY_DATA_STRING_NIGHT_NOTIFICATION_TIME` | Bool, "HH:mm" | `reminders.night.{enabled,time}` | §6 |
| `com.ibyteapps.aa12stepguide.donatetier5_PURCHASED` / `…10_…` / `…20_…` | Bool | `premium.legacyLifetime = true`, `premium.legacySource = ios-donation` | Any true → lifetime. StoreKit 2 should also list these non-consumables; either source is enough |
| `annual_PURCHASED`, `KEY_SUBSCRIPTION_EXPIRY` | Bool, String | `premium.cache = {type: annual, until: …}` | Used only until StoreKit 2 answers (avoids an ad flash when offline at first launch); StoreKit 2 is the truth |
| `LastShownAppOpenAd` | Date | `ads.lastAppOpenAt` | Copy |
| `KEY_DATA_INT_TAP_COUNT` | Int | `ads.contentOpenCount` | Copy modulo 3 |
| `KEY_SUBSCRIPTION_DETAILS`, `annual` (price), `KEY_DATA_INT_CURRENT_*`, `KEY_DATA_INT_PENDING_INTENT`, `FLAG_IS_SHOWING_SUBSCRIPTION_SCREEN`, sponsorship flags, `KEY_DATA_STRING_EMAIL`, `tapcount` | — | — | Not migrated (derived, transient or leftovers) |

### 4.2 Android (default `SharedPreferences`: `com.ibyteapps.aa12stepguide_preferences.xml`; Flutter writes its own `FlutterSharedPreferences.xml`, so there is no collision)

| Legacy key | Type | New key | Rule |
|---|---|---|---|
| `mKeyStepDatalaunchCount_aa12stepguide_aa12stepguide` | Int | `app.launchCount` | Copy |
| `onBoardingShown` | Bool | `onboarding.done` | Copy; also an upgrader signal |
| `myAppDay`, `myAppMonth`, `myAppYear` | Long ×3 | `sobriety.date` (ISO `yyyy-MM-dd`) | Only if day ≥ 1; month is 1-based; reject impossible dates (log non-fatal, keep unset); clamp to today if in the future |
| `mKeyStepDatahtmlsize_aa12stepguide` | Int 0/3/6 | `reader.textStep` | 0 → 3, 3 → 6, 6 → 8 |
| `donatetier1_aa12stepguidepurchased_aa12stepguide` (and tiers 2, 3) | Bool | `premium.legacyLifetime = true`, `premium.legacySource = android-donation` | Any true → lifetime. See §5.2 |
| `mKeyStepDatatimeShownLiterature_aa12stepguide_aa12stepguide` | Int | `ads.contentOpenCount` | Copy modulo 3 |
| `mKeyStepDatarate_shown_aa12stepguide`, `ratedapp_aa12stepguide`, `rated` | Int/Bool | `review.promptCount`, `review.rated` | Copy |
| keys ending `COUNT_TIPPED_aa12stepguide` | Int | `reader.coachMarkSeen` | Any > 0 → true |
| `canplayaudio`, `datafetched`, `tabno`, `accountid`, `mLastClickTime…`, `2SHOWONCE…`, price keys | — | — | Not migrated |

---

## 5. Purchases and entitlement

### 5.1 iOS
- **Annual subscribers:** StoreKit 2 `Transaction.currentEntitlements` returns the active
  `annual` transaction on first launch, with no user action. Trial, grace and expiry come from
  StoreKit. `verifyReceipt` and the shared secret are retired.
- **Legacy donors** (`donatetier5/10/20`): StoreKit 2 returns non-consumables in current
  entitlements, and the migrated flag (m004) covers them even before StoreKit answers. Lifetime
  Premium.
- **Restore** remains available (it calls `AppStore.sync`) for new devices.
- Test: StoreKit configuration file in the repo (product ids, trial), sandbox accounts for
  renewals and expiry, a sandbox account that owns a legacy tier (needs a tester account
  created *before* the tiers are removed from sale, or the tiers kept "cleared for sale"
  but hidden — Q-S2).

### 5.2 Android — the consumed-donation problem (decision A-04)
The native app **consumes** each donation, then rebuilds ad-free status from purchase history.
Billing 8, which the Flutter plugin uses and Play requires for updates, has **no purchase-history
API**, and consumed items do not appear in `queryPurchases`.

| Case | Covered by | Result |
|---|---|---|
| Donor updates in place | m004 reads the legacy flag | ✅ ad-free kept |
| Donor's device is restored from a Google backup that contains the old app's prefs | `allowBackup` is kept on; the legacy prefs file is restored; m004 reads it | ✅ usually |
| Donor reinstalls with no backup, or wiped data | — | ❌ shows ads |
| New donation in 2.0 | Recommended: **do not consume** new donations, so they stay owned and `queryPurchases` returns them forever | ✅ restorable |

**Recommendation (A-04):** do all three of the following.
1. Migrate the flag.
2. Stop consuming new donations. A user can still donate again at another tier, because the tiers
   are separate products.
3. Add a "Lost your supporter status?" link on the Premium page. It opens an email to support
   with the platform pre-filled. The owner verifies the Google order number in the Play Console
   and sends a Play promo code for a hidden non-consumable `supporter_lifetime` product (no
   server needed).

A server record of donors (option C) is only worth it if A-15 brings in a backend.

### 5.3 Entitlement rules after migration
`premium = legacyLifetime ∨ storeLifetime(nonconsumable owned) ∨ storeSubscriptionActive`.
The cache is refreshed on every launch and every purchase event. A legacy lifetime flag is never
cleared by the app. Refunds and revocations of store items clear their store-derived
entitlement only.

---

## 6. Reminders (iOS) — avoid duplicates, honour what users actually get

The native app schedules `UNNotificationRequest`s with these identifiers:
`HourNotification{h}{h}` for each hour in range (e.g. `HourNotification88`),
`KEY_DATA_STRING_ON_AWAKENING_NOTIFICATION_TIME`, `KEY_DATA_STRING_NIGHT_NOTIFICATION_TIME`,
`3days`, `7days`. They survive an app update and would keep firing beside the new app's own.

**m007:**
1. Ask the native channel for pending requests (the Flutter plugin works with numeric ids and
   is not a reliable way to read the legacy string ids).
2. For each reminder type, set the new setting from **what is actually pending**, because the
   flag is unreliable (BUG-03: new installs show "on" with nothing scheduled):
   - Hourly: enabled if ≥ 1 `HourNotification*` request is pending. The window comes from the
     **stored** start/end strings, not from the pending hours: the native app never cancels hours
     outside a narrowed window (BUG-23), so the pending set can be wider than what the user chose.
     Hours are read from each request's trigger components, never parsed from the id
     (`HourNotification1010`). If none is pending: disabled, but the stored start/end are kept so
     the screen shows the user's times when they switch it on.
   - Morning / night: their cells are hidden in the shipped app, so normally nothing is pending.
     Anything found is cancelled. They are enabled only if A-18 brings the feature in and a
     request was pending.
   - "We miss you": not migrated; the new rule (A-13) applies.
3. Cancel all legacy request ids (`removePendingNotificationRequests`) and remove delivered
   legacy notifications from Notification Centre.
4. Schedule the new set through the scheduler.
5. If any step fails, legacy requests are **left in place** and the new ones are **not**
   scheduled until the step succeeds. Duplicates are worse than one missing day.

**Owner choice A-12:** the alternative is "honour the flag" — turn hourly on for everyone whose
flag says on, which would start ~15 notifications a day for users who have never received
them. Not recommended.

Legacy hourly notifications already delivered and sitting in Notification Centre mostly carry
`userInfo.action`. The native channel maps a tap on one of those to `/quote`, so the old behaviour
still works on the first day. The start-hour notification (BUG-02) and the "we miss you" ones
carry no `action`; a tap on them just opens the app (the new app never force-unwraps payloads).

**Android:** nothing to migrate. Reminders are off until the user turns them on (onboarding or
the Reminders page). Android 13+ asks for `POST_NOTIFICATIONS` at that moment.

---

## 7. Downloads (iOS)

- Existing files are in `Documents/{file_name}` (flat). The new `DownloadStore` uses the same
  directory on iOS, so **nothing is moved or copied**.
- m008 lists `Documents`, matches file names against the catalogue, and checks the size is
  above zero and within ±2 % of the catalogue size (when known). Matches are marked downloaded.
  Anything else (`main.db`, unknown files) is left alone.
- Partial downloads left by the old background `URLSession` cannot be resumed (the session
  belonged to the old binary). They show as not downloaded and can be downloaded again.
- Downloaded files are excluded from iCloud backup from now on (they are re-downloadable).
- `Documents/main.db` stays where it is, untouched, so a rollback to the native app finds it.
- Premium rule A-05 decides whether a lapsed user's files play locally or stream.

---

## 8. Platform and compatibility changes

| Change | Who is affected | Mitigation |
|---|---|---|
| iOS minimum 12.1 → 15.0 | iPhone 6 / 5s and iOS 12–14 users | They keep 1.51 from the store (Apple serves the last compatible version). Note in release notes. Check App Store Connect → Analytics → iOS version share first (Q-D1) |
| Android minSdk 23 → 24 | Android 6.0 devices | Play keeps serving build 29 to them. Check Play Console → Statistics by API level (Q-D1) |
| Android gains `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED` (reminders and audio) | All Android users | Play declarations: foreground service type "media playback". Runtime prompt only for notifications |
| Android drops `READ_PROFILE`, `requestLegacyExternalStorage`, `largeHeap`, `org.apache.http.legacy` | — | None needed |
| iOS drops ATS arbitrary loads, Face ID string, Sign in with Apple entitlement, unused URL schemes, `armv7` capability; keeps background audio; `remote-notification` only if A-17 | — | None needed |
| iOS adds `PrivacyInfo.xcprivacy` (UserDefaults, file timestamp, disk space reasons) | — | Required for submission |
| App Store privacy label: "Data Not Collected" → must declare Identifiers (device ID for ads), Usage Data, Diagnostics, linked to tracking = No | iOS | Update before submission (R-10) |
| Play Data safety: device ids (ads, analytics), crash logs, app interactions; "data can't be deleted" stays (no server data) | Android | Update before rollout |
| Android naming brought in line with AAWS compliance (D-005) | Android users | "What's new" mentions the new look |
| Play app name (A-02) | Android | Listing change |
| New app icon on both platforms (D-007) | Everyone | It keeps the navy book (Android) and sky blue (iOS) so users still find it; "What's new" and the store screenshots show it. Upload `assets/branding/store/` icons to both store listings |

---

## 9. Risks

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Android donors lose ad-free status after a reinstall | Medium | Medium (goodwill) | §5.2 recommendation |
| R-02 | Audio host down or slow; no monitoring | Low–Medium | High (Android users newly depend on it) | Uptime check on one track URL; graceful errors; ask about a CDN (Q-B1) |
| R-03 | Users on iOS 12–14 / Android 6 stop getting updates | Certain for them | Low (they keep the old app) | Release notes; data check first |
| R-04 | AAWS compliance on Android | Unknown | High (takedown) | iOS naming applied everywhere, gaps closed (D-005); complaint scope still unknown (Q-L1) |
| R-05 | UMP lowers EEA/UK ad revenue at first | High | Medium | Required by Google; no alternative |
| R-06 | Step-guide text change noticed by one audience | Certain | Low–Medium | A-08; mention in release notes |
| R-07 | Toolkit server cut-over breaks `/universal/1/mail.php`, which the **old** iOS contact form uses | Medium | Low–Medium | Keep or redirect that path in the Toolkit Laravel app until 2.0 adoption is high; A-14 removes the dependency from 2.0 |
| R-08 | Version collision blocks upload | Low | High | 2.0.0 (100) |
| R-09 | Duplicate hourly notifications on iOS | Medium without m007 | High (annoying, uninstalls) | m007 + integration test with fixture requests |
| R-10 | Store privacy declarations wrong | Certain today | Medium (review rejection, compliance) | Fix both forms before submission |
| R-11 | "150+ hours" claim vs ~94 h catalogue | Certain | Low | Correct listing copy |
| R-12 | Upload key or Apple team access unavailable | Unknown | Blocking | Q-T2 early |
| R-13 | Background audio rejected by review if no audio is playing on launch | Low | Medium | Session activated only on play; no silent audio |
| R-14 | Legacy notification tap from Notification Centre after update | Low | Low | Native mapping to `/quote` (§6) |

---

## 10. Release strategy

1. **Internal:** TestFlight internal group and Play internal testing, owner + 2–3 testers, for
   at least one week. Upgrade tests from the live store builds on real devices (§11).
2. **Closed beta:** TestFlight external group / Play closed testing, invited long-time users
   (if the owner has a list), one to two weeks. Watch Crashlytics crash-free users ≥ 99.5 % and
   reminder/download feedback.
3. **Production:**
   - iOS: **phased release** over 7 days (pausable at any point).
   - Android: **staged rollout** 5 % → 20 % → 50 % → 100 %, at least 48 h per step.
   - Gates between steps: crash-free users ≥ 99.5 %, no P1 bug, ANR rate < 0.47 %, purchase
     success rate not below the previous 30-day baseline, ad revenue per DAU not below 70 % of
     baseline (UMP effect expected).
4. Store listing updates go live with 100 %: screenshots (light and dark), description,
   privacy forms, "What's new".

---

## 11. Testing the migration

- **Fixtures:** captured legacy prefs (iOS plist dump, Android XML) for: new user; iOS
  subscriber; iOS legacy donor; iOS user with hourly on and pending; iOS user with flag on and
  nothing pending (BUG-03); iOS user with downloads; Android donor; Android with sobriety date;
  Android with a future date; corrupted values. Unit tests run every step against each fixture.
- **Device upgrade tests** (manual, both platforms): install the live store build, set state
  (date, text size, reminders, downloads, purchases with sandbox/licence testers), then update
  to the TestFlight / Play internal build and verify each item against §4–§7. On Android the
  update must come from Play (internal testing) so the signing key matches.
- **Re-run safety:** launch the migrated app twice and confirm no step runs again, nothing is
  duplicated, and legacy data is unchanged (checksum the legacy prefs before and after).

---

## 12. Rollback

The stores do not allow installing an older version number, so a rollback means **shipping the
native app again with a higher version number**. The plan keeps that path open:

- Keep both native projects buildable: update the iOS project's version to 2.0.1 and Android
  versionCode to 101 in a branch, and verify both **build and run** before the 2.0 rollout
  starts. The Android rollback build also has to meet Play's current rules for updates
  (Billing Library 8, targetSdk 36). Billing 8 has no purchase history, so that branch must stop
  clearing the donation flags and must read `queryPurchases` instead. Without that change, the
  native app would hit the same donor problem as §5.2, and worse, because it clears the flags.
- Because the new app never modifies or deletes legacy keys, `main.db` or downloaded files, a
  re-released native app finds the user's data as it left it. Only the cancelled iOS
  notifications are gone, which leaves the native app in its normal "flag on, nothing
  scheduled" state (BUG-03). Users re-enable reminders.
- **Triggers:** crash-free users < 98 %, purchase failures above baseline, data-loss reports, or
  store rejection loops.
- **Before rollback, prefer a pause:** halt the Android staged rollout and pause the iOS phased
  release, then ship a 2.0.x hotfix (expedited review on iOS).
- Purchases made in 2.0 (StoreKit 2 / Billing 8) are standard store transactions that the native
  app can also see: iOS restore finds them, and on Android, donations made in 2.0 are **not
  consumed**, so `queryPurchases` in the rollback build finds them.
