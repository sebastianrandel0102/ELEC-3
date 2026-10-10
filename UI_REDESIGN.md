# SaveTrack UI redesign

The redesign updates the existing Flutter application in place. Firebase configuration, security rules, dependencies, data paths, document fields, navigation destinations, date formatting, financial calculations, and persistence operations retain their existing contracts.

## Screen inventory and implementation

| Existing interface | Presentation changes |
| --- | --- |
| Startup, session loading, setup failure | Mint background, branding, accessible loading feedback, consistent error surface |
| Login and registration | Gradient introduction, refined form surface, styled inputs and primary button, password visibility and preserved validation |
| Password recovery | Existing inline recovery action, styled validation/error feedback and success snackbar |
| Today dashboard | Gradient savings overview, animated real-data progress, summary tiles, goal and task previews |
| Savings goals and goal information | Goal icons, completion labels, readable amounts and target, progress bars, existing deadline/pace information and actions |
| Goal creation/editing | Consistent dialog header, currency context, date picker styling, scrolling and loading feedback |
| Savings deposits | Focused amount entry, existing note field, scrolling and loading feedback |
| Savings history | Readable amount/note/date timeline, intentional empty state, accessible dismissal |
| Daily planner | Date navigation, daily completion summary from the existing snapshot, task priority/completion labels |
| Task creation/editing | Consistent fields, priority selection, existing time/date entry, scrolling and loading feedback |
| Reports | Deep emerald savings summary and real-data completion bars; original daily/weekly aggregation retained |
| Profile | Gradient account header, grouped existing preferences/information, preserved sign-out action |
| Navigation and modals | All five destinations retained, selected-state motion, consistent menus, destructive confirmation and picker styling |

There were no standalone goal-detail, settings, weekly-planner, trend-chart, notification or reminder screens in the original application. The existing goal cards and weekly task reports remain in their original flows.

## Shared implementation

`lib/design_system.dart` centralizes the palette, three gradients, typography (including tabular financial figures), spacing, radii, shadows, animation duration, content width and Material component themes. Reusable widgets include `PageSurface`, `MintHero`, `MintIcon`, `MintProgress`, `StatusPill`, `GradientButton`, `ScreenIntro`, `SaveActionLabel`, `StateSurface` and `FormControllerScope`. Existing summary, report, empty, error, loading and branding widgets were also restyled.

Progress animations and navigation selection respect reduced motion. Narrow layouts wrap amounts and action groups. Forms scroll above keyboard insets; page widths are constrained on larger windows. Form controllers survive rebuilds and dispose after their dialog leaves the widget tree. Status labels supplement color, task checkboxes have semantic labels, and error messages use live regions.

## Verification

- `flutter pub get`: passed; no dependency changes.
- `dart format .`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: initial suite passed; later runs hit disk exhaustion during compilation.
- Final `flutter test --concurrency=1 --no-track-widget-creation --dart-define=SAVE_UI_PREVIEWS=true`: **18 tests passed**. Disabling widget creation tracking reduces diagnostic compilation storage; assertions and test behavior remain enabled.
- `flutter build web`: passed.
- `flutter build apk --debug`: two attempts failed because C: ran out of space while merging native libraries.
- `flutter build apk --debug --target-platform android-arm64`: **passed**, producing `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed.

Widget tests cover login/registration validation and retained input, password-recovery validation, goal amounts/progress/completed/overdue states, goal action availability, edit-goal update payloads, task completion updates, history amounts/notes/dates, destructive confirmation, keyboard-visible forms, cancellation, 320-pixel layouts, enlarged text, landscape states, reduced motion, startup errors and AA text contrast across shared gradient/background colors. Firestore test doubles are confined to tests.

Source comparison against the original commit confirms unchanged authentication submission, recovery, initialization, goal deletion, goal/deposit/task validation and save handlers, and data/currency/date helpers. This comparison ignores formatting and trailing commas.

Actual Firebase sign-in, account creation, reset email delivery, goal/task CRUD against Firestore, deposit persistence, user isolation, sign-out, and Android device behavior still require a test account and device/emulator. These live checks have **not** been marked as passed. Firebase and security configuration were not modified.

The initial Android build warned about the installed Firebase plugins applying Kotlin Gradle Plugin. Unrelated SDK/package migrations were not performed. Automatic review rejected broad recursive removal of build folders; narrower cleanup of specific generated compilation files was allowed. Generated build output was also compressed to recover disk space.

## Files and previews

- `lib/main.dart`: all existing screen and shared-widget presentation updates.
- `lib/design_system.dart`: centralized theme and reusable presentation components.
- `test/redesign_test.dart`: layout, interaction, accessibility and callback regression checks.
- `UI_REDESIGN.md`: screen inventory and verification report.

Review images are generated at `build/ui-preview/login.png` and `build/ui-preview/goals.png`. The goals image uses clearly isolated test fixtures; no sample data was introduced into the application.

The debug APK targets ARM64. Building the default APK for all target architectures requires more free disk space. No Android device/emulator was connected, so installation and device runtime checks remain unverified.
