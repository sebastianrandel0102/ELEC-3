# SaveTrack — Mint Aurora 8.7 implementation report

27 October 2026. Implemented in the existing Flutter/Android application. This report distinguishes source implementation, host-side rendering tests, Firestore emulator tests and device verification.

1. **Original architecture.** Four Kotlin `AppWidgetProvider` classes share `WidgetRenderer`, XML RemoteViews, `WidgetLayoutResolver` and app-private `WidgetStore` preferences. A custom MethodChannel publishes privacy-filtered Flutter snapshots. There is no Glance or `home_widget` dependency. Flutter subscriptions already target affected goal/planner instances.
2. **Problems found by source audit.** Compact Goal reduced full-details balances to percentages; compact Planner reduced upcoming tasks to counts. Quick Save controls foregrounded MainActivity and offered no native amount editing, review, pending state or local input persistence. Flutter previews independently approximated native layouts. Quick Save allowed 110 × 56dp resizing although interactive entry cannot fit there. Existing expanded controls could exceed provider maximum heights.
3. **Interaction delays.** Every Quick Save amount action went through Activity startup, Flutter navigation and server authorization before reaching the existing form. Basic entry now stays in native preferences and RemoteViews. A serial receiver executor preserves digit order without a typing debounce. Network work starts only after explicit review and confirmation.
4. **Size mismatch causes.** The existing engine used both dimensions, but compact content discarded useful facts, preview compositions differed, and metadata permitted impractical Quick Save sizes. Resize callbacks now use the supplied options directly; API 31 size maps reject non-finite and duplicate dimensions. Older Android retains portrait/landscape fallbacks using all four bounds.
5. **Responsive architecture.** Keep the existing native renderer and size resolver. `WidgetComposition` names the horizontal/vertical compositions; Quick Save uses dedicated text/button RemoteViews with paged or full keys. Installed widgets remain native views, not widget-sized bitmaps. Gallery images alone are generated from the same production renderer through `preview`.
6. **Actual buckets.** Dimensions below are usable host dp divided by system font scale (minimum 1). The existing detail tiers remain: Compact below 120h, or below 125w and 190h; Medium from 250 × 190; Expanded from 250 × 270; extra detail from 250 × 360. Remaining sizes use the existing small vertical composition. Composition names distinguish narrow (<156w), standard compact (<250w or <190h), short horizontal (>=240w and <120h), medium, expanded and expanded wide (>=360w and >=270h). Quick entry requires >=156 × 180 effective dp; the full pad requires >=240 × 360. These are content budgets, not launcher grid assumptions. Quick Save metadata now requests at least 180 × 210dp; reference previews use explicit example sizes, while deployed layouts use actual host options.
7. **Compact changes.** Goal can show the formatted saved amount when it fits, with a small progress bar; unreadably long amounts retain the percentage fallback. Planner can show the first authorized task and time when task-title display is enabled. Decorative logos no longer consume essential compact width. Quick Save uses paged number keys, More, Back and Review at practical dimensions; unsupported legacy sizes retain an app shortcut.
8. **Medium changes.** Keep measured native goal/task rows and existing summary priorities. Quick Save exposes local amount editing, decimal rules, Clear, Back, preset selection, Review and Cancel without starting MainActivity. More cycles through digit groups and, when configured, preset shortcuts.
9. **Expanded changes.** Quick Save uses a full number pad with separate Back, Cancel and Review controls. Existing Goal remaining/deadline cards, Planner task rows and Today summary panels remain available. All provider maximum heights now allow 600dp; Goal/Planner/Today can expand to 720dp width. Additional content remains bounded and readable rather than scaling text to fill space.
10. **Savings Goal.** Preserve authoritative formatted balances, target, capped progress, remaining, deadline, optional bounded covers and existing app savings forms. Compact full-details presentation is richer, and a confirmed widget contribution refreshes associated Goal instances.
11. **Today's Planner.** Preserve the existing task ordering, metadata, title privacy opt-in and task-editor navigation. Compact can expose the next task/time instead of only a count. Existing day/timezone guards suppress yesterday's task facts. Direct task completion was not previously supported by native widgets and has not been added; task taps retain the existing editor and its confirmation behavior.
12. **Quick Save.** Entry → Review → Pending → Saved, or Retry for an unconfirmed outcome. The selected goal remains the instance configuration. Digits, decimals, Clear, Back, Cancel, presets and review are local. Full Details is required for native amount entry; privacy modes retain their existing safe shortcuts. Resizing does not mutate input or its operation.
13. **Today Overview.** Preserve native side-by-side/stacked savings and task panels, progress, next activity and empty states. Higher resize bounds make expanded actions reachable. After a contribution, related Overview facts are rebuilt from authorized goal data and current planner facts. No totals across unrelated currencies, invented reminders or synthetic production records were added.
14. **Native actions.** A non-exported receiver handles input. Immutable explicit broadcast PendingIntents include widget ID, configuration revision, input/review generation and control identity. No amounts or goal IDs are accepted from action intents. Old review/confirmation intents cannot confirm a later draft. Existing navigation actions retain unique identifiers and server authorization.
15. **Input state.** `input_<widgetId>` stores stage, exact decimal text, keypad page and flow identity in the existing backup-excluded private preferences. State survives process recreation and resizing. A shared lock coordinates separate store objects, account cleanup, configuration and action processing. Widget removal, restored ID handling and account changes clear input and operation keys alongside snapshots.
16. **Transaction safety.** Confirm atomically persists an immutable `operation_<widgetId>` containing account, goal reference, currency, exact amount, date and UUID request ID before scheduling. Duplicate Confirm is disabled. Retry keeps exactly that operation. Dart revalidates native configuration and Firebase user, uses `LockedMoneyEntry`, and calls existing `recordCurrencySavings` or `SharedSavingsRepository.call('contribute')`. Existing transactions and receipts provide server-side authorization and idempotency. Personal widget deposits additionally check archived status inside the transaction, after recognizing an already committed retry. Pending/retry operations prevent changing the instance configuration until resolved. No financial arithmetic uses a new floating-point shortcut.
17. **Background execution.** A persisted network-constrained Android JobScheduler job starts a headless FlutterEngine at the retained `widgetBackgroundMain` entrypoint. It initializes the existing Firebase and App Check setup, executes confirmed operations and destroys the engine afterwards. Receivers perform no Firebase work. A timeout and Android stop/restart preserve stable operations; bootstrap failures and scheduling rejection expose Retry. Pending means waiting for connectivity/scheduling or the save result; it does not mean Saved. No foreground Activity is requested by this native workflow. This path still needs real-device validation.
18. **Targeted refresh.** Existing goal/planner subscriptions, 180ms publication batching and installed-ID filtering are retained. Background success refreshes only configurations selecting the contributed goal, through the existing snapshot formatter and privacy checks. Freshness-only cached publications persist without needless redraws. Confirmed success appears before optional refreshed details; a refresh failure cannot change a successful contribution into a failed save. App resume and existing calendar/provider maintenance can recover pending scheduling.
19. **Preview parity.** Android gallery/configuration previews request the production RemoteViews renderer at Compact/Medium/Expanded example bounds, with the selected appearance, privacy, real facts and font scale. They are read-only PNGs; no preview action submits a contribution. Unsupported platforms retain Flutter fallback compositions. A changed preview request resets its image immediately, preventing a prior private image from lingering while a privacy-safe replacement loads. The existing single-preview configuration UI is preserved. All four picker images were regenerated from the passing native test renders, not independently redrawn art.
20. **Dark Mode.** Reuse existing Mint Aurora semantic palette, explicit Light/Dark/White and System handling. The Quick Save text, surface and action resources use the same tokens and Android 12 day/night RemoteViews color APIs.
21. **Accessibility.** Number/action controls use 48dp rows. Exact entry text has an accessibility label; currency can move into the goal label when the amount needs the entire line. Unreadable amounts can use two lines; supported detail is reduced as font scale grows. Native controls expose Backspace and Next number keys labels. At extreme text scale/legacy dimensions that cannot fit native entry, existing app shortcuts remain available.
22. **Performance.** No network calls during entry, no typing debounce, no polling added, no per-key Flutter startup, and no large bitmaps in deployed widgets. Quick Save uses one bounded native-tree measurement to preserve key space when font metrics exceed the nominal budget, without the generic per-row measurement loop. API 31 rendering remains capped at 16 distinct valid sizes; covers retain existing decode bounds. Only the preview endpoint creates bounded bitmaps. No device latency measurements or universal timing guarantees are claimed.
23. **Files created.** `QuickSaveInput.kt`, `QuickSaveActions.kt`, `QuickSaveRenderer.kt`, `QuickSaveJobService.kt`; `st_widget_quick_entry.xml`, `st_widget_quick_row.xml`; `lib/home_widgets/widget_background.dart`, `widget_native_preview.dart`; `QuickSaveTest.kt`, `test/home_widgets_native_preview_test.dart`; this report.
24. **Files modified.** Existing native bridge, providers, store, renderer and resolver; AndroidManifest; compact layout; all eight provider metadata files; native widget layout/lifecycle/rendering tests; Flutter widget models, previews, descriptions and configuration guidance; main entrypoint; the existing personal transaction writer's optional active-goal check; widget documentation; native picker PNGs where regenerated. Existing user changes to the single-preview settings flow were retained.
25. **Dependencies.** No runtime or test dependencies added or upgraded. Firebase Spark compatibility is preserved: JobScheduler, existing Flutter embedding, Firebase client SDKs and existing Firestore transactions/rules. No Cloud Functions, Blaze requirement or paid service.
26. **Tests added.** Exact input precision and currency decimal limits; local review/cancel/confirm/retry transitions; immutable request identity; multiple instance isolation; resize persistence; stale intent rejection; account cleanup; PendingIntent routing; persisted network scheduling; breakpoint boundaries; all twelve Android preview requests; immediate preview image removal after privacy changes. Existing native rendering tests continue exercising themes, long amounts and font scaling.
27. **Executed results.** Final command results and counts are recorded below after verification. The first native run was superseded while implementation was still changing; its partial output is not a baseline or a passing result. Static audit findings above are not claimed as observed launcher defects.
28. **Android build.** See the final verification record below. Artifact: `build/app/outputs/flutter-apk/app-debug.apk` when the debug build succeeds. Gradle uses the installed Android Studio JBR, since the shell's default `java` is Java 8.
29. **Actual device findings.** No physical device was attached. The configured API 29 emulator failed its normal launch because the Android hypervisor driver is absent. A software-emulation attempt also failed the available memory/commit check. No installed-widget screenshots, launcher resize measurements, reboot tests or authenticated on-device financial operations are claimed.
30. **Remaining platform limits.** Android/launcher scheduling controls background start time and widget delivery. Force-stopped apps cannot run jobs until Android allows them again. Cloud data changes while the entire app is stopped still rely on the existing cached snapshot/maintenance behavior unless triggered by this confirmed-save job; no permanent listener was added. Offline/unknown saves retain their operation and offer Retry. A deleted/revoked goal cannot receive a new contribution; an unresolved operation may require restoring access to reconcile its receipt. Reconfiguration is intentionally blocked for an unresolved financial operation. Restored Android widget IDs require safe reconfiguration. Live Samsung/third-party launcher parity, instrumentation and the headless Firebase path need a usable device. Native host-side renders are not launcher screenshots.

Platform references: [Android flexible widget layouts](https://developer.android.com/develop/ui/views/appwidgets/layouts), [FlutterEngine background execution](https://api.flutter.dev/javadoc/io/flutter/embedding/engine/FlutterEngine.html), [Firestore transaction guarantees and offline behavior](https://firebase.google.com/docs/firestore/manage-data/transactions).

## Final verification record

| Check | Executed result |
| --- | --- |
| `flutter pub get` | Passed; existing dependency versions retained. |
| `flutter analyze` | Passed: no issues found. |
| `flutter test` | Passed: 1,077 tests. |
| Native-preview Flutter tests | Passed: 2 additional tests covering twelve preview requests and immediate private-image removal. |
| Isolated Firestore emulator suite | Passed: 54 tests. These exercise existing rules/transaction invariants; they are not a claim that the new headless engine has run on a device. |
| Native widget JVM/Robolectric suite | Passed: 71 tests, zero failures or errors; APIs 29/31/35 where annotated, with actual native graphics for the appearance matrix. Earlier layout failures were corrected and rerun. The final narrow-label adjustment also passed 15 focused rendering/state checks. |
| Debug APK | Passed: final `flutter build apk --debug`, including regenerated native picker images and the final layout/label fixes. Artifact: `build/app/outputs/flutter-apk/app-debug.apk`. |
| Device/instrumentation/launcher matrix | Not executed: no attached device; emulator launch failures described above. |

Executed logs are under `build/widget-*.log`; native sample renders are under `build/widget-responsive/`. Samples contain test-only fixture data, never production seed data. Native renders were sampled visually for paged/full Quick Save, Planner, compact Goal and Today Overview. Automated bounds checks cover the complete native theme/shape matrix. No launcher latency or end-to-end background-save measurement is claimed.

## Exact source inventory

| Change | Path |
| --- | --- |
| Created | `android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveActions.kt` |
| Created | `android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveInput.kt` |
| Created | `android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveJobService.kt` |
| Created | `android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveRenderer.kt` |
| Created | `android/app/src/main/res/layout/st_widget_quick_entry.xml` |
| Created | `android/app/src/main/res/layout/st_widget_quick_row.xml` |
| Created | `android/app/src/test/kotlin/com/example/myproject/widgets/QuickSaveTest.kt` |
| Created | `docs/widget_responsiveness_8_7.md` |
| Created | `lib/home_widgets/widget_background.dart` |
| Created | `lib/home_widgets/widget_native_preview.dart` |
| Created | `test/home_widgets_native_preview_test.dart` |
| Modified | `android/app/src/main/AndroidManifest.xml` |
| Modified | `android/app/src/main/kotlin/com/example/myproject/widgets/WidgetBridge.kt` |
| Modified | `android/app/src/main/kotlin/com/example/myproject/widgets/WidgetLayoutResolver.kt` |
| Modified | `android/app/src/main/kotlin/com/example/myproject/widgets/WidgetProviders.kt` |
| Modified | `android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt` |
| Modified | `android/app/src/main/kotlin/com/example/myproject/widgets/WidgetStore.kt` |
| Modified | `android/app/src/main/res/drawable/st_widget_preview_planner.png` |
| Modified | `android/app/src/main/res/drawable/st_widget_preview_quick_save.png` |
| Modified | `android/app/src/main/res/layout/st_widget_compact.xml` |
| Modified | `android/app/src/main/res/xml-v31/st_widget_goal_info.xml` |
| Modified | `android/app/src/main/res/xml-v31/st_widget_planner_info.xml` |
| Modified | `android/app/src/main/res/xml-v31/st_widget_quick_save_info.xml` |
| Modified | `android/app/src/main/res/xml-v31/st_widget_today_info.xml` |
| Modified | `android/app/src/main/res/xml/st_widget_goal_info.xml` |
| Modified | `android/app/src/main/res/xml/st_widget_planner_info.xml` |
| Modified | `android/app/src/main/res/xml/st_widget_quick_save_info.xml` |
| Modified | `android/app/src/main/res/xml/st_widget_today_info.xml` |
| Modified | `android/app/src/test/kotlin/com/example/myproject/widgets/WidgetAtelierRenderingTest.kt` |
| Modified | `android/app/src/test/kotlin/com/example/myproject/widgets/WidgetLayoutResolverTest.kt` |
| Modified | `android/app/src/test/kotlin/com/example/myproject/widgets/WidgetLifecycleTest.kt` |
| Modified | `docs/home_widgets.md` |
| Modified | `lib/currency_transactions.dart` |
| Modified | `lib/home_widgets/widget_models.dart` |
| Modified | `lib/home_widgets/widget_preview.dart` |
| Modified | `lib/home_widgets/widget_settings_screen.dart` |
| Modified | `lib/home_widgets/widget_visuals.dart` |
| Modified | `lib/main.dart` |
