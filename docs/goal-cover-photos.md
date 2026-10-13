# Goal Cover Photos

Optional covers belong to an individual personal or shared savings goal, independently of profile avatars. Cards, Home previews and Goal Details retain the landscape crop and Mint Aurora presentation, with existing balances, reminders, ledger and membership behavior.

## Upload failure fixed on 14 October 2026

The configured `project-4dcb3.firebasestorage.app` bucket returned HTTP 404. A new Storage upload consequently failed with `object-not-found`; changing Firestore permissions alone could not repair that bucket. The user approved compact Firestore covers without a billing upgrade, matching the existing profile-photo approach. All production cover actions now use `FirestoreGoalCoverBackend`. Creating, uploading, reading, replacing and deleting a new compact cover never initializes Firebase Storage.

Existing Storage references remain readable and removable through the legacy adapter, if their bucket is available. No Firebase project or bucket configuration is replaced, and no billing upgrade or Cloud Functions deployment is required for the compact implementation.

## Workflow

- On creation, choose an optional gallery photo, preview its actual oriented image, and adjust a locked 16:9 crop. The goal is saved before the cover. A cover failure leaves that goal intact and allows retry or completion without a photo. A retry retains its document ID and never recreates its finances or shared membership.
- Existing personal owners and shared owners can add, replace or remove a cover from its form, actions or Details photo control. Shared contributors only view it.
- Preview supports dragging, zoom and horizontal/vertical sliders. Choose Another Photo preserves the selection when the picker is cancelled. Cancel never uploads. Save/Cancel remain visible on narrow screens. Firestore has no transfer-byte progress API, so saves show indeterminate progress until the server confirms both photo and reference.
- Removal clears only the cover reference, then deletes the obsolete photo. Financial and profile fields are untouched.

## Processing

The existing bounded preparation utility accepts decodable JPEG/PNG, rejects corrupt/animated/unsupported input, bounds originals to 20 MiB / 24 megapixels, applies EXIF orientation, removes GPS/metadata, flattens transparency and bounds its working edge to 1536 pixels. The approved viewport is cropped to a 1280 by 720 JPEG with a 1 MiB intermediate limit.

The Firestore adapter independently validates that intermediate, resizes the same crop to **960 by 540**, removes metadata again, and tries JPEG quality 86/78/70/62/54/46/38/30 until it fits **200 KiB**. Detail-heavy photos can require more compression. Loading verifies the stored MIME/dimensions, size, JPEG framing and bounded full decoding before displaying bytes. Lower resolution is the deliberate tradeoff for compact covers.

No dependencies were added or upgraded. Gallery selection uses the existing system picker without camera or broad storage permissions. JPEG/PNG, picker cancellation, owner-specific lost-data recovery, account changes and Web byte-based processing retain the existing implementation. Android process death can recover selection for an existing goal; unsaved forms require reopening and reselecting. Web processing uses Flutter's existing `compute` behavior and can occupy the browser thread within the bounded input limits.

## Data and permissions

| Type | Immutable Firestore photo document |
| --- | --- |
| Personal | `users/{ownerUid}/goals/{goalId}/coverPhotos/{20-character-version}` |
| Shared | `sharedGoals/{goalId}/coverPhotos/{20-character-version}` |

Each photo contains only `bytes` (Blob), `contentType`, `width`, `height` and server `createdAt`. Image bytes stay separate from goal, financial, profile and planner snapshots. `coverPhotos.bytes` has an index exemption in `firestore.indexes.json`.

The goal retains the compatible `coverStoragePath` reference field plus server `coverUpdatedAt`; the path now identifies either a compact Firestore photo or a legacy Storage object. No public URLs or tokens are stored. Goals without covers need no migration.

Firestore Rules enforce exact goal-specific paths, an existing referenced photo, owner-only writes, immutable image versions, JPEG framing, 960 by 540 metadata and a 200 KiB limit. Personal covers are private to their owner while the goal exists. An active shared member may fetch only the currently referenced shared cover. Staged and obsolete shared photos are private to the owner. Listing is denied. Guests, unrelated accounts, removed/inactive members and contributor edits are denied.

Cover-only root updates cannot include financial, currency, ownership or membership changes. Shared financial actions continue through the original strict atomic protocol. Rules reject deletion of a currently referenced photo, including a reference/deletion race. Personal owners can clean up an orphan after deleting its parent goal. Rules inspect framing and supplied dimensions; the app additionally validates actual decoded content.

## Ordering, retries and cleanup

The service checks the current owner and fetches the goal from the server, journals a new immutable destination, writes the compact photo in an online transaction, then compares the previous reference in a second transaction before attaching the photo. A concurrent device change is rejected. The photo must exist before attachment. Firestore transactions fail offline rather than treating a queued write as a confirmed save ([Firebase transaction documentation](https://firebase.google.com/docs/firestore/manage-data/transactions)).

The old photo is deleted only after attachment commits. An ambiguous acknowledgement is resolved by reading the server reference. Cleanup independently rechecks that reference; rules protect the current photo. Failure to confirm or delete leaves the private journal for later retry. Removal and whole-goal deletion use the same cleanup path; image cleanup failure cannot undo successful goal deletion.

`users/{ownerUid}/goalCoverUploads/{version}` contains only `goalId`, `shared`, `storagePath` and server `createdAt`. Entries accept the exact compact or legacy path, remain immutable and private, and survive crashes. Owner session startup checks at most 100 entries older than 24 hours; referenced covers are retained. Cleanup depends on the owner returning to the app. A never-returning account may retain an orphan until administrator maintenance.

The optional existing `sweepGoalCovers` / `cleanupDeletedGoalCovers` functions recognize both backends. Compact cleanup uses an Admin transaction so a concurrent reference update cannot turn a deleted photo into the current cover. Legacy cleanup uses a Storage generation precondition. These functions are not needed or deployed for Spark. Do not deploy the legacy sharedSavings service as part of this fix.

## Cache

Authenticated server document reads load compact photos; legacy paths use authenticated Storage `getData`. The app publishes no download URLs. A version-aware memory cache deduplicates requests and bounds compressed entries to 24 / 12 MiB. Cards request 640-pixel decoding; Details requests 1280. Session and shared-access changes discard in-flight bytes and evict tracked Flutter image providers. The existing shared-goal listener supplies revocation information.

The app-managed image cache creates no separate disk files. The existing Firestore SDK persistence configuration is retained, so its normal platform cache can store documents locally; `Source.server` does not disable SDK persistence ([Firebase offline documentation](https://firebase.google.com/docs/firestore/manage-data/enable-offline)). Previously delivered photos or screenshots cannot be recalled. An uncached or inaccessible cover shows the existing Mint Aurora fallback.

## Publish and run

1. In Firebase Console for `project-4dcb3`, open **Firestore Database > Rules**, replace the editor with the complete updated `firestore.rules`, then Publish. Alternatively, sign in to Firebase CLI and deploy `firestore:rules,firestore:indexes` for that project.
2. Deploy `firestore.indexes.json` to apply the `coverPhotos.bytes` exemption. Existing indexes and avatar exemptions are preserved. No Storage Rules/CORS changes are needed for new Firestore covers.
3. Install the rebuilt debug APK or run the updated app with a full restart. An already installed APK still contains the old Storage upload code.
4. Check save, replacement, removal and second-account shared membership on real devices after publishing rules.

Firestore supplies free quotas, including stored data and daily operations; compact images still consume that allowance ([Firebase quotas](https://firebase.google.com/docs/firestore/quotas)). This implementation avoids the Storage billing requirement without offering unlimited image hosting.

No authorized Firebase CLI account or connected Firebase Console browser session was available during this fix. Rules/indexes were prepared and emulator-validated, but were not published. There was no live upload or connected Android device.

## Verification

Verified with Flutter 3.47.7 / Dart 3.13.5 on 14 October 2026:

| Check | Result |
| --- | --- |
| Format on changed Dart files | Passed |
| `flutter analyze` | Passed; no issues |
| `flutter test --dart-define=SAVE_UI_PREVIEWS=true` | **423 passed**, including 31 cover service/processing/picker/cache tests, 9 compact Firestore adapter tests and 15 cover widget tests |
| Demo Firestore + Storage emulator suite | **46 passed**: 24 compact/legacy cover tests, 15 avatar tests and 7 reminder tests |
| Personal/shared/currency Firestore regression suite | **54 passed**, including the full shared protocol with a compact cover attached |
| Node cleanup unit tests | **7 passed** |
| `flutter build apk --debug --no-pub` | Passed; `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build web --no-pub` | Passed; `build/web`; Wasm dry run also succeeded |
| `git diff --check` | Passed |

The adapter tests upload real compact JPEG bytes without initializing Firebase Storage, preserve goal/profile fields, verify reference-before-cleanup ordering, reject immutable collisions and missing references, and validate authenticated server loading. A detailed-noise image exercises the compression limit; the emulator separately accepts an exactly 200 KiB blob and rejects larger blobs. Financial regression checks verify contributions, withdrawals, invitations and member removal with a compact reference, while rejecting contributor cover forgery.

The fresh narrow-screen preview and personal Details captures were visually inspected: `build/ui-preview/goal-cover-preview-320.png` and `goal-cover-details-390.png`. No live uploads, phone gallery tests or production rule/index deployments were performed.
