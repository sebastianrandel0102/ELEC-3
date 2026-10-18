import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_screen.dart';
import 'package:myproject/agent_studio/agent_language_settings.dart';
import 'package:myproject/agent_studio/agent_planner.dart';
import 'package:myproject/agent_studio/agent_voice.dart';
import 'package:myproject/agent_studio/agent_ai_gateway.dart';

import 'agent_studio_fixtures.dart';
import 'redesign_test.dart' as preview;
import 'ui_preview_fonts.dart';

class LanguageAdviceGateway implements AgentAiGateway {
  final requests = <AgentSafeRequest>[];
  @override
  Future<AgentAiAdvice> advise(AgentSafeRequest request) async {
    requests.add(request);
    return AgentAiAdvice(
      'Suriin muna ang mga detalye bago aprubahan.',
      request.actions.toList(),
    );
  }
}

void main() {
  setUpAll(loadManropeForPreviews);
  testWidgets(
    'optional guidance honors Automatic conversation language after consent',
    (tester) async {
      final engine = testEngine();
      await enableAgent(engine);
      await engine.applyPlan(
        LocalAgentPlanner().plan(
          'Gusto ko ng ipon para sa laptop.',
          now: agentNow,
        ),
      );
      expect(engine.settings.language, AgentLanguage.automatic);
      expect(engine.sessionLanguage, AgentLanguage.filipino);
      final voice = AgentVoiceController(FakeAgentVoice()),
          gateway = LanguageAdviceGateway();
      addTearDown(() {
        engine.dispose();
        voice.dispose();
      });
      await preview.mount(
        tester,
        AgentStudioScreen(engine: engine, voice: voice, gateway: gateway),
      );
      await tester.scrollUntilVisible(
        find.text('Optional Gemini planning guidance'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Optional Gemini planning guidance')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Optional Gemini planning guidance'));
      await tester.pumpAndSettle();
      expect(gateway.requests, isEmpty);
      await tester.tap(find.text('Get guidance'));
      await tester.pumpAndSettle();
      expect(gateway.requests.single.language, AgentLanguage.filipino);
      expect(gateway.requests.single.payload, isNot(contains('laptop')));
      expect((engine.backend as FakeAgentBackend).calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetViewInsets();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'Filipino welcome and draft review wrap at large text, dark=$dark',
      (tester) async {
        final engine = testEngine();
        await enableAgent(engine);
        await engine.updateSettings(
          engine.settings.change({
            'interfaceLanguage': 'filipino',
            'language': 'taglish',
          }),
        );
        final voice = AgentVoiceController(FakeAgentVoice());
        addTearDown(() {
          engine.dispose();
          voice.dispose();
        });
        final theme = dark ? ThemeData.dark() : ThemeData.light();
        await preview.mount(
          tester,
          Theme(
            data: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'Manrope'),
            ),
            child: AgentStudioScreen(engine: engine, voice: voice),
          ),
          size: const Size(320, 800),
          scale: 1.7,
        );
        expect(find.text('Ano ang gusto mong gawin?'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await preview.capture(
          tester,
          'agent-language-home-${dark ? 'dark' : 'light'}',
        );
        await engine.applyPlan(
          LocalAgentPlanner().plan(
            'Gawa goal para sa laptop target PHP 500 by 2027-01-31 pero huwag muna i-save',
            now: agentNow,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('agent-enable-review')),
        );
        await tester.pumpAndSettle();
        await preview.capture(
          tester,
          'agent-language-draft-${dark ? 'dark' : 'light'}',
        );
        await tester.tap(find.byKey(const Key('agent-enable-review')));
        await tester.pumpAndSettle();
        expect(engine.mission!.planOnly, false);
        expect((engine.backend as FakeAgentBackend).calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'language selector changes only written response preference and preserves draft',
    (tester) async {
      final engine = testEngine();
      await enableAgent(engine);
      engine.draft([goalDraft()]);
      final snapshot = engine.mission!.snapshot;
      final voice = AgentVoiceController(FakeAgentVoice());
      await voice.initialize();
      addTearDown(() {
        engine.dispose();
        voice.dispose();
      });
      await preview.mount(
        tester,
        AgentLanguageSettingsScreen(engine: engine, voice: voice),
      );
      await tester.tap(find.byKey(const ValueKey('language:automatic')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taglish').last);
      await tester.pumpAndSettle();
      expect(engine.settings.language, AgentLanguage.taglish);
      expect(engine.settings.interfaceLanguage, AgentLanguage.automatic);
      expect(engine.settings.locale, isEmpty);
      expect(engine.settings.ttsLocale, isEmpty);
      expect(engine.mission!.snapshot, snapshot);
      expect(engine.settings.execute, true);
      await preview.capture(tester, 'agent-language-settings');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'amount clarification repairs only the draft; goal selection uses authorized local options',
    (tester) async {
      final engine = testEngine();
      await enableAgent(engine);
      final voice = AgentVoiceController(FakeAgentVoice());
      addTearDown(() {
        engine.dispose();
        voice.dispose();
      });
      await preview.mount(
        tester,
        AgentStudioScreen(engine: engine, voice: voice),
      );
      await tester.enterText(
        find.byKey(const Key('agent-input')),
        'Add PHP 500 or 5000 to my goal',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send reviewed text'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(ActionChip, '500'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.widgetWithText(ActionChip, '500')),
        alignment: 0.2,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, '500'));
      await tester.pumpAndSettle();
      expect(
        (engine.mission!.steps.single.action as ContributionDraft).amount,
        '500',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('agent-choose-goal')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('agent-choose-goal'))),
        alignment: 0.2,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agent-choose-goal')));
      await tester.pumpAndSettle();
      expect(find.text('Laptop · PHP'), findsOneWidget);
      await tester.tap(find.text('Laptop · PHP'));
      await tester.pumpAndSettle();
      expect(
        (engine.mission!.steps.single.action as ContributionDraft).goalId,
        'goalA',
      );
      expect((engine.backend as FakeAgentBackend).calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
