// SDK interfaces are replaced only in tests; production uses real Firestore.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/decrease_savings_dialog.dart';
import 'package:myproject/main.dart';
import 'package:myproject/savings_decrease.dart';

import 'redesign_test.dart' as ui;

class SavingsUser extends Fake implements User {
  SavingsUser(this.uid);
  @override
  final String uid;
}

class SavingsAuth extends Fake implements FirebaseAuth {
  @override
  User? currentUser = SavingsUser('owner');
}

class SavingsSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  SavingsSnapshot(this.values);
  final Map<String, dynamic>? values;
  @override
  bool get exists => values != null;
  @override
  Map<String, dynamic>? data() => values;
}

class SavingsReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  SavingsReference(this.firestore, this.path);
  @override
  final SavingsFirestore firestore;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(SavingsSnapshot(firestore.documents[path]));
  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      SavingsCollection(firestore, '$path/$name');
}

class ActionGoal extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  ActionGoal(this.reference);
  @override
  final SavingsReference reference;
  @override
  Map<String, dynamic> data() => reference.firestore.documents[reference.path]!;
}

class SavingsCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  SavingsCollection(this.store, this.path);
  final SavingsFirestore store;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      SavingsReference(store, '$path/${id ?? 'request'}');
}

class SavingsTransaction extends Fake implements Transaction {
  SavingsTransaction(this.store) : version = store.version;
  final SavingsFirestore store;
  final int version;
  final writes = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    expect(writes, isEmpty, reason: 'All Firestore reads precede writes.');
    store.reads.add(reference.path);
    final data = store.documents[reference.path];
    return SavingsSnapshot(data == null ? null : Map.of(data))
        as DocumentSnapshot<T>;
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    writes[reference.path] = {
      ...store.documents[reference.path]!,
      ...Map<String, dynamic>.from(data),
    };
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    writes[reference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }
}

// Optimistic version checks exercise callback retries and atomic commit failure.
// Emulator tests separately verify real server transactions and security rules.
class SavingsFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final reads = <String>[];
  int version = 0, attempts = 0;
  Object? commitFailure;
  void Function()? beforeCommit;
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      attempts++;
      final transaction = SavingsTransaction(this);
      final result = await handler(transaction);
      final action = beforeCommit;
      beforeCommit = null;
      action?.call();
      if (commitFailure != null) throw commitFailure!;
      if (version != transaction.version) continue;
      documents.addAll(transaction.writes);
      if (transaction.writes.isNotEmpty) version++;
      return result;
    }
    throw FirebaseException(plugin: 'cloud_firestore', code: 'aborted');
  }
}

void main() {
  group('monetary validation', () {
    for (final input in [
      '',
      ' ',
      '0',
      '0.00',
      '-500',
      '+5',
      'abc',
      '1e3',
      'NaN',
      'Infinity',
      '1,000',
      '1.234',
      '.50',
      '1.',
      '5000.01',
    ]) {
      test('rejects "$input"', () {
        expect(validateDecreaseAmount(input, 5000), isNotNull);
      });
    }
    for (final input in ['0.01', '1000', '1000.50', '5000.00']) {
      test('accepts "$input"', () {
        expect(validateDecreaseAmount(input, 5000), isNull);
      });
    }
    test('readable zero, negative and insufficient messages', () {
      expect(
        validateDecreaseAmount('0', 5000),
        'Please enter an amount greater than zero.',
      );
      expect(
        validateDecreaseAmount('-500', 5000),
        'Please enter a valid positive amount.',
      );
      expect(
        validateDecreaseAmount('6000', 5000),
        'You cannot decrease more than your available savings.',
      );
    });
    test('exact balance and floating-point deposits cannot result in negative savings', () {
      expect(decreasedSavingsBalance(5000, 5000), 0);
      expect(decreasedSavingsBalance(0.3 - 0.1, 0.2), 0);
      expect(decreasedSavingsBalance(6000, 2000), 4000);
      for (final amount in [
        0.0,
        -1.0,
        5001.0,
        double.nan,
        double.infinity,
        1.001,
      ]) {
        expect(
          () => decreasedSavingsBalance(5000, amount),
          throwsA(isA<SavingsDecreaseFailure>()),
        );
      }
    });
  });

  group('atomic Firestore operation', () {
    late SavingsFirestore db;
    late SavingsAuth auth;
    late SavingsReference goal;
    Future<void> withdraw(
      double amount, {
      String id = 'stable',
      String note = 'Emergency expense',
    }) => decreaseSavings(
      goal: goal,
      uid: 'owner',
      amount: amount,
      note: note,
      requestId: id,
      auth: auth,
    );
    setUp(() {
      db = SavingsFirestore();
      auth = SavingsAuth();
      goal = SavingsReference(db, 'users/owner/goals/emergency');
      db.documents[goal.path] = {
        'savedAmount': 5000.0,
        'targetAmount': 10000.0,
        'title': 'Emergency fund',
      };
    });
    test('records positive peso withdrawal and updates only the selected user goal', () async {
      db.documents['users/owner/goals/other'] = {'savedAmount': 999.0};
      await withdraw(1500);
      expect(db.documents[goal.path]!['savedAmount'], 3500);
      expect(db.documents[goal.path]!['lastWithdrawalId'], 'stable');
      expect(db.documents[goal.path]!['updatedAt'], isA<FieldValue>());
      expect(db.documents['${goal.path}/transactions/stable'], {
        'amount': 1500.0,
        'type': 'withdrawal',
        'note': 'Emergency expense',
        'date': isA<FieldValue>(),
      });
      expect(db.documents['users/owner/goals/other']!['savedAmount'], 999);
      expect(db.reads.every((path) => path.startsWith(goal.path)), isTrue);
    });
    test('failed commit leaves both balance and history unchanged', () async {
      db.commitFailure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await expectLater(withdraw(1500), throwsA(isA<FirebaseException>()));
      expect(db.documents[goal.path]!['savedAmount'], 5000);
      expect(db.documents.length, 1);
    });
    test('repeated request succeeds without a second decrease even at zero balance', () async {
      await withdraw(5000);
      await withdraw(5000);
      expect(db.documents[goal.path]!['savedAmount'], 0);
      expect(db.documents.length, 2);
      await expectLater(withdraw(1), throwsA(isA<SavingsDecreaseFailure>()));
    });
    test(
      'callback retry uses the same record and latest authoritative balance',
      () async {
        db.beforeCommit = () {
          db.documents[goal.path]!['savedAmount'] = 6000.0;
          db.version++;
        };
        await withdraw(1500);
        expect(db.attempts, 2);
        expect(db.documents[goal.path]!['savedAmount'], 4500);
        expect(db.documents.length, 2);
      },
    );
    test('concurrent withdrawals cannot overdraw', () async {
      final results = await Future.wait([
        withdraw(
          3000,
          id: 'first',
        ).then<Object?>((_) => null, onError: (Object error) => error),
        withdraw(
          3000,
          id: 'second',
        ).then<Object?>((_) => null, onError: (Object error) => error),
      ]);
      expect(results.whereType<SavingsDecreaseFailure>().length, 1);
      expect(db.documents[goal.path]!['savedAmount'], 2000);
      expect(db.documents.length, 2);
    });
    test('stale insufficient balance is rejected without writes', () async {
      db.documents[goal.path]!['savedAmount'] = 100.0;
      await expectLater(withdraw(1500), throwsA(isA<SavingsDecreaseFailure>()));
      expect(db.documents.length, 1);
      expect(db.documents[goal.path]!['savedAmount'], 100);
    });
    test(
      'missing, unauthenticated and other-owner goals are rejected',
      () async {
        db.documents.clear();
        await expectLater(withdraw(1), throwsA(isA<SavingsDecreaseFailure>()));
        auth.currentUser = null;
        db.reads.clear();
        await expectLater(withdraw(1), throwsA(isA<SavingsDecreaseFailure>()));
        expect(db.reads, isEmpty);
        auth.currentUser = SavingsUser('owner');
        goal = SavingsReference(db, 'users/someone-else/goals/emergency');
        await expectLater(withdraw(1), throwsA(isA<SavingsDecreaseFailure>()));
        expect(db.reads, isEmpty);
      },
    );
  });

  Future<void> openForm(
    WidgetTester tester, {
    required Future<void> Function(double, String) onConfirm,
    Stream<DocumentSnapshot<Map<String, dynamic>>>? updates,
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0,
  }) async {
    await ui.mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => DecreaseSavingsDialog(
                initialGoal: const {
                  'title': 'Emergency fund',
                  'savedAmount': 5000.0,
                  'targetAmount': 10000.0,
                },
                goalUpdates: updates ?? const Stream.empty(),
                formatMoney: (amount) => 'PHP ${amount.toStringAsFixed(2)}',
                onConfirm: onConfirm,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
      size: size,
      scale: scale,
      keyboard: keyboard,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'live preview and invalid values never display negative balances',
    (tester) async {
      var calls = 0;
      await openForm(
        tester,
        onConfirm: (_, _) async {
          calls++;
        },
      );
      expect(find.text('Goal: Emergency fund'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('decrease-amount')),
        '1500',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('New Savings Balance: PHP 3500.00'),
        findsOneWidget,
      );
      expect(calls, 0);
      await tester.enterText(
        find.byKey(const ValueKey('decrease-amount')),
        '6000',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('You cannot decrease more than your available savings.'),
        findsOneWidget,
      );
      expect(find.text('New Savings Balance: —'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirm Decrease'));
      await tester.tap(find.text('Confirm Decrease'));
      expect(calls, 0);
    },
  );
  testWidgets(
    'submission blocks duplicate taps and closes only after success',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await openForm(
        tester,
        onConfirm: (amount, note) {
          calls++;
          expect(amount, 1500);
          expect(note, 'Emergency expense');
          return pending.future;
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('decrease-amount')),
        '1500',
      );
      await tester.enterText(
        find.byKey(const ValueKey('decrease-note')),
        'Emergency expense',
      );
      await tester.ensureVisible(find.text('Confirm Decrease'));
      await tester.tap(find.text('Confirm Decrease'));
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(DecreaseSavingsDialog), findsOneWidget);
      expect(
        tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(DecreaseSavingsDialog), findsNothing);
    },
  );
  testWidgets(
    'uncertain network failure preserves payload for an idempotent retry',
    (tester) async {
      var calls = 0;
      await openForm(
        tester,
        onConfirm: (amount, note) async {
          expect(amount, 1500);
          expect(note, 'Emergency expense');
          if (calls++ == 0) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            );
          }
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('decrease-amount')),
        '1500',
      );
      await tester.enterText(
        find.byKey(const ValueKey('decrease-note')),
        'Emergency expense',
      );
      await tester.ensureVisible(find.text('Confirm Decrease'));
      await tester.tap(find.text('Confirm Decrease'));
      await tester.pumpAndSettle();
      expect(find.byType(DecreaseSavingsDialog), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('decrease-note')))
            .enabled,
        isFalse,
      );
      expect(find.textContaining('Check your connection'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirm Decrease'));
      await tester.tap(find.text('Confirm Decrease'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(DecreaseSavingsDialog), findsNothing);
    },
  );
  testWidgets('live balance updates and deleted goals disable confirmation', (
    tester,
  ) async {
    final updates = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
    addTearDown(updates.close);
    await openForm(tester, updates: updates.stream, onConfirm: (_, _) async {});
    await tester.enterText(
      find.byKey(const ValueKey('decrease-amount')),
      '1500',
    );
    updates.add(
      SavingsSnapshot({
        'title': 'Emergency fund',
        'savedAmount': 3000.0,
        'targetAmount': 10000.0,
      }),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('New Savings Balance: PHP 1500.00'),
      findsOneWidget,
    );
    updates.add(SavingsSnapshot(null));
    await tester.pumpAndSettle();
    expect(
      find.text('This savings goal is no longer available.'),
      findsOneWidget,
    );
    expect(
      tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
      isNull,
    );
  });
  for (final size in [const Size(320, 640), const Size(1200, 900)]) {
    testWidgets('decrease form fits $size with large text and keyboard', (
      tester,
    ) async {
      await openForm(
        tester,
        size: size,
        scale: 2,
        keyboard: 260,
        onConfirm: (_, _) async {},
      );
      await tester.ensureVisible(find.text('Cancel'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(DecreaseSavingsDialog), findsNothing);
    });
  }
  testWidgets(
    'history distinguishes withdrawals while preserving typed and legacy deposits',
    (tester) async {
      final goal = ui.TestDocument({'title': 'Emergency fund'});
      goal.testReference.records.addAll([
        ui.TestDocument({
          'amount': 500.0,
          'type': 'withdrawal',
          'note': 'Emergency',
          'date': Timestamp.fromDate(DateTime(2026, 10, 11)),
        }),
        ui.TestDocument({
          'amount': 1000.0,
          'type': 'deposit',
          'date': Timestamp.fromDate(DateTime(2026, 10, 10)),
        }),
        ui.TestDocument({
          'amount': 2000.0,
          'date': Timestamp.fromDate(DateTime(2026, 10, 9)),
        }),
      ]);
      await ui.mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTransactionHistory(context, goal),
              child: const Text('History'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('-PHP ₱500.00'), findsOneWidget);
      expect(find.text('Savings Decreased'), findsOneWidget);
      expect(find.text('Reason: Emergency'), findsOneWidget);
      expect(find.text('+PHP ₱1,000.00'), findsOneWidget);
      expect(find.text('+PHP ₱2,000.00'), findsOneWidget);
      expect(find.byIcon(Icons.south_east), findsOneWidget);
      expect(find.byIcon(Icons.south_west), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'goal actions preserve all existing choices and disable empty withdrawals',
    (tester) async {
      for (final balance in [5000.0, 0.0]) {
        await ui.mount(
          tester,
          ui.scrollPage(
            GoalCard(
              uid: 'owner',
              doc: ui.TestDocument({
                'title': 'Emergency fund',
                'savedAmount': balance,
                'targetAmount': 10000.0,
              }),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Goal actions'));
        await tester.pumpAndSettle();
        expect(find.text('Add savings'), findsNWidgets(2));
        expect(find.text('Edit goal'), findsOneWidget);
        expect(find.text('Delete goal'), findsOneWidget);
        final withdrawal = tester.widget<PopupMenuItem<String>>(
          find.ancestor(
            of: find.text('Decrease Savings'),
            matching: find.byType(PopupMenuItem<String>),
          ),
        );
        expect(withdrawal.enabled, balance > 0);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets('selecting Decrease Savings opens the exact goal from its menu', (
    tester,
  ) async {
    final db = SavingsFirestore();
    final selected = SavingsReference(db, 'users/owner/goals/selected');
    db.documents[selected.path] = {
      'title': 'Selected fund',
      'savedAmount': 2500.0,
      'targetAmount': 8000.0,
    };
    db.documents['users/owner/goals/other'] = {
      'title': 'Other fund',
      'savedAmount': 9000.0,
      'targetAmount': 20000.0,
    };
    await ui.mount(
      tester,
      ui.scrollPage(GoalCard(uid: 'owner', doc: ActionGoal(selected))),
    );
    await tester.tap(find.byTooltip('Goal actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decrease Savings'));
    await tester.pumpAndSettle();
    expect(find.text('Goal: Selected fund'), findsOneWidget);
    expect(find.text('Current Savings: PHP ₱2,500.00'), findsOneWidget);
    expect(find.text('Target Amount: PHP ₱8,000.00'), findsOneWidget);
    expect(find.text('Goal: Other fund'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(db.documents.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced balance drives existing progress, remaining amount and overdue status',
    (tester) async {
      for (final overdue in [false, true]) {
        final values = {
          'title': 'Emergency fund',
          'savedAmount': 10000.0,
          'targetAmount': 10000.0,
          'deadline': Timestamp.fromDate(
            DateTime.now().add(Duration(days: overdue ? -2 : 10)),
          ),
        };
        await ui.mount(
          tester,
          ui.scrollPage(GoalCard(uid: 'owner', doc: ui.TestDocument(values))),
        );
        expect(find.text('Goal reached'), findsOneWidget);
        values['savedAmount'] = decreasedSavingsBalance(10000, 6000);
        await ui.mount(
          tester,
          ui.scrollPage(GoalCard(uid: 'owner', doc: ui.TestDocument(values))),
        );
        expect(find.text('Goal reached'), findsNothing);
        expect(find.text('40% saved'), findsOneWidget);
        expect(find.text('PHP ₱6,000.00 to go'), findsOneWidget);
        expect(
          tester.widget<MintProgress>(find.byType(MintProgress)).value,
          .4,
        );
        expect(
          find.text('Overdue  PHP ₱6,000.00 remaining'),
          overdue ? findsOneWidget : findsNothing,
        );
      }
    },
  );
}
