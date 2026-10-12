# Smart Task Suggestions

Smart Suggestions lives in the Daily Planner, below Daily progress and above
the original **Your Tasks** list. It includes **Your Next Move**, up to three
**Up Next** entries, a compact remaining/high-priority/next-schedule overview,
and a **Why this task?** explanation sheet. All suggestions are advisory.

## Implementation

- `lib/smart_task_recommendation_service.dart`: pure Dart task projection,
  schedule parser, ephemeral results, injectable clock and ranking service.
- `lib/smart_suggestions.dart`: live suggestion section, gradient primary card,
  recommended task tiles, summary, explanation/conflict sheet and empty states.
- `lib/main.dart`: Daily Planner integration, cached existing task stream,
  shared original completion update, screen visibility and calendar rollover.
- `test/smart_task_recommendation_service_test.dart`: fixed-time engine tests.
- `test/smart_suggestions_test.dart`: planner integration, original task actions,
  clock/lifecycle/error states, responsiveness and optional visual previews.
- `README.md`: link to these feature and validation notes.

No dependencies, Firestore fields, security rules, indexes, authentication,
savings calculations, reports or notification behavior were added or changed.
The compact task list on the dashboard retains its original presentation.

## Rules

The engine reads existing `dateKey`, `title`, `time`, `priority`, `completed`
and `createdAt` values from the planner's authenticated, date-filtered snapshot.
It ignores completed tasks, other dates, invalid dates and duplicate IDs.
Missing priorities use the existing `Normal` default. Unknown priority strings
remain intact and get neutral weight; their explanations do not claim a known
priority. Missing titles receive a presentation-only placeholder.

For today, the category order is:

1. Current scheduled activities.
2. Scheduled activities starting within 30 minutes (configurable in the service).
3. Unfinished tasks whose scheduled starts or explicit windows have passed.
4. Flexible tasks without recorded times.
5. Later scheduled activities.
6. Tasks with times that require review.

Scheduled upcoming commitments are chronological, with priority breaking equal
starts. Other categories use **High (3), Normal (2), Low (1)**, then recorded
start where both candidates have one, existing creation time and task ID.
Firestore iteration order does not change the ranking. The original list's
ordering is preserved; no document is reordered or updated by analysis.

An explicit time window is active at its start and inactive at its end
(`[start, end)`). A start-only task is labeled **Scheduled for now** during
its recorded start minute. After that, its start needs review; the engine
does not invent an end time or classify the start as a deadline. Imminent
commitments prompt preparation. Later commitments stay upcoming and never
receive a “start now” instruction.

For future dates, the UI says **Recommended Order** and orders fixed
commitments by that day's times, followed by flexible tasks. Today's clock
never produces “starts in” labels for a future date. For past dates, the UI
says **Review Unfinished Tasks**, with no claim that historical work should
start now. Empty and completed days have separate states.

## Time data and conflicts

The existing task form has one optional free-text `time` field. The service
recognizes explicit values such as `9:30 AM`, `2 PM`, `14:00`, and same-day
ranges such as `2:00 PM–3:00 PM` or `14:00–15:00`. Spaces and a hyphen,
en dash, em dash or `to` separator are supported. Both endpoints must be
unambiguous; `2–3 PM`, arbitrary phrases, invalid clock values and overnight
ranges require review. The original recorded text stays visible and editable.

Conflicts are detected only between unfinished tasks with explicit, valid
start and end times. Adjacent windows do not overlap. The warning identifies
the conflicting task names in the explanation sheet. Single start times
and unscheduled tasks never imply durations or conflicts.

SaveTrack has no task estimated-duration or deadline fields. Suggestions show
the minutes until the next scheduled start and explicitly state that flexible
task duration is unknown. No task is claimed to fit a gap, and unsupported
duration-based fitting is omitted. The optional focus timer is omitted.

## Updates and actions

Firestore snapshot changes immediately recompute the section after task
creation, edits, deletion, completion and reopening. **Edit Task** and Up Next
open the existing editor. **Mark Complete** shares the exact existing
`completed`/`updatedAt` update used by the original checkbox. A failed write
shows an error and never independently changes local completion state.
Deletion during an open editor continues through its existing save-error
handling. Existing legacy priority strings remain editable without dropdown
assertions or automatic replacement.

While visible and foregrounded, the section updates at local minute
boundaries using its in-memory tasks. It pauses its timer while hidden or
backgrounded, refreshes immediately on activation/resume, and disposes its
timer/observer. The planner follows today's calendar through midnight if
Today is selected; manually browsing another date preserves that selection.
Calendar checks also account for device timezone changes. Stream instances
are retained across clock/visibility rebuilds and changed only for a new
user/date/source. A new user/date resets the StreamBuilder's snapshot.

## Validation

Validation performed on October 13, 2026:

- `flutter pub get`: passed; dependency manifests/lockfile unchanged.
- `dart format .`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test --reporter expanded`: **202 passed**, including **31 new engine
  tests** and **20 new widget/integration tests**.
- Existing isolated Firestore regression suite: **42 passed** for personal
  withdrawals, shared savings transactions, rules and data isolation.
- `flutter build apk --debug`: passed; output is
  `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build web`: passed; output is `build/web`. The compiler's Wasm
  compatibility dry run also succeeded; the delivered build uses JavaScript.
- Preview widget suite with `SAVE_UI_PREVIEWS=true`: **20 passed**. Rendered
  mobile (390 px), narrow (320 px), wide (1280 px), integrated planner and
  original-list images were visually inspected. A separate widget test passed
  at 320 px with 200% text.

The Android build reports an existing Firebase-plugin Kotlin migration warning.
No unrelated dependency or Android configuration changes were made.

Run `flutter pub get`, `dart format .`, `flutter analyze`, and `flutter test`.
Build Android with `flutter build apk --debug` and web with
`flutter build web`. The existing isolated rules regression suite is:

```powershell
py -3 test/run_shared_emulator.py --java 'D:\Program Files\Android\Android Studio\jbr\bin\java.exe'
```

Optional rendered UI review images use SDK fonts and stay in ignored build
output:

```powershell
flutter test test/smart_suggestions_test.dart --dart-define=SAVE_UI_PREVIEWS=true
```

Unit and widget tests use fixed clocks and Firestore test doubles; they do
not require a live account. Production Firebase login, task creation over
the network, offline persistence and physical-device interactions require
manual authenticated testing. This repository has no implemented weekly
planner, reminder system or task filter/sort controls to regression-test.
