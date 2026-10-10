# SaveTrack Google Sign-In

Google Sign-In is an additional method on the existing login form. Email/password registration, sign-in, recovery, the mint theme, Firebase initialization, and the existing HomeShell navigation remain in place.

## Implementation

- `lib/auth_service.dart` initializes `GoogleSignIn.instance` once, calls `authenticate()` on Android/iOS/macOS, obtains the ID token, and exchanges `GoogleAuthProvider.credential(idToken: ...)` through Firebase `signInWithCredential`. It requests no additional Google API scopes.
- Web calls Firebase `signInWithPopup(GoogleAuthProvider())` directly from the button interaction; it does not call the native Google authentication API or require Google Identity Services' rendered web button.
- The Firebase-authenticated UID selects `users/{uid}`. A Firestore transaction creates the document only if missing, with the same `displayName`, `email`, `createdAt` server timestamp, and `currency: PHP` fields as email registration. No existing profile fields or child records are written on subsequent logins.
- AuthGate waits for Google profile preparation before showing the existing HomeShell. A profile failure signs out the newly authenticated session; it does not delete the Firebase account or app data. Cancellation is silent, failures use the existing ErrorPanel, and both UI and service block duplicate requests.
- Logout signs out Firebase and clears native Google account state, including restored Google sessions. Google cleanup errors cannot prevent Firebase logout. Web retains the browser's Google account session, as expected for Firebase popup authentication.
- Account conflicts explain that the user must use the existing sign-in method. The app never calls linking, merging, provider lookup by email, or account deletion APIs. Firebase itself determines trusted-provider behavior for matching verified identities; do not change account-security settings to bypass conflicts. Confirm behavior with existing password accounts during manual testing.
- Tokens exist only for credential exchange and are never stored in Firestore or logged. Security rules and data paths are unchanged.

Dependency added: `google_sign_in: ^7.2.0`, resolved to **7.2.0**. Existing Firebase versions remain unchanged. Its endorsed Android/iOS/web packages are transitive dependencies; no new test dependency is needed. Google supplies the logo and Google Sans font; provenance and license are in `assets/branding`.

Validation used Flutter **3.47.7** and Dart **3.13.5**, matching the existing Dart constraint. The resolved Android implementation **7.2.17** requires Flutter **3.44.0+**, recorded in the lockfile. No unrelated dependency upgrades were performed.

## Required Firebase / Google Cloud setup

The checked-in configuration identifies Firebase project **project-4dcb3** (project number **864730227148**) and Android package **com.example.myproject**, app ID **1:864730227148:android:1e8d2655ca328ed0d2fd69**. These match the Android Gradle and Dart configuration. The current Android JSON has an **empty `oauth_client` array**, so native Google authentication needs console configuration. Provider enablement and registered fingerprints cannot be verified from these local files.

1. Open [Firebase Console](https://console.firebase.google.com/project/project-4dcb3/authentication/providers) for **project-4dcb3**. In **Authentication → Sign-in method**, enable **Google**, select the project's support email, and save. Keep **Email/Password** enabled.
2. In **Project settings → General → Your apps**, select the existing Android app **com.example.myproject**. Add both SHA-1 and SHA-256 for each certificate that actually signs installed builds. This workstation's debug certificate, read with keytool, is:

   ```text
   SHA-1:   61:36:B9:E8:81:77:3B:75:C6:D7:4A:E4:FB:0C:B8:D0:23:1B:AE:E3
   SHA-256: AF:50:4D:92:B6:BD:4A:30:12:6C:0F:7B:08:05:FB:FC:41:17:E9:98:93:6E:75:F2:F1:4B:67:B8:F0:07:68:F4
   ```

   Other developers must register their own debug fingerprints. The existing release build currently uses the debug signing configuration; no signing settings were changed. When release signing is configured, register that certificate too. For Play distribution, register the **Play app-signing certificate**, not just the upload certificate.
3. Download the refreshed **google-services.json** for this exact Android app and replace only `android/app/google-services.json`. Verify its project/app/package identifiers match above and `oauth_client` includes the web OAuth client with **`client_type: 3`**. The existing Google Services Gradle plugin supplies its ID to `initialize()`; no hardcoded `serverClientId` is needed. If the web OAuth entry is missing, check the project's web app/OAuth client configuration and download again. Never use an Android OAuth client ID as the server client ID.
4. In the same Google Cloud project's **Google Auth Platform**, confirm Branding, Audience, and OAuth clients correspond to this app. If consent is in testing mode, add the intended Google test users. Use only clients created for this Firebase project. Authentication alone does not require enabling the People API or extra Google API scopes.
5. Fully restart/rebuild the app after changing native configuration. Plugin initialization occurs once per process; hot reload will not reload the new OAuth configuration.

No Gradle, manifest, minimum SDK, application ID, Firebase initialization, security rule, or signing changes were necessary.

Official references: [Android plugin setup](https://pub.dev/packages/google_sign_in_android), [7.2.0 package API](https://pub.dev/packages/google_sign_in/versions/7.2.0), [Firebase federated authentication](https://firebase.google.com/docs/auth/flutter/federated-auth).

## Other platforms

- **Web:** Existing Firebase web options already specify `project-4dcb3.firebaseapp.com`. Enable the Google provider and add each development/production hostname under **Authentication → Settings → Authorized domains**, including `localhost` if absent. Permit the popup and test on the deployed HTTPS origin. Firebase's popup flow uses its configured Google provider; do not invent a web client ID or add GIS metadata to `web/index.html` for this implementation.
- **iOS:** The existing Firebase bundle ID is `com.example.myproject`. After enabling Google, download its `GoogleService-Info.plist` from the same project's registered Apple app. Copy its **CLIENT_ID** into `GIDClientID` in `ios/Runner/Info.plist`. Add `CFBundleURLTypes`, with a dictionary containing `CFBundleTypeRole: Editor` and a `CFBundleURLSchemes` array containing the plist's **REVERSED_CLIENT_ID**. If configuring a server client, `GIDServerClientID` must be the same project's **web** OAuth client ID. No guessed values were inserted in this repository. See [Apple plugin setup](https://pub.dev/packages/google_sign_in_ios).
- **macOS:** Apply the same client ID and reversed URL scheme setup in `macos/Runner/Info.plist`. Enable Keychain Sharing and add `keychain-access-groups` with `$(AppIdentifierPrefix)com.google.GIDSignIn` to both `DebugProfile.entitlements` and `Release.entitlements`. Verify the registered bundle ID matches the Xcode target. These identifiers/entitlements require validation on macOS; they were not guessed here.
- **Windows/Linux:** The official Google Sign-In plugin supports Android, iOS, macOS, and web only. The Google button is guarded out on unsupported native targets; existing email/password authentication is retained. Linux also lacks Firebase options in the original project. No custom desktop OAuth flow was introduced.

## Validation and manual acceptance

Unit/widget tests use isolated SDK doubles, not a live Firebase project or Google account. They cover token exchange, UID ownership, required profile fields, preservation of existing profiles, repeated login, cancellation, credential/network/configuration/conflict errors, duplicate requests, loading until profile completion, rollback, web popup routing, restored-session logout, cleanup failures, branded UI, small-screen keyboard scrolling, and existing form/recovery/registration controls.

Real account/device checks remain required after console setup:

- Debug Android: complete Google account selection and confirm Firebase currentUser plus the expected `users/{uid}` document. Sign out, select another account, and verify data isolation.
- Returning user: verify the same Firebase UID and unchanged profile, goals, deposits, transactions, tasks, and reports. Repeat login and confirm no extra profile document.
- New user: verify only the existing four profile fields are created under the authenticated UID.
- Cancel/back: remain on login without an error. Retry successfully. Test offline/network errors and disabled/misconfigured provider behavior. Android Credential Manager can report some configuration errors as cancellation; if selection repeatedly returns silently, recheck fingerprints and the web OAuth client.
- Existing email/password account: test sign-in, registration, reset email delivery, and logout against the real backend. Test a Google identity sharing an existing account email; confirm Firebase's UID/provider behavior and that existing app data is preserved.
- Web: test popup success, cancellation, popup blocking, authorized domain failures, and logout on the deployed origin.
- Release/Play and Apple: repeat on the real signing configurations and configured devices. No Android device, Apple toolchain, or authenticated console session was available during implementation.

## Executed checks (October 10, 2026)

| Command | Result |
| --- | --- |
| `flutter pub get` | Passed; Google package and five transitive dependencies added. Existing Firebase versions retained. |
| `dart format .` | Passed. |
| `flutter analyze` | Passed; no issues found. |
| `flutter test` | Passed; 43 tests, including 25 Google service/UI tests. |
| `flutter test test/google_sign_in_test.dart` | Passed; all 25 new tests. |
| `flutter test test/redesign_test.dart --dart-define=SAVE_UI_PREVIEWS=true --plain-name 'login preview'` | Passed; rendered login preview reviewed with the actual Google font/logo. |
| `flutter build apk --debug` | Passed, including a final rebuild of the completed source; artifact: `build/app/outputs/flutter-apk/app-debug.apk`. |
| `flutter build web` | Passed; artifact: `build/web`. The Wasm dry run also succeeded; a deployed browser authentication session was not tested. |
| `git diff --check` | Passed. |

The Android build emitted an existing Firebase Auth/Core Kotlin Gradle Plugin migration notice. It did not fail; no unrelated plugin/Gradle upgrade was made. Apple builds require a Mac; Windows build tooling is unavailable on this machine. These successful compile checks do not verify provider enablement, OAuth clients, live Google authentication, reset email delivery, or real account data access.

The existing registration-mode UI test now waits for scrolling/layout to settle before tapping its link after the additional button. Its validation/input-preservation assertions remain unchanged. Optional screenshot generation also preloads the Google logo and bundled Google Sans font.

## Files changed

- `lib/main.dart`: Google button and loading/errors, AuthGate profile wait, logout integration; existing email registration/login/recovery remain.
- `lib/auth_service.dart`: Google/Firebase exchange, create-if-missing profile transaction, cancellation/errors, duplicate guard, Google cleanup.
- `pubspec.yaml` and `pubspec.lock`: Google dependency, logo/font registration, resolved packages.
- `macos/Flutter/GeneratedPluginRegistrant.swift`: automatically generated registration for the endorsed Google plugin.
- `assets/branding/google_g.png`, `GoogleSans.ttf`, `GoogleSans-OFL.txt`, and `README.md`: official assets, font license, and provenance.
- `test/google_sign_in_test.dart`: 25 new service/widget tests using SDK doubles.
- `test/redesign_test.dart`: registration-link layout wait and Google assets in optional previews.
- `README.md` and `docs/google-sign-in.md`: setup reference, external configuration steps, validation report, and manual checklist.

Firestore rules, Firebase options/JSON, Gradle/manifest/signing configuration, and all savings/planner/report business logic remain unchanged.
