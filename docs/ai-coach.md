# SaveTrack AI Coach Lite — Mint Aurora 5.0

Implementation report and setup guide, October 14, 2026.

## What is implemented

The Dashboard has a compact emerald **SaveTrack AI** card beneath its existing
savings overview and metrics. It opens the AI screen without making a model
request. Returning preserves Dashboard navigation and scroll state.

**Ask Anything** answers general questions about education, mathematics,
science, writing, languages, technology, programming, and everyday problems.
Its request builder rejects Coach context and mismatched histories. General
questions invoke no personal Firestore reads.

**SaveTrack Coach** offers savings and productivity guidance. Its actions select
an authorized personal/shared goal, a planner day, or a report week. Build a
Savings Plan also offers an editable hypothetical question. Improve Saving
Habits needs no personal data. Actions prepare the composer; sending remains
an explicit user action.

Both modes support separate in-memory sessions and drafts, New Chat, Clear Chat,
real streamed generation, Stop, manual Retry, answer/code copying, recent paired
history, bounded input/output, quota and connection errors, and first-use
provider disclosure. Nothing runs automatically when the Dashboard opens,
the mode changes, a task completes, or a balance changes.

## Architecture and files

The feature follows the application's existing ChangeNotifier/StatefulWidget
patterns without another state-management framework.

| File | Responsibility |
| --- | --- |
| `lib/ai_coach/ai_domain.dart` | Typed modes, messages, statuses, safe summary vocabulary, request guards, instructions and limits |
| `lib/ai_coach/ai_gateway.dart` | Provider and read-only context interfaces; optional invalidation stream |
| `lib/ai_coach/ai_app_check.dart` | Platform attestation policy, localhost web debug provider, public site-key preference and token verification |
| `lib/ai_coach/ai_setup_sheet.dart` | Recoverable setup flow, public-key entry, Console links and protection recheck |
| `lib/ai_coach/firebase_ai_gateway.dart` | App Check startup, Gemini model factory, actual `generateContentStream`, safe error mapping and serialized content seam |
| `lib/ai_coach/ai_controller.dart` | User-scoped sessions, request lifecycle, cancellation, consent, batching, freshness and identity guards |
| `lib/ai_coach/ai_facts.dart` | Local exact-decimal financial summaries and existing planner task adapters |
| `lib/ai_coach/firestore_ai_context_source.dart` | Authenticated server reads of selected subjects; permission/freshness checks |
| `lib/ai_coach/ai_widgets.dart` | AI emblem, Dashboard card, welcome hero, segmented modes, prompt cards, fact cards and review sheet |
| `lib/ai_coach/ai_response.dart` | Safe Markdown, fenced code, horizontal tables, copying and confirmed HTTP(S) links |
| `lib/ai_coach/ai_coach_screen.dart` | Responsive conversation, composer, scrolling, quick actions and privacy flows |
| `test/ai_coach_fixtures.dart` | Test-only provider/context doubles |
| `test/ai_coach_test.dart` | Requests, streaming, financial edge cases, identity and privacy tests |
| `test/ai_coach_firestore_test.dart` | SDK-double verification of actual adapter paths, selected date windows and server-only reads |
| `test/ai_coach_widgets_test.dart` | Interactive, responsive, rendering, privacy and optional visual captures |
| `test/ai_app_check_test.dart` | Provider selection, release safeguards, preflight failure and recovery |

Existing source changes are limited to `lib/main.dart` (App Check startup and
Dashboard entry), dependency manifests, generated platform registrants,
`android/flutterfire-compat.settings.gradle.kts`, README and this guide. The
Android compatibility script extends the existing version-pinned staging
mechanism to `firebase_app_check` 0.4.8 and `firebase_ai` 4.0.0 for AGP 9 built-in
Kotlin. Pub-cache packages and the Flutter SDK are not modified.

Added direct dependencies: `firebase_ai ^4.0.0`, `firebase_app_check ^0.4.8`, and
`flutter_markdown_plus ^1.0.12`. Markdown Plus continues the discontinued original
Flutter Markdown package. Existing `url_launcher` handles confirmed safe links.

## Gemini and Spark compatibility

The central model is **`gemini-3.5-flash-lite`**, using
`FirebaseAI.googleAI()` and Firebase AI Logic's Gemini Developer API backend.
The official [supported-model list](https://firebase.google.com/docs/ai-logic/models)
lists it as stable and not requiring Blaze through this backend. The
[Gemini pricing page](https://ai.google.dev/gemini-api/docs/pricing) lists free
text input/output. These checks establish published eligibility, not the
availability or remaining quota of this particular project.

There is no private Gemini key in the application, paid backend, Cloud Function,
Cloud Run deployment, Vertex backend, model fallback, grounding, search, image
generation, voice service or AI database tool. Billing and Firebase Security
Rules were not changed.

Configuration limits: 3,000 UTF-16 question units, six completed history pairs
and 24,000 history characters, 2,048 output tokens, 40,000 response characters,
100 messages per mode, three-second accidental-send cooldown, 90-second total
request deadline, and 20-second context-read deadlines. Local limits are UX
guards, not tamper-proof provider quotas. There are no automatic retry loops.

## Privacy and authoritative financial facts

The first send explains Google processing, unpaid-service product improvement
and human review, in-memory retention, and answer limitations. Selecting
**Do not show again** and confirming **I understand** saves a versioned,
account-specific preference on this device; canceling saves nothing. The
**AI privacy** menu always reopens this disclosure and lets users uncheck the
option to restore it on future visits. Users should not type personal, sensitive,
confidential or credential information. The implementation cannot reliably
classify arbitrary user-written questions; the notice does not promise that.

Coach review displays readable categorical summary rows, with the **exact
categorical JSON** available under **View exact data**. The
allowlist contains only subject, broad progress/deadline category, workload,
completion category, and presence of high-priority work. Raw goal/task text,
balances, currency, exact dates, counts, notes, UIDs, document IDs, transaction
history, email addresses, member identities and profile information are absent
from automatically built model content. The request type cannot carry local
fact objects or ownership metadata. Synthetic injection strings are excluded
by projection rather than by relying on the model to obey instructions.

Users can approve, cancel, or choose General Advice Instead. Shared-goal facts
are **always local-only**: membership does not authorize sending them to an
external service. Exact private financial analysis also stays local.

Approval belongs to the current user, subject revision, Coach session and a
ten-minute window. Before each contextual request, the adapter rechecks server
authorization and freshness. Goal and planner changes invalidate selected
context; server errors fail closed. Changed report balances are rechecked
before sending. Revocation/expiration replaces the Coach session and removes
its history too, because previous answers could paraphrase approved categories.
Logout clears both sessions, facts, approval and drafts and exits the AI route.

The model has no Firestore writer or function-calling tools. The context adapter
reads the user's existing goals/tasks and the membership-filtered shared-goal
collection; it never reads transactions, other users' private goals, or member
profiles. Explicitly selected context listeners are stopped on revocation,
New Chat, logout and disposal. No transcripts or AI context are persisted in
Firestore, preferences, analytics or application logs.

Verified fact cards are separate from AI text. They display stored balance,
target, remaining amount, progress, actual deadline and local contribution
pace where possible. Calculations reuse `ExactDecimal`, `formatCurrency`,
`goalCurrency`, `SharedSavingsGoal` and `PlannerTask`. Remaining amounts clamp
at zero; progress clamps to the existing zero-to-one meaning. Completed,
overfunded, overdue, missing-deadline and withdrawn-balance cases are covered.
Daily/weekly pace uses the existing deadline-day window and is labeled as a
local estimate. It does not infer contribution history.

Reports reuse the current app's completion counts for the selected week and
current personal balances. Original currencies are grouped separately without
inventing exchange rates or combining unlike denominations. Historical growth
is not fabricated because the existing Reports screen does not provide it.
Planner scheduled starts are explicitly not described as task deadlines.

## Interface and rendering

The screen reuses Mint Aurora's existing Manrope font, semantic colors, spacing,
motion durations and reduced-motion helper. The AI symbol is an emerald sparkle
and does not replace the piggy-bank brand. Static emerald heroes, restrained
mint surfaces, bento prompts, deep user bubbles, white assistant surfaces and
a keyboard-resizing composer create a quiet reading column capped at 760 px.
Large text and short landscape layouts use compact chrome; controls retain
accessible labels and targets. Lazy message lists retain stable message IDs.

Only the active bubble rebuilds for streamed text, batched at 40 ms. Streaming
uses plain selectable text; completed answers use Markdown headings, lists,
quotes, inline code and horizontally scrollable tables. Fenced code has exact
whitespace, a language label and Copy. External images are omitted to avoid
tracking/network loads. HTML and JavaScript are not executed. HTTP(S) links
require user confirmation and reject embedded credentials and unsafe schemes.
Scrolling follows new text only near the bottom and offers Latest when reading
older messages. Cancellation invalidates callbacks before canceling the
subscription; disposed screens cannot receive late UI updates.

## Firebase Console actions still required

Use the existing project **`project-4dcb3`**. Do not attach a billing account or
upgrade Spark.

1. Open [Firebase AI Logic setup](https://console.firebase.google.com/project/project-4dcb3/ailogic).
   Choose **Gemini Developer API** in the guided workflow. Confirm the Firebase
   AI Logic API and Generative Language API are enabled. Allow Firebase to
   create/manage the provider key; never copy it into Dart, assets or source.
2. Confirm `gemini-3.5-flash-lite` is accessible in the project and inspect its
   actual free-tier quotas in AI Studio. If unavailable, retain the honest error
   until a supported free-tier replacement is deliberately verified and the
   single `AiConfig.model` setting is updated. Do not add an automatic fallback.
3. In **Security → App Check → Apps**, register the Android app
   `com.example.myproject` with Play Integrity. Supply the relevant signing
   certificate SHA-256, configure Play distribution/attestation for production,
   and use properly signed production builds. The repository's existing release
   signing configuration still uses a debug key; configure real release signing
   before production distribution.
4. Debug builds use the App Check debug provider. Run on an Android test device
   or emulator, obtain the locally printed SDK debug token, and register it in
   **Manage debug tokens**. Do not commit or share that token. Never use a debug
   provider in a release build.
5. In **App Check → APIs**, enforce baseline protection for **Firebase AI Logic**.
   The gateway requests limited-use tokens, so also configure/verify replay
   protection. Do not disable protection to make a live test succeed. Avoid
   changing enforcement for existing Auth/Firestore/Storage services without
   separately verifying their app registrations.
6. For web, register reCAPTCHA v3 and build with the public site key:
   `flutter build web --dart-define=SAVETRACK_RECAPTCHA_SITE_KEY=<site-key>`.
   Add the intended production domain in the reCAPTCHA configuration. For local
   web debugging use the documented debug-provider setup and register the
   generated token; do not add localhost to production allowed domains.
   A debug Flutter build on `localhost`, `127.0.0.1` or `::1` now selects the
   official SDK `WebDebugProvider` without needing a production site key. A
   release/profile build or a non-local origin never selects this provider.
   Published web builds still require a real site key. If it was omitted at
   build time, **AI setup** accepts and stores the public key for this browser
   and activates protection without rebuilding. Nothing stores debug secrets.
7. Apple builds use App Attest with DeviceCheck fallback in production and the
   debug provider in debug mode. Register the Apple app in App Check and follow
   current native setup instructions. The installed App Check SDK documents an
   Apple physical-device provider-selection limitation; verify attestation on
   actual devices before distributing Apple builds.
8. Set a low-volume per-user rate limit for Firebase AI Logic and verify the
   model's project-wide RPM/TPM/daily limits. The published Firebase default
   is much higher than this personal app needs; project quotas may differ.
   Attestation providers also have their own limits; check them without
   enabling paid infrastructure.
9. Live acceptance: sign in, send a general question, verify an App Check token
   and streamed chunks, select/review a Coach subject and send, switch back to
   Ask Anything and inspect its outgoing content, revoke approval, and test
   model/quota/offline failures. Verify existing savings, planner and auth flows
   on the same actual device.

Official references: [Flutter setup](https://firebase.google.com/docs/ai-logic/get-started?platform=flutter),
[text generation](https://firebase.google.com/docs/ai-logic/generate-text?platform=flutter),
[App Check](https://firebase.google.com/docs/ai-logic/app-check),
[security checklist](https://firebase.google.com/docs/ai-logic/security-checklist),
[quotas](https://firebase.google.com/docs/ai-logic/quotas), and
[unpaid-service terms](https://ai.google.dev/gemini-api/terms).

## Validation and remaining limits

All results below were executed on the implementation environment; they are
not inferred from source inspection.

| Check | Actual result |
| --- | --- |
| `flutter pub get` | Passed; dependencies resolved |
| Formatting modified Dart files | Passed |
| `flutter analyze --no-pub` | Passed; no issues found |
| `flutter test --no-pub --reporter expanded` | Passed; 486 tests, including 59 AI tests and 427 existing tests |
| AI widget suite with `SAVE_UI_PREVIEWS=true` | Passed; 19 tests with real Manrope and host monospace fonts |
| `flutter build apk --debug --no-pub` | Passed; `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build web --no-pub` | Passed; `build/web`; the tool emitted its non-failing Wasm dry-run suggestion |
| `git diff --check` | Passed |

AI coverage includes the serialized SDK cross-mode leak sequence; consent,
revocation, changed/deleted subjects, logout and identity changes; malicious goal
and task text; first/empty/multiple chunks, failures, stop, mode switches,
disposal, total timeout, duplicate sends and retry; financial edge cases and
original currency precision; real adapter read paths; safe links/images;
Markdown, tables, exact code copying, hallucinated amounts, context review and
clear chat. Responsive checks cover 320, 360, 390, 412, 480, 600 and 960 px,
200% text, portrait keyboards and a short landscape keyboard layout.

Seven visual captures were rendered and inspected under `build/ui-preview/`:
`ai-general-welcome.png`, `ai-coach-welcome.png`, `ai-coach-conversation.png`,
`ai-code-conversation.png`, `ai-context-review.png`, `ai-verified-facts.png`,
and `ai-accessibility-320.png`. These use synthetic test-only provider responses
and fixtures; they are UI verification, not proof of live Gemini access.
No golden-test framework was added. Command logs are in `build/test-results.log`,
`build/ai-analyze.log`, `build/ai-preview-test.log`, `build/ai-android-build.log`
and `build/ai-web-build.log`.

Real Gemini generation, project quotas, Console setup and valid App Check tokens
have not been live-verified. The available devices are Windows, Chrome and Edge;
there is no connected Android device or emulator. Apple builds, native keyboard
behavior, TalkBack and real-device attestation still require manual checks.
Firebase AI Logic does not list Windows/Linux as supported Flutter AI targets;
the feature intentionally shows a configuration error there. The rest of the
existing application is preserved.

There are no claimed DevTools frame-time, CPU, memory or latency measurements.
AI can still hallucinate; a fabricated-amount fixture verifies that model text
does not replace the verified fact card. Cancellation stops local consumption
and UI updates; a request already accepted by Google may still consume quota
or be processed. Revocation cannot undo prior provider processing.

Existing authentication, savings writes, withdrawals, shared invitations and
permissions, currency conversion, smart suggestions, reminders, cover photos,
profile images, reports and Security Rules retain their original code paths.
The test suite checks existing regressions; it does not substitute for live
Firebase account or native device acceptance.

## Web setup fix and first-time setup

The initial web implementation returned early when the compile-time reCAPTCHA
key was absent, including for localhost debug builds. The installed SDK already
supports `WebDebugProvider`; it is now used for debug builds on loopback origins.
The gateway verifies protection before the controller creates a chat turn. A
failed protection check preserves the question and shows **AI setup** rather
than an ineffective Retry action or an empty "Incomplete" assistant bubble.
Protection can be rechecked after registering the device; transient startup
failures no longer permanently lock the feature until a rebuild.

For local development using your regular Chrome profile:

1. In [Firebase AI Logic](https://console.firebase.google.com/project/project-4dcb3/ailogic),
   click **Get started**, select **Gemini Developer API**, and complete API
   setup. Keep Spark. Do not attach billing or choose a paid backend. Let
   Firebase manage the provider API key; do not put it into Flutter.
2. Restart the updated app from the project directory:

   ```powershell
   flutter run -d web-server --web-port=7357
   ```

   Open `http://localhost:7357` in your normal Chrome window. A fixed origin and
   your regular browser profile keep the SDK's generated debug token stable.
   Flutter's separately launched temporary Chrome profiles can generate a
   different token when recreated.
3. Open Chrome Developer Tools (**F12**) and its **Console** tab. Find the SDK's
   `Firebase App Check debug token` message. Copy the token privately; do not
   paste it into this chat or commit it to source.
4. In [App Check → Apps](https://console.firebase.google.com/project/project-4dcb3/appcheck/apps),
   find the web app with App ID
   `1:864730227148:web:0f468c4f60f34a6ed2fd69`. Open its overflow menu, select
   **Manage debug tokens**, add a token named `SaveTrack local Chrome`, paste
   the token and save. If the web app requires initial registration first,
   register it with the web provider shown in the Console before adding the
   debug token. Production reCAPTCHA setup is separate from using this token
   in a local debug build.
5. Ensure **App Check → APIs → Firebase AI Logic** has baseline protection
   enforced. Limited-use tokens are enabled in the app; configure replay
   protection as described above. Do not newly enforce Auth/Firestore/Storage
   without separately validating those existing services.
6. Reload SaveTrack, sign in, open **Dashboard → SaveTrack AI**, and ask a
   general question. If token exchange needs to be refreshed, use **AI setup →
   Check connection**. New API configuration can need time to propagate.

This follows the [official debug-provider workflow](https://firebase.google.com/docs/app-check/flutter/debug-provider).
Registering a development token is a one-time Firebase Console step for that
browser profile. A token from one profile does not register every device.

App-side setup fixes have local regression coverage. Project registration,
Gemini availability and a real response are still pending your Console setup;
the application cannot generate a registered Firebase attestation token by
changing Dart code alone.

Follow-up verification: `flutter analyze --no-pub` passed with no issues;
`flutter test --no-pub` passed all **496 tests**. This includes eight new App Check
policy/preflight tests and two new setup/empty-bubble widget regression tests.
The updated web and Android debug builds passed. No live provider response or registered App Check
token is claimed; the Console steps above are required before live use.
