import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/main.dart';
import 'package:myproject/currency_money.dart';

import 'redesign_test.dart' as preview;
import 'ui_preview_fonts.dart';

// Presentation fixtures never enter the production application or Firebase.
// The SDK interface double follows the existing test suite's isolated seam.
// ignore: subtype_of_sealed_class
class PreviewDocument extends preview.TestDocument {
  PreviewDocument(this.recordId, super.values);
  final String recordId;
  @override
  String get id => recordId;
}

List<PreviewDocument> goals({bool stress = false}) => [
  PreviewDocument('emergency', {
    'title': stress
        ? 'A home for our family and the next chapter of our lives'
        : 'Emergency fund',
    'note': 'A little peace of mind.',
    'savedAmount': stress ? 123456789.12 : 12500.0,
    'targetAmount': stress ? 987654321.98 : 50000.0,
    'currencyCode': 'PHP',
    'deadline': Timestamp.fromDate(DateTime(2026, 12, 31)),
  }),
  PreviewDocument('travel', {
    'title': 'A trip to remember',
    'savedAmount': 24000.0,
    'targetAmount': 40000.0,
    'currencyCode': 'PHP',
  }),
];

List<PreviewDocument> tasks({bool stress = false}) => [
  PreviewDocument('budget', {
    'title': stress
        ? 'Review the household budget and organize our upcoming commitments for the entire week'
        : 'Review this week\u2019s budget',
    'time': '9:30 AM',
    'priority': 'High',
    'completed': false,
  }),
  PreviewDocument('groceries', {
    'title': 'Plan the grocery list',
    'time': '11:00 AM',
    'priority': 'Normal',
    'completed': false,
  }),
  PreviewDocument('reading', {
    'title': 'Read a chapter',
    'time': '',
    'priority': 'Low',
    'completed': true,
  }),
];

Widget frame(Widget body, int tab) => Scaffold(
  body: PageSurface(child: body),
  bottomNavigationBar: SaveTrackNavigation(
    selectedIndex: tab,
    onSelected: (_) {},
  ),
);

List<Widget> screens({bool stress = false}) {
  final records = goals(stress: stress), plans = tasks(stress: stress);
  final summary = currencySummary(
    null,
    records.map((d) => (d.values['savedAmount'] as num, 'PHP')).toList(),
    records.map((d) => (d.values['targetAmount'] as num, 'PHP')).toList(),
  );
  final balance = summary.$1;
  final target = summary.$2;
  final value = originalMoney(balance);
  return [
    frame(
      DashboardLayout(
        header: const ScreenIntro(
          eyebrow: 'Tuesday, 13 October',
          title: 'Hello, Alex',
          detail: 'A little progress adds up.',
        ),
        savings: SavingsOverview(total: balance, target: target, count: 2),
        metrics: const AdaptiveCards(
          breakpoint: 0,
          children: [
            AuroraMetricCard(
              icon: Icons.flag_outlined,
              value: '2',
              label: 'Active goals',
            ),
            AuroraMetricCard(
              icon: Icons.check_circle_outline,
              value: '1/3',
              label: 'Done today',
            ),
          ],
        ),
        goals: AdaptiveCards(
          children: records
              .map((d) => GoalCard(uid: 'fixture', doc: d))
              .toList(),
        ),
        tasks: Column(
          children: plans.map((d) => TaskTile(uid: 'fixture', doc: d)).toList(),
        ),
        onGoals: () {},
        onPlanner: () {},
      ),
      0,
    ),
    frame(
      ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PlannerDateHeader(
            title: 'Tue  13/10/2026',
            onPrevious: () {},
            onNext: () {},
            onToday: () {},
          ),
          const DailyCompletion(done: 1, total: 3),
          const SizedBox(height: 24),
          const Text('Your Tasks', style: SaveTrackDesign.heading),
          const SizedBox(height: 16),
          ...plans.map((d) => TaskTile(uid: 'fixture', doc: d)),
        ],
      ),
      2,
    ),
    frame(
      AdaptiveCardList(
        itemCount: records.length,
        header: const ScreenIntro(
          eyebrow: 'Personal savings',
          title: 'Save for what matters.',
          detail: 'Your milestones, one contribution at a time.',
        ),
        itemBuilder: (context, index) =>
            GoalCard(uid: 'fixture', doc: records[index]),
      ),
      1,
    ),
    frame(
      ReportsLayout(
        savings: ReportMetric(
          title: 'Savings balance',
          value: value,
          caption: stress
              ? 'Across 2 personal goals \u00b7 PHP \u20b1987,694,321.98 total target.'
              : 'Across 2 personal goals \u00b7 PHP \u20b190,000.00 total target.',
          icon: Icons.savings_outlined,
          featured: true,
          progress: balance / target,
        ),
        shared: const SizedBox.shrink(),
        daily: const ReportMetric(
          title: 'Today\u2019s tasks',
          value: '1 / 3 completed',
          caption: '2 remaining',
          icon: Icons.check_circle_outline,
          progress: 1 / 3,
        ),
        weekly: const ReportMetric(
          title: 'This week\u2019s tasks',
          value: '8 / 12 completed',
          caption: '4 remaining',
          icon: Icons.date_range_outlined,
          progress: 8 / 12,
        ),
        goals: AdaptiveCards(
          children: records
              .map((d) => GoalCard(uid: 'fixture', doc: d))
              .toList(),
        ),
      ),
      3,
    ),
  ];
}

void main() {
  setUpAll(loadManropeForPreviews);
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetViewInsets();
  });

  const names = ['dashboard', 'planner', 'savings', 'reports'];
  for (final width in [
    320.0,
    360.0,
    390.0,
    412.0,
    480.0,
    600.0,
    840.0,
    1280.0,
  ]) {
    testWidgets(
      'four primary compositions at $width retain values without overflow',
      (tester) async {
        final layouts = screens();
        for (var i = 0; i < layouts.length; i++) {
          await preview.mount(tester, layouts[i], size: Size(width, 900));
          expect(tester.takeException(), isNull, reason: names[i]);
          await preview.capture(tester, 'aurora4-${names[i]}-${width.toInt()}');
          if (i == 0 || i == 3) {
            expect(find.text('PHP \u20b136,500.00'), findsOneWidget);
          }
          // Inspect more than the first viewport, including task states/actions.
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${names[i]} after scrolling',
          );
          if (width == 390 || width == 1280) {
            await preview.capture(
              tester,
              'aurora4-${names[i]}-${width.toInt()}-scrolled',
            );
          }
        }
      },
    );
  }

  for (final width in [320.0, 600.0, 1280.0]) {
    testWidgets('large text, long names and exact balances at $width', (
      tester,
    ) async {
      final layouts = screens(stress: true);
      for (var i = 0; i < layouts.length; i++) {
        await preview.mount(
          tester,
          layouts[i],
          size: Size(width, 900),
          scale: 2,
        );
        expect(tester.takeException(), isNull, reason: names[i]);
        await preview.capture(
          tester,
          'aurora4-${names[i]}-${width.toInt()}-large-text',
        );
        if (i == 0 || i == 3) {
          await tester.scrollUntilVisible(
            find.text('PHP \u20b1123,480,789.12'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('PHP \u20b1123,480,789.12'), findsOneWidget);
        }
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -1000),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${names[i]} after scrolling',
        );
      }
    });
  }

  testWidgets('dashboard task sliver builds lazily and retains all 200 tasks', (
    tester,
  ) async {
    final docs = List.generate(
      200,
      (index) => PreviewDocument('task-$index', {
        'title': 'Task $index',
        'priority': 'Normal',
        'completed': false,
      }),
    );
    await preview.mount(
      tester,
      frame(
        DashboardLayout(
          header: const SizedBox.shrink(),
          savings: const SizedBox.shrink(),
          metrics: const SizedBox.shrink(),
          goals: const SizedBox.shrink(),
          tasksAreSlivers: true,
          tasks: TasksList(
            uid: 'fixture',
            dateKey: '2026-10-13',
            compact: true,
            asSliver: true,
            taskStream: Stream.value(preview.TestSnapshot(docs)),
          ),
          onGoals: () {},
          onPlanner: () {},
        ),
        0,
      ),
    );
    expect(find.byType(TaskTile).evaluate().length, lessThan(20));
    await tester.scrollUntilVisible(
      find.text('Task 199'),
      600,
      maxScrolls: 100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Task 199'), findsOneWidget);
    expect(docs.every((d) => d.testReference.updates.isEmpty), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading, empty and error surfaces fit compact bento constraints',
    (tester) async {
      await preview.mount(
        tester,
        MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: preview.scrollPage(
            Column(
              children: [
                const LoadingPanel(featured: true),
                const AdaptiveCards(
                  breakpoint: 0,
                  children: [LoadingPanel(), LoadingPanel()],
                ),
                const SizedBox(height: 16),
                const ErrorPanel(
                  message: 'Could not load goals. Check your connection and try again.',
                ),
                EmptyPanel(
                  icon: Icons.savings_outlined,
                  title: 'Start with a savings goal',
                  detail: 'Give your next milestone a name and target.',
                  action: 'Create goal',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        size: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);
      await preview.capture(tester, 'aurora4-feedback-320');
      // Force the two-column loading case independently of enlarged-text reflow.
      await preview.mount(
        tester,
        preview.scrollPage(
          const Row(
            children: [
              Expanded(child: LoadingPanel()),
              SizedBox(width: 16),
              Expanded(child: LoadingPanel()),
            ],
          ),
        ),
        size: const Size(320, 900),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completion presentation waits for the existing source of truth',
    (tester) async {
      final doc = tasks().first;
      late StateSetter refresh;
      await preview.mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return preview.scrollPage(TaskTile(uid: 'fixture', doc: doc));
          },
        ),
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(doc.testReference.updates.single['completed'], true);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
      refresh(() => doc.values['completed'] = true);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
      expect(find.text('Completed'), findsOneWidget);
      expect(doc.testReference.updates.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'progress starts at authoritative value and only animates value changes',
    (tester) async {
      Widget bar(double value) => MaterialApp(
        home: Scaffold(body: MintProgress(value: value)),
      );
      double fill() => tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor!;
      await tester.pumpWidget(bar(.4));
      expect(fill(), .4);
      await tester.pumpWidget(bar(.7));
      expect(fill(), .4);
      await tester.pump(const Duration(milliseconds: 210));
      expect(fill(), inExclusiveRange(.4, .7));
      await tester.pumpAndSettle();
      expect(fill(), .7);
      await tester.pumpWidget(bar(.7));
      expect(fill(), .7);
    },
  );
}
