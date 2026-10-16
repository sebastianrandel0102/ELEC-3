> Current visual implementation and validation: [Mint Aurora 6.0 ? Widget Atelier](widget_atelier.md).

# SaveTrack home-screen widgets — Mint Aurora Home Edition

Implemented in the existing Flutter application on 16 October 2026.

## User experience

Four providers appear in the Android widget picker:

| Widget | Content | Tap behavior |
| --- | --- | --- |
| Savings Goal | Selected personal or shared goal, progress, optional original-currency amounts, remaining amount and deadline | Opens that goal; Add Savings opens the existing review form |
| Today's Planner | Local date, completion summary, up to five pending tasks using Smart Task Suggestions ordering | Opens Planner or the existing task editor |
| Quick Save | Selected goal, up to three user-defined exact decimal shortcuts, custom amount | Opens the existing savings/contribution form with a validated suggestion |
| Today Overview | Separate savings and task cards with progress bars | Opens Dashboard, Savings, Planner, or Coach |

No home-screen action records a transaction or completes a task. Savings still require the existing explicit confirmation and use the existing transaction service and request IDs.

Open **Profile → Home Screen Widgets** to view the gallery, request launcher pinning when supported, and manage installed instances. Pinning reports that a request was sent; the launcher controls whether a widget is actually placed. A launcher that does not configure a pinned widget immediately shows a tappable setup state.

To add manually: long-press an empty home-screen area, choose Widgets, find SaveTrack, drag a widget into place, select settings, and save. Long-press the placed widget and use the launcher's resize handles. Menus, grid sizes and reconfiguration support vary by launcher.

Each instance has an independent goal reference, theme, privacy preference, task-title opt-in, cover-photo opt-in and optional contribution presets. Removing or editing one instance does not change another instance or any Firestore record.

## Implementation choice

The primary renderer is Kotlin **RemoteViews**, using supported Android views rather than Flutter screenshots. This fits the project's existing FlutterActivity and XML-based Android setup without enabling Compose or adding a second rendering framework. Android 12+ receives exact `SizeF` RemoteViews variants supplied by the host; older hosts receive portrait/landscape variants using all four min/max size options. Providers repaint on `onAppWidgetOptionsChanged`, following Android's [flexible widget layout APIs](https://developer.android.com/develop/ui/views/appwidgets/layouts).

`home_widget` was evaluated but is not a dependency. The small `savetrack/home_widgets` MethodChannel handles atomic versioned payloads, native instance enumeration, account invalidation, pin requests, configuration completion and cold/warm launch events directly. No runtime Dart or native dependencies were added. Tests add JUnit 4.13.2 and Robolectric 4.17 only. The minimum SDK remains 24; compile and target SDK remain Flutter's existing 36.

The native configuration Activity preserves the launcher's `RESULT_CANCELED` default and sends `RESULT_OK` only after Flutter saves configuration and publishes a safe initial state. It forwards setup to the existing MainActivity/Flutter engine. Cancelling does not commit preferences. Reconfiguration uses the launcher on supported versions or the in-app management list.

PendingIntents are immutable and use distinct URI identities per widget, action, preset and task. The identity URI is kept out of Flutter's automatic deep-link routing; the authenticated Dart handler owns navigation. Cold-start requests wait for Firebase authentication, Google sign-in completion and the root navigator frame. Duplicate taps on an active confirmation flow are ignored.

## Adaptive content

The resolver uses **both** actual dp dimensions and font scale. Thresholds are content breakpoints, not promises about launcher cells:

| Class | Effective constraints | Content priority |
| --- | --- | --- |
| Compact | Height below 120dp, or width below 125dp with height below 190dp | One metric and a short title when it fits; the whole surface is a shortcut |
| Small | Remaining narrow/short sizes | Title, progress or task count; secondary content only with enough height |
| Medium | At least 250 × 190dp | Financial summary, task rows or contribution shortcuts; actions when height permits |
| Expanded | At least 250 × 270dp | Remaining amount, deadlines, additional tasks, optional bounded thumbnail |
| Extra large | At least 250 × 360dp | Fuller goal and task summaries, comfortable actions, update label, Today Coach shortcut |

Effective constraints divide available dimensions by at least the system font scale. Layouts preserve readable native text rather than proportionally stretching an image. Tall/narrow and wide/short hosts take different paths. The renderer measures the actual native header, footer and child views before adding rows, so lower-priority content is omitted before it can clip. Exact amounts use the existing formatter, retain the goal's ISO currency, and never undergo widget-only conversion. If an exact amount cannot fit readably, the primary metric becomes progress. Visual progress follows the application's existing 0–100% clamp; balances remain unchanged, including overfunding. Follow System resolves Android appearance per instance; Android 12+ also resolves supported day/night actions in the host. Older stopped-app theme changes can wait for repaint.

Today Overview has dedicated resize layouts: equal savings/task cards side by side at ordinary sizes, stacked cards for tall narrow placements, and two labeled metrics for short placements. Both summaries retain separate tap targets. Its panels fill the available body instead of centering a generic two-line summary in empty space. Actual native measurements remove secondary amounts and task titles before progress bars or core metrics; singular task labels, empty days and stale Planner data have distinct states. The in-app preview mirrors the two-card composition and stacks for narrow widths or larger text.

All providers allow horizontal and vertical resizing, with a 110 × 56dp metadata floor. Android 12 target cells are 4 × 2, or 4 × 3 for Today. Actual placement and minimum sizes are launcher-controlled. Rounded native surfaces and the system background ID permit launcher corner clipping. Four native-rendered PNG picker previews are included on all supported versions; sample data is restricted to previews and tests. Android 12 uses these images instead of the old separate preview layouts.

## Data flow and refresh

```text
Existing authenticated Firestore collections / shared repository
  → WidgetDataSource read adapter
  → exact money formatter + existing SmartTaskRecommendationService
  → HomeWidgetSnapshot (privacy applied)
  → one atomic native SharedPreferences edit
  → relevant AppWidget IDs / native RemoteViews
```

There is at most one widget data subscription per selected goal and one shared subscription for today's tasks. No listeners are started when no widgets require them. Goal changes repaint linked instances; task changes repaint Planner and Today. A 180ms debounce coalesces normal updates. Permission failures immediately replace affected private payloads. Terminated subscriptions may be retried on foreground reload. Subscription generations prevent cancelled listeners or old accounts from publishing later.

Goal and task metadata events with pending writes are excluded. The widget does not present an optimistic contribution as confirmed. Existing Firestore aggregates provide saved/target facts; transaction histories are never fetched for widget rendering. Changing display-currency preference does not revalue widget balances: widgets deliberately retain the selected goal's original denomination. A changed goal denomination disables old presets until reconfiguration.

Account changes, app resume, configuration changes and date rollover reconcile instances. A foreground minute check follows the existing Planner's local-date convention. Native date, time, timezone, reboot and package-replacement broadcasts repaint locally. A conservative 30-minute AppWidget update period performs local maintenance only. There is no WorkManager job, background Flutter engine, background Firebase initialization, permanent service, AI call or network request in native providers.

When the app is stopped, native code can repaint only the last saved snapshot. It does not claim live cloud synchronization. Yesterday's task titles/counts are suppressed after a date or timezone change and replaced by an Open Planner refresh state. Expanded layouts identify cached information or show the actual confirmation time. Cached repaints retain their previous freshness timestamp; after 24 hours without refreshed facts, the renderer substitutes a neutral Open SaveTrack state. Offline goal/task actions requiring authoritative server authorization report unavailability instead of bypassing checks.

## Privacy and authorization

- Default: **Progress Only**, with generic goal identification, no exact balances and no task titles.
- **Full Details** is an explicit selection. Task titles require a separate opt-in; task notes are never serialized.
- **Hide All Private Details** stores a neutral display payload containing no goal summary or planner facts.
- Native storage also strips private fields according to the configured privacy level, validates schema/type/instance/revision/account, and rejects corrupt payloads.
- Local display data is in the app-private, credential-protected `savetrack_widgets` SharedPreferences file. It is plaintext app-private storage, not encrypted storage. Cloud backup and device transfer exclude this file.
- Logout/account switching atomically clears private snapshots and prior selections, then repaints neutral widgets. The next account must configure its own selections. Open widget-originated screens and dialogs are account-guarded. Optional native images, actions and labels are explicitly reset even when the launcher reapplies an existing view, preventing an old cover photo from surviving a neutral/private update.
- Shared-goal snapshots require current root membership and remain subject to existing Firestore rules. Revocation or a permission failure clears facts and thumbnail data when observed. Offline caches cannot independently discover server-side revocation while the app is stopped.
- Goal/task taps are identifiers, not authority. Flutter checks the current user, installed instance and saved configuration, then reads the actual goal/task from the server. Shared goals also require an active membership document.
- Preset intents contain an index, not a trusted amount. The amount comes from current per-instance preferences, is checked with `parseCurrencyAmount`, and must match the current goal currency. Existing guarded savings forms provide busy-state and stable-request duplicate protection.
- Optional covers reuse the existing authenticated cover cache and ownership checks. A bounded 128 × 72 JPEG is stored inside the cohesive display payload. Native decoding is bounded; photos are optional and cleared with unavailable or private states.

Firebase rules, indexes, account business logic, financial writers, reports, existing reminder scheduling and AI services were not replaced. This feature does not require Blaze, Cloud Functions, new hosting or paid services. As with the app's other foreground data, ordinary reads count toward existing Firestore quotas.

## Source map

| Location | Responsibility |
| --- | --- |
| `lib/home_widgets/widget_models.dart` | Typed configuration, snapshots, exact-money presentation, privacy, launch validation |
| `lib/home_widgets/widget_bridge.dart` | Typed MethodChannel facade |
| `lib/home_widgets/widget_data_source.dart` | Read-only adaptation of existing records, metadata and cover cache |
| `lib/home_widgets/widget_controller.dart` | Instance reconciliation, shared subscriptions, date rollover, debounced publication |
| `lib/home_widgets/widget_host.dart` | Stable application host, auth lifecycle, deferred navigation, account guards |
| `lib/home_widgets/widget_settings_screen.dart` | Gallery, instructions, configuration, previews and instance management |
| `lib/main.dart` | Root integration, Profile entry and authenticated routing into existing screens/forms |
| `lib/currency_savings_dialog.dart`, `lib/shared_savings_screens.dart` | Optional validated prefill in existing confirmation flows |
| `android/.../widgets/WidgetStore.kt` | App-private versioned storage, schema and session validation, cleanup/restore |
| `android/.../widgets/WidgetRenderer.kt`, `WidgetLayoutResolver.kt` | Native adaptive content, themes, actions, expiry and local-date guards |
| `android/.../widgets/WidgetProviders.kt` | Four provider classes and calendar maintenance receiver |
| `android/.../widgets/WidgetConfigurationActivity.kt`, `WidgetBridge.kt` | Launcher result lifecycle and platform bridge |
| `android/.../MainActivity.kt` | Existing-engine cold/warm intent delivery |
| `android/app/src/main/AndroidManifest.xml` | Provider/configuration/calendar registrations and cache backup exclusions |
| `android/app/src/main/res/{layout,drawable,xml,xml-v31,values}` | Layout primitives, preview assets, themes, provider metadata and strings |
| `android/app/build.gradle.kts` | Test-only dependencies and AGP 9 host-test asset dependency |
| `test/home_widgets_test.dart`, `test/home_widgets_recovery_test.dart` | Snapshot, configuration, navigation validation, privacy, synchronization, recovery and UI tests |
| `android/app/src/test/kotlin/.../widgets/` | Native resolver, storage/lifecycle and RemoteViews layout tests |
| `tools/generate_widget_previews.ps1` | Exporter for the four checked-in native picker PNGs |

Restoration deliberately invalidates old/new widget IDs and asks for setup, rather than attaching restored IDs to possibly incorrect private selections. Removal and pruning affect device widget records only.

## Verification and remaining device checks

Run Android builds and Gradle host tests **sequentially** in this checkout: both invoke Flutter asset generation. Concurrent invocations caused asset-copy collisions during development. AGP 9 also required an explicit host-test packaging dependency on `copyFlutterAssets<Variant>`, now declared in the app Gradle file.

Commands used:

```powershell
flutter pub get
dart format lib/home_widgets lib/main.dart lib/currency_savings_dialog.dart lib/shared_savings_screens.dart test/home_widgets_test.dart
flutter analyze --no-pub
flutter test --reporter expanded
flutter test test/home_widgets_test.dart --reporter expanded
flutter test test/home_widgets_test.dart test/home_widgets_recovery_test.dart --reporter expanded
flutter build apk --debug
cd android
$env:JAVA_HOME = 'D:\Program Files\Android\Android Studio\jbr'
.\gradlew.bat :app:testDebugUnitTest --console=plain
```

Validation results (including the Today Overview resize fix):

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; no new runtime package dependency |
| Dart formatting | Passed |
| `flutter analyze --no-pub` | Passed, no issues |
| Full `flutter test` suite | **542 passed**, including the Widget Atelier follow-up and existing app coverage |
| Targeted widget and recovery suite | **42 passed** after Widget Atelier |
| `:app:testDebugUnitTest` | **47 passed**, plus four isolated native picker capture tests |
| Android debug APK | Built successfully at `build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check` | Passed |

Native tests run under Robolectric on API 29, 31 and 35. They cover account/session binding, stale configuration revisions, isolated removal/restoration, privacy sanitization, stale and corrupt snapshots, per-instance preset intents, explicit themes for every provider, cached freshness retention, and clearing old photos/actions/text during RemoteViews reapplication. Layout measurement covers four widget types × seven geometries × three font scales × three API levels: **252 combinations**, including the five content classes, wide/short and tall/narrow shapes. A real medium-size overflow found by these tests was fixed with native view measurement. Test setup follows [Robolectric's current Gradle guidance](https://robolectric.org/getting-started/).

The picker PNGs can be regenerated on Windows with `./tools/generate_widget_previews.ps1 -Render`. They are actual native renders using sample facts from the test fixture; Planner counts and progress agree. All Android versions use the same accurate preview images.

Today resize regressions additionally cover the reported 270 × 190dp geometry, tall layouts at three font scales, individual card navigation, stale/private details and RemoteViews reapplication. `TodayWidgetRenderingTest` uses API 31 native graphics to check that both metric strings fit their actual text bounds at seven geometries/font settings. Set `SAVETRACK_WIDGET_PREVIEW_DIR` when running Gradle tests to export its rendered PNGs for visual review.

There was no connected Android device or configured emulator AVD. No launcher screenshots, real launcher resize gestures, live Firebase widget configuration, cold/warm device launches, or connected instrumentation results are claimed. Native API 31 renders and PNG picker artwork were visually inspected. Robolectric checks cover text metrics, layout bounds and native pixels; they do not establish Pixel/Samsung/third-party launcher compatibility.

Before release, exercise the APK on Android 10/11 and Android 12+, preferably Pixel plus another launcher: add/configure/cancel/reconfigure all four types, resize width and height, rotate, change font scale, create two goals with different currencies, test both privacy settings, confirm a prefilled contribution once, revoke shared access, remove one instance, sign out/switch accounts, restart offline, and cross midnight/timezone boundaries. The project's existing debug signing for release builds remains unchanged; this work does not provide production signing.
