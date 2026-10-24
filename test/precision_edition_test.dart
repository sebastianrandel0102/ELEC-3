import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/main.dart';
import 'package:myproject/reminder_coordinator.dart';
import 'package:myproject/reminder_widgets.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'aurora4_layout_test.dart' show PreviewDocument;
import 'reminder_system_test.dart'
    show MemoryDeviceStore, MemoryReminders, RecordingScheduler;
import 'ui_preview_fonts.dart';

final capture = GlobalKey();
final referenceDay = DateTime.utc(2026, 10, 23, 0);
PreviewDocument goal({bool invalid = false}) => PreviewDocument('laptop', {
  'title': 'A laptop for my next chapter',
  'savedAmount': invalid ? double.nan : 12500,
  'targetAmount': 50000,
  'currencyCode': 'PHP',
  'note': 'For learning, creating and everything ahead.',
  'deadline': Timestamp.fromDate(DateTime(2026, 12, 31)),
});
Map<String, dynamic> transaction({bool withdrawal = false}) => {
  'amount': 1250,
  'type': withdrawal ? 'withdrawal' : 'deposit',
  'currencyCode': 'PHP',
  'note': withdrawal ? 'An unexpected expense' : 'A little closer',
  'date': Timestamp.fromDate(referenceDay),
};

Future<void> mount(
  WidgetTester tester,
  Widget body, {
  bool dark = false,
  double width = 390,
  double height = 844,
  double scale = 1,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? SaveTrackDesign.darkTheme : SaveTrackDesign.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: RepaintBoundary(key: capture, child: child!),
      ),
      home: body,
    ),
  );
  await tester.pumpAndSettle();
}

Widget page(String title, Widget child) => Scaffold(
  body: PageSurface(
    child: AuroraPage(
      title: title,
      actions: [
        IconButton(
          tooltip: 'Assist',
          onPressed: () {},
          icon: const Icon(Icons.auto_awesome_outlined),
        ),
      ],
      child: child,
    ),
  ),
);

Widget details() => Scaffold(
  appBar: AppBar(title: const Text('Goal Details')),
  body: PageSurface(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: PersonalGoalOverview(
        uid: 'fixture',
        doc: goal(),
        clock: () => DateTime(2026, 10, 23),
        recentActivity: AuroraGroupedSection(
          children: [
            PersonalTransactionTile(data: transaction(), currency: 'PHP'),
            PersonalTransactionTile(
              data: transaction(withdrawal: true),
              currency: 'PHP',
            ),
          ],
        ),
      ),
    ),
  ),
);

Widget profile() => page(
  'Profile',
  ProfileContent(
    name: 'Alex Hernandez',
    email: 'alex@example.test',
    onPassword: () {},
    onSignOut: () {},
  ),
);

Widget home() => Scaffold(
  body: PageSurface(
    child: AuroraPage(
      title: 'Today',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AuroraGreeting(
            date: 'Friday, October 23',
            greeting: 'Good morning.',
          ),
          const SavingsOverview(total: 12500, target: 50000, count: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final item in [
                (Icons.add, 'Add savings'),
                (Icons.flag_outlined, 'New goal'),
                (Icons.checklist, 'Add task'),
                (Icons.notifications_outlined, 'Reminders'),
              ])
                Expanded(
                  child: AuroraQuickAction(
                    icon: item.$1,
                    label: item.$2,
                    onTap: () {},
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Goal Gallery',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          AtelierGoalTile(
            uid: 'fixture',
            doc: goal(),
            compact: true,
            onOpen: () {},
          ),
        ],
      ),
    ),
  ),
  bottomNavigationBar: SaveTrackNavigation(
    selectedIndex: 0,
    onSelected: (_) {},
  ),
);

void main() {
  setUpAll(() async {
    await loadManropeForPreviews(force: true);
    tzdata.initializeTimeZones();
  });

  test('normal text and primary action pairs meet AA in both themes', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    for (final theme in [SaveTrackDesign.theme, SaveTrackDesign.darkTheme]) {
      final c = theme.colorScheme;
      for (final background in [
        c.surface,
        c.surfaceContainer,
        theme.scaffoldBackgroundColor,
      ]) {
        expect(contrast(c.onSurface, background), greaterThanOrEqualTo(4.5));
        expect(
          contrast(c.onSurfaceVariant, background),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(contrast(c.primary, c.onPrimary), greaterThanOrEqualTo(4.5));
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Manrope');
      expect(theme.chipTheme.labelStyle?.fontFamily, 'Manrope');
      expect(
        contrast(
          theme.inputDecorationTheme.floatingLabelStyle!.color!,
          theme.inputDecorationTheme.fillColor!,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets('large title collapses with the list and restores on return', (
    tester,
  ) async {
    await mount(
      tester,
      page(
        'Goals',
        ListView.builder(
          itemCount: 50,
          itemBuilder: (_, i) => ListTile(title: Text('Goal $i')),
        ),
      ),
    );
    double titleSize() =>
        tester.widget<Text>(find.text('Goals')).style!.fontSize!;
    expect(titleSize(), 30);
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(titleSize(), 20);
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(titleSize(), 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all five destinations select and retain tab scroll offsets', (
    tester,
  ) async {
    var selected = 0;
    await mount(
      tester,
      StatefulBuilder(
        builder: (context, update) => Scaffold(
          body: IndexedStack(
            index: selected,
            children: [
              for (var index = 0; index < 5; index++)
                AuroraPage(
                  title: 'Page $index',
                  child: ListView.builder(
                    key: PageStorageKey('test-tab-$index'),
                    itemCount: 60,
                    itemBuilder: (_, i) =>
                        ListTile(title: Text('Tab $index row $i')),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: SaveTrackNavigation(
            selectedIndex: selected,
            onSelected: (value) => update(() => selected = value),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('Tab 0 row 10')).dy;
    for (final label in ['Goals', 'Planner', 'Reports', 'Profile', 'Today']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(selected, 0);
    expect(
      tester.getTopLeft(find.text('Tab 0 row 10')).dy,
      closeTo(before, .1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Assist has separate working choices with labeled targets', (
    tester,
  ) async {
    var ai = 0, agent = 0;
    await mount(
      tester,
      Scaffold(
        body: AuroraAssistChooser(onAi: () => ai++, onAgent: () => agent++),
      ),
    );
    await tester.tap(find.text('SaveTrack AI'));
    await tester.tap(find.text('Agent Studio Pro'));
    expect((ai, agent), (1, 1));
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('Daily and Weekly are one accessible selection', (tester) async {
    var weekly = false;
    await mount(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (_, update) => AuroraModeSelector<bool>(
            selected: weekly,
            options: const {false: 'Daily', true: 'Weekly'},
            onSelected: (value) => update(() => weekly = value),
          ),
        ),
      ),
      width: 320,
      scale: 2,
    );
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(weekly, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final state in [
    (false, false),
    (true, false),
    (false, true),
    (true, true),
  ]) {
    testWidgets('cache and pending states remain truthful: $state', (
      tester,
    ) async {
      await mount(
        tester,
        Scaffold(
          body: AuroraSyncStatus(cached: state.$1, pending: state.$2),
        ),
      );
      expect(
        find.textContaining('pending cloud confirmation'),
        state.$2 ? findsOneWidget : findsNothing,
      );
      expect(
        find.textContaining('Showing cached'),
        state.$1 && !state.$2 ? findsOneWidget : findsNothing,
      );
      expect(find.textContaining('Saved successfully'), findsNothing);
    });
  }

  testWidgets(
    'transaction detail preserves direction, note and recorded amount',
    (tester) async {
      final data = transaction(withdrawal: true);
      final before = Map<String, dynamic>.from(data);
      await mount(
        tester,
        Scaffold(
          body: PersonalTransactionTile(data: data, currency: 'PHP'),
        ),
      );
      expect(find.text('−PHP ₱1,250.00'), findsOneWidget);
      await tester.tap(find.text('Savings decreased'));
      await tester.pumpAndSettle();
      expect(find.text('Recorded amount: PHP ₱1,250.00'), findsOneWidget);
      expect(find.text('An unexpected expense'), findsNWidgets(2));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(data, before);
    },
  );

  testWidgets('invalid balance never enables a financial action', (
    tester,
  ) async {
    await mount(
      tester,
      Scaffold(
        body: PersonalGoalOverview(uid: 'fixture', doc: goal(invalid: true)),
      ),
    );
    expect(find.textContaining('unavailable balance'), findsOneWidget);
    expect(find.text('Add savings'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'agenda uses next recurrence and the scheduler timezone at midnight',
    () {
      final zone = tz.getLocation('Asia/Manila');
      final coordinator = ReminderCoordinator(
        repository: MemoryReminders(),
        scheduler: RecordingScheduler(zone),
        deviceStore: MemoryDeviceStore(),
        clock: () => DateTime.utc(2026, 10, 22, 23, 30),
      );
      coordinator.zone = zone;
      addTearDown(coordinator.dispose);
      for (final record in [
        ('daily', true, 9),
        ('disabled', false, 8),
        ('early', true, 8),
      ]) {
        final c = ReminderConfiguration(
          uid: 'fixture',
          type: ReminderTargetType.personalGoal,
          targetId: record.$1,
          enabled: record.$2,
          frequency: ReminderFrequency.daily,
          hour: record.$3,
        );
        coordinator.configurations[c.key] = c;
        coordinator.targets[c.key] = ReminderTarget(
          type: c.type,
          id: c.targetId,
          title: c.targetId,
        );
      }
      final agenda = reminderAgenda(coordinator);
      expect(agenda.map((e) => e.configuration.targetId), [
        'early',
        'daily',
        'disabled',
      ]);
      expect(agenda.map((e) => e.section), [
        'Today',
        'Today',
        'Other reminders',
      ]);
      expect(agenda.first.next!.hour, 8);
      expect(agenda.first.next!.day, 23);
    },
  );

  for (final width in [320.0, 360.0, 390.0, 412.0, 480.0, 600.0, 840.0]) {
    testWidgets(
      'goal details and Profile retain values at $width with large text',
      (tester) async {
        await mount(tester, details(), width: width, scale: 2);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is AmountText && widget.text == 'PHP ₱12,500.00',
          ),
          findsOneWidget,
        );
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -900),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await mount(tester, profile(), dark: true, width: width, scale: 2);
        expect(find.text('Alex Hernandez'), findsOneWidget);
        expect(find.text('alex@example.test'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dark in [false, true]) {
    for (final scene in ['home', 'goals', 'details', 'profile', 'assist']) {
      testWidgets('Precision $scene ${dark ? 'dark' : 'light'} golden', (
        tester,
      ) async {
        final body = switch (scene) {
          'home' => home(),
          'goals' => page(
            'Goals',
            GoalBrowser(uid: 'fixture', records: [goal()]),
          ),
          'details' => details(),
          'profile' => profile(),
          _ => Scaffold(
            body: AuroraAssistChooser(onAi: () {}, onAgent: () {}),
          ),
        };
        await mount(tester, body, dark: dark);
        await expectLater(
          find.byKey(capture),
          matchesGoldenFile(
            'goldens/precision81-$scene-${dark ? 'dark' : 'light'}.png',
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
