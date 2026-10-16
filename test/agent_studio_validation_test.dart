import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/agent_studio/agent_backend.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/reminder_repository.dart';
import 'package:myproject/reminder_models.dart';

import 'agent_studio_fixtures.dart';
import 'ai_coach_firestore_test.dart' show ContextDb, ContextAuth;
import 'profile_photo_firestore_backend_test.dart'
    show PhotoAuth, PhotoDatabase;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('conditional reminder creation reconciles replays and rejects concurrent edits', () async {
    final db = PhotoDatabase();
    final repository = FirestoreReminderRepository(db: db, auth: PhotoAuth());
    const config = ReminderConfiguration(
      uid: 'owner',
      type: ReminderTargetType.personalGoal,
      targetId: 'goalA',
      enabled: true,
      frequency: ReminderFrequency.weekly,
      weekday: 6,
      hour: 9,
    );
    await repository.createReviewed(config);
    final count = db.writes.length;
    await repository.createReviewed(config);
    expect(db.writes.length, count);
    final path = 'users/owner/reminders/personalGoal_goalA';
    db.documents[path]!['hour'] = 10;
    await expectLater(
      repository.createReviewed(config),
      throwsA(isA<ReminderFailure>()),
    );
    expect(db.documents[path]!['hour'], 10);
    expect(
      db.documents.keys.where((k) => k.contains('/transactions/')),
      isEmpty,
    );
  });
  test('server checks detect case-insensitive goal duplicates and overlapping existing task windows', () async {
    final server = ContextDb(), user = ContextAuth();
    final adapter = FirestoreAgentBackend(
      uid: 'private-uid',
      db: server,
      auth: user,
      reminders: null,
      openContribution: (_, _) async {},
    );
    server.documents['users/private-uid/goals/existing'] = {
      'title': 'LAPTOP',
      'archived': false,
    };
    server.documents['users/private-uid/tasks/existing'] = {
      'title': 'A different task',
      'dateKey': '2027-01-02',
      'time': '9:00 AM - 10:00 AM',
      'completed': false,
    };
    final m = AgentMission(
      id: 'missionA',
      uid: 'private-uid',
      title: 'Plan',
      createdAt: agentNow,
      steps: [
        AgentStep(id: 'goal', action: goalDraft()),
        AgentStep(
          id: 'task',
          action: taskDraft(time: '09:30'),
        ),
      ],
    );
    final issues = await adapter.check(m);
    expect(issues, contains(contains('already exists')));
    expect(issues, contains(contains('09:30')));
    expect(
      server.reads.every(
        (r) => r.$1.startsWith('users/private-uid/') && r.$2 == Source.server,
      ),
      true,
    );
  });
  test('account change during server read fails closed', () async {
    final server = ContextDb(), user = ContextAuth();
    final adapter = FirestoreAgentBackend(
      uid: 'private-uid',
      db: server,
      auth: user,
      reminders: null,
      openContribution: (_, _) async {},
    );
    server.afterRead = () => user.user = null;
    await expectLater(adapter.goals(), throwsA(isA<AgentFailure>()));
  });
  test(
    'equal allocation preserves every minor unit and never converts currencies',
    () async {
      final server = ContextDb(), user = ContextAuth();
      for (var i = 0; i < 3; i++) {
        server.documents['users/private-uid/goals/g$i'] = {
          'title': 'Goal $i',
          'archived': false,
          'currencyCode': 'PHP',
          'targetAmount': 100,
          'savedAmount': 0,
        };
      }
      server.documents['users/private-uid/goals/usd'] = {
        'title': 'USD Goal',
        'archived': false,
        'currencyCode': 'USD',
        'targetAmount': 100,
        'savedAmount': 0,
      };
      final adapter = FirestoreAgentBackend(
        uid: 'private-uid',
        db: server,
        auth: user,
        reminders: null,
        openContribution: (_, _) async {},
      );
      final m = AgentMission(
        id: 'missionA',
        uid: 'private-uid',
        title: 'Plan',
        createdAt: agentNow,
        steps: [
          AgentStep(
            id: 'allocation',
            action: const AllocationDraft(budget: '100', currency: 'PHP'),
          ),
        ],
      );
      final result = await adapter.perform(m, m.steps.single);
      expect(result.message, contains('33.34'));
      expect('33.33'.allMatches(result.message), hasLength(2));
      expect(result.message, isNot(contains('USD Goal')));
    },
  );
}
