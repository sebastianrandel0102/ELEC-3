# SaveTrack Agent Autopilot — Mint Aurora 6.5

Autopilot is integrated into the existing Flutter application. Open **Agent
Studio → Agent settings → Agent Execution & Autopilot**, or tap the execution
mode chip in Agent Studio. Every existing and new account starts in **Ask First**.

## Architecture and original approval boundary

The repository uses Flutter `ChangeNotifier`, immutable typed domain objects,
injected service interfaces, Firebase Authentication and Cloud Firestore.
`LocalAgentPlanner` interprets English, Filipino and Taglish locally. The existing
semantic, title, exact-money, calendar and correction resolvers remain the source
of typed drafts. Optional Firebase AI Logic provides abstract planning guidance;
it receives no database tools or execution authority.

Previously, the chat applied a plan using `AgentEngine.applyPlan`, the user
opened `review()`, and an exact confirmation dialog minted a process-local,
single-use `AgentApproval`. `execute()` revalidated that approval and dispatched
the typed actions through `FirestoreAgentBackend`. That manual flow remains.

The active chat now calls `handleUserPlan`. This coordinator first applies and
validates the draft, then asks `AgentAutoExecutionPolicyEngine` for a typed
decision. An eligible request enters the same dependency-ordered executor with
a separate policy authorization callback. No manual approval is fabricated.
Unsupported or sensitive clauses in a combined request prevent automatic
execution of the request's supported subset. Shared-goal instructions retain
the Save Together workflow; quoted title content stays literal data.
Editor changes, history, model guidance and ordinary `applyPlan` calls do not
trigger automatic execution.

`GuardedAgentBackend` carries the live authorization callback into the existing
repositories. Goal/task transactions and conditional reminder transactions call
it immediately before `tx.set`, including transaction retries after async reads.
Account identity, request snapshot, settings revision, cancellation, foreground
state, validation and limits must still match at that boundary.

## Modes and permissions

| Mode | Behavior |
| --- | --- |
| Ask Before Every Action | Existing manual review for mutations. |
| Smart Auto-Execute | Explicit opt-in enables personal goal, task, reminder and eligible mission creation. |
| Custom Auto-Execute | Only individually enabled categories may run. |
| Paused | No new automatic mutations; manual review stays usable. |

Local simulations may run without mutation approval in every mode. They can be
disabled separately. The original master execution permission and per-operation
Agent permissions remain independent checks. Enabling an automatic category
through its settings control also enables its matching ordinary action
permission, preserving manual use when Autopilot is later disabled.

Separate controls cover goal creation, task creation, reminder creation,
eligible missions, local simulations, savings-form preparation and spoken
automatic actions. Existing goal edits, target/deadline edits, task organization,
rescheduling/completion, reminder adjustment/deletion, shared-goal changes,
withdrawals and destructive actions retain their existing workflows. Unsupported
operations are never added to the automatic allowlist.

Settings have a validated schema and consent version and are stored through the
existing account-scoped local preferences. Missing, corrupt or unsupported
settings fall back to Ask First. Settings are **device-specific**, including
category permissions; there is no cross-device synchronization. Reset restores
Ask First, disables automatic mutation categories and invalidates pending
authority without removing unrelated application data.

## Policy and execution

The trusted classifier assigns new personal goals/tasks/reminders low risk,
contributions high risk, and scenarios/allocations read-only risk. Moderate and
prohibited categories are represented in the risk model but have no automatic
mutation implementation. Unknown action types/fields are rejected by the sealed
action decoder. The model cannot choose a risk level, alter settings or specify
an arbitrary database path.

Policy outcomes are automatic execution, clarification, manual review, blocked,
read-only, draft-only and deferred. Each includes a reason code, explanation and
policy version (`autopilot-1`). Negation, uncertain interpretation, incomplete
fields, stale requests, inactive sessions and untrusted origins cannot authorize
automatic writes. A full mixed-risk mission goes to review together, preventing
surprising partial execution. Eligible independent steps continue after an
ordinary failure; dependent steps are blocked. The result reports actual success
and failure rather than claiming rollback.

Default limits are 4 actions/request, 20/session and 30/hour. User-selectable hard
ceilings are 6, 40 and 60 respectively. A request may contain at most 2 goals,
6 tasks or 3 reminders, within its total limit. Oversized requests go to review
without truncation. Session/hour exhaustion pauses automatic mutations. Hourly
attempts are persisted, count uncertain dispatches and future timestamps, and
survive restarting the engine or moving the clock backward on the same device.
These are local safeguards, not a tamper-proof cross-device rate limiter.

The existing server-only checks verify ownership, duplicate titles, task dates
and overlapping schedules. Goals and tasks use stable
`agent_<missionId>_<stepId>` document IDs and compare the exact serialized action
inside a transaction before creating anything. Reminder creation is conditional
and never overwrites a changed reminder. Rapid chat submission is serialized;
old missions and recognizer callbacks never auto-replay. A deliberately repeated
request is still checked against current records rather than globally banning
the text.

## Domain behavior and examples

* `Create a goal called Laptop, target ₱30,000, deadline December 15, 2027.`
  creates an empty personal goal through `AppRecordRepository` when permitted.
  Its saved balance is zero; there is no initial contribution.
* `Create a task called Research Laptop Prices tomorrow.` uses the current local
  date and existing Planner schema, defaults and duplicate/conflict checks.
* `Remind me every Friday at 7 PM to save for Laptop.` resolves an authorized
  personal goal and uses `FirestoreReminderRepository` and `ReminderCoordinator`.
  Phone capabilities and notification permission must be available for automatic
  creation. Preference persistence and actual phone scheduling have distinct
  result messages. No new exact-alarm permission is requested.
* `Add ₱500 to my Laptop Fund.` stays under financial review by default. With the
  separate preparation option enabled, a single resolved request may open the
  existing Add Savings form. The form's own financial confirmation remains
  mandatory. The agent never records or verifies a deposit on its own.
* `What if I save ₱700 per week toward a ₱30,000 target?` runs the existing precise
  local simulation. It does not change a balance. A bare contribution scenario
  asks for a target or an explicitly named goal; loading that goal requires
  Private Context Access.

The existing reminder infrastructure attaches reminders to personal goals or
tasks. Standalone reminders without a resolvable target ask for a selection;
Autopilot does not invent an association. Private goal loading still requires
the existing Private Context Access permission. Task reminders retain the
existing once/task-start restriction. Monthly/payday reminder recurrence is not
introduced by this upgrade.

## Voice, pause and recovery

Spoken automatic actions default off and require a separate disclosure and
explicit opt-in. Transcript review supports always reviewing before sending,
reviewing uncertain recognition, or submitting eligible final speech. Automatic
submission requires a final turn, foreground session, explicit microphone
activation and no recognition alternatives/low reported confidence. The uncertain
recognition mode also requires a reported confidence of at least 0.85. Semantic
validation still applies after submission. Partial transcripts, stale callbacks,
TTS playback and inactive sessions cannot execute. No background listener or raw
audio storage is added.

Pause and Stop Remaining Actions invalidate authority immediately. Already
dispatched server writes can still finish and their real results are retained.
Backgrounding, account changes, permission revocation and disposal prevent
further writes. Uncertain/offline outcomes retain the draft or stable operation
ID; there is no automatic offline queue or reconnect replay.

`PreferenceAgentExecutionLedger` durably records minimal typed operation metadata
before automatic dispatch, even when optional mission history is disabled.
It stores up to 500 operations, authorization kind, mode, policy version, time,
stable target ID, status and result. It stores no raw command, conversation or
audio. Storage failure blocks dispatch. This app-local metadata is not encrypted
or tamper-proof. Existing optional mission history still retains its original
30-day/50-mission behavior.

**Autopilot Activity** filters goals, tasks, reminders and unverified outcomes.
Its **Check server result** action performs only authenticated server reads to
reconcile interrupted creations; it never resubmits a write. Manual mission
retry also reconciles the original stable record ID. The ledger distinguishes
dispatched, completed, uncertain and reversed outcomes.

Direct user **Undo task creation** is available for ten minutes on the exact
unchanged personal task. Its transaction checks the operation, original fields,
timestamps, ownership and absence of a task reminder. Edited, completed, expired
or cross-account tasks cannot be removed. Goal and reminder undo are not exposed;
their existing management screens remain available. No financial rollback is
claimed.

## Files and dependencies

New production files are under `lib/agent_studio/autopilot/`:
`autopilot_settings.dart`, `auto_execution_policy.dart`, `execution_ledger.dart`,
`autopilot_settings_screen.dart` and `autopilot_activity_screen.dart`.

The existing domain, engine, backend, planner, chat, settings and voice controller were
extended. `AppRecordRepository` and `FirestoreReminderRepository` gained guarded
write boundaries; the former also implements narrow transactional task undo.
No package versions, Firebase initialization, cloud services, Security Rules,
indexes, native Kotlin code or paid-plan requirements were changed.

Modified source files: `agent_domain.dart`, `agent_engine.dart`,
`agent_backend.dart`, `agent_planner.dart`, `agent_screen.dart`,
`agent_settings_screen.dart`, `agent_voice.dart`, `app_record_repository.dart`
and `reminder_repository.dart`. Existing tests gained injectable ledger fixtures
in `agent_studio_fixtures.dart` and a stable removal-button locator in
`agent_studio_widgets_test.dart`. `docs/agent-studio.md` links to this report.

Tests are in `agent_autopilot_policy_test.dart`,
`agent_autopilot_execution_test.dart`, `agent_autopilot_backend_test.dart` and
`agent_autopilot_widgets_test.dart`, with a shared SDK boundary double in
`agent_autopilot_database.dart`. These cover typed settings, policy decisions,
language commands, repository integration, notifications, limits, revocation,
account changes, recovery, undo, explicit opt-in and voice behavior. Existing
Agent tests continue to cover the manual approval boundary.

`agent_autopilot_rules_test.py` adds isolated emulator coverage for the real
creation schemas, stable-ID preconditions, account isolation, reminder targets,
forged policy metadata, withdrawal protection and task deletion ownership.

## Verification — October 18, 2026

| Check | Actual result |
| --- | --- |
| `flutter pub get` | Passed; no dependency changes. |
| Dart formatting and `git diff --check` | Passed. |
| `flutter analyze` | No issues found; exit 0. |
| `flutter test --concurrency=4` | All 845 tests passed; exit 0, including 62 new Autopilot Flutter tests. |
| Existing financial/shared/currency Firestore emulator suite | All 54 tests passed. |
| New Autopilot Firestore emulator suite | All 7 tests passed; exit 0. |
| Light/dark visual checks | Rendered and inspected settings and goal-result captures; narrow screens and 200% text covered by widget tests. |
| `flutter build apk --debug` | Passed; exit 0. Final build completed in 65.7 seconds. |
| Android device testing | Not performed: no connected Android device was found. |

The final debug APK is `build/app/outputs/flutter-apk/app-debug.apk`
(190,889,589 bytes). Verification logs are the ignored local files
`autopilot-final-full-tests.log`, `autopilot-final-analysis.log`,
`autopilot-final-apk.log`, `autopilot-rules-tests.log` and
`autopilot-rules-verified.log`.

Live microphone input, OS permission dialogs and physical notification delivery
remain unverified. Firebase validation used SDK boundary doubles and the isolated
local Firestore emulator, without production-account testing or deployment.

Useful follow-up work includes Android device acceptance tests, a separately
designed standalone-reminder schema, and optional account-wide category settings
with explicit conflict/revocation handling. Existing-record automation would
need its own version checks, scoped permissions and tests before being added.
