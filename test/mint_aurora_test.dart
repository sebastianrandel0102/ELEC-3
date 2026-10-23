import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/design_system.dart';
import 'package:myproject/shared_savings.dart';
import 'package:myproject/shared_savings_screens.dart';

import 'redesign_test.dart' as previews;
import 'ui_preview_fonts.dart';

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

  final goal = SharedSavingsGoal('isolated-preview', {
    'name': 'A home for our next chapter',
    'description': 'Building a little more room for everyone.',
    'ownerId': 'fixture-owner',
    'targetAmount': 150000,
    'currentAmount': 42000,
    'totalDeposits': 45000,
    'totalDecreases': 3000,
    'startDate': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
    'deadline': Timestamp.fromDate(DateTime.utc(2026, 12, 30)),
    'memberCount': 3,
    'iconKey': 'home',
    'status': 'active',
    'memberNames': {
      'one': 'Alex Rivera',
      'two': 'Jamie Santos',
      'three': 'Sam Lee',
    },
  });

  testWidgets('long financial values remain intact and explicitly scrollable', (
    tester,
  ) async {
    const value = 'PHP ₱987,654,321.00';
    await previews.mount(
      tester,
      previews.scrollPage(
        AmountText(value, style: SaveTrackDesign.amount.copyWith(color: teal)),
      ),
      size: const Size(320, 640),
      scale: 2,
    );
    expect(find.text(value), findsOneWidget);
    expect(find.text('Swipe to view full amount'), findsOneWidget);
    expect(tester.widget<Text>(find.text(value)).softWrap, isFalse);
    final horizontal = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.right,
    );
    expect(horizontal, findsOneWidget);
    await tester.drag(horizontal, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(horizontal).position.pixels,
      greaterThan(0),
    );
    await previews.capture(tester, 'long-amount-narrow');
    expect(tester.takeException(), isNull);
  });

  for (final sample in [
    (const Size(390, 844), 1.0, 'shared-goal'),
    (const Size(320, 640), 2.0, 'shared-goal-narrow'),
    (const Size(1280, 800), 1.0, 'shared-goal-wide'),
  ]) {
    testWidgets('shared financial surfaces retain values at ${sample.$1}', (
      tester,
    ) async {
      await previews.mount(
        tester,
        previews.scrollPage(
          Column(
            children: [
              SharedGoalHero(goal: goal),
              const SizedBox(height: 24),
              SharedGoalCard(goal: goal, uid: 'fixture-owner'),
            ],
          ),
        ),
        size: sample.$1,
        scale: sample.$2,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is AmountText && widget.text == 'PHP ₱42,000.00',
        ),
        findsNWidgets(2),
      );
      for (final progress in tester.widgetList<MintProgress>(
        find.byType(MintProgress),
      )) {
        expect(progress.value, .28);
      }
      await previews.capture(tester, sample.$3);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'activity differentiates deposits and decreases without losing notes',
    (tester) async {
      SharedSavingsTransaction record(String type, String name, String note) =>
          SharedSavingsTransaction(type, {
            'displayName': name,
            'type': type,
            'amount': 2500,
            'date': Timestamp.fromDate(DateTime.utc(2026, 10, 13)),
            'note': note,
          });
      await previews.mount(
        tester,
        previews.scrollPage(
          Column(
            children: [
              SharedActivityTile(
                record: record(
                  'deposit',
                  'Jamie Santos',
                  'For our next chapter.',
                ),
              ),
              SharedActivityTile(
                record: record(
                  'withdrawal',
                  'Alex Rivera',
                  'A planned expense.',
                ),
              ),
            ],
          ),
        ),
        size: const Size(320, 844),
        scale: 2,
      );
      expect(find.text('For our next chapter.'), findsOneWidget);
      expect(find.text('A planned expense.'), findsOneWidget);
      expect(find.text('+PHP ₱2,500.00'), findsOneWidget);
      expect(find.text('−PHP ₱2,500.00'), findsOneWidget);
      await previews.capture(tester, 'shared-activity-narrow');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('notice and tab selector remain readable with enlarged text', (
    tester,
  ) async {
    await previews.mount(
      tester,
      previews.scrollPage(
        const DefaultTabController(
          length: 2,
          child: Column(
            children: [
              AuroraTabs(
                tabs: [
                  Tab(text: 'Personal'),
                  Tab(text: 'Shared'),
                ],
              ),
              SharedNotice(
                'No pending invitations. Your circle is up to date.',
              ),
              SharedNotice(
                'Could not update this goal. Check your connection and try again.',
                error: true,
              ),
            ],
          ),
        ),
      ),
      size: const Size(320, 640),
      scale: 2,
    );
    await tester.tap(find.text('Shared'));
    await tester.pumpAndSettle();
    await previews.capture(tester, 'shared-states-narrow');
    expect(tester.takeException(), isNull);
  });
}
