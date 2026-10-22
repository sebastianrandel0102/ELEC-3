import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/ai_coach/ai_coach_screen.dart';
import 'package:myproject/ai_coach/ai_controller.dart';
import 'package:myproject/ai_coach/ai_conversation_widgets.dart';
import 'package:myproject/ai_coach/ai_domain.dart';
import 'package:myproject/ai_coach/ai_response.dart';
import 'package:myproject/ai_coach/ai_theme.dart';
import 'package:myproject/atelier_preferences.dart';
import 'package:myproject/design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_coach_fixtures.dart';
import 'ui_preview_fonts.dart';

void main() {
  late RecordingAiGateway gateway;
  late AiCoachController controller;
  late DateTime time;
  final preview = GlobalKey();

  setUpAll(() async => loadManropeForPreviews(force: true));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    time = DateTime(2026, 10, 19, 9);
    gateway = RecordingAiGateway();
    controller = AiCoachController(
      gateway: gateway,
      contextSource: FakeAiContextSource(),
      currentUid: () => 'atelier-test-user',
      now: () => time,
    )..acknowledgeProvider();
  });
  tearDown(() {
    controller.dispose();
    AtelierPreferences.themeMode.value = ThemeMode.system;
  });

  Future<void> mount(
    WidgetTester tester, {
    bool dark = false,
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0,
    Widget? child,
    AtelierPreferences? preferences,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    Widget themedApp(ThemeMode mode) => MaterialApp(
      theme: SaveTrackDesign.theme,
      darkTheme: SaveTrackDesign.darkTheme,
      themeMode: mode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: RepaintBoundary(key: preview, child: child!),
      ),
      home: child ?? AiCoachScreen(controller: controller),
    );
    final app = preferences == null
        ? themedApp(dark ? ThemeMode.dark : ThemeMode.light)
        : AtelierScope(
            preferences: preferences,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: AtelierPreferences.themeMode,
              builder: (context, mode, _) => themedApp(mode),
            ),
          );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    for (final width in [320.0, 360.0, 390.0, 412.0, 480.0, 600.0, 840.0]) {
      testWidgets('both modes fit $width in ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await mount(tester, dark: dark, size: Size(width, 844));
        expect(find.text('A little clarity\ngoes a long way.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('SaveTrack Coach'));
        await tester.pumpAndSettle();
        expect(find.text('Small steps.\nMeaningful progress.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(gateway.requests, isEmpty);
      });
    }
  }

  testWidgets('multiline drafts survive modes and Enter does not send', (
    tester,
  ) async {
    await mount(tester, size: const Size(320, 640), scale: 2, keyboard: 220);
    await tester.enterText(
      find.byType(TextField),
      'Paano ako makakaipon?\nHelp me plan.',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(gateway.requests, isEmpty);
    final draft = tester
        .widget<TextField>(find.byType(TextField))
        .controller!
        .text;
    expect(draft, contains('\n'));
    await tester.tap(find.text('SaveTrack Coach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask Anything'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      draft,
    );
    expect(
      tester.getBottomRight(find.byTooltip('Send question')).dy,
      lessThanOrEqualTo(420),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('send locks duplicate taps and follow-ups fill a draft', (
    tester,
  ) async {
    final stream = gateway.pending = StreamController<String>();
    await mount(tester);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Send question',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Explain a savings habit');
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.tap(find.byTooltip('Send question'));
    await tester.pump();
    expect(gateway.requests, hasLength(1));
    expect(find.byType(AiThinkingIndicator), findsOneWidget);
    stream.add('Start small and choose a regular savings day.');
    await stream.close();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show an example.'));
    await tester.tap(find.text('Show an example.'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Show an example.',
    );
    expect(gateway.requests, hasLength(1));
    expect(controller.active.messages, hasLength(2));
  });

  testWidgets(
    'failed retry replaces the pair without duplicating the question',
    (tester) async {
      gateway.error = const AiFailure(
        AiErrorKind.quota,
        'AI usage limit reached. Please try again later.',
      );
      await mount(tester);
      await send(tester, 'Give me a weekly planning tip');
      expect(find.text('Retry'), findsOneWidget);
      expect(controller.active.messages, hasLength(2));
      gateway.error = null;
      gateway.reply = 'Choose one priority for each day.';
      time = time.add(const Duration(seconds: 4));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(controller.active.messages, hasLength(2));
      expect(controller.active.messages.last.text, gateway.reply);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets('reading older content does not jump on streamed updates', (
    tester,
  ) async {
    gateway.reply = List.generate(
      45,
      (i) => 'Step ${i + 1}. Choose a routine that suits your week.',
    ).join('\n\n');
    await mount(tester);
    await send(tester, 'Explain routines');
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(find.byType(ListView).first);
    final position = list.controller!.positions.last;
    final before = position.pixels;
    expect(find.text('Latest'), findsOneWidget);
    time = time.add(const Duration(seconds: 4));
    final stream = gateway.pending = StreamController<String>();
    final request = controller.send('Explain another habit');
    await tester.pump();
    stream.add('A thoughtful follow-up.');
    await tester.pump(const Duration(milliseconds: 100));
    expect(position.pixels, closeTo(before, 1));
    await stream.close();
    await request;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latest'));
    await tester.pumpAndSettle();
    expect(find.text('Latest'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'structured content and long Taglish wrap in ${dark ? 'dark' : 'light'}',
      (tester) async {
        await mount(
          tester,
          dark: dark,
          size: const Size(320, 640),
          scale: 2,
          child: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: AiMarkdownResponse(
                text:
                    '## Isang simpleng plano\n\n'
                    '> **Hypothetical example**\n> If you save ₱500 weekly, you contribute ₱2,000 over four weeks.\n\n'
                    '1. Magtakda ng araw para mag-ipon.\n2. Review your routine every week.\n\n'
                    '| Approach | Description |\n| --- | --- |\n| Weekly | Regular contributions |\n| Flexible | Adjust when your budget changes |',
              ),
            ),
          ),
        );
        expect(find.byType(AiInsightCard), findsOneWidget);
        expect(find.byType(AiComparisonCard), findsOneWidget);
        final markdown = tester
            .widgetList<MarkdownBody>(find.byType(MarkdownBody))
            .first;
        final context = tester.element(find.byType(AiMarkdownResponse));
        expect(markdown.styleSheet!.p!.color, context.atelierInk);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('clipboard failure reports failure without a success message', (
    tester,
  ) async {
    await mount(tester);
    await send(tester, 'A short answer please');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.byTooltip('Copy answer'));
    await tester.pump();
    expect(
      find.text('Could not copy. Try selecting the text.'),
      findsOneWidget,
    );
    expect(find.text('Copied'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final layout in [
    (const Size(740, 360), 1.0, 150.0),
    (const Size(320, 640), 2.0, 220.0),
  ]) {
    testWidgets('error and retry fit with keyboard ${layout.$1}', (
      tester,
    ) async {
      gateway.error = const AiFailure(
        AiErrorKind.offline,
        'AI could not connect. Check your connection, then retry.',
      );
      await mount(
        tester,
        size: layout.$1,
        scale: layout.$2,
        keyboard: layout.$3,
      );
      await send(tester, 'Help me plan my week');
      expect(find.text('Retry'), findsOneWidget);
      expect(
        tester.getBottomRight(find.byTooltip('Send question')).dy,
        lessThanOrEqualTo(layout.$1.height - layout.$3),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'settings use the existing global preference and disclose session history',
    (tester) async {
      final storage = await SharedPreferences.getInstance();
      final preferences = AtelierPreferences(
        storage,
        account: 'atelier-test-user',
      );
      addTearDown(preferences.dispose);
      await mount(
        tester,
        preferences: preferences,
        size: const Size(320, 640),
        scale: 2,
      );
      await tester.tap(find.byTooltip('Chat actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dark'));
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(preferences.appearance, ThemeMode.dark);
      expect(AtelierPreferences.themeMode.value, ThemeMode.dark);
      expect(storage.getString('savetrack.appearance'), 'dark');
      expect(
        Theme.of(tester.element(find.text('Dark'))).brightness,
        Brightness.dark,
      );
      await tester.ensureVisible(find.text('Here for this visit'));
      expect(
        find.textContaining('Chats are cleared when you leave'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(gateway.requests, isEmpty);
    },
  );

  testWidgets('conversation colors have accessible contrast in both themes', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await mount(tester, dark: dark);
      final context = tester.element(find.byType(AiCoachScreen));
      double contrast(Color foreground, Color background) {
        final a = foreground.computeLuminance(),
            b = background.computeLuminance();
        return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
      }

      expect(
        contrast(context.aiOnUser, context.aiUserSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(context.atelierInk, context.aiAssistantSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(context.atelierMuted, context.aiInputSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(context.aiOnAction, context.aiAction),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  for (final dark in [false, true]) {
    testWidgets('welcome golden ${dark ? 'dark' : 'light'}', (tester) async {
      await mount(tester, dark: dark);
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile(
          'goldens/ai-atelier-welcome-${dark ? 'dark' : 'light'}.png',
        ),
      );
    });

    testWidgets('conversation golden ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      gateway.reply =
          '### Make it a small ritual\n\n'
          'Choose a regular savings day and an amount that fits your week.\n\n'
          '> **An illustrative example**\n> ₱500 each week is ₱2,000 over four weeks.\n\n'
          'Review your routine as your priorities change.';
      await mount(tester, dark: dark);
      await send(tester, 'How can I save more consistently?');
      await expectLater(
        find.byKey(preview),
        matchesGoldenFile(
          'goldens/ai-atelier-conversation-${dark ? 'dark' : 'light'}.png',
        ),
      );
    });
  }

  testWidgets('comparison and steps golden', (tester) async {
    await mount(
      tester,
      child: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: AiMarkdownResponse(
            text:
                '## Find a rhythm that fits\n\n'
                '| Approach | A useful starting point |\n| --- | --- |\n'
                '| Weekly | Pick a regular savings day. |\n| Flexible | Adjust contributions to your budget. |\n\n'
                '### Try it this week\n\n1. Choose one small habit.\n2. Set a reminder.\n3. Review what worked.\n\n'
                '> This is general guidance. Choose an approach that suits your situation.',
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('goldens/ai-atelier-response-cards.png'),
    );
  });

  testWidgets('settings golden', (tester) async {
    final storage = await SharedPreferences.getInstance();
    final preferences = AtelierPreferences(storage);
    addTearDown(preferences.dispose);
    await mount(tester, preferences: preferences);
    await tester.tap(find.byTooltip('Chat actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI settings'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(preview),
      matchesGoldenFile('goldens/ai-atelier-settings.png'),
    );
  });
}
