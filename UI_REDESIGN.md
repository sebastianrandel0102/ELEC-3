# SaveTrack Gradient Modern redesign

> Historical report from 11 October 2026. The current implementation and validation are documented in [Mint Aurora 7.1 — Home Atelier](docs/mint-aurora-7.1-home-atelier.md).

Implemented in the existing Flutter project on 11 October 2026. This pass builds on the existing mint theme and changes presentation only. No dependencies or production assets were added.

## Audit and preserved behavior

The complete `lib/` directory, five test files, `pubspec.yaml`, branding assets, Firebase configuration, Android/web targets, navigation, forms, and asynchronous states were inspected before implementation. State remains in the original stateful widgets and Firebase stream builders. All five destinations remain in the original IndexedStack.

| Existing interface | Completed visual treatment | Preserved controls and data flow |
| --- | --- | --- |
| Session loading and startup failure | Deep emerald loading surface, branding, restrained entrance, scrollable setup/error presentation | Original Firebase initialization, session stream, setup failure and auth routing |
| Login | Aligned gradient introduction, spacious form, focused inputs, gradient submit, responsive two-column web composition | Email/password controllers and validation, visibility toggle, sign-in, recovery, registration, branded Google sign-in |
| Registration | Distinct introduction within the same authentication composition | Original name/email/password fields, validation, registration callback and return to login |
| Forgot Password | Emerald modal header, readable instructions, themed email field and reset action | Email reset request, prefilled email, loading, errors, confirmation, resend cooldown and Back to Login |
| Dashboard | Date/greeting, savings hero, mint progress fill, responsive metric cards, savings/planning composition that reflows into two columns on wide windows | Existing goal/task queries, balance/target totals, active-goal and completed-task counts, See all and Open planner callbacks |
| Savings goals and goal information | Responsive lazy list, refined icon/menu header, prominent financial panel, gradient progress, completion label, deadline and pace rows | Original title/note/amount fields, progress/remaining/pace formulas, deposit, edit, delete and history actions |
| Create/edit goal | Structured milestone form, prominent target input, contextual heading and outlined deadline picker | Original controllers, validators, optional note/deadline, Save/Cancel and identical create/update payloads |
| Add savings | Selected goal context, current savings panel, prominent PHP entry and gradient submit | Original amount/note fields, positive-amount validator, transaction batch and balance increment |
| Transaction history | Refined deposit rows, aligned date/note/amount hierarchy, lazy separators and intentional empty state | Same ordered transaction stream, amounts, notes, dates and Close history |
| Daily planner | Date panel and Today shortcut within the scrolling content, mint completion summary and gradient ring | Original selected-day state, previous/next/Today callbacks, query and completion ratio |
| Task rows | Compact bordered surfaces, readable time and priority, calmer completed state and animated surface updates | Original completion write, title/time/priority fields, edit/delete menu |
| Create/edit task | Grouped plan/scheduling fields, refined date picker and gradient Save action | Original title, optional free-text time, Low/Normal/High priority, date, validation, payloads and cancellation |
| Reports | Deep emerald savings overview, clear target progress, adaptive task report cards and completion rings | Original savings totals, daily and Monday-through-Sunday task aggregation, goal previews; no synthetic trend series |
| Profile and account preferences | Gradient identity card, robust initials, grouped currency/app information and account security surface | Actual name/email, PHP preference, Change Password and Sign out |
| Change Password | Matching emerald header, themed secure form and feedback | Current/new/confirmation fields, visibility, linked-Google verification, reauthentication, policy checks and success/error behavior |
| Navigation, menus and confirmation | Rounded navigation surface, visible selected state, consistent menus, themed pickers and destructive action styling | All five tab indices, profile shortcut, existing FAB callbacks, dialog results and delete handlers |

The existing project has no standalone goal-detail screen, editable profile, separate settings screen, weekly planner, reminders/preferences or trend-chart/period-control feature. Existing goal cards expose goal information and reports include the original weekly task summary. These flows were redesigned without adding unsupported controls or sample records.

## Shared visual system

`lib/design_system.dart` remains the single design system. It centralizes the mint/emerald palette, gradients, financial typography with tabular figures, 16/24-pixel spacing, radii, shadows, motion duration and a 1080-pixel content limit. Built-in application typography is retained, along with the existing GoogleSans font for the Google button.

- Deep emerald and contrast-adjusted signature gradients carry white text. The full emerald-to-bright-mint spectrum is used for accent progress; a separate light mint gradient keeps progress visible on dark cards.
- `MintHero`, `MintIcon`, `StatusPill`, `MintProgress`, `GradientButton`, `ScreenIntro`, `FormHeading`, `FieldCaption`, `DetailLine`, `ProgressRing` and `EnterOnce` provide reusable visual treatment.
- `AdaptiveCards` and `AdaptiveCardList` reflow content without fixed card heights or shrinking text. Large text stacks dashboard metrics. Long goal and task lists and transaction history build lazily.
- `DashboardLayout`, `SavingsOverview`, `PlannerDateHeader`, `DailyCompletion`, `ProfileContent`, `SaveTrackNavigation` and `SessionLoading` separate reusable presentation from the original Firebase bindings.
- Buttons have 120 ms press feedback, navigation and task surfaces use 240 ms transitions, and rings use a 420 ms progress tween. Reduced-motion settings bypass these animations. Entrances retain their endpoint across rebuilds; no artificial loading delay was added.
- Forms retain scrolling and controller disposal after route exit. Planner date controls scroll with their content in landscape. Safe-area navigation reserves its own space, and small error surfaces stack icon/text rather than overflowing.
- Status words, completion semantics, labeled controls, visible focus states, adequate touch targets and tested text contrast support accessibility.

## Verification

Results are recorded after the final checks below. Widget tests use isolated fixtures and Firebase test doubles; the application uses the original real Firebase SDK objects.

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; dependencies and lockfile unchanged |
| `dart format .` | Passed |
| `flutter analyze` | Passed with no issues |
| `flutter test --concurrency=1` | **101 tests passed** using standard widget creation tracking and default test fonts |
| Preview suite (`flutter test test/redesign_test.dart --concurrency=1 --dart-define=SAVE_UI_PREVIEWS=true`) | **28 tests passed**; real SDK fonts loaded for review captures. Follow-up session-loading/narrow-error checks also passed in both default and preview-font modes |
| `flutter build web` | Passed on the final production sources; output in `build/web`, including successful Wasm dry run |
| `flutter build apk --debug` | Attempted twice; failed in existing Kotlin plugin incremental-cache compilation |
| Android Gradle debug build with temporary compiler flags | **Passed**: `gradlew.bat -Pkotlin.incremental=false -Pkotlin.compiler.execution.strategy=in-process --no-daemon assembleDebug` |
| Debug APK | Fresh output at `build/app/outputs/flutter-apk/app-debug.apk` and `build/app/outputs/apk/debug/app-debug.apk` (all default Android target architectures) |
| Source preservation comparison / `git diff --check` | Passed |
| Android device runtime | Unverified: no Android device/emulator connected |

The installed Android plugins still emit pre-existing Kotlin/Gradle/SDK compatibility warnings. Compiler flags were passed to this build only; tracked Android configuration and package versions remain unchanged. The APK was compiled and packaged successfully, but has not been installed or run on an Android device.

A token-level source comparison against the starting `HEAD` verified unchanged Firebase initialization, authentication submission, Google/recovery callbacks, goal deletion, all three goal/deposit/task save callbacks, every form validator, money/date/data-path helpers, goal progress and deadline/overdue/daily/weekly calculations, and every `where`, `orderBy` and `limit` expression. Authentication/password services, Firebase configuration, Firestore rules, `pubspec.yaml` and lockfile are byte-for-byte unchanged apart from newline normalization. This is source verification, not a live Firebase acceptance test.

Automated checks exercise authentication/recovery/password workflows with test doubles, goal editing, task completion, history values, confirmation/cancellation, five navigation callbacks, profile security/logout callbacks, planner date controls, wide/narrow card order, reduced motion, text contrast, long names/large amounts, keyboard-visible forms, 320-pixel phones, wide windows and landscape with enlarged text.

Live email/password and Google authentication, account creation, reset email delivery, real Firestore goal/task CRUD and deposits, data isolation and sign-out against a real account have not been verified. Android device runtime and platform screen-reader/keyboard behavior also require device/manual acceptance testing.

## Files and review artifacts

Modified:

- `lib/design_system.dart`
- `lib/main.dart`
- `lib/password_dialog.dart`
- `lib/password_recovery_dialog.dart`
- `test/redesign_test.dart`
- `UI_REDESIGN.md`

No new dependencies, production assets, collections, document fields, service implementations or financial formulas were introduced.

Review images are generated in `build/ui-preview/`: login, wide login/registration, dashboard, goals, planner, reports, profile, goal/deposit/task forms, history and password dialogs. Auth previews render the actual screens; authenticated presentations use clearly isolated test fixtures. Previews are review artifacts, not application demonstration data.

Android build retries can use the documented temporary `-Pkotlin.incremental=false` and `-Pkotlin.compiler.execution.strategy=in-process` Gradle flags to bypass local compiler/cache failures, without changing tracked project configuration. See [Kotlin compilation and caches](https://kotlinlang.org/docs/gradle-compilation-and-caches.html) and [compiler execution strategy](https://kotlinlang.org/docs/compiler-execution-strategy.html).
