import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../ai_coach/ai_domain.dart';
import '../ai_coach/firebase_ai_gateway.dart';
import 'agent_domain.dart';

/// The provider request cannot carry free-form user input, record values, IDs,
/// dates, financial amounts, chat history, transcripts, or preference memory.
class AgentSafeRequest {
  AgentSafeRequest(Iterable<AgentActionType> actions, this.language)
    : actions = Set.unmodifiable(actions);
  final Set<AgentActionType> actions;
  final AgentLanguage language;
  String get payload => jsonEncode({
    'actionTypes': actions.map((a) => a.name).toList()..sort(),
    'language': language.name,
  });
}

class AgentAiAdvice {
  AgentAiAdvice(this.explanation, List<AgentActionType> order)
    : order = List.unmodifiable(order);
  final String explanation;
  final List<AgentActionType> order;
  factory AgentAiAdvice.parse(String text, AgentSafeRequest request) {
    if (text.length > 12000) {
      throw const AgentFailure(
        'AI response too large. Keep using local planning.',
      );
    }
    try {
      final m = jsonDecode(text) as Map<String, dynamic>;
      if (m.keys.toSet().difference({'explanation', 'order'}).isNotEmpty ||
          m.length != 2) {
        throw const FormatException();
      }
      final explanation = m['explanation'] as String;
      final order = (m['order'] as List)
          .map((s) => AgentActionType.values.byName(s as String))
          .toList();
      if (explanation.isEmpty ||
          explanation.length > 2500 ||
          order.length > AgentLimits.steps ||
          order.toSet().length != order.length ||
          order.any((a) => !request.actions.contains(a))) {
        throw const FormatException();
      }
      return AgentAiAdvice(explanation, order);
    } catch (_) {
      throw const AgentFailure(
        'AI returned an invalid proposal. Your local mission is unchanged.',
      );
    }
  }
}

abstract interface class AgentAiGateway {
  Future<AgentAiAdvice> advise(AgentSafeRequest request);
}

class FirebaseAgentAiGateway implements AgentAiGateway {
  @override
  Future<AgentAiAdvice> advise(AgentSafeRequest request) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const AgentFailure('Sign in again to use optional AI guidance.');
    }
    try {
      await AiAppCheck.verify();
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw const AgentFailure('Your account changed.');
      }
      final model = FirebaseAI.googleAI(useLimitedUseAppCheckTokens: true)
          .generativeModel(
            model: AiConfig.model,
            systemInstruction: Content.system(
              'You advise on an abstract SaveTrack workflow. You have no records, money values, dates, names, or authorization. Explain a useful order and what details to review. Do not claim any action has executed. Only return the supplied action types. You cannot approve, execute, or request tools. Reply in the specified language. No numeric financial advice.',
            ),
            generationConfig: GenerationConfig(
              maxOutputTokens: 1024,
              responseMimeType: 'application/json',
              responseSchema: Schema.object(
                properties: {
                  'explanation': Schema.string(),
                  'order': Schema.array(
                    items: Schema.enumString(
                      enumValues: request.actions.map((a) => a.name).toList(),
                    ),
                    maxItems: AgentLimits.steps,
                  ),
                },
              ),
            ),
          );
      final response = await model
          .generateContent([Content.text(request.payload)])
          .timeout(AgentLimits.requestTimeout);
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw const AgentFailure('Your account changed.');
      }
      return AgentAiAdvice.parse(response.text ?? '', request);
    } catch (e) {
      if (e is AgentFailure) rethrow;
      throw AgentFailure(
        '${mapAiError(e).message} Local planning remains available.',
      );
    }
  }
}
