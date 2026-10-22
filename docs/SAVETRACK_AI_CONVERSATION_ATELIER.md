# SaveTrack AI — Mint Aurora 7.3, Conversation Atelier

Implemented in the existing Flutter application on October 19, 2026.

## Repository audit

SaveTrack AI is `AiCoachScreen`, reached from the dashboard, navigation and existing widget routes. It contains Ask Anything and SaveTrack Coach (AI Coach Lite). The existing controller isolates each mode's conversation, streams Gemini output, supports cancel/retry, limits retained turns, and clears user-scoped state on identity changes.

Coach already provides locally computed fact cards, goal selection, a review sheet for categorical summaries, expiring approval, revocation and a general-advice fallback. Ask Anything never reads the private context source. Firebase authentication, App Check, the Gemini gateway and their configuration remain intact.

SaveTrack AI has no saved-conversation repository, history screen, microphone or text-to-speech service. Agent Studio has separate history and voice features. Those were not imported into SaveTrack AI. There is no separate SaveTrack AI onboarding screen; its existing first-provider-use disclosure is retained.

The previous presentation used a large dark welcome card, boxed assistant messages, small supporting text and a composer embedded directly in the screen. Markdown body text used a fixed light-theme foreground. Clipboard feedback assumed success. The latest-message action changed its state without requesting a rebuild. AI preferences had no dedicated entry point.

## Design and implementation

| Area | Result |
| --- | --- |
| Shared tokens | Reuses `SaveTrackDesign`, `AtelierColors`, the bundled Manrope font, existing mint/emerald colors, semantic theme surfaces, spacing conventions and motion durations. No global palette duplication. |
| New tokens | `AiConversationTheme` adds semantic user-message, assistant, input, action and disabled roles backed by existing tokens. `AiLayout` centralizes reading style, message/composer radii and the 760 dp conversation width. |
| Welcome | Small custom-painted four-point sparkle, restrained radial mint illumination, editorial headline and compact supporting copy. Ask Anything: “A little clarity goes a long way.” Coach: “Small steps. Meaningful progress.” |
| Suggestions | Local, functional starter cards for savings habits, weekly planning, financial education and coding. Coach retains its actual goal, plan, day, report and habit workflows. Cards fill the composer or open the existing context-review flow. No provider call is made just to generate suggestions. |
| Header and modes | Compact back/identity/actions header, accessible new-chat shortcut where space permits, tonal mode tabs, truthful sharing descriptions and a clear read-only Coach identity. |
| User messages | Right-aligned emerald bubbles with selectable text, comfortable padding, adaptive width and a softened trailing corner. Dark mode uses the existing selected surface. |
| Assistant messages | Open reading layout, small identity marker, theme-aware text, clear spacing and a 48 dp copy action. Incomplete, canceled and streaming statuses remain truthful. |
| Response renderer | Preserves Markdown headings, numbered steps, lists, code and existing math support. Source blockquotes become reusable `AiInsightCard` surfaces; source tables use horizontally scrollable `AiComparisonCard` surfaces. Values and illustrative labels come from the answer, with no synthesized financial figures. Copy preserves the original answer. |
| Composer | Extracted reusable, focus-aware composer; grows to five lines, with two visible lines and internal scrolling in constrained layouts. Enter supports multiline editing; Ctrl/Command+Enter sends. Includes disabled, focused, send and stop states. The Scaffold continues to handle keyboard insets and safe areas. |
| Submission and drafts | Submission guard also covers the first-use privacy dialog. Duplicate taps cannot start duplicate sends. Separate mode drafts, preflight-failure recovery and existing retry logic remain. Clearing an empty chat also clears its draft. |
| Follow-ups | Two real draft-building actions after successful answers: request an example or a simpler explanation. They never submit without user action. |
| Local Coach facts | Existing calculations and approval checks are preserved. A persistent facts shortcut and menu action return to the verified local card after reading a reply. Revocation still clears Coach context and its related conversation. |
| Processing and errors | Restrained animated mint dots appear only while awaiting an actual response. Existing offline, quota, timeout, blocked, setup, retry and cancel behavior remains connected to the real controller. Clipboard errors now show failure feedback. |
| AI settings | New scrollable settings sheet with the real mode selector, existing global Light/Dark/System persistence, session-history explanation, supported-language guidance and the existing provider privacy notice. No unsupported language, voice or response-length toggles. |
| History | Existing in-memory, per-mode conversations are preserved. Settings explicitly explains that chats are cleared on leaving/sign-out. New/Clear Chat retains the confirmation flow. No fabricated saved-history screen. |
| Voice | No voice controls added: this feature has no existing speech service. Agent Studio voice remains untouched. |
| Light/dark | Pale mint canvas and tonal white surfaces in light mode; midnight emerald and subdued mint surfaces in dark mode. Corrects Markdown foregrounds, inline code, tables and follow-up typography. Settings typography remains stable while the app changes themes. |
| Responsiveness | Constrained desktop/tablet reading width; adaptive one/two-column prompt cards and stacked mode controls for large text. Short landscape and keyboard-open layouts use a denser composer without losing multiline input. Very short layouts and compact error states keep mode switching in AI settings to leave room for the composer and Retry. |
| Accessibility | Selectable messages, labeled icon controls, selected-mode semantics, semantic welcome heading, live processing/error announcements, readable metadata and normal device text scaling. Active text/action color contrast is tested against a 4.5:1 minimum. |
| Motion | Short message fade/translation, refined input focus transition, existing selection motion and native ink feedback. All custom motion respects reduced-animation/accessibility preferences. Thinking dots become static under reduced motion. |
| Scrolling | Keeps the existing near-latest follow behavior. Readers who scroll upward retain their position during streaming. Latest returns to the newest content and clears its affordance correctly. |
| Performance | Retains lazy conversation building, bounded history, batched streaming updates and per-message listeners. Static vector emblem, local starters and no added network assets or dependencies. No device performance profile was performed. |

## Files

Created:

- `lib/ai_coach/ai_theme.dart`
- `lib/ai_coach/ai_conversation_widgets.dart`
- `lib/ai_coach/ai_settings_sheet.dart`
- `test/ai_conversation_atelier_test.dart`
- `test/goldens/ai-atelier-welcome-light.png`
- `test/goldens/ai-atelier-welcome-dark.png`
- `test/goldens/ai-atelier-conversation-light.png`
- `test/goldens/ai-atelier-conversation-dark.png`
- `test/goldens/ai-atelier-response-cards.png`
- `test/goldens/ai-atelier-settings.png`
- This report.

Modified:

- `lib/ai_coach/ai_coach_screen.dart`
- `lib/ai_coach/ai_widgets.dart`
- `lib/ai_coach/ai_response.dart`
- `test/ai_coach_widgets_test.dart`

No packages added or removed. No changes to Firebase rules, authentication, model selection, provider payloads, financial operations, the AI controller or Agent Studio files.

## Validation

The new test file adds 31 cases, including six deterministic widget goldens with the bundled production font. Coverage includes both modes at 320/360/390/412/480/600/840 dp in light and dark themes; 2× text with a keyboard; multiline drafts; duplicate submission prevention; retry without duplicate messages; compact error/retry layouts with a keyboard; scroll stability; Filipino/Taglish and structured responses; clipboard failure; actual global appearance switching/persistence; session-history disclosure; and contrast.

The existing widget suite was updated for the new welcome copy and explicit navigation to the verified facts card. Existing security, service, math, consent, App Check and Agent Studio regressions are retained.

| Check | Actual result |
| --- | --- |
| `flutter pub get` | Passed. No dependency changes. |
| Dart formatting | All eight changed/new Dart files are formatted; the final format check made no changes. |
| `git diff --check` | Passed. |
| `flutter analyze` | Passed: no issues found. |
| Focused AI widget suites | 57 tests passed, including all 31 new cases and the six golden comparisons. |
| `flutter test` | Passed: all 930 tests, including existing Agent Studio, AI security/consent, math, currency, planner, savings, authentication and other application regressions. |
| `flutter build apk --debug` | Passed on the final source. APK: `build/app/outputs/flutter-apk/app-debug.apk`. |

Logs are in `.buildlog/ai-atelier-pub-get.log`, `.buildlog/ai-atelier-final-analyze.log`, `.buildlog/ai-atelier-final-ui-tests.log`, `.buildlog/ai-atelier-full-tests.log` and `.buildlog/ai-atelier-android-build.log`.

## Visual review and limitations

Rendered and visually inspected the six widget golden images: light/dark welcome, light/dark chat, response cards and settings. These contain synthetic fixtures and make no live Gemini requests. Corrected dark follow-up typography, quote line breaks, live appearance-switch typography and the short landscape composer during review.

No known layout overflows remain in the tested configurations. No Android device or emulator was connected (`adb devices` returned an empty device list). Device rendering, Android keyboard/IME behavior, live Gemini output and low-end-device frame performance have not been manually exercised.

Saved history, speech and persisted language/response-length preferences remain outside this presentation change because SaveTrack AI does not implement them. Tables intentionally scroll horizontally on narrow screens. Message timestamps are not invented: the existing message model has no timestamp field. Structured cards depend on Markdown actually present in the response; arbitrary plain prose remains readable prose.

Recommended follow-up: run the built APK on a representative Android device to review the system keyboard, TalkBack, text scaling and frame timing, then verify a live provider response using the existing Firebase configuration.
