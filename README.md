# SaveTrack

SaveTrack is a Flutter savings goals and daily planner app. It uses Firebase Authentication and Cloud Firestore for sign-in and cloud persistence.

Optional personal/shared **Goal Cover Photos** include gallery selection, landscape cropping, compact private Firestore photos and Mint Aurora cards. New covers work on Spark without a Storage bucket or billing upgrade. See [implementation, setup and verification](docs/goal-cover-photos.md).

## Firebase setup

Firebase credentials are intentionally not included in this repository. To connect your project:

1. Install the FlutterFire CLI and run `flutterfire configure` from this project directory. Select the registered Firebase project and Android application.
2. Install `google-services.json` at `android/app/google-services.json` and configure the Google Services Gradle plugin as directed by FlutterFire for this Android Gradle setup.
3. In Firebase Console, enable **Authentication > Email/Password** and create a **Cloud Firestore** database.
4. Deploy the rules in [`firestore.rules`](firestore.rules) with `firebase deploy --only firestore:rules`.
5. Run `flutter pub get`, then `flutter run` with an Android device or emulator.

The app initializes Firebase with native default configuration and displays a setup message if initialization fails. It does not provide a demo login or in-memory substitute.

## Data layout

Google Sign-In is available alongside email/password login. See [Google Sign-In setup and validation](docs/google-sign-in.md) for the existing Firebase project's required OAuth configuration, platform setup, and manual acceptance checks.

Forgot Password opens a mint email-recovery modal and requests a real Firebase password-reset email. Firebase's hosted handler verifies the emailed action code and handles the password update. Profile retains its separate password-change modal using Firebase reauthentication. See [recovery setup and verification](docs/password-recovery.md) and [signed-in password management](docs/password-management.md).

- `users/{uid}`: display name, email, account creation time, and currency preference.
- `users/{uid}/goals/{goalId}`: title, optional note and deadline, target amount, saved amount, and timestamps.
- `users/{uid}/goals/{goalId}/transactions/{transactionId}`: deposit and withdrawal history. Currency-aware entries commit atomically with the balance and preserve confirmed conversion metadata.
- `users/{uid}/tasks/{taskId}`: title, optional time, date key, priority, completion state, and timestamps.

The supplied Firestore rules restrict private document access to the signed-in user whose UID owns the path.

## Current scope

Implemented: email/password registration and sign-in, Firebase email password recovery, authenticated password changes, profile creation at registration, a live dashboard, savings goal create/edit/delete, batched deposits and transaction history, daily and weekly savings pace calculations for goals with deadlines, daily task create/edit/delete/completion, date navigation, summaries, and sign-out.

Not yet implemented: personal goal/task filters and sorting, transaction correction/deletion, a weekly planner view, daily/weekly/monthly trend charts, and profile editing. Shared transaction and Firestore security regression tests run locally in an isolated emulator. Live Firebase behavior still requires configuration and manual account testing.

Smart Reminders adds native Android/iOS scheduling for personal goals, each shared-goal member's own preferences, and planner tasks. Use the goal/task bell controls and **Profile → Smart Reminders**. See [setup, permissions, time policies, validation, and device limitations](docs/smart-reminders.md). Deploy the added Firestore reminder rules before using synced preferences. Native phone delivery still needs the documented real-device acceptance checks.

## Checks

SaveTrack AI Coach Lite is available from the Dashboard with separate Ask Anything and Coach sessions, real Gemini streaming, local financial facts and explicit context approval. See [implementation, privacy, Firebase AI Logic/App Check setup and validation](docs/ai-coach.md). Console configuration is required before live AI requests can succeed; the feature does not enable billing.

Daily Planner includes local, time-aware **Smart Suggestions**, with a next-task card, recommended follow-ups, explainable ranking, explicit-window conflict warnings, and automatic clock/data updates. It uses existing task records and actions. See [Smart Suggestions rules, supported time formats and validation](docs/smart-suggestions.md).

Save Together adds shared goals, secure single-use invitations, attributed contributions, owner controls and live shared reports. It uses Spark-compatible Firestore transactions and security rules; no Cloud Functions or billing upgrade is required. See [implementation, Firebase deployment, verification and two-account testing](docs/save-together.md). Existing personal financial records remain private and unchanged; sharing a personal goal creates a separate shared goal at zero.

Run `dart format .`, `flutter analyze`, and `flutter test`. Attempt an Android debug build with `flutter build apk --debug`.

Global currencies are available from **Profile → Currency Settings**. PHP remains the default. Display preferences never revalue stored goals; new personal goals can choose a supported denomination. Daily public exchange rates, offline caching, exact decimal conversion, cross-currency tracking entries, and shared/report estimates are documented in [the implementation and verification report](docs/currency-system.md). Deploy the updated Firestore rules before using the new financial recording flow. No currency API key, Cloud Functions deployment, or billing upgrade is required.
