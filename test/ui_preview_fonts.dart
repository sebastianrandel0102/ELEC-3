import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';

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
