import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_ai_gateway.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_planner.dart';
import 'package:myproject/agent_studio/agent_voice.dart';
import 'package:myproject/agent_studio/intelligence/agent_language.dart';

import 'agent_studio_fixtures.dart';

class LanguageVoice extends FakeAgentVoice {
  LanguageVoice({this.defaultLocale = 'en-US'});
  final String defaultLocale;
  final spokenLocales = <String>[];
  @override
  Future<Map<String, dynamic>> capabilities() async => {
    ...await super.capabilities(),
    'ttsLanguages': ['en-US', 'fil-PH'],
    'ttsDefaultLocale': defaultLocale,
    'voiceDetails': [
      {'name': 'filipino-voice', 'locale': 'fil-PH', 'network': false},
    ],
  };
  @override
  Future<void> speak({
    required String session,
    required String text,
    required String locale,
    required String voice,
    required double rate,
  }) async {
    spokenLocales.add(locale);
    await super.speak(
      session: session,
      text: text,
      locale: locale,
      voice: voice,
      rate: rate,
    );
  }
}

void main() {
  final planner = LocalAgentPlanner();
  test('conditional goal stays draft-only across correction and serialization', () async {
    final engine = testEngine();
    await enableAgent(engine);
    final plan = planner.plan(
      'Create a goal for laptop target PHP 500 by 2027-01-31 if I get a bonus',
      now: agentNow,
    );
    expect(plan.interpretation!.slots['conditional'], true);
    await engine.applyPlan(plan);
    expect(engine.mission!.planOnly, true);
    expect(await engine.review(), isNotEmpty);
    final snapshot = engine.mission!.snapshot;
    await engine.applyPlan(
      planner.plan(
        'Actually 300 lang pala',
        mission: engine.mission,
        previous: engine.activeInterpretation,
        now: agentNow,
      ),
    );
    expect((engine.mission!.steps.single.action as GoalDraft).amount, '300');
    expect(engine.mission!.planOnly, true);
    expect(engine.mission!.snapshot, isNot(snapshot));
    final restored = AgentMission.fromJson(
      jsonDecode(jsonEncode(engine.mission!.toJson())),
    );
    expect(restored.planOnly, true);
    expect((engine.backend as FakeAgentBackend).calls, isEmpty);
    engine.dispose();
  });
  test('conditional words inside a proper name do not create a condition', () {
    final plan = planner.plan(
      'Create a goal called "If I Travel" target PHP 500 by 2027-01-31',
      now: agentNow,
    );
    expect((plan.actions.single as GoalDraft).name, 'If I Travel');
    expect(plan.interpretation!.draftOnly, false);
  });
  test('conditional read-only scenarios do not acquire an execution block', () {
    final plan = planner.plan(
      'Simulate PHP 1000 target with PHP 100 weekly if I get a bonus',
      now: agentNow,
    );
    expect(plan.actions.single, isA<ScenarioDraft>());
    expect(plan.interpretation!.draftOnly, false);
  });
  test('automatic guidance uses only the detected language enum; explicit language wins', () {
    for (final language in [
      AgentLanguage.english,
      AgentLanguage.filipino,
      AgentLanguage.taglish,
    ]) {
      final automatic = AgentSafeRequest(
        [AgentActionType.createGoal],
        AgentLanguage.automatic,
        detectedLanguage: language,
      );
      expect(jsonDecode(automatic.payload)['language'], language.name);
      expect(
        jsonDecode(automatic.payload).keys,
        unorderedEquals(['actionTypes', 'language']),
      );
      final explicit = AgentSafeRequest(
        [AgentActionType.createGoal],
        AgentLanguage.english,
        detectedLanguage: language,
      );
      expect(explicit.language, AgentLanguage.english);
    }
  });
  test('Filipino spoken privacy notice follows TTS locale independently of written preference', () async {
    final adapter = LanguageVoice(),
        voice = AgentVoiceController(LanguageVoice());
    voice.dispose();
    final controller = AgentVoiceController(adapter);
    await controller.initialize();
    await controller.speak(
      'Private PHP 999 Laptop Fund',
      AgentSettings(
        spoken: true,
        language: AgentLanguage.english,
        ttsLocale: 'fil-PH',
        locale: 'en-PH',
      ),
    );
    expect(
      adapter.spoken.single,
      const AgentStrings(AgentLanguage.filipino).privateSpokenNotice,
    );
    expect(adapter.spoken.single, isNot(contains('999')));
    expect(adapter.spoken.single, isNot(contains('Laptop')));
    expect(adapter.spokenLocales.single, 'fil-PH');
    controller.dispose();
  });
  test('English spoken privacy notice stays English with Filipino written preference', () async {
    final adapter = LanguageVoice(),
        controller = AgentVoiceController(LanguageVoice());
    controller.dispose();
    final voice = AgentVoiceController(adapter);
    await voice.initialize();
    await voice.speak(
      'Pribadong sagot',
      AgentSettings(
        spoken: true,
        language: AgentLanguage.filipino,
        ttsLocale: 'en-US',
      ),
    );
    expect(
      adapter.spoken.single,
      const AgentStrings(AgentLanguage.english).privateSpokenNotice,
    );
    voice.dispose();
  });
  test('default TTS and explicit Filipino voice metadata select a matching private notice', () async {
    for (final explicitVoice in [false, true]) {
      final adapter = LanguageVoice(
        defaultLocale: explicitVoice ? 'en-US' : 'fil-PH',
      );
      final voice = AgentVoiceController(adapter);
      await voice.initialize();
      await voice.speak(
        'PHP 999',
        AgentSettings(
          spoken: true,
          voice: explicitVoice ? 'filipino-voice' : '',
        ),
      );
      expect(
        adapter.spoken.single,
        const AgentStrings(AgentLanguage.filipino).privateSpokenNotice,
      );
      expect(adapter.spokenLocales.single, isEmpty);
      voice.dispose();
    }
  });
}
