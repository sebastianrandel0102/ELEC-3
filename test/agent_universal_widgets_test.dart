import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_planner.dart';
import 'package:myproject/agent_studio/agent_screen.dart';
import 'package:myproject/agent_studio/agent_voice.dart';
import 'package:myproject/agent_studio/intelligence/interpretation_preview.dart';
import 'package:myproject/agent_studio/intelligence/agent_language.dart';

import 'agent_studio_fixtures.dart';
import 'redesign_test.dart' as preview;
import 'ui_preview_fonts.dart';

void main() {
  setUpAll(loadManropeForPreviews);
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
      'understanding preview wraps on narrow large-text screens, dark=$dark',
      (tester) async {
        final e = testEngine();
        await enableAgent(e);
        await e.applyPlan(
          LocalAgentPlanner().plan(
            'Create a savings goal called My Future Setup, target PHP 30000 by 2027-12-31.',
            now: agentNow,
          ),
        );
        final voice = AgentVoiceController(FakeAgentVoice());
        addTearDown(() {
          e.dispose();
          voice.dispose();
        });
        await preview.mount(
          tester,
          Theme(
            data: (dark ? ThemeData.dark() : ThemeData.light()).copyWith(
              textTheme: (dark ? ThemeData.dark() : ThemeData.light()).textTheme
                  .apply(fontFamily: 'Manrope'),
            ),
            child: AgentStudioScreen(engine: e, voice: voice),
          ),
          size: const Size(320, 900),
          scale: 1.6,
        );
        await tester.scrollUntilVisible(
          find.byType(AgentInterpretationPreview),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Goal Title: My Future Setup'), findsOneWidget);
        expect(find.text('Title source: Your title'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await preview.capture(
          tester,
          'agent-universal-${dark ? 'dark' : 'light'}',
        );
        expect((e.backend as FakeAgentBackend).calls, isEmpty);
      },
    );
  }
  testWidgets('purpose title is visibly labelled as a suggestion', (
    tester,
  ) async {
    final p = LocalAgentPlanner().plan(
      'Create a goal for a laptop.',
      now: agentNow,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentInterpretationPreview(
            action: p.actions.single,
            binding: p.interpretation!.titles.single,
            strings: const AgentStrings(AgentLanguage.english),
          ),
        ),
      ),
    );
    expect(find.text('Goal Title: laptop'), findsOneWidget);
    expect(find.textContaining('Suggested from purpose'), findsOneWidget);
    expect(find.text('Purpose: laptop'), findsOneWidget);
    expect(find.text('Target: Not specified'), findsOneWidget);
    expect(find.text('Deadline: Not selected'), findsOneWidget);
  });
  testWidgets('mission rename changes typed state with no repository write', (
    tester,
  ) async {
    final e = testEngine();
    await enableAgent(e);
    e.draft([goalDraft()], title: 'Old Plan');
    final voice = AgentVoiceController(FakeAgentVoice());
    addTearDown(() {
      e.dispose();
      voice.dispose();
    });
    await preview.mount(tester, AgentStudioScreen(engine: e, voice: voice));
    await tester.ensureVisible(find.byKey(const Key('agent-rename-mission')));
    await tester.tap(find.byKey(const Key('agent-rename-mission')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'My Future');
    await tester.tap(find.text('Save draft details'));
    await tester.pumpAndSettle();
    expect(e.mission!.title, 'My Future');
    expect((e.backend as FakeAgentBackend).calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('scenario and reminder editors expose actual title fields', (
    tester,
  ) async {
    final e = testEngine();
    await enableAgent(e);
    e.draft([
      const ReminderDraft(title: 'Friday Savings'),
      const ScenarioDraft(title: 'Fast Track'),
    ]);
    final voice = AgentVoiceController(FakeAgentVoice());
    addTearDown(() {
      e.dispose();
      voice.dispose();
    });
    await preview.mount(tester, AgentStudioScreen(engine: e, voice: voice));
    await tester.scrollUntilVisible(
      find.text('Reminder Title: Friday Savings'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reminder Title: Friday Savings'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Scenario Title: Fast Track'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Scenario Title: Fast Track'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
