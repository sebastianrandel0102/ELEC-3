# SaveTrack piggy-bank branding

The revised identity follows the user's simple silhouette reference: one rounded mint piggy bank facing left, a short snout, one ear, a small eye, two sturdy feet, and a restrained curved tail. One circular gold coin floats directly above the centered dark money slot. There are no currency characters, extra coins, textures, or shading inside the pig. Only the launcher background has a subtle emerald gradient.

The symbol uses luminous mint `#4BD4A8`, deep emerald `#073F34`, premium gold `#F5C96A`, and a gold rim `#DDAA4F`. The background transitions from `#073F34` to rich emerald `#13876D`. The light-surface variant uses an emerald pig with pale mint `#DCF8EB` eye and slot. The wordmark remains SaveTrack in the existing bundled Manrope typeface at weight 700, with deliberate spacing.

## Master and generation

`assets/branding/savetrack-symbol.svg` is the original 1024 × 1024 vector master. It contains two groups, `pig` and `coin`, with absolute Bézier paths. All geometry is derived from this source; none of the PNGs is used as a source for a larger PNG.

Run from the repository root:

```powershell
py tools/generate_branding.py
```

The Python script uses only the standard library. It writes SVG variants, Android vector resources, and `lib/branding/savetrack_logo_painter.dart`, then runs `flutter test tools/render_branding.dart --reporter expanded`. This export utility rasterizes the same painter with Flutter's renderer and downsamples each independently rendered image for antialiasing. The existing `image` and `flutter_test` dependencies are reused. No Flutter, Python, or native dependencies were added; `pubspec.yaml` and `pubspec.lock` remain unchanged.

The runtime symbol uses `SaveTrackLogo` and its generated `CustomPainter`. Static artwork has a repaint boundary and requires no runtime image decoding. Master and export files are kept out of the Flutter asset bundle because the painter is compiled into the app.

## Platform and in-app integration

| Location | Implementation |
| --- | --- |
| Android legacy launcher | Generated opaque PNGs in all five existing mipmap densities: 48, 72, 96, 144, and 192 pixels. The existing manifest continues to reference `@mipmap/ic_launcher`. |
| Android adaptive icon, API 26+ | `mipmap-anydpi-v26/ic_launcher.xml` references separate vector foreground and full-bleed gradient background. Both use a 108 dp canvas. Foreground artwork is scaled to `.84` of the master and fits within the central 66 dp circular safe area. Android applies the launcher mask. |
| Android themed icon, API 33+ | `mipmap-anydpi-v33/ic_launcher.xml` adds a white monochrome vector. The coin has a thick circular ring with transparent center so its meaning does not depend on gold. The pig remains a solid silhouette. |
| Android native splash | Existing launch backgrounds now show a centered vector on deep emerald. API 31 day/night themes use a static splash vector and an opaque emerald background; the 288 dp vector is scaled to fit the 192 dp circular visible area. No Activity or startup lifecycle code changed. |
| Flutter session loading | The existing `AuroraEmblem` now draws the pig logo. Its existing session-loading view opts into a single 700 ms coin drop. The coin clips at the slot as it enters. Reduced-motion and accessible-navigation settings show the static coin-above-pig logo. Authentication does not wait for the animation. |
| Login and registration | `BrandMark`, `BrandDot`, and the existing authentication showcase reuse the same vector symbol. SaveTrack's wordmark uses Manrope. Forms, callbacks, sign-in buttons, and Google branding are unchanged. |
| Dashboard and Profile/Settings | The existing shared navigation-header `BrandDot` now shows the pig. No additional dashboard logo was added. Profile photos, goal covers, functional savings icons, and navigation icons remain unchanged. |
| Password recovery | The existing dialog has functional email/reset symbols rather than an application logo; those symbols and its workflow remain unchanged. |
| Flutter Web | Replaced the 32 px favicon and existing 192/512 px standard and maskable icons. Added a 180 px Apple touch icon. Manifest colors, HTML title, description, and visible app name now use SaveTrack instead of scaffold defaults. The base URL, manifest start URL, and Flutter bootstrap/routing are unchanged. There was no existing branded web loading screen. |
| iOS | Replaced every PNG referenced by the existing AppIcon catalog at its specified dimensions. Installed icons are opaque RGB, including the 1024 px marketing icon. Replaced 1×/2×/3× launch images with transparent symbols on a deep emerald launch storyboard. Updated the visible display name to SaveTrack. Bundle identifiers, signing, and catalog configuration remain unchanged. |

## Files

Created:

- `assets/branding/savetrack-symbol.svg`, the icon/light/monochrome/adaptive SVG variants, and their PNG exports.
- `lib/branding/savetrack_logo.dart` and generated `savetrack_logo_painter.dart`.
- `tools/generate_branding.py` and `tools/render_branding.dart`.
- Android `drawable/ic_launcher_foreground.xml`, `ic_launcher_background.xml`, `ic_launcher_monochrome.xml`, and `savetrack_splash.xml`.
- Android `mipmap-anydpi-v26/ic_launcher.xml`, `mipmap-anydpi-v33/ic_launcher.xml`, `values/branding_colors.xml`, and API 31 day/night splash themes.
- `web/icons/apple-touch-icon.png` and `test/branding_test.dart`.
- This implementation report. Generated review images live under ignored `build/branding-review/`.

Modified:

- `lib/design_system.dart` and the branding-only lines in `lib/main.dart`.
- Both existing Android `launch_background.xml` files and all five legacy launcher PNGs.
- Existing iOS icon/launch PNGs, `LaunchScreen.storyboard`, and the visible display-name entry in `Info.plist`.
- Existing web favicon/icon PNGs, `web/index.html`, and `web/manifest.json`.
- `assets/branding/README.md`.

## Verification

| Command/check | Actual result |
| --- | --- |
| `flutter pub get` | Passed. Dependency manifests and lockfile unchanged. |
| `py tools/generate_branding.py` | Passed; all SVG/vector/PNG assets generated. Its Flutter export utility completed successfully. |
| `dart format lib/branding/savetrack_logo.dart lib/design_system.dart lib/main.dart tools/render_branding.dart test/branding_test.dart` | Files formatted; generated painter is also formatted by the generator. |
| `flutter analyze` | Passed: no issues found. |
| `flutter test --reporter expanded` | Passed: **427 tests**. Final run logged in `.buildlog/branding-tests-final.log`. |
| `flutter test test/branding_test.dart --reporter expanded` | Passed: all 4 branding checks, covering adaptive circular safe area, separate monochrome coin/pig, iOS/web dimensions and opacity, and static reduced-motion rendering at 24–192 px. |
| `flutter test test/redesign_test.dart --dart-define=SAVE_UI_PREVIEWS=true --plain-name 'login preview' --reporter expanded` | Passed: mobile login screenshot captured with bundled fonts. |
| `flutter test test/redesign_test.dart --dart-define=SAVE_UI_PREVIEWS=true --name 'wide authentication\|session loading\|premium screen' --reporter expanded` | Passed: 3 existing preview tests. Captured wide login/registration, session loading, dashboard, planner, reports, profile, and existing modal previews. |
| `py tools/verify_ui_preservation.py` | Passed: 149 callbacks/validators, 60 query expressions, 37 financial/auth/operation methods, 37 enabled/dismissal bindings, and 27 non-presentation Dart files unchanged from HEAD. |
| `flutter build apk --debug` | Passed with the final vectors and PNGs. Output: `build/app/outputs/flutter-apk/app-debug.apk`. |
| `flutter build web` | Passed with the final painter and web assets. Output: `build/web/`. Flutter emitted informational Wasm dry-run and font tree-shaking messages. |
| APK ZIP and `aapt2 dump xmltree` inspection | Confirmed five legacy density icons, API 26/33 adaptive resources, foreground/background/monochrome vectors, and splash vector are present in the APK. The compiled API 33 icon contains all three adaptive layers. |
| Built web assets | Every web icon and `manifest.json` in `build/web/` matches its final source file byte for byte. |
| `flutter emulators` | No emulators available. |
| `git diff --check` | Passed. |

Visual review covered light/dark surfaces, monochrome, circle, rounded square, squircle and diamond masks, actual small-size exports, the packaged legacy Android icon, login, registration, session loading, dashboard and profile. No critical logo parts are cropped. Review sheet: `build/branding-review/contact-sheet.png`; screen captures: `build/ui-preview/`.

`firestore.rules`, `storage.rules`, Firebase configuration, authentication services, savings calculations, planner logic, profile-photo handling, and goal-cover handling were not edited. No application data operations or live Firebase acceptance tests were performed as part of this branding change.

## Remaining platform verification

This Windows environment does not provide Xcode/iOS simulator tooling. iOS catalog dimensions, opacity, and launch storyboard references can be checked locally, but an iOS build and device render remain unverified.

No Android device was connected, and `flutter emulators` reported that none are available. A successful APK build and resource inspection do not establish that an installed home-screen icon changed. Reinstall on a test device and check its launcher, native splash, recent-apps view, and themed icons. Some launchers cache installed icons.

Browser favicon/PWA cache refresh and installed-PWA appearance must be verified in the browser/device used for deployment. Updating generated resources does not force an already installed browser icon cache to refresh.

Android implementation references: [adaptive icon layers and safe area](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive), [native splash sizes and theme attributes](https://developer.android.com/develop/ui/views/launch/splash-screen).
