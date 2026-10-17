import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_screen.dart';
import 'package:myproject/agent_studio/agent_voice.dart';
import 'package:myproject/main.dart';
import 'package:myproject/shared_savings.dart';
import 'package:myproject/shared_savings_screens.dart';

import 'agent_studio_fixtures.dart';
import 'profile_photo_firestore_backend_test.dart' show PhotoUser;
import 'redesign_test.dart' as preview;
import 'ui_preview_fonts.dart';

class ProgressAuth extends Fake implements FirebaseAuth {
  User? session;
  final changes = StreamController<User?>.broadcast(sync: true);
  @override
  User? get currentUser => session;
  @override
  Stream<User?> authStateChanges() => changes.stream;
  void switchAccount(String? uid) {
    session = uid == null ? null : PhotoUser(uid);
    changes.add(session);
  }
}

class ProgressRepository extends Fake implements SharedSavingsRepository {
  ProgressRepository(this.auth) {
    events = StreamController<List<SharedSavingsGoal>>.broadcast(
      sync: true,
      onCancel: () => cancellations++,
    );
  }
  @override
  final FirebaseAuth auth;
  @override
  String get uid => auth.currentUser!.uid;
  late final StreamController<List<SharedSavingsGoal>> events;
  int subscriptions = 0, cancellations = 0;
  @override
  Stream<List<SharedSavingsGoal>> watchGoals() {
    subscriptions++;
    return events.stream;
  }
}

SharedSavingsGoal progressGoal(String name) => SharedSavingsGoal('shared', {
  'name': name,
  'ownerId': 'owner',
  'targetAmount': 8000,
  'currentAmount': 1000,
  'totalDeposits': 1000,
  'totalDecreases': 0,
  'personalDeposits': {'owner': 500},
  'startDate': Timestamp.fromDate(DateTime(2026, 10, 1)),
  'deadline': Timestamp.fromDate(DateTime(2027, 12, 31)),
  'memberCount': 2,
  'status': 'active',
});

Widget progressReport() => Scaffold(
  appBar: AppBar(title: const Text('Reports')),
  body: const PageSurface(
    child: ReportsLayout(
      savings: ReportMetric(
        title: 'Savings balance',
        value: 'PHP ₱1,000.00',
        caption: 'Across 2 personal goals · PHP ₱8,000.00 total target.',
        icon: Icons.savings_outlined,
        featured: true,
        progress: .125,
      ),
      shared: SharedGoalsPanel(report: true),
      daily: ReportMetric(
        title: 'Today’s tasks',
        value: '1 / 2 completed',
        caption: '1 remaining',
        icon: Icons.check_circle_outline,
        progress: .5,
      ),
      weekly: ReportMetric(
        title: 'This week’s tasks',
        value: '2 / 4 completed',
        caption: '2 remaining',
        icon: Icons.date_range_outlined,
        progress: .5,
      ),
      goals: Text('Personal goal progress'),
    ),
  ),
);

void main() {
  setUpAll(loadManropeForPreviews);
  late ProgressAuth auth;
  late Map<String, ProgressRepository> repositories;
  setUp(() {
    auth = ProgressAuth()..session = PhotoUser('owner');
    repositories = {};
  });
  tearDown(() async {
    await auth.changes.close();
    for (final repository in repositories.values) {
      await repository.events.close();
    }
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget home, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    await tester.pumpWidget(
      MaterialApp(
        theme: SaveTrackDesign.theme,
        builder: (context, navigator) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: preview.previewKey,
            child: SharedSavingsHost(
              auth: auth,
              repositoryForUser: (user) => repositories.putIfAbsent(
                user.uid,
                () => ProgressRepository(auth),
              ),
              child: navigator!,
            ),
          ),
        ),
        home: home,
      ),
    );
    await tester.pump();
  }

  for (final config in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'Review my progress retains shared state across routes at ${config.$1}',
      (tester) async {
        final engine = testEngine();
        await enableAgent(engine);
        final voice = AgentVoiceController(FakeAgentVoice());
        addTearDown(() {
          engine.dispose();
          voice.dispose();
        });
        await mount(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AgentStudioScreen(
                      engine: engine,
                      voice: voice,
                      onOpen: (context, destination, id, amount) async {
                        expect(destination, 'reports');
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => progressReport(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                child: const Text('Open Agent Studio'),
              ),
            ),
          ),
          width: config.$1,
          scale: config.$2,
        );
        final repository = repositories['owner']!;
        repository.events.add([]);
        await tester.tap(find.text('Open Agent Studio'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Review my progress'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('Review my progress'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Review my progress'));
        await tester.pumpAndSettle();
        expect(find.text('Progress, in perspective.'), findsOneWidget);
        expect(find.text('PHP ₱1,000.00'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Shared savings'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Start saving together.'), findsOneWidget);
        expect(repository.subscriptions, 1);
        expect(find.byType(ErrorWidget), findsNothing);
        expect((engine.backend as FakeAgentBackend).calls, isEmpty);
        await preview.capture(
          tester,
          'agent-progress-reports-${config.$1.toInt()}',
        );

        repository.events.add([progressGoal('College together')]);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('College together'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('College together'), findsOneWidget);
        expect(repository.subscriptions, 1);
        await tester.scrollUntilVisible(
          find.text('Planning rhythm'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Today’s tasks'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Agent Studio'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(repository.cancellations, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(repository.cancellations, 1);
        expect(auth.changes.hasListener, false);
      },
    );
  }

  testWidgets('shared report errors retain personal and planning sections', (
    tester,
  ) async {
    await mount(tester, progressReport());
    repositories['owner']!.events.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Your access may have changed'), findsOneWidget);
    expect(find.text('PHP ₱1,000.00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Planning rhythm'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Today’s tasks'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reports remain usable while shared savings is loading', (
    tester,
  ) async {
    await mount(tester, progressReport());
    expect(find.byType(AuroraLoadingSurface), findsOneWidget);
    expect(find.text('PHP ₱1,000.00'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
    repositories['owner']!.events.add([]);
    await tester.pumpAndSettle();
    expect(find.byType(AuroraLoadingSurface), findsNothing);
    expect(find.text('Shared savings'), findsOneWidget);
    expect(find.text('Start saving together.'), findsOneWidget);
    expect(repositories['owner']!.subscriptions, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'global shared host replaces listeners on account changes and sign-out',
    (tester) async {
      auth.session = null;
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) {
              final controller = context
                  .dependOnInheritedWidgetOfExactType<SharedSavingsScope>()
                  ?.notifier;
              return Text(
                controller == null
                    ? 'Signed out'
                    : '${controller.repository.uid}: ${controller.goals.map((g) => g.name).join(',')}',
              );
            },
          ),
        ),
      );
      expect(repositories, isEmpty);
      expect(find.text('Signed out'), findsOneWidget);
      auth.switchAccount('owner');
      await tester.pump();
      final first = repositories['owner']!;
      first.events.add([progressGoal('Private owner goal')]);
      await tester.pump();
      expect(find.text('owner: Private owner goal'), findsOneWidget);
      auth.switchAccount('owner');
      await tester.pump();
      expect(first.subscriptions, 1);
      auth.switchAccount('other');
      await tester.pump();
      expect(first.cancellations, 1);
      expect(find.text('other: '), findsOneWidget);
      first.events.add([progressGoal('Old account update')]);
      await tester.pump();
      expect(find.textContaining('Old account update'), findsNothing);
      expect(find.textContaining('Private owner goal'), findsNothing);
      final other = repositories['other']!;
      auth.switchAccount(null);
      await tester.pump();
      expect(other.cancellations, 1);
      expect(find.text('Signed out'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(auth.changes.hasListener, false);
    },
  );

  testWidgets('auth stream failures clear private shared state', (
    tester,
  ) async {
    await mount(
      tester,
      Builder(
        builder: (context) => Text(
          context.dependOnInheritedWidgetOfExactType<SharedSavingsScope>() ==
                  null
              ? 'Signed out'
              : 'Signed in',
        ),
      ),
    );
    expect(find.text('Signed in'), findsOneWidget);
    auth.changes.addError(StateError('session unavailable'));
    await tester.pump();
    expect(repositories['owner']!.cancellations, 1);
    expect(find.text('Signed out'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
