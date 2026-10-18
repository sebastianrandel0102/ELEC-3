# Mint Aurora 7.1 — Home Atelier

Implemented in the existing SaveTrack Flutter application on 18–19 October 2026.
This pass extends the existing Mint Aurora screens and shared component library.

## Implementation

- Home now uses a single personal-goal snapshot for its balance, goal count, gallery and activity inputs. The greeting, compact financial hero, goal picker for Add Savings, Planner and Agent shortcuts are connected to existing workflows.
- Goal Gallery supports a featured goal, image/cache fallbacks, responsive gallery/grid/list layouts, accurate amounts, bounded progress and real deadlines. The full personal-goal browser adds local search, active/completed/overdue filters and five sorting choices. Tapping a goal opens the existing live details screen and its financial/edit/history/reminder controls.
- Savings Pulse reads dated personal-goal ledger entries for seven days, thirty days or the current calendar month. It displays contributions, withdrawals, net change and a daily contribution chart, with tap tooltips and screen-reader descriptions. Currency groups remain separate. Amount labels use the existing exact-decimal formatter directly, including very large aggregates. Invalid or failed ledger reads show an error instead of partial totals; cached/pending data and empty caches are labeled. Missing conversions never display a fabricated zero. The same component is connected to full Reports.
- Up Next uses `ReminderCoordinator` and its existing timezone/recurrence calculator. It sorts next occurrences, excludes unavailable/completed targets, exposes scheduling problems and opens the real reminder editor. Timeline and Next Up are available.
- Customize Home controls gallery/report/reminder presentation, optional section visibility, section order through accessible arrow buttons, and the featured goal. Restore Default Layout affects presentation only. Preferences use `SharedPreferences` under an account-specific key; appearance is a separate device preference.
- Planner now has Daily and Weekly choices. The weekly agenda uses the existing task collection, date keys, completion state and editing actions. A real seven-day selector and weekly completion summary accompany the selected day's tasks. Home limits its task preview to three items.
- Transaction history adds date groups and All, Added and Withdrawn filters over the existing ordered stream. Missing timestamps are labeled unavailable. Transaction values and writes are unchanged.
- Goal and task forms confirm before discarding edits through Cancel or Back, retain edits when the user chooses Keep editing, and block navigation during submission. Existing successful-save and partial-save handling remain in place.
- Light, Dark and Follow System are connected to the root app theme. Semantic surfaces, text, borders and selected states extend through goals, financial dialogs, shared savings, reminders, currency settings, profile/password/authentication, AI Coach, Agent Studio and Flutter widget settings. Fixed dark heroes retain light text, and mint artwork retains dark foregrounds.
- Android RemoteViews reuse their existing layouts, typography, actions and lifecycle. Their light surface and dark surface/text resources now align with the Flutter palette.
- Top-level destinations, route arguments, navigation callbacks, financial confirmations and authorization remain intact. Tabs initialize when first visited and reset for each account; Home sections retain their state while scrolling. Reduced-motion behavior, accessible amount scrolling and existing lazy long lists are retained. Decorative cover captions are omitted at large text scales to prevent clipping.

## Screen inventory and data ownership

| Existing destination | Entry point | Authoritative data / behavior |
| --- | --- | --- |
| Home | Today tab | Existing personal-goal stream, task stream, shared-goal store, reminder coordinator, currency controller |
| Personal and shared goals | Goals tabs, Home | Existing goal collections and shared-savings store; personal gallery opens `PersonalGoalDetailsScreen` |
| Goal details, creation, editing and covers | Goal cards, New goal | Existing forms, repositories, cover service and account guards |
| Add/decrease savings and history | Goal details, Home goal picker | Existing exact-money inputs, confirmations, transaction writers and ordered ledger streams |
| Save Together, invitations, members and shared activity | Shared tab | Existing shared repository, owner/member permissions and confirmation flows |
| Daily and weekly Planner, task forms | Planner tab | Existing task records, `dateKey`, priorities, completion writes and reminder drafts |
| Reminder center and editor | Home bell, Up Next, Profile, goal/task controls | Existing synced configurations, target subscriptions, timezone calculator and native scheduler |
| Reports | Reports tab, Home Pulse link | Existing balance/currency calculations, task metrics, shared summaries and read-only personal activity aggregation |
| AI Coach Lite and Ask Anything | Toolbar and AI shortcuts | Existing controller, consent boundaries and gateways |
| Agent Studio, voice, missions, Autopilot and history | Agent shortcut / toolbar | Existing engine, reviewed actions, permissions, voice lifecycle and execution ledger |
| Profile, appearance, currency, notifications, widgets and security | Profile tab | Existing account/photo/password services plus local presentation preferences |
| Login, registration, Google sign-in and password recovery | Existing authentication gate | Existing Firebase Authentication and recovery services |
| Native Android widgets | Existing widget configuration / launcher | Existing native widget bridge, account isolation, privacy modes, deep links and scheduling |

No separate onboarding, arbitrary general-reminder backend, profile-text editor, report export, Home week-strip reminder mode or drag reordering was invented. Existing goal/task reminder configuration remains the way to create reminders. Optional presentation modes are shown only when implemented.

## Integrity and performance

Authentication services, transaction-writing services, authorization rules, Firebase configuration, database schemas, package dependencies and billing requirements are unchanged. Presentation settings do not write to Firestore. Report aggregation reuses the existing exact decimal type and currency formatter; it never writes balances or requests AI-generated financial facts.

Activity reads are bounded by the selected date range and performed once per personal goal when a report loads or its period/data revision changes. No transaction listeners, collection-group permissions, paid services or new storage providers were added. Shared financial analytics retain the existing summaries; personal activity charts are explicitly labeled as personal goals.

## Verification

The pre-change baseline passed **845 tests**. The new suite covers preference persistence/account separation/reset, malformed preferences, exact report sums, currency separation, period boundaries, recurrence ordering, gallery modes, navigation, pin fallbacks, search/filtering, zero/overfunded goals, retry states, customization, weekly selection, transaction direction/date groups, discard confirmation, appearance selection, large text, dark-mode legacy surfaces and semantic color contrast. Two committed golden images use the actual bundled Manrope and Material icon fonts with deterministic, date-independent fixtures.

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; dependency versions and lockfile unchanged |
| `flutter analyze` | Passed, no issues |
| Complete Flutter regression suite | 879 passed |
| Focused final UI / financial / Agent checks | 92 passed on the final sources, including the added reminder initialization-error case |
| Light / dark golden comparisons | Passed in the focused suite |
| `flutter build apk --debug` | Passed; final source labels verified in the packaged Dart kernel |
| `git diff --check` and protected-source comparison | Passed |

The full regression run completed **879 tests**. A subsequent **92-test focused pass** covered the final reminder initialization-error adjustment and its added test, goal/task discard confirmation, typed and legacy transaction history, the real Agent adapter, all new Home components and both golden comparisons. This includes exact display of a PHP 100,000,000,004,200.01 aggregate and honest empty-cache states. History assertions scroll to offscreen entries in the lazy grouped list. One existing Agent integration fixture was aligned with its production adapter's real-clock date validation after midnight; production Agent logic was not modified.

Review images: `build/ui-preview/atelier71-*.png` (synthetic test fixtures, never production data). Golden references: `test/goldens/atelier71-home-light.png` and `test/goldens/atelier71-home-dark.png`.

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk` (all default Android architectures). Existing release outputs were retained.

No Android device or emulator was connected. Live Firebase authentication, live account writes, OS notification delivery, native widget placement, device screen-reader behavior and device performance profiling require device/account acceptance testing. Automated regression tests use isolated fixtures and service doubles.
