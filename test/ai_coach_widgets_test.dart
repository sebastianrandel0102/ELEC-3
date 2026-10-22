import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:myproject/ai_coach/ai_coach_screen.dart';
import 'package:myproject/ai_coach/ai_controller.dart';
import 'package:myproject/ai_coach/ai_domain.dart';
import 'package:myproject/ai_coach/ai_response.dart';
import 'package:myproject/ai_coach/ai_widgets.dart';
import 'package:myproject/ai_coach/firestore_ai_context_source.dart';
import 'package:myproject/design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_coach_fixtures.dart';
import 'ai_coach_firestore_test.dart' show ContextAuth, ContextDb;
import 'redesign_test.dart' as preview;
import 'ui_preview_fonts.dart';

void main() {
  late RecordingAiGateway gateway;
  late AiCoachController controller;
  late DateTime time;
  setUpAll(() async {
    await loadManropeForPreviews();
    await loadAiMathFontsForPreviews();
    // Flutter tests otherwise substitute Ahem for platform monospace. Load the
    // host's code font only for optional local review; never copy/distribute it.
    if (const bool.fromEnvironment('SAVE_UI_PREVIEWS') && Platform.isWindows) {
      final font = File('C:/Windows/Fonts/consola.ttf');
      if (await font.exists()) {
        await (FontLoader(
          'monospace',
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    time = DateTime(2026, 10, 14);
    gateway = RecordingAiGateway();
    controller = AiCoachController(
      gateway: gateway,
      contextSource: FakeAiContextSource(),
      currentUid: () => 'private-uid',
      now: () => time,
    )..acknowledgeProvider();
  });
  tearDown(() => controller.dispose());
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0,
    AiCoachController? withController,
  }) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    await preview.mount(
      tester,
      AiCoachScreen(controller: withController ?? controller),
      size: size,
      scale: scale,
      keyboard: keyboard,
    );
  }

  Future<AiCoachController> reopenCoach(
    WidgetTester tester, {
    String uid = 'private-uid',
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final fresh = AiCoachController(gateway: gateway, currentUid: () => uid);
    addTearDown(fresh.dispose);
    await mount(tester, withController: fresh, size: size, scale: scale);
    return fresh;
  }

  Future<void> askQuestion(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Explain science');
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 360.0, 390.0, 412.0, 480.0, 600.0, 960.0]) {
    testWidgets('welcome modes and composer fit width $width', (tester) async {
      await mount(tester, size: Size(width, 844));
      expect(find.text('SaveTrack AI'), findsOneWidget);
      expect(find.text('A little clarity\ngoes a long way.'), findsOneWidget);
      expect(gateway.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('SaveTrack Coach'));
      await tester.pumpAndSettle();
      expect(find.text('Small steps.\nMeaningful progress.'), findsOneWidget);
      expect(gateway.requests, isEmpty);
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    });
  }
  for (final layout in [
    (const Size(320, 640), 2.0, 0.0),
    (const Size(390, 844), 2.0, 320.0),
    (const Size(740, 360), 1.0, 150.0),
    (const Size(320, 640), 1.0, 300.0),
  ]) {
    testWidgets(
      'large text/keyboard layout ${layout.$1} ${layout.$2} ${layout.$3}',
      (tester) async {
        await mount(
          tester,
          size: layout.$1,
          scale: layout.$2,
          keyboard: layout.$3,
        );
        await tester.enterText(find.byType(TextField), 'A multiline\nquestion');
        await tester.pump();
        expect(tester.takeException(), isNull);
        final send = tester.getRect(find.byTooltip('Send question'));
        expect(send.bottom, lessThanOrEqualTo(layout.$1.height - layout.$3));
      },
    );
  }
  testWidgets(
    'quick prompts populate composer without provider or context reads',
    (tester) async {
      await mount(tester);
      await tester.scrollUntilVisible(
        find.text('Code'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        contains('Flutter widgets'),
      );
      expect(gateway.requests, isEmpty);
      expect((controller.contextSource! as FakeAiContextSource).reads, 0);
    },
  );
  testWidgets('mode switching keeps drafts and histories isolated', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'A general question');
    await tester.tap(find.text('SaveTrack Coach'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A private Coach draft');
    await tester.tap(find.text('Ask Anything'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'A general question',
    );
    expect(gateway.requests, isEmpty);
  });
  testWidgets('long response Markdown code tables copy and clear chat work', (
    tester,
  ) async {
    gateway.reply =
        '# A useful answer\n\n**Bold** and an explanation.\n\n'
        '```dart\n  print("hello");\n  // ${'a' * 240}\n```\n\n'
        '| Topic | Detail |\n| --- | --- |\n| A | Some content |\n\n${'A long paragraph. ' * 80}';
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Explain Flutter');
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.byType(AiMarkdownResponse), findsOneWidget);
    await tester.ensureVisible(find.byType(AiCodeBlock));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
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
    await tester.tap(find.byTooltip('Copy code'));
    await tester.pump();
    expect(copied, '  print("hello");\n  // ${'a' * 240}\n');
    await tester.tap(find.byTooltip('Chat actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear chat'));
    await tester.pumpAndSettle();
    expect(controller.active.messages, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'integral renders while streaming and keeps the copyable answer',
    (tester) async {
      final stream = gateway.pending = StreamController<String>();
      await mount(tester);
      await tester.enterText(
        find.byType(TextField),
        'What is integration of x?',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send question'));
      await tester.pump();
      stream.add(
        r'The integral of $x$ is:'
        '\n\n'
        r'$$'
        '\n'
        r'\int x\,dx = \frac{x',
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Formatting equation…'), findsOneWidget);
      expect(find.byType(Math), findsWidgets);
      expect(tester.takeException(), isNull);
      stream.add(
        '^2}{2} + C\n'
        r'$$'
        '\n\nAdd 1 to the power of x, then divide by the new power (2).\n\n'
        r'$C$ is any constant, because the derivative of a constant is zero.',
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Formatting equation…'), findsNothing);
      expect(find.textContaining('Could not format'), findsNothing);
      await stream.close();
      await tester.pumpAndSettle();
      expect(controller.active.messages.last.text, integralAnswer);
      expect(tester.takeException(), isNull);
      await preview.capture(tester, 'ai-integral-conversation');
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
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
      await tester.ensureVisible(find.byTooltip('Copy answer'));
      await tester.tap(find.byTooltip('Copy answer'));
      await tester.pump();
      expect(copied, integralAnswer);
    },
  );

  testWidgets('first-use notice precedes every first provider request', (
    tester,
  ) async {
    final firstUse = AiCoachController(
      gateway: gateway,
      currentUid: () => 'private-uid',
    );
    addTearDown(firstUse.dispose);
    await preview.mount(tester, AiCoachScreen(controller: firstUse));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.enterText(find.byType(TextField), 'Explain science');
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.text('Before your first question'), findsOneWidget);
    expect(gateway.requests, isEmpty);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      false,
    );
    await preview.capture(tester, 'ai-provider-notice');
    await tester.ensureVisible(find.text('Do not show again'));
    await tester.tap(find.text('Do not show again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(gateway.requests, isEmpty);
    expect(firstUse.providerAcknowledged, false);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Explain science',
    );
  });
  testWidgets(
    'remembered notice survives reopening and stays account-specific',
    (tester) async {
      await reopenCoach(tester);
      await askQuestion(tester);
      await tester.ensureVisible(find.text('Do not show again'));
      await tester.tap(find.text('Do not show again'));
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();
      expect(gateway.requests, hasLength(1));

      final returning = await reopenCoach(tester);
      expect(returning.providerAcknowledged, false);
      await askQuestion(tester);
      expect(find.text('Before your first question'), findsNothing);
      expect(returning.providerAcknowledged, true);
      expect(gateway.requests, hasLength(2));

      await reopenCoach(tester, uid: 'another-user');
      await askQuestion(tester);
      expect(find.text('Before your first question'), findsOneWidget);
      expect(gateway.requests, hasLength(2));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'accepting without remembering shows the notice on a future visit',
    (tester) async {
      await reopenCoach(tester);
      await askQuestion(tester);
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();
      expect(gateway.requests, hasLength(1));
      await reopenCoach(tester);
      await askQuestion(tester);
      expect(find.text('Before your first question'), findsOneWidget);
      expect(gateway.requests, hasLength(1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets('AI privacy can reopen the notice and restore future reminders', (
    tester,
  ) async {
    await reopenCoach(tester);
    await askQuestion(tester);
    await tester.ensureVisible(find.text('Do not show again'));
    await tester.tap(find.text('Do not show again'));
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    await reopenCoach(tester);
    await tester.tap(find.byTooltip('Chat actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI privacy'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      true,
    );
    await tester.ensureVisible(find.text('Do not show again'));
    await tester.tap(find.text('Do not show again'));
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    await reopenCoach(tester);
    await askQuestion(tester);
    expect(find.text('Before your first question'), findsOneWidget);
    expect(gateway.requests, hasLength(1));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
  testWidgets('notice checkbox and confirmation work with large text', (
    tester,
  ) async {
    await reopenCoach(tester, size: const Size(320, 640), scale: 2);
    await askQuestion(tester);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Do not show again'));
    await tester.tap(find.text('Do not show again'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      true,
    );
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(gateway.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });
  for (final action in ['Analyze a Goal', 'Build a Savings Plan']) {
    testWidgets(
      '$action identifies and selects personal goals by saved title',
      (tester) async {
        final db = ContextDb();
        for (final (id, title) in [
          ('emergency', 'Emergency fund'),
          ('laptop', 'New laptop for school'),
        ]) {
          db.documents['users/private-uid/goals/$id'] = {
            'title': title,
            'savedAmount': 250,
            'targetAmount': 1000,
            'currencyCode': 'PHP',
            'archived': false,
          };
        }
        final coach =
            AiCoachController(
                gateway: gateway,
                contextSource: FirestoreAiContextSource(
                  firestore: db,
                  auth: ContextAuth(),
                ),
                currentUid: () => 'private-uid',
              )
              ..acknowledgeProvider()
              ..switchMode(AiMode.coach);
        addTearDown(coach.dispose);
        await mount(tester, withController: coach, size: const Size(360, 800));
        await tester.scrollUntilVisible(
          find.text(action),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();

        expect(find.text('Emergency fund'), findsOneWidget);
        expect(find.text('New laptop for school'), findsOneWidget);
        expect(find.text('Personal goal · Review summary'), findsNWidgets(2));
        expect(find.text('Savings goal'), findsNothing);
        expect(gateway.requests, isEmpty);
        expect(tester.takeException(), isNull);
        await preview.capture(
          tester,
          action == 'Analyze a Goal'
              ? 'ai-analyze-goal-picker'
              : 'ai-plan-goal-picker',
        );

        await tester.tap(find.text('New laptop for school'));
        await tester.pumpAndSettle();
        expect(find.text('Review AI Context'), findsOneWidget);
        await tester.ensureVisible(find.text('Approve this summary'));
        await tester.tap(find.text('Approve this summary'));
        await tester.pumpAndSettle();
        expect(coach.active.facts!.subjectKey, 'goal/laptop');
        expect(coach.active.facts!.title, 'New laptop for school');
        expect(gateway.requests, isEmpty);

        await tester.tap(find.byTooltip('Send question'));
        await tester.pumpAndSettle();
        final outgoing = gateway.requests.single.providerQuestion;
        expect(outgoing, contains('Application-approved categorical summary'));
        for (final localText in [
          'Emergency fund',
          'New laptop for school',
          'goal/laptop',
        ]) {
          expect(outgoing, isNot(contains(localText)));
        }
        expect(tester.takeException(), isNull);
        coach.revokeContext();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'Coach review approval is required and exact local facts remain separate',
    (tester) async {
      gateway.reply = 'Your saved balance is PHP 999,999.99.'; // Deliberate hallucination fixture.
      controller.switchMode(AiMode.coach);
      await mount(tester);
      await tester.scrollUntilVisible(
        find.text('Analyze a Goal'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze a Goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Private goal:'));
      await tester.pumpAndSettle();
      expect(find.text('Review AI Context'), findsOneWidget);
      expect(gateway.requests, isEmpty);
      expect(find.textContaining('exact amounts'), findsOneWidget);
      await tester.ensureVisible(find.text('Approve this summary'));
      await tester.tap(find.text('Approve this summary'));
      await tester.pumpAndSettle();
      expect(controller.active.approval, isNotNull);
      expect(gateway.requests, isEmpty);
      await tester.pump();
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      expect(controller.active.facts!.values['Saved'], contains('250.00'));
      expect(controller.active.messages.last.text, contains('999,999.99'));
      await tester.tap(find.byTooltip('View verified SaveTrack facts'));
      await tester.pumpAndSettle();
      expect(find.byType(AiFactCard), findsOneWidget);
      await tester.tap(
        find.byTooltip('Revoke context and clear Coach history'),
      );
      await tester.pumpAndSettle();
      expect(controller.active.facts, isNull);
      expect(controller.active.messages, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('streaming thinking stop and recoverable error controls render', (
    tester,
  ) async {
    final stream = gateway.pending = StreamController<String>();
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pump();
    expect(find.text('Thinking…'), findsOneWidget);
    stream.add('First chunk');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('First chunk'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop response'));
    await tester.pump();
    unawaited(stream.close());
    await tester.pump();
    expect(controller.busy, false);
    expect(find.text('Stopped · partial answer'), findsOneWidget);
    time = time.add(const Duration(seconds: 4));
    gateway.pending = null;
    gateway.error = const AiFailure(
      AiErrorKind.offline,
      'Offline. Check your connection.',
    );
    await tester.enterText(find.byType(TextField), 'Another question');
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.text('Offline. Check your connection.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('AI images never trigger external network image loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SaveTrackDesign.theme,
        home: const Scaffold(
          body: AiMarkdownResponse(
            text: '![tracker](https://example.com/tracker.png)\n\n<script>alert(1)</script>',
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.text('[Image omitted]'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'App Check setup failure keeps question and offers a setup action',
    (tester) async {
      final gateway = PreflightAiGateway()
        ..preparationError = const AiFailure(
          AiErrorKind.configuration,
          'Web AI needs an App Check site key.',
        );
      final guarded = AiCoachController(
        gateway: gateway,
        currentUid: () => 'private-uid',
      )..acknowledgeProvider();
      await preview.mount(tester, AiCoachScreen(controller: guarded));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        guarded.dispose();
      });
      await tester.enterText(find.byType(TextField), 'Explain photosynthesis.');
      await tester.pump();
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      expect(guarded.active.messages, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Explain photosynthesis.',
      );
      expect(find.text('Incomplete · AI-generated'), findsNothing);
      expect(find.text('AI setup'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tester.tap(find.text('AI setup'));
      await tester.pumpAndSettle();
      expect(find.text('Connect SaveTrack AI'), findsOneWidget);
      expect(find.text('Open Firebase App Check'), findsOneWidget);
      expect(find.text('Open Firebase AI Logic'), findsOneWidget);
      await tester.ensureVisible(find.text('Check connection'));
      await tester.pumpAndSettle();
      gateway.preparationError = null;
      await tester.tap(find.text('Check connection'));
      await tester.pumpAndSettle();
      expect(gateway.checks.last, true);
      expect(guarded.active.failure, isNull);
      expect(gateway.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty failed assistant response is omitted from transcript', (
    tester,
  ) async {
    gateway.error = const AiFailure(
      AiErrorKind.configuration,
      'App Check registration is required.',
    );
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.text('Incomplete · AI-generated'), findsNothing);
    expect(find.text('AI setup'), findsOneWidget);
    expect(find.text('Question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('optional actual-font visual review captures', (tester) async {
    if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
    await mount(tester);
    await preview.capture(tester, 'ai-general-welcome');
    controller.switchMode(AiMode.coach);
    await tester.pumpAndSettle();
    await preview.capture(tester, 'ai-coach-welcome');
    controller.selectFacts(goalFixture(title: 'A new laptop'), approve: true);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(AiFactCard));
    await tester.pumpAndSettle();
    await preview.capture(tester, 'ai-verified-facts');
    final review = showAiContextReview(
      tester.element(find.byType(AiCoachScreen)),
      controller.active.facts!,
    );
    await tester.pumpAndSettle();
    await preview.capture(tester, 'ai-context-review');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await review;
    for (final subject in [AiContextValue.planner, AiContextValue.report]) {
      final summary = AiSafeSummary({
        AiContextField.subject: subject,
        AiContextField.workload: subject == AiContextValue.planner
            ? AiContextValue.light
            : AiContextValue.moderate,
        AiContextField.completion: subject == AiContextValue.planner
            ? AiContextValue.noneComplete
            : AiContextValue.someComplete,
        AiContextField.priority: subject == AiContextValue.planner
            ? AiContextValue.noHighPriority
            : AiContextValue.highPriorityPresent,
      });
      final subjectReview = showAiContextReview(
        tester.element(find.byType(AiCoachScreen)),
        AiLocalFacts(
          title: 'Local preview',
          values: const {},
          summary: summary,
          subjectKey: 'preview-${subject.name}',
          revision: 'preview',
          ownerUid: 'private-uid',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await preview.capture(tester, 'ai-context-review-${subject.name}');
      await tester.tap(find.text('View exact data'));
      await tester.pumpAndSettle();
      expect(find.text(summary.text), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await subjectReview;
    }
    final sharedReview = showAiContextReview(
      tester.element(find.byType(AiCoachScreen)),
      goalFixture(shared: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Approve this summary'), findsNothing);
    expect(find.text('View exact data'), findsNothing);
    await preview.capture(tester, 'ai-context-review-shared');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await sharedReview;
    gateway.reply =
        '## Your next step\n\nYou’re in the **early stage** of this goal. Build a contribution routine that fits your week.\n\n'
        '1. Pick a consistent savings day.\n2. Review your local daily pace.\n3. Adjust if your budget changes.\n\nExact financial values stay in the SaveTrack fact card.';
    await controller.send('Help me plan my progress.');
    await tester.pumpAndSettle();
    await preview.capture(tester, 'ai-coach-conversation');
    controller.switchMode(AiMode.askAnything);
    time = time.add(const Duration(seconds: 4));
    gateway.reply =
        '## A widget is a building block\n\nFlutter uses widgets to describe the interface.\n\n'
        '```dart\nclass Greeting extends StatelessWidget {\n  const Greeting({super.key});\n\n  @override\n  Widget build(BuildContext context) {\n    return const Text("Hello, SaveTrack!");\n  }\n}\n```\n\nUse small widgets to keep your UI readable.';
    await controller.send('Explain Flutter widgets.');
    await tester.pumpAndSettle();
    await preview.capture(tester, 'ai-code-conversation');
    controller.newChat();
    await tester.pumpAndSettle();
    await preview.mount(
      tester,
      AiCoachScreen(controller: controller),
      size: const Size(320, 640),
      scale: 2,
    );
    await preview.capture(tester, 'ai-accessibility-320');
    final largeTextReview = showAiContextReview(
      tester.element(find.byType(AiCoachScreen)),
      goalFixture(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await preview.capture(tester, 'ai-context-review-accessibility-320');
    await tester.ensureVisible(find.text('General advice instead'));
    await tester.tap(find.text('General advice instead'));
    await tester.pumpAndSettle();
    expect(await largeTextReview, AiReviewChoice.localOnly);
    await preview.mount(
      tester,
      AiCoachScreen(controller: controller),
      size: const Size(740, 360),
      keyboard: 150,
    );
    final shortReview = showAiContextReview(
      tester.element(find.byType(AiCoachScreen)),
      goalFixture(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await shortReview, isNull);
    expect(tester.takeException(), isNull);
    controller.revokeContext();
  });
}
