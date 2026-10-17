import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_record_repository.dart';
import '../currency_money.dart';
import '../reminder_coordinator.dart';
import '../reminder_models.dart';
import '../reminder_repository.dart';
import '../smart_task_recommendation_service.dart';
import 'agent_domain.dart';
import 'autopilot/execution_ledger.dart';

abstract interface class AgentBackend {
  Future<List<AgentRecord>> goals();
  Future<List<String>> check(AgentMission mission);
  Future<AgentExecutionResult> perform(AgentMission mission, AgentStep step);
}

/// Production adapters repeat the live authorization guard immediately before
/// each transaction write, including SDK transaction retries after async reads.
abstract interface class GuardedAgentBackend implements AgentBackend {
  Future<List<String>> checkAutomatic(AgentMission mission);
  Future<AgentExecutionResult> performGuarded(
    AgentMission mission,
    AgentStep step, {
    required void Function() beforeWrite,
  });
}

abstract interface class AgentTaskUndoBackend {
  Future<void> undoCreatedTask(
    String recordId,
    TaskDraft action, {
    required void Function() beforeWrite,
  });
}

abstract interface class AgentOperationReconciler {
  Future<AgentExecutionResult?> reconcileAutomaticRecord(
    AgentExecutionRecord record,
  );
}

class FirestoreAgentBackend
    implements
        GuardedAgentBackend,
        AgentTaskUndoBackend,
        AgentOperationReconciler {
  FirestoreAgentBackend({
    required this.uid,
    required this.reminders,
    required this.openContribution,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : db = db ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;
  final String uid;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final ReminderCoordinator? reminders;
  final Future<void> Function(String goalId, String amount) openContribution;
  @override
  Future<AgentExecutionResult?> reconcileAutomaticRecord(
    AgentExecutionRecord record,
  ) async {
    _session();
    if (record.uid != uid ||
        !agentRecordId(record.missionId) ||
        !agentRecordId(record.stepId)) {
      throw const AgentFailure(
        'This operation belongs to another session or account.',
      );
    }
    final action = record.action;
    if (action is GoalDraft || action is TaskDraft) {
      final id = 'agent_${record.missionId}_${record.stepId}';
      final doc = await _records(action is GoalDraft ? 'goals' : 'tasks')
          .doc(id)
          .get(const GetOptions(source: Source.server));
      _session();
      if (!doc.exists) return null;
      if (doc.data()?['agentOperation'] != jsonEncode(action.toJson())) {
        throw const AgentFailure(
          'This record differs from the operation. Inspect it in SaveTrack.',
        );
      }
      return AgentExecutionResult(
        'Creation confirmed by the server. Later edits are preserved.',
        recordId: id,
      );
    }
    if (action is ReminderDraft) {
      final mission = AgentMission(
        id: record.missionId,
        uid: uid,
        title: 'Reconciliation',
        createdAt: record.createdAt,
        steps: [
          if (action.targetStep.isNotEmpty)
            AgentStep(id: action.targetStep, action: const GoalDraft()),
        ],
      );
      final config = _config(mission, action);
      final doc = await _records('reminders')
          .doc(config.key)
          .get(const GetOptions(source: Source.server));
      _session();
      if (!doc.exists) return null;
      if (!_sameReminder(doc.data()!, config)) {
        throw const AgentFailure(
          'This reminder changed. Inspect it in Smart Reminders.',
        );
      }
      return AgentExecutionResult(
        'Reminder preference confirmed by the server. Check Smart Reminders for current phone scheduling status.',
        recordId: config.targetId,
      );
    }
    throw const AgentFailure(
      'This operation cannot be reconciled as a database creation.',
    );
  }

  @override
  Future<void> undoCreatedTask(
    String recordId,
    TaskDraft action, {
    required void Function() beforeWrite,
  }) => AppRecordRepository(db: db, auth: auth).undoAgentTask(
    uid: uid,
    id: recordId,
    operation: jsonEncode(action.toJson()),
    beforeWrite: beforeWrite,
    expected: {
      'title': action.title.trim(),
      'dateKey': agentDay(action.day!),
      'time': action.time,
      'priority': action.priority,
      'completed': false,
    },
  );
  @override
  Future<List<String>> checkAutomatic(AgentMission mission) async {
    final issues = await check(mission);
    for (final step in mission.pending) {
      if (step.action case final ReminderDraft action) {
        final coordinator = reminders;
        if (coordinator == null) {
          continue; // check() reports the missing service.
        }
        final capability = await coordinator.scheduler.capability(
          ReminderTargetType.values.byName(action.targetKind),
        );
        _session();
        if (!capability.supported || !capability.allowed) {
          issues.add(
            'Phone notifications are unavailable or disabled. Enable them in Smart Reminders before automatic scheduling.',
          );
        }
      }
    }
    return issues;
  }

  void _session() {
    if (auth.currentUser?.uid != uid) {
      throw const AgentFailure('Your account changed. Sign in again.');
    }
  }

  CollectionReference<Map<String, dynamic>> _records(String name) =>
      db.collection('users').doc(uid).collection(name);
  String _id(AgentMission mission, AgentStep step) =>
      'agent_${mission.id}_${step.id}';
  String _target(AgentMission mission, ReminderDraft action) {
    if (action.targetStep.isEmpty) return action.targetId;
    final step = mission.steps.where((s) => s.id == action.targetStep).first;
    return _id(mission, step);
  }

  @override
  Future<List<AgentRecord>> goals() async {
    _session();
    final snapshot = await _records('goals')
        .where('archived', isEqualTo: false)
        .limit(101)
        .get(const GetOptions(source: Source.server));
    _session();
    if (snapshot.docs.length > 100) {
      throw const AgentFailure(
        'There are more than 100 active goals. Use the Goals screen to narrow your selection.',
      );
    }
    return snapshot.docs.map((doc) {
      final d = doc.data();
      return AgentRecord(
        doc.id,
        d['title'] as String? ?? '',
        currency: goalCurrency(d),
        target: (d['targetAmount'] ?? 0).toString(),
        saved: (d['savedAmount'] ?? 0).toString(),
        deadline: (d['deadline'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  /// Server reads fail closed. There is no cached ownership assumption.
  @override
  Future<List<String>> check(AgentMission mission) async {
    _session();
    if (mission.uid != uid) {
      throw const AgentFailure('This mission belongs to another account.');
    }
    final issues = <String>[];
    for (final step in mission.pending) {
      final action = step.action;
      if (action is GoalDraft || action is TaskDraft) {
        final collection = action is GoalDraft ? 'goals' : 'tasks';
        final own = await _records(collection)
            .doc(_id(mission, step))
            .get(const GetOptions(source: Source.server));
        _session();
        if (own.exists) {
          if (own.data()?['agentOperation'] != jsonEncode(action.toJson())) {
            issues.add(
              'A previously submitted step has different values. Open its existing record.',
            );
          }
          continue;
        }
        Query<Map<String, dynamic>> query = _records(collection);
        if (action is GoalDraft) {
          query = query.where('archived', isEqualTo: false);
        }
        if (action is TaskDraft) {
          query = query.where('dateKey', isEqualTo: agentDay(action.day!));
        }
        final found = await query
            .limit(200)
            .get(const GetOptions(source: Source.server));
        _session();
        if (found.docs.length >= 200) {
          issues.add(
            'Too many records to safely check this date. Use the existing form.',
          );
        }
        for (final doc in found.docs) {
          final data = doc.data();
          if (action is GoalDraft &&
              data['archived'] != true &&
              data['title'].toString().trim().toLowerCase() ==
                  action.name.trim().toLowerCase()) {
            issues.add(
              'A goal named “${action.name}” already exists. Rename this draft or use that goal.',
            );
          }
          if (action is TaskDraft) {
            if (data['title'].toString().trim().toLowerCase() ==
                action.title.trim().toLowerCase()) {
              issues.add(
                '“${action.title}” is already on this date. Edit or remove the duplicate.',
              );
            }
            final existingSchedule =
                SmartTaskRecommendationService.parseSchedule(
                  data['time']?.toString() ?? '',
                  action.day!,
                );
            final candidate = action.time.isEmpty
                ? null
                : DateTime(
                    action.day!.year,
                    action.day!.month,
                    action.day!.day,
                    int.parse(action.time.split(':')[0]),
                    int.parse(action.time.split(':')[1]),
                  );
            if (candidate != null &&
                existingSchedule.start != null &&
                (candidate == existingSchedule.start ||
                    (existingSchedule.end != null &&
                        candidate.isAfter(existingSchedule.start!) &&
                        candidate.isBefore(existingSchedule.end!))) &&
                data['completed'] != true) {
              issues.add(
                'A task already starts at ${action.time} on ${agentDay(action.day!)}. Change the proposed time.',
              );
            }
          }
        }
      }
      if (action is ReminderDraft && action.targetStep.isEmpty) {
        final repository = reminders?.repository;
        if (repository == null) {
          issues.add('Reminder service unavailable.');
          continue;
        }
        final type = ReminderTargetType.values.byName(action.targetKind);
        final target = await repository.target(uid, type, action.targetId);
        _session();
        if (target == null || !target.available || target.completed) {
          issues.add(
            'The reminder target is missing, completed, or unavailable.',
          );
        }
        final existing = await db
            .collection('users')
            .doc(uid)
            .collection('reminders')
            .doc('${action.targetKind}_${action.targetId}')
            .get(const GetOptions(source: Source.server));
        _session();
        if (existing.exists &&
            !_sameReminder(existing.data()!, _config(mission, action))) {
          issues.add(
            'This item already has a different reminder. Edit it in Smart Reminders.',
          );
        }
      }
      if (action is ContributionDraft) {
        final goal = await _records('goals')
            .doc(action.goalId)
            .get(const GetOptions(source: Source.server));
        _session();
        if (!goal.exists ||
            goal.data()?['archived'] == true ||
            goalCurrency(goal.data()!) != action.currency) {
          issues.add('Select an available personal goal in the same currency.');
        }
      }
    }
    return issues.toSet().toList();
  }

  ReminderConfiguration _config(AgentMission mission, ReminderDraft action) {
    final parts = action.time.split(':').map(int.parse).toList();
    return ReminderConfiguration(
      uid: uid,
      type: ReminderTargetType.values.byName(action.targetKind),
      targetId: _target(mission, action),
      enabled: true,
      frequency: ReminderFrequency.values.byName(action.frequency),
      weekday: action.weekday ?? 1,
      hour: parts[0],
      minute: parts[1],
      instant: action.day == null
          ? null
          : DateTime(
              action.day!.year,
              action.day!.month,
              action.day!.day,
              parts[0],
              parts[1],
            ),
    );
  }

  bool _sameReminder(
    Map<String, dynamic> existing,
    ReminderConfiguration config,
  ) {
    try {
      return jsonEncode(ReminderConfiguration.fromMap(existing).toMap()) ==
          jsonEncode(config.toMap());
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AgentExecutionResult> perform(AgentMission mission, AgentStep step) =>
      performGuarded(mission, step, beforeWrite: _session);

  @override
  Future<AgentExecutionResult> performGuarded(
    AgentMission mission,
    AgentStep step, {
    required void Function() beforeWrite,
  }) async {
    _session();
    if (mission.uid != uid) {
      throw const AgentFailure('This mission belongs to another account.');
    }
    final action = step.action;
    final errors = action.validate(DateTime.now());
    if (errors.isNotEmpty) throw AgentFailure(errors.first);
    final id = _id(mission, step);
    final records = AppRecordRepository(db: db, auth: auth);
    final timestamps = {
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (action is GoalDraft) {
      await records.create(
        uid: uid,
        collection: 'goals',
        id: id,
        operation: jsonEncode(action.toJson()),
        beforeWrite: beforeWrite,
        data: {
          ...timestamps,
          'title': action.name.trim(),
          'note': '',
          'targetAmount': parseCurrencyAmount(
            action.amount,
            action.currency,
          )!.toDouble(),
          'savedAmount': 0.0,
          'currencyCode': action.currency,
          'deadline': Timestamp.fromDate(action.deadline!),
          'archived': false,
        },
      );
      return AgentExecutionResult(
        'Goal created. Confirmed by the server.',
        recordId: id,
      );
    }
    if (action is TaskDraft) {
      await records.create(
        uid: uid,
        collection: 'tasks',
        id: id,
        operation: jsonEncode(action.toJson()),
        beforeWrite: beforeWrite,
        data: {
          ...timestamps,
          'title': action.title.trim(),
          'dateKey': agentDay(action.day!),
          'time': action.time,
          'priority': action.priority,
          'completed': false,
        },
      );
      return AgentExecutionResult(
        'Planner task created. Confirmed by the server.',
        recordId: id,
      );
    }
    if (action is ReminderDraft) {
      final coordinator = reminders;
      if (coordinator == null) {
        throw const AgentFailure('Reminder service unavailable.');
      }
      final config = _config(mission, action);
      final target = await coordinator.repository.target(
        uid,
        config.type,
        config.targetId,
      );
      _session();
      if (target == null || !target.available) {
        throw const AgentFailure('Reminder target unavailable.');
      }
      final existing = await _records('reminders')
          .doc(config.key)
          .get(const GetOptions(source: Source.server));
      _session();
      if (existing.exists && !_sameReminder(existing.data()!, config)) {
        throw const AgentFailure(
          'A different reminder now exists. Review it in Smart Reminders.',
        );
      }
      final repository = coordinator.repository;
      if (repository is! FirestoreReminderRepository) {
        throw const AgentFailure(
          'Conditional reminder creation is unavailable. Use Smart Reminders.',
        );
      }
      await coordinator.save(
        config,
        target,
        persist: (config) =>
            repository.createReviewed(config, beforeWrite: beforeWrite),
      );
      _session();
      final status = coordinator.status(config.key);
      return AgentExecutionResult(
        'Reminder preference saved. ${status.message}',
        recordId: config.targetId,
      );
    }
    if (action is ContributionDraft) {
      beforeWrite();
      await openContribution(action.goalId, action.amount);
      _session();
      return AgentExecutionResult(
        'Add Savings review opened. This mission has not recorded or verified a deposit.',
        recordId: action.goalId,
      );
    }
    if (action is ScenarioDraft) {
      return AgentExecutionResult(action.calculate(DateTime.now()));
    }
    if (action is AllocationDraft) {
      final records = (await goals())
          .where(
            (g) =>
                g.currency == action.currency &&
                ExactDecimal.parse(g.target)
                        .compareTo(ExactDecimal.parse(g.saved)) >
                    0,
          )
          .toList();
      if (records.isEmpty) {
        return const AgentExecutionResult(
          'No active, unfinished personal goals in this currency.',
        );
      }
      final digits = CurrencyCatalog.require(action.currency).digits;
      final units = ExactDecimal.parse(action.budget).roundedUnits(digits);
      final base = units ~/ BigInt.from(records.length);
      final remainder = (units % BigInt.from(records.length)).toInt();
      final lines = [
        for (var i = 0; i < records.length; i++)
          '${records[i].title}: ${formatCurrency(ExactDecimal(base + (i < remainder ? BigInt.one : BigInt.zero), BigInt.from(10).pow(digits)), action.currency)}',
      ];
      return AgentExecutionResult(
        'Equal allocation scenario only; nothing was transferred.\n${lines.join('\n')}',
      );
    }
    throw const AgentFailure('Unsupported action.');
  }
}
