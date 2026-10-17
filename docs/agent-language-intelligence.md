# Mint Aurora 6.1 — Language Intelligence implementation report

Implemented in the existing SaveTrack Flutter app on October 17, 2026. No separate app, paid provider, billing change, dependency upgrade, or Firestore rules change was introduced.

## Audit and architecture

The repository already had a native Kotlin speech/TTS bridge, Firebase AI Logic, typed goal/task/reminder/contribution/scenario/allocation drafts, an account-scoped local store, mission editing, and a trusted approval/execution service. These remain the integration points. The previous planner depended mainly on English keywords, Arabic numerals, and a small date vocabulary. Follow-ups could select the first incomplete step. Recognition and TTS shared one locale setting.

`LocalAgentPlanner` now produces both the existing typed draft actions and an ephemeral `AgentInterpretation`. Processing separates matching normalization, language detection, number/calendar extraction, clause negation, corrections, context resolution, ambiguity checks, and draft validation. Widgets display results rather than parsing money or language. Unresolved fields remain explicit review blockers.

## Language, intent, and context

- Automatic, English, Filipino/Tagalog, and Taglish written-response preferences. Automatic detection uses local lexical evidence and preserves the previous conversational language for short replies and numbers. It reports no invented confidence score.
- Independent Agent interface, written-response, recognition preference/locale, and spoken-response locale/voice settings. Existing language, permissions, history, and locale settings remain readable. Switching languages retains the mission.
- Filipino and Taglish command vocabulary includes `gawa`, `gawan`, `gusto`, `ipon`, `pa-create`, `pa-add`, `pa-remind`, `dagdagan`, `magtabi`, `maghulog`, `gawain`, `ayusin`, and `tuwing`. Politeness and fillers do not require grammar correction. Non-fluent examples are included in the corpus.
- Normalization handles whitespace, fullwidth ASCII, Unicode quotation/dash variants, and a small explicit informal-spelling dictionary. It preserves negation, signs, decimal punctuation, and a separate immutable original utterance. This is intentionally limited matching normalization, not universal spelling correction or full Unicode canonical normalization.
- Typed intents distinguish creation, planning, contribution preparation, questions, modification, cancellation, and unsupported operations. Questions mentioning withdrawals do not create withdrawal proposals. Existing-record edits remain in their dedicated screens.
- Creation verbs are bound to their objects: a reminder or task mentioning an existing/new goal, or a task title containing “make a savings target”, does not create an extra goal. Natural “savings target”, “Create savings ko laptop”, “to-do”, and “activity” phrases are recognized alongside the existing vocabulary.
- Clause negation suppresses rejected operations. A later positive direction can survive a rejected withdrawal. Cancellation and change-of-mind expressions cancel proposals. Negated follow-ups pause review of an existing mission.
- Explicit correction markers select the latest amount or schedule. Amount evidence offsets refer to the original current input. Earlier words remain available in ephemeral interpretation memory, never transcript history on disk.
- Single-field replies update existing drafts while keeping their other values. Step numbers and Filipino/English ordinal references identify steps. A pending ambiguous amount change can be resolved by `yung pangalawa`, without repeating the original amount. A short goal-name reply preserves spelling. Pending interpretation context is bound to the current mission snapshot and expires after an unrelated edit or opening another mission.
- Local goal matching accepts only caller-authorized records, preserves similar matches, and supports explicitly quoted names. The production goal selector reads personal goals only after the private-context permission and an explicit selection interaction. It checks identity, permissions, and the mission snapshot again after asynchronous reads/dialogs.

## Financial numbers and calendar parsing

The money parser uses SaveTrack's `ExactDecimal` and existing currency validation. It supports common English/Filipino number words, linking forms such as `limang daang piso`, `dalawang libo't limang daan`, grouped decimals such as `1,500.50`, compact thousands, and explicit millions. Binary floating-point is not used to calculate parsed money.

Currency codes and explicit peso/euro/pound markers are recognized. Ambiguous dollars and conflicting currencies require clarification. New goals can inherit the app's configured currency; selected existing goals retain their own currency. Bare numbers do not universally imply PHP. Exchange rates and existing conversion calculations are unchanged.

Approximation (`mga`, `siguro`, `around`), alternatives, ranges, malformed grouping, negatives, zero amounts, excessive precision, and out-of-range amounts remain unresolved. `one fifty`, `one five`, and `1.500` require repair. Calendar dates, times, step counts, and task counts are masked before money extraction. Extracted money remains a proposal requiring review; contributions still open the existing Add Savings flow for separate confirmation.

Calendar parsing supports ISO dates, explicit English/Filipino named dates with years, today/ngayon, tomorrow/bukas, makalawa, English/Filipino weekdays, daily and weekly recurrence, AM/PM times, and common spoken clock expressions. It uses the supplied application/device-local clock and calendar arithmetic, including month/year/leap-year boundaries. It does not use a model's clock.

Invalid dates, past deadlines, ambiguous numeric dates, `next Friday`, vague month deadlines, and unspecified AM/PM are left unresolved. One-time weekdays and recurring weekdays remain distinct. A weekday repair preserves an existing weekly reminder. Monthly/payday schedules are explicitly unsupported by the existing Agent reminder contract and are not silently converted into weekly reminders.

## Clarification, UI, and review safety

The existing emerald/mint visual system is retained. New UI includes Language & Understanding settings, a language/capability chip, localized Filipino/Taglish welcome/input/quick actions, core permission and mission labels, localized review summaries and approval controls, visible amount choices, an authorized personal-goal selector, and editable transcript review with retry/cancel controls. Names are not translated. Screens are scrollable and use wrapping controls; light/dark and large-text tests cover the new flows.

The clarification engine asks compact questions for missing or uncertain fields. Per-step uncertainty metadata persists through opt-in mission history and belongs to the approval snapshot. Editing another step cannot clear an unresolved time or amount. Typed form edits or explicit field repairs clear relevant blockers. Generic validation and some advanced/editor/help text still use the existing English resources; this is Agent-focused localization, not app-wide Filipino translation.

`plan lang muna` / `wag muna i-save` persists a draft-only review block. A dedicated on-screen control can allow review later; it never approves or executes anything. Chat or spoken `yes`, `sige`, and `approve` cannot authorize actions. Changes invalidate prior approval through the existing snapshot, account, permission-epoch, expiry, and one-use checks. The native backend, contribution confirmation, idempotent record IDs, retry bounds, and mode boundaries remain in place.

Conditional mutation requests using `if`, `kung`, or `kapag` also stay draft-only until the user explicitly allows review. Their block survives amount corrections and mission serialization. Conditional words inside quoted proper names do not trigger this rule; read-only scenarios do not acquire an execution block.

## Voice and Gemini integration

The existing Android bridge is reused rather than adding speech packages. Reported recognizer locales drive selection, including Filipino `fil` and Tagalog `tl` tags and underscore/hyphen canonicalization. Filipino requests fail clearly when the recognizer does not report a compatible locale. Taglish is labeled best effort. Device-default recognition and text remain available. The existing on-device recognizer/model check and no-remote-fallback behavior remain intact.

Kotlin now returns up to five recognizer hypotheses and actual confidence values when supplied. Dart retains these as local review signals, marks partial results provisional, and rejects stale session callbacks. It never submits hypotheses as approval. Transcript amounts/names/dates can be corrected before sending. Raw audio is not stored by SaveTrack. Android's selected speech provider may process audio remotely unless verified on-device recognition is required; the existing disclosure remains visible.

TTS capabilities now include languages and voice locale/network metadata. Spoken-response language is independent of recognition. Unsupported TTS languages and mismatched voices fail visibly. Selecting the device TTS default resets to its captured default language rather than retaining the preceding locale. Spoken replies remain opt-in and private-detail suppression remains enabled by default.

The native bridge also reports the actual default TTS locale. The private, generic spoken notice uses Filipino for a reported Filipino/Tagalog locale or selected voice, and English for English output, independently of the written-response preference. No dynamic financial details enter that notice.

The Firebase AI Logic prompt now describes English, natural Filipino, and Taglish, with synthetic negation/correction/clarification examples. Gemini remains optional abstract workflow guidance: `AgentSafeRequest` can carry only action-type enums and a language enum. It cannot carry raw input, records, financial values, IDs, transcripts, dates, or history. Response schema validation and strict local JSON field/action allowlists remain enforced. No model-generated JSON can authorize writes. The configured model and Spark-first setup are unchanged. No live model benchmark or provider call was performed during this upgrade.

For Automatic responses, optional guidance uses the detected conversation-language enum. An explicit language preference takes precedence. The external-context consent screen still precedes the request; a fake-gateway widget test verifies this integration without a live provider call.

The native API behavior follows Android's [SpeechRecognizer reference](https://developer.android.com/reference/android/speech/SpeechRecognizer), [TextToSpeech reference](https://developer.android.com/reference/android/speech/tts/TextToSpeech), and [Voice metadata reference](https://developer.android.com/reference/android/speech/tts/Voice).

## Measured synthetic evaluation

`test/fixtures/agent_language_v1.json` contains 330 versioned synthetic text cases with stable intent/slot/clarification expectations and a fixed local clock. These include template-expanded number/language combinations, punctuation variants, and targeted safety examples. This is a development regression corpus used while implementing the parser, not a held-out estimate of real-world accuracy. The voice-transcribed cohort is synthetic text, not recordings or actual recognizer output.

| Cohort | Intent matches | Annotated slot matches | Intent macro F1 |
|---|---:|---:|---:|
| English | 85 / 85 | 177 / 177 | 1.000 |
| Filipino | 82 / 82 | 177 / 177 | 1.000 |
| Taglish | 72 / 72 | 176 / 176 | 1.000 |
| Non-fluent English | 30 / 30 | 114 / 114 | 1.000 |
| Non-fluent Filipino | 30 / 30 | 114 / 114 | 1.000 |
| Synthetic voice-transcribed text | 31 / 31 | 115 / 115 | 1.000 |

Overall: 330/330 intent matches; 873/873 annotated slot matches; 225/225 annotated clarification decisions; zero unexpected action proposals across 54 negative cases. Per-intent precision/recall/F1 and per-field counts are in [the measured results](agent-language-v1-results.json). Amount 240/240, currency 234/234, date 156/156, goal name 180/180, and time/weekday/recurrence each 21/21 matched their annotations. Target disambiguation and multi-turn field preservation are exercised in focused unit/widget tests rather than included in those single-turn slot totals.

The evaluator automatically writes `build/reports/agent_language_v1_results.json`. No speech WER/CER, accent accuracy, unseen-language accuracy, general slang coverage, or live Gemini accuracy is inferred from these numbers.

An additional 50-case [specification acceptance pack](../test/fixtures/agent_language_acceptance_v2.json) covers the direct non-fluent examples, conditional drafts, and verb/object boundaries. It matched 50/50 intents and 48/48 annotated slots, with zero unexpected proposals in eight negative cases. Its [separate measured results](agent-language-acceptance-v2-results.json) retain per-language and per-intent metrics. Together, the two packs contain 380 cases and 921 annotated slots. These are development regression cases, not a held-out accuracy estimate. Multi-turn conditional safety, Automatic guidance consent, and private TTS notice selection are tested separately.

## Verification

Final verification results:

- `flutter pub get`: passed; no dependency changes.
- Modified Dart source/tests: formatted.
- `flutter analyze --no-pub`: passed, no issues found.
- `flutter test --reporter expanded`: passed, **680 tests**. This includes existing authentication, currency, shared savings, Planner/reminders, reports-related calculations, AI modes, Agent approvals/backends, and home-widget regression tests alongside the new language tests and direct specification acceptance pack.
- Native `AgentVoiceBridgeTest`: passed, **25 tests**, zero failures/errors/skips across the configured Robolectric API levels.
- `flutter build apk --debug`: passed. Output: `build/app/outputs/flutter-apk/app-debug.apk`.
- Screenshots were rendered and inspected for language settings and Filipino large-text light/dark screens under `build/ui-preview/agent-language-*.png`. A dropdown width regression and a test scrolling issue discovered during the first full run were fixed before the final passing run.
- No Android device speech test or live Gemini benchmark was performed.

Commands: `flutter pub get`, formatting of changed Dart files, `flutter analyze --no-pub`, `flutter test --reporter expanded`, `gradlew.bat :app:testDebugUnitTest --tests com.example.myproject.agent.AgentVoiceBridgeTest`, and `flutter build apk --debug`.

Focused tests cover language/context, normalization, numbers and precision, date boundaries, recurrence, self-corrections, negation/cancellation, goal matching, clarification, per-field blockers, approval invalidation, opt-in history, safe AI payloads, locale capability checks, and local transcript hypotheses. Widget tests cover independent language settings, Filipino large text/light/dark, draft-only review, amount repair, goal selection, and existing voice recovery. Native tests use Robolectric, not a real microphone.

Android SDK platform-tools `adb devices` returned no connected Android hardware/emulator. Installed phone recognizer/TTS locale inventories and live English/Filipino/Taglish speech were therefore not measured. The app queries capabilities at runtime; there is no claim that Filipino speech is installed on any particular phone. Existing Gradle/plugin deprecation and JDK native-access warnings remain outside this change.

## Source inventory and dependencies

Created:

- `lib/agent_studio/agent_language_settings.dart`
- `lib/agent_studio/intelligence/agent_language.dart`
- `lib/agent_studio/intelligence/agent_interpretation.dart`
- `lib/agent_studio/intelligence/money_expression_parser.dart`
- `lib/agent_studio/intelligence/date_expression_parser.dart`
- `lib/agent_studio/intelligence/voice_locale_repository.dart`
- `lib/agent_studio/intelligence/multilingual_evaluator.dart`
- `test/agent_language_intelligence_test.dart`
- `test/agent_language_corpus_test.dart`
- `test/agent_language_widgets_test.dart`
- `test/agent_language_followup_test.dart`
- `test/fixtures/agent_language_v1.json`
- `test/fixtures/agent_language_acceptance_v2.json`
- This report and `docs/agent-language-v1-results.json`.
- `docs/agent-language-acceptance-v2-results.json`.

Modified:

- `lib/agent_studio/agent_domain.dart`, `agent_planner.dart`, and `agent_engine.dart`
- `lib/agent_studio/agent_screen.dart`, `agent_settings_screen.dart`, and `agent_voice.dart`
- `lib/agent_studio/agent_ai_gateway.dart`
- `android/app/src/main/kotlin/com/example/myproject/agent/AgentVoiceBridge.kt`
- `android/app/src/test/kotlin/com/example/myproject/agent/AgentVoiceBridgeTest.kt`
- `test/agent_studio_test.dart` and `test/agent_voice_recovery_widgets_test.dart`
- `README.md` (report link).

No packages were added or changed. Existing `firebase_ai`, the native Android recognizer/TTS integration, exact money utilities, SharedPreferences, and the current Flutter/Kotlin toolchain were reused. Authentication, shared savings, balance calculations, Planner persistence, reminder scheduling, reports, AI Coach, Ask Anything, home widgets, and Firestore rules were not reimplemented.

## Remaining limitations and next evaluation work

The local parser is deliberately bounded: unfamiliar number compounds, novel slang, complex nested negation, arbitrary multi-target entity binding, unspecified times/dates, and unsupported operations need clarification or existing forms. It is not a general multilingual language model. Cebuano, Ilocano, Hiligaynon, and other Philippine languages/dialects are not advertised as supported. TTS/recognition availability depends on the installed provider/model; Taglish accuracy cannot be inferred from a locale label.

Next useful accuracy work is a separate, independently authored held-out corpus; broader adversarial correction/negation and multi-step field-binding cases; real consented device speech with critical-number/date error measures; and a quota-controlled abstract Gemini prompt regression check. Expand Filipino resources for remaining generic form/help/validation text as the application-wide localization system grows.
