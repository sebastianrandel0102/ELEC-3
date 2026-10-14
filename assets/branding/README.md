SaveTrack branding:

- `savetrack-symbol.svg`: original 1024 × 1024 vector master. Edit this file to change the piggy bank geometry.
- `savetrack-icon.svg` / `.png`: opaque emerald gradient launcher artwork.
- `savetrack-symbol.png`: transparent mint symbol, also used to export the native splash images.
- `savetrack-light.svg` / `.png`: emerald pig and gold coin for light surfaces.
- `savetrack-monochrome.svg` / `.png`: one-color pig and a separate ring-shaped coin.
- `savetrack-adaptive-foreground.svg` / `.png`: transparent foreground within the Android safe area.

Regenerate all variants, Flutter vector drawing code, Android resources, iOS icons/splash images, and web icons with `py tools/generate_branding.py` from the repository root. Python standard library and the project's existing Flutter/image tooling are sufficient; no new packages are needed. The in-app logo uses compiled vector drawing code, so these export PNGs do not add image decoding or unused launcher artwork to the Flutter asset bundle.

See [implementation and verification details](../../docs/BRANDING.md).

Google branding assets used only by the Continue with Google button:

- `google_g.png`: downloaded unchanged from Google's current branding guidelines at https://developers.google.com/static/identity/images/g-logo.png.
- `GoogleSans.ttf`: Google Sans Medium, subset to the button's English label using Google's Fonts API: https://fonts.googleapis.com/css2?family=Google+Sans:wght@500&text=Continue%20with%20Google. The API returned a TrueType font hosted by fonts.gstatic.com. Other characters require regenerating the subset if the label is localized.
- `GoogleSans-OFL.txt`: font license downloaded from https://github.com/google/fonts/blob/main/ofl/googlesans/OFL.txt.

The logo keeps its original colors and aspect ratio on a white button. The label uses Google Sans at weight 500. Button guidance: https://developers.google.com/identity/branding-guidelines.
