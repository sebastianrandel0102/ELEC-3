import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_domain.dart';
import '../firebase_options.dart';

enum AiProtectionProvider {
  webDebug,
  webRecaptcha,
  androidDebug,
  androidIntegrity,
  appleDebug,
  appleAttest,
  missingWebKey,
  unsupported,
}

/// Development attestation is restricted to a debug build on a loopback host.
/// A release/profile build never substitutes a debug provider for reCAPTCHA.
AiProtectionProvider aiProtectionProvider({
  required bool web,
  required bool debug,
  required TargetPlatform platform,
  required Uri origin,
  required String siteKey,
}) {
  if (web) {
    if (debug &&
        [
          'localhost',
          '127.0.0.1',
          '::1',
          '[::1]',
        ].contains(origin.host.toLowerCase())) {
      return AiProtectionProvider.webDebug;
    }
    return siteKey.trim().isEmpty
        ? AiProtectionProvider.missingWebKey
        : AiProtectionProvider.webRecaptcha;
  }
  return switch (platform) {
    TargetPlatform.android =>
      debug
          ? AiProtectionProvider.androidDebug
          : AiProtectionProvider.androidIntegrity,
    TargetPlatform.iOS || TargetPlatform.macOS =>
      debug
          ? AiProtectionProvider.appleDebug
          : AiProtectionProvider.appleAttest,
    _ => AiProtectionProvider.unsupported,
  };
}

bool isAiSiteKey(String value) =>
    RegExp(r'^[A-Za-z0-9_-]{20,200}$').hasMatch(value.trim());

/// App Check failure stays within AI. Only the public reCAPTCHA site key is
/// persisted; no debug tokens, provider credentials, prompts or user context.
abstract final class AiAppCheck {
  static bool ready = false;
  static AiProtectionProvider provider = AiProtectionProvider.unsupported;
  static AiFailure? failure;
  static Future<void>? _initializing;
  static const _buildSiteKey = String.fromEnvironment(
    'SAVETRACK_RECAPTCHA_SITE_KEY',
  );
  static String _siteKeyPreference() =>
      'savetrack.ai.recaptcha.${Firebase.app().options.appId}';
  static String get projectId =>
      DefaultFirebaseOptions.currentPlatform.projectId;
  static String get appCheckUrl =>
      'https://console.firebase.google.com/project/$projectId/appcheck/apps';
  static String get aiLogicUrl =>
      'https://console.firebase.google.com/project/$projectId/ailogic';

  static Future<void> initialize() {
    if (ready) return Future.value();
    return _initializing ??= _activate().whenComplete(
      () => _initializing = null,
    );
  }

  static Future<void> _activate() async {
    failure = null;
    try {
      var key = _buildSiteKey.trim();
      if (kIsWeb && key.isEmpty) {
        key =
            (await SharedPreferences.getInstance()).getString(
              _siteKeyPreference(),
            ) ??
            '';
      }
      provider = aiProtectionProvider(
        web: kIsWeb,
        debug: kDebugMode,
        platform: defaultTargetPlatform,
        origin: Uri.base,
        siteKey: key,
      );
      switch (provider) {
        case AiProtectionProvider.webDebug:
          // Official SDK provider: generates a browser-local token. Firebase
          // still rejects it until this app's token is registered in Console.
          await FirebaseAppCheck.instance.activate(
            providerWeb: WebDebugProvider(),
          );
        case AiProtectionProvider.webRecaptcha:
          await FirebaseAppCheck.instance.activate(
            providerWeb: ReCaptchaV3Provider(key),
          );
        case AiProtectionProvider.androidDebug:
          await FirebaseAppCheck.instance.activate(
            providerAndroid: const AndroidDebugProvider(),
          );
        case AiProtectionProvider.androidIntegrity:
          await FirebaseAppCheck.instance.activate(
            providerAndroid: const AndroidPlayIntegrityProvider(),
          );
        case AiProtectionProvider.appleDebug:
          await FirebaseAppCheck.instance.activate(
            providerApple: const AppleDebugProvider(),
          );
        case AiProtectionProvider.appleAttest:
          await FirebaseAppCheck.instance.activate(
            providerApple:
                const AppleAppAttestWithDeviceCheckFallbackProvider(),
          );
        case AiProtectionProvider.missingWebKey:
          throw const AiFailure(
            AiErrorKind.configuration,
            'Web AI needs an App Check site key. Open AI setup to connect this browser.',
          );
        case AiProtectionProvider.unsupported:
          throw const AiFailure(
            AiErrorKind.configuration,
            'AI protection is supported on Android, Apple devices and web. Use a supported device.',
          );
      }
      ready = true;
    } catch (error) {
      ready = false;
      failure = error is AiFailure
          ? error
          : const AiFailure(
              AiErrorKind.configuration,
              'AI protection could not start. Open AI setup and check the app registration.',
            );
    }
  }

  static Future<void> saveWebSiteKey(String value) async {
    if (!kIsWeb || !isAiSiteKey(value)) {
      throw const AiFailure(
        AiErrorKind.input,
        'Enter the public reCAPTCHA site key from Firebase App Check.',
      );
    }
    if (ready) {
      throw const AiFailure(
        AiErrorKind.configuration,
        'Protection is already initialized. Reload the app before changing its provider.',
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_siteKeyPreference(), value.trim());
    await initialize();
    if (!ready) throw failure!;
  }

  static Future<void> verify({bool forceRefresh = false}) async {
    // Recover a transient startup failure instead of permanently locking AI.
    await initialize().timeout(const Duration(seconds: 20));
    if (!ready) {
      throw failure ??
          const AiFailure(
            AiErrorKind.configuration,
            'Open AI setup to configure protection.',
          );
    }
    try {
      final token = await FirebaseAppCheck.instance
          .getToken(forceRefresh)
          .timeout(const Duration(seconds: 15));
      if (token == null || token.isEmpty) {
        throw StateError('No attestation token');
      }
    } catch (error) {
      if (error is TimeoutException ||
          error is http.ClientException ||
          (error is FirebaseException &&
              ['network-request-failed', 'unavailable'].contains(error.code))) {
        throw const AiFailure(
          AiErrorKind.offline,
          'Cannot connect to AI protection. Check your connection and retry.',
        );
      }
      final development = [
        AiProtectionProvider.webDebug,
        AiProtectionProvider.androidDebug,
        AiProtectionProvider.appleDebug,
      ].contains(provider);
      throw AiFailure(
        AiErrorKind.configuration,
        development
            ? 'Register this device’s App Check debug token in Firebase, then check the connection in AI setup.'
            : 'Firebase could not verify this app. Open AI setup to check the site key and registered domain.',
      );
    }
  }
}
