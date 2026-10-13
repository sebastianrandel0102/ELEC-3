# Smart Reminders

SaveTrack now schedules native phone notifications for personal savings goals,
each member's own shared goals, and existing planner tasks. Reminder preferences
never deposit money, change balances, change priorities, mark tasks complete, or
create recurring tasks. All existing reminders start off.

## Using reminders

- Personal goals: **Goal actions → Set Reminder / Manage Reminder**, or the bell
  control on the existing goal card. Choose Once, Daily, Weekly, or Before Deadline
  when the actual goal has a deadline. Deadline options are on the day, or 1, 3,
  or 7 calendar days before it.
- Shared goals: open the existing Save Together details and choose **Set My
  Reminder**. Preferences are private to the authenticated member. Editing yours
  does not change another member's reminders.
- Planner: use **Set Task Reminder** in Add/Edit Task, or the task's bell/action
  menu. Choose a custom date and clock time, or the actual task start with an
  offset of 0, 5, 10, 15, 30, or 60 minutes. Custom reminder time is separate from
  the existing task start field. Save the task to apply a reminder draft.
- **Profile → Smart Reminders** lists saved preferences and actual device status;
  it supports editing, enabling, disabling, removing, refreshing, notification
  settings, and Android's optional precise-timing access.

The existing planner has one-time task documents grouped by `dateKey`. There is
no weekly view or task recurrence schema in this repository. Task reminders
therefore remain one-time. Weekly reminder repetition applies to savings goals;
no competing task recurrence system was introduced.

## Architecture and persistence

`users/{uid}/reminders/{type}_{targetId}` is the only preference store. Structured
fields include UID, target type/ID, enabled state, hour/minute, frequency, optional
UTC instant, weekday, task offset, deadline offset, notification name privacy,
schema version, and server update timestamp. Existing goals, tasks, shared
members, transactions, authentication, currencies, and financial rules are not
rewritten.

Firestore rules restrict reading/writing/removing preferences to their owner.
Enabled personal/task reminders require an existing owned target. Enabled shared
reminders require the UID in `memberIds`, an active membership document, and an
unarchived goal. An account can still disable or remove its old preference after
access ends. Only this narrowly scoped rules block was added.

`ReminderRepository` loads preferences and watches their actual target records.
`ReminderCoordinator` reconciles them at startup, auth changes, preference/target
updates, resume, and explicit refresh. It serializes native scheduling operations,
checks permissions/channels, replaces changed alarms, cancels obsolete alarms,
and checks device capacity. Reconciliation caches capability checks per channel
and uses signatures to avoid scheduling unchanged reminders again.

SharedPreferences contains device scheduling metadata only: monotonically
allocated notification IDs and configuration signatures. IDs include account
and logical reminder identity in the persistent mapping; they do not use Dart's
unstable `hashCode`. No reminder preferences or financial data are copied there.

Firestore's existing mobile offline persistence also applies to these documents.
Snapshot metadata labels cached values and pending writes. Local scheduling may
apply an offline preference, but the UI never claims its cloud write was confirmed
until Firestore acknowledges it. A write waiting more than eight seconds reports
pending confirmation; it is not a second local persistence system. A rejected
write's Firestore rollback is reconciled. Already scheduled alarms need no internet
to deliver. A device that has never loaded a synced preference cannot schedule it.

## Native integration

Packages selected after checking the installed Flutter 3.47.7 / Dart 3.13.5 SDK:

- `flutter_local_notifications` **22.3.2**: the sole notification delivery system.
- `flutter_timezone` **5.1.1**: device IANA timezone identifier.
- `timezone` **0.11.2**: timezone data and `TZDateTime` calculations.

The adapter calls `zonedSchedule`, with native daily/weekly matching components.
There are no Dart delivery timers, fake notifications, direct background audio,
FCM services, or automatic financial actions.

Android retains package name `com.example.myproject`, the existing Java 17
configuration, and Flutter's compile/target SDK 36 and minimum SDK 24. Necessary
configuration adds core-library desugaring 2.1.4, the documented scheduled/boot
receivers, a white status icon, and resource retention for release shrinking.
There are three stable channels: `savings_reminders`, `shared_goal_reminders`,
and `planner_reminders`. Channel sound, vibration, lock-screen behavior, and DND
remain under OS/user control.

Permissions:

- `POST_NOTIFICATIONS`: Android 13+ runtime permission. A contextual explanation
  appears only when configuring an enabled reminder. Initialization does not
  prompt. After the initial request, denied access has an explicit settings path.
- `RECEIVE_BOOT_COMPLETED`: lets the plugin restore locally known alarms after
  reboot/app replacement.
- `SCHEDULE_EXACT_ALARM`: optional user-controlled special access for chosen
  planner/reminder times. SaveTrack does **not** declare the restricted
  `USE_EXACT_ALARM` permission. The app checks exact-alarm capability separately
  from notification permission. With access it selects `exactAllowWhileIdle`;
  otherwise it selects `inexactAllowWhileIdle` and labels timing approximate.
  Profile's Precise timing control explains the separate access before opening
  system settings. Play distribution eligibility must still be assessed for the
  final published product.

See the [plugin integration documentation](https://pub.dev/packages/flutter_local_notifications/versions/22.3.2)
and [Android's alarm guidance](https://developer.android.com/develop/background-work/services/alarms)
for the integration and platform requirements.

iOS uses deferred alert/sound permission requests, foreground presentation,
timezone scheduling, launch/tap callbacks, and the AppDelegate's notification
center delegate. The coordinator caps this device at 60 pending reminders,
leaving room below the plugin-documented iOS limit of 64. Android is capped at
400. Additional preferences remain saved with a clear unscheduled status.
iOS compilation and delivery require macOS/Xcode validation and were not tested
on this Windows workstation.

Web and desktop can manage synced preferences but do not schedule phone-style
background alarms. There are no unconditional `dart:io` imports in production
reminder code, and scheduling is behind a platform adapter. The web build is
preserved; no background browser scheduling promise is made.

## Clock picker and time policy

The sheet uses Flutter's actual Material `showTimePicker`, initially in dial mode,
with Cancel/Confirm, device 12/24-hour preference, AM/PM controls, accessibility
semantics, and Mint Aurora colors/rounded surfaces. Selected time is stored as
hour/minute, never an authoritative formatted clock string. Standard Material
keyboard entry remains optional for accessibility; no manual typing is required.

One-time custom reminders store a UTC instant; they keep that instant when the
device travels. Daily/weekly reminders use the current device wall-clock zone.
Task offsets and goal-deadline times are recomputed from existing record dates
in that zone. Deadline dates retain the same calendar-date interpretation already
used by the corresponding goal UI.

New custom local times inside a daylight-saving gap are rejected rather than
silently shifted. For initial daily/weekly calculation, invalid days are skipped;
an ambiguous fall-back time selects its first occurrence. Subsequent repeating
occurrences use the plugin's native timezone recurrence implementation; its
normalization around future DST transitions remains a platform/library limit.
Timezone data initializes once. Device timezone is refreshed on resume/manual
refresh, and signatures force replacement when it changes. While the app stays
closed, alarms retain their last reconciled timezone until SaveTrack resumes.
There is no persistent Dart isolate polling for timezone changes.

## Cancellation, navigation, privacy, and accounts

Completed tasks and reached goals pause their pending reminders without changing
saved preferences. Marking a task incomplete again schedules only a future valid
occurrence. Editing task start/date or goal deadlines recalculates relative
reminders; a custom UTC reminder keeps the separately chosen instant. Disabling,
removing, or deleting a target cancels its pending alarm. Shared archival/removal
or revocation cancels and disables the member's preference when the app learns
of the change; it does not silently reactivate on rejoining.

Payloads contain only version, UID, type, and target ID. Notification names are
hidden by default; each reminder can opt into showing its item name. Neither
balances, transactions, member emails, invitations, nor credentials are included.
Android notifications use private lock-screen visibility.

Tapping uses the existing Navigator and Firebase sign-in flow. A signed-out tap
is held until sign-in; UID, existence, ownership, and shared active membership are
rechecked against Firestore before navigation. Personal goals open a details page
reusing the existing goal card/actions/history; shared goals open their existing
details page; tasks open the existing planner on their actual date. Deleted or
unauthorized items give a graceful unavailable message. Protected opened pages
also guard account changes.

Logout/account switching clears delivered and pending local notifications and
loads only the next account's preferences. Saved Firestore preferences survive.
Local scheduling cannot learn remote deletions, completions, or revocations while
the device/app has no opportunity to sync; its next active snapshot/resume cancels
the stale alarm. Server-originated multi-device push would require separate FCM
infrastructure, which this feature does not introduce.

## Files

Created: `lib/reminder_models.dart`, `lib/reminder_repository.dart`,
`lib/reminder_scheduler.dart`, `lib/reminder_coordinator.dart`,
`lib/reminder_widgets.dart`, the Android status icon/resource retention XML,
three reminder Dart test files, two reminder rules-emulator scripts, and this
report.

Modified: `lib/main.dart`, `lib/shared_savings_screens.dart`, `pubspec.yaml/lock`,
Android app Gradle/manifest, iOS AppDelegate, `firestore.rules`, README, two
existing test fixture files to supply real-style IDs, and generated desktop
plugin registrants produced by Flutter dependency resolution. Analyzer options
exclude the emulator tooling's installed `node_modules` templates from Dart analysis.

## Validation and remaining acceptance

Unit/widget/channel tests are mocked checks, not proof that a real phone displayed a notification. The Android
SDK and build tools are available, but `adb devices` found no connected device and
`emulator -list-avds` found no configured AVD. No actual phone, reboot, background,
offline, tap, or iOS delivery test was performed.

Before deployment, deploy the new Firestore rules with the project's existing
Firebase configuration:

```powershell
firebase deploy --only firestore:rules
```

Before release, manually verify on Android: foreground/background/swiped-away
delivery, once/daily/weekly alarms, permission denial and later settings grant,
channel disabling, optional exact-access grant/revocation, reboot, offline delivery
of an already scheduled alarm, timezone travel, tap routing through sign-in,
task completion/deletion/rescheduling, shared membership revocation, logout, and
account switching. Also test iOS on Xcode/hardware if shipping that platform.

Android force-stop, OEM battery restrictions, Doze, exact-alarm access, system
notification/channel settings, and DND can delay or prevent delivery. Reboot
restoration is plugin-supported, not a guarantee under force-stop/OEM restrictions.
No sound, vibration, precise timing, or universal delivery guarantee is made.

## Executed checks (13 October 2026, Asia/Manila)

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; locked notification/timezone packages resolved |
| `dart format` on modified Dart files | Passed |
| `flutter analyze` | Passed with no issues |
| Full `flutter test` regression suite | 367 passed, zero failures |
| Final reminder unit/widget/native-channel suite after cancellation hardening | 49 passed, zero failures |
| Real-font reminder UI suite at widths 320–324 and 600, scales 1.0/1.8 | 19 passed, zero failures; rendered sheet/clock visually inspected |
| Firestore reminder rules on an actual local demo emulator | 7 passed, zero failures |
| `flutter build web --no-wasm-dry-run` | Passed |
| `flutter build apk --debug --target-platform android-arm64` | Passed; `build/app/outputs/flutter-apk/app-debug.apk` produced |
| Existing Firebase rules regressions on local Firestore/Storage demo emulators | 15 passed, zero failures |
| Android device/emulator delivery | Not performed; no device or AVD available |
| iOS build/delivery | Not performed; macOS/Xcode unavailable |

Verification logs are under the ignored `.buildlog/` directory. Rendered sheet
and clock previews are in `build/reminder-preview/`. Firestore tests use the
existing test-tooling package; with Node 24.12+ and Java 21+ on PATH, run:

```powershell
npm ci --prefix test/profile_photo_emulator
node test/profile_photo_emulator/run-reminder-tests.cjs
node test/profile_photo_emulator/run-tests.cjs
```

Native channel tests verify the production plugin adapter's method calls and
payloads against a mocked Android channel. Scheduling lifecycle tests use an
injectable clock, real timezone data, and mocked OS adapters. Security tests
exercise the real rules compiler and Firestore emulator, including unchanged
financial and task documents. None of these substitutes for phone delivery tests.

The final APK's packaged permissions were checked with `aapt`; package identity,
notification permission, boot permission, optional exact-alarm access, and absence
of `USE_EXACT_ALARM` were confirmed. The initial multi-architecture build attempt
was canceled when it competed with the final ARM64 build; the completed artifact
above is an ARM64 debug build. The SDK emitted a non-fatal XML-version warning;
no unrelated Gradle/SDK upgrades were made.
