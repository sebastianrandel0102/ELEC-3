# SaveTrack — Mint Aurora 4.0

Implemented in the actual Flutter project on 13 October 2026. Starting revision: `17de14f`; the working tree was clean. This iteration builds on the existing committed mint theme, bundled Manrope font and previous redesign. It does not create a demonstration application.

## Audit and implementation scope

Inspected the package/SDK constraints, application startup and authentication, five-tab IndexedStack navigation, Firestore queries, currency presentation, personal and shared goals, transaction dialogs/history, planner state and recommendations, reports, profile/photo controls, settings, forms, feedback, existing tests and platform tooling. The baseline had no analyzer findings and all 304 tests passed.

The internal implementation sequence was: extend the existing semantic design system; recompose the four main presentations; align shared and supporting surfaces; address scrolling and text scaling; render the application widgets; correct visible issues; run source-preservation, test and build checks. The initial rendered review showed tall dashboard metrics, nested goal surfaces and repetitive report composition. Enlarged-text review later exposed crowded navigation labels, split planner dates and unnecessarily narrow goal titles, all addressed in this iteration.

The application has no independent personal Goal Details route, separate Weekly Planner screen, reminder UI, reporting-period selector or external chart package. Its personal goal card already contains the detailed financial overview and actions. Existing daily/weekly task reports and custom progress charts were redesigned without adding unsupported features or routes.

## 1. Visual transformation

Mint-white canvas, deeper emerald heroes, restrained mint reflections and contour artwork, larger and more deliberate financial typography, compact bento metrics and quieter white cards now form a consistent system. Dashboard, Planner, Savings and Reports retain distinct visual compositions. Authentication, account, currency, password, photo, dialog and feedback surfaces inherit the updated shared theme.

## 2. Dashboard

Personal greeting and date lead into the signature savings hero. Currency codes/symbols use smaller inline typography while the exact balance remains prominent. The hero's target and goal count have a clearer supporting hierarchy. Summary cells are substantially shorter, with values and icons sharing a row. Goals and planner sections use stronger section headings. Expanded windows keep financial and productivity panels side by side.

Compact and enlarged-text dashboard layouts use a single CustomScrollView with lazy task slivers. The existing task query, date, ordering and completion/edit/delete controls remain intact. The existing profile action now shows initials using the existing avatar component, without adding a profile or storage read.

## 3. Daily Planner

The editorial title sits above a compact selected-date surface and the original Previous, Next and Today controls. Narrow enlarged-text layouts give the date a full-width row and move arrows below it, preserving the complete year. A compact progress ring and completion summary replace the previous duplicated bar/ring composition.

Task cards use clearer titles, precise time labels, readable priority/status pills and quiet completed surfaces. Tint and text-emphasis transitions follow authoritative task updates; there is no new optimistic completion policy. Existing recommendation cards retain every explanation, priority, schedule, conflict indication and action, with more compact typography and spacing.

## 4. Savings and goal information

Personal savings gets a clearer page introduction. Goal cards remove the redundant nested financial panel and emphasize saved/target amounts, status, remaining amount and progress directly on a white surface. The saved label is typographically secondary, preserving the exact complete text and decimals. Long names at enlarged text scale receive a full-width title beneath the icon/menu row. Existing deadlines, overdue messages and daily/weekly pace formulas are unchanged.

History, Add Savings, Decrease Savings, editing, Save Together and deletion controls remain. Add Savings uses the existing gradient button component. Shared cards align with the same financial hierarchy; the shared detail hero separates remaining amount and deadline into readable supporting lines. Invitation, membership, attribution, access guards and shared accounting are unchanged.

## 5. Reports

Reports now has its own responsive composition: an emerald financial feature, separate shared savings surface, distinct daily/weekly completion panels and goal progress. On expanded windows, finance and productivity occupy adjacent columns. Chart surfaces have deliberate headers, dividers, gradient completion rings, readable percentages and exact completed/total captions. Shared group balances remain explicitly separate from personal savings and member-attributed deposits.

The existing savings currency aggregation and daily/weekly reporting windows are unchanged. No synthetic time series, new insights, new reporting periods or chart dependencies were introduced.

## 6–9. Tokens, reusable components, gradients and typography

`SaveTrackDesign` remains the single ThemeData source.

| Token family | Implementation |
| --- | --- |
| Brand | Obsidian `#052F28`, midnight `#073F34`, deep emerald `#0B5B4B`, rich emerald `#13876D`, premium mint `#26B58E`, accents `#4BD4A8` / `#75E7BF`, soft mint `#ABF2D7` |
| Surfaces | Pale mint `#DCF8EB`, mist `#EDFAF3`, cloud `#F4FCF8`, canvas `#F6FBF8`, white |
| Text/borders | Ink `#14362B`, supporting text `#526E61`, hero supporting text `#D9F6E9`, border `#E1EEE7`, elevated border `#D7EAE0`, divider `#EBF3EE` |
| Accessibility adjustment | Text-bearing hero endpoint `#106550`; supporting and semantic foregrounds remain darker than decorative palette shades |
| Spacing | 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48; compact page inset 16, standard inset 20 |
| Shape | Small 12, medium/input 16, card 22, hero 30, rounded status pills |
| Elevation | One diffused, low-opacity emerald shadow; borders carry ordinary card separation |

New reusable components: `AuroraMetricCard`, `AuroraChartSurface`, `AuroraLoadingSurface` and the pure `ReportsLayout`. Updated components include `AmountText`, `MintHero`, `MintIcon`, `MintProgress`, `ProgressRing`, `GradientButton`, `ScreenIntro`, `SaveTrackNavigation`, `GoalCard`, `TaskTile`, `PlannerDateHeader`, `DailyCompletion` and shared savings presentation. These components receive existing state and callbacks; business operations remain outside them.

Gradient definitions:

- Signature: `#073F34 → #0B5B4B → #106550`, for readable text-bearing features.
- Premium: `#052F28 → #073F34 → #0B5B4B`, for deeper financial features.
- Spectrum: `#073F34 → #13876D → #26B58E → #75E7BF`, for progress/chart accents.
- Glow: `#ABF2D7 → #75E7BF → #4BD4A8`, for small accents.
- Surface: `#FFFFFF → #F4FCF8 → #EDFAF3`; soft: `#FFFFFF → #EDFAF3 → #DCF8EB`.

The full bright spectrum is intentionally used for accents; white-label hero gradients end in a darker accessible shade. Static radial highlights are limited to roughly 14% opacity and decoration is excluded from semantics and hit testing.

The existing bundled Manrope remains the application font. Financial figures use tabular numbers and semibold 36–42 pixel display sizes where space permits. Page titles use 26–29 pixels, section titles 21, task titles 15 and supporting text 12–14. Currency and saved-label spans change emphasis without altering the formatter's string. Large balances retain horizontal access and an explicit hint instead of losing significant decimals. Existing Google button branding is preserved.

## 10–13. Motion, performance, responsiveness and accessibility

- Central motion tokens: press 120 ms, selection 190 ms, state/entrance 240 ms, progress 420 ms, with easeOutCubic. New transitions respect both disabled animations and accessible navigation. Callbacks are never delayed for animation.
- Progress bars/rings start at the current authoritative value and interpolate only when the endpoint changes. Unrelated rebuilds do not replay progress from zero. Task completion styling changes only after existing state allows it.
- Lazy dashboard task rendering is verified with 200 records: fewer than 20 task widgets are initially mounted and the final task remains reachable. Planner, personal goal and transaction lists retain their existing lazy builders. There are no additional data reads, continuously animated backgrounds, scrolling blur layers or new animation controllers.
- Personal/shared goal rows and dashboard task rows use stable document-based keys, keeping progress and card state associated with the same record when lists update. Query order and accounting are unchanged.
- Reviewed widths: 320, 360, 390, 412, 480, 600, 840 and 1280 logical pixels. Existing 1080-pixel content and 760-pixel navigation limits remain. Reports reflow at 600/840 pixels; enlarged text stacks chart/summary content and widens goal/date headings.
- When enlarged navigation labels need more width, the same five destinations remain accessible in a horizontal dock with an explicit swipe hint. No route or destination was removed. Navigation tests scroll each label into view before invoking its original callback.
- Skeleton loading surfaces reserve financial/report space without fabricating values. Compact metric skeletons stack their contents. Error conditions and existing retry/action mechanisms remain visible.
- Contrast checks cover text-bearing gradients, supporting surfaces and the maximum decorative hero highlight. Progress semantics, checkbox labels, tooltips, focus treatments and accessible button targets remain. Device screen-reader acceptance is still a live-device check.

No device frame-rate, raster/UI thread or memory measurements are claimed. The verified performance improvement is lazy widget construction; Android timing and higher-refresh-rate behavior require a connected device. Expanded dashboard task previews retain their pre-existing eager composition.

## 14–16. Files and dependencies

Created:

- `test/aurora4_layout_test.dart`
- `docs/mint-aurora-4.0.md`

Modified:

- `lib/design_system.dart`
- `lib/main.dart`
- `lib/shared_savings_screens.dart`
- `lib/smart_suggestions.dart`
- `test/redesign_test.dart`

No packages, fonts or raster assets were added. `pubspec.yaml`, the lockfile, platform configuration and existing assets remain unchanged.

## 17–19. Executed validation and visual evidence

| Executed check | Actual result |
| --- | --- |
| `flutter pub get` | Passed; package declarations and lockfile unchanged |
| `dart format` on all six changed Dart files | Passed; final check formatted 6 files with 0 changes |
| `flutter analyze` | Passed with no issues, including the final adaptive-grid changes |
| `flutter test --concurrency=1 --reporter expanded` | **319 tests passed**, native exit 0 |
| Broader real-font preview pass, including photo/password/supporting flows | **147 tests passed**, native exit 0 |
| Main/currency/recommendation real-font preview suite | **83 tests passed**, native exit 0 |
| Final adaptive-grid and primary/shared presentation review suite | **49 tests passed**, native exit 0 |
| Final state-retention/layout/shared regression checks | **57 tests passed**, native exit 0 |
| `flutter build apk --debug` | Passed, native exit 0; `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build web` | Passed on final sources, native exit 0; Wasm dry run succeeded |
| Final Android/web cached-input comparison | All four modified production source hashes match both compiled artifacts |
| Source-preservation audit and `git diff --check` | Passed |
| Local built-web HTTP request | Served successfully, HTTP 200 |

The two initial failures in the new layout test harness were corrected by scrolling lazy financial content into view and selecting the intended vertical Scrollable. The final suite retains its exact amount, callback, task availability and authoritative-state assertions. The existing navigation callback test now reveals each destination before tapping when enlarged labels require horizontal scrolling.

Individually reviewed rendered screenshots include all four main presentations at 390 pixels; compact dashboard/navigation at 320; enlarged goal/date/navigation/report treatments at 320; dashboard/report adaptive grids at 1280; savings at 600; shared goal/hero at narrow, phone and expanded widths; planner recommendations; currency settings; authentication; goal/password/history/transaction dialogs; profile/photo presentations; and loading/error feedback. The new primary-layout suite produces 53 captures across the eight widths, enlarged text and scrolled states. Not every generated image is claimed to have been individually inspected.

Rendered captures are Flutter widget-test images using the actual bundled Manrope and Material icons. Fixtures and SDK doubles are confined to tests; they do not form a production demo mode or touch Firebase records. Baseline captures were preserved under `build/aurora4-before/ui-preview/`. Current review captures are under `build/ui-preview/` and `build/profile-photo-previews/`.

The production web build was served locally for a live-browser attempt. Browser inventory exposed no connected surfaces, and both in-app browser and Chrome creation returned "Browser is not available". No live browser screenshot or authenticated account acceptance is claimed. Flutter-rendered widget screenshots provide the visual verification; browser/device acceptance remains a tooling limitation. The temporary HTTP server was stopped after verification.

## 20. Remaining limits and pre-existing tooling warnings

No Android phone/emulator is connected. Live authenticated account operations, email delivery, Google OAuth, shared invitations/permissions, real photo uploads, currency preference synchronization and Android screen-reader behavior have not been accepted against a live account. Their existing implementations are retained and covered by the relevant source/unit/widget checks. No account was created and no production data was submitted for cosmetic testing.

Android tooling is installed and builds are supported. The installed Java/Gradle native-access warning and Firebase plugins' future Built-in Kotlin migration warning are pre-existing tooling concerns; dependencies/compiler settings were not upgraded. Visual Studio C++ tooling is absent, so Windows desktop execution is not available. These do not prevent Android/web builds.

## 21. Functional and database preservation

| Presentation | Authoritative values and preserved actions |
| --- | --- |
| Dashboard | Existing unarchived `users/{uid}/goals` snapshots, `savedAmount` / `targetAmount` and existing currency summary; date-filtered task snapshots supply done/total. See all/Open planner keep the same tab callbacks. |
| Personal goal overview | Existing goal title/note/currency/deadline and saved/target fields; original percentage, remaining, overdue and pace expressions. Existing menu and History/Add Savings callbacks remain. |
| Planner | Existing `users/{uid}/tasks` stream for the selected date; title/time/priority/completed fields. Previous/Next/Today preserve `_selectDay`; completion still calls `setPlannerTaskCompleted`; editing/deletion and recommendation actions keep their original callbacks. |
| Reports | Existing all-personal-goal currency aggregation and exact daily/Monday-to-Sunday task queries. The original done/total and target progress feed the restyled charts. |
| Shared savings | Existing SharedSavingsHost/controller and SharedSavingsGoal/member/transaction values. Original access guards, owner/member visibility, contribution/invitation/member-management callbacks remain. |
| Profile/settings | Existing user document, Firebase user identity, original photo backend and CurrencyScope/controller. Original password, photo, currency and logout actions remain. |
| Forms/authentication | Original controllers, validators, formatters, busy/disabled gates, route results and authentication/transaction/task callbacks. Cosmetic widgets do not own persistence. |

`py tools/verify_ui_preservation.py HEAD` passes: all **144 callback/validator bindings**, **52 query expressions**, **37 audited financial/authentication/operation methods**, **29 enabled/dismissal bindings** and **17 non-presentation Dart files** are unchanged from the starting revision. Source comparison is evidence of preservation, not a live backend acceptance test.

There are no intentional business-logic, model, service, repository, security-rule, collection/path, database-schema, calculation or user-data changes. Authentication, Firestore/Storage operations, currency conversion, recommendations, task completion, permissions and transaction accounting remain owned by their original implementations. All five navigation destinations and existing action/form controls remain available.
