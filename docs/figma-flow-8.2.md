# SaveTrack — Mint Aurora 8.2, Figma Flow

Implementation report, 25 October 2026.

## Existing application and initial audit

Work was performed directly in the existing Flutter repository. `main.dart` owns startup, Firebase authentication, the five-destination shell and existing personal savings/task screens. Presentation parts include `home_atelier.dart`, `precision_components.dart` and `precision_flows.dart`. Dedicated modules own currency/exact-money operations, shared savings, reminders, AI conversations, Agent Studio, Autopilot and native Android widgets. Existing `StatefulWidget`, inherited scopes, `ChangeNotifier`, repositories and Firestore streams remain in use.

The initial Flutter suite passed **1,018 tests**. No user source changes were present at the start. The audit identified a stack of separate Home cards, a vertically arranged goal gallery, a smaller date selector, duplicated scheduling metadata, dark emerald feature panels and inconsistent secondary surfaces. Existing financial, permission and persistence implementations were retained.

The screen inventory covers Today, personal and shared goals, goal details, creation/editing, contributions/decreases, history/details, daily/weekly planning, tasks, reminders, Reports, Profile, appearance/Home/currency/widget settings, login/registration/password recovery, SaveTrack AI, Agent Studio, mission/draft/history/voice flows and Autopilot settings/activity.

## Reference translation and design system

The supplied reference is the primary visual guide. Its mint illustration region, rounded white sheet, compact category cards, strong headings, quiet metadata, large date number, seven-day selector, narrow time column and restrained navigation were adapted to SaveTrack's existing features. No school content or copied illustration assets were introduced.

`SaveTrackDesign` remains the central theme. `figma_flow_components.dart` is a part of that library, rather than a second competing design system.

| Role | Implementation |
| --- | --- |
| Brand | Mint `#48BF91`, fresh mint `#65D5A9`, soft mint `#DDF5E9` |
| Neutral text | Charcoal `#202C29`; contrast-adjusted secondary `#626F69` |
| Surfaces | White, warm mint canvas, neutral `#F4F6F5` |
| Secondary categories | Coral for overdue goals/scenarios, lavender for featured goals/reminder actions, peach for approaching deadlines/contribution actions |
| Dark mode | Neutral green-charcoal canvas `#142824`, surface `#203630`, elevated `#2B453C` |
| Typography | Existing bundled Manrope; 30-pixel expanded destination headings, 20-pixel compact headings, 22-pixel section headings, 32–38-pixel balances, 48-pixel selected date |
| Spacing | Existing 8-point foundation and 4-point subdivisions; 16–20-pixel phone insets; 24–28-pixel section separation |
| Geometry | 20-pixel cards, 16-pixel inputs/actions, 28-pixel feature panels, 34-pixel Home sheet corners |
| Motion | Existing reduced-motion-aware press, selection, progress and entrance tokens; no new perpetual animation or blur |

Mint fills use dark text when needed. Text actions keep an accessible darker botanical tone. Existing dark gradients remain available for specialized legacy contexts; the primary Home, personal/shared balances, currency, authentication, recovery, recommendation and Agent panels use the softer surfaces.

New shared components are `FlowHomeLayout`, `FlowContentSheet`, `FlowWeekSelector`, `FlowDateHeading`, `FlowTimelineEntry`, `FlowCategoryDecoration`, `FlowSavingsArt` and `FlowTaskGroupEntry`. The original savings-jar/coin/botanical illustration is drawn with Flutter vector painting; it has no network request, raster dependency or animation controller.

## Screen and feature coverage

| Area | Result | Preserved behavior |
| --- | --- | --- |
| Navigation | Five original destinations; quieter full-width bottom surface; compact Home/Planner headers; consistent other destination titles | Tab state, callbacks, Android Back, visited-tab lifecycle, inactive ticker handling and existing widget/reminder navigation |
| Today | Continuous mint header with real balance and original artwork meets a rounded white content sheet | Existing shared goal snapshot, currency summary, cache/pending states, quick actions, customized section ordering/visibility and featured-goal preference |
| Goal Gallery | Horizontally scrolling cards with soft corner decoration; layouts expand for large text | Actual title, saved/target amounts, capped visual progress, covers, pinning and correct goal destination |
| Goals | Gallery/grid/list cards share status-based surfaces, consistent spacing and title hierarchy; missing covers no longer force a large dark placeholder | Existing search, filters, sorting, view preference and create actions |
| Goal details | Soft mint balance panel, slim progress, primary mint action and grouped facts/activity | Exact stored amounts, remaining/pace calculations, deadline, edit, cover, reminder, shared-goal and delete actions |
| Goal/task forms | Shared white modal surfaces, neutral filled inputs, consistent Manrope headings, mint primary buttons and accessible field boundaries | Validators, input retention, unsaved-change guards, keyboard scrolling, controller disposal and duplicate-submission protection |
| Add/decrease savings | Shared action, input and dialog styling | Exact-money utilities, exchange-rate confirmation, preview semantics, balance limits and existing transaction confirmation paths |
| Transactions | Existing grouped history and detail rows inherit the new typography, surface and control system | Stored dates, amounts, currency, direction, notes, filtering and lazy history rendering |
| Save Together | Soft mint shared balance and coordinated cards/forms | Guarded streams, owner/member permissions, invitations, contributions, authorized member data and financial confirmations |
| Daily Planner | Large date with weekday/month, Today, seven-day strip, day/week navigation and schedule-first list | Selected-date state, midnight rollover, existing task query and original completion/edit/delete/reminder callbacks |
| Weekly Planner | Same week strip and timeline treatment, with actual per-day counts | Existing bounded weekly query, day selection, weekly progress and empty/error states |
| Task timeline | Chronological timed entries, compact highlighted next item, separate flexible/unscheduled section; time ranges show only stored endpoints | Existing strict time parser; no fabricated start/end times; Smart Suggestions and completion summary remain below the schedule |
| Reminders | Home Up Next and management cards share the time-column visual language; today's agenda receives mint emphasis | Scheduler/timezone calculator, next occurrence, recurrence, OS status, toggle/manage/remove actions and invalid/unavailable schedules |
| Reports | Shared mint/neutral metric, chart, period and planning surfaces | Existing real transaction series, exact aggregation, period boundaries and currency separation; no synthetic chart data |
| Profile/settings | Existing compact identity and grouped settings inherit neutral text, consistent white cards and mint controls | Avatar, security, sign-out, appearance/Home preferences, currencies, notifications and widget configuration |
| Authentication | Soft mint welcome illustration, consistent forms and matching password/recovery headers | Firebase/Google sign-in, registration, recovery, reauthentication, error feedback and session routing |
| SaveTrack AI | Soft mint user messages and white assistant surfaces, matched composer/action roles | Coaching/read-only boundaries, context consent, history, message formatting, retry and existing backend |
| Agent Studio | Soft mint introduction and six softly colored action cards with reference-inspired corner shapes | Natural-language input, validated drafts, missions, execution status, history, voice and preparation-versus-recording boundaries |
| Autopilot | Existing grouped current mode, permissions, limits and activity inherit the shared theme/components | Consent, policy gates, financial/destructive confirmations, execution ledger, pause and device/account isolation |
| Android widgets | Native XML and Flutter previews share the mint/charcoal day/night palette | RemoteViews layouts, configuration identifiers, stored preferences, privacy clearing, intents and confirmation deep links |

No application feature, financial formula, database collection, permission rule or confirmation requirement was replaced to achieve the presentation.

## Accessibility, responsiveness and performance

The new week strip keeps real calendar semantics and a stable touch target. At narrow widths or enlarged text it scrolls horizontally. Timeline metadata moves above cards when a separate rail would squeeze content. Financial values retain the existing accessible `AmountText` behavior rather than being truncated. Task and reminder text wraps, and the new illustration cannot intercept input.

The schedule uses the existing strict parser, orders a copy of the records and keeps unparseable/free-text schedules separate. The featured task is resolved once per list rebuild. Lists remain lazy; Home sections keep their lifecycle and user preferences. No new Firestore listener, third-party package, hosted image service or paid Firebase capability was added.

Device frame rate, memory, notification delivery, TalkBack and authenticated Firebase workflows have not been measured in this environment. Implementation choices alone are not a claim of 60/120 Hz performance.

## Verification and artifacts

All final checks below completed successfully. Logs are in ignored `build/figma-flow-*.log`. The read-only preservation/count report is [figma-flow-preservation-results.json](figma-flow-preservation-results.json), generated by `py tools/verify_figma_flow.py`.

| Final check | Verified result |
| --- | --- |
| Flutter dependency resolution | Passed; package definitions and lockfile unchanged |
| Static analysis | No issues found |
| Complete Flutter suite | **1,038 passed**, exit 0; 20 added checks (3 unit, 17 widget) |
| Independent visual references, without updating files | **44 passed**, exit 0; includes six new Home/Planner/Reminders light/dark images |
| Native Android unit/rendering suite | **76 passed**, zero failures/errors; actual RemoteViews renders exported |
| Formatting of changed Dart source/tests | 21 files checked, zero changes required |
| Preservation audit | 43 protected methods match; 112 service/configuration files unchanged |
| Android debug build after native asset export | **Passed**, exit 0; final Gradle packaging 343.5 seconds |
| Source whitespace check | Passed |
| Device/emulator runtime and performance | Unverified; no device/system image available |

The final machine-readable record is [figma-flow-8.2-results.json](figma-flow-8.2-results.json). The packaged APK is at `build/app/outputs/flutter-apk/app-debug.apk` (191,121,069 bytes). Four launcher picker images were refreshed from native sample renders. Existing Gradle/Java deprecation warnings remain; no package, Gradle or Kotlin version was changed.

During verification, selected-action colors, secondary text, high-priority labels, large-text week navigation and date-control semantics were refined. Existing weekly/Planner tests now exercise the new date control and lazy list while preserving date, exact-value, callback and persistence assertions. A test-only semantics-handle cleanup was corrected before the final clean run.

New tests cover strict timeline ordering, unchanged record identity, next-task highlighting, date/week callbacks, goal navigation and exact displayed money, light/dark reference compositions and 320/390/600/840-pixel layouts at 200% text. New deterministic screenshots are `test/goldens/flow82-{home,planner,reminders}-{light,dark}.png`. Existing golden references also cover Goals, Details, Reports, Profile, authentication, reminders, AI and Agent presentations.

Visual review uses the actual Flutter widgets with explicitly isolated fixtures. These are rendered widget captures, not authenticated Android screenshots. `adb devices` returned no connected device; the SDK has emulator tooling but no installed system image or configured AVD. Consequently actual emulator screenshots, authenticated device acceptance and profile-mode measurements are unavailable. No production records were written to create captures.

New source/test files are `lib/figma_flow_components.dart` and `test/figma_flow_test.dart`; the audit helper/report and this document are also new. The machine-readable report lists all modified source files and normalized, nonblank/non-comment added/removed line counts. Production Kotlin logic, service modules, Firebase/security configuration and package versions are unchanged. The existing implementation was reused; no code was padded toward a 10,000-line target.

Remaining acceptance work requires a configured Android device/emulator and a test account: email/Google authentication, real add/decrease confirmations, shared membership/invitations, native notifications, launcher widgets, Back/TalkBack behavior and profile-mode frame/memory measurement.

## Source counts and delivery inventory

| Category | Added | Removed | Normalized diff lines |
| --- | ---: | ---: | ---: |
| Production Dart | 1,180 | 486 | 1,666 |
| Native XML | 15 | 15 | 30 |
| Dart tests | 417 | 6 | 423 |
| **Total** | **1,612** | **507** | **2,119** |

These counts exclude blank/comment lines and normalize indentation. They describe both sides of the source diff, not 2,119 newly written lines. No production Kotlin or integration-test code was added. Utility scripts, documentation, generated captures and binary image files are excluded from this table. The full source-file list is in the preservation report. Native preview images are the four `android/app/src/main/res/drawable/st_widget_preview_*.png` files; new and refreshed visual references are in `test/goldens/`.

The implementation is ready for source review and debug-APK installation. No known Flutter analysis, unit/widget/golden or native-unit failures remain. Remaining work is the device/account acceptance and measurement described above.
