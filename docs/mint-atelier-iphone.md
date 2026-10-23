# Mint Atelier — iPhone-inspired SaveTrack UI

Implemented in the existing Flutter application on 24 October 2026 (Asia/Manila). The source brief is [the supplied redesign contract](design-prompts/SAVETRACK_IPHONE_UI_REDESIGN_MASTER_PROMPT_8000_PLUS_LINES.txt). This is a Flutter implementation; no Figma file, WidgetKit extension or new iOS speech bridge was created.

## What changed

- **Foundations:** Manrope roles at 34/22/17/15/13 logical pixels, a 38-pixel savings amount, layered emerald Dark surfaces, explicit input/focus/error roles, solid primary actions, consistent modal/picker styling and reduced-motion behavior. Ordinary content remains opaque.
- **Today and navigation:** shorter scroll-connected large-title geometry, a compact savings focal point, quieter greeting, four quick actions, truthful personal-goal count wording and final content clearance. Five destinations retain visited state and scroll positions. The existing account resets and offscreen ticker controls remain.
- **Goals:** clearable search, horizontally accessible status choices, current-sort menu with all five original options, explicit result count and empty-result reset. Grid uses two columns only when width and text size permit. Currency can reflow before requiring horizontal scrolling; exact formatted values remain available to accessibility. Covers retain their private image lifecycle and use a quieter fallback.
- **Planning and reports:** concise daily/weekly introductions, a tappable daily date, iOS wheel pickers with explicit Cancel/Done, and existing Material pickers elsewhere. Reports use a quiet balance panel and a larger contribution plot with expandable daily values. Contributions, withdrawals and net change retain the original calculations and labels.
- **Shared savings, profile and forms:** the same grouped surfaces, labels, fields and actions flow through shared goal/member/invitation screens, currency, reminders, photo editors and account security. Shared member initials have a readable dark foreground on mint. Financial entry separates the conversion review and projected balance from editable input.
- **AI and Agent:** shared SaveTrack logo geometry, more readable conversation type, restrained hero headings and unified surfaces across context review, missions, settings, voice and Autopilot. Existing approval, permissions and voice capability behavior remains authoritative.
- **Startup recovery:** a real retry runs the existing Firebase/App Check initialization path, stays busy during the request, and returns through AuthGate after success. Raw startup exceptions are no longer displayed to users.
- **Android widgets:** Flutter previews and native resource colors share the updated semantic palette. Existing RemoteViews layouts, privacy filtering, launch targets and in-app savings confirmation remain intact.

## Design contracts and review evidence

The existing `SaveTrackDesign`, `AtelierColors`, `AuroraPage`, grouped sections and feature-specific primitives form the component library. [The coverage table](mint-atelier-coverage.md) maps all 106 surface IDs and 51 component IDs to their owning sources. A surface marked “shared system” retains its existing composition and adopts the refined tokens; it is not a claim that another route was built.

Reference captures use deterministic synthetic records, the bundled Manrope font and a 390×844 logical canvas. Companion frames use 320×693, 375×812 and 430×932; the responsive matrix covers all four widths at 100%, 130%, 160% and 200% text in both themes. These are Flutter fixture renders, not authenticated account or device screenshots. [Browse all 40 captures](mint-atelier-screenshots.md).

| Review | Before | After | Annotation |
| --- | --- | --- | --- |
| Today Light | [baseline](../build/mint-atelier/before/goldens/precision81-home-light.png) | [current](../test/goldens/precision81-home-light.png) | The savings amount leads; less repeated supporting copy exposes goal content earlier. |
| Goals Dark | [baseline](../build/mint-atelier/before/goldens/precision81-goals-dark.png) | [current](../test/goldens/precision81-goals-dark.png) | Search, status and sort share a compact region above the collection. |
| Goal detail | [baseline](../build/mint-atelier/before/goldens/precision81-details-light.png) | [current](../test/goldens/precision81-details-light.png) | Exact balance, primary/secondary financial actions and grouped milestone facts. |
| Profile Dark | [baseline](../build/mint-atelier/before/goldens/precision81-profile-dark.png) | [current](../test/goldens/precision81-profile-dark.png) | Compact identity and separated preference/security groups. |

Additional Light/Dark pairs are stored in `test/goldens/mint-atelier-*` for authentication, Planner, Reports, shared savings, empty/loading/failure states, narrow large text and keyboard-open authentication. Existing AI and Agent golden families cover their welcome, conversation, mission and voice surfaces. Baseline source hashes and all original golden files were preserved under `build/mint-atelier/before/` before edits.

## Verification

Exact command outcomes are recorded after the final checks below. Logs and additional review captures are under `build/mint-atelier/` and `build/ui-preview/`.

| Check | Outcome |
| --- | --- |
| Formatting | Passed; 26 changed/new Dart files, zero further formatting changes; `git diff --check` passed |
| Flutter analysis | Passed; no issues |
| Complete Flutter suite and reviewed goldens | **1,018 tests passed**; 40 golden artifacts; the later comparison run passed **103 tests** without updating goldens |
| Source preservation audit | Passed; **87 domain files, 159 query calls, 25 critical methods and 16 validators unchanged** |
| Android native widget tests/rendering | **76 tests passed**, zero failures/errors/skips; 163 actual Android fixture renders. Four picker assets use visually reviewed 300×220 native reference frames |
| Web release build | Passed at `build/web`; Wasm compilation dry run also succeeded. Browser runtime was not exercised |
| Android debug APK | Passed; fresh APK at [`build/app/outputs/flutter-apk/app-debug.apk`](../build/app/outputs/flutter-apk/app-debug.apk), 191,095,635 bytes. ZIP inspection confirmed all four updated native preview PNGs are bundled |

The preservation audit compares all tracked Dart domain sources, query expressions, validators and selected authentication/financial/photo operations with the starting revision `97d58d5ce540235b1453dd82ad3b4b38d2631366`. It supports nested sources and explicitly separates presentation changes from domain sources. This is source evidence, not a live Firebase acceptance test.

Commands used from the repository root (native commands run inside `android`):

```powershell
$dartFiles = @((git diff --name-only -- '*.dart') + @('lib/platform_pickers.dart','test/mint_atelier_test.dart'))
dart format --output=none --set-exit-if-changed $dartFiles
flutter --no-version-check analyze --no-pub lib test
flutter --no-version-check test --no-pub --update-goldens --concurrency=4 --reporter expanded
flutter --no-version-check test --no-pub test/reminder_widgets_test.dart test/precision_edition_test.dart test/mint_atelier_test.dart --concurrency=4 --reporter expanded
py tools/verify_mint_atelier.py HEAD
flutter --no-version-check build web --no-pub
git diff --check

$env:JAVA_HOME = 'D:\Program Files\Android\Android Studio\jbr'
$env:SAVETRACK_WIDGET_PREVIEW_DIR = 'D:\VS Files\ELEC-3\build\mint-atelier\native'
Push-Location android
.\gradlew.bat :app:testDebugUnitTest '-Pkotlin.incremental=false' '-Pkotlin.compiler.execution.strategy=in-process' --offline --no-daemon --console=plain
.\gradlew.bat :app:assembleDebug '-Pkotlin.incremental=false' '-Pkotlin.compiler.execution.strategy=in-process' --offline --no-daemon --console=plain
Pop-Location
```

The Kotlin flags apply to these invocations only. Dependencies, SDK configuration and tracked Gradle settings were not upgraded. Existing Gradle deprecation and JVM native-access notices remain; the native check exited successfully.

`tools/generate_widget_previews.ps1` now selects the native matrix's 300×220 reference frames. Higher-density Robolectric exports omitted parts of the branding in this environment despite passing view-bound checks; those exports are excluded from the packaged picker artwork. The selected files were visually inspected with complete logos, labels, values and actions. They are actual RemoteViews renders, with synthetic examples, and were not independently redrawn. `-Render` reproduces the matrix before exporting; without it, the helper copies the existing verified renders.

The APK SHA-256 is `b9de867d74f37b52f0bfa6464819c48d147d27b3b5efccc548b14f43b238127e`. Artifact metadata, ZIP verification, source hashes and screenshot hashes are in `build/mint-atelier/`. The existing release APK was not rebuilt; the delivered APK is the new debug build.

## Capability limits

- Live Firebase/Google authentication, real account switching, multi-account membership changes, delivered reminders and real AI responses require configured services and device/account acceptance checks. Synthetic tests do not establish these runtime outcomes.
- iOS wheel pickers are covered by Flutter interaction tests, including a 320-pixel frame at 200% text. The iOS runner and Firebase options exist; iOS compilation, back swipe, VoiceOver, physical keyboards, permission prompts and runtime performance require an Apple target. No native iPhone runtime claim is made from Windows. `adb devices -l` reported no connected Android device.
- Home Screen widgets remain the existing Android RemoteViews feature. Unsupported hosts keep the current capability gates. There is no WidgetKit implementation.
- Agent speech remains limited to the platforms supported by its existing bridge. Typed input remains available. A voice artwork fixture does not establish iOS recognition or audio support.
- No backend schema, billing, package version, money parser, exchange-rate policy, operation policy, storage permission or Firestore rule was changed.

## Main changed sources

`lib/design_system.dart`, `lib/precision_components.dart`, `lib/platform_pickers.dart`, `lib/main.dart`, `lib/home_atelier.dart`, `lib/goal_cover_widgets.dart`, `lib/currency_savings_dialog.dart`, `lib/shared_savings_screens.dart`, `lib/reminder_widgets.dart`, AI presentation/theme files, Agent shared widgets and step-editor picker calls, Flutter widget palette, Android `widget_atelier.xml`, four native picker PNGs and their export helper. Regression additions are in `test/mint_atelier_test.dart`; existing golden fixtures and a few assertions were updated for intentional layout/reflow changes.
