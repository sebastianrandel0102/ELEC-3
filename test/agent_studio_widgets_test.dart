import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_engine.dart';
import 'package:myproject/agent_studio/agent_screen.dart';
import 'package:myproject/agent_studio/agent_voice.dart';

import 'agent_studio_fixtures.dart';
import 'redesign_test.dart' as preview;
import 'ui_preview_fonts.dart';

void main() {
  late AgentEngine engine;
  late FakeAgentBackend backend;
  late FakeAgentVoice adapter;
  late AgentVoiceController voice;
  setUpAll(loadManropeForPreviews);
  setUp(() async {
    backend = FakeAgentBackend();
    engine = testEngine(backend: backend);
    await enableAgent(engine);
    adapter = FakeAgentVoice();
    voice = AgentVoiceController(adapter);
  });
  tearDown(() {
    engine.dispose();
    voice.dispose();
  });
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0,
  }) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    await preview.mount(
      tester,
      AgentStudioScreen(engine: engine, voice: voice),
      size: size,
      scale: scale,
      keyboard: keyboard,
    );
  }

  for (final width in [320.0, 360.0, 390.0, 412.0, 480.0, 600.0, 960.0]) {
    testWidgets(
      'Agent home fits $width without auto-starting voice or writes',
      (tester) async {
        await mount(tester, size: Size(width, 844));
        expect(find.text('Agent Studio'), findsOneWidget);
        expect(adapter.starts, isEmpty);
        expect(backend.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('large text and keyboard keep composer usable', (tester) async {
    await mount(tester, size: const Size(320, 740), scale: 2, keyboard: 250);
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const Key('agent-input')),
      'Create a task to compare prices tomorrow',
    );
    await tester.tap(find.byTooltip('Send reviewed text'));
    await tester.pumpAndSettle();
    expect(engine.mission, isNotNull);
    expect(backend.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('short landscape preserves text input', (tester) async {
    await mount(tester, size: const Size(740, 360), keyboard: 150);
    expect(find.byKey(const Key('agent-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'draft, review and explicit final approval are separate interactions',
    (tester) async {
      engine.draft([taskDraft()]);
      await mount(tester);
      await tester.ensureVisible(find.byKey(const Key('agent-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agent-review')));
      await tester.pumpAndSettle();
      expect(find.text('Approve selected actions'), findsOneWidget);
      expect(backend.calls, isEmpty);
      await preview.capture(tester, 'agent-review');
      await tester.tap(find.byKey(const Key('agent-confirm')));
      await tester.pumpAndSettle();
      expect(backend.calls, ['step_1']);
      expect(engine.mission!.status, MissionStatus.completed);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cancel review performs no writes', (tester) async {
    engine.draft([goalDraft()]);
    await mount(tester);
    await tester.ensureVisible(find.byKey(const Key('agent-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agent-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(backend.calls, isEmpty);
  });
  testWidgets(
    'voice has first-use disclosure and transcript review before send',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Start voice input'));
      await tester.pumpAndSettle();
      expect(adapter.starts, isEmpty);
      expect(find.text('Start microphone'), findsOneWidget);
      await tester.tap(find.text('Start microphone'));
      await tester.pumpAndSettle();
      expect(adapter.starts, hasLength(1));
      adapter.emit('listening');
      adapter.emit('partial', text: 'Prepare PHP 15');
      await tester.pumpAndSettle();
      expect(backend.calls, isEmpty);
      adapter.emit('final', text: 'Prepare PHP 50 for my goal');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Prepare PHP 50 for my goal'),
        findsOneWidget,
      );
      expect(engine.mission, isNull);
      await preview.capture(tester, 'agent-voice');
      await tester.enterText(
        find.byKey(const Key('agent-input')),
        'Prepare PHP 15 for my goal',
      );
      await tester.tap(find.byTooltip('Send reviewed text'));
      await tester.pumpAndSettle();
      expect(
        (engine.mission!.steps.single.action as ContributionDraft).amount,
        '15',
      );
      expect(backend.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('mission edit and removal revalidate dependencies', (
    tester,
  ) async {
    engine.draft([
      goalDraft(),
      const ReminderDraft(targetStep: 'step_1', weekday: 6, time: '09:00'),
    ]);
    await mount(tester);
    final remove = find.byKey(const Key('agent-remove-step_1'));
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(
      engine.mission!.validate(agentNow),
      contains(contains('missing dependency')),
    );
    expect(backend.calls, isEmpty);
  });
  testWidgets(
    'settings disable action permission and expose honest local history defaults',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Agent settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Execute approved actions'));
      await tester.pumpAndSettle();
      expect(engine.settings.execute, false);
      await tester.scrollUntilVisible(
        find.text('Save mission history on this device'),
        350,
      );
      expect(engine.settings.history, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Agent home and mission produce review captures', (tester) async {
    await mount(tester);
    await preview.capture(tester, 'agent-home');
    engine.draft([
      goalDraft(),
      taskDraft(),
      const ReminderDraft(targetStep: 'step_1', weekday: 6, time: '09:00'),
    ]);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mission builder'));
    await tester.pumpAndSettle();
    await preview.capture(tester, 'agent-mission');
    expect(tester.takeException(), isNull);
  });
}
