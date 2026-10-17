import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_backend.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/app_record_repository.dart';

import 'agent_studio_fixtures.dart';
import 'profile_photo_firestore_backend_test.dart'
    show PhotoAuth, PhotoDatabase, PhotoUser;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PhotoDatabase db;
  late PhotoAuth auth;
  late FirestoreAgentBackend backend;
  int contributionScreens = 0;
  AgentMission mission(AgentAction action) => AgentMission(
    id: 'missionA',
    uid: 'owner',
    title: 'Plan',
    createdAt: agentNow,
    steps: [AgentStep(id: 'step_1', action: action)],
  );
  setUp(() {
    db = PhotoDatabase();
    auth = PhotoAuth();
    contributionScreens = 0;
    backend = FirestoreAgentBackend(
      uid: 'owner',
      db: db,
      auth: auth,
      reminders: null,
      openContribution: (id, amount) async {
        contributionScreens++;
      },
    );
  });
  test('real goal adapter preserves currency schema, zero balance, server creation and operation ID', () async {
    final m = mission(goalDraft());
    final result = await backend.perform(m, m.steps.single);
    final goal = db.documents['users/owner/goals/${result.recordId}']!;
    expect(goal['targetAmount'], 30000);
    expect(goal['savedAmount'], 0);
    expect(goal['currencyCode'], 'PHP');
    expect(goal['agentOperation'], jsonEncode(goalDraft().toJson()));
    expect(goal['archived'], false);
    expect(db.writes.where((w) => w.$1.contains('transactions')), isEmpty);
  });
  test(
    'retry reconciles the same goal ID without replacing later savings',
    () async {
      final m = mission(goalDraft());
      final result = await backend.perform(m, m.steps.single);
      final path = 'users/owner/goals/${result.recordId}';
      db.documents[path]!['savedAmount'] = 500;
      final writes = db.writes.length;
      await backend.perform(m, m.steps.single);
      expect(db.writes, hasLength(writes));
      expect(db.documents[path]!['savedAmount'], 500);
      final changed = mission(goalDraft(amount: '20000'));
      await expectLater(
        backend.perform(changed, changed.steps.single),
        throwsStateError,
      );
      expect(db.documents[path]!['targetAmount'], 30000);
    },
  );
  test(
    'actual task adapter creates standard planner fields and safely retries',
    () async {
      final m = mission(taskDraft(time: '14:00'));
      final result = await backend.perform(m, m.steps.single);
      final task = db.documents['users/owner/tasks/${result.recordId}']!;
      expect(task['dateKey'], '2027-01-02');
      expect(task['time'], '14:00');
      expect(task['completed'], false);
      expect(task['priority'], 'Normal');
      await backend.perform(m, m.steps.single);
      expect(db.writes.where((w) => w.$1.contains('/tasks/')), hasLength(1));
    },
  );
  test('contribution only opens the protected screen; no transaction or balance write', () async {
    final m = mission(
      const ContributionDraft(goalId: 'goalA', amount: '200', currency: 'PHP'),
    );
    await backend.perform(m, m.steps.single);
    expect(contributionScreens, 1);
    expect(db.writes, isEmpty);
  });
  test('changed auth, invalid paths, unsupported record collections fail before writing', () async {
    auth.session = PhotoUser('other');
    final m = mission(goalDraft());
    await expectLater(
      backend.perform(m, m.steps.single),
      throwsA(isA<AgentFailure>()),
    );
    final repo = AppRecordRepository(db: db, auth: auth);
    await expectLater(
      repo.create(uid: 'other', collection: 'transactions', id: 'x', data: {}),
      throwsFormatException,
    );
    await expectLater(
      repo.create(uid: 'other', collection: 'goals', id: '../other', data: {}),
      throwsFormatException,
    );
    expect(db.writes, isEmpty);
  });
  test(
    'financial scenarios are computed locally without repository writes',
    () async {
      final m = mission(
        const ScenarioDraft(
          target: '30000',
          saved: '10000',
          contribution: '500',
          currency: 'PHP',
        ),
      );
      final result = await backend.perform(m, m.steps.single);
      expect(result.message, startsWith('40 weekly'));
      expect(db.writes, isEmpty);
    },
  );
}
