import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/firebase_options.dart';

void main() {
  test('Android Firebase config supplies the native Google server client', () {
    final config = jsonDecode(
      File('android/app/google-services.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final options = DefaultFirebaseOptions.android;
    expect(config['project_info']['project_id'], options.projectId);
    expect(config['project_info']['project_number'], options.messagingSenderId);

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final packageName = RegExp(r'applicationId\s*=\s*"([^"]+)"')
        .firstMatch(gradle)!
        .group(1);
    final client = (config['client'] as List).singleWhere(
      (entry) =>
          entry['client_info']['android_client_info']['package_name'] ==
          packageName,
    );
    expect(client['client_info']['mobilesdk_app_id'], options.appId);
    expect(
      (client['api_key'] as List).map((key) => key['current_key']),
      contains(options.apiKey),
    );

    // Dart service doubles cannot catch a missing native serverClientId.
    // Gradle generates default_web_client_id only from a type-3 OAuth entry.
    final webClients = (client['oauth_client'] as List).where(
      (oauth) => oauth['client_type'] == 3,
    );
    expect(
      webClients,
      isNotEmpty,
      reason:
          'Download Google-enabled google-services.json before shipping APKs.',
    );
    for (final oauth in webClients) {
      expect(
        oauth['client_id'],
        matches(
          '^${options.messagingSenderId}-[a-z0-9]+'
          r'\.apps\.googleusercontent\.com$',
        ),
      );
    }
    expect(gradle, contains('id("com.google.gms.google-services")'));
  });
}
