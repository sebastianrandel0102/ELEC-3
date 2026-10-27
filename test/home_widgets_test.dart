import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/currency_money.dart';
import 'package:myproject/currency_savings_dialog.dart';
import 'package:myproject/design_system.dart';
import 'package:myproject/home_widgets/widget_bridge.dart';
import 'package:myproject/home_widgets/widget_controller.dart';
import 'package:myproject/home_widgets/widget_data_source.dart';
import 'package:myproject/home_widgets/widget_host.dart';
import 'package:myproject/home_widgets/widget_models.dart';
import 'package:myproject/home_widgets/widget_settings_screen.dart';
import 'package:myproject/smart_task_recommendation_service.dart';

final now = DateTime(2026, 10, 16, 10);
const goalRef = WidgetGoalRef('motorcycle');
HomeWidgetConfig config({
  int id = 42,
  HomeWidgetType type = HomeWidgetType.goal,
  WidgetPrivacy privacy = WidgetPrivacy.full,
  String currency = 'PHP',
  bool titles = false,
  List<String> presets = const [],
}) => HomeWidgetConfig(
  id: id,
  type: type,
  uid: 'alice',
  goal: type == HomeWidgetType.planner ? null : goalRef,
  privacy: privacy,
  currency: type == HomeWidgetType.planner ? null : currency,
  showTaskTitles: titles,
  presets: presets,
  revision: 1,
);
WidgetGoalFacts facts({
  String saved = '12000',
  String target = '30000',
  String currency = 'PHP',
  DateTime? deadline,
  bool archived = false,
}) => WidgetGoalFacts(
  ref: goalRef,
  title: 'Motorcycle Fund',
  saved: ExactDecimal.parse(saved),
  target: ExactDecimal.parse(target),
  currency: currency,
  deadline: deadline,
  archived: archived,
);
Map<String, dynamic> snapshot({
  HomeWidgetConfig? settings,
  WidgetGoalFacts? goal,
  WidgetPlannerFacts? planner,
}) => HomeWidgetSnapshot.build(
  config: settings ?? config(),
  now: now,
  goal: goal ?? facts(),
  planner: planner,
).data;

class FakeBridge extends HomeWidgetBridge {
  FakeBridge() : super(supported: false);
  List<HomeWidgetInstance> installed = [];
  final List<HomeWidgetSnapshot> published = [];
  final List<String?> sessions = [];
  @override
  Future<void> setSession(String? uid) async {
    sessions.add(uid);
    if (uid == null) {
      installed = installed
          .map((i) => HomeWidgetInstance(i.id, i.type, null))
          .toList();
    }
  }

  @override
  Future<List<HomeWidgetInstance>> instances() async => installed;
  @override
  Future<void> publish(String uid, List<HomeWidgetSnapshot> snapshots) async {
    published.addAll(snapshots);
  }

  @override
  Future<HomeWidgetConfig> save(HomeWidgetConfig config) async {
    installed = installed
        .map(
          (i) =>
              i.id == config.id ? HomeWidgetInstance(i.id, i.type, config) : i,
        )
        .toList();
    return config;
  }
}

class FakeSource implements WidgetDataSource {
  final goals = <String, StreamController<WidgetGoalFacts?>>{};
  final planners = <String, StreamController<WidgetPlannerFacts>>{};
  final subscriptions = <String, int>{};
  List<WidgetGoalFacts> available = [facts()];
  @override
  Stream<WidgetGoalFacts?> watchGoal(String uid, WidgetGoalRef ref) {
    subscriptions.update(ref.key, (n) => n + 1, ifAbsent: () => 1);
    return (goals[ref.key] ??= StreamController<WidgetGoalFacts?>.broadcast())
        .stream;
  }

  @override
  Stream<WidgetPlannerFacts> watchPlanner(String uid, String day) {
    subscriptions.update(day, (n) => n + 1, ifAbsent: () => 1);
    return (planners[day] ??= StreamController<WidgetPlannerFacts>.broadcast())
        .stream;
  }

  @override
  Future<List<WidgetGoalFacts>> choices(String uid) async => available;
  @override
  Future<Uint8List?> thumbnail(String uid, WidgetGoalFacts goal) async => null;
  Future<void> close() async {
    for (final stream in [...goals.values, ...planners.values]) {
      await stream.close();
    }
  }
}

void main() {
  group('exact savings snapshots', () {
    for (final entry in [
      ('0', '30000', 0),
      ('12000', '30000', 40),
      ('30000', '30000', 100),
      ('36000', '30000', 100),
      ('0', '0', 0),
    ]) {
      test('${entry.$1} / ${entry.$2} follows existing clamped progress', () {
        final goal =
            snapshot(
                  goal: facts(saved: entry.$1, target: entry.$2),
                )['goal']
                as Map;
        expect(goal['percent'], entry.$3);
        expect(goal['progress'], inInclusiveRange(0, 1000));
        if (entry.$1 == '36000') {
          expect(goal['saved'], 'PHP ₱36,000.00');
          expect(goal['remaining'], 'PHP ₱0.00');
        }
      });
    }
    test('withdrawals and remaining retain decimal precision', () {
      final goal =
          snapshot(
                goal: facts(saved: '0.10', target: '0.30'),
              )['goal']
              as Map;
      expect(goal['remaining'], 'PHP ₱0.20');
      expect(goal['saved'], 'PHP ₱0.10');
    });
    for (final currency in ['PHP', 'USD', 'EUR', 'JPY', 'KWD']) {
      test('$currency uses existing formatting without conversion', () {
        final goal = facts(currency: currency, saved: '15', target: '100');
        final data =
            snapshot(
                  settings: config(currency: currency),
                  goal: goal,
                )['goal']
                as Map;
        expect(data['saved'], formatCurrency(goal.saved, currency));
      });
    }
    test('missing deadlines are absent, overdue/completed/archived statuses are honest', () {
      expect((snapshot()['goal'] as Map).containsKey('deadline'), false);
      expect(
        (snapshot(goal: facts(deadline: DateTime(2026, 10, 15)))['goal']
            as Map)['status'],
        'Overdue',
      );
      expect(
        (snapshot(goal: facts(saved: '30000'))['goal'] as Map)['status'],
        'Completed',
      );
      final goal = snapshot(goal: facts(archived: true))['goal'] as Map;
      expect(goal['status'], 'Archived');
      expect(goal['canSave'], false);
    });
    test('deleted and invalid financial data have no private goal payload', () {
      final missing = HomeWidgetSnapshot.build(config: config(), now: now).data;
      expect(missing['state'], 'unavailable');
      expect(missing.containsKey('goal'), false);
      final invalid = snapshot(goal: facts(saved: '-1'));
      expect(invalid['state'], 'unavailable');
      expect(invalid.containsKey('goal'), false);
    });
    test('currency changes disable shortcuts until reconfiguration', () {
      expect(
        (snapshot(goal: facts(currency: 'USD'))['goal'] as Map)['canSave'],
        false,
      );
    });
  });
  group('privacy and planner semantics', () {
    final tasks = [
      const PlannerTask(
        id: 'normal',
        dateKey: '2026-10-16',
        title: 'Private normal task',
      ),
      const PlannerTask(
        id: 'high',
        dateKey: '2026-10-16',
        title: 'Private high task',
        priority: 'High',
        time: '09:00',
      ),
      const PlannerTask(
        id: 'done',
        dateKey: '2026-10-16',
        title: 'Finished',
        completed: true,
      ),
      const PlannerTask(id: 'old', dateKey: '2026-10-15', title: 'Yesterday'),
    ];
    final planner = WidgetPlannerFacts(tasks, '2026-10-16');
    test(
      'today counts and task ordering match SmartTaskRecommendationService',
      () {
        final data =
            snapshot(
                  settings: config(type: HomeWidgetType.today, titles: true),
                  planner: planner,
                )['planner']
                as Map;
        expect(data['total'], 3);
        expect(data['done'], 1);
        expect(data['remaining'], 2);
        final expected = SmartTaskRecommendationService(clock: () => now)
            .recommend(tasks: tasks, selectedDate: now);
        expect(
          (data['tasks'] as List).map((t) => t['id']),
          expected.recommendations.map((r) => r.task.id),
        );
        expect(jsonEncode(data), isNot(contains('Yesterday')));
      },
    );
    test('empty day differs from an unavailable/stale day', () {
      final empty =
          snapshot(
                settings: config(type: HomeWidgetType.planner),
                planner: const WidgetPlannerFacts([], '2026-10-16'),
              )['planner']
              as Map;
      expect(empty['total'], 0);
      expect(empty['state'], 'ready');
      final stale =
          snapshot(
                settings: config(type: HomeWidgetType.planner),
                planner: const WidgetPlannerFacts([], '2026-10-15'),
              )['planner']
              as Map;
      expect(stale['state'], 'refresh');
      expect(stale.containsKey('total'), false);
    });
    test(
      'task titles require explicit full-details and task-title opt-ins',
      () {
        final private = snapshot(
          settings: config(type: HomeWidgetType.today),
          planner: planner,
        );
        expect((private['planner'] as Map)['tasks'], isEmpty);
        final visible = snapshot(
          settings: config(type: HomeWidgetType.today, titles: true),
          planner: planner,
        );
        expect(jsonEncode(visible), contains('Private high task'));
      },
    );
    for (final privacy in [WidgetPrivacy.progress, WidgetPrivacy.hidden]) {
      test('$privacy strips details before native storage', () {
        final data = snapshot(
          settings: config(
            type: HomeWidgetType.today,
            titles: true,
            privacy: privacy,
          ),
          planner: planner,
        );
        final raw = jsonEncode(data);
        for (final secret in [
          'Motorcycle',
          'Private high',
          '12,000',
          '30,000',
          'savedAmount',
          'notes',
        ]) {
          expect(raw, isNot(contains(secret)));
        }
        if (privacy == WidgetPrivacy.hidden) {
          expect(data.containsKey('goal'), false);
          expect(data.containsKey('planner'), false);
        }
      });
    }
    test(
      'cached data is marked without inventing a server confirmation time',
      () {
        final data = snapshot(
          settings: config(type: HomeWidgetType.planner),
          planner: const WidgetPlannerFacts([], '2026-10-16', cached: true),
        );
        expect(data['cached'], true);
        expect(data.containsKey('confirmedAt'), false);
      },
    );
  });
  group('configuration and launch validation', () {
    test('configuration round-trips independently per instance', () {
      final first = HomeWidgetConfig.fromMap(
        config(presets: ['0.10', '50.00']).toMap(),
      );
      final second = HomeWidgetConfig.fromMap(
        config(id: 43, privacy: WidgetPrivacy.hidden).toMap(),
      );
      expect(first.id, 42);
      expect(second.id, 43);
      expect(first.presets, ['0.10', '50.00']);
      expect(second.privacy, WidgetPrivacy.hidden);
    });
    for (final preset in ['-1', '0', '1.001', 'NaN', '1e3']) {
      test(
        'rejects invalid PHP shortcut $preset',
        () => expect(
          () => config(presets: [preset]).validate(),
          throwsFormatException,
        ),
      );
    }
    test(
      'rejects precision unsuitable for JPY',
      () => expect(
        () => config(currency: 'JPY', presets: ['1.50']).validate(),
        throwsFormatException,
      ),
    );
    test('rejects invalid schemas and goal paths', () {
      expect(
        () => HomeWidgetConfig.fromMap({
          ...config().toMap(),
          'schemaVersion': 99,
        }),
        throwsFormatException,
      );
      expect(
        () => WidgetGoalRef.fromMap({'id': '../other', 'shared': false}),
        throwsFormatException,
      );
    });
    test('launches contain only a valid installed identifier and bounded action arguments', () {
      expect(
        WidgetLaunch.parse({'id': 42, 'action': 'save', 'preset': 1})?.preset,
        1,
      );
      for (final raw in [
        null,
        {'id': -1, 'action': 'save'},
        {'id': 42, 'action': 'deposit'},
        {'id': 42, 'action': 'save', 'preset': -1},
        {'id': 42, 'action': 'task', 'taskId': 'a/b'},
        {'id': 42, 'action': 'task'},
      ]) {
        expect(WidgetLaunch.parse(raw), null);
      }
    });
  });
  group('event-driven synchronization', () {
    late FakeBridge bridge;
    late FakeSource source;
    late HomeWidgetController controller;
    setUp(() {
      bridge = FakeBridge();
      source = FakeSource();
      controller = HomeWidgetController(
        bridge: bridge,
        source: source,
        clock: () => now,
      );
    });
    tearDown(() async {
      controller.dispose();
      await source.close();
    });
    test('no installed widgets create no data subscriptions', () async {
      await controller.switchAccount('alice');
      expect(source.subscriptions, isEmpty);
    });
    test('multiple instances share one goal stream and publish independent privacy', () async {
      bridge.installed = [
        HomeWidgetInstance(42, HomeWidgetType.goal, config()),
        HomeWidgetInstance(
          43,
          HomeWidgetType.goal,
          config(id: 43, privacy: WidgetPrivacy.progress),
        ),
      ];
      await controller.switchAccount('alice');
      expect(source.subscriptions[goalRef.key], 1);
      source.goals[goalRef.key]!.add(facts());
      await Future<void>.delayed(Duration.zero);
      await controller.flush();
      expect(bridge.published.map((s) => s.data['id']), containsAll([42, 43]));
      expect(
        jsonEncode(bridge.published.last.data),
        isNot(contains('Motorcycle')),
      );
    });
    test('goal changes do not repaint unrelated planner instances', () async {
      bridge.installed = [
        HomeWidgetInstance(42, HomeWidgetType.goal, config()),
        HomeWidgetInstance(
          43,
          HomeWidgetType.planner,
          config(id: 43, type: HomeWidgetType.planner),
        ),
      ];
      await controller.switchAccount('alice');
      await controller.flush();
      bridge.published.clear();
      source.goals[goalRef.key]!.add(facts(saved: '100'));
      await Future<void>.delayed(Duration.zero);
      await controller.flush();
      expect(bridge.published.map((s) => s.data['id']), [42]);
    });
    test('permission error immediately replaces private snapshot with unavailable state', () async {
      bridge.installed = [
        HomeWidgetInstance(42, HomeWidgetType.goal, config()),
      ];
      await controller.switchAccount('alice');
      source.goals[goalRef.key]!.add(facts());
      await Future<void>.delayed(Duration.zero);
      await controller.flush();
      source.goals[goalRef.key]!.addError(StateError('permission-denied'));
      await Future<void>.delayed(Duration.zero);
      expect(bridge.published.last.data['state'], 'unavailable');
      expect(bridge.published.last.data.containsKey('goal'), false);
    });
    test(
      'logout clears account binding before new data can be published',
      () async {
        bridge.installed = [
          HomeWidgetInstance(42, HomeWidgetType.goal, config()),
        ];
        await controller.switchAccount('alice');
        await controller.switchAccount(null);
        expect(bridge.sessions, ['alice', null]);
        expect(controller.instances, isEmpty);
        final count = bridge.published.length;
        source.goals[goalRef.key]!.add(facts());
        await Future<void>.delayed(Duration.zero);
        await controller.flush();
        expect(bridge.published.length, count);
      },
    );
    test('date rollover replaces the planner subscription and invalidates yesterday', () async {
      var clock = now;
      controller.dispose();
      controller = HomeWidgetController(
        bridge: bridge,
        source: source,
        clock: () => clock,
      );
      bridge.installed = [
        HomeWidgetInstance(
          42,
          HomeWidgetType.planner,
          config(type: HomeWidgetType.planner),
        ),
      ];
      await controller.switchAccount('alice');
      clock = DateTime(2026, 10, 17);
      controller.checkDate();
      await controller.flush();
      expect(
        source.subscriptions.keys,
        containsAll(['2026-10-16', '2026-10-17']),
      );
      expect(
        (bridge.published.last.data['planner'] as Map)['state'],
        'refresh',
      );
    });
  });
  testWidgets('Quick Save prefill does not call the transaction callback', (
    tester,
  ) async {
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: SaveTrackDesign.theme,
        home: Scaffold(
          body: CurrencySavingsDialog(
            initialGoal: const {
              'title': 'Motorcycle Fund',
              'savedAmount': 0,
              'targetAmount': 100,
              'currencyCode': 'USD',
            },
            goalUpdates: const Stream.empty(),
            initialAmount: '12.34',
            onConfirm: (_, _) async {
              writes++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12.34'), findsOneWidget);
    expect(writes, 0);
  });
  testWidgets('configuration remains readable at narrow width and large text', (
    tester,
  ) async {
    final bridge = FakeBridge()
      ..installed = [HomeWidgetInstance(42, HomeWidgetType.goal, config())];
    final source = FakeSource();
    final controller = HomeWidgetController(
      bridge: bridge,
      source: source,
      clock: () => now,
    );
    await controller.switchAccount('alice');
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      controller.dispose();
      unawaited(source.close());
    });
    await tester.pumpWidget(
      HomeWidgetScope(
        controller: controller,
        child: MaterialApp(
          theme: SaveTrackDesign.theme,
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
            child: child!,
          ),
          home: WidgetConfigurationScreen(instance: bridge.installed.first),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    expect(find.text('Customize Your Widget'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Save Widget'), 600);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Today preview keeps both summaries readable without leaking hidden details',
    (tester) async {
      for (final width in [280.0, 360.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(1.7),
                    ),
                    child: WidgetPreviewCard(
                      type: HomeWidgetType.today,
                      privacy: WidgetPrivacy.progress,
                      goal: facts(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Savings'), findsOneWidget);
        expect(find.text('Today’s focus'), findsOneWidget);
        expect(find.text('40%'), findsOneWidget);
        expect(find.text('Motorcycle Fund'), findsNothing);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetPreviewCard(
              type: HomeWidgetType.today,
              privacy: WidgetPrivacy.hidden,
              goal: facts(),
            ),
          ),
        ),
      );
      expect(find.text('Open SaveTrack'), findsOneWidget);
      expect(find.text('40%'), findsNothing);
      expect(find.text('Today’s focus'), findsNothing);
    },
  );
  testWidgets('all Atelier previews support themes, sizes and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    for (final type in HomeWidgetType.values) {
      for (final size in WidgetPreviewSize.values) {
        for (final theme in [
          WidgetTheme.mint,
          WidgetTheme.emerald,
          WidgetTheme.system,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MediaQuery(
                    data: const MediaQueryData(
                      platformBrightness: Brightness.dark,
                      textScaler: TextScaler.linear(1.7),
                    ),
                    child: WidgetPreviewCard(
                      type: type,
                      size: size,
                      theme: theme,
                      privacy: WidgetPrivacy.full,
                      goal: facts(),
                      presets: const ['50.00', '100.00'],
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$type $size $theme');
        }
      }
    }
  });
  testWidgets(
    'studio previews stay local until Save and Cancel preserves the instance',
    (tester) async {
      final first = HomeWidgetInstance(42, HomeWidgetType.goal, config());
      final second = HomeWidgetInstance(
        43,
        HomeWidgetType.planner,
        config(id: 43, type: HomeWidgetType.planner),
      );
      final bridge = FakeBridge()..installed = [first, second];
      final source = FakeSource();
      final controller = HomeWidgetController(
        bridge: bridge,
        source: source,
        clock: () => now,
      );
      await controller.switchAccount('alice');
      addTearDown(() {
        controller.dispose();
        unawaited(source.close());
      });
      await tester.pumpWidget(
        HomeWidgetScope(
          controller: controller,
          child: MaterialApp(
            theme: SaveTrackDesign.theme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Configure'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => WidgetConfigurationScreen(
                        instance: bridge.installed.first,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();
      expect(find.text('Compact'), findsNothing);
      expect(find.text('Medium'), findsNothing);
      expect(find.text('Expanded'), findsNothing);
      await tester.scrollUntilVisible(find.text('Light'), 350);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(bridge.installed.first.config!.theme, WidgetTheme.emerald);
      await tester.scrollUntilVisible(find.byType(WidgetPreviewCard), -350);
      expect(
        tester.widget<WidgetPreviewCard>(find.byType(WidgetPreviewCard)).theme,
        WidgetTheme.mint,
      );
      expect(bridge.installed.first.config!.theme, WidgetTheme.emerald);
      await tester.scrollUntilVisible(find.text('Save Widget'), 500);
      await tester.tap(find.text('Save Widget'));
      await tester.pumpAndSettle();
      expect(bridge.installed.first.config!.theme, WidgetTheme.mint);
      expect(bridge.installed[1].config, same(second.config));
      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Dark'), 350);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Cancel'), 500);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(bridge.installed.first.config!.theme, WidgetTheme.mint);
      expect(find.text('Configure'), findsOneWidget);
    },
  );
}
