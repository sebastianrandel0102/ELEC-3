# Agent Studio Pro — Mint Aurora 6.3

Implementation and measured validation, October 17, 2026. This upgrade runs in the existing SaveTrack Flutter project. It adds local semantic roles and shared title handling to the existing multilingual planner and approval engine.

## Original failure and baseline

The previous goal extractor understood quoted strings, purpose phrases such as “for …” and “para sa …”, and seven hardcoded product words. It did not represent an explicit naming relation or title provenance. The task extractor used a different string-removal heuristic. Reminders and scenarios had no title fields; mission titles were not editable or part of the approval snapshot.

In this workspace, **“Create a savings goal called Laptop” already returned Laptop incidentally through that hardcoded fallback**. It did not establish general naming support. Arbitrary titles such as “My Future Setup”, naming variants, and canonical title provenance exposed the failure. The new mandatory golden test verifies the exact Laptop request, `create_goal_draft`, `title = Laptop`, `titleSource = explicit_user_title`, draft status, approval requirement, and absence of a missing-title question.

A real baseline was recorded before replacing title extraction. The same 1,128-case development corpus is used for the comparison below. It contains 188 base utterances and six controlled transformations, spanning the six functions, English, Filipino, Taglish, informal grammar, titles, purpose, amounts, simulations, negation and unsupported requests. It does not obtain its expected answers from the parser.

| Measurement | Before | After |
| --- | ---: | ---: |
| Correct canonical intents | 816 / 1,128 | 1,128 / 1,128 |
| Fully correct cases under the original comparison criteria | 219 / 1,128 | 1,128 / 1,128 |
| Correct annotated action fields | 873 / 1,974 | 1,974 / 1,974 |
| Intent macro F1 | 0.699806 | 1.000000 |
| Unexpected proposals in negative cases | 3 / 102 | 0 / 102 |
| Goal title exact match, explicit and inferred | 80 / 246 | 246 / 246 |
| Task title exact match | 7 / 168 | 168 / 168 |
| Reminder title exact match | 0 / 168 | 168 / 168 |
| Mission title exact match | 0 / 168 | 168 / 168 |
| Scenario title exact match | 0 / 168 | 168 / 168 |

The upgraded parser also matches **918/918 title-provenance annotations**. Explicit-title-only exact match is **216/216 goals** and **168/168 each for tasks, reminders, missions and scenarios**, or **888/888 total**. The baseline did not expose a provenance field; the newly added provenance metric is reported separately from the original before/after comparison.

These are synthetic development regression measurements, including cases used while improving the implementation. They are **not held-out accuracy, live speech accuracy, general multilingual fluency, or a promise of universal understanding**. Per-intent precision/recall/F1 and the confusion matrix are in [the measured results](agent-universal-results.json); [baseline summaries and failure samples](agent-universal-baseline.json) preserve the original measurements. Complete baseline failure output remains in `build/reports/agent_universal_baseline.json`.

The two existing multilingual corpora remain part of the tests: 330 original cases plus 50 specification acceptance cases. Together with the new corpus there are **1,508 versioned synthetic cases**, in addition to focused unit, context, repository, voice and widget tests. Existing corpus reports under `build/reports/agent_language_*_results.json` retain money, currency, date, time, recurrence, reference, clarification and language-group metrics.

## Working interpretation pipeline

1. Preserve the original utterance in ephemeral conversation state.
2. Tokenize Unicode text with offsets into the original source, recognize balanced quoted literals and preserve punctuation inside them.
3. Split explicit action/object scopes while retaining field declarations with their object.
4. Resolve shared naming, purpose, inverse assignment, compact object titles, fronted subjects and suffix title fields.
5. Mask literal spans before command classification, negation, money, dates and times. Title text cannot become instructions or financial fields.
6. Assign financial amounts to labelled target, saved and contribution roles. Multiple amounts are not blindly assigned by position.
7. Apply domain adapters and current-draft context. Missing or ambiguous values remain editable and block review where needed.
8. Generate typed local actions and provenance-backed previews. These objects contain no execution authority.
9. Reuse the existing authenticated review, snapshot-bound approval, validation and repository execution path.

`AgentIntent` has stable canonical identifiers, `AgentDomain` identifies the six domains, and `ResolvedTitle`, `SlotOrigin`, `SemanticSpan`, `SlotEvidence` and `TitleBinding` record interpretation evidence and provenance. Raw utterances and evidence are not serialized to mission history or sent to optional Gemini guidance.

## Domain behavior

| Function | Implemented behavior |
| --- | --- |
| Plan a Goal | Explicit called/named/titled/name/title declarations, quoted and multiword titles, purpose-derived suggestions, title/amount/deadline field separation, rearranged fields, corrections and missing-field questions. Existing goals remain behind their existing edit controls. |
| Organize Tasks | Shared title roles, separate comma/conjunction/numbered list drafts, literal quoted commas, requested counts without invented names, date/time/priority extraction, contextual and ordinal title changes. Existing saved-task changes continue through Planner. |
| Make Reminders | Typed draft titles and editing, purpose-derived title suggestions, recurrence/date/time separation, contextual renaming, supported once/daily/weekly schedules, dependency-aware links and existing authorized target selection. |
| Build a Mission | Separate mission and step titles, nested multi-domain scopes, named empty drafts awaiting steps, title follow-ups, title editing, draft-step removal and supported reordering. Recurring reminders link to compatible goal steps rather than unsupported recurring task alarms. |
| Prepare Savings | Exact amounts, self-corrections, explicit goal-name/quoted references, conservative ambiguous-reference handling and authorized local goal loading. Contributions still open Add Savings for its separate confirmation. Withdrawal/deletion requests never become deposits. |
| What-If | Named scenarios, labelled target/saved/contribution roles, daily/weekly/monthly contribution periods, shared-baseline contribution comparisons, amount follow-ups, exact local calculations and calendar-month deadline estimates. Simulations never modify balances. |

Title provenance distinguishes explicit user titles, inferred purposes, contextual follow-ups and corrections. Explicit names retain function words such as “For” and “Called”, numbers and original spelling. Inferred titles are visibly labelled as suggestions requiring review. Ordinary whitespace is normalized; evidence still points into the original source.

English, Filipino and Taglish naming relations share the same slot engine, including `pangalan`, `tawag`, `na`, `para sa`, `pang`, informal creation forms and mixed-language declarations. This is a bounded local grammar, not thousands of sentence equality checks or a remote language model.

## Context, clarification and voice

Naming follow-ups update an eligible active draft without creating a second object. Compound title corrections also retain explicitly supplied amounts and schedules. Bare title replies fill a pending title, while numeric replies remain amount fields. Multiple possible targets prompt for a step instead of silently choosing one. Completed/canceled mission context is discarded for new requests.

Corrections invalidate prior review/approval. Mission titles now participate in the approval snapshot. Draft-only and conditional requests remain protected across field edits and serialization. Reset/cancel requests perform no saved-record deletion.

Existing editable transcript review, runtime recognizer/TTS capability checks, language settings, final-result handling and partial-transcript protections are retained. An unfinished quote or a recoverable but uncertain “goal cold …” naming transcript receives a title verification blocker. The parser does not silently rewrite recognizer output into an approved command.

Unspecified AM/PM and incomplete month deadlines ask for exact values. No purchase price, goal balance, contribution, date or success probability is invented. Reminder scheduling and simulation contribution periods are separate roles, so a monthly calculation does not require a monthly alarm service.

## UI and security

The Mint Aurora 6.3 interface shows “I understood · Draft”, actual object titles, title source, inferred purpose and goal target/deadline. Existing Edit details forms now include reminder/scenario titles and contribution frequency. Mission title editing updates typed mission state. The preview reads the actual action, avoiding stale values after edits. Light/dark, 320-pixel width and 1.6× text previews were rendered and visually inspected.

Execution remains independent from language parsing. Authentication, private-context permission checks, server ownership checks, approval expiry, revision invalidation, idempotent operation IDs, double-submission handling, dependency validation and financial confirmation are reused and regression-tested. Quoted prompt-like names remain literal data. No arbitrary Firestore tool or provider-controlled approval was added.

The feature is local-first and Spark-compatible. No new dependency, paid service, Cloud Function, Cloud Run deployment, billing setting or Firebase rule change is required. Optional existing AI guidance still receives only abstract action types and language; it receives no raw utterance, titles, goal IDs, balances or amounts. The upgrade does not change provider models or claim a particular provider quota is available.

## Verification and completion ledger

- Repository audit and baseline: complete, with the incidental Laptop fallback documented above.
- Canonical types, shared lexical/title/role extraction and six-domain integration: complete for the supported grammar.
- Context, correction, negation, ambiguity and approval protections: implemented and covered by focused integration tests using fake repositories.
- UI, editable titles and light/dark rendering: implemented and widget-tested.
- Synthetic benchmark and existing language corpora: passing; metrics above are measured.
- `flutter pub get`: passed; no dependency changes.
- Full `flutter test --no-pub --reporter expanded`: **passed, 777 tests** (97 more than the previous 680-test suite).
- `flutter analyze --no-pub`: **passed, no issues found**.
- `flutter build apk --debug --no-pub`: **passed**; Gradle `assembleDebug` completed in 85.0 seconds. Artifact: [`app-debug.apk`](../build/app/outputs/flutter-apk/app-debug.apk), **190,820,357 bytes**, built on October 17, 2026.

The separately rerun corpus/provenance and light/dark preview suite passed all six top-level tests. The final focused language/title regression run passed 94 tests. Command logs are under `build/reports/universal-*.log`. No failing tests, analyzer issues or Android build errors remain in the final verification. Native voice source was unchanged; its JVM tests were not rerun for this change. Live-device and service validation limits are listed below.

Physical code lines were counted from the actual files using `dart run tools/measure_agent_source.dart`. The count excludes blank/comment-only lines, generated code, dependency/lock files and JSON reports/data. This is the affected Agent feature inventory, **not a claim that all these lines were newly written**:

| Category | Nonblank, noncomment code lines |
| --- | ---: |
| Production Dart, entire Agent feature | 8,735 |
| Production Kotlin, existing voice bridges | 363 |
| Unit and engine integration Dart tests | 2,415 |
| Widget Dart tests | 712 |
| Repository integration Dart tests | 262 |
| Kotlin voice tests | 177 |
| Synthetic fixture generator | 242 |
| Source inventory tool | 124 |
| **Affected feature total** | **13,030** |

Production source totals **9,098** lines; test source totals **3,566** lines; evaluation/support totals **366** lines. The six new standalone production modules contain **984** code lines, the three new test files **977**, and the fixture generator/inventory tool **366**, or **2,327 newly created-file code lines**, plus changes in the existing modules. Their [file-by-file inventory](agent-universal-source-lines.json) is reproducible. Existing architecture was extended rather than replaced or padded to manufacture 10,000 new lines. Mixed unit/engine integration files are counted once in their combined category.

## Source inventory

New production files under `lib/agent_studio/intelligence/`:

- `semantic_text.dart`: source spans, tokens, quote masking and command scopes.
- `title_resolver.dart`: shared naming and purpose grammar.
- `domain_slot_resolvers.dart`: task-list and contribution-period adapters.
- `draft_field_resolver.dart`: typed contextual field patches.
- `financial_role_resolver.dart`: labelled financial-role assignment.
- `interpretation_preview.dart`: actual-draft preview UI.

Modified production files:

- `agent_planner.dart`: integrated extraction, contextual repair, multi-domain missions and scenarios; removed the old goal/task name extractors and product-name fallback.
- `agent_domain.dart`: reminder/scenario titles, scenario periods/calculations, validation and mission title snapshots.
- `agent_engine.dart`: mission metadata/editing and title verification blockers, retaining protected execution.
- `agent_screen.dart`: previews, mission renaming, authorized goal resolution and edition label.
- `agent_step_editor.dart`: title and contribution-period editing.
- `intelligence/agent_interpretation.dart`: canonical IDs/domains, title evidence, structured previews and reference resolution.
- `intelligence/money_expression_parser.dart`: punctuation boundaries, invalid-input retention and explicit zero saved-balance roles.
- `intelligence/date_expression_parser.dart`: ambiguous spoken-time and month clarification.

New tests: `agent_universal_intelligence_test.dart`, `agent_universal_corpus_test.dart`, `agent_universal_widgets_test.dart`, and `fixtures/universal_intelligence_cases.dart`. Existing language/Studio widget tests were adjusted for authorized goal matching and settled scroll frames. `tools/measure_agent_source.dart` reproduces the nonblank/noncomment source inventory. Existing uncommitted project work was preserved. No Kotlin source changes were needed.

## Known limitations and next work

- The local parser deliberately asks or falls back to existing forms for unfamiliar paraphrases, slang, unsupported languages, complex nested conditions and genuinely ambiguous field boundaries. It is not a universal semantic model.
- Reminder titles are editable proposal/mission metadata. The existing reminder service remains target-bound and uses its existing privacy-safe notification text. This upgrade does not introduce independent named alarm records or monthly/payday reminder scheduling.
- Existing saved-goal/task/reminder edits, destructive operations, shared-goal mutations and withdrawals continue through their protected application screens. Draft reordering/removal is not record mutation.
- Initial saved balances are not automatically recorded when creating a goal. New goals use the existing zero-balance creation workflow, followed by separately confirmed contributions.
- Simulation comparisons use explicit/authorized baseline data or request missing values. They make deterministic estimates with stated assumptions, not statistical predictions or guaranteed completion dates.
- Original/draft text stays in the active session; opt-in mission history retains typed titles as before. No new private raw-text persistence was introduced.
- No real Android microphone, installed-language inventory, device notification delivery, live Firebase account, shared-member revocation event or live Gemini request was tested. Existing fake-backed and native tests cannot establish real-device speech accuracy or production service configuration.
- The measured corpus is developmental. The next accuracy step is an independently authored held-out multilingual and adversarial corpus, followed by consented device speech evaluation of critical titles, numbers, dates and references.
