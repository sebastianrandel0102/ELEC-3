// Deterministic presentation fixtures. These never write account records.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/atelier_preferences.dart';
import 'package:myproject/main.dart';
import 'package:myproject/shared_savings_models.dart';
import 'package:myproject/shared_savings_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_atelier_test.dart' show fixtureGoals;
import 'precision_edition_test.dart' as preview;
import 'redesign_test.dart' show TestDocument;
import 'ui_preview_fonts.dart';

Widget planner() => preview.page(
  'Planner',
  ListView(
    padding: const EdgeInsets.all(20),
    children: [
      AuroraModeSelector<bool>(
        selected: false,
        options: const {false: 'Daily', true: 'Weekly'},
        onSelected: (_) {},
      ),
      PlannerDateHeader(
        title: 'Saturday, October 24',
        onPrevious: () {},
        onNext: () {},
        onToday: () {},
        onPick: () {},
      ),
      const DailyCompletion(done: 1, total: 3),
      const SizedBox(height: 24),
      const AtelierSectionHeader(
        title: 'Your tasks',
        subtitle: 'One step at a time.',
      ),
      for (final entry in [
        ('Compare laptop prices', '10:00', false),
        ('Set aside this week\'s savings', '', false),
        ('Review my goal', '09:00', true),
      ])
        TaskTile(
          uid: 'fixture',
          doc: TestDocument({
            'title': entry.$1,
            'time': entry.$2,
            'priority': 'Normal',
            'completed': entry.$3,
            'dateKey': '2026-10-24',
          }),
        ),
    ],
  ),
);

Widget reports() => preview.page(
  'Reports',
  ReportsLayout(
    savings: const ReportMetric(
      title: 'Savings balance',
      value: 'PHP ₱12,500.00',
      caption: 'Across 1 personal goal. Target: PHP ₱50,000.00.',
      icon: Icons.savings_outlined,
      featured: true,
      progress: .25,
    ),
    shared: const TonalPanel(
      child: Text('Shared savings are reported separately.'),
    ),
    daily: const ReportMetric(
      title: 'Today\'s tasks',
      value: '1 / 3 completed',
      caption: 'October 24 · 2 remaining',
      icon: Icons.check_circle_outline,
      progress: 1 / 3,
    ),
    weekly: const ReportMetric(
      title: 'This week\'s tasks',
      value: '7 / 10 completed',
      caption: 'October 19–25 · 3 remaining',
      icon: Icons.check_circle_outline,
      progress: .7,
    ),
    goals: AtelierGoalTile(
      uid: 'fixture',
      doc: preview.goal(),
      compact: true,
      onOpen: () {},
    ),
  ),
);

Widget shared() => Scaffold(
  appBar: AppBar(title: const Text('Save Together')),
  body: ListView(
    padding: const EdgeInsets.all(20),
    children: [
      SharedGoalHero(
        goal: SharedSavingsGoal('fixture', {
          'name': 'A home for our next chapter',
          'ownerId': 'fixture-owner',
          'targetAmount': 150000,
          'currentAmount': 42000,
          'startDate': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'deadline': Timestamp.fromDate(DateTime(2027, 12, 31)),
          'memberCount': 3,
          'iconKey': 'home',
          'status': 'active',
        }),
      ),
      const SizedBox(height: 24),
      AuroraGroupedSection(
        title: 'Together',
        children: [
          ListTile(
            leading: const MemberAvatar('Jamie Santos'),
            title: const Text('Jamie Santos'),
            subtitle: const Text('Member'),
            trailing: IconButton(
              tooltip: 'View member',
              onPressed: () {},
              icon: const Icon(Icons.chevron_right),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.group_outlined),
            title: Text('3 members'),
            subtitle: Text('Contributions keep their attribution.'),
          ),
        ],
      ),
    ],
  ),
);

void main() {
  setUpAll(() => loadManropeForPreviews(force: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('reflowed money keeps one exact accessible currency value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await preview.mount(
      tester,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(20),
          child: AmountText(
            'PHP ₱1,000.00',
            compactCurrency: true,
            style: TextStyle(fontSize: 40),
          ),
        ),
      ),
      width: 320,
      scale: 1.5,
    );
    expect(find.bySemanticsLabel('PHP ₱1,000.00'), findsOneWidget);
    expect(find.text('Swipe to view full amount'), findsNothing);
    expect(find.text('1,000.00'), findsOneWidget);
    semantics.dispose();
  });

  test('input boundaries and progress endpoints remain distinguishable in both themes', () {
    double contrast(Color a, Color b) {
      final first = a.computeLuminance(), second = b.computeLuminance();
      return first > second
          ? (first + .05) / (second + .05)
          : (second + .05) / (first + .05);
    }

    for (final dark in [false, true]) {
      final theme = dark ? SaveTrackDesign.darkTheme : SaveTrackDesign.theme;
      final field = theme.inputDecorationTheme;
      expect(
        contrast(
          (field.enabledBorder! as OutlineInputBorder).borderSide.color,
          field.fillColor!,
        ),
        greaterThanOrEqualTo(3),
      );
      final track = dark ? const Color(0xFF315D50) : const Color(0xFFD8E8E0);
      for (final color
          in (dark
                  ? SaveTrackDesign.progressOnDark
                  : SaveTrackDesign.progressOnLight)
              .colors) {
        expect(contrast(color, track), greaterThanOrEqualTo(3));
      }
    }
  });

  testWidgets(
    'goal sorting, clearing and empty-result reset retain record identity',
    (tester) async {
      await preview.mount(
        tester,
        Scaffold(
          body: GoalBrowser(uid: 'fixture', records: fixtureGoals()),
        ),
      );
      await tester.tap(find.byTooltip('Sort goals'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<GoalSort>, 'Highest progress'),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<AtelierGoalTile>(find.byType(AtelierGoalTile))
            .first
            .doc
            .id,
        'travel',
      );
      await tester.enterText(find.byType(TextField), 'No such goal');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset search and filters'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), 'quiet');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('iOS wheels commit only Done and preserve date bounds', (
    tester,
  ) async {
    DateTime? committed;
    await tester.pumpWidget(
      MaterialApp(
        theme: SaveTrackDesign.theme.copyWith(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => committed = await showSaveTrackDatePicker(
                context: context,
                initialDate: DateTime(2026, 10, 24),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              ),
              child: const Text('Choose date'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    final wheel = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(wheel.minimumDate, DateTime(2020));
    expect(wheel.maximumDate, DateTime(2100));
    wheel.onDateTimeChanged(DateTime(2026, 10, 25));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(committed, isNull);
    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2026, 10, 26));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(committed, DateTime(2026, 10, 26));
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS time wheel preserves hour and minute through confirmation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 693);
    addTearDown(tester.view.reset);
    TimeOfDay? committed;
    await tester.pumpWidget(
      MaterialApp(
        theme: SaveTrackDesign.darkTheme.copyWith(platform: TargetPlatform.iOS),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => committed = await showSaveTrackTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 9, minute: 30),
              ),
              child: const Text('Choose time'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2026, 10, 24, 17, 45));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(committed, const TimeOfDay(hour: 17, minute: 45));
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Mint Atelier narrow keyboard ${dark ? 'dark' : 'light'} golden',
      (tester) async {
        await preview.mount(
          tester,
          const AuthScreen(),
          width: 320,
          height: 693,
          scale: 1.6,
          dark: dark,
        );
        await tester.tap(find.byType(TextFormField).first);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Sign in'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(preview.capture),
          matchesGoldenFile(
            'goldens/mint-atelier-keyboard-${dark ? 'dark' : 'light'}.png',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'Mint Atelier narrow large text ${dark ? 'dark' : 'light'} golden',
      (tester) async {
        await preview.mount(
          tester,
          planner(),
          width: 320,
          height: 693,
          scale: 2,
          dark: dark,
        );
        await expectLater(
          find.byKey(preview.capture),
          matchesGoldenFile(
            'goldens/mint-atelier-large-text-${dark ? 'dark' : 'light'}.png',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
    for (final scene in [
      'auth',
      'planner',
      'reports',
      'shared',
      'empty',
      'loading',
      'failure',
    ]) {
      testWidgets('Mint Atelier $scene ${dark ? 'dark' : 'light'} golden', (
        tester,
      ) async {
        final body = switch (scene) {
          'auth' => const AuthScreen(),
          'planner' => planner(),
          'reports' => reports(),
          'shared' => shared(),
          'empty' => preview.page(
            'Goals',
            GoalBrowser(uid: 'fixture', records: const []),
          ),
          'loading' => preview.page(
            'Today',
            ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                LoadingPanel(featured: true),
                SizedBox(height: 24),
                LoadingPanel(),
              ],
            ),
          ),
          _ => SetupScreen(error: 'private diagnostic', onRetry: () {}),
        };
        await preview.mount(tester, body, dark: dark);
        await expectLater(
          find.byKey(preview.capture),
          matchesGoldenFile(
            'goldens/mint-atelier-$scene-${dark ? 'dark' : 'light'}.png',
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.3, 1.6, 2.0]) {
        testWidgets(
          'phone layout $width scale $scale dark $dark keeps goals and planning readable',
          (tester) async {
            final height = switch (width) {
              320 => 693.0,
              375 => 812.0,
              430 => 932.0,
              _ => 844.0,
            };
            await preview.mount(
              tester,
              planner(),
              width: width,
              height: height,
              scale: scale,
              dark: dark,
            );
            await tester.drag(find.byType(ListView), const Offset(0, -600));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final preferences = AtelierPreferences(
              await SharedPreferences.getInstance(),
              account: 'fixture',
            )..goals = GoalPresentation.grid;
            addTearDown(preferences.dispose);
            await preview.mount(
              tester,
              AtelierScope(
                preferences: preferences,
                child: preview.page(
                  'Goals',
                  GoalBrowser(uid: 'fixture', records: fixtureGoals()),
                ),
              ),
              width: width,
              height: height,
              scale: scale,
              dark: dark,
            );
            await tester.drag(
              find.byType(CustomScrollView).last,
              const Offset(0, -450),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
