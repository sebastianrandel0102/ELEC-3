# SaveTrack password management

Implemented October 11, 2026. Forgot Password opens an in-place mint dialog titled **Reset Your Password**, with **Verify your identity to create a new password.** It no longer requires an email address or calls `sendPasswordResetEmail`. There was no separate reset screen to remove: the old callback sent email directly from the login form.

## Recovery availability

**Unauthenticated password recovery is deliberately unavailable in this project configuration.** The dialog shows:

> Password recovery is not available for this account without an enrolled verification method.

It explains that SaveTrack cannot verify an enrolled recovery identity from this login screen. This is a configuration limitation, not a claim that a particular Firebase account has no linked providers: no authenticated Firebase console/account inventory was available.

The existing code has no provider enrollment, trusted recovery lookup, or phone authentication integration. The checked-in Android Google JSON has an empty `oauth_client` list. Google provider enablement and existing account links cannot be established from local files. Ordinary Google sign-in may create an account or trigger Firebase trusted-provider behavior; using it as a recovery shortcut would not prove that a provider was previously linked. The new recovery dialog therefore exposes no Google/SMS verification buttons and never accepts passwords, email/phone claims, or arbitrary target UIDs.

An owner who already has Google linked can use the existing Google login, then Profile → Change Password. A password-only user who has lost their password cannot use this non-email flow. No unsupported bypass is included. Enrollment must occur while the user can still authenticate; this change does not add enrollment or a backend recovery service.

## Signed-in password change

Profile → **Change Password** opens the same styled, scrollable dialog family:

- Password accounts: Current Password, New Password, Confirm New Password. All inputs hide characters initially and provide accessible visibility buttons. Cancel closes the dialog.
- Accounts with both password and Google providers: an additional **Verify with linked Google** action reauthenticates the existing Firebase user. Web uses `User.reauthenticateWithPopup`; supported native platforms use Google authentication followed by `User.reauthenticateWithCredential`. It never calls linking, merging, account creation, or Firebase sign-in for this action. Firebase rejects the wrong Google identity. Successful verification transitions to **Create New Password** with two fields.
- Google-only accounts: explains that there is no SaveTrack password and that their Google password is managed in Google Account. It does not ask for a nonexistent current password or silently add another provider.

Validation checks required values, Firebase's minimum baseline, confirmation equality, and the project's configured Firebase password policy through the installed SDK's `validatePassword(auth, password)`. Policy retrieval failure/timeout prevents saving. Missing configured character/length requirements are explained. Firebase also enforces its policy when updating.

The session captures the authenticated user at dialog creation and checks the current Firebase UID before and after asynchronous verification. Current-password changes reauthenticate with `EmailAuthProvider.credential` on every submission. Google changes require successful Firebase reauthentication. A refreshed Firebase token must contain an `authTime` within five minutes, and Firebase independently enforces recent login on `updatePassword`. The application awaits the password update before displaying **Password Changed** and clearing inputs. Done returns to Profile.

Both UI and service prevent duplicate operations. Cancel/back are disabled while processing. Recoverable errors keep the form open. Cancellation of Google verification leaves it unverified. Weak-password, policy, network, current-password, UID mismatch, recent-login, provider/configuration, account conflict, and unexpected errors produce safe messages without raw payloads. Passwords retain meaningful whitespace; none are persisted or logged.

## Firebase setup still required

1. Keep Email/Password enabled; review Authentication → Settings → Password policy. No Firebase settings were changed by this implementation.
2. For existing linked Google accounts, complete [Google setup](google-sign-in.md): provider enablement, proper OAuth clients, Android signing fingerprints/refreshed JSON, and web authorized domains/popup permissions. Merely enabling Google does not enroll it on existing password accounts.
3. Before unauthenticated recovery can be enabled, add a secure provider enrollment and verification design that proves the provider was already associated with the target Firebase UID. If a server lookup is needed, it must validate provider credentials and existing Firebase links, without trusting caller-supplied UID/email. Do not enable a client-only flag or infer ownership from Firestore fields.
4. Phone recovery is not implemented/configured and is not offered. It would require prior Firebase `phone` provider enrollment, provider enablement, SMS verification and platform app/reCAPTCHA setup, plus verification that the authenticated UID is the original enrolled account.

## Scope and verification

Changed implementation: `lib/main.dart`, `lib/auth_service.dart`; new `lib/password_dialog.dart` and `lib/password_service.dart`. Existing recovery expectations were updated in `test/google_sign_in_test.dart` and `test/redesign_test.dart`; `test/password_management_test.dart` adds 25 SDK-double service/widget tests. README, these docs, and a current-behavior note in `docs/google-sign-in.md` describe availability.

Firebase initialization/configuration, Firestore schema/rules, registration, ordinary Google/email login, logout, goals, transactions, calculations, planner, reports, and navigation logic were preserved. Password management has no Firestore access and performs no data writes. No dependencies were added.

Automated tests validate client logic using isolated SDK doubles; they do not prove live password changes. Manual acceptance with configured test accounts remains required: linked Google reauthentication on Android/web, rejection of a different Google identity, current-password errors, configured policy rules, successful update, login with the new password, rejection of the old password, cancellation/offline behavior, and unchanged account UID/profile/goals/transactions/tasks/reports. SMS scenarios are unavailable rather than claimed as passed.

Official API basis: [Firebase user management and recent-login reauthentication](https://firebase.google.com/docs/auth/flutter/manage-users), [Flutter password authentication](https://firebase.google.com/docs/auth/flutter/password-auth).

## Executed checks (October 11, 2026)

Flutter 3.47.7 / Dart 3.13.5, with the existing dependency versions.

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; no dependency changes. |
| `dart format .` | Passed after adding the existing Git installation to this command's PATH. |
| `flutter analyze` | Passed on final source; no issues found. |
| `flutter test` / final `flutter test --no-pub` | Final suite passed: 68 tests, including 25 password-management tests and existing regression coverage. |
| `flutter test --dart-define=SAVE_UI_PREVIEWS=true` | Passed: 67 tests before the final expired-token case was added; recovery/change dialogs rendered and inspected. |
| Final recovery preview test | Passed on completed source; updated recovery dialog rendered and visually reviewed. |
| `flutter build apk --debug` | Initial attempt failed in existing Kotlin incremental caches for Firebase Core / Google Sign-In Android. Retry passed with temporary process settings disabling Kotlin incremental compilation and using in-process compilation. Artifact: `build/app/outputs/flutter-apk/app-debug.apk`. |
| `flutter build web` | Passed, including Wasm dry run; artifact: `build/web`. No deployed browser/Firebase authentication session was tested. |
| `git diff --check` | Passed. |
| Live Firebase account acceptance | Not performed. Successful password mutation, new-password login, old-password rejection, linked-account recovery and Google configuration are not claimed as verified. |

The initial test/preview runs exposed compilation/fixture issues and an unnecessary login spinner behind recovery; these were corrected before the passing final suite. No Firebase deployment or real user data mutation was performed.

Android retry used process-local `GRADLE_OPTS`:

```text
-Dorg.gradle.project.kotlin.incremental=false -Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process
```

No project Gradle files or global build settings were changed. The build still emits the existing Firebase Auth/Core Kotlin Gradle Plugin migration notice. Successful compilation does not verify live provider enablement or account ownership recovery.
