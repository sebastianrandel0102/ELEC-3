import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/ai_coach/ai_widgets.dart';
import 'package:myproject/agent_studio/presentation/agent_widgets.dart';
import 'package:myproject/currency_money.dart';
import 'package:myproject/main.dart';
import 'package:myproject/reminder_widgets.dart';
import 'package:myproject/shared_savings_models.dart';
import 'package:myproject/shared_savings_screens.dart';

import 'figma_flow_test.dart' as flow;
import 'precision_edition_test.dart' as preview;
import 'redesign_test.dart' show TestDocument, TestSnapshot;
import 'ui_preview_fonts.dart';

final day = DateTime(2026, 10, 24);

SharedSavingsGoal sharedGoal() => SharedSavingsGoal('flow83-shared', {
  'name': 'A home for our next chapter',
  'ownerId': 'owner',
  'targetAmount': 150000,
  'currentAmount': 42000,
  'totalDeposits': 43000,
  'totalDecreases': 1000,
  'memberIds': ['owner', 'member', 'third', 'fourth'],
  'memberCount': 4,
  'memberNames': {
    'owner': 'Alex Hernandez',
    'member': 'Jamie Cruz',
    'third': 'Sam Reyes',
    'fourth': 'Pat Santos',
  },
  'startDate': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
  'deadline': Timestamp.fromDate(DateTime.utc(2027, 12, 31)),
});

Widget pulse() => preview.page(
  'Savings Pulse',
  ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const AtelierSectionHeader(
        title: 'Your savings, in focus.',
        subtitle: 'Recorded activity, in its original currency.',
      ),
      SavingsPulse(
        uid: 'fixture',
        goals: const [],
        clock: () => day,
        load: (_, _) async => (
          [
            for (final entry in [(18, 250), (20, 750), (21, 500), (23, 1000)])
              PulseEntry(
                at: DateTime(2026, 10, entry.$1),
                amount: ExactDecimal.fromNum(entry.$2),
                currency: 'PHP',
                withdrawal: false,
              ),
            PulseEntry(
              at: DateTime(2026, 10, 22),
              amount: ExactDecimal.fromNum(300),
              currency: 'PHP',
              withdrawal: true,
            ),
          ],
          false,
        ),
      ),
    ],
  ),
);

Widget weekly() => preview.page(
  'Planner',
  WeeklyPlanner(
    uid: 'fixture',
    selected: day,
    today: day,
    onSelect: (_) {},
    taskStream: Stream.value(
      TestSnapshot([
        flow.flowTask('budget', '09:30 - 10:15'),
        flow.flowTask('transfer', '13:15'),
        flow.flowTask('evening', ''),
      ]),
    ),
    header: AuroraModeSelector(
      selected: true,
      options: const {false: 'Daily', true: 'Weekly'},
      onSelected: (_) {},
    ),
  ),
);

Widget collaboration() => preview.page(
  'Save Together',
  ListView(
    padding: const EdgeInsets.all(20),
    children: [
      SharedGoalCard(goal: sharedGoal(), uid: 'owner'),
      SharedGoalHero(goal: sharedGoal()),
    ],
  ),
);

Widget upNext() => preview.page(
  'Up Next',
  ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const AtelierSectionHeader(
        title: 'A little focus for today.',
        subtitle: 'Your saved reminder schedule.',
      ),
      ReminderTimeline(
        onOpen: (_) {},
        items: [
          for (final item in [
            (9, 'Review my budget', ReminderTargetType.task),
            (13, 'A little closer to my goal', ReminderTargetType.personalGoal),
            (18, 'Our next chapter', ReminderTargetType.sharedGoal),
          ])
            UpcomingReminder(
              ReminderConfiguration(
                uid: 'fixture',
                type: item.$3,
                targetId: 'target-${item.$1}',
                enabled: true,
                hour: item.$1,
                frequency: ReminderFrequency.once,
                instant: DateTime(2026, 10, 24, item.$1),
              ),
              ReminderTarget(
                type: item.$3,
                id: 'target-${item.$1}',
                title: item.$2,
              ),
              DateTime(2026, 10, 24, item.$1),
            ),
        ],
      ),
    ],
  ),
);

void main() {
  setUpAll(() => loadManropeForPreviews(force: true));

  test('local calendar shifts cross leap days and year boundaries', () {
    expect(
      FlowCalendar.shift(DateTime(2028, 2, 28, 23), 1),
      DateTime(2028, 2, 29),
    );
    expect(FlowCalendar.shift(DateTime(2028, 2, 29), 1), DateTime(2028, 3, 1));
    expect(FlowCalendar.shift(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
    expect(
      FlowCalendar.shift(DateTime(2027, 1, 1), -1),
      DateTime(2026, 12, 31),
    );
    expect(FlowCalendar.monday(DateTime(2027, 1, 3)), DateTime(2026, 12, 28));
  });

  testWidgets('Today is distinct from selection and dates retain task counts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      DateTime? selected;
      await preview.mount(
        tester,
        Scaffold(
          body: FlowWeekSelector(
            selected: DateTime(2026, 10, 23),
            today: day,
            counts: const {5: 2, 6: 3},
            onSelected: (date) => selected = date,
          ),
        ),
      );
      final todayNode = tester.getSemantics(
        find.bySemanticsLabel('Saturday, October 24, 2026, Today, 3 tasks'),
      );
      expect(
        todayNode.getSemanticsData().flagsCollection.isSelected,
        Tristate.isFalse,
      );
      final selectedNode = tester.getSemantics(
        find.bySemanticsLabel('Friday, October 23, 2026, 2 tasks'),
      );
      expect(
        selectedNode.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      await tester.tap(find.text('24'));
      expect(selected, day);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('task tap opens details, completion uses the original update', (
    tester,
  ) async {
    var opened = 0;
    final doc = TestDocument({
      'title': 'Review my budget',
      'dateKey': '2026-10-24',
      'time': '09:30 - 10:15',
      'priority': 'High',
      'completed': false,
      'description': 'Compare this month with my plan.',
    });
    await preview.mount(
      tester,
      Scaffold(
        body: ListView(
          children: [
            TaskTile(
              uid: 'fixture',
              doc: doc,
              timeline: true,
              featured: true,
              onOpen: () => opened++,
            ),
          ],
        ),
      ),
    );
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('10:15'), findsOneWidget);
    expect(find.text('Compare this month with my plan.'), findsOneWidget);
    await tester.tap(find.text('Review my budget'));
    expect(opened, 1);
    expect(doc.testReference.updates, isEmpty);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(doc.testReference.updates.single['completed'], isTrue);
    expect(doc.testReference.updates.single.keys, contains('updatedAt'));
    expect(opened, 1);
    expect(doc.data()['completed'], isFalse);
  });

  testWidgets(
    'failed completion gives feedback and leaves the task incomplete',
    (tester) async {
      await preview.mount(
        tester,
        Scaffold(
          body: TaskTile(
            uid: 'fixture',
            doc: flow.flowTask('budget', '09:30'),
            timeline: true,
            onComplete: (_) async => throw StateError('offline'),
          ),
        ),
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(
        find.text('Could not update this task. Please try again.'),
        findsOneWidget,
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty day retains its date header and offers Add Task', (
    tester,
  ) async {
    await preview.mount(
      tester,
      Scaffold(
        body: TasksList(
          uid: 'fixture',
          dateKey: '2026-10-24',
          taskStream: Stream.value(TestSnapshot([])),
          header: const Text('Saturday, October 24'),
        ),
      ),
      width: 320,
      scale: 2,
    );
    expect(find.text('Saturday, October 24'), findsOneWidget);
    expect(find.text('Nothing scheduled for this day.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Add Task'), 150);
    expect(find.text('Add Task'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error surface exposes a working recovery callback', (
    tester,
  ) async {
    var retried = 0;
    await preview.mount(
      tester,
      Scaffold(
        body: ErrorPanel(
          message: 'Your schedule could not be loaded.',
          onRetry: () => retried++,
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('AI and Agent tiles retain independent action callbacks', (
    tester,
  ) async {
    final selected = <String>[];
    await preview.mount(
      tester,
      Scaffold(
        body: ListView(
          children: [
            AiPromptCard(
              icon: Icons.event_note_outlined,
              title: 'Plan my week',
              detail: 'Start a draft.',
              onTap: () => selected.add('ai'),
            ),
            AgentQuickActionCard(
              icon: Icons.savings_outlined,
              title: 'Prepare savings',
              description: 'Review before recording.',
              onTap: () => selected.add('agent'),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Plan my week'));
    await tester.tap(find.text('Prepare savings'));
    expect(selected, ['ai', 'agent']);
  });

  testWidgets('shared cards show actual member counts and ownership', (
    tester,
  ) async {
    for (final owner in [true, false]) {
      await preview.mount(
        tester,
        Scaffold(
          body: ListView(
            children: [
              SharedGoalCard(
                goal: sharedGoal(),
                uid: owner ? 'owner' : 'member',
              ),
            ],
          ),
        ),
      );
      expect(find.text(owner ? 'Owner' : 'Contributor'), findsOneWidget);
      expect(find.text('4 members'), findsOneWidget);
      expect(find.textContaining('42,000'), findsOneWidget);
      expect(find.textContaining('150,000'), findsOneWidget);
      expect(find.byType(MemberAvatar), findsNWidgets(3));
    }
  });

  for (final dark in [false, true]) {
    testWidgets(
      'featured task text meets contrast in ${dark ? 'dark' : 'light'}',
      (tester) async {
        await preview.mount(
          tester,
          Scaffold(
            body: TaskTile(
              uid: 'fixture',
              doc: flow.flowTask('budget', '09:30'),
              timeline: true,
              featured: true,
            ),
          ),
          dark: dark,
        );
        final background =
            tester
                    .widget<AnimatedContainer>(
                      find.byType(AnimatedContainer).first,
                    )
                    .decoration!
                as BoxDecoration;
        final title = tester
            .widget<Text>(find.text('Review the monthly budget'))
            .style!
            .color!;
        final a = background.color!.computeLuminance(),
            b = title.computeLuminance();
        final contrast = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      },
    );

    for (final entry in {
      'pulse': pulse,
      'weekly': weekly,
      'collaboration': collaboration,
      'up-next': upNext,
    }.entries) {
      testWidgets('${entry.key} ${dark ? 'dark' : 'light'} composition', (
        tester,
      ) async {
        await preview.mount(tester, entry.value(), dark: dark);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(preview.capture),
          matchesGoldenFile(
            'goldens/flow83-${entry.key}-${dark ? 'dark' : 'light'}.png',
          ),
        );
      });
    }

    for (final width in [320.0, 390.0, 600.0, 840.0]) {
      testWidgets('flow surfaces at $width and 200% text, dark=$dark', (
        tester,
      ) async {
        for (final screen in [pulse(), weekly(), collaboration()]) {
          await preview.mount(
            tester,
            screen,
            dark: dark,
            width: width,
            scale: 2,
          );
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
