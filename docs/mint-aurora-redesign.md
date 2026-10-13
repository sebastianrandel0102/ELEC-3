# SaveTrack — Mint Aurora redesign

Implemented in the existing application on **13 October 2026**. This report supersedes the earlier visual audit in `UI_REDESIGN.md`.

## Scope and initial findings

The repository already contained a previous mint redesign. Authentication and the original personal savings/planner screens had reusable styling, but newer collaborative savings, currency and photo flows did not consistently use it. Shared forms and activity screens relied on plain text blocks; notices had little hierarchy; currency selection had no coherent surface treatment; authentication repeated the same card composition; hero artwork and financial typography needed refinement. The earlier report also predated the implemented collaboration, currency, photo and recommendation features.

Reviewed `pubspec.yaml`, startup/session routing, all 28 Dart source files, the existing theme, assets, navigation, form controllers and disposal, stream bindings, dialogs, recommendations, progress visualizations, platform targets and the existing test suites. There is no separate personal goal-detail route: the existing goal card contains balance, progress, deadline, pace and actions. There is no separate weekly planner or reminder feature; the existing weekly task report remains the weekly presentation.

## Visual direction and design system

The existing `SaveTrackDesign` is extended rather than replaced. Mint Aurora combines midnight emerald, forest mint and luminous accents with an airy canvas and disciplined typography.

- **Palette:** midnight `#063F34`, deep emerald `#0B5948`, forest mint `#117B63`, premium mint `#24A987`, fresh mint `#48CFA6`, luminous mint `#75E2BE`, soft mint `#A8F0D5`, pale mint `#DDF9ED`, mist `#EEFCF5`, canvas `#F6FBF8`, ink `#16382E`, borders `#E2EFE8` and dividers `#EBF3EF`. Supporting text and semantic foregrounds use darker accessible tones. Decorative muted mint is not used for small body text.
- **Typography:** bundled Manrope replaces the default application typeface, with semibold headings, clearer hierarchy and tabular financial figures. GoogleSans remains specific to the existing branded Google action. The variable font and its SIL Open Font License are included locally, with no font network requests or new package dependency. Source: [Google Fonts Manrope](https://github.com/google/fonts/tree/main/ofl/manrope).
- **Gradients:** contrast-safe signature and deep emerald gradients carry white text. The full midnight-to-luminous spectrum is reserved for progress accents. Glow and white-to-mint surface gradients support selected contexts. Main content remains on quiet solid surfaces.
- **Layout tokens:** 4/8/12/16/24 spacing, 12/16/22/30 radius hierarchy, subtle emerald shadows, existing 1080-pixel page limit and a new 760-pixel navigation limit. Cards retain variable heights and text wrapping.
- **Backgrounds:** static radial mint canvas and fine curved contours in heroes and modal headers. The artwork is decoration, not fabricated financial or productivity data. No blur filters, constantly animated backgrounds or new image dependencies are used.

Reusable presentation includes `AuroraEmblem`, `TonalPanel`, `AmountText`, `AuroraNotice`, `AuroraTabs` and `SharedGoalHero`, together with the improved existing `MintHero`, `MintIcon`, `MintProgress`, `GradientButton`, `ScreenIntro`, `FormHeading`, `StatusPill`, `ProgressRing` and adaptive layouts.

## Screen inventory and completed presentation

| Existing screen or flow | Completed changes |
| --- | --- |
| Startup/session loading and setup error | New emblem and theme; original initialization, session check and error routing retained, with no added delay |
| Login and registration | Editorial emerald introduction, clearer welcome copy, open mobile form composition, split desktop composition, refined fields and primary action; Google branding and all authentication controls retained |
| Password recovery and change password | Shared aurora modal headers, typography, inputs and action styling; verification, password policy, resend cooldown, blocking conditions and dismissal behavior retained |
| Dashboard | Refined greeting, readable savings hero, translucent target/count summary, larger compact metric figures, quieter preview surfaces and constrained navigation; original responsive composition and real streams retained |
| Personal savings and goal information | Segmented Personal/Shared selector, tonal financial grouping, stronger amount hierarchy, refined icons and progress, accurate statuses/deadlines/pace, history and all existing goal actions |
| Create/edit goal and task forms | Consistent contextual headings, financial typography, themed fields, selectors, modal surfaces and actions; original fields, controllers and validation retained |
| Add/decrease savings | Focused current-balance panel, larger amount entry, currency selection spacing, clear existing conversion/new-balance previews and warning/error treatment; authoritative denomination, locked rates and retry behavior retained |
| Transaction history | Clearer amount hierarchy and semantic deposit/decrease icon colors; exact stored amounts, conversion information, notes, dates and ordering retained |
| Shared goal overview | Refined icon headers, larger combined balances, readable status/member hierarchy and coherent participant avatars |
| Shared goal details | Deep aurora financial hero, accurate progress and existing report/contribution/activity sections; owner/member action visibility retained |
| Shared goal creation/settings | New milestone introduction, grouped milestone/timing fields, prominent target entry and consistent date/icon selectors |
| Contribution/group decrease | Contextual heading, prominent live balance/amount entry, currency and note grouping; original attribution, request locking and transactions retained |
| Members | Clear group context and stronger contribution figures; role/status/share displays, remove confirmation and ownership restrictions retained |
| Generate/revoke/redeem invitations | Circle introduction, intentional code surface, readable status badges and consistent join form; single-use codes, expiry, clipboard action and decision locking retained |
| Shared activity/history | Stronger signed amounts, clear member attribution, date details and note spacing; pagination, refresh, access checks and chronological grouping retained |
| Daily planner | Tonal date navigation, compact progress summary, calmer task surfaces, priorities and completion controls |
| Smart suggestions | Auroral featured task, quiet summary, ranked next-task treatment and contextual explanation sheet; original recommendation ordering, scheduling/conflict logic and callbacks retained |
| Reports | Refined savings hero, task completion rings, metric typography and shared report styling; no new trend series, synthetic chart values or aggregation changes |
| Profile/account preferences | Personal account hero, stronger identity typography, concise currency setting copy, grouped account rows and consistent logout action |
| Currency settings/picker/converter | Coherent selected rows with visible Material feedback, revised symbol surfaces, existing hero/preview/status presentation, theme-consistent chips and search; existing conversions and persistence retained |
| Profile photo actions/crop/upload | Gradient initials, consistent contextual crop heading and save action, refined upload heading; existing gallery selection, crop sliders, image processing, fallbacks, storage and rollback retained |
| Navigation and global feedback | Same five destinations and tab order, constrained floating navigation surface, coherent menus/pickers/dialogs, noticeable selection and readable empty/error/loading presentation |

## Responsiveness, accessibility, motion and performance

Review targets include 320-pixel phones, 390-pixel phones, landscape and 1280-pixel windows, enlarged text, long names, large balances and keyboard-visible forms. Enlarged Personal/Shared labels scroll instead of fading within narrow tabs. Long prominent currency strings stay on one line with a horizontal gesture and an explicit “Swipe to view full amount” hint. Values are not truncated, shrunk or reformatted; supporting labels wrap naturally. Standard-phone main balances use a 34-pixel display size to keep typical values together. Navigation width is limited on wide windows.

Shared notices include icons and words, not color alone. Status text, progress semantics, password visibility tooltips, profile controls, focus states and existing button targets remain. Contrast checks cover text on hero and supporting surfaces. New decoration is excluded from semantics. Existing 120/240/420 ms press, selection and progress motion remains restrained and respects reduced-motion preferences. Changing progress uses a gradient-filled fraction instead of a ShaderMask; no new business operations, reads or network requests occur for styling.

## Preservation evidence

`py tools/verify_ui_preservation.py d2afbad` compares Dart tokens with the starting revision. It verifies **144 callback/validator bindings, 52 complete query expressions, 37 critical financial/authentication/operation methods, 29 enabled/dismissal bindings and all 17 non-presentation Dart files**. This provides reviewable evidence beyond compilation.

Firebase options, repositories, authentication/password services, currency/transaction calculations, recommendation service, photo processing/storage service, shared models/store, Firestore/Storage rules, Cloud Functions and platform configuration are unchanged. Package versions and the lockfile are unchanged. No production records, accounts, preferences, collections or document fields were modified during this work.

The production app still uses its real SDK bindings. Preview fixtures and test doubles are confined to `test/`; they do not provide a production demo mode or sample records.

## Validation and artifacts

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; package versions and lockfile unchanged |
| `dart format .` | Passed; final pass formatted 73 files with 0 changes |
| `flutter analyze` | Passed with no issues |
| `flutter test --concurrency=1 --reporter expanded` | **304 tests passed**, native exit code 0 |
| Comprehensive real-font preview suites | **107 checks passed** before the final amount improvement; unchanged photo/recommendation presentations were also inspected |
| Final amount/layout preview suite (`redesign_test`, `currency_widgets_test`, `mint_aurora_test`) | **48 checks passed**, including long amount scrolling, narrow/landscape dashboards and conversion/decrease dialogs |
| Additional password/history/decrease/deposit captures | **4 focused checks passed** |
| `flutter build web` | Passed on final production sources, native exit code 0; Wasm dry run also succeeded |
| `flutter build apk --debug` | Passed on final production sources, native exit code 0; APK at `build/app/outputs/flutter-apk/app-debug.apk` |
| Source preservation audit and `git diff --check` | Passed |
| Android runtime/live account acceptance | Unverified; no Android device/emulator connected |

Both the final web assets and APK include the bundled Manrope font and license. Existing Java/Kotlin/Firebase-plugin build warnings remain; no plugin versions or Android compiler settings were changed. The APK compiled and packaged successfully, but was not installed or run on a device.

The original baseline passed static analysis and all **298 existing tests**. The baseline optional real-font preview suite exposed a pre-existing off-screen tap in the long-profile test. Updated UI tests explicitly scroll and center controls before tapping, rather than relying on the earlier screen height. Lazy planner/dashboard tests now reveal the content being checked. Tests continue asserting the original values and callbacks.

**34 rendered captures** are in `build/ui-preview/` and `build/profile-photo-previews/`; original review captures are retained in `build/mint-aurora-baseline/ui-preview/`. These cover authentication, financial/dashboard presentations, planner/recommendations, reports/profile, savings/task/password dialogs, empty and populated history, currency, photo crop, shared goal surfaces, activity, long amounts and feedback. Captures were inspected individually and in contact sheets in `build/mint-aurora-review/`. They are Flutter-rendered test captures, not live authenticated account screenshots.

Screenshots cannot establish live backend behavior. Live email/Google authentication, reset delivery, real-account CRUD, shared invitations/member permissions, profile uploads and currency preference sync still require account/device acceptance testing. No Android phone or emulator is connected. Full guarded shared routes (members, invitation management, full history and contribution submission) are reviewed in source and through their reusable presentation; their authenticated runtime has not been visually verified against a live account. Platform screen-reader behavior also remains a device check. Performance was assessed through source inspection; no device frame-rate or memory profile is claimed.

## Files

Modified production files: `lib/design_system.dart`, `lib/main.dart`, `lib/currency_savings_dialog.dart`, `lib/decrease_savings_dialog.dart`, `lib/currency_settings_screen.dart`, `lib/currency_widgets.dart`, `lib/password_dialog.dart`, `lib/password_recovery_dialog.dart`, `lib/profile_photo_widgets.dart`, `lib/shared_savings_screens.dart`, `lib/smart_suggestions.dart` and `pubspec.yaml`.

New production assets: `assets/fonts/Manrope.ttf` and `assets/fonts/Manrope-OFL.txt`. No package dependencies added.

Test updates: `test/redesign_test.dart`, `test/currency_widgets_test.dart`, `test/smart_suggestions_test.dart`, `test/profile_photo_test.dart`, `test/password_management_test.dart`; new `test/ui_preview_fonts.dart` and `test/mint_aurora_test.dart`. New source verification tool: `tools/verify_ui_preservation.py`. Documentation: this report and the superseding link in `UI_REDESIGN.md`. Temporary audit/edit scripts and command logs stay under ignored `build/`.
