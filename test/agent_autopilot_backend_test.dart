import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_backend.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_engine.dart';
import 'package:myproject/agent_studio/agent_planner.dart';
import 'package:myproject/agent_studio/autopilot/execution_ledger.dart';
import 'package:myproject/reminder_coordinator.dart';
import 'package:myproject/reminder_repository.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'agent_autopilot_database.dart';
import 'agent_autopilot_policy_test.dart' show enableAutopilot;
import 'agent_studio_fixtures.dart';
import 'ai_coach_firestore_test.dart' show ContextAuth;
import 'reminder_system_test.dart' show RecordingScheduler, MemoryDeviceStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AutopilotDatabase db;
  late ContextAuth auth;
  late RecordingScheduler scheduler;
  late ReminderCoordinator coordinator;
  late AgentEngine engine;
  late MemoryExecutionLedger ledger;
  late DateTime now;
  var forms = 0;
  setUp(() async {
    tzdata.initializeTimeZones();
    now = DateTime.now();
    forms = 0;
    db = AutopilotDatabase();
    auth = ContextAuth();
    scheduler = RecordingScheduler(tz.getLocation('Asia/Manila'));
    coordinator = ReminderCoordinator(
      repository: FirestoreReminderRepository(db: db, auth: auth),
      scheduler: scheduler,
      deviceStore: MemoryDeviceStore(),
      clock: () => now,
    );
    await coordinator.initialize();
    coordinator.uid = 'private-uid';
    ledger = MemoryExecutionLedger();
    engine = AgentEngine(
      uid: 'private-uid',
      currentUid: () => auth.currentUser?.uid,
      backend: FirestoreAgentBackend(
        uid: 'private-uid',
        db: db,
        auth: auth,
        reminders: coordinator,
        openContribution: (_, _) async {
          forms++;
        },
      ),
      store: MemoryAgentStore(),
      ledger: ledger,
      clock: () => now,
    );
    await enableAutopilot(engine);
    db.documents['users/private-uid/goals/laptop'] = {
      'title': 'Laptop',
      'targetAmount': 30000.0,
      'savedAmount': 0.0,
      'currencyCode': 'PHP',
      'archived': false,
      'deadline': Timestamp.fromDate(now.add(const Duration(days: 365))),
    };
  });
  tearDown(() {
    engine.dispose();
    coordinator.dispose();
  });
  Future<void> command(String text) async => engine.handleUserPlan(
    LocalAgentPlanner().plan(
      text,
      now: now,
      defaultCurrency: 'PHP',
      goals: [const AgentRecord('laptop', 'Laptop', currency: 'PHP')],
    ),
  );

  test('real reminder repository persists and existing scheduler receives the requested weekly alarm', () async {
    await command('Remind me every Friday at 7 PM to save for Laptop.');
    expect(
      engine.mission!.status,
      MissionStatus.completed,
      reason: engine.error,
    );
    final config =
        db.documents['users/private-uid/reminders/personalGoal_laptop']!;
    expect(config['weekday'], 5);
    expect(config['hour'], 19);
    expect(config['frequency'], 'weekly');
    expect(scheduler.scheduled, 1);
    expect(scheduler.dates.values.single.weekday, DateTime.friday);
    expect(scheduler.dates.values.single.hour, 19);
    expect(engine.mission!.steps.single.result, contains('scheduled'));
  });
  for (final denied in ['permission', 'unsupported']) {
    test('notification $denied prevents an automatic reminder write', () async {
      if (denied == 'permission') {
        scheduler.allowed = false;
      } else {
        scheduler.supported = false;
      }
      await command('Remind me every Friday at 7 PM to save for Laptop.');
      expect(db.writes, 0);
      expect(scheduler.scheduled, 0);
      expect(engine.error, contains('notifications'));
    });
  }
  test(
    'repeated text command is checked against actual persisted task data',
    () async {
      await command('Create a task called Homework tomorrow');
      expect(db.writes, 1);
      await command('Create a task called Homework tomorrow');
      expect(db.writes, 1);
      expect(engine.error, contains('already on this date'));
    },
  );
  test(
    'revocation inside the transaction read prevents the actual tx.set',
    () async {
      db.beforeTransactionRead = () async {
        db.beforeTransactionRead = null;
        await engine.pauseAutopilot();
      };
      await command('Create a task called Homework tomorrow');
      expect(db.writes, 0);
      expect(
        engine.automaticActivity.single.status,
        AgentOperationStatus.uncertain,
      );
    },
  );
  test('auto-preparation opens only Add Savings and never writes a balance or transaction', () async {
    await enableAutopilot(engine, changes: {'autoPrepareContributions': true});
    await command('Add PHP 500 to my Laptop goal');
    expect(forms, 1);
    expect(db.writes, 0);
    expect(db.documents['users/private-uid/goals/laptop']!['savedAmount'], 0);
    expect(
      engine.automaticActivity.single.authorizationKind,
      'autopilotPreparationOnly',
    );
    expect(engine.mission!.steps.single.result, contains('not recorded'));
  });
  test('explicit task Undo deletes the exact unchanged record and records reversal', () async {
    await command('Create a task called Homework tomorrow');
    final record = engine.automaticActivity.single;
    expect(engine.canUndoAutomaticTask(record), true);
    await engine.undoAutomaticTask(record);
    expect(db.documents['users/private-uid/tasks/${record.recordId}'], isNull);
    expect(
      engine.automaticActivity.single.status,
      AgentOperationStatus.reversed,
    );
    await expectLater(
      engine.undoAutomaticTask(record),
      throwsA(isA<AgentFailure>()),
    );
  });
  test('restart reconciliation confirms an interrupted stable operation without replaying a write', () async {
    await command('Create a task called Homework tomorrow');
    final record = engine.automaticActivity.single;
    ledger.records['private-uid'] = [
      record.finish(
        AgentOperationStatus.dispatched,
        'Interrupted before confirmation.',
        record.recordId,
      ),
    ];
    final writes = db.writes;
    final restarted = AgentEngine(
      uid: 'private-uid',
      currentUid: () => auth.currentUser?.uid,
      backend: engine.backend,
      store: MemoryAgentStore(),
      ledger: ledger,
      clock: () => now,
    );
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(db.writes, writes);
    await restarted.reconcileAutomaticRecord(
      restarted.automaticActivity.single,
    );
    expect(
      restarted.automaticActivity.single.status,
      AgentOperationStatus.completed,
    );
    expect(db.writes, writes);
  });
  test(
    'a missing interrupted operation is not replayed by reconciliation',
    () async {
      db.beforeTransactionRead = () async {
        db.beforeTransactionRead = null;
        await engine.pauseAutopilot();
      };
      await command('Create a task called Homework tomorrow');
      final record = engine.automaticActivity.single;
      await engine.reconcileAutomaticRecord(record);
      expect(db.writes, 0);
      expect(
        engine.automaticActivity.single.status,
        AgentOperationStatus.uncertain,
      );
      expect(
        engine.automaticActivity.single.message,
        contains('No action was replayed'),
      );
    },
  );
  for (final change in [
    'completed',
    'edited',
    'reminder',
    'expired',
    'account',
  ]) {
    test('Undo refuses a task that is $change', () async {
      await command('Create a task called Homework tomorrow');
      final record = engine.automaticActivity.single;
      final path = 'users/private-uid/tasks/${record.recordId}';
      switch (change) {
        case 'completed':
          db.documents[path]!['completed'] = true;
        case 'edited':
          db.documents[path]!['title'] = 'New title';
        case 'reminder':
          db.documents['users/private-uid/reminders/task_${record.recordId}'] =
              {};
        case 'expired':
          now = now.add(const Duration(minutes: 11));
        case 'account':
          auth.user = null;
      }
      await expectLater(
        engine.undoAutomaticTask(record),
        throwsA(anyOf(isA<AgentFailure>(), isA<StateError>())),
      );
      expect(db.documents[path], isNotNull);
    });
  }
}
