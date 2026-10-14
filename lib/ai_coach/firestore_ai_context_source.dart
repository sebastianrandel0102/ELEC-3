import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../currency_money.dart';
import '../shared_savings_models.dart';
import '../smart_task_recommendation_service.dart';
import 'ai_domain.dart';
import 'ai_facts.dart';
import 'ai_gateway.dart';

/// Read-only server reads on explicit Coach actions only. No transactions,
/// member identities, notes, profile records, documents, or model tools.
class FirestoreAiContextSource implements AiContextSource, AiContextWatcher {
  FirestoreAiContextSource({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : db = firestore ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  String get uid =>
      auth.currentUser?.uid ??
      (throw const AiFailure(
        AiErrorKind.authentication,
        'Sign in again to review your data.',
      ));
  static const server = GetOptions(source: Source.server);
  CollectionReference<Map<String, dynamic>> _personal(
    String owner,
    String collection,
  ) => db.collection('users').doc(owner).collection(collection);
  void _checkUid(String owner) {
    if (auth.currentUser?.uid != owner) {
      throw const AiFailure(
        AiErrorKind.authentication,
        'Your account session changed.',
      );
    }
  }

  num _amount(dynamic value) {
    if (value is! num || !value.isFinite || value < 0) {
      throw const AiFailure(
        AiErrorKind.privacy,
        'Financial values are unavailable for this selection.',
      );
    }
    return value;
  }

  String _revision(Map<String, dynamic> data, List<String> fields) =>
      jsonEncode({
        for (final key in fields)
          key: data[key] is Timestamp
              ? (data[key] as Timestamp).microsecondsSinceEpoch
              : data[key],
      });
  static const _goalFields = [
    'name',
    'savedAmount',
    'targetAmount',
    'currencyCode',
    'deadline',
    'archived',
  ];

  AiLocalFacts _goal(String owner, String id, Map<String, dynamic> data) =>
      aiGoalFacts(
        key: 'goal/$id',
        uid: owner,
        title: data['name'] as String? ?? 'Savings goal',
        saved: _amount(data['savedAmount']),
        target: _amount(data['targetAmount']),
        currency: goalCurrency(data),
        revision: _revision(data, _goalFields),
        deadline: data['deadline'] is Timestamp
            ? (data['deadline'] as Timestamp).toDate()
            : null,
      );

  @override
  Future<List<AiLocalFacts>> goals() async {
    final owner = uid;
    final personal = await _personal(
      owner,
      'goals',
    ).where('archived', isEqualTo: false).limit(101).get(server);
    _checkUid(owner);
    if (personal.docs.length > 100) {
      throw const AiFailure(
        AiErrorKind.input,
        'The AI goal selector supports up to 100 active goals.',
      );
    }
    final shared = await db
        .collection('sharedGoals')
        .where('memberIds', arrayContains: owner)
        .limit(101)
        .get(server);
    _checkUid(owner);
    if (shared.docs.length > 100) {
      throw const AiFailure(
        AiErrorKind.input,
        'The AI goal selector supports up to 100 shared goals.',
      );
    }
    final facts = [
      for (final document in personal.docs)
        _goal(owner, document.id, document.data()),
    ];
    for (final document in shared.docs) {
      final goal = SharedSavingsGoal(document.id, document.data());
      if (goal.archived) continue;
      // Shared details are displayed locally only, never eligible for consent.
      facts.add(
        aiGoalFacts(
          key: 'shared/${goal.id}',
          uid: owner,
          title: '${goal.name} · Shared',
          saved: goal.balance,
          target: goal.target,
          currency: goal.currencyCode,
          revision: _revision(goal.data, [
            'currentAmount',
            'targetAmount',
            'deadline',
            'status',
            'memberIds',
          ]),
          deadline: goal.data['deadline'] is Timestamp ? goal.deadline : null,
          shared: true,
        ),
      );
    }
    return facts;
  }

  Future<AiLocalFacts> _tasks(DateTime date, {required bool week}) async {
    final owner = uid;
    final start = SmartTaskRecommendationService.dateKey(date);
    final end = SmartTaskRecommendationService.dateKey(
      date.add(const Duration(days: 6)),
    );
    final collection = _personal(owner, 'tasks');
    final query = week
        ? collection
              .where('dateKey', isGreaterThanOrEqualTo: start)
              .where('dateKey', isLessThanOrEqualTo: end)
        : collection.where('dateKey', isEqualTo: start);
    final snapshot = await query.limit(501).get(server);
    _checkUid(owner);
    if (snapshot.docs.length > 500) {
      throw const AiFailure(
        AiErrorKind.input,
        'This period has too many tasks for a complete AI summary.',
      );
    }
    final docs = snapshot.docs.toList()..sort((a, b) => a.id.compareTo(b.id));
    return aiPlannerFacts(
      key: '${week ? 'report' : 'planner'}/$start',
      uid: owner,
      title: week ? 'Weekly report · $start to $end' : 'Your day · $start',
      tasks: docs.map((d) => PlannerTask.fromData(d.id, d.data())).toList(),
      revision: jsonEncode([
        for (final d in docs)
          [
            d.id,
            _revision(d.data(), ['dateKey', 'completed', 'priority', 'time']),
          ],
      ]),
      report: week,
    );
  }

  @override
  Future<AiLocalFacts> planner(DateTime date) => _tasks(date, week: false);

  @override
  Future<AiLocalFacts> report(DateTime weekStart) async {
    final facts = await _tasks(weekStart, week: true);
    final snapshot = await _personal(
      facts.ownerUid,
      'goals',
    ).limit(501).get(server);
    _checkUid(facts.ownerUid);
    if (snapshot.docs.length > 500) {
      throw const AiFailure(
        AiErrorKind.input,
        'There are too many goals for a complete report summary.',
      );
    }
    final docs = snapshot.docs.toList()..sort((a, b) => a.id.compareTo(b.id));
    final balances = [
      for (final d in docs)
        (
          _amount(d.data()['savedAmount']),
          _amount(d.data()['targetAmount']),
          goalCurrency(d.data()),
        ),
    ];
    return AiLocalFacts(
      title: facts.title,
      ownerUid: facts.ownerUid,
      subjectKey: facts.subjectKey,
      revision: jsonEncode([
        facts.revision,
        for (final d in docs) [d.id, _revision(d.data(), _goalFields)],
      ]),
      values: {...facts.values, ...aiReportBalances(balances)},
      summary: facts.summary,
    );
  }

  @override
  Future<bool> isCurrent(AiLocalFacts facts) async {
    final owner = uid;
    if (facts.ownerUid != owner || facts.shared) return false;
    final parts = facts.subjectKey.split('/');
    if (parts.length != 2) return false;
    switch (parts.first) {
      case 'goal':
        final doc = await _personal(owner, 'goals').doc(parts.last).get(server);
        _checkUid(owner);
        if (!doc.exists || doc.data()?['archived'] != false) return false;
        return _goal(owner, doc.id, doc.data()!).revision == facts.revision;
      case 'planner':
        final current = await planner(DateTime.parse(parts.last));
        return current.revision == facts.revision;
      case 'report':
        final current = await report(DateTime.parse(parts.last));
        return current.revision == facts.revision;
      default:
        return false;
    }
  }

  @override
  Stream<void> invalidations(AiLocalFacts facts) async* {
    final owner = uid;
    if (facts.ownerUid != owner) {
      yield null;
      return;
    }
    final parts = facts.subjectKey.split('/');
    if (parts.length != 2) {
      yield null;
      return;
    }
    if (parts.first == 'goal' || parts.first == 'shared') {
      final reference = parts.first == 'goal'
          ? _personal(owner, 'goals').doc(parts.last)
          : db.collection('sharedGoals').doc(parts.last);
      await for (final doc in reference.snapshots()) {
        if (auth.currentUser?.uid != owner || !doc.exists) {
          yield null;
          return;
        }
        if (doc.metadata.isFromCache) continue;
        final data = doc.data()!;
        final revision = _revision(
          data,
          parts.first == 'goal'
              ? _goalFields
              : [
                  'currentAmount',
                  'targetAmount',
                  'deadline',
                  'status',
                  'memberIds',
                ],
        );
        if (revision != facts.revision) {
          yield null;
          return;
        }
      }
    } else {
      final date = DateTime.parse(parts.last);
      final week = parts.first == 'report';
      final query = week
          ? _personal(owner, 'tasks')
                .where('dateKey', isGreaterThanOrEqualTo: parts.last)
                .where(
                  'dateKey',
                  isLessThanOrEqualTo: SmartTaskRecommendationService.dateKey(
                    date.add(const Duration(days: 6)),
                  ),
                )
          : _personal(owner, 'tasks').where('dateKey', isEqualTo: parts.last);
      await for (final snapshot in query.limit(501).snapshots()) {
        if (snapshot.metadata.isFromCache) continue;
        if (!await isCurrent(facts)) {
          yield null;
          return;
        }
      }
    }
  }
}
