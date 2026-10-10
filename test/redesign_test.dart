// The sealed Firestore interfaces are implemented only as test doubles; the
// application continues to use the original Firebase SDK objects.
// ignore_for_file: subtype_of_sealed_class

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/main.dart';

// These fixtures exercise presentation and callbacks without a live account.
class TestReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final updates = <Map<String, dynamic>>[];
  final records = <TestDocument>[];
  @override
  Future<void> update(Map<Object, Object?> data) async {
    updates.add(Map<String, dynamic>.from(data));
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      TestCollection(records);
}

class TestDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  TestDocument(this.values);
  final Map<String, dynamic> values;
  final testReference = TestReference();
  @override
  Map<String, dynamic> data() => values;
  @override
  DocumentReference<Map<String, dynamic>> get reference => testReference;
}

class TestCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  TestCollection(this.records);
  final List<TestDocument> records;
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(TestSnapshot(records));
}

class TestSnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  TestSnapshot(this.records);
  final List<TestDocument> records;
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => records;
}

final previewKey = GlobalKey();

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
  await tester.pumpWidget(
    MaterialApp(
      theme: const bool.fromEnvironment('SAVE_UI_PREVIEWS')
          ? SaveTrackDesign.theme.copyWith(
              textTheme: SaveTrackDesign.theme.textTheme.apply(
                fontFamily: 'Roboto',
              ),
            )
          : SaveTrackDesign.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: previewKey, child: child!),
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary =
        previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final screenshot = await boundary.toImage();
    final bytes = await screenshot.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-preview/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    screenshot.dispose();
  });
}

Widget scrollPage(Widget child) => Scaffold(
  body: PageSurface(
    child: ListView(padding: const EdgeInsets.all(20), children: [child]),
  ),
);

void main() {
  test('small text meets AA contrast across shared surfaces', () {
    double contrast(Color text, Color background) {
      final a = text.computeLuminance(), b = background.computeLuminance();
      return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
    }

    for (final background in [
      ...SaveTrackDesign.signature.colors,
      ...SaveTrackDesign.premium.colors,
    ]) {
      expect(contrast(Colors.white, background), greaterThanOrEqualTo(4.5));
      expect(
        contrast(SaveTrackDesign.onHeroMuted, background),
        greaterThanOrEqualTo(4.5),
      );
    }
    for (final background in [
      ...SaveTrackDesign.soft.colors,
      Colors.white,
      canvas,
    ]) {
      expect(contrast(muted, background), greaterThanOrEqualTo(4.5));
    }
  });
  setUpAll(() async {
    // Optional review images use the SDK's real fonts instead of Ahem. No font
    // dependency or development-machine path is added to the application.
    if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
    final config = jsonDecode(
      await File('.dart_tool/package_config.json').readAsString(),
    ) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((package) => package['name'] == 'flutter');
    final sdk = Uri.parse('${flutter['rootUri']}/').resolve('../../');
    for (final entry in {
      'Roboto': 'bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      'MaterialIcons':
          'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    }.entries) {
      final file = File.fromUri(sdk.resolve(entry.value));
      if (await file.exists()) {
        final loader = FontLoader(entry.key)
          ..addFont(
            file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      }
    }
    final googleFont = FontLoader('GoogleSans')
      ..addFont(
        File('assets/branding/GoogleSans.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    await googleFont.load();
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetViewInsets();
  });

  testWidgets('authentication validates and retains input across modes', (
    tester,
  ) async {
    await mount(
      tester,
      const AuthScreen(),
      size: const Size(320, 640),
      scale: 1.6,
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(find.text('Use at least 6 characters.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      'secret123',
    );
    await tester.ensureVisible(
      find.text('New to SaveTrack? Create an account'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to SaveTrack? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'person@example.com',
    );
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password recovery retains existing email validation', (
    tester,
  ) async {
    await mount(tester, const AuthScreen());
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address first.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login preview', (tester) async {
    await mount(tester, const AuthScreen());
    if (const bool.fromEnvironment('SAVE_UI_PREVIEWS')) {
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/branding/google_g.png'),
          tester.element(find.byType(AuthScreen)),
        ),
      );
      await tester.pumpAndSettle();
    }
    await capture(tester, 'login');
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('goal layout keeps long names and amounts at scale $scale', (
      tester,
    ) async {
      final goal = TestDocument({
        'title': 'A home for our family and a brighter future',
        'note': 'A meaningful milestone, one contribution at a time.',
        'savedAmount': 1234567.89,
        'targetAmount': 9876543.21,
        'deadline': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 90)),
        ),
      });
      await mount(
        tester,
        scrollPage(GoalCard(uid: 'fixture', doc: goal)),
        size: const Size(320, 640),
        scale: scale,
      );
      expect(find.text('PHP 1234567.89 saved'), findsOneWidget);
      expect(find.text('PHP 9876543.21 target'), findsOneWidget);
      expect(find.text('PHP 8641975.32 to go'), findsOneWidget);
      expect(
        tester.widget<MintProgress>(find.byType(MintProgress)).value,
        closeTo(1234567.89 / 9876543.21, .00001),
      );
      await tester.tap(find.byTooltip('Goal actions'));
      await tester.pumpAndSettle();
      expect(find.text('Edit goal'), findsOneWidget);
      expect(find.text('Delete goal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('goal completed and overdue states reflect stored values', (
    tester,
  ) async {
    final completed = TestDocument({
      'title': 'Emergency fund',
      'savedAmount': 1200.0,
      'targetAmount': 1000.0,
    });
    final overdue = TestDocument({
      'title': 'Travel fund',
      'savedAmount': 100.0,
      'targetAmount': 500.0,
      'deadline': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 2)),
      ),
    });
    await mount(
      tester,
      scrollPage(
        Column(
          children: [
            GoalCard(uid: 'fixture', doc: completed),
            GoalCard(uid: 'fixture', doc: overdue),
          ],
        ),
      ),
    );
    expect(find.text('Goal reached'), findsOneWidget);
    expect(find.text('PHP 0.00 to go'), findsOneWidget);
    expect(find.text('Overdue  PHP 400.00 remaining'), findsOneWidget);
    await capture(tester, 'goals');
    expect(tester.takeException(), isNull);
  });

  testWidgets('task checkbox sends the original completion update', (
    tester,
  ) async {
    final task = TestDocument({
      'title': 'Review the household budget and plan for the week',
      'time': '9:30 AM',
      'priority': 'High',
      'completed': false,
    });
    await mount(
      tester,
      scrollPage(TaskTile(uid: 'fixture', doc: task)),
      size: const Size(320, 640),
      scale: 2,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(task.testReference.updates.single['completed'], true);
    expect(task.testReference.updates.single.containsKey('updatedAt'), true);
    expect(find.text('High priority'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports retain large values and captions without overflow', (
    tester,
  ) async {
    await mount(
      tester,
      scrollPage(
        const Column(
          children: [
            ReportMetric(
              title: 'Savings balance',
              value: 'PHP 987654321.00',
              caption: 'Across 12 goals  PHP 999999999.00 total target',
              icon: Icons.savings_outlined,
              featured: true,
              progress: .8,
            ),
            SizedBox(height: 16),
            ReportMetric(
              title: 'This week’s tasks',
              value: '123 / 456 completed',
              caption: '333 remaining',
              icon: Icons.check_circle_outline,
              progress: .27,
            ),
          ],
        ),
      ),
      size: const Size(320, 640),
      scale: 2,
    );
    expect(find.text('PHP 987654321.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final type in ['goal', 'deposit', 'task']) {
    testWidgets('$type dialog validates, scrolls over keyboard, and cancels', (
      tester,
    ) async {
      final doc = TestDocument({
        'title': 'Emergency fund',
        'targetAmount': 1000.0,
      });
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                if (type == 'goal') showGoalForm(context);
                if (type == 'deposit') showDepositForm(context, 'fixture', doc);
                if (type == 'task') showTaskForm(context);
              },
              child: const Text('Open form'),
            ),
          ),
        ),
        size: const Size(320, 640),
        scale: 1.5,
        keyboard: 260,
      );
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle();
      final submit = find.text(type == 'deposit' ? 'Add savings' : 'Save');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.text(
          type == 'goal'
              ? 'Enter a goal name.'
              : type == 'task'
              ? 'Enter a task.'
              : 'Enter an amount greater than zero.',
        ),
        findsOneWidget,
      );
      if (type == 'goal') {
        expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('edit goal retains existing fields and update callback', (
    tester,
  ) async {
    final goal = TestDocument({
      'title': 'Original name',
      'note': 'Original note',
      'targetAmount': 1000.0,
    });
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGoalForm(context, doc: goal),
            child: const Text('Edit'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Original note'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'New name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(goal.testReference.updates.single['title'], 'New name');
    expect(goal.testReference.updates.single['targetAmount'], 1000.0);
    expect(goal.testReference.updates.single['note'], 'Original note');
    expect(goal.testReference.updates.single.containsKey('savedAmount'), false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction history keeps actual amounts, notes, and dates', (
    tester,
  ) async {
    final goal = TestDocument({
      'title': 'A long goal name for our future emergency savings',
    });
    goal.testReference.records.add(
      TestDocument({
        'amount': 12345678.90,
        'note': 'Monthly contribution toward the goal',
        'date': Timestamp.fromDate(DateTime(2026, 10, 10)),
      }),
    );
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTransactionHistory(context, goal),
            child: const Text('History'),
          ),
        ),
      ),
      size: const Size(320, 640),
      scale: 2,
    );
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('+PHP 12345678.90'), findsOneWidget);
    expect(find.text('10/10/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close history'));
    await tester.pumpAndSettle();
    expect(find.text('+PHP 12345678.90'), findsNothing);
  });

  testWidgets('destructive confirmation only calls action after Delete', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                confirmDelete(context, 'Delete this task?', () async {
                  calls++;
                }),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('empty and error states work in landscape with large text', (
    tester,
  ) async {
    var called = false;
    await mount(
      tester,
      scrollPage(
        Column(
          children: [
            EmptyPanel(
              icon: Icons.event_note_outlined,
              title: 'Nothing planned yet',
              detail: 'Add a task to make a plan for this day.',
              action: 'Add a task',
              onTap: () => called = true,
            ),
            const ErrorPanel(
              message: 'Could not load your goals. Check your internet connection and try again.',
            ),
          ],
        ),
      ),
      size: const Size(640, 320),
      scale: 2,
    );
    await tester.ensureVisible(find.text('Add a task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a task'));
    expect(called, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress respects reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(body: MintProgress(value: .75)),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .75,
    );
  });
}
