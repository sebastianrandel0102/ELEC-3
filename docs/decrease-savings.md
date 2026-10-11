# Decrease Savings

The existing Goal actions menu on every `GoalCard` now contains **Decrease
Savings** immediately after Add savings. Add savings, Edit goal, Delete goal,
and the separate History button keep their existing behavior. The withdrawal
option is disabled when the goal has no savings.

## Interface

`DecreaseSavingsDialog` uses the existing `FormHeading`, `GradientButton`,
`SaveActionLabel`, input theme, mint colors, and dialog spacing. It shows the
selected goal name, current balance, target, and available balance, with an
amount field, optional reason, and live new-balance preview. Invalid values
show field-specific errors and no negative preview. Currency uses the existing
`_money` formatter (`PHP` and two decimal places).

The goal's snapshot stream updates the displayed balance while the dialog is
open. The final write always checks the latest server balance. Confirm and
Cancel are disabled during confirmation, and back navigation is blocked until
the request finishes. Failure leaves the dialog open. Success closes it and
shows feedback only after Firestore confirms the operation.

If a network or unexpected error makes the result uncertain, the amount and
note stay locked so Confirm retries the same request and payload. A definitive
validation or permission failure allows editing again. Cancel remains available
after failure. Request deduplication covers one form's lifetime and Firestore
transaction retries; reopening the form creates a separate intentional request.

## Data and consistency

This project uses Firestore document maps rather than separate goal/transaction
models or a savings repository. The authoritative balance remains `savedAmount`
on `users/{uid}/goals/{goalId}`. Existing deposits use numeric pesos, and this
feature preserves that storage format and the existing subcollection:

```text
users/{uid}/goals/{goalId}/transactions/{requestId}
  amount: positive numeric pesos
  type: "withdrawal"
  note: trimmed optional reason
  date: server timestamp
```

`decreaseSavings` checks the authenticated UID against the exact user-specific
goal path. Its Firestore transaction reads the goal and the stable request ID
before writing anything, verifies existence and sufficient funds, updates
`savedAmount` and `updatedAt`, and creates the withdrawal record. The same
transaction adds `lastWithdrawalId` to the goal so rules can connect the balance
change with its new history document. A matching existing request returns
without a second decrease; an ID with a different payload is rejected.

Firestore retries the conditional read/write when a concurrent change conflicts;
validation runs again against the latest balance. Neither half of the change
is committed on failure. See [Firebase transaction documentation](https://firebase.google.com/docs/firestore/manage-data/transactions).

Amounts accept decimal digits with up to two fractional digits and must be
positive and within the available balance. Internal validation also rejects
nonfinite values and amounts beyond safe integer-cent precision. The existing
floating-point peso balance is preserved; a tolerance of `0.00000001` pesos
handles accumulated representation noise when withdrawing the exact balance.
The resulting stored balance is always at least zero.

## Existing views and records

History keeps its descending `date` query. Withdrawals have a downward icon,
minus sign, Savings Decreased label, optional reason, and the existing date
format. Deposits retain their plus sign and original presentation. Records
without a type remain deposits; no historical data migration is required.

`GoalCard` computes progress, remaining amount, Goal reached, overdue state,
and suggested savings pace from the current balance and deadline. No stored
completion flag needs clearing. A withdrawal below the target therefore
removes Goal reached and restores the existing funded/overdue presentation.

Dashboard savings totals, preview cards, and the report's Savings balance
metric already listen to goal documents and sum `savedAmount`. They reflect
the lower balance automatically. There is no period-deposit report or
transaction-derived savings chart in this project. Task productivity reports,
planner, authentication, profile, and theme were not modified.

History has no transaction edit/delete UI. None is introduced for withdrawals.
Deleting a whole goal still deletes its transactions through the existing
cleanup process.

## Security rules and deployment

The original rules allowed all owner writes. The updated rules preserve UID
ownership and existing deposit behavior, require nonnegative goal balances,
and require a balance decrease to link to a newly created withdrawal in the
same atomic operation. Withdrawal creation validates its positive amount,
type, note, server timestamp, and corresponding balance difference. Withdrawal
records cannot be edited or converted to deposits.

The rules are updated **locally**. Deploy them to the existing configured
Firebase project as part of your release:

```powershell
firebase deploy --only firestore:rules --project project-4dcb3
```

These narrow changes do not make the original entire ledger tamper-proof.
Owner-authorized deposits/increases and owner history deletion remain allowed
to preserve existing behavior and whole-goal cleanup. Full ledger immutability,
strict server monetary normalization, and authenticated-user restrictions on
standalone history deletion would require a broader design, potentially trusted
backend writes. The feature does not claim those protections.

## Validation

The Dart tests cover input errors, exact-balance withdrawal, floating-point
noise, atomic commit failure, stable-ID retries, stale balances, concurrent
decreases, owner paths, form loading/failure behavior, correct goal selection,
responsive layouts, typed and legacy history, and progress/completion/overdue
behavior. The full existing Flutter suite provides regression coverage.

`test/firestore_withdrawal_rules_test.py` runs against an isolated local
Firestore emulator and a `demo-` project, never the production database. It
downloads and verifies the official emulator JAR into ignored `build/emulator`,
starts a hidden local process, and stops it after testing. It covers real
server atomic transactions, rules enforcement, concurrent write preconditions,
idempotent document IDs, decimal/full withdrawals, date sorting, legacy
deposits, increment-based deposits, goal edits, and goal cleanup. It requires
Python 3 and Java 21 or newer:

```powershell
py -3 test/firestore_withdrawal_rules_test.py --java '<path to Java executable>'
```

No production account or production data was used for automated verification.

Executed results:

- `flutter pub get`: succeeded; no dependency changes.
- `dart format .`: completed; final source is formatted.
- `flutter analyze`: no issues found.
- `flutter test`: all 139 tests passed.
- Firestore emulator suite: all 14 tests passed.
- Android debug APK: built successfully at
  `build/app/outputs/flutter-apk/app-debug.apk`.

The standard Android build encountered pre-existing Kotlin incremental cache
failures because dependency sources are on C: and this project is on D:.
The successful build used a fresh Gradle process, disabled incremental Kotlin
compilation, and reduced memory/worker limits for that invocation. No Android
configuration or dependency files were modified. The successful command was:

```powershell
$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx2G -Dorg.gradle.workers.max=2'
flutter build apk --debug --no-android-gradle-daemon --android-project-arg=kotlin.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process
```

The compiler settings are documented by [Kotlin](https://kotlinlang.org/docs/gradle-compilation-and-caches.html)
and [Kotlin compiler execution strategy](https://kotlinlang.org/docs/compiler-execution-strategy.html).
The build still emits existing plugin migration and Android SDK metadata
warnings. Automated verification did not include signing in to a production
account or a physical-device withdrawal.
