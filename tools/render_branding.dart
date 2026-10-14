// Raster export step for generate_branding.py; uses the actual Flutter renderer.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:myproject/branding/savetrack_logo_painter.dart';

const _background = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF073F34), Color(0xFF13876D)],
);

Future<img.Image> render(
  int pixels, {
  bool background = false,
  bool light = false,
  bool monochrome = false,
  double scale = 1,
}) async {
  // Supersample each export independently from the vector. Never enlarge a PNG.
  final resolution = pixels < 512 ? pixels * 4 : pixels * 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size.square(resolution.toDouble());
  if (background) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = _background.createShader(rect));
  }
  SaveTrackLogoPainter(
    light: light,
    monochrome: monochrome,
    artworkScale: scale,
  ).paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(resolution, resolution);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final decoded = img.decodePng(bytes!.buffer.asUint8List())!;
  image.dispose();
  picture.dispose();
  final result = img.copyResize(
    decoded,
    width: pixels,
    height: pixels,
    interpolation: img.Interpolation.average,
  );
  // Apple installed icons and opaque web/legacy icons have no alpha channel.
  return background ? result.convert(numChannels: 3) : result;
}

Future<void> save(String path, img.Image image) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export all SaveTrack platform branding from vector geometry', () async {
    for (final entry in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      await save(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        await render(entry.value, background: true),
      );
    }
    final catalog = jsonDecode(
      await File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json')
          .readAsString(),
    ) as Map<String, dynamic>;
    for (final entry
        in (catalog['images'] as List).cast<Map<String, dynamic>>()) {
      final points = double.parse((entry['size'] as String).split('x').first);
      final scale = double.parse(
        (entry['scale'] as String).replaceAll('x', ''),
      );
      await save(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry['filename']}',
        await render((points * scale).round(), background: true),
      );
    }
    for (final density in [1, 2, 3]) {
      final suffix = density == 1 ? '' : '@${density}x';
      await save(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
        await render(160 * density),
      );
    }
    for (final pixels in [192, 512]) {
      await save(
        'web/icons/Icon-$pixels.png',
        await render(pixels, background: true),
      );
      await save(
        'web/icons/Icon-maskable-$pixels.png',
        await render(pixels, background: true),
      );
    }
    await save(
      'web/favicon.png',
      await render(32, background: true, scale: 1.15),
    );
    await save(
      'web/icons/apple-touch-icon.png',
      await render(180, background: true),
    );
    await save(
      'assets/branding/savetrack-icon.png',
      await render(1024, background: true),
    );
    await save('assets/branding/savetrack-symbol.png', await render(512));
    await save(
      'assets/branding/savetrack-light.png',
      await render(512, light: true),
    );
    await save(
      'assets/branding/savetrack-monochrome.png',
      await render(512, monochrome: true),
    );
    await save(
      'assets/branding/savetrack-adaptive-foreground.png',
      await render(1024, scale: .84),
    );

    // Review sheet: backgrounds, launcher masks, actual small-size exports.
    final sheet = img.Image(width: 1400, height: 1060, numChannels: 3);
    img.fill(sheet, color: img.ColorRgb8(246, 251, 248));
    img.drawString(
      sheet,
      'SaveTrack | Simple mint piggy bank',
      font: img.arial48,
      x: 36,
      y: 28,
      color: img.ColorRgb8(7, 63, 52),
    );
    img.drawString(
      sheet,
      'One coin. One slot. Shared vector geometry.',
      font: img.arial24,
      x: 36,
      y: 91,
      color: img.ColorRgb8(82, 110, 97),
    );
    final primary = await render(260, background: true);
    img.compositeImage(sheet, primary, dstX: 36, dstY: 140);
    final light = await render(260, light: true);
    img.compositeImage(sheet, light, dstX: 335, dstY: 140);
    img.fillRect(
      sheet,
      x1: 635,
      y1: 140,
      x2: 894,
      y2: 399,
      color: img.ColorRgb8(7, 63, 52),
    );
    img.compositeImage(sheet, await render(260), dstX: 635, dstY: 140);
    img.compositeImage(
      sheet,
      await render(260, monochrome: true),
      dstX: 934,
      dstY: 140,
    );
    for (final entry in {
      36: 'Launcher',
      335: 'Light surface',
      635: 'Dark surface',
      934: 'Monochrome',
    }.entries) {
      img.drawString(
        sheet,
        entry.value,
        font: img.arial24,
        x: entry.key,
        y: 415,
        color: img.ColorRgb8(7, 63, 52),
      );
    }
    final layer = await render(300, background: true, scale: .84);
    // A launcher displays the center 72/108 of its full adaptive canvas.
    final viewport = img.copyCrop(layer, x: 50, y: 50, width: 200, height: 200);
    for (var shape = 0; shape < 4; shape++) {
      final icon = viewport.convert(numChannels: 4);
      for (final p in icon) {
        final dx = (p.x + .5 - 100).abs(), dy = (p.y + .5 - 100).abs();
        final outside = switch (shape) {
          0 => dx * dx + dy * dy > 10000,
          1 =>
            dx > 60 &&
                dy > 60 &&
                (dx - 60) * (dx - 60) + (dy - 60) * (dy - 60) > 1600,
          2 =>
            (dx / 100) * (dx / 100) * (dx / 100) * (dx / 100) +
                    (dy / 100) * (dy / 100) * (dy / 100) * (dy / 100) >
                1,
          _ => dx + dy > 135,
        };
        if (outside) p.a = 0;
      }
      final x = 36 + shape * 300;
      img.compositeImage(sheet, icon, dstX: x, dstY: 485);
      img.drawString(
        sheet,
        ['Circle', 'Rounded square', 'Squircle', 'Diamond'][shape],
        font: img.arial24,
        x: x,
        y: 705,
        color: img.ColorRgb8(7, 63, 52),
      );
    }
    var x = 36;
    for (final pixels in [24, 32, 48, 64, 96, 192]) {
      await save(
        'build/branding-review/size-$pixels.png',
        await render(pixels, background: true),
      );
      img.compositeImage(
        sheet,
        await render(pixels, background: true),
        dstX: x,
        dstY: 770 + 192 - pixels,
      );
      img.drawString(
        sheet,
        '${pixels}px',
        font: img.arial14,
        x: x,
        y: 982,
        color: img.ColorRgb8(7, 63, 52),
      );
      x += pixels + 50;
    }
    await save('build/branding-review/contact-sheet.png', sheet);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
