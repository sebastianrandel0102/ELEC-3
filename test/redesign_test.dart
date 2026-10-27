// The sealed Firestore interfaces are implemented only as test doubles; the
// application continues to use the original Firebase SDK objects.
// ignore_for_file: subtype_of_sealed_class

import 'ui_preview_fonts.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/main.dart';

import 'profile_photo_firestore_backend_test.dart'
    show PhotoAuth, PhotoDatabase;

Future<void> showTestGoalForm(
  BuildContext context, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) => showGoalForm(
  context,
  doc: doc,
  auth: PhotoAuth(),
  firestore: PhotoDatabase(),
);

// These fixtures exercise presentation and callbacks without a live account.
class TestReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final updates = <Map<String, dynamic>>[];
  final records = <TestDocument>[];
  @override
  String get id => 'fixture_request';
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => const Stream.empty();
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
  String get id => 'preview_record';
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
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      TestReference();
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
                fontFamily: 'Manrope',
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
      Color.alphaBlend(SaveTrackDesign.heroHighlight, SaveTrackDesign.heroEnd),
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
    await loadManropeForPreviews();
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

  testWidgets('password recovery opens the email reset modal', (tester) async {
    await mount(tester, const AuthScreen());
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('New Password'), findsNothing);
    await capture(tester, 'password-recovery');
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
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
      expect(find.text('PHP ₱1,234,567.89 saved'), findsOneWidget);
      expect(find.text('PHP ₱9,876,543.21 target'), findsOneWidget);
      expect(find.text('PHP ₱8,641,975.32 to go'), findsOneWidget);
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
    expect(find.text('PHP ₱0.00 to go'), findsOneWidget);
    expect(find.text('Overdue  PHP ₱400.00 remaining'), findsOneWidget);
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
              value: 'PHP ₱987,654,321.00',
              caption: 'Across 12 goals  PHP ₱999,999,999.00 total target',
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
    expect(find.text('PHP ₱987,654,321.00'), findsOneWidget);
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
                if (type == 'goal') showTestGoalForm(context);
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
            onPressed: () => showTestGoalForm(context, doc: goal),
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
    expect(find.text('+PHP ₱12,345,678.90'), findsOneWidget);
    expect(find.textContaining('Oct 10, 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'history-populated-narrow');
    await tester.tap(find.byTooltip('Close history'));
    await tester.pumpAndSettle();
    expect(find.text('+PHP ₱12,345,678.90'), findsNothing);
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
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      .75,
    );
  });

  testWidgets('all five navigation destinations retain selection callbacks', (
    tester,
  ) async {
    var selected = 0;
    final calls = <int>[];
    await mount(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: SaveTrackNavigation(
            selectedIndex: selected,
            onSelected: (index) => setState(() {
              selected = index;
              calls.add(index);
            }),
          ),
        ),
      ),
      size: const Size(320, 640),
      scale: 2,
    );
    for (final label in ['Today', 'Goals', 'Planner', 'Reports', 'Profile']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(calls, [0, 1, 2, 3, 4]);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account layout preserves security and logout actions with long identity',
    (tester) async {
      var passwordCalls = 0, logoutCalls = 0;
      await mount(
        tester,
        Scaffold(
          body: PageSurface(
            child: ProfileContent(
              name: 'A very long account name that must remain readable on a small phone',
              email: 'a.long.email.address@example.com',
              onPassword: () => passwordCalls++,
              onSignOut: () => logoutCalls++,
            ),
          ),
        ),
        size: const Size(320, 640),
        scale: 2,
      );
      await tester.scrollUntilVisible(find.text('Currency Settings'), 300);
      expect(find.text('Currency Settings'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Change Password'), 300);
      await Scrollable.ensureVisible(
        tester.element(find.text('Change Password')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change Password'));
      await tester.scrollUntilVisible(find.text('Sign out'), 300);
      await tester.ensureVisible(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      expect(passwordCalls, 1);
      expect(logoutCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account initials handle empty display names', (tester) async {
    await mount(
      tester,
      Scaffold(
        body: ProfileContent(
          name: '',
          email: '',
          onPassword: () {},
          onSignOut: () {},
        ),
      ),
    );
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(1280, 800),
    const Size(640, 320),
  ]) {
    testWidgets(
      'dashboard composition adapts to $size and retains tab actions',
      (tester) async {
        var goalCalls = 0, plannerCalls = 0;
        final scale = size.width == 1280 ? 1.0 : 2.0;
        await mount(
          tester,
          Scaffold(
            body: PageSurface(
              child: DashboardLayout(
                header: const ScreenIntro(
                  eyebrow: 'Today',
                  title: 'Hello, Alex',
                  detail: 'A little progress adds up.',
                ),
                savings: const SavingsOverview(
                  total: 987654321,
                  target: 999999999,
                  count: 123,
                ),
                metrics: const SizedBox.shrink(),
                goals: const SizedBox.shrink(),
                tasks: const SizedBox.shrink(),
                onGoals: () => goalCalls++,
                onPlanner: () => plannerCalls++,
              ),
            ),
          ),
          size: size,
          scale: scale,
        );
        await tester.scrollUntilVisible(
          find.text('PHP ₱987,654,321.00'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('PHP ₱987,654,321.00'), findsOneWidget);
        expect(
          tester.widget<MintProgress>(find.byType(MintProgress)).value,
          closeTo(987654321 / 999999999, .00001),
        );
        await tester.scrollUntilVisible(
          find.text('See all'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('See all')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('See all'));
        await tester.scrollUntilVisible(
          find.text('Open planner'),
          size.width == 1280 ? -300 : 300,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Open planner')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open planner'));
        expect(goalCalls, 1);
        expect(plannerCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('planner header keeps date navigation and works in landscape', (
    tester,
  ) async {
    final calls = <String>[];
    await mount(
      tester,
      scrollPage(
        Column(
          children: [
            PlannerDateHeader(
              title: 'Today  11/10/2026',
              onPrevious: () => calls.add('previous'),
              onNext: () => calls.add('next'),
              onToday: () => calls.add('today'),
            ),
            const DailyCompletion(done: 3, total: 4),
          ],
        ),
      ),
      size: const Size(640, 320),
      scale: 2,
    );
    for (final label in ['Previous day', 'Next day']) {
      await tester.ensureVisible(find.byTooltip(label));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(label));
    }
    await tester.ensureVisible(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.ensureVisible(find.text('3 of 4 tasks completed'));
    expect(calls, ['previous', 'next', 'today']);
    expect(tester.widget<MintProgress>(find.byType(MintProgress)).value, .75);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal collection reflows without changing item order', (
    tester,
  ) async {
    Widget list() => Scaffold(
      body: PageSurface(
        child: AdaptiveCardList(
          itemCount: 50,
          header: const Text('Milestones'),
          itemBuilder: (_, index) => Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Goal $index'),
            ),
          ),
        ),
      ),
    );
    await mount(tester, list(), size: const Size(1280, 800));
    expect(
      tester.getTopLeft(find.text('Goal 0')).dy,
      tester.getTopLeft(find.text('Goal 1')).dy,
    );
    expect(
      tester.getTopLeft(find.text('Goal 0')).dx,
      lessThan(tester.getTopLeft(find.text('Goal 1')).dx),
    );
    await mount(tester, list(), size: const Size(320, 640), scale: 2);
    expect(
      tester.getTopLeft(find.text('Goal 0')).dy,
      lessThan(tester.getTopLeft(find.text('Goal 1')).dy),
    );
    await tester.scrollUntilVisible(find.text('Goal 49'), 500);
    expect(find.text('Goal 49'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wide authentication keeps the complete form and registration flow',
    (tester) async {
      await mount(tester, const AuthScreen(), size: const Size(1280, 800));
      await capture(tester, 'login-wide');
      await tester.ensureVisible(
        find.text('New to SaveTrack? Create an account'),
      );
      await tester.tap(find.text('New to SaveTrack? Create an account'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Big plans.\nStart right here.'), findsOneWidget);
      await capture(tester, 'registration-wide');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('session loading and narrow error surfaces support large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 320);
    await tester.pumpWidget(
      MaterialApp(
        theme: const bool.fromEnvironment('SAVE_UI_PREVIEWS')
            ? SaveTrackDesign.theme.copyWith(
                textTheme: SaveTrackDesign.theme.textTheme.apply(
                  fontFamily: 'Manrope',
                ),
              )
            : SaveTrackDesign.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: RepaintBoundary(key: previewKey, child: child!),
        ),
        home: const Scaffold(body: SessionLoading()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('SaveTrack'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    await capture(tester, 'session-loading');
    await mount(
      tester,
      scrollPage(
        const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 120,
            child: ErrorPanel(
              message: 'Could not load this information. Please try again.',
            ),
          ),
        ),
      ),
      size: const Size(320, 640),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium screen and modal visual previews', (tester) async {
    final goal = TestDocument({
      'title': 'Emergency fund',
      'savedAmount': 12500.0,
      'targetAmount': 50000.0,
      'note': 'A little peace of mind.',
    });
    final task = TestDocument({
      'title': 'Review this week\u2019s budget',
      'time': '9:30 AM',
      'priority': 'High',
      'completed': false,
    });
    await mount(
      tester,
      Scaffold(
        body: PageSurface(
          child: DashboardLayout(
            header: const ScreenIntro(
              eyebrow: 'Today  11/10/2026',
              title: 'Hello, Alex',
              detail: 'A little progress adds up.',
            ),
            savings: const SavingsOverview(
              total: 12500,
              target: 50000,
              count: 1,
            ),
            metrics: Row(
              children: [
                Expanded(
                  child: SummaryTile(
                    icon: Icons.flag_outlined,
                    label: 'Active goals',
                    stream: Stream.value(TestSnapshot([goal])),
                    count: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryTile(
                    icon: Icons.check_circle_outline,
                    label: 'Done today',
                    stream: Stream.value(TestSnapshot([task])),
                    count: false,
                  ),
                ),
              ],
            ),
            goals: GoalCard(uid: 'fixture', doc: goal),
            tasks: TaskTile(uid: 'fixture', doc: task),
            onGoals: () {},
            onPlanner: () {},
          ),
        ),
        bottomNavigationBar: SaveTrackNavigation(
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ),
    );
    await capture(tester, 'dashboard');
    await mount(
      tester,
      scrollPage(
        Column(
          children: [
            PlannerDateHeader(
              title: 'Today  11/10/2026',
              onPrevious: () {},
              onNext: () {},
              onToday: () {},
            ),
            const DailyCompletion(done: 0, total: 1),
            const SizedBox(height: 24),
            TaskTile(uid: 'fixture', doc: task),
          ],
        ),
      ),
    );
    await capture(tester, 'planner');
    await mount(
      tester,
      scrollPage(
        const Column(
          children: [
            ScreenIntro(
              eyebrow: 'Your progress',
              title: 'See how far you\u2019ve come.',
              detail: 'Your savings and planning, at a glance.',
            ),
            ReportMetric(
              title: 'Savings balance',
              value: 'PHP ₱12,500.00',
              caption: 'Across 1 goals  PHP ₱50,000.00 total target',
              icon: Icons.savings_outlined,
              featured: true,
              progress: .25,
            ),
            SizedBox(height: 24),
            ReportMetric(
              title: 'Today\u2019s tasks',
              value: '0 / 1 completed',
              caption: '1 remaining',
              icon: Icons.check_circle_outline,
              progress: 0,
            ),
          ],
        ),
      ),
    );
    await capture(tester, 'reports');
    await mount(
      tester,
      Scaffold(
        body: PageSurface(
          child: ProfileContent(
            name: 'Alex Rivera',
            email: 'alex@example.com',
            onPassword: () {},
            onSignOut: () {},
          ),
        ),
      ),
    );
    await capture(tester, 'profile');
    for (final type in ['goal', 'deposit', 'task', 'history']) {
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                if (type == 'goal') showTestGoalForm(context);
                if (type == 'deposit') {
                  showDepositForm(context, 'fixture', goal);
                }
                if (type == 'task') showTaskForm(context);
                if (type == 'history') showTransactionHistory(context, goal);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await capture(tester, '$type-form');
      expect(tester.takeException(), isNull);
      if (type == 'history') {
        await tester.tap(find.byTooltip('Close history'));
      } else {
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Cancel'));
      }
      await tester.pumpAndSettle();
    }
  });
}
