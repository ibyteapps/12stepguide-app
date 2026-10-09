# 12 Step Guide — Open Questions, Needs and Decisions

Three lists: what is still uncertain (§1), what I need from you (§2), and the decisions that
need your approval before the matching phase starts (§3). When you decide, the decision is
recorded in `DECISIONS.md` (dated, with what it commits the build to), the same way the Toolkit
does it.

**Decided so far (9 Oct 2026):** A-01 → D-001 (navigation), A-08 → D-002 (step text), A-23 →
D-003 (literature as Markdown), Q-P1 → D-004 (no newer iOS source). Q-C3 is resolved by the
conversion (the 30th file never existed).

---

## 1. Uncertainties

| ID | Question | Why it matters | How to resolve |
|---|---|---|---|
| Q-P1 | ~~Is there a newer iOS project?~~ **Answered: no (D-004).** | — | — |
| Q-P2 | Do you ever send push campaigns from the Firebase console to this app? | Decides whether FCM stays (A-17) | You confirm |
| Q-P3 | Is the audio host `scripts.12stepapp.com/tracks/` on your Fasthosts/Plesk server, and is it staying? Any plan to move it? | Audio, including the new Android audio, depends on it entirely | You confirm; I can add an uptime check |
| Q-P4 | Is **Meeting Finder** (`com.ibyteapps.meetingfinder`) still live on Play? Are the five iOS "other apps" ids still the ones to promote? | "Our other apps" list | You confirm the lists per platform |
| Q-P5 | Which privacy policy URL is current: `12steptoolkit.com/privacy-policy-ibyte/` (iOS) or `/privacy` (Android)? The Toolkit's new Laravel site has `/privacy` | Both apps should link to one page, and it must keep working after the Toolkit site moves | You confirm |
| Q-P6 | Keep the iOS app available on Apple-silicon Macs and visionOS? | It is offered there today by default | You confirm (default: keep) |
| Q-L1 | What did the 2021 AAWS complaint require? The only record is the iOS changelog line "1.21 (2021/10/16) AAWS Complaint Compliance". Diffing 1.20 → 1.21 shows that build only renamed things: "AA Speaker Tapes" → "Speaker Tapes", "Big Book - Alcoholics Anonymous" → "The Big Book", "AA Daily Reflections" → "Daily Reflections", "Recovery Box - AA 12 Step Toolkit" → "12 Step Toolkit". "AA Big Book", "Alcoholics Anonymous Literature" and "AA 12 Step Guide" were missed on iOS; Android never changed | Both apps may still carry names AAWS objected to; the circle-and-triangle symbol is used on both | Search your email for "AAWS", "Alcoholics Anonymous World Services" or an App Store "notice of infringement" around Sept–Oct 2021; otherwise apply A-03 |
| Q-L2 | Content rights, separate from naming. The Markdown conversion showed that the Big Book "Preface" is the **fourth-edition (2001)** preface, the 2nd-edition stories date from 1955, the app quotes the Steps and Traditions wording, and "The Preamble" is an altered version of a Grapevine text. The store description says the app uses public-domain content | Later-edition text may still be in copyright; it is worth checking before a relaunch draws attention | You decide whether to get advice; I can list exactly which documents are first-edition (1939) text |
| Q-C1 | ~~Android 2024 step text on iOS too?~~ **Answered: yes (D-002).** | — | — |
| Q-C2 | The step guides contain `ibyteapps@gmail.com` as a personal contact; Android support uses `ibyteappsuk@gmail.com`. Which address should the app use for support? | Contact flow (A-14) | You confirm |
| Q-C3 | ~~What is `stories1_30.html`?~~ **Resolved:** the Android list named 30 files but only 29 exist | — | — |
| Q-S1 | iOS subscription group id and whether the 7-day trial is still configured for new subscribers | StoreKit configuration and paywall copy | App Store Connect → Subscriptions |
| Q-S2 | Are the iOS donation tiers still "cleared for sale" in App Store Connect (the store page lists them)? | Testing legacy-donor restore; whether to keep or retire them | App Store Connect |
| Q-S3 | Roughly how many Android donors and active iOS subscribers are there? | Sizes the A-04 risk and the paywall changes | Play Console / App Store Connect |
| Q-D1 | Share of users on iOS < 15 and Android 6.0 | Sizes the minimum-OS impact (A-16) | App Store Connect Analytics, Play Console statistics |
| Q-T1 | Commit Firebase config files (public identifiers) or keep them out of git? | The Toolkit keeps secrets out; Firebase files are not secret but you may prefer them out | You choose (default: out of git, generated with `flutterfire configure`) |
| Q-T2 | Who holds the Android **upload key** and the Apple distribution certificate? | Without them the update cannot replace the live app | You confirm; see §2 |
| Q-B1 | Do you want server features later (own subscription verification, support tickets, remote ad pacing) like your other apps? | Not needed for 2.0 (A-15); affects seams only | Decision A-15 |

---

## 2. What I need from you

**Access** (none of these should be pasted into chat):

1. **GitHub repo** `ibyteapps/12stepguide-app` created (private, empty) and added to the
   Claude GitHub app. Then tell me and I attach it with push access.
2. **Firebase**: either add me nothing and run `flutterfire configure` yourself on your Mac
   (I'll give the exact commands), or download the existing `google-services.json` and
   `GoogleService-Info.plist` for project `aa-12-step-guide` and put them in
   `Websites/12StepGuide/app/` locally. They stay out of git.
3. **Signing, for CI release builds later (P8):** Android upload keystore + passwords and an App
   Store Connect API key, added by you as **GitHub encrypted secrets** (I'll give the names).
   Until then CI builds unsigned and you sign on your Mac.
4. **Sandbox / testing:** an App Store sandbox tester account; on Play, add your test Google
   account as a **licence tester**. Ideally keep one device that has the **current store
   versions** installed with real data (date, reminders, downloads, a purchase) for the upgrade
   test.
5. **AdMob:** confirm the existing ad unit ids are the ones to keep (I have them from the source;
   they go into gitignored config). If you want Meta via mediation, add the Meta adapter in the
   AdMob console.

**Assets**

6. ~~App icon decision (A-22)~~ Decided (D-007): a new icon on both platforms, designed in the
   repo (`assets/branding/`). Nothing needed from you unless you want changes.
7. Any onboarding or store screenshot artwork you want kept (the old onboarding images are in the
   projects and can be reused).
8. The AAWS complaint text or a summary (Q-L1).

**Backend:** nothing for 2.0 if A-15 is approved. The only server dependency is the existing
audio host (unchanged).

---

## 3. Decisions requiring your approval

**Blocking for the first phases.** The rest can be decided as their phase approaches. Each line
gives the recommendation first.

| ID | Decision | Recommendation | Alternatives | Phase |
|---|---|---|---|---|
| A-01 | ~~Primary navigation~~ | **Decided: D-001** | — | — |
| A-03 | ~~Naming / AAWS compliance~~ | **Decided: D-005** | — | — |
| A-08 | ~~Step-guide text~~ | **Decided: D-002** | — | — |
| A-23 | ~~How literature is displayed~~ | **Decided: D-003** | — | — |
| A-02 | Name under the icon | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-04 | Android donors after reinstall (Billing 8 has no purchase history) | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-05 | Premium benefits and lapsed downloads | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-06 | Android products | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-07 | Hidden "Conclusion" chapter | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-09 | ~~Toolkit leftovers~~ | **Decided: D-006** | — | — |
| A-10 | Ad pacing | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-11 | Ad consent | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-12 | iOS reminders on upgrade | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-13 | "We miss you" nudges | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-14 | Contact us | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-15 | Backend | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-16 | Minimum OS | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-17 | Firebase Cloud Messaging | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-18 | Morning and night reminders: implemented in the iOS code but **hidden** from users (no one can turn them on); Android has none | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-19 | Reading comfort | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-20 | Optional extras | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-21 | "Classic layout" option (like the Toolkit's D-011) | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-22 | ~~Icon and brand direction~~ | **Decided: D-007** (new icon on both) | — | — |
| A-24 | Audio catalogue | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-25 | Paywall auto-show | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
| A-26 | Review prompt | **Provisional: D-008** (built as recommended; confirm or change) | — | — |
