import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/atelier_preferences.dart';
import 'package:myproject/currency_money.dart';
import 'package:myproject/main.dart';
import 'package:myproject/reminder_coordinator.dart';
import 'package:myproject/reminder_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'aurora4_layout_test.dart' show PreviewDocument;
import 'aurora4_layout_test.dart' as regression;
import 'reminder_system_test.dart'
    show MemoryDeviceStore, MemoryReminders, RecordingScheduler;
import 'ui_preview_fonts.dart';
import 'redesign_test.dart' show TestSnapshot, showTestGoalForm;

final boundaryKey = GlobalKey();
final date = DateTime(2026, 10, 18, 12);
List<QueryDocumentSnapshot<Map<String, dynamic>>> fixtureGoals() => [
  PreviewDocument('home', {
    'title': 'A home for our next chapter',
    'savedAmount': 42000,
    'targetAmount': 150000,
    'currencyCode': 'PHP',
    'deadline': Timestamp.fromDate(DateTime(2026, 12, 30)),
  }),
  PreviewDocument('travel', {
    'title': 'A quiet weekend away',
    'savedAmount': 12500,
    'targetAmount': 20000,
    'currencyCode': 'PHP',
    'deadline': Timestamp.fromDate(DateTime(2027, 1, 20)),
  }),
];
List<PulseEntry> fixtureActivity() => [
  for (final record in [(12, 1200), (14, 800), (16, 2000), (18, 500)])
    PulseEntry(
      at: DateTime(2026, 10, record.$1, 10),
      amount: ExactDecimal.fromNum(record.$2),
      currency: 'PHP',
    ),
  PulseEntry(
    at: DateTime(2026, 10, 17),
    amount: ExactDecimal.fromNum(300),
    currency: 'PHP',
    withdrawal: true,
  ),
];

Future<void> mount(
  WidgetTester tester,
  Widget body, {
  bool dark = false,
  double width = 390,
  double scale = 1,
  double height = 844,
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
        child: RepaintBoundary(key: boundaryKey, child: child!),
      ),
      home: body,
    ),
  );
  await tester.pumpAndSettle();
}

Widget page(Widget child) => Scaffold(
  body: PageSurface(
    child: ListView(padding: const EdgeInsets.all(20), children: [child]),
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final picture = await boundary.toImage();
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-preview/atelier71-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

void main() {
  additionalTests();
  setUpAll(() async {
    await loadManropeForPreviews(force: true);
    tzdata.initializeTimeZones();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('presentation is persisted per account; restore preserves appearance and other preferences', () async {
    final storage = await SharedPreferences.getInstance();
    await storage.setString('existing.setting', 'keep');
    final alex = AtelierPreferences(storage, account: 'alex');
    alex.goals = GoalPresentation.list;
    alex.pulse = PulsePresentation.compact;
    alex.reminders = ReminderPresentation.nextUp;
    alex.featuredGoal = 'home';
    alex.hidden.add(HomeSection.pulse);
    alex.order = HomeSection.values.reversed.toList();
    alex.appearance = ThemeMode.dark;
    await alex.save();
    final loaded = AtelierPreferences(storage, account: 'alex');
    expect(loaded.goals, GoalPresentation.list);
    expect(loaded.pulse, PulsePresentation.compact);
    expect(loaded.reminders, ReminderPresentation.nextUp);
    expect(loaded.featuredGoal, 'home');
    expect(loaded.hidden, contains(HomeSection.pulse));
    expect(loaded.order.first, HomeSection.agent);
    final other = AtelierPreferences(storage, account: 'other');
    expect(other.goals, GoalPresentation.gallery);
    expect(other.featuredGoal, isNull);
    await loaded.restore();
    expect(loaded.order, HomeSection.values);
    expect(loaded.appearance, ThemeMode.dark);
    expect(storage.getString('existing.setting'), 'keep');
    alex.dispose();
    loaded.dispose();
    other.dispose();
  });

  test('malformed or old preferences fall back to usable defaults', () async {
    final storage = await SharedPreferences.getInstance();
    await storage.setString('savetrack.atelier71.alex', '{bad');
    var prefs = AtelierPreferences(storage, account: 'alex');
    expect(prefs.goals, GoalPresentation.gallery);
    prefs.dispose();
    await storage.setString(
      'savetrack.atelier71.alex',
      '{"goals":"removed","order":["pulse","pulse","unknown"],"hidden":[]}',
    );
    prefs = AtelierPreferences(storage, account: 'alex');
    expect(prefs.order.first, HomeSection.pulse);
    expect(prefs.order.toSet().length, HomeSection.values.length);
    expect(prefs.hidden, isEmpty);
    prefs.dispose();
  });

  test('Pulse keeps exact decimals, currency boundaries, and an exclusive period end', () {
    final totals = PulseTotals(
      'PHP',
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 19),
      [
        ...fixtureActivity(),
        PulseEntry(
          at: date,
          amount: ExactDecimal.parse('0.10'),
          currency: 'PHP',
        ),
        PulseEntry(
          at: date,
          amount: ExactDecimal.parse('0.20'),
          currency: 'PHP',
        ),
        PulseEntry(
          at: date,
          amount: ExactDecimal.fromNum(9000),
          currency: 'USD',
        ),
        PulseEntry(
          at: DateTime(2026, 10, 19),
          amount: ExactDecimal.fromNum(9000),
          currency: 'PHP',
        ),
      ],
    );
    expect(totals.contributions.fixed(2), '4500.30');
    expect(totals.withdrawals.fixed(2), '300.00');
    expect(totals.net.fixed(2), '4200.30');
    expect(totals.count, 7);
  });

  test('recurring reminders are sorted by their next occurrence and omit completed targets', () {
    final zone = tz.getLocation('Asia/Manila');
    final coordinator = ReminderCoordinator(
      repository: MemoryReminders(),
      scheduler: RecordingScheduler(zone),
      deviceStore: MemoryDeviceStore(),
    );
    coordinator.zone = zone;
    final now = tz.TZDateTime(zone, 2026, 10, 18, 12);
    final configs = [
      const ReminderConfiguration(
        uid: 'alex',
        type: ReminderTargetType.personalGoal,
        targetId: 'daily',
        enabled: true,
        frequency: ReminderFrequency.daily,
        hour: 8,
      ),
      ReminderConfiguration(
        uid: 'alex',
        type: ReminderTargetType.task,
        targetId: 'soon',
        enabled: true,
        instant: tz.TZDateTime(zone, 2026, 10, 18, 14),
      ),
      ReminderConfiguration(
        uid: 'alex',
        type: ReminderTargetType.task,
        targetId: 'done',
        enabled: true,
        instant: tz.TZDateTime(zone, 2026, 10, 18, 13),
      ),
    ];
    for (final config in configs) {
      coordinator.configurations[config.key] = config;
      coordinator.targets[config.key] = ReminderTarget(
        type: config.type,
        id: config.targetId,
        title: config.targetId,
        completed: config.targetId == 'done',
      );
    }
    final items = upcomingReminders(coordinator, now);
    expect(items.map((e) => e.target.id), ['soon', 'daily']);
    expect(items.last.at.day, 19);
    coordinator.dispose();
  });

  for (final mode in GoalPresentation.values) {
    for (final dark in [false, true]) {
      testWidgets(
        'gallery ${mode.name}, dark $dark, preserves actual values and navigation',
        (tester) async {
          var opens = 0;
          await mount(
            tester,
            page(
              GoalGallery(
                uid: 'fixture',
                records: fixtureGoals(),
                presentation: mode,
              ),
            ),
            dark: dark,
            width: 320,
            scale: 2,
          );
          expect(find.text('A home for our next chapter'), findsOneWidget);
          // Currency may reflow onto its own line at large text sizes.
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is AmountText && widget.text == 'PHP ₱42,000.00',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await mount(
            tester,
            page(
              AtelierGoalTile(
                uid: 'fixture',
                doc: fixtureGoals().first,
                onOpen: () => opens++,
              ),
            ),
            dark: dark,
          );
          await tester.tap(find.text('A home for our next chapter'));
          expect(opens, 1);
        },
      );
    }
  }

  testWidgets(
    'pinning changes the deterministic gallery order and missing pins fall back',
    (tester) async {
      await mount(
        tester,
        page(
          GoalGallery(
            uid: 'fixture',
            records: fixtureGoals(),
            featuredId: 'travel',
          ),
        ),
      );
      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where(
            (t) =>
                t == 'A home for our next chapter' ||
                t == 'A quiet weekend away',
          )
          .toList();
      expect(titles.first, 'A quiet weekend away');
      await mount(
        tester,
        page(
          GoalGallery(
            uid: 'fixture',
            records: fixtureGoals(),
            featuredId: 'deleted',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'goal search and completion filters operate on supplied records',
    (tester) async {
      await mount(
        tester,
        Scaffold(
          body: GoalBrowser(
            uid: 'fixture',
            records: [
              ...fixtureGoals(),
              PreviewDocument('done', {
                'title': 'Finished goal',
                'targetAmount': 100,
                'savedAmount': 125,
              }),
            ],
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Finished');
      await tester.pumpAndSettle();
      expect(find.text('Finished goal'), findsOneWidget);
      expect(find.text('A home for our next chapter'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
      await tester.pumpAndSettle();
      expect(
        find.text('No goals match your search and filters.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('zero-target and overfunded goals have bounded progress', (
    tester,
  ) async {
    await mount(
      tester,
      page(
        Column(
          children: [
            AtelierGoalTile(
              uid: 'fixture',
              compact: true,
              doc: PreviewDocument('zero', {
                'title': 'Zero',
                'savedAmount': 0,
                'targetAmount': 0,
              }),
            ),
            AtelierGoalTile(
              uid: 'fixture',
              compact: true,
              doc: PreviewDocument('over', {
                'title': 'Over target',
                'savedAmount': 150,
                'targetAmount': 100,
              }),
            ),
          ],
        ),
      ),
    );
    expect(
      tester
          .widgetList<MintProgress>(find.byType(MintProgress))
          .map((p) => p.value),
      [0.0, 1.0],
    );
    expect(find.text('Target reached'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pulse periods request actual date ranges; mixed currencies remain separate',
    (tester) async {
      final requests = <(DateTime, DateTime)>[];
      await mount(
        tester,
        page(
          SavingsPulse(
            uid: 'fixture',
            goals: const [],
            clock: () => date,
            load: (start, end) async {
              requests.add((start, end));
              return (
                [
                  ...fixtureActivity(),
                  for (var i = 0; i < 100; i++)
                    PulseEntry(
                      at: date,
                      amount: ExactDecimal.fromNum(1000000000000),
                      currency: 'PHP',
                    ),
                  PulseEntry(
                    at: date,
                    amount: ExactDecimal.parse('0.01'),
                    currency: 'PHP',
                  ),
                  PulseEntry(
                    at: date,
                    amount: ExactDecimal.fromNum(10),
                    currency: 'USD',
                  ),
                ],
                false,
              );
            },
          ),
        ),
      );
      expect(requests.single, (DateTime(2026, 10, 12), DateTime(2026, 10, 19)));
      expect(
        find.text('Net savings change: PHP ₱100,000,000,004,200.01'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'USD'));
      await tester.pumpAndSettle();
      expect(
        find.text('Net savings change: ${originalMoney(10, 'USD')}'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, '30 days'));
      await tester.pumpAndSettle();
      expect(requests.last.$1, DateTime(2026, 9, 19));
      await tester.tap(find.widgetWithText(ChoiceChip, 'This month'));
      await tester.pumpAndSettle();
      expect(requests.last.$1, DateTime(2026, 10, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pulse reports loading, empty and retryable errors without invented data',
    (tester) async {
      final pending = Completer<(List<PulseEntry>, bool)>();
      await mount(
        tester,
        page(
          SavingsPulse(
            uid: 'fixture',
            goals: const [],
            load: (_, _) => pending.future,
          ),
        ),
      );
      expect(find.byType(LoadingPanel), findsOneWidget);
      pending.complete((<PulseEntry>[], false));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No recorded savings activity'),
        findsOneWidget,
      );
      await mount(
        tester,
        page(
          SavingsPulse(
            uid: 'fixture',
            goals: const [],
            load: (_, _) async => (<PulseEntry>[], true),
          ),
        ),
      );
      expect(find.textContaining('No activity is cached'), findsOneWidget);
      var attempts = 0;
      await mount(
        tester,
        page(
          SavingsPulse(
            uid: 'fixture',
            goals: const [],
            load: (_, _) async {
              attempts++;
              throw StateError('offline');
            },
          ),
        ),
      );
      expect(find.textContaining('No partial totals'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    },
  );

  testWidgets(
    'customization reorders with buttons, hides sections and resets only layout',
    (tester) async {
      final storage = await SharedPreferences.getInstance();
      final preferences = AtelierPreferences(storage, account: 'alex');
      await mount(
        tester,
        CustomizeHomeScreen(preferences: preferences),
        dark: true,
        width: 320,
        scale: 2,
      );
      final target = find.byTooltip('Move Goal Gallery down');
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(preferences.order.first, HomeSection.pulse);
      final reset = find.text('Restore Default Layout');
      await tester.scrollUntilVisible(
        reset,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(preferences.order, HomeSection.values);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      preferences.dispose();
    },
  );

  for (final dark in [false, true]) {
    for (final size in [(320.0, 2.0), (390.0, 1.0), (1080.0, 1.0)]) {
      testWidgets(
        'signature surfaces render at ${size.$1}, scale ${size.$2}, dark $dark',
        (tester) async {
          final totals = PulseTotals(
            'PHP',
            DateTime(2026, 10, 12),
            DateTime(2026, 10, 19),
            fixtureActivity(),
          );
          await mount(
            tester,
            page(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScreenIntro(
                    eyebrow: 'Sunday, October 18',
                    title: 'Good afternoon.',
                    detail: 'Your progress, beautifully organized.',
                  ),
                  const SavingsOverview(total: 54500, target: 170000, count: 2),
                  const SizedBox(height: 24),
                  const AtelierSectionHeader(
                    title: 'Goal Gallery',
                    subtitle: 'Make room for what matters.',
                  ),
                  GoalGallery(uid: 'fixture', records: fixtureGoals()),
                  const SizedBox(height: 24),
                  const AtelierSectionHeader(
                    title: 'Savings Pulse',
                    subtitle: 'Your recent savings, in focus.',
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: PulseContent(totals: totals),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const AtelierSectionHeader(
                    title: 'Up Next',
                    subtitle: "What's coming up.",
                  ),
                  ReminderTimeline(
                    items: [
                      UpcomingReminder(
                        ReminderConfiguration(
                          uid: 'fixture',
                          type: ReminderTargetType.task,
                          targetId: 'task',
                          enabled: true,
                          instant: DateTime(2026, 10, 18, 16),
                        ),
                        const ReminderTarget(
                          type: ReminderTargetType.task,
                          id: 'task',
                          title: 'Make time for a weekly review',
                        ),
                        DateTime(2026, 10, 18, 16),
                      ),
                    ],
                    onOpen: (_) {},
                  ),
                ],
              ),
            ),
            dark: dark,
            width: size.$1,
            scale: size.$2,
          );
          expect(tester.takeException(), isNull);
          if (size.$2 > 1.5) {
            expect(find.text('A little closer, every day.'), findsNothing);
          }
          await capture(
            tester,
            'home-${dark ? 'dark' : 'light'}-${size.$1.toInt()}',
          );
          await tester.scrollUntilVisible(
            find.byType(PulseContent),
            500,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await capture(
            tester,
            'pulse-${dark ? 'dark' : 'light'}-${size.$1.toInt()}',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test(
    'dark semantic text and accent meet readable contrast on dark surfaces',
    () {
      final scheme = SaveTrackDesign.darkTheme.colorScheme;
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      expect(
        contrast(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.onSurfaceVariant, scheme.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.primary, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    },
  );
}

void additionalTests() {
  testWidgets('Up Next exposes initialization failures and unavailable times', (
    tester,
  ) async {
    final zone = tz.getLocation('Asia/Manila');
    final coordinator = ReminderCoordinator(
      repository: MemoryReminders(),
      scheduler: RecordingScheduler(zone),
      deviceStore: MemoryDeviceStore(),
    );
    coordinator.error = 'Reminder initialization failed';
    await mount(
      tester,
      page(
        ReminderScope(
          coordinator: coordinator,
          child: const UpcomingTimeline(),
        ),
      ),
    );
    expect(find.text('Reminder initialization failed'), findsOneWidget);
    expect(find.byType(LoadingPanel), findsNothing);
    coordinator.error = null;
    await mount(
      tester,
      page(
        ReminderScope(
          coordinator: coordinator,
          child: const UpcomingTimeline(),
        ),
      ),
    );
    expect(
      find.textContaining('Reminder times are unavailable'),
      findsOneWidget,
    );
    expect(find.byType(LoadingPanel), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
  });
  for (final goal in [true, false]) {
    testWidgets(
      '${goal ? 'goal' : 'task'} edits require confirmation on Cancel and Back',
      (tester) async {
        await mount(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => goal
                      ? showTestGoalForm(context)
                      : showTaskForm(
                          context,
                          doc: PreviewDocument('task', {
                            'title': 'Original task',
                            'dateKey': '2026-10-18',
                            'priority': 'Normal',
                          }),
                        ),
                  child: const Text('Open form'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open form'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'Changed plan',
        );
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(find.text('Changed plan'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsOneWidget);
        await tester.tap(find.text('Discard changes'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('transaction date headings only repeat when the day changes', (
    tester,
  ) async {
    final first = Timestamp.fromDate(DateTime(2026, 10, 18, 14));
    final second = Timestamp.fromDate(DateTime(2026, 10, 18, 10));
    final third = Timestamp.fromDate(DateTime(2026, 10, 17, 10));
    await mount(
      tester,
      page(
        Column(
          children: [
            TransactionDateGroup(
              at: first,
              previous: null,
              first: true,
              child: const Text('First'),
            ),
            TransactionDateGroup(
              at: second,
              previous: first,
              first: false,
              child: const Text('Second'),
            ),
            TransactionDateGroup(
              at: third,
              previous: second,
              first: false,
              child: const Text('Third'),
            ),
          ],
        ),
      ),
    );
    expect(find.text('October 18, 2026'), findsOneWidget);
    expect(find.text('October 17, 2026'), findsOneWidget);
  });
  testWidgets(
    'appearance choices fit large text and persist an actual theme change',
    (tester) async {
      final storage = await SharedPreferences.getInstance();
      final prefs = AtelierPreferences(storage, account: 'alex');
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showAppearancePicker(context, prefs),
                child: const Text('Appearance'),
              ),
            ),
          ),
        ),
        width: 320,
        scale: 2,
        height: 640,
      );
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Dark'));
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(AtelierPreferences.themeMode.value, ThemeMode.dark);
      expect(storage.getString('savetrack.appearance'), 'dark');
      await tester.pumpWidget(const SizedBox.shrink());
      prefs.dispose();
    },
  );
  for (final index in [1, 2, 3]) {
    testWidgets(
      'existing Planner, goal details and report surfaces support dark mode: $index',
      (tester) async {
        await mount(
          tester,
          regression.screens()[index],
          dark: true,
          width: 320,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        await capture(tester, 'existing-dark-$index');
      },
    );
  }
  testWidgets(
    'weekly agenda uses selected dates and actual weekly completion',
    (tester) async {
      var selected = DateTime(2026, 10, 18);
      final tasks = [
        PreviewDocument('today', {
          'title': 'Sunday review',
          'dateKey': '2026-10-18',
          'completed': false,
          'priority': 'Normal',
        }),
        PreviewDocument('monday', {
          'title': 'Monday planning',
          'dateKey': '2026-10-12',
          'completed': true,
          'priority': 'Low',
        }),
      ];
      await mount(
        tester,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => WeeklyPlanner(
              uid: 'fixture',
              selected: selected,
              onSelect: (day) => update(() => selected = day),
              header: const Text('Weekly'),
              taskStream: Stream.value(TestSnapshot(tasks)),
            ),
          ),
        ),
      );
      expect(find.text('Sunday review'), findsOneWidget);
      expect(find.text('Monday planning'), findsNothing);
      expect(
        tester
            .widget<FlowWeekSelector>(find.byType(FlowWeekSelector))
            .counts[DateTime.monday],
        1,
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(FlowWeekSelector),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Monday planning'), findsOneWidget);
      expect(find.text('Sunday review'), findsNothing);
      expect(
        tester.widget<DailyCompletion>(find.byType(DailyCompletion)).done,
        1,
      );
      expect(
        tester.widget<DailyCompletion>(find.byType(DailyCompletion)).total,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('transaction filters preserve deposit and withdrawal identity', (
    tester,
  ) async {
    await mount(
      tester,
      Scaffold(
        body: TransactionFilters(
          records: [
            PreviewDocument('add', {'type': 'deposit', 'note': 'Contribution'}),
            PreviewDocument('less', {
              'type': 'withdrawal',
              'note': 'Planned expense',
            }),
          ],
          builder: (context, records) => ListView(
            children: records.map((d) => Text('${d.data()['note']}')).toList(),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Withdrawn'));
    await tester.pumpAndSettle();
    expect(find.text('Planned expense'), findsOneWidget);
    expect(find.text('Contribution'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Added'));
    await tester.pumpAndSettle();
    expect(find.text('Contribution'), findsOneWidget);
    expect(find.text('Planned expense'), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets('Home Atelier ${dark ? 'dark' : 'light'} reference image', (
      tester,
    ) async {
      await mount(
        tester,
        page(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenIntro(
                eyebrow: 'Sunday, October 18',
                title: 'Good afternoon.',
                detail: 'Your progress, beautifully organized.',
              ),
              const SavingsOverview(total: 54500, target: 170000, count: 2),
              const SizedBox(height: 24),
              const AtelierSectionHeader(
                title: 'Goal Gallery',
                subtitle: 'Make room for what matters.',
              ),
              GoalGallery(
                uid: 'fixture',
                records: [
                  PreviewDocument('home', {
                    ...fixtureGoals().first.data(),
                    'deadline': null,
                  }),
                ],
              ),
            ],
          ),
        ),
        dark: dark,
        height: 1100,
      );
      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile(
          'goldens/atelier71-home-${dark ? 'dark' : 'light'}.png',
        ),
      );
    });
  }
}
