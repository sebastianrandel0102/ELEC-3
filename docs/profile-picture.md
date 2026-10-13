# SaveTrack profile pictures on Firebase Spark

Custom profile pictures now use **small compressed image documents in Cloud Firestore**. No Firebase Storage bucket, Blaze upgrade, billing account, or third-party service is required for new uploads. The user explicitly approved storing small avatar images in Firestore on October 13, 2026, replacing the original Storage-only requirement.

The app still uses its existing Firebase Authentication and Firestore database. Gallery selection, circular preview, zoom/position controls, confirmation, replacement, removal, Google-photo fallback, account controls, navigation, savings, planners and currency calculations are preserved.

## Image pipeline

- Tap the circular Profile avatar or attached camera icon. The action sheet offers Gallery, View and confirmed Remove where applicable.
- `image_picker` selects an existing image with `ImageSource.gallery` and `requestFullMetadata: false`. Android uses its supported photo-picker flow; no camera or broad storage permission is added. Web reads bytes instead of local file paths.
- Originals must be JPEG/PNG, no larger than 20 MiB or 24 megapixels (12 megapixels for 16-bit PNG), with a maximum side of 12,000 pixels. Decoding, actual signatures, still-image encoding and dimensions are checked.
- EXIF orientation is applied. The working preview has a maximum edge of 1,536 pixels. Crop/zoom/position controls determine the actual square crop. Transparency is flattened onto white; original metadata including GPS is discarded.
- The approved crop is encoded at **512 x 512**, using JPEG 4:2:0 sampling and quality 88. Quality 82 then 76 are attempted only when needed to meet the strict **200 KiB (204,800 bytes)** limit. Compression failure is reported instead of uploading an oversized file. Native processing uses Flutter `compute`; the bounded workload runs on the main thread on web.
- New photo saves use Firestore transactions. Firestore does not provide byte-upload percentages, so saving shows an honest indeterminate indicator. Duplicate submissions are disabled; cancellation never writes a photo or profile reference.

## Persistence and one authoritative reference

New images are binary `Blob` values in private, versioned documents:

`users/{Firebase UID}/profilePhotos/{20-character random ID}`

The document contains only `bytes`, `contentType` (`image/jpeg`), `width`, `height`, and server `createdAt`. The user profile contains only a reference and maintenance metadata; image bytes are never embedded in the existing profile document or included in its live snapshots.

The existing `users/{uid}.avatarStoragePath` field is retained as the **single authoritative photo reference** for backward compatibility. For new saves it contains the Firestore document path above. `avatarCleanupPaths` remains a deletion-retry queue, not a second image source. No new user-profile database or conflicting photo field was introduced.

The Firestore adapter saves the immutable photo object in an online transaction, verifies that the object exists, then updates only the two avatar fields in the existing profile transaction. Names, email, creation date, currency, notification settings and all savings/planner subcollections remain intact. Failed metadata commits trigger a server check before rollback. A lost response cannot cause deletion of the committed active image or false success.

Firestore profile snapshots refresh the avatar immediately and restore the reference after restart, login or another-device login. Authenticated image downloads use a small cache keyed by versioned reference. Invalid data or failed downloads fall back to initials/person icon. Google photos remain the fallback; custom photos take precedence, and Firebase Auth `photoURL` and provider links are not overwritten.

Removal clears the custom reference first, then deletes the obsolete owned photo. Failed cleanup retains the retry queue. Maintenance checks queued objects and at most three unreferenced Firestore photos per visit; objects older than one day can be removed. The current avatar is excluded from the orphan query, avoiding unnecessary binary downloads. Queued paths are rechecked against server state before deletion. Abandoned accounts may still require administrator cleanup; no paid TTL or Cloud Function is used.

## Security and quotas

`firestore.rules` adds owner-only access to `users/{uid}/profilePhotos/{photoId}`. New objects require a safe ID, the exact field allowlist, binary bytes, JPEG framing, 512-pixel dimension metadata, a server timestamp and a maximum 200 KiB payload. Objects cannot be overwritten. Foreign users and unauthenticated users cannot read/list/write/delete them. An active photo cannot be deleted until its profile reference has been cleared or replaced. A new profile reference must point to an existing owned photo.

Rules check JPEG framing and metadata; complete decoding is also enforced by the app before save and display. Rules cannot fully decode image files. Profile and shared-member visibility remain private: the existing name-based shared-goal initials are unchanged. Savings/planner rules and currency constraints are retained.

`firestore.indexes.json` exempts the `profilePhotos.bytes` field from indexing, avoiding unnecessary binary index entries. No composite index is required for the maintenance query.

Firestore has a [free quota](https://firebase.google.com/docs/firestore/quotas#free_quota) of 1 GiB stored data, 50,000 reads/day, 20,000 writes/day, 20,000 deletes/day and 10 GiB outbound transfer/month. Photo reads/writes and existing app data share these quotas. The 200 KiB photo limit stays well below the [1 MiB document limit](https://firebase.google.com/docs/firestore/quotas#collections_documents_and_fields). Staying on Spark does not create unlimited storage; quota exhaustion is reported clearly.

## Required setup without Blaze

The existing project is `project-4dcb3`. Firebase Auth and Firestore are already used by SaveTrack. **Do not enable Firebase Storage or upgrade billing for this implementation.**

1. Open [Firestore Rules for this project](https://console.firebase.google.com/project/project-4dcb3/firestore/rules).
2. Publish the repository's updated `firestore.rules`. Compare with any currently deployed changes that are absent from this checkout before replacing cloud rules. The new `profilePhotos` rule is required because the existing owner profile rule does not automatically allow access to subcollections.
3. In Firestore **Indexes > Single field**, add an exemption for collection group `profilePhotos`, field `bytes`, with all indexes disabled. Alternatively deploy the checked-in rules/indexes using an authorized Firebase CLI account:

   ```powershell
   firebase login
   firebase deploy --only firestore --project project-4dcb3
   ```

   `--only firestore` does not deploy Storage or any paid backend.

4. Install the rebuilt `build/app/outputs/flutter-apk/app-debug.apk` and test a real photo. Verify restart, login, replacement/removal and another device signed in to the same account.

This machine has no authorized Firebase CLI account. Production rule/index deployment and real-account upload/display have not been performed here. Local/emulator tests do not establish production end-to-end readiness.

## Legacy Storage compatibility

The previous `users/{uid}/profile/avatar/{id}.jpg` references are still recognized. The existing Firebase Storage dependency and rules are retained only to support older images and cleanup when such a reference exists. New photos use `FirestoreProfilePhotoBackend`; its ordinary upload/read/delete operations do not contact Storage. No Storage bucket is initialized for the new path.

The configured bucket had returned 404 during the previous diagnosis because it had not been created. That missing bucket does not affect this Spark implementation. No tokenized download URL, API secret, third-party account or replacement Firebase credentials are needed.

## Files and dependencies

- `lib/profile_photo_service.dart`: new Firestore adapter, legacy adapter, ownership, transactions, rollback, caching, cleanup and readable errors.
- `lib/profile_photo_processing.dart`: bounded validation, optimized crop/JPEG encoding and the 200 KiB cap.
- `lib/profile_photo_picker.dart`, `lib/profile_photo_widgets.dart`: gallery/lifecycle recovery and existing mint-green avatar UI.
- `lib/main.dart`: Profile uses the Firestore adapter and existing profile stream.
- `firestore.rules`, `firestore.indexes.json`: private binary photo permissions and index exemption. Legacy `storage.rules`/`firebase.json` remain available.
- Tests: `test/profile_photo_test.dart`, `test/profile_photo_firestore_backend_test.dart`, and `test/profile_photo_emulator/profile-photo.rules.test.cjs`. The existing financial/security regression runner remains unchanged.
- Existing dependency additions remain pinned: `image_picker 1.2.4`, `image 4.11.1`, `firebase_storage 13.6.0` (legacy only). No new dependency was needed for Spark.
- Existing iOS photo-library description, macOS selected-file entitlement and Flutter-generated desktop registrants remain in place. No new Android Gradle or manifest changes were needed.

## Validation

Validation runs use Flutter 3.47.7 / Dart 3.13.5, isolated demo Firebase emulators, and the installed Android toolchain. The emulator suite checks legacy Storage access plus the new Spark path, binary/size/type constraints, owner-only access, immutable objects, active-object protection, persistence, and preservation of existing user/savings/planner records.

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
flutter build web
py -3 test/run_shared_emulator.py --java 'D:\Program Files\Android\Android Studio\jbr\bin\java.exe'
```

For avatar integration/rules checks (Node 24.12+ and Java 21+):

```powershell
Set-Location test/profile_photo_emulator
npm ci
npm test
```

This suite uses only `demo-savetrack-avatar` and refuses to run without the dedicated emulator environment variables.

### Actual results — October 13, 2026

- `flutter pub get`: passed.
- `dart format .`: passed; only the feature's processing source required formatting.
- `flutter analyze`: no issues.
- Full `flutter test`: **298 passed**, including **44 photo/persistence/adapter tests**.
- Avatar integration/rules: **15 passed**, including the exact 200 KiB boundary, binary data persistence, owner/guest/foreign access, immutability, active-photo protection and preservation of savings/planner/profile fields.
- Existing financial/security emulator regressions: **51 passed**.
- Android: `flutter build apk --debug` passed; artifact is `build/app/outputs/flutter-apk/app-debug.apk`.
- Web: `flutter build web` passed; artifact is `build/web`. The Wasm dry run succeeded; a separate Wasm release build was not requested.
- Firebase plugin Kotlin warnings remain upstream notices; no unrelated Gradle migration was made.
- Production rules/index publication, real-phone upload/display and a second physical device still need verification using the configured project. No production deployment or billing change was performed.
