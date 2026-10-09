# 12 Step Guide (Flutter)

The unified Flutter rebuild of **12 Step Guide** (iOS `com.ibyteapps.aa12stepguide`, App Store
id 1238097883; Android `com.ibyteapps.aa12stepguide`), shipping to both stores as version 2.0
in place of the two native apps.

**Status (9 Oct 2026):** planning complete; first owner decisions recorded in
[DECISIONS.md](DECISIONS.md); all literature converted to Markdown in [content/](content/README.md).
No Flutter code yet.

| Document | What it is |
|---|---|
| [CURRENT_APP_AUDIT.md](CURRENT_APP_AUDIT.md) | What the two native apps do today: screens, journeys, data, endpoints, purchases, ads, defects |
| [FEATURE_MATRIX.md](FEATURE_MATRIX.md) | Every feature side by side with its unified behaviour. **The running checklist** |
| [UNIFIED_PRODUCT_SPEC.md](UNIFIED_PRODUCT_SPEC.md) | The combined product: navigation, drawer, screen map, screen-by-screen requirements, edge cases |
| [UX_UI_SPEC.md](UX_UI_SPEC.md) | Design system, light/dark tokens with measured contrast, typography, components, Mobbin research |
| [FLUTTER_ARCHITECTURE.md](FLUTTER_ARCHITECTURE.md) | Stack, layers, folders, packages and why, data flow, testing, CI |
| [MIGRATION_PLAN.md](MIGRATION_PLAN.md) | Moving users from the native apps safely: keys, purchases, reminders, downloads, release and rollback |
| [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) | Phases, dependencies, acceptance criteria, release checklist |
| [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | Uncertainties, what's needed from the owner, decisions awaiting approval |
| [DECISIONS.md](DECISIONS.md) | Owner decisions, dated, with what each commits the build to |
| [content/README.md](content/README.md) | The literature as Markdown: folders, file format, known source issues |

**Folders:** `content/` (literature, Markdown) · `content-source/` (original HTML and the legacy
audio database, for reference and re-conversion) · `tool/` (converters and checks).

**Never change:** the bundle id / applicationId, product ids, Firebase project
`aa-12-step-guide`, the audio URLs, and the iOS download location `Documents/{file_name}`.
`FLUTTER_ARCHITECTURE.md` §0 explains why.
