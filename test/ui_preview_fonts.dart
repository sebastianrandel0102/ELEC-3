import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';

Future<void> loadAiMathFontsForPreviews() async {
  if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final name = family['family'] as String;
    if (!name.startsWith('packages/flutter_math_fork/')) continue;
    final loader = FontLoader(name);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Review captures use the same bundled typeface as the production app.
Future<void> loadManropeForPreviews() async {
  if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
  final loader = FontLoader('Manrope')
    ..addFont(
      File('assets/fonts/Manrope.ttf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)),
    );
  await loader.load();
  final config = jsonDecode(
    await File('.dart_tool/package_config.json').readAsString(),
  ) as Map<String, dynamic>;
  final flutter = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == 'flutter');
  final sdk = Uri.parse('${flutter['rootUri']}/').resolve('../../');
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File.fromUri(
        sdk.resolve(
          'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ),
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  await icons.load();
}
