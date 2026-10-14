import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/ai_coach/ai_app_check.dart';
import 'package:myproject/ai_coach/ai_controller.dart';
import 'package:myproject/ai_coach/ai_domain.dart';

import 'ai_coach_fixtures.dart';

void main() {
  AiProtectionProvider web(String url, {bool debug = true, String key = ''}) =>
      aiProtectionProvider(
        web: true,
        debug: debug,
        platform: TargetPlatform.windows,
        origin: Uri.parse(url),
        siteKey: key,
      );
  test('local debug web uses official debug provider without a site key', () {
    for (final url in [
      'http://localhost:8080',
      'http://127.0.0.1:5000',
      'http://[::1]:8080',
    ]) {
      expect(web(url), AiProtectionProvider.webDebug);
    }
  });
  test('release/profile builds never choose debug even on localhost', () {
    expect(
      web('http://localhost:8080', debug: false),
      AiProtectionProvider.missingWebKey,
    );
    expect(
      web('http://localhost:8080', debug: false, key: 'public-site-key'),
      AiProtectionProvider.webRecaptcha,
    );
  });
  test('published origins require reCAPTCHA even for a debug build', () {
    for (final url in [
      'https://example.com',
      'https://localhost.evil.example',
      'https://localhost@evil.example',
    ]) {
      expect(web(url), AiProtectionProvider.missingWebKey);
      expect(
        web(url, key: 'public-site-key'),
        AiProtectionProvider.webRecaptcha,
      );
    }
  });
  test('Android and Apple production attestation preserved', () {
    expect(
      aiProtectionProvider(
        web: false,
        debug: false,
        platform: TargetPlatform.android,
        origin: Uri(),
        siteKey: '',
      ),
      AiProtectionProvider.androidIntegrity,
    );
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      expect(
        aiProtectionProvider(
          web: false,
          debug: false,
          platform: platform,
          origin: Uri(),
          siteKey: '',
        ),
        AiProtectionProvider.appleAttest,
      );
    }
    expect(
      aiProtectionProvider(
        web: false,
        debug: true,
        platform: TargetPlatform.android,
        origin: Uri(),
        siteKey: '',
      ),
      AiProtectionProvider.androidDebug,
    );
  });
  test('unsupported native targets fail closed', () {
    expect(
      aiProtectionProvider(
        web: false,
        debug: true,
        platform: TargetPlatform.windows,
        origin: Uri(),
        siteKey: '',
      ),
      AiProtectionProvider.unsupported,
    );
  });
  test(
    'public key input rejects blanks and arbitrary pasted configuration',
    () {
      expect(isAiSiteKey('6Lc${'a' * 37}'), true);
      for (final value in [
        '',
        '  ',
        'https://example.com/key',
        '{"apiKey":"something"}',
        'a' * 201,
      ]) {
        expect(isAiSiteKey(value), false);
      }
    },
  );
  test(
    'missing App Check prevents empty chat turns and model requests',
    () async {
      final gateway = PreflightAiGateway()
        ..preparationError = const AiFailure(
          AiErrorKind.configuration,
          'Register this browser in App Check.',
        );
      final controller = AiCoachController(
        gateway: gateway,
        currentUid: () => 'private-uid',
      )..acknowledgeProvider();
      await controller.send('Explain photosynthesis.');
      expect(controller.active.messages, isEmpty);
      expect(gateway.requests, isEmpty);
      expect(controller.active.failure!.kind, AiErrorKind.configuration);
      expect(controller.busy, false);
      gateway.preparationError = null;
      await controller.checkConnection();
      expect(gateway.checks.last, true);
      controller.clearFailure();
      await controller.send('Explain photosynthesis.');
      expect(gateway.requests.length, 1);
      expect(controller.active.messages.length, 2);
      expect(controller.active.messages.last.status, AiMessageStatus.complete);
      controller.dispose();
    },
  );
  test(
    'switching modes during protection check cannot send a stale request',
    () async {
      final gateway = PreflightAiGateway()..preparing = Completer<void>();
      final source = FakeAiContextSource();
      final controller = AiCoachController(
        gateway: gateway,
        contextSource: source,
        currentUid: () => 'private-uid',
      )..acknowledgeProvider();
      final pending = controller.send('A question');
      controller.switchMode(AiMode.coach);
      gateway.preparing!.complete();
      await pending;
      expect(gateway.requests, isEmpty);
      expect(controller.active.messages, isEmpty);
      expect(source.reads, 0);
      controller.dispose();
    },
  );
}
