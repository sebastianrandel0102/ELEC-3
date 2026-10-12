import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/design_system.dart';
import 'package:myproject/shared_savings.dart';
import 'package:myproject/shared_savings_screens.dart';

class StreamRepository extends Fake implements SharedSavingsRepository {
  final events = StreamController<List<SharedSavingsGoal>>();
  int subscriptions = 0;

  @override
  Stream<List<SharedSavingsGoal>> watchGoals() {
    subscriptions++;
    return events.stream;
  }
}

void main() {
  SharedSavingsGoal goal({double balance = 12000, String status = 'active'}) =>
      SharedSavingsGoal('goal', {
        'name': 'Summer vacation with friends',
        'ownerId': 'owner',
        'targetAmount': 30000,
        'currentAmount': balance,
        'totalDeposits': 15000,
        'totalDecreases': 3000,
        'startDate': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'deadline': Timestamp.fromDate(DateTime.utc(2026, 12, 30)),
        'memberCount': 3,
        'status': status,
        'memberNames': {'owner': 'Alex', 'jamie': 'Jamie', 'sam': 'Sam'},
      });
  test(
    'shared listener clears sensitive totals after revoked access and recovers',
    () async {
      final repository = StreamRepository();
      final controller = SharedSavingsController(repository);
      addTearDown(repository.events.close);
      addTearDown(controller.dispose);
      expect(controller.loading, isTrue);
      repository.events.add([goal()]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.goals.single.balance, 12000);
      expect(controller.loading, isFalse);
      repository.events.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.goals, isEmpty);
      expect(controller.error, contains('denied'));
      repository.events.add([goal(balance: 500)]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.goals.single.balance, 500);
      expect(controller.error, isNull);
      expect(repository.subscriptions, 1);
    },
  );

  test(
    'disposing the shared controller cancels its account listener',
    () async {
      final repository = StreamRepository();
      final controller = SharedSavingsController(repository);
      expect(repository.events.hasListener, isTrue);
      controller.dispose();
      expect(repository.events.hasListener, isFalse);
      await repository.events.close();
    },
  );

  test(
    'shared progress, remaining amount, pace and status use combined balance',
    () {
      final g = goal();
      expect(g.progress, 0.4);
      expect(g.remaining, 18000);
      expect(g.deposits - g.decreases, g.balance);
      expect(g.daily(DateTime(2026, 12, 20)), 1800);
      expect(g.statusAt(DateTime(2027, 1, 1)), 'Overdue');
      expect(goal(balance: 35000).progress, 1);
      expect(goal(balance: 35000).remaining, 0);
      expect(goal(balance: 35000).statusAt(DateTime(2027)), 'Completed');
      expect(goal(status: 'archived').statusAt(DateTime(2026)), 'Archived');
    },
  );
  test('amount precision and grouping follow PHP convention', () {
    expect(parseSharedAmount('0.29'), 0.29);
    for (final v in [
      'NaN',
      'Infinity',
      '-1',
      '1.001',
      '1e3',
      '1000000000.01',
    ]) {
      expect(parseSharedAmount(v), isNull);
    }
    expect(sharedMoney(12345.67), 'PHP 12,345.67');
  });
  test('invitations expire without a client write', () {
    final i = SharedGoalInvitation('invite', {
      'status': 'pending',
      'expiresAt': Timestamp.fromDate(DateTime.utc(2026, 10, 10)),
    });
    expect(i.statusAt(DateTime.utc(2026, 10, 9)), 'pending');
    expect(i.statusAt(DateTime.utc(2026, 10, 11)), 'expired');
  });
  test(
    'new invitations expire seven days after the server creation timestamp',
    () {
      final invitation = SharedGoalInvitation('code', {
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 12, 10, 55)),
      });
      expect(invitation.expiresAt, DateTime.utc(2026, 10, 19, 10, 55));
      expect(
        invitation.statusAt(DateTime.utc(2026, 10, 19, 10, 54, 59)),
        'pending',
      );
      expect(
        invitation.statusAt(DateTime.utc(2026, 10, 19, 10, 55)),
        'expired',
      );
    },
  );
  testWidgets(
    'shared card remains readable on a small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: SaveTrackDesign.theme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 1000),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SharedGoalCard(goal: goal(), uid: 'owner'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Shared'), findsOneWidget);
      expect(find.text('PHP 12,000.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('member initials support Unicode and empty display names', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MemberAvatar('Jamie Santos'),
              MemberAvatar(''),
              MemberAvatar('🌱 Saver'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('JS'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
    expect(find.text('🌱S'), findsOneWidget);
  });
}
