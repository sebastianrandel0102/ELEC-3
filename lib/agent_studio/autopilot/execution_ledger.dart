import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../agent_domain.dart';
import 'auto_execution_policy.dart';
import 'autopilot_settings.dart';

enum AgentOperationStatus {
  dispatched,
  completed,
  uncertain,
  canceled,
  reversed,
}

class AgentExecutionRecord {
  const AgentExecutionRecord({
    required this.uid,
    required this.missionId,
    required this.stepId,
    required this.sessionId,
    required this.action,
    required this.createdAt,
    required this.mode,
    this.status = AgentOperationStatus.dispatched,
    this.recordId = '',
    this.message = 'Awaiting server confirmation.',
    this.policyVersion = AgentPolicyDecision.version,
  });
  final String uid,
      missionId,
      stepId,
      sessionId,
      recordId,
      message,
      policyVersion;
  final AgentAction action;
  final DateTime createdAt;
  final AgentExecutionMode mode;
  final AgentOperationStatus status;
  String get id => '$missionId/$stepId';
  String get authorizationKind => action is ContributionDraft
      ? 'autopilotPreparationOnly'
      : 'autopilotPolicy';
  bool get countsTowardsLimit =>
      action is! ScenarioDraft && action is! AllocationDraft;
  bool get undoCandidate =>
      status == AgentOperationStatus.completed &&
      (action is TaskDraft || action is ReminderDraft);
  AgentExecutionRecord finish(
    AgentOperationStatus value,
    String result,
    String target,
  ) => AgentExecutionRecord(
    uid: uid,
    missionId: missionId,
    stepId: stepId,
    sessionId: sessionId,
    action: action,
    createdAt: createdAt,
    mode: mode,
    status: value,
    recordId: target,
    message: result,
    policyVersion: policyVersion,
  );
  Map<String, Object?> toJson() => {
    'uid': uid,
    'missionId': missionId,
    'stepId': stepId,
    'sessionId': sessionId,
    'action': action.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'mode': mode.name,
    'status': status.name,
    'recordId': recordId,
    'message': message,
    'policyVersion': policyVersion,
    'authorizationKind': authorizationKind,
  };
  factory AgentExecutionRecord.fromJson(Map<String, dynamic> m) =>
      AgentExecutionRecord(
        uid: m['uid'] as String,
        missionId: m['missionId'] as String,
        stepId: m['stepId'] as String,
        sessionId: m['sessionId'] as String,
        action: AgentAction.fromJson(
          Map<String, dynamic>.from(m['action'] as Map),
        ),
        createdAt: DateTime.parse(m['createdAt'] as String),
        mode: AgentExecutionMode.values.byName(m['mode'] as String),
        status: AgentOperationStatus.values.byName(m['status'] as String),
        recordId: m['recordId'] as String,
        message: m['message'] as String,
        policyVersion: m['policyVersion'] as String,
      );
}

abstract interface class AgentExecutionLedger {
  Future<List<AgentExecutionRecord>> load(String uid);
  Future<void> save(String uid, List<AgentExecutionRecord> records);
}

/// Mandatory minimal recovery metadata, independent of optional conversation or
/// mission history. Never stores raw commands/audio or replays on restart.
class PreferenceAgentExecutionLedger implements AgentExecutionLedger {
  String _key(String uid) => 'savetrack.autopilot.v1.$uid.ledger';
  @override
  Future<List<AgentExecutionRecord>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null) return [];
    if (raw.length > 2000000) throw const FormatException('Invalid ledger');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (map['schema'] != 1) {
      throw const FormatException('Unknown ledger schema');
    }
    final records = (map['records'] as List)
        .map(
          (m) => AgentExecutionRecord.fromJson(
            Map<String, dynamic>.from(m as Map),
          ),
        )
        .toList();
    if (records.length > 500 ||
        records.any((r) => r.uid != uid) ||
        records.map((r) => r.id).toSet().length != records.length) {
      throw const FormatException('Invalid execution records');
    }
    return records;
  }

  @override
  Future<void> save(String uid, List<AgentExecutionRecord> records) async {
    if (records.any((r) => r.uid != uid)) {
      throw const FormatException('Account mismatch');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _key(uid),
      jsonEncode({
        'schema': 1,
        'records': records.take(500).map((r) => r.toJson()).toList(),
      }),
    )) {
      throw const AgentFailure(
        'Could not save automatic action recovery metadata.',
      );
    }
  }
}
