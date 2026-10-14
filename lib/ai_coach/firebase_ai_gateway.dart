import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'ai_domain.dart';
import 'ai_gateway.dart';
import 'ai_app_check.dart';
export 'ai_app_check.dart' show AiAppCheck;

class FirebaseAiGateway implements AiGateway, AiGatewayPreflight {
  final _models = <AiMode, GenerativeModel>{};

  @override
  Future<void> prepare({bool forceRefresh = false}) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw const AiFailure(
        AiErrorKind.authentication,
        'Sign in again to use SaveTrack AI.',
      );
    }
    await AiAppCheck.verify(forceRefresh: forceRefresh);
  }

  @override
  Stream<String> generate(AiRequest request) async* {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const AiFailure(
        AiErrorKind.authentication,
        'Sign in again to use SaveTrack AI.',
      );
    }
    await prepare();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw const AiFailure(
        AiErrorKind.authentication,
        'Your account session changed.',
      );
    }
    final model = _models.putIfAbsent(
      request.mode,
      () =>
          FirebaseAI.googleAI(useLimitedUseAppCheckTokens: true)
              .generativeModel(
                model: AiConfig.model,
                systemInstruction: Content.system(request.systemInstruction),
                generationConfig: GenerationConfig(
                  maxOutputTokens: AiConfig.maxOutputTokens,
                ),
              ),
    );
    final contents = aiProviderContents(request);
    try {
      await for (final response in model.generateContentStream(contents)) {
        if (response.promptFeedback?.blockReason != null) {
          throw const AiFailure(
            AiErrorKind.blocked,
            'The model could not answer this request. Try rephrasing your question.',
          );
        }
        final value = response.text;
        if (value != null && value.isNotEmpty) yield value;
      }
    } catch (error) {
      throw mapAiError(error);
    }
  }
}

/// The same serialized content seam is inspected by cross-mode security tests.
List<Content> aiProviderContents(AiRequest request) => [
  for (final message in request.history)
    Content(message.role == AiRole.user ? 'user' : 'model', [
      TextPart(message.text),
    ]),
  Content.text(request.providerQuestion),
];

AiFailure mapAiError(Object error) {
  if (error is AiFailure) return error;
  if (error is QuotaExceeded ||
      (error is FirebaseException && error.code == 'resource-exhausted')) {
    return const AiFailure(
      AiErrorKind.quota,
      'AI usage limit reached. Please try again later.',
    );
  }
  if (error is InvalidApiKey || error is ServiceApiNotEnabled) {
    return const AiFailure(
      AiErrorKind.configuration,
      'Enable Firebase AI Logic with the Gemini Developer API in the Firebase Console.',
    );
  }
  if (error is TimeoutException ||
      error is http.ClientException ||
      (error is FirebaseException &&
          [
            'unavailable',
            'network-request-failed',
            'deadline-exceeded',
          ].contains(error.code))) {
    return const AiFailure(
      AiErrorKind.offline,
      'AI could not connect. Check your connection, then retry.',
    );
  }
  if (error is FirebaseException &&
      ['unauthenticated', 'permission-denied'].contains(error.code)) {
    return const AiFailure(
      AiErrorKind.authentication,
      'Your access could not be verified. Sign in and check App Check configuration.',
    );
  }
  // SDK currently exposes some HTTP failures only as text. Inspect locally;
  // never show the raw error (which can contain provider/request details).
  final description = error.toString().toLowerCase();
  if (description.contains('429') ||
      description.contains('resource_exhausted')) {
    return const AiFailure(
      AiErrorKind.quota,
      'AI usage limit reached. Please try again later.',
    );
  }
  if (description.contains('app check') ||
      description.contains('appcheck') ||
      description.contains('403')) {
    return const AiFailure(
      AiErrorKind.configuration,
      'AI access was rejected. Check Firebase AI Logic and App Check setup.',
    );
  }
  return const AiFailure(
    AiErrorKind.unavailable,
    'AI is unavailable right now. Check model access or try again later.',
  );
}
