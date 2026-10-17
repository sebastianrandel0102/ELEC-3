# Mint Aurora 7.0 — Agent Atelier

Implemented inside the existing SaveTrack Flutter application on October 18, 2026. No application, backend, paid service, font, package, or primary brand asset was added.

## Audit and architecture

Agent Studio already had a local multilingual planner, typed drafts for all six workflows, Gemini advisory integration, Android speech recovery, mission review and execution, account-specific local history, and persisted Autopilot policies. The presentation used repeated outlined shortcuts, mostly unstructured draft summaries, a flat composer, plain history rows, and a partially overridden dark theme. Feature-level themes were not consistently inherited by pushed routes and dialogs.

The new `lib/agent_studio/presentation/` layer renders existing `AgentEngine`, `AgentAction`, and `AgentMission` data. Reusable surfaces, heroes, action cards, statuses, mode selectors, processing indicators, empty states, previews, and activity tiles contain no Firestore calls. Existing state management, routing callbacks, repositories, interpretation previews, editors, and security boundaries remain in use.

`AgentAtelier` extends `SaveTrackDesign` instead of replacing the application theme. It reuses Manrope, emerald/mint colors, spacing, corner radii, and motion durations. Semantic Material color roles cover canvas, raised panels, inputs, text, borders, selection, disabled controls, errors, and actions in both themes. Theme objects are cached. Normal text and action foreground contrast are tested at 4.5:1 or better on the tested surfaces.

`AgentSettings.appearance` is the only persisted model addition: `system` (default), `light`, or `dark`. Existing settings deserialize safely without the new field. The existing account-specific preferences store persists it. It grants no permission and changes no execution policy. `AgentAtelierScope` applies the preference to the studio, settings, language preferences, history, and Autopilot routes. Voice deliberately uses a dark emerald canvas. State-owned dialogs capture the feature theme.

## Implemented experience

| Area | Behavior |
| --- | --- |
| Home | Compact Agent identity, editorial emerald hero, restrained ambient highlight, six adaptive shortcut cards with icons and descriptions, editable suggestion prefills, real recent missions, thoughtful empty state, actual execution mode and activity shortcut. |
| Conversation | Readable adaptive bubbles, grouped speaker identities, existing Markdown formatting, copy and read-aloud callbacks, real errors, optional guidance cancellation, lazy message building, and a jump-to-latest control. New responses follow only while the reader is near the end. |
| Composer | Floating surface, multiline input, disabled empty Send, submission guard, microphone states, editable transcript review, bounded transcript scrolling, and a persistent input/action row. Narrow keyboard layouts reduce supporting content and input height. Unsent input survives settings/history navigation. |
| Voice | Code-rendered mint orbital artwork, real recognizer amplitude, distinct listening/reviewing/speaking/error labels, privacy information, language indicator, first-use disclosure, transcript editing, stop controls, text fallback, and existing Android speech recovery. Reduced motion disables amplitude scaling and transition duration. Amplitude-only events rebuild the orb instead of the full conversation. |
| Goal planning | Actual goal title, tabular target amount, currency, deadline, and expandable weekly pace computed through the existing exact-decimal scenario calculation. No invented saved balance. |
| Tasks | Actual title, planned date, flexible or specified time, and textual priority. Existing editor still changes the real draft. |
| Reminders | Human-readable recurrence, time, linked target state, and truthful notification-permission dependency. Existing scheduling and delivery behavior is unchanged. |
| Missions | Connected numbered step timeline, domain icons, exact typed previews, real completion counts, inline validation, edit/remove/select actions, and accessible up/down controls. Controls cannot move a dependency behind its dependent step. |
| Review and execution | Structured review surfaces retain exact action summaries, financial-confirmation explanations, immutable reviewed snapshot approval, per-step results, cancellation, and existing safe retry/reconciliation. Completed, failed, partial, and pending states come from the engine. |
| Savings preparation | Contribution draft, exact proposed currency/amount, authorized goal label when available, and explicit confirmation in the existing Add Savings flow. The UI never claims that money was recorded. |
| What-If | Typed scenario preview, fixed-contribution projection, precise numeric controls, currency-quantized slider, frequency/target/deadline fields, and live exact-decimal result in the editor. The chart uses doubles only for drawing coordinates; financial results use the existing calculator. It shows at most 12 contribution periods and labels its assumptions. |
| Autopilot | Consistent hero, selectable mode cards, persisted category controls, original consent dialogs, execution limits, pause, reset, and actual activity navigation. Financial and destructive actions retain existing protected confirmation. |
| History | Real saved mission timeline, date/status/step count, All/Completed/Drafts/Failed filters, lazy activity tiles, and open-selected-mission behavior. Autopilot results remain in the existing separate activity ledger; internal record IDs and policy version strings are no longer presented as ordinary UI copy. |

New core home, composer, privacy, and preview copy uses the existing English/Filipino/Taglish preference resources. Existing diagnostic messages and some advanced settings retain their existing English fallback.

## Accessibility, layout, and performance

- Existing SafeArea and Scaffold keyboard handling remain active. Content is limited to 780 logical pixels. Shortcuts use one, two, or three columns according to space and text scaling.
- Buttons and voice controls retain approximately 48-pixel Material touch targets and tooltips. Selection and execution states include labels/icons; recording is never indicated by animation alone.
- Large-text section actions stack vertically. Long chip labels wrap. The compact app-bar title uses ellipsis with its full semantic text; financial and draft content wraps vertically.
- Existing reduced-motion utilities control orbital and Material selection transitions. The orb has no continuous timer, shader, audio simulation, or decorative background work.
- Chat and mission-history lists build visible rows lazily. The existing 100-message cap remains unchanged, and new-message detection still works at that cap. Voice amplitude notifications are isolated from conversation rebuilds.
- Text, focus, scroll, voice, authentication, and lifecycle cleanup remain active. No service orchestration or financial code was moved into reusable widgets.

## Verification

Test data and voice adapters are deterministic fakes; tests do not require live Gemini, Firebase, or microphone access.

| Check | Actual result |
| --- | --- |
| `flutter pub get` | Passed; no dependency or lockfile changes. |
| `flutter analyze --no-pub` | Passed; no issues found. |
| `flutter test --no-pub --reporter expanded` | Passed: **864 tests**, zero failures, including all 19 new Atelier tests and four golden comparisons. |
| `flutter build apk --debug --no-pub` | Passed; Gradle `assembleDebug` completed in 76.7 seconds. Artifact: `build/app/outputs/flutter-apk/app-debug.apk`. |
| `git diff --check` | Passed. |

The full test run printed one off-screen tap warning in the unchanged `mint_aurora_test.dart` large-text Shared-tab case; that test passed. No Agent widget warnings remained in the final run. Validation logs are in `build/agent-atelier-*.log` (generated, not committed).

New integration-test files: none. The build verifies Android compilation and packaging; it does not substitute for device installation or live-service testing.

The 19 new tests in `test/agent_atelier_test.dart` cover appearance migration/persistence, System brightness changes, color contrast, all six shortcut prefills, live scenario editing, actual history filtering, dependency-safe reorder controls, long conversation scrolling/lazy construction, reduced-motion voice behavior, and responsive dark previews at 320/360/390/412/480/600 pixels. Four deterministic, visually reviewed golden baselines cover home light/dark, a goal mission, and listening mode. Existing Agent tests continue to check explicit approval, contribution protection, multilingual clarification, voice recovery, and Autopilot policies. Existing interaction tests now wait for the disabled Send control to update after typing and scroll to controls moved by the new layout.

Golden command: `flutter test test/agent_atelier_test.dart`. Intentional baseline updates use `--update-goldens`, followed by visual inspection. Golden fonts load from the bundled Manrope asset and the installed Flutter SDK's Material Icons. Use the same Flutter renderer/font assets for cross-machine baseline comparisons.

## Files

Created:

- `lib/agent_studio/presentation/agent_theme.dart`
- `lib/agent_studio/presentation/agent_widgets.dart`
- `lib/agent_studio/presentation/agent_action_preview.dart`
- `lib/agent_studio/presentation/agent_history_screen.dart`
- `lib/agent_studio/presentation/agent_orb_artwork.dart`
- `test/agent_atelier_test.dart`
- Four `test/goldens/agent_atelier_*.png` files
- This implementation report

Modified: `agent_domain.dart`, `agent_screen.dart`, `agent_step_editor.dart`, `agent_settings_screen.dart`, `agent_language_settings.dart`, both Autopilot presentation screens, four existing Agent widget-test files, and the README documentation link.

No dependencies changed. No production engine, planner, AI gateway, voice service, financial arithmetic, authentication, Firestore repository, security rule, notification scheduler, shared-goal permission, Android widget, or Coach implementation changed. No new native integration tests or hardware performance measurements are claimed.

## Practical limits and follow-up

There was no connected Android device or emulator during implementation. Live recognition, real microphone permission transitions, TTS output, notification delivery, device accessibility navigation, and frame/battery profiling still need on-device review. Golden/widget tests validate rendering and mocked interaction, not hardware speech or network services. Firestore emulator suites were not run; repositories and security rules were unchanged.

The existing Agent guidance path is advisory and non-streaming; streaming in the separate AI Coach is preserved. “Stop waiting” dismisses the local guidance request and ignores its late response; the existing gateway does not expose provider-side cancellation. What-If uses the existing fixed-contribution model, without interest, withdrawals, or exchange-rate changes. Arbitrary multi-scenario comparison and draggable workflow editing were not invented; editable scenarios and safe up/down controls use the supported architecture. There is no fake mission history or success state.

Recommended follow-up: device QA in both themes with large system fonts; real voice/TTS and notification testing; and Android DevTools profiling of a long conversation and the voice view on a low-end phone. Extend remaining advanced English fallback copy through the existing language resources when localization is expanded.
