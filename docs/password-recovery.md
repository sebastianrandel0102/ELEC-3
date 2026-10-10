# SaveTrack Firebase email password recovery

Implemented and checked October 11, 2026, with the existing Flutter 3.47.7 / Dart 3.13.5 and firebase_auth 6.7.0. No dependencies or Firebase project identifiers were changed.

## Root cause

The login callback opened `PasswordDialog()` without an authenticated password-change session. That dialog intentionally displayed `recoveryUnavailable`, required an enrolled verification method, offered no email field, and made no Firebase password-reset request. This disabled email recovery in client code. Firebase's emailed action code supplies the verification needed for its supported password-reset flow; a separate Google/phone recovery enrollment is unnecessary for that flow.

## Implementation

Login's **Forgot password?** opens `PasswordRecoveryDialog`, optionally prefilled from the login email field. It reuses the current mint gradient, rounded email field, gradient button, and dialog theme. The form is scrollable and respects the dialog's safe-area and keyboard insets.

`AuthService.sendPasswordResetEmail` validates a trimmed email, resolves the existing Firebase Auth instance, and awaits:

```dart
await _auth.sendPasswordResetEmail(email: normalizedEmail);
```

No custom action-code settings, continue URL, app-link handler, password fields, Firestore operations, or provider lookups are added. Firebase generates the secure email link and its existing hosted action handler performs code validation and password confirmation. The app never updates a password based on an email address alone.

Both button and keyboard submission are blocked while the request is pending. Loading prevents back/dismissal until completion. Invalid input receives field feedback; recoverable errors preserve it. Successful requests display **Check Your Email** and eligibility-neutral wording, never **Password Changed**. Older `user-not-found` responses receive the same neutral wording to avoid exposing account existence; that path does not imply Firebase accepted or delivered mail.

Resend reuses the submitted email and waits for a 30-second SaveTrack UI cooldown after a successful request or a Firebase rate-limit error. This is an accidental-repeat safeguard, not a Firebase quota guarantee. Network errors allow retry. Firebase remains authoritative about quotas. Invalid email, network, quota, provider/configuration, initialization, and unexpected failures show safe messages. Development diagnostics contain error codes/types only.

Google sign-in behavior is unchanged. The dialog explains that a SaveTrack reset does not change a Google password. No accounts are linked, merged, created, or deleted. The signed-in Profile password-change implementation and all user data paths remain intact; its obsolete unauthenticated fallback was removed.

## Configuration inspected

- `main()` already awaits Firebase initialization with `DefaultFirebaseOptions.currentPlatform`.
- Android and Web configurations, `firebase.json`, and Android's `google-services.json` consistently identify `project-4dcb3` / project number `864730227148`.
- Web's Auth domain is `project-4dcb3.firebaseapp.com`.
- Android already includes the Internet permission.
- Public Auth configuration currently authorizes `localhost`, `project-4dcb3.firebaseapp.com`, and `project-4dcb3.web.app`.
- `https://project-4dcb3.firebaseapp.com/__/auth/action` returned HTTP 200 and the Firebase `fireauth.oob.OobHandler` bootstrap.
- No custom reset handler was found in the source. Authenticated Console access was unavailable, so the actual email template, custom action URL, and provider settings could not be directly inspected. Nothing was changed in the Console.

## Live request versus delivery and completion

One Firebase `PASSWORD_RESET` request was sent to the user-supplied dedicated test email using the existing Web project's public API key and Firebase's official `accounts:sendOobCode` endpoint. Firebase returned HTTP 200. The test email, response email, credentials, and action codes are omitted from this report.

This is a live backend acceptance check, separate from the SDK-double tests of the Flutter code. No browser surface was available to run the built Flutter app interactively. An accepted request does not prove account eligibility, email delivery, or a password update.

| Event | Verification |
| --- | --- |
| Live email request accepted | Verified: HTTP 200 from Firebase. |
| Email received in inbox/spam | Not verified: owner reported that it had not arrived yet. |
| Valid emailed link opens and completes reset | Not tested: no email received at the owner's check. |
| New-password login succeeds; old password rejected | Not tested. |
| Invalid action-code rejection | Verified: live Firebase `accounts:resetPassword` rejected a fabricated code with HTTP 400 / `INVALID_OOB_CODE`. No password was supplied or changed. |
| Expired emailed link rejection | Not tested. |

The owner reports that the test email already belongs to an email/password account. Delivery remains unresolved. Check that exact account in this configured Firebase project and review template/sender settings; do not treat the API response as proof of delivery. No additional live reset emails were sent during these checks.

New credentials must be entered and submitted by the test-account owner under the browser-control tool's credential handoff requirement. Do not send passwords or reset action codes in chat or logs.

## Firebase Console checklist

In the existing **project-4dcb3** project:

1. Open **Authentication > Users** in **project-4dcb3** and confirm the exact test email exists there with the password sign-in provider. Then open **Authentication > Sign-in method > Email/Password** and confirm Email/Password is enabled. Email-link sign-in is a different feature and is not required here. Preserve Google settings.
2. Open **Authentication > Templates > Password reset**. Preserve the Firebase-generated link placeholder. Check sender/app branding and review **Customize action URL**. Use the default Firebase handler at `https://project-4dcb3.firebaseapp.com/__/auth/action` if there is no verified custom handler. Do not point reset emails at an ordinary login route. Review the scope shown by the Console before saving any shared action-URL change.
3. Open **Authentication > Settings > Authorized domains**. The public config above already includes local and Firebase hosting domains. Add the actual deployed SaveTrack Web domain if needed; do not invent a production domain. This implementation sends no continue URL, so no new continue-URL allowlist entry is needed.
4. Review **Authentication > Settings > Password policy** for the requirements Firebase applies during reset. Keep email enumeration protection enabled where configured.
5. With a dedicated email/password test account, request one email through the app, check inbox/spam, open the link, enter/confirm a new password, and complete Firebase's hosted flow. Return to SaveTrack and verify the new password works and the old one fails. Confirm UID/profile/goals/tasks/reports are unchanged. Reusing the consumed link should fail; separately test an expired link. A Google-only test account should continue using Google sign-in, with no claim of changing its Google password.

## Changed files

- `lib/main.dart`: recovery callback passes the existing Auth service and initial email.
- `lib/auth_service.dart`: awaited Firebase email operation and safe error handling.
- `lib/password_recovery_service.dart`: validation, error messages, and recovery failure type.
- `lib/password_recovery_dialog.dart`: recovery form, loading, confirmation, and resend.
- `lib/password_dialog.dart`, `lib/password_service.dart`: replace the blocked recovery entry point and remove its obsolete fallback/message; retain signed-in password changes.
- `test/password_recovery_test.dart`: recovery service/widget tests, including async completion, duplicates, error/retry, resend, keyboard, and large-text layouts.
- `test/password_management_test.dart`, `test/google_sign_in_test.dart`, `test/redesign_test.dart`: update recovery-only expectations.
- `README.md`, `docs/password-management.md`, `docs/google-sign-in.md`, `docs/password-recovery.md`: replace obsolete recovery descriptions and document setup/results.

No savings, planner, report, Firestore, Firebase initialization/configuration, Google authentication, registration, login authentication, or logout logic was changed. No production user records were mutated.

## Executed checks

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; dependency versions unchanged. |
| `dart format .` | Passed; subsequent focused formatting also passed. |
| `flutter analyze` | Final run passed: no issues found. |
| `flutter test` / final `flutter test --no-pub` | Final suite passed: 90 tests, including 22 new recovery tests and existing regression coverage. |
| `flutter build web` | Final-source build passed, including Wasm dry run. Artifact: `build/web`. |
| `flutter build apk --debug` | Retry passed with the process-local compiler settings below. Initial attempt failed in existing Firebase Core / Google Sign-In Kotlin incremental caches. Artifact: `build/app/outputs/flutter-apk/app-debug.apk`. Existing KGP migration notices remain. |
| Recovery visual preview | Passed: targeted `SAVE_UI_PREVIEWS` recovery test; rendered phone dialog inspected at `build/ui-preview/password-recovery.png`. |
| `git diff --check` | Passed. |
| Live Firebase reset-email request | Accepted: HTTP 200 via official REST endpoint. |
| Invalid reset-code request | Rejected: HTTP 400 / `INVALID_OOB_CODE`. |
| Inbox receipt, completed reset, login with new/old passwords | Not verified; see owner status above. |

Initial analysis/test runs caught fixture compilation/tapping issues that were fixed before the final passing run. Automated recovery tests use Firebase SDK doubles; existing tests exercise Google auth/profile preservation, signed-in password changes, login/registration validation, savings/planner callbacks, reports, and logout. They do not establish live regression behavior for every feature.

Commands require the existing `D:/Program Files/Git/cmd` directory in this process's PATH. The Android retry uses process-local `GRADLE_OPTS` only:

```text
-Dorg.gradle.project.kotlin.incremental=false -Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process
```

No Gradle files, global compiler settings, Firebase settings, or Google setup were changed.

Official references: [Flutter Firebase user management](https://firebase.google.com/docs/auth/flutter/manage-users), [Firebase hosted/custom action handlers](https://firebase.google.com/docs/auth/custom-email-handler), and [email-action continue URL configuration](https://firebase.google.com/docs/auth/flutter/passing-state-in-email-actions).
