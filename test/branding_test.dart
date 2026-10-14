import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:myproject/branding/savetrack_logo.dart';
import 'package:myproject/branding/savetrack_logo_painter.dart';

void main() {
  test('adaptive artwork stays inside the Android circular safe area', () {
    final foreground = img.decodePng(
      File('assets/branding/savetrack-adaptive-foreground.png')
          .readAsBytesSync(),
    )!;
    expect(foreground.width, 1024);
    expect(foreground.height, 1024);
    expect(foreground.getPixel(0, 0).a, 0);
    final safeRadius = foreground.width * 66 / 108 / 2;
    for (final pixel in foreground) {
      if (pixel.a < 16) continue;
      final dx = pixel.x + .5 - 512, dy = pixel.y + .5 - 512;
      expect(math.sqrt(dx * dx + dy * dy), lessThan(safeRadius));
    }
    final adaptive = File(
      'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
    ).readAsStringSync();
    for (final layer in ['foreground', 'background', 'monochrome']) {
      expect(
        adaptive,
        contains('<$layer android:drawable="@drawable/ic_launcher_$layer"'),
      );
      expect(
        File('android/app/src/main/res/drawable/ic_launcher_$layer.xml')
            .existsSync(),
        isTrue,
      );
    }
  });

  test('monochrome export keeps one separate coin and one connected pig', () {
    final image = img.decodePng(
      File('assets/branding/savetrack-monochrome.png').readAsBytesSync(),
    )!;
    final remaining = <int>{};
    for (final pixel in image) {
      if (pixel.a >= 128) remaining.add(pixel.y * image.width + pixel.x);
    }
    var components = 0;
    while (remaining.isNotEmpty) {
      components++;
      final queue = <int>[remaining.first];
      remaining.remove(queue.first);
      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        final x = current % image.width, y = current ~/ image.width;
        for (final (dx, dy) in [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= image.width || ny >= image.height) {
            continue;
          }
          final next = ny * image.width + nx;
          if (remaining.remove(next)) queue.add(next);
        }
      }
    }
    expect(components, 2);
    // The coin's central negative space remains visible without gold coloring.
    expect(image.getPixel(256, 111).a, 0);
  });

  test(
    'installed iOS and web icons have correct sizes and opaque backgrounds',
    () {
      const catalog = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/';
      final contents = jsonDecode(
        File('${catalog}Contents.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final entry
          in (contents['images'] as List).cast<Map<String, dynamic>>()) {
        final points = double.parse((entry['size'] as String).split('x').first);
        final scale = double.parse(
          (entry['scale'] as String).replaceAll('x', ''),
        );
        final image = img.decodePng(
          File('$catalog${entry['filename']}').readAsBytesSync(),
        )!;
        expect(image.width, (points * scale).round());
        expect(image.height, image.width);
        expect(
          image.numChannels,
          3,
          reason: 'iOS icons must not contain an alpha channel',
        );
      }
      final manifest = jsonDecode(
        File('web/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(manifest['name'], 'SaveTrack');
      for (final entry
          in (manifest['icons'] as List).cast<Map<String, dynamic>>()) {
        final image = img.decodePng(
          File('web/${entry['src']}').readAsBytesSync(),
        )!;
        expect('${image.width}x${image.height}', entry['sizes']);
        expect(image.numChannels, 3);
      }
      final favicon = img.decodePng(File('web/favicon.png').readAsBytesSync())!;
      expect(favicon.width, 32);
      expect(favicon.height, 32);
    },
  );

  testWidgets(
    'reduced motion preserves the static logo at supported sizes',
    (tester) async {
      for (final size in [24.0, 32.0, 48.0, 64.0, 96.0, 192.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Center(
                child: SaveTrackLogo(size: size, onDark: true, animate: true),
              ),
            ),
          ),
        );
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(SaveTrackLogo),
            matching: find.byType(CustomPaint),
          ),
        );
        expect((paint.painter! as SaveTrackLogoPainter).coinProgress, 0);
        expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
