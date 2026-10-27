# Mint Aurora 6.0 — Widget Atelier

> Current palette and export workflow: [Mint Atelier implementation and verification](mint-atelier-iphone.md). The exporter now uses visually reviewed native 300×220 matrix frames; the earlier xhdpi capture description below records the original implementation.

## Presentation audit

The existing implementation uses Kotlin RemoteViews, XML resources and a Flutter configuration screen. Per-instance configuration, authenticated navigation, local snapshots and confirmation-based savings flows remain the integration contract.

| Widget | Existing visual issue | Refinement | Resize priority and verification |
| --- | --- | --- | --- |
| Savings Goal | Centered text stack, weak distinction between amounts and labels, plain expanded details | Financial display type, labeled progress, supporting remaining/deadline surfaces, clear Save action | Progress first when small; exact money and supporting metrics as room permits; long names and currencies in native renders |
| Today's Planner | Pending count dominates, task rows lack structure | Completion hierarchy, quiet date, status markers, themed task surfaces and priority/time labels | Aggregate progress in compact sizes; measured rows in taller sizes; empty days, privacy and text scaling |
| Quick Save | Generic information-card appearance, equal emphasis for actions | Strong primary savings action, quieter formatted preset shortcuts, concise confirmation context | One action when compact; 48dp shortcuts only when they fit; existing authenticated confirmation routing tests |
| Today Overview | Improved responsive cards, but separate theme and progress styling | Shared semantic colors, balanced financial/productivity panels, completion context and richer expanded details | Two metrics, side-by-side cards or stacked panels according to real bounds; resize and reapplication tests |

Native work belongs in `widgets/WidgetRenderer.kt`, shared visual/layout helpers, and `res/{values,values-v31,drawable,layout}`. Flutter work belongs in `lib/home_widgets/widget_settings_screen.dart` and presentation-only preview components. Tests exercise native dimensions, themes, privacy, navigation and actual rendered text bounds; Flutter tests cover the customization controls and previews.

System corner radii, grid-filling backgrounds and accessible controls follow the [Android widget quality guidance](https://developer.android.com/docs/quality-guidelines/widget-quality). This is a design target, not certification. Existing uncommitted changes are preserved.

## Implementation and validation

The redesign is implemented in the existing RemoteViews feature. No Glance/Compose migration, runtime dependency, paid service, new polling job or background engine was introduced. The package remains `com.example.myproject`; the existing minimum SDK and provider identities are unchanged.

### Visual system

`WidgetVisualTokens` centralizes effective appearance, text, surfaces, accents, warning colors, progress and actions. XML color/dimension resources hold the Daylight and Midnight Emerald palettes; `WidgetTypography` reads the same unscaled type values used by the XML. Financial values use a system-compatible sans-serif fallback and tabular figures. Exact money strings still come from SaveTrack's existing snapshot formatter.

| Role | Daylight | Midnight Emerald |
| --- | --- | --- |
| Background | `#EDFAF3` | `#073F34`, with a restrained gradient for explicit Dark |
| Main surface | `#FFFFFF` | `#165346` |
| Secondary surface | `#E3F5EA` | `#0B5B4B` |
| Primary text | `#14362B` | `#FFFFFF` |
| Supporting text | `#526E61` | `#DCF8EB` |
| Progress fill | `#13876D` | `#75E7BF` |
| Progress track | `#D6EDE0` | `#286A5B` |
| Primary action | `#0F745D` / white text | `#4BD4A8` / `#052F28` text |

The supporting Daylight text is darker than the proposed `#688176` to meet the tested contrast targets. Native tests verify normal text and action contrast of at least 4.5:1, and fill/track contrast of at least 3:1. Status remains readable through text, not color alone.

Light, Dark and System stay independent per widget. Existing `mint`, `emerald`, `system` and `white` stored values remain valid; White is available as a Light variation in the studio. Fixed themes ignore system brightness. On Android 12+, System uses host-resolved day/night text, icon and progress actions plus day/night drawable resources. A view created in Daylight was tested when applied by a dark host. Foreground Android configuration changes repaint current local snapshots. On older versions, appearance follows the current configuration on repaint; stopped-app refresh timing remains launcher-controlled.

Android 12+ outer and inner corners use the system widget radius resources. Earlier versions retain a 24dp outer fallback. Backgrounds fill the widget's own bounds; the 12dp padding is internal. Internal surfaces, 8dp gaps and 48dp actions establish a consistent grid. Primary actions have native ripple feedback; secondary actions use quieter surfaces.

### Four compositions

- **Savings Goal:** saved amount is the focal point when it fits; target and percentage share a supporting line. Expanded views add remaining/deadline panels, status and the existing optional thumbnail. Narrow views keep whole percentages and show exact financial strings only when they fit without ambiguous digit grouping. Save and Goal Details retain separate actions where space allows.
- **Today's Planner:** a quiet date supports completion counts, a clear progress bar and relevant task rows. Medium layouts prioritize the next task over an extra footer button. Taller layouts reveal more existing recommendations with status markers, priority and time. Empty days show an All Clear state with a small completion icon.
- **Quick Save:** a primary Add Savings action anchors the surface. Valid presets form a quieter secondary group with formatted currency symbols; the ISO currency stays in the goal context. Presets disappear when their full labels cannot fit. The expanded view includes confirmation context and goal progress. Every action still opens the existing reviewed, authenticated savings workflow.
- **Today Overview:** separate savings and focus surfaces use balanced metrics and themed progress. Compact views show progress and pending counts; normal views show completed/total tasks. Stacked layouts suit tall placements. Exact savings, remaining amounts and a 48dp next-task link appear when measured space permits. Supporting labels give way to a useful task; larger layouts retain the Save, Planner and AI Coach routes.

### Resizing and accessibility

Size selection uses both dp dimensions and font scale, followed by actual native view measurement. Wide short layouts use horizontal summaries; tall narrow views retain useful content rather than falling into a tiny centered fallback. Lower-priority content is omitted before it can clip. Extreme minimum-size text scaling uses one readable summary or an Open shortcut when separate metrics cannot fit.

Native important actions and task rows target at least 48dp. Compact widgets use one full-surface action. Long names can wrap in larger goal layouts and ellipsize where needed; money never uses misleading abbreviations. Per-provider maximum resize dimensions limit otherwise empty expansion: Goal 500×360dp, Planner 500×480dp, Quick Save 500×300dp, Today 500×480dp. Enforcement depends on launcher/API support; rendering also handles larger reported bounds.

### Flutter customization studio

The existing screen now groups preview, selected content, appearance, privacy and additional options. A single preview replaces the Compact/Medium/Expanded controls; users resize the installed widget on their home screen, where its layout adjusts automatically. Light/Dark/System choices include icons and check marks; White remains available. Privacy choices include an explanation and selected-state icon. Preset entry updates the preview locally. Save commits through the existing controller, and explicit Cancel preserves saved configuration. Tests verify that changing preview appearance does not persist until Save, Cancel retains the instance and another installed widget stays unchanged.

Previews use the production snapshot formatter/privacy filter, selected goal facts and read-only Planner facts from the existing subscription. Missing data uses honest placeholders. No demo balances or tasks were added to production widgets. No decorative preview animation was added. The gallery shows each widget's purpose, initial size guidance and its own composition.

### Picker previews and visual evidence

All four picker images come from actual native 300×220dp sample renders at xhdpi, exported as 600×440 PNGs. They replace the old independently drawn artwork. Android 12 also uses these supported `previewImage` resources; the old separate `previewLayout` resources were removed so the picker does not show a second, outdated design. Sample values remain restricted to tests and picker artwork. Actual widgets continue to consume authorized snapshots.

Native output is in `build/widget-atelier/`, including Light, Dark, White, System Day, System Night, wide/short, narrow/tall, unusually large and larger-font cases. These are Robolectric Android renders using synthetic test facts, not phone/launcher screenshots. Inspected captures include all four picker cards, expanded Goal/Planner/Today layouts, narrow large-text money fallback and minimum-size metrics. Picker captures run in isolated tests at native xhdpi density; dimensions, complete branding and layout bounds are asserted before export.

To regenerate picker files, set the project's Java environment and run:

```powershell
$env:JAVA_HOME = 'D:\Program Files\Android\Android Studio\jbr'
.\tools\generate_widget_previews.ps1 -Render
```

Without `-Render`, the helper copies previously exported native images. `-Widget today` (or another existing type name) limits the files copied. This workflow was executed successfully.

### Executed checks

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; dependency files unchanged |
| `dart format` on modified Dart files | Passed |
| `flutter analyze` | Passed, no issues |
| Focused widget/recovery suite | 42 passed |
| Full `flutter test --reporter expanded` | 542 passed |
| Full Android `:app:testDebugUnitTest` | 47 passed, zero failures/errors |
| Native picker regeneration | Four additional isolated xhdpi capture tests passed; native 600×440 artwork visually inspected |
| `flutter build apk --debug` | Built successfully; final picker images included in the rebuilt APK |
| `git diff --check` | Passed |

Native coverage includes the existing 252 combinations across four types, seven geometries, three font scales and APIs 29/31/35. The new API 31 native graphics suite adds 120 theme/shape combinations, 32 long-content/large-font combinations, cross-host System resolution, contrast, privacy, empty states, whole 0/40/100% values at minimum size, and assertions that medium layouts actually retain a task and preset shortcuts. Existing navigation, per-instance preset intents, privacy/session invalidation and stale snapshot tests remain in place.

Logs: `build/atelier-pub-get.log`, `build/atelier-analysis.log`, `build/atelier-focused-tests.log`, `build/atelier-full-flutter-tests.log`, `build/atelier-native-tests.log`, `build/atelier-picker-generation.log`, `build/atelier-android-build.log`.

### Preserved behavior and practical limits

Firebase/authentication, financial calculations, currency conversion, saving/contribution transactions, shared-goal authorization, Planner ordering, snapshot synchronization and secure navigation were not rewritten. The controller addition is a read-only preview getter. Configuration IDs, schema and stored theme/privacy choices remain compatible. Native resizing/appearance uses saved snapshots; no new cloud reads, AI requests, background polling or permanent services were added. Existing authorized cover thumbnails remain bounded and cached; there are no bitmap backgrounds in the actual widgets.

There was no connected Android device and no configured emulator AVD. Real launcher resize gestures, OEM grid/corner behavior, live Firebase configuration and connected instrumentation were not exercised. Flutter previews approximate native composition and cell geometry; their inherited app font differs from the native system fallback, and they do not load cover photos. Native expanded widgets retain cover support. No battery or device frame-time benchmark, universal OEM compatibility or official Tier 1 certification is claimed. Remaining validation is the connected-device/launcher review; no failing automated check remains.

## File inventory

Status relative to the starting working tree. The four removed XML picker layouts are superseded by the native-rendered PNGs.

| File | Change |
| --- | --- |
| `android/app/src/main/kotlin/com/example/myproject/MainActivity.kt` | Modified |
| `android/app/src/main/kotlin/com/example/myproject/widgets/WidgetLayoutResolver.kt` | Modified |
| `android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt` | Modified |
| `android/app/src/main/kotlin/com/example/myproject/widgets/WidgetVisualTokens.kt` | Created |
| `android/app/src/main/res/drawable/st_widget_button_bg.xml` | Modified |
| `android/app/src/main/res/drawable/st_widget_button_light.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_button_secondary_dark.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_button_secondary_light.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_complete_marker.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_emerald.xml` | Modified |
| `android/app/src/main/res/drawable/st_widget_mint.xml` | Modified |
| `android/app/src/main/res/drawable/st_widget_preview_goal.png` | Modified |
| `android/app/src/main/res/drawable/st_widget_preview_planner.png` | Modified |
| `android/app/src/main/res/drawable/st_widget_preview_quick_save.png` | Modified |
| `android/app/src/main/res/drawable/st_widget_preview_today.png` | Modified |
| `android/app/src/main/res/drawable/st_widget_progress_track.xml` | Modified |
| `android/app/src/main/res/drawable/st_widget_progress_track_light.xml` | Modified |
| `android/app/src/main/res/drawable/st_widget_secondary_dark.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_secondary_light.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_section_bg.xml` | Modified |
| `android/app/src/main/res/drawable/st_widget_system.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_system_action.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_system_secondary.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_system_surface.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_task_marker.xml` | Created |
| `android/app/src/main/res/drawable/st_widget_today_panel.xml` | Modified |
| `android/app/src/main/res/drawable/st_widget_today_panel_dark.xml` | Modified |
| `android/app/src/main/res/drawable/st_widget_white.xml` | Modified |
| `android/app/src/main/res/layout/st_widget.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_amount.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_button.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_compact.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_empty.xml` | Created |
| `android/app/src/main/res/layout/st_widget_metric.xml` | Created |
| `android/app/src/main/res/layout/st_widget_mini_metrics.xml` | Created |
| `android/app/src/main/res/layout/st_widget_mini_metrics_pair.xml` | Created |
| `android/app/src/main/res/layout/st_widget_preview_goal.xml` | Removed |
| `android/app/src/main/res/layout/st_widget_preview_planner.xml` | Removed |
| `android/app/src/main/res/layout/st_widget_preview_quick_save.xml` | Removed |
| `android/app/src/main/res/layout/st_widget_preview_today.xml` | Removed |
| `android/app/src/main/res/layout/st_widget_progress.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_progress_light.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_task.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_text.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_today.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_today_footer.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_today_goal.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_today_header.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_today_stacked.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_today_tasks.xml` | Modified |
| `android/app/src/main/res/layout/st_widget_wide.xml` | Created |
| `android/app/src/main/res/values-night/widget_system.xml` | Created |
| `android/app/src/main/res/values-v31/widget_atelier.xml` | Created |
| `android/app/src/main/res/values/widget_atelier.xml` | Created |
| `android/app/src/main/res/values/widget_system.xml` | Created |
| `android/app/src/main/res/xml-v31/st_widget_goal_info.xml` | Modified |
| `android/app/src/main/res/xml-v31/st_widget_planner_info.xml` | Modified |
| `android/app/src/main/res/xml-v31/st_widget_quick_save_info.xml` | Modified |
| `android/app/src/main/res/xml-v31/st_widget_today_info.xml` | Modified |
| `android/app/src/main/res/xml/st_widget_goal_info.xml` | Modified |
| `android/app/src/main/res/xml/st_widget_planner_info.xml` | Modified |
| `android/app/src/main/res/xml/st_widget_quick_save_info.xml` | Modified |
| `android/app/src/main/res/xml/st_widget_today_info.xml` | Modified |
| `android/app/src/test/kotlin/com/example/myproject/widgets/TodayWidgetRenderingTest.kt` | Modified |
| `android/app/src/test/kotlin/com/example/myproject/widgets/WidgetAtelierRenderingTest.kt` | Created |
| `android/app/src/test/kotlin/com/example/myproject/widgets/WidgetLayoutResolverTest.kt` | Modified |
| `android/app/src/test/kotlin/com/example/myproject/widgets/WidgetLifecycleTest.kt` | Modified |
| `docs/home_widgets.md` | Modified |
| `docs/widget_atelier.md` | Created |
| `lib/home_widgets/widget_controller.dart` | Modified |
| `lib/home_widgets/widget_preview.dart` | Created |
| `lib/home_widgets/widget_settings_screen.dart` | Modified |
| `lib/home_widgets/widget_visuals.dart` | Created |
| `test/home_widgets_test.dart` | Modified |
| `tools/generate_widget_previews.ps1` | Modified |
