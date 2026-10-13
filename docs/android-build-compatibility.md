# Android build compatibility

The Gradle launch scripts grant native access to the launcher JVM. The same
option in `android/gradle.properties` grants access to the daemon JVM. Both
processes load Gradle's native libraries when using Android Studio's JDK 25.
The daemon uses a 4 GB maximum heap and two workers; Kotlin compiles in that
process to avoid running an additional compiler daemon on machines with limited
available memory.

`android/flutterfire-compat.settings.gradle.kts` stages Android modules under
`android/.gradle/flutterfire-compat` for firebase_core 4.15.0, firebase_auth 6.7.0,
firebase_storage 13.6.0, and cloud_firestore 6.10.0. The original packages in the
Pub cache and their Dart, web, and Apple implementations remain unchanged.

The three Kotlin modules remove their legacy Kotlin Gradle Plugin guards and
configure `kotlin.compilerOptions` directly, following the
[Flutter migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors).
This project requires AGP 9 and `android.builtInKotlin=true`. Flutter's warning
detector otherwise matches even guarded legacy plugin declarations.

The Firestore copy adds `@SuppressWarnings("unchecked")` to
`PipelineStageHandlers`, extending annotations already used on individual
methods to its generic platform-channel parsing helpers. This suppresses that
dependency's compiler note; it does not change runtime behavior or disable
warnings in application code.

The patches apply only to the versions listed above. Upgraded packages use their
published Android builds; review and remove the compatibility script when their
upstream fixes are available. Generated copies are recreated as needed after
deleting Gradle caches. Flutter's icon tree-shaking message is informational and
is retained to keep the release APK smaller.
