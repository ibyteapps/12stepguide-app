# Privacy answers for the stores (draft for the owner)

The App Store privacy label and the Google Play Data safety form must match what 2.0 does
(R-10: today's labels are wrong — the App Store says "Data Not Collected"). These answers come
from the code: the app has no account and no server of its own; the recovery date, reading
positions, reminders and downloads stay on the device. What leaves the device comes from the
Google SDKs:

| SDK | When | What |
|---|---|---|
| Google Mobile Ads (AdMob) + UMP consent | Free users only; after consent where required (UK/EEA) | Device identifiers, IP-derived coarse location, advert interactions, diagnostics |
| Firebase Analytics | Production builds with Firebase configured; off in staging | Screen views by route name only, app version, Premium *type* (no content, no dates, no email) |
| Firebase Crashlytics | Release builds with Firebase configured | Crash and error reports, redacted (no email addresses or dates) |

**Before submitting, compare these answers with Google's own disclosure guides for the SDK
versions in `pubspec.lock`** ("Google Mobile Ads SDK — Apple App Store data disclosure" and
"Google Play data disclosure", and Firebase's equivalents). Google updates them, and the store
forms must cover what the SDKs collect, not only what this app's code does. The iOS privacy
manifest (`ios/Runner/PrivacyInfo.xcprivacy`) lists the same categories.

---

## App Store Connect → App Privacy

**Do you or your third-party partners collect data from this app?** Yes.

| Data type | Collected | Linked to the user | Used for tracking | Purposes |
|---|---|---|---|---|
| Identifiers → Device ID | Yes | No | No | Third-party advertising, Analytics |
| Usage Data → Product Interaction | Yes | No | No | Analytics, Third-party advertising |
| Usage Data → Advertising Data | Yes | No | No | Third-party advertising |
| Location → Coarse Location | Yes (AdMob, from IP address) | No | No | Third-party advertising |
| Diagnostics → Crash Data | Yes | No | No | App functionality |
| Diagnostics → Performance Data | Yes | No | No | App functionality |
| Diagnostics → Other Diagnostic Data | Yes | No | No | App functionality, Analytics |

Not collected: contact info, health and fitness, financial info, user content, browsing or
search history, sensitive info, contacts, purchases (Apple handles them), precise location.

"Used for tracking: No" holds because 2.0 never shows the App Tracking Transparency prompt
(D-008, A-11), so no advertising identifier is available to Google on iOS. If the owner later
adds the ATT prompt, Device ID and Advertising Data become "used for tracking".

## Google Play Console → Data safety

**Does your app collect or share any of the required user data types?** Yes.
**Is all of the user data collected by your app encrypted in transit?** Yes.
**Do you provide a way for users to request that their data is deleted?** No — the app has no
account and keeps no data on a server of its own (same answer as today).

| Data type | Collected | Shared | Processed ephemerally | Required or optional | Purposes |
|---|---|---|---|---|---|
| Location → Approximate location | Yes | Yes (advertising partners) | No | Required | Advertising or marketing |
| App activity → App interactions | Yes | Yes | No | Required | Analytics, Advertising or marketing |
| App info and performance → Crash logs | Yes | No | No | Required | App functionality |
| App info and performance → Diagnostics | Yes | No | No | Required | App functionality, Analytics |
| Device or other IDs | Yes | Yes | No | Required | Advertising or marketing, Analytics, Fraud prevention |

**Advertising ID declaration:** yes, the app uses the advertising ID (adverts for free users;
`AD_ID` permission comes from the Google Mobile Ads SDK).

## Other Play Console declarations for 2.0

- **Foreground service (media playback):** the app uses `FOREGROUND_SERVICE_MEDIA_PLAYBACK` for
  audio that keeps playing with the screen off. Describe it as "Plays recovery audio the user
  started, with controls in the notification", with a short screen recording.
- **Notifications:** `POST_NOTIFICATIONS` is asked only when the user turns a reminder on.
- **Exact alarms:** not used (reminders are inexact).
- **Ads:** "Contains ads" stays Yes.
- **Target audience and content rating:** unchanged.
