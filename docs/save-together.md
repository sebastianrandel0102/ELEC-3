# Save Together: Spark implementation and verification

Save Together extends SaveTrack with shared, self-reported savings goals using the
existing Firebase Authentication and Cloud Firestore integration. It does not
transfer or hold money. Personal goals, their history, authentication, planner and
personal report calculations retain their existing paths and flows.

This version works on Firebase's Spark plan. Flutter performs transactions and
Firestore rules independently validate the complete atomic write. Cloud Functions,
service-account credentials and a billing upgrade are not required.

## Screens and entry points

- **Savings:** Personal and Shared tabs, shared status filters and a choice of
  personal or shared goal when creating a goal.
- **Personal goal actions → Save Together:** Copies name, description, target and
  deadline into a separate shared goal. Initial shared savings default to zero.
  Personal money and history stay private; no automatic migration occurs.
- **Create/settings:** Name, description, PHP target, optional initial savings,
  start date, deadline and icon. Creation atomically adds owner membership and any
  initial deposit record.
- **Details:** Mint/emerald cards show combined progress, remaining amount,
  deadline, status, member count, personal deposits, group deposits/decreases,
  daily/weekly pace and five recent records.
- **Invitations:** Owners generate/copy codes, view the latest 100 invitations for
  a goal and revoke pending codes. Signed-in recipients paste a code, preview its
  limited information, then join or decline.
- **Members:** Active members, roles, join dates and lifetime deposit totals.
  Owners can remove contributors; contributors can leave.
- **Contribution/decrease:** Amount, calendar date and shared note, attributed to
  the authenticated user. Only owners can decrease the balance. Open forms observe
  changes to goal access and balance.
- **History:** Immutable attributed records, newest recorded first, 30 per page.
- **Home/reports:** Shared previews, group balances and personal shared deposits
  appear separately from the existing personal calculations.

## Data and authorization

| Path | Purpose |
| --- | --- |
| `users/{uid}/goals/{id}` | Existing private goals and subcollections |
| `sharedGoals/{id}` | Schema version 2, owner, active member IDs/count, names and deposit map, dates, integer-cent summaries and PHP projections |
| `sharedGoals/{id}/members/{uid}` | Role, active/left/removed state, name, join/departure times, lifetime deposits and invitation reference |
| `sharedGoals/{id}/transactions/{requestId}` | Actor, deposit/withdrawal type, integer cents and PHP amount, contribution date, shared note and creation time |
| `sharedInvitations/{code}` | Limited preview, creator/recipient IDs, status and expiry |
| `sharedInviteLimits/{uid}` | Owner-private counter: 20 new codes per one-hour window across all owned goals |
| `sharedOperations/{uid}/requests/{requestId}` | User-private immutable retry receipt, fingerprint and result |

Discovery uses `memberIds arrayContains current UID`. Active members can read a
goal, history and member list. Users can also read their own membership before
joining or after leaving, without gaining group access. There is no public user
directory or email enumeration.

Owners can create/edit, contribute, invite/revoke, remove contributors, decrease
and archive. Contributors can read, contribute under their UID and leave. The sole
owner cannot leave or be removed. Goals have at most 50 active members. Archiving
preserves history and blocks edits, deposits, decreases, new joins and invitations.
Leaving/removal preserves group balance and attribution while revoking group
access. Removed members cannot redeem another code; members who left voluntarily
may rejoin with a fresh code.

Rules reject arbitrary summaries, role escalation, forged actor IDs, stale balances,
negative balances, unmatched ledger entries, history edits/deletion and membership
changes without the matching atomic invitation or departure. Existing personal
rules retain their prior behavior.

## Balance and retry integrity

Arithmetic uses integer centavos. Every PHP projection must equal its integer
field divided by 100, and rules enforce
`currentCents = depositCents - decreaseCents`. Maximum monetary totals are PHP
1 billion. Overfunding is allowed; displayed progress caps at 100% and remaining
savings floors at zero.

Each contribution reads the goal and membership, then atomically writes its ledger,
summaries, member deposit total and receipt. Decreases do not reduce members'
lifetime deposits. Firestore retries contention; stale totals cannot commit.
Rules validate the resulting state using `getAfter()`.

Forms retain a stable request ID and submitted values when an outcome is uncertain.
The private receipt returns a completed result on retry. Ledger IDs independently
prevent financial replay. Receipts never authorize financial or membership writes:
a forged receipt can only affect its user's own displayed response. Receipts are
retained indefinitely and remain readable by their user after leaving a goal;
they contain operation results, not continuing access to current group records.

Calendar dates are UTC midnight. Rules validate recorded dates against server time
using Asia/Manila's UTC+8 date. The start date cannot be edited after creation.
Completion is recomputed after deposits, decreases and target edits; overdue is
derived from the current date. Shared writes need a network connection and do not
silently queue financial transactions offline.

## Invitation security and Spark limits

Codes contain 32 cryptographically random bytes encoded as 43 URL-safe characters.
They are single-use bearer capabilities, expire seven days after their server
creation timestamp and should be
shared privately. Any signed-in holder can accept or decline a pending code;
codes are not email-bound. Acceptance atomically consumes the code, creates or
reinstates membership and updates the goal's member maps.

The raw code is the invitation document ID and appears in the creator's private
retry receipt. It is not a hashed backend secret. A known code permits reading
limited invitation metadata (goal name, target, creator and resolution metadata),
including after expiry/revocation. It never permits reading balance/history before
membership. Only the creator can list invitations. Expired status is derived from
server creation time plus seven days, without a cleanup scheduler. Older codes
with an explicit `expiresAt` retain that expiry. New invitation creation sends no
device-derived expiry, so a device clock ahead of Firebase cannot reject a valid
owner's request at the seven-day validation boundary.

Every invitation creation must atomically increment its owner's counter. Rules
use server time to enforce 20 codes per one-hour window and reject early resets,
counter deletion and multiple codes against one increment. The client shows a
specific limit message. Member caps, bounded fields, pagination and unguessable
codes provide additional limits. These do not rate-limit failed reads or prevent
abuse through many Firebase accounts. App Check is not configured; register and
test Android/web providers before enforcing it if broader abuse protection is
needed. Spark's Firestore quotas apply; exhausted quotas can make operations fail.

## Source and deployment

Implementation: `lib/shared_savings_models.dart`, `lib/shared_savings_repository.dart`,
`lib/shared_savings_store.dart` and `lib/shared_savings_screens.dart`, integrated
through `lib/main.dart`. `lib/shared_savings.dart` exports the API. No runtime package
beyond existing Firebase dependencies is needed.

`firestore.rules` is the authoritative source. `firestore.indexes.json` includes the
invitation query index. `firebase.json` intentionally has no Functions stanza.
The earlier callable prototype remains in `functions/` for reference only; its
different schema must not be deployed alongside this version. Its tests are not
the active Spark suite.

Deploy with an authorized Firebase CLI account:

```powershell
firebase deploy --project project-4dcb3 --only firestore:rules,firestore:indexes
```

Wait for the `sharedInvitations` index on `createdBy`, `goalId` and descending
`createdAt` to be ready. The legacy `invitations` index is retained to avoid an
unrelated deletion. Preserve existing Android/web registrations, Email/Password
and Google auth settings. No billing account needs linking. The earlier callable
deployment was blocked by Spark's billing requirement; the app no longer calls it.

On October 12, 2026 at approximately 18:44 Asia/Manila, the Spark rules were
successfully released to `project-4dcb3` and its invitation index was submitted.
The `sharedInvitations` index was confirmed **READY** at 18:48 Asia/Manila.
No billing plan change or Cloud Functions deployment was performed. CLI output is
saved locally in ignored `build/shared-spark-deployment.log`; index status is in
`build/shared-spark-index-state.log`.

Reference: Firebase's [transaction documentation](https://firebase.google.com/docs/firestore/manage-data/transactions)
describes retries, atomic writes and transaction validation with security rules.

## Automated verification

```powershell
flutter analyze
flutter test
py -3 test/run_shared_emulator.py --java "C:/Program Files/Android/Android Studio/jbr/bin/java.exe" --port 8090
flutter build apk --debug
flutter build web
```

The runner uses a checksum-verified official Firestore emulator JAR in ignored
`build/emulator`, an isolated demo project and loopback only. It refuses an occupied
port. Tested operations use unprivileged emulator identities with real rules:
creation, invitations, privacy, concurrent deposits/decreases, immutable history,
membership, removal, archive and retry protection. An emulator-only fixture
backdates invitation windows and creation times to simulate elapsed time; operations under test
still pass through rules. Existing personal security regressions run alongside.

Results after the invitation clock fix on October 12, 2026: 150 Flutter tests
and 42 emulator cases (28 shared, 14 personal) passed. Flutter analysis reports no
issues and Dart formatting is clean. Android debug APK and Flutter web builds
succeeded for the Spark implementation. The Android
build reports an existing Firebase-plugin Kotlin migration warning for future
Flutter compatibility.

The shared controller tests confirm that access errors clear previously displayed
financial data and that disposing the controller cancels its account listener.
These are rules/protocol tests and Flutter unit/widget tests, not a production
multi-device integration run.

Invitation clock regression: the computer clock was approximately two seconds
ahead of Firebase's response time. The old client sent `deviceNow + 7 days`, which
exceeded the rules' `request.time + 7 days` bound. New invitations derive expiry
from the server timestamp; rules still enforce the seven-day lifetime and preserve
older explicit expiries. The emulator reproduces the old rejection, accepts the
new format and checks expiration and forbidden extension. Store tests capture the
actual Dart transaction payload and verify same-request retries reuse the code.
Deployment output for this fix is in ignored
`build/shared-invitation-fix-deployment.log`.
The corrected rules were released on October 12, 2026 at 18:58 Asia/Manila.
A running `flutter run` or VS Code session needs a hot restart to load the
client change; a browser refresh alone may retain the old compiled development app.

## Two-account manual acceptance

1. A creates a shared goal with an initial deposit; verify owner, initial ledger
   and matching group/personal deposit totals.
2. A generates a code. B signs into another browser/device, previews it under
   Shared → Enter invitation and joins.
3. Keep A's details open while B contributes. Verify live balance, progress,
   recent activity, member totals, Home and Reports.
4. Both contribute concurrently. Retry an uncertain response with the same values
   and check that each intended entry appears once.
5. B has no owner controls. A decreases savings; check that the balance changes
   while member lifetime deposits stay unchanged.
6. Test fresh codes for decline, revocation and reuse rejection. A removes B;
   B's open screens lose access while A retains B's historical records.
7. Test voluntary leave/rejoin, then archive and confirm history remains readable
   while new financial entries stop.
8. Check personal goals/totals, planner, login/recovery, profile/settings and logout
   on Android/web. Test Google sign-in and intermittent connectivity.

Use your own accounts for manual testing. The emulator suite creates no production
accounts or financial records. Live sign-in, actual devices and transport behavior
remain manual checks after deployment.

Viewer roles, email-bound invitations, ownership transfer, assigned member targets,
push notifications and permanent deletion are not implemented. Cleanup uses
archiving. Reports cover currently accessible groups and lifetime shared totals;
there is no shared period-trend chart or banking integration.
