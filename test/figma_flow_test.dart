import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/main.dart';
import 'package:myproject/reminder_widgets.dart';

import 'aurora4_layout_test.dart' show PreviewDocument;
import 'home_atelier_test.dart' show fixtureGoals;
import 'precision_edition_test.dart' as preview;
import 'ui_preview_fonts.dart';

final flowDay = DateTime(2026, 10, 24);

PreviewDocument flowTask(String id, String time, {bool done = false}) =>
    PreviewDocument(id, {
      'title': id == 'budget'
          ? 'Review the monthly budget'
          : id == 'transfer'
          ? 'Plan my next contribution'
          : 'Make time for a little progress',
      'dateKey': '2026-10-24',
      'time': time,
      'priority': id == 'budget' ? 'High' : 'Normal',
      'completed': done,
    });

Widget flowHome() => Scaffold(
  body: PageSurface(
    child: AuroraPage(
      title: 'Today',
      child: FlowHomeLayout(
        header: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuroraGreeting(
              date: 'Saturday, October 24',
              greeting: 'Good morning.',
            ),
            SavingsOverview(
              total: 54500,
              target: 170000,
              count: 2,
              embedded: true,
            ),
          ],
        ),
        quickActions: Row(
          children: [
            for (final action in [
              (Icons.add_rounded, 'Add savings'),
              (Icons.flag_outlined, 'New goal'),
              (Icons.checklist_rounded, 'Add task'),
              (Icons.notifications_outlined, 'Reminders'),
            ])
              Expanded(
                child: AuroraQuickAction(
                  icon: action.$1,
                  label: action.$2,
                  onTap: () {},
                ),
              ),
          ],
        ),
        sectionCount: 2,
        sectionBuilder: (context, i) => i == 0
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AtelierSectionHeader(
                    title: 'Goal Gallery',
                    subtitle: 'Make room for what matters.',
                  ),
                  GoalGallery(
                    uid: 'fixture',
                    records: fixtureGoals(),
                    featuredId: 'home',
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AtelierSectionHeader(
                    title: 'Up Next',
                    subtitle: 'A little focus for today.',
                  ),
                  TaskTile(
                    uid: 'fixture',
                    doc: flowTask('budget', '09:30 - 10:15'),
                    timeline: true,
                    featured: true,
                  ),
                ],
              ),
      ),
    ),
  ),
  bottomNavigationBar: SaveTrackNavigation(
    selectedIndex: 0,
    onSelected: (_) {},
  ),
);

Widget flowPlanner() => Scaffold(
  body: PageSurface(
    child: AuroraPage(
      title: 'Planner',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AuroraModeSelector(
            selected: false,
            options: const {false: 'Daily', true: 'Weekly'},
            onSelected: (_) {},
          ),
          const SizedBox(height: 16),
          PlannerDateHeader(
            title: 'Sat, Oct 24',
            date: flowDay,
            onSelect: (_) {},
            onPrevious: () {},
            onNext: () {},
            onToday: () {},
            onPick: () {},
          ),
          Row(
            children: [
              SizedBox(width: 80, child: Text('Time')),
              Text('Your Tasks'),
            ],
          ),
          const SizedBox(height: 16),
          TaskTile(
            uid: 'fixture',
            doc: flowTask('budget', '09:30 - 10:15'),
            timeline: true,
            featured: true,
          ),
          TaskTile(
            uid: 'fixture',
            doc: flowTask('transfer', '13:15'),
            timeline: true,
          ),
          TaskTile(
            uid: 'fixture',
            doc: flowTask('evening', '17:00'),
            timeline: true,
          ),
        ],
      ),
    ),
  ),
  bottomNavigationBar: SaveTrackNavigation(
    selectedIndex: 2,
    onSelected: (_) {},
  ),
);

Widget flowReminders() => Scaffold(
  appBar: AppBar(title: const Text('Smart Reminders')),
  body: ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const AtelierSectionHeader(
        title: 'Today',
        subtitle: 'A thoughtful nudge, right on time.',
      ),
      for (final item in [
        (9, 'Review the monthly budget'),
        (18, 'A little closer to my goal'),
      ])
        ReminderAgendaCard(
          entry: ReminderAgendaEntry(
            configuration: ReminderConfiguration(
              uid: 'fixture',
              type: ReminderTargetType.personalGoal,
              targetId: 'goal-${item.$1}',
              enabled: true,
              hour: item.$1,
              frequency: ReminderFrequency.daily,
            ),
            target: ReminderTarget(
              type: ReminderTargetType.personalGoal,
              id: 'goal-${item.$1}',
              title: item.$2,
            ),
            next: DateTime(2026, 10, 24, item.$1),
            section: 'Today',
          ),
          status: const ReminderStatus(
            ReminderDelivery.scheduled,
            'Scheduled on this phone',
          ),
          onManage: () {},
          onToggle: (_) {},
          onRemove: () {},
        ),
    ],
  ),
);

void main() {
  setUpAll(() => loadManropeForPreviews(force: true));

  test('priority text remains readable on the highlighted mint card', () {
    final background = Color.alphaBlend(
      SaveTrackDesign.warning.withValues(alpha: .08),
      FigmaFlowPalette.soft,
    );
    final foregroundLuminance = SaveTrackDesign.warning.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    expect(
      (backgroundLuminance + .05) / (foregroundLuminance + .05),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('timeline sorting uses parsed schedules and preserves all records', () {
    final records = [
      flowTask('anytime', ''),
      flowTask('late', '5:00 PM'),
      flowTask('invalid', 'after lunch'),
      flowTask('early', '09:30 - 10:15'),
    ];
    final ordered = flowOrderedTasks(records, '2026-10-24');
    expect(ordered.map((d) => d.id), ['early', 'late', 'anytime', 'invalid']);
    expect(records.first.id, 'anytime');
    expect(ordered.toSet(), records.toSet());
    expect(flowOrderedTasks(records, 'invalid'), same(records));
  });

  test('featured task skips completed and elapsed schedules without inventing a time', () {
    final records = flowOrderedTasks([
      flowTask('done', '09:00', done: true),
      flowTask('budget', '10:00 - 11:00'),
      flowTask('transfer', '13:00'),
      flowTask('anytime', ''),
    ], '2026-10-24');
    expect(
      flowFeaturedTask(
        records,
        '2026-10-24',
        now: DateTime(2026, 10, 24, 10, 30),
      ),
      'budget',
    );
    expect(
      flowFeaturedTask(records, '2026-10-24', now: DateTime(2026, 10, 24, 12)),
      'transfer',
    );
    expect(
      flowFeaturedTask(records, '2026-10-24', now: DateTime(2026, 10, 24, 18)),
      isNull,
    );
  });

  testWidgets(
    'week selector announces seven dates and commits actual calendar dates',
    (tester) async {
      DateTime? selected;
      final semantics = tester.ensureSemantics();
      try {
        await preview.mount(
          tester,
          Scaffold(
            body: FlowWeekSelector(
              selected: DateTime(2026, 11, 1),
              onSelected: (d) => selected = d,
            ),
          ),
        );
        expect(find.byType(InkWell), findsNWidgets(7));
        expect(
          tester.getSize(find.byType(InkWell).first).width,
          greaterThanOrEqualTo(48),
        );
        final monday = tester.getSemantics(
          find.bySemanticsLabel('Monday, October 26, 2026'),
        );
        expect(
          monday.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        await tester.tap(find.byType(InkWell).first);
        expect(selected, DateTime(2026, 10, 26));
        await tester.tap(find.byType(InkWell).last);
        expect(selected, DateTime(2026, 11, 1));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'date picker, Today, day and week controls keep independent callbacks',
    (tester) async {
      var previous = 0, next = 0, today = 0, picked = 0;
      DateTime? selected;
      await preview.mount(
        tester,
        Scaffold(
          body: ListView(
            children: [
              PlannerDateHeader(
                title: 'Saturday',
                date: flowDay,
                onPrevious: () => previous++,
                onNext: () => next++,
                onToday: () => today++,
                onPick: () => picked++,
                onSelect: (d) => selected = d,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byTooltip('Previous day'));
      await tester.tap(find.byTooltip('Next day'));
      await tester.tap(find.text('Today'));
      await tester.tap(find.text('24').first);
      await tester.tap(find.byTooltip('Next week'));
      expect([previous, next, today, picked], [1, 1, 1, 1]);
      expect(selected, DateTime(2026, 10, 31));
    },
  );

  testWidgets(
    'goal preview opens its supplied destination and retains exact financial values',
    (tester) async {
      var opened = 0;
      await preview.mount(
        tester,
        Scaffold(
          body: ListView(
            children: [
              AtelierGoalTile(
                uid: 'fixture',
                doc: fixtureGoals().first,
                preview: true,
                onOpen: () => opened++,
              ),
            ],
          ),
        ),
      );
      expect(find.textContaining('42,000'), findsOneWidget);
      expect(find.textContaining('150,000'), findsOneWidget);
      await tester.tap(find.text('A home for our next chapter'));
      expect(opened, 1);
    },
  );

  for (final dark in [false, true]) {
    for (final screen in ['home', 'planner', 'reminders']) {
      testWidgets('$screen ${dark ? 'dark' : 'light'} reference composition', (
        tester,
      ) async {
        await preview.mount(
          tester,
          screen == 'home'
              ? flowHome()
              : screen == 'planner'
              ? flowPlanner()
              : flowReminders(),
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(preview.capture),
          matchesGoldenFile(
            'goldens/flow82-$screen-${dark ? 'dark' : 'light'}.png',
          ),
        );
      });
    }
    for (final width in [320.0, 390.0, 600.0, 840.0]) {
      testWidgets(
        'Home and Planner at $width and 200% text ${dark ? 'dark' : 'light'}',
        (tester) async {
          for (final screen in [flowHome(), flowPlanner(), flowReminders()]) {
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
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
