import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_engine.dart';
import 'package:myproject/agent_studio/agent_screen.dart';
import 'package:myproject/agent_studio/agent_voice.dart';
import 'package:myproject/agent_studio/autopilot/autopilot_settings.dart';
import 'package:myproject/agent_studio/autopilot/autopilot_settings_screen.dart';

import 'agent_studio_fixtures.dart';
import 'agent_autopilot_policy_test.dart' show smartAutopilot;
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
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    await preview.mount(tester, child, size: size, scale: scale);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> configure(
    WidgetTester tester, {
    Map<String, Object?> changes = const {},
  }) async {
    // Construct the serialized-write queue in this widget test's async zone.
    engine.dispose();
    voice.dispose();
    adapter = FakeAgentVoice();
    voice = AgentVoiceController(adapter);
    engine = testEngine(backend: backend);
    await engine.initialize();
    engine.settings = AgentSettings(
      execute: true,
      permissions: AgentPermission.values.toSet(),
      autopilot: smartAutopilot(changes: changes),
    );
  }

  testWidgets(
    'enabling Smart requires explicit consent and reset restores safe defaults',
    (tester) async {
      await mount(tester, AgentAutopilotSettingsScreen(engine: engine));
      expect(engine.settings.autopilot.enabled, false);
      await tapVisible(
        tester,
        find.byKey(const Key('autopilot-mode-smartAuto')),
      );
      expect(find.text('Enable automatic actions?'), findsOneWidget);
      expect(engine.settings.autopilot.enabled, false);
      await tester.tap(find.text('Keep Ask First'));
      await tester.pumpAndSettle();
      expect(engine.settings.autopilot.enabled, false);
      await tapVisible(
        tester,
        find.byKey(const Key('autopilot-mode-smartAuto')),
      );
      await tester.tap(find.byKey(const Key('autopilot-consent')));
      await tester.pumpAndSettle();
      expect(engine.settings.autopilot.mode, AgentExecutionMode.smartAuto);
      expect(engine.settings.autopilot.autoCreateTasks, true);
      expect(engine.settings.autopilot.voiceAutoExecutionEnabled, false);
      await preview.capture(tester, 'autopilot-settings-light');
      await tester.scrollUntilVisible(
        find.byKey(const Key('autopilot-reset')),
        500,
      );
      await tester.tap(find.byKey(const Key('autopilot-reset')));
      await tester.pumpAndSettle();
      expect(
        engine.settings.autopilot.mode,
        AgentExecutionMode.askBeforeEveryAction,
      );
      expect(engine.settings.autopilot.autoCreateTasks, false);
      expect(engine.settings.autopilot.autoCreateReminders, false);
      expect(
        engine.settings.permissions.contains(AgentPermission.createTask),
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Custom category switch changes actual per-action permission', (
    tester,
  ) async {
    await mount(tester, AgentAutopilotSettingsScreen(engine: engine));
    await tester.scrollUntilVisible(
      find.byKey(const Key('autopilot-autoCreateTasks')),
      350,
    );
    await tapVisible(
      tester,
      find.byKey(const Key('autopilot-autoCreateTasks')),
    );
    expect(engine.settings.autopilot.autoCreateTasks, true);
    expect(engine.settings.autopilot.autoCreateReminders, false);
    expect(engine.settings.autopilot.enabled, false);
  });
  testWidgets(
    'chat automatically completes the requested goal with no approval dialog; pause restores review',
    (tester) async {
      await configure(tester);
      await mount(tester, AgentStudioScreen(engine: engine, voice: voice));
      expect(find.text('Auto-Execute Active'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('agent-input')),
        'Create a goal called Laptop, target ₱30,000, deadline December 15, 2027.',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send reviewed text'));
      await tester.pumpAndSettle();
      expect(engine.mission!.status, MissionStatus.completed);
      expect(find.byKey(const Key('agent-confirm')), findsNothing);
      expect(backend.calls, ['step_1']);
      await preview.capture(tester, 'autopilot-goal-result');
      await tester.tap(find.byTooltip('Pause Autopilot'));
      await tester.pumpAndSettle();
      expect(engine.settings.autopilot.mode, AgentExecutionMode.paused);
      await tester.enterText(
        find.byKey(const Key('agent-input')),
        'Create a task called Research Laptop Prices tomorrow',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send reviewed text'));
      await tester.pumpAndSettle();
      expect(backend.calls, hasLength(1));
      expect(find.byKey(const Key('agent-review')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'default voice opt out and partial recognition never trigger automatic execution',
    (tester) async {
      await configure(tester);
      await mount(tester, AgentStudioScreen(engine: engine, voice: voice));
      await voice.start(engine.settings);
      adapter.emit('listening');
      adapter.emit('partial', text: 'Create a task called Homework tomorrow');
      await tester.pumpAndSettle();
      expect(backend.calls, isEmpty);
      expect(engine.mission, isNull);
      adapter.emit('final', text: 'Create a task called Homework tomorrow');
      await tester.pumpAndSettle();
      expect(backend.calls, isEmpty);
      expect(engine.mission, isNull);
      await tester.pump();
      await tester.tap(find.byTooltip('Send reviewed text'));
      await tester.pumpAndSettle();
      expect(backend.calls, isEmpty);
      expect(engine.autoDecision!.reasonCode, 'voice_permission');
    },
  );
  testWidgets(
    'separately opted-in eligible final voice runs once, never a partial or duplicate callback',
    (tester) async {
      await configure(
        tester,
        changes: {
          'voiceAutoExecutionEnabled': true,
          'voiceReviewMode': AgentVoiceReviewMode.autoRunEligible.name,
        },
      );
      await mount(tester, AgentStudioScreen(engine: engine, voice: voice));
      await voice.start(engine.settings);
      adapter.emit('listening');
      adapter.emit('partial', text: 'Create a task called Homework tomorrow');
      await tester.pumpAndSettle();
      expect(backend.calls, isEmpty);
      adapter.emit('final', text: 'Create a task called Homework tomorrow');
      await tester.pumpAndSettle();
      expect(backend.calls, hasLength(1));
      expect(engine.mission!.status, MissionStatus.completed);
      adapter.emit('final', text: 'Create a task called Homework tomorrow');
      await tester.pumpAndSettle();
      expect(backend.calls, hasLength(1));
    },
  );
  testWidgets('uncertain voice alternatives remain in transcript review', (
    tester,
  ) async {
    await configure(
      tester,
      changes: {
        'voiceAutoExecutionEnabled': true,
        'voiceReviewMode': AgentVoiceReviewMode.autoRunEligible.name,
      },
    );
    await mount(tester, AgentStudioScreen(engine: engine, voice: voice));
    await voice.start(engine.settings);
    adapter.emit('listening');
    adapter.controller.add({
      'type': 'final',
      'session': adapter.session,
      'text': 'Create a task called Homework tomorrow',
      'alternatives': ['Homework', 'Housework'],
      'confidences': [.6, .4],
    });
    await tester.pumpAndSettle();
    expect(backend.calls, isEmpty);
    expect(engine.mission, isNull);
  });
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('settings fit 320px, text scale $scale, dark $dark', (
        tester,
      ) async {
        final screen = AgentAutopilotSettingsScreen(engine: engine);
        await mount(
          tester,
          dark
              ? Theme(
                  data: ThemeData(
                    fontFamily: 'Manrope',
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF087C68),
                      brightness: Brightness.dark,
                    ),
                    useMaterial3: true,
                  ),
                  child: screen,
                )
              : screen,
          size: const Size(320, 740),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        await preview.capture(
          tester,
          'autopilot-settings-${dark ? 'dark' : 'light'}-$scale',
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('autopilot-reset')),
          400,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
