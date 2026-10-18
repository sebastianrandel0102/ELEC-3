import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_screen.dart';
import 'package:myproject/agent_studio/agent_settings_screen.dart';
import 'package:myproject/agent_studio/agent_step_editor.dart';
import 'package:myproject/agent_studio/agent_voice.dart';
import 'package:myproject/agent_studio/presentation/agent_action_preview.dart';
import 'package:myproject/agent_studio/presentation/agent_history_screen.dart';
import 'package:myproject/agent_studio/presentation/agent_orb_artwork.dart';
import 'package:myproject/agent_studio/presentation/agent_theme.dart';
import 'package:myproject/agent_studio/presentation/agent_widgets.dart';

import 'agent_studio_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    final config = jsonDecode(
      await File('.dart_tool/package_config.json').readAsString(),
    ) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == 'flutter');
    final sdk = Uri.parse('${flutter['rootUri']}/').resolve('../../');
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File.fromUri(
          sdk.resolve(
            'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ),
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await icons.load();
  });

  Future<(AgentEngineFixture, AgentVoiceController)> setup(
    WidgetTester tester, {
    String appearance = 'light',
  }) async {
    final fixture = AgentEngineFixture();
    await enableAgent(fixture.engine);
    fixture.engine.settings = fixture.engine.settings.change({
      'appearance': appearance,
    });
    final voice = AgentVoiceController(fixture.adapter);
    addTearDown(() {
      fixture.engine.dispose();
      voice.dispose();
    });
    return (fixture, voice);
  }

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AgentAtelier.theme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: RepaintBoundary(key: const Key('atelier-capture'), child: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('appearance is backward compatible and does not grant permissions', () {
    final old = AgentSettings.fromJson(const {});
    expect(old.appearance, 'system');
    final dark = old.change({'appearance': 'dark'});
    expect(AgentSettings.fromJson(dark.toJson()).appearance, 'dark');
    expect(dark.permissions, isEmpty);
    expect(dark.execute, false);
    expect(dark.autopilot.enabled, false);
    expect(old.change({'appearance': 'invalid'}).appearance, 'system');
  });

  test('reading and action colors meet AA in light and dark', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    for (final brightness in Brightness.values) {
      final c = AgentAtelier.theme(brightness).colorScheme;
      for (final surface in [
        c.surface,
        c.surfaceContainerLow,
        c.surfaceContainer,
        c.secondaryContainer,
      ]) {
        expect(contrast(c.onSurface, surface), greaterThanOrEqualTo(4.5));
        expect(
          contrast(c.onSurfaceVariant, surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(c.primary, surface), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
    }
  });

  for (final appearance in ['light', 'dark']) {
    testWidgets('Agent home $appearance golden', (tester) async {
      final (f, voice) = await setup(tester, appearance: appearance);
      await mount(tester, AgentStudioScreen(engine: f.engine, voice: voice));
      await expectLater(
        find.byKey(const Key('atelier-capture')),
        matchesGoldenFile('goldens/agent_atelier_home_$appearance.png'),
      );
      expect(f.backend.calls, isEmpty);
      expect(f.adapter.starts, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('goal mission golden uses real draft values', (tester) async {
    final (f, voice) = await setup(tester);
    f.engine.draft([goalDraft()]);
    await mount(tester, AgentStudioScreen(engine: f.engine, voice: voice));
    expect(find.text('Laptop'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('atelier-capture')),
      matchesGoldenFile('goldens/agent_atelier_mission.png'),
    );
    expect(f.backend.calls, isEmpty);
  });

  testWidgets('voice golden is tied to listening and reduced motion', (
    tester,
  ) async {
    final (f, voice) = await setup(tester);
    await mount(tester, AgentStudioScreen(engine: f.engine, voice: voice));
    await tester.tap(find.byTooltip('Start voice input'));
    await tester.pumpAndSettle();
    expect(f.adapter.starts, isEmpty);
    await tester.tap(find.text('Start microphone'));
    f.adapter.emit('listening');
    await tester.pumpAndSettle();
    expect(voice.state, AgentVoiceState.listening);
    expect(find.byTooltip('Stop microphone'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('atelier-capture')),
      matchesGoldenFile('goldens/agent_atelier_voice.png'),
    );
    final before = tester.getSize(find.byType(AgentOrbArtwork));
    f.adapter.controller.add({
      'type': 'amplitude',
      'session': f.adapter.session,
      'value': 1.0,
    });
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AgentOrbArtwork)), before);
    expect(f.backend.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all six shortcuts prefill real input and sending stays explicit',
    (tester) async {
      final (f, voice) = await setup(tester);
      await mount(
        tester,
        AgentStudioScreen(engine: f.engine, voice: voice),
        size: const Size(600, 1100),
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('agent-send')))
            .onPressed,
        isNull,
      );
      for (final title in [
        'Plan a goal',
        'Organize tasks',
        'Draft a reminder',
        'Build a mission',
        'Prepare savings',
        'What if…',
      ]) {
        final card = find.widgetWithText(AgentQuickActionCard, title);
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('agent-input')))
              .controller!
              .text,
          isNotEmpty,
        );
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('agent-send')))
              .onPressed,
          isNotNull,
        );
        expect(f.engine.mission, isNull);
        expect(f.backend.calls, isEmpty);
      }
    },
  );

  testWidgets(
    'appearance dropdown persists and the route updates immediately',
    (tester) async {
      final (f, voice) = await setup(tester);
      await mount(tester, AgentSettingsScreen(engine: f.engine, voice: voice));
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).first,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(f.engine.settings.appearance, 'dark');
      expect((await f.engine.store.settings(f.engine.uid)).appearance, 'dark');
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
      expect(f.backend.calls, isEmpty);
    },
  );

  testWidgets('scenario controls update preview and save the actual draft', (
    tester,
  ) async {
    final (f, _) = await setup(tester);
    AgentAction? result;
    await mount(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showAgentStepEditor(
                context,
                const ScenarioDraft(
                  target: '30000',
                  saved: '0',
                  contribution: '500',
                  currency: 'PHP',
                ),
                engine: f.engine,
              );
            },
            child: const Text('Explore'),
          ),
        ),
      ),
      size: const Size(600, 1100),
    );
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Slider));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    final contribution = fields
        .firstWhere(
          (field) =>
              field.decoration?.labelText ==
              'Contribution per period (optional)',
        )
        .controller!
        .text;
    expect(contribution, isNot('500'));
    expect(find.byType(AgentActionPreview), findsOneWidget);
    await tester.tap(find.text('Save draft details'));
    await tester.pumpAndSettle();
    expect((result as ScenarioDraft).contribution, contribution);
    expect(f.backend.calls, isEmpty);
  });

  testWidgets('System appearance follows platform brightness changes', (
    tester,
  ) async {
    final (f, voice) = await setup(tester, appearance: 'system');
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await mount(tester, AgentStudioScreen(engine: f.engine, voice: voice));
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    expect(f.backend.calls, isEmpty);
  });

  testWidgets('history filters actual missions and opens the selected record', (
    tester,
  ) async {
    final (f, _) = await setup(tester);
    f.engine.draft([goalDraft()], title: 'Laptop draft');
    final draft = f.engine.mission!;
    f.engine.history.addAll([
      draft,
      draft.copyWith(title: 'Finished plan', status: MissionStatus.completed),
    ]);
    AgentMission? opened;
    await mount(
      tester,
      AgentHistoryScreen(engine: f.engine, onOpen: (m) => opened = m),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Laptop draft'), findsNothing);
    await tester.ensureVisible(find.text('Finished plan'));
    await tester.tap(find.text('Finished plan'));
    expect(opened!.status, MissionStatus.completed);
    expect(f.backend.calls, isEmpty);
  });

  testWidgets(
    'long conversations build lazily and preserve the reader position',
    (tester) async {
      final (f, voice) = await setup(tester);
      for (var i = 0; i < 100; i++) {
        f.engine.say(
          'Message $i. A small step toward a clearer plan.',
          user: i.isEven,
        );
      }
      await mount(tester, AgentStudioScreen(engine: f.engine, voice: voice));
      final list = tester.widget<ListView>(find.byType(ListView).first);
      final scroll = list.controller!;
      expect(find.byType(SelectableText).evaluate().length, lessThan(25));
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      final position = scroll.offset;
      f.engine.say('A new response while you are reading earlier messages.');
      await tester.pumpAndSettle();
      expect(scroll.offset, position);
      await tester.tap(find.byTooltip('Jump to latest'));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(position));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dependent steps cannot be moved before their prerequisite', (
    tester,
  ) async {
    final (f, voice) = await setup(tester);
    f.engine.draft([
      goalDraft(),
      const ReminderDraft(targetStep: 'step_1', weekday: 6, time: '09:00'),
    ]);
    await mount(tester, AgentStudioScreen(engine: f.engine, voice: voice));
    final buttons = tester.widgetList<IconButton>(
      find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            (w.tooltip == 'Move step up' || w.tooltip == 'Move step down'),
      ),
    );
    expect(buttons.length, 4);
    expect(buttons.every((button) => button.onPressed == null), true);
    expect(f.backend.calls, isEmpty);
  });

  for (final width in [320.0, 360.0, 390.0, 412.0, 480.0, 600.0]) {
    testWidgets('dark home and financial preview fit $width at large text', (
      tester,
    ) async {
      final (f, voice) = await setup(tester, appearance: 'dark');
      await mount(
        tester,
        AgentStudioScreen(engine: f.engine, voice: voice),
        size: Size(width, 900),
        scale: 1.7,
        keyboard: 250,
      );
      expect(tester.takeException(), isNull);
      f.engine.draft([goalDraft()]);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(AgentActionPreview));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(f.backend.calls, isEmpty);
    });
  }
}

class AgentEngineFixture {
  final backend = FakeAgentBackend();
  final adapter = FakeAgentVoice();
  late final engine = testEngine(backend: backend);
}
