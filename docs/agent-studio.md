# SaveTrack Agent Studio Pro — Mint Aurora 6.0

Optional **Agent Autopilot (Mint Aurora 6.5)** adds policy-authorized automatic
actions while keeping Ask First as the default. See [Autopilot settings,
architecture and limitations](agent-autopilot.md).

Agent Studio is integrated into the existing dashboard and app bar. Ask Anything
and the read-only Coach retain their own controllers, histories, and permissions.
Agent Studio uses the app's existing Flutter state pattern (`ChangeNotifier` and
injected service interfaces), Firebase initialization, App Check, currency math,
personal goal/task schemas, Add Savings dialog, and notification coordinator.

## Using it

1. Open **Agent Studio**. Type a request or tap the microphone. The voice disclosure
   precedes Android's permission prompt. Review and edit the transcript, especially
   names, currencies, amounts, and dates, then press Send.
2. Edit the proposed cards. Goal deadlines, currencies, reminder times, and target
   selections must be explicit. Task start times may be flexible, consistent with
   the existing Planner. Missing details block approval. Follow-up dates and values
   can complete the current draft; ambiguous changes require a step selection.
3. In **Agent settings**, explicitly enable Execute Approved Actions and the
   individual operations you want. Private Context Access is separate and is
   required to load existing goal choices or calculate a goal allocation.
4. Select steps, then **Review mission**. The dedicated final approval dialog shows
   the exact values and dependencies. Typed/spoken “yes” never executes a mutation.
5. Inspect each actual result. Retry unfinished steps through another review.
   A successful step is retained if another fails. Cancel stops subsequent steps;
   a request already accepted by a service may finish.

Examples: `Create a savings goal for a laptop worth PHP 30000 by 2027-01-31`,
`Create a task to compare prices tomorrow at 2:30 pm`, `Remind me every Saturday`,
`Prepare PHP 200 for my goal`, and `Simulate a PHP 30000 target with PHP 500 weekly`.
English and common Filipino/Taglish commands are deterministic local assistance,
not unrestricted natural-language reasoning. Unsupported/ambiguous requests leave
fields blank or offer the existing app workflows. Unspecified dates/times and
word-number financial amounts are never guessed.

## Implemented boundaries

`agent_domain.dart` contains typed, allowlisted action arguments, validation,
immutable mission/step snapshots, dependencies, selection, versions, results,
settings, and permissions. It rejects unknown action fields and types, malformed
money, unsupported currencies/precision, invalid paths, cycles, missing/deselected
dependencies, duplicates, conflicting proposed start times, and oversized missions.
Limits: 12 steps, 6 tasks, 3 reminders, 3 attempts per step, 3,000 input characters.

`agent_engine.dart` separates draft/review/approval/execution. Approvals have private
constructors, an engine-specific issuer, exact snapshot, account, permission epoch,
ten-minute expiry, and single-use state. A successful review must precede minting.
Edits, selection changes, account changes, permission changes, cancellation, and
expiry invalidate approval. Neither an AI gateway nor persisted history can mint
an approval. The engine validates again after asynchronous server reads and before
each operation. Execution follows dependency order and reports individual outcomes.

`agent_backend.dart` performs bounded, owner-scoped server checks, normalizes
duplicate goal/task names, checks existing task schedule windows using the existing
Planner parser, and never reads transaction histories or member identities.
Shared goal mutation and shared reminder management remain in existing protected
screens. The Agent cannot modify/delete existing goals, withdraw, write arbitrary
documents, fetch arbitrary URLs, or run shell commands.

The shared `AppRecordRepository` creation seam is used by existing goal/task forms
and the Agent's typed adapter. It uses Firebase transactions and stable per-step
record IDs, with a serialized operation marker to prevent a changed retry from
overwriting an existing record. Reconciliation does not reset savings balances or
task completion after creation. Financial arithmetic uses `ExactDecimal` and
`parseCurrencyAmount`; conversion to the existing numeric Firestore format occurs
only at the established storage boundary. This does not migrate existing balances.

Reminder creation uses the existing `ReminderCoordinator.save` with a conditional
`FirestoreReminderRepository.createReviewed` persistence callback. Its transaction
refuses to replace a different reminder created/edited since review. Identical
replays reconcile. The result distinguishes a server-saved preference from this
phone's actual scheduling/permission status; unsupported devices do not claim
notification delivery. There is no second notification engine.

Contributions open the existing currency-aware Add Savings dialog, including its
account guard, validation, confirmation, and idempotent financial request ID.
The mission does not itself deposit or claim to verify a deposit. Exact local
savings scenarios and equal allocations are calculations only. Allocations retain
the original currency and distribute every minor unit without a rounding loss.

Transactions protect retries for these creation operations. This is not a claim
of universal exactly-once semantics or automatic rollback. Duplicate detection is
bounded and cannot prevent every concurrent independently created duplicate.

## External AI and Firebase Spark

Core planning works without Gemini or a paid service. Optional **Gemini planning
guidance** shows the exact request before submission. Its request type can carry
only an enum set of action types and reply language. It cannot carry arbitrary
user text, transcript, money, names, identifiers, schedules, app records, history,
or memory. A strict categorical projection replaces reliance on imperfect regex
redaction. It deliberately provides abstract workflow guidance, not remote private
financial analysis or arbitrary financial tool interpretation.

The isolated gateway uses Firebase AI Logic's Gemini Developer API, the centralized
existing `AiConfig.model` (`gemini-3.5-flash-lite`), limited-use App Check tokens,
a structured JSON schema, bounded output, a 45-second deadline, and no automatic
retry/fallback/tool loop. Unknown actions, extra fields, malformed JSON, and
oversized responses are rejected. Guidance is advisory text and never executes
or silently adds actions. Late responses after cancellation, navigation, account
changes, or mission changes are ignored. Canceling local consumption cannot undo a
provider request already accepted or its quota use.

The model's no-billing eligibility and structured-output support were checked on
2026-10-17 against [Firebase models](https://firebase.google.com/docs/ai-logic/models),
[pricing](https://firebase.google.com/docs/ai-logic/pricing),
[quotas](https://firebase.google.com/docs/ai-logic/quotas),
[Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing), and
[structured output](https://firebase.google.com/docs/ai-logic/generate-structured-output).
Availability and actual quotas must still be verified in this project's Console.
No billing, Cloud Functions, new server, raw Gemini secret, or paid speech service
was introduced. Dependencies are reused; no additional package is required.

The existing [AI setup guide](ai-coach.md) describes required Firebase AI Logic API
enablement, Android Play Integrity registration, development debug-token
registration, production signing, and Console enforcement/replay protection.
Installing App Check does not prove Console enforcement. This implementation does
not change the Firebase plan, deployed rules, signing configuration, or Console.

## Voice, privacy, and retention

Android's scoped `AgentVoiceBridge.kt` uses SpeechRecognizer and TextToSpeech via
one method channel. Manifest changes add RECORD_AUDIO and speech/TTS package
visibility. No minimum SDK increase or foreground/background audio service is
needed. Recognition is user-initiated, partial/final transcripts are editable,
and synthesis stops recognition before playback. Native audio focus loss, app
backgrounding, cancellation, disposal, permission denial, unavailable engines,
network/no-match errors, and a 60-second listening cap release audio resources.
Session IDs and generations reject stale callbacks. The orb uses actual RMS input
when available; its other states are generic status visualization.

The device's reported recognition languages and installed TTS voices are exposed
in settings. A device default is available when the service does not report a
language list. On-device recognition is explicitly requested only when Android
reports availability; an unsupported local recognizer never silently falls back
to remote recognition. Installed language models can still be unavailable.
Spoken replies are off by default. Hide Financial Details in Speech sends only a
fixed generic summary to TTS, excluding dynamic amounts, names, and task text.
Turning that off permits spoken conversation text, subject to the chosen TTS
engine's processing. No raw audio is recorded to storage or uploaded by SaveTrack.
This is turn-based speech recognition plus TTS, not full-duplex live audio.

Chats and transcripts are session-only. Optional history stores mission drafts and
actual results in account-scoped app-local preferences, up to 50 missions, with a
30-day filter on access/save. It is not encrypted storage; operating-system backups
follow the existing app backup policy. History defaults off;
turning it off deletes local mission history. With history off, process termination
does not preserve the draft, so inspect existing app records before recreating a
request. Restored interrupted steps require fresh review and reconcile stable
record IDs; they never auto-run. Preferences and approved memory are account
scoped. Logout clears visible state, invalidates approval, stops audio, and exits
Agent routes. Saved opt-in history remains available only when that account signs
back in. Memory is limited to explicitly selected preferences, editable/deletable,
and never sent to external AI; a remembered weekday still appears in the draft.

## Validation and feature limits

Checks executed for the initial implementation in this workspace:

| Check | Actual result |
| --- | --- |
| `flutter pub get` | Dependencies resolved; existing package versions retained |
| Dart formatting on changed files | Completed |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub --concurrency=2 --reporter expanded` | All **605** tests passed, including **55** new Agent tests |
| `:app:testDebugUnitTest` with Android Studio's bundled JDK | Gradle reported BUILD SUCCESSFUL; XML reports verify **57** tests, zero failures/errors, including **6** new voice lifecycle cases on APIs 29, 31 and 35 |
| `flutter build apk --debug --no-pub` | Built `build/app/outputs/flutter-apk/app-debug.apk` from the final source |
| Responsive Agent UI suite with real-font preview mode | All **15** tests passed; review captures rendered and inspected |
| `git diff --check` | Passed; Git emitted only line-ending conversion notices |

New Dart coverage includes local English/Taglish extraction, missing and ambiguous
values, calendar validity, exact money, dependency cycles, duplicate/conflicting
steps, strict model parsing and categorical privacy, stale/expired/forged-context
approval rejection, double taps, permission revocation during an asynchronous
server check, cancellation, partial failure, retries, persistence failure,
account isolation, conditional reminder creation, actual goal/task adapter schema
and idempotency, same-currency minor-unit allocation, voice permission failure,
transcript review, stale callbacks, opt-in TTS privacy, and explicit final UI
confirmation. Layout checks cover 320, 360, 390, 412, 480, 600 and 960 pixels,
200% text, portrait keyboards, and short landscape.

Logs: `build/agent-analyze.log`, `build/agent-all-tests.log`,
`build/agent-native-tests.log`, `build/agent-android-build.log`, and
`build/agent-ui-tests.log`. Native reports are in
`build/app/test-results/testDebugUnitTest/`. Screenshots are
`build/ui-preview/agent-home.png`, `agent-mission.png`, `agent-review.png`, and
`agent-voice.png`. Preview content uses test-only fixtures and fake speech
events; it is not evidence of a live provider or physical microphone session.

Live Gemini responses, Firebase Console enforcement, Android hardware recognition,
real microphone permission behavior, TTS engines, audio focus during a phone call,
TalkBack, and notification delivery require device/project acceptance. Deterministic
tests and rendered screenshots do not substitute for those live checks.

The first executor intentionally supports personal record creation, reminder
creation, contribution preparation, scenarios, and equal allocation. Existing
record edits, shared mutations, advanced weighted/custom allocation, autonomous
rescheduling, and always-on/live audio are not enabled. Use existing app screens
for existing-record edits. General questions retain the original Ask Anything
experience. These limits are visible in settings; unsupported work is not presented
as completed.

## Voice startup recovery follow-up

The user reported an immediate failure after tapping Speak a turn on an Honor
X6b running Android 16, with Require on-device recognition enabled. The previous
message combined several native errors, so the screenshot cannot establish
whether the failure was an unavailable language model, audio capture, or the
phone's recognition service. Android's local recognizer availability does not
guarantee that a model for the requested language has been downloaded.

The follow-up checks installed on-device language support on Android 13 and
later before listening, preserves native error numbers and specific messages,
and exposes the reported installed languages in Voice settings. Services that
cannot answer the optional support query still use the same local recognizer.
The app never silently switches providers while on-device recognition is
required. Speech input no longer requests playback audio focus; playback retains
its own focus and interruption handling.

With the requirement explicitly disabled, a user can choose Android's speech
dialog after a disclosure that the provider may use the internet. The returned
transcript still requires review and sending. Cancellation invalidates late
results. The dialog's expected activity pause does not cancel its result.
Error status now stays consistent with the visible message, the toolbar fits
the pushed phone route, and the smaller error orb keeps recovery controls visible.

For a retry on the reported phone, use Voice settings, turn Require on-device
recognition off, select Device default, and tap Speak a turn. The Android speech
dialog is an explicit alternative if direct recognition still fails. To retain
strict local recognition, install a supported model through the phone's speech
provider and choose that installed language instead.

Follow-up validation:

| Check | Actual result |
| --- | --- |
| `flutter analyze --no-pub` | No issues found |
| Recovery, Agent unit and responsive widget suites | **53** tests passed, including **8** new recovery cases |
| Targeted native `AgentVoiceBridgeTest` | **25** tests passed with zero failures/errors; coverage includes API 36 (Android 16) support checks and APIs 29, 31, 33 and 35 |
| Error UI capture | Rendered and inspected at 360 x 800 with 120% text scale; readable title and visible recovery controls |
| `flutter build apk --debug --no-pub` | Successfully rebuilt `build/app/outputs/flutter-apk/app-debug.apk` with the recovery changes |

Logs: `build/agent-voice-fix-analyze-final.log`,
`build/agent-voice-fix-tests-final.log`, `build/agent-voice-fix-native.log`, and
`build/agent-voice-fix-build.log`. The new capture is
`build/ui-preview/agent-voice-model-error.png`. No phone is connected for a
physical Honor microphone test; the checks above use fake events and Robolectric.

## Source map

| Responsibility | Files |
| --- | --- |
| Typed proposals, exact calculations, validation | `lib/agent_studio/agent_domain.dart` |
| Local command interpretation and clarification | `lib/agent_studio/agent_planner.dart` |
| Review, approval, orchestration and recovery | `lib/agent_studio/agent_engine.dart` |
| Authorized app service adapter | `lib/agent_studio/agent_backend.dart` |
| Categorical structured Gemini guidance | `lib/agent_studio/agent_ai_gateway.dart` |
| Account-scoped local settings and history | `lib/agent_studio/agent_store.dart` |
| Agent home, conversation, voice and mission UI | `lib/agent_studio/agent_screen.dart` |
| Typed mission editor | `lib/agent_studio/agent_step_editor.dart` |
| Permissions, privacy, voice and memory settings | `lib/agent_studio/agent_settings_screen.dart` |
| Speech contract, channel adapter and state controller | `lib/agent_studio/agent_voice.dart` |
| Shared record creation | `lib/app_record_repository.dart` |
| Dashboard, app bar, protected result/transaction navigation | `lib/main.dart` |
| Existing safe renderer with optional Agent foreground color | `lib/ai_coach/ai_response.dart` |
| Conditional reminder creation through existing scheduling | `lib/reminder_repository.dart`, `lib/reminder_coordinator.dart` |
| Native speech, lifecycle, audio focus and package visibility | `android/app/src/main/kotlin/com/example/myproject/agent/AgentVoiceBridge.kt`, `MainActivity.kt`, `AndroidManifest.xml` |
| Deterministic Agent coverage | `test/agent_studio_test.dart`, `agent_studio_backend_test.dart`, `agent_studio_validation_test.dart`, `agent_studio_widgets_test.dart`, `agent_studio_fixtures.dart` |
| Native lifecycle coverage | `android/app/src/test/kotlin/com/example/myproject/agent/AgentVoiceBridgeTest.kt` |

No Firebase rules deployment, billing change, or external account mutation was
performed. Android Gradle/plugin deprecation warnings and the existing widget
renderer safe-call warning remain outside this feature's scope.
