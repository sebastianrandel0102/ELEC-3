import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_screen.dart';
import 'package:myproject/agent_studio/agent_voice.dart';

import 'agent_studio_fixtures.dart';
import 'redesign_test.dart' as preview;
import 'ui_preview_fonts.dart';

void main() {
  setUpAll(loadManropeForPreviews);
  testWidgets(
    'on-device model failure has a specific recovery path and a readable pushed voice toolbar',
    (tester) async {
      final engine = testEngine();
      await enableAgent(engine);
      await engine.updateSettings(engine.settings.change({'onDevice': true}));
      final adapter = FakeAgentVoice()..onDeviceAvailable = true;
      final voice = AgentVoiceController(adapter);
      addTearDown(() {
        engine.dispose();
        voice.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await preview.mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AgentStudioScreen(engine: engine, voice: voice),
                ),
              ),
              child: const Text('Open Agent'),
            ),
          ),
        ),
        size: const Size(360, 800),
        scale: 1.2,
      );
      await tester.tap(find.text('Open Agent'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Start voice input'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start microphone'));
      await tester.pumpAndSettle();
      adapter.controller.add({
        'type': 'support',
        'session': adapter.session,
        'onDeviceLanguages': ['en-US'],
      });
      adapter.controller.add({
        'type': 'error',
        'session': adapter.session,
        'nativeCode': 13,
        'code': 'language_unavailable',
        'message': 'The on-device language model is not installed or ready. Choose an installed language or change the on-device requirement.',
      });
      await tester.pumpAndSettle();
      expect(find.text('Voice needs attention'), findsOneWidget);
      expect(find.text('Ready for your next turn'), findsNothing);
      expect(find.text('Android speech error 13'), findsOneWidget);
      expect(find.text('Use Android speech dialog'), findsNothing);
      expect(adapter.systemStarts, isEmpty);
      expect(engine.mission, isNull);
      if (const bool.fromEnvironment('SAVE_UI_PREVIEWS')) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('SaveTrack Voice'))
              .didExceedMaxLines,
          false,
        );
      }
      expect(tester.takeException(), isNull);
      await preview.capture(tester, 'agent-voice-model-error');
      await tester.ensureVisible(find.text('Voice settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voice settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Recognition locale override'),
        250,
      );
      await tester.tap(find.text('Recognition locale override'));
      await tester.pumpAndSettle();
      expect(find.text('en-US'), findsOneWidget);
      expect(find.text('fil-PH'), findsNothing);
    },
  );
  testWidgets(
    'Android speech fallback survives its external UI and still requires transcript review',
    (tester) async {
      final engine = testEngine();
      await enableAgent(engine);
      final adapter = FakeAgentVoice();
      final voice = AgentVoiceController(adapter);
      addTearDown(() {
        engine.dispose();
        voice.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await preview.mount(
        tester,
        AgentStudioScreen(engine: engine, voice: voice),
        size: const Size(360, 800),
      );
      await tester.tap(find.byTooltip('Conversation options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open voice mode'));
      await tester.pumpAndSettle();
      await voice.start(engine.settings);
      adapter.controller.add({
        'type': 'error',
        'session': adapter.session,
        'nativeCode': 5,
        'message': 'Android speech service could not start this session.',
      });
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Use Android speech dialog'));
      await tester.tap(find.text('Use Android speech dialog'));
      await tester.pumpAndSettle();
      expect(adapter.systemStarts, isEmpty);
      await tester.tap(find.text('Open speech dialog'));
      await tester.pumpAndSettle();
      expect(adapter.systemStarts, hasLength(1));
      expect(voice.usingSystemDialog, true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(voice.usingSystemDialog, true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      adapter.emit('final', text: 'Prepare PHP 50 for my goal');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Prepare PHP 50 for my goal'),
        findsOneWidget,
      );
      expect(engine.mission, isNull);
      expect(engine.messages, isEmpty);
      expect(voice.usingSystemDialog, false);
      expect(tester.takeException(), isNull);
    },
  );
}
