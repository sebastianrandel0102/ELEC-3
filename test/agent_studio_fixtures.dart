import 'dart:async';

import 'package:myproject/agent_studio/agent_backend.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_engine.dart';
import 'package:myproject/agent_studio/agent_store.dart';
import 'package:myproject/agent_studio/agent_voice.dart';
import 'package:myproject/agent_studio/autopilot/execution_ledger.dart';

final agentNow = DateTime(2026, 10, 17, 10);
GoalDraft goalDraft({
  String name = 'Laptop',
  String amount = '30000',
  String currency = 'PHP',
}) => GoalDraft(
  name: name,
  amount: amount,
  currency: currency,
  deadline: DateTime(2027, 1, 31),
);
TaskDraft taskDraft({String title = 'Compare prices', String time = ''}) =>
    TaskDraft(title: title, day: DateTime(2027, 1, 2), time: time);

class MemoryAgentStore implements AgentStore {
  AgentSettings preferences = AgentSettings();
  final missions = <String, List<AgentMission>>{};
  bool fail = false;
  @override
  Future<AgentSettings> settings(String uid) async => preferences;
  @override
  Future<void> saveSettings(String uid, AgentSettings value) async {
    preferences = value;
  }

  @override
  Future<List<AgentMission>> history(String uid) async => missions[uid] ?? [];
  @override
  Future<void> saveHistory(String uid, List<AgentMission> values) async {
    if (fail) throw StateError('disk');
    missions[uid] = [...values];
  }

  @override
  Future<void> clear(String uid) async {
    missions.remove(uid);
  }
}

class MemoryExecutionLedger implements AgentExecutionLedger {
  final records = <String, List<AgentExecutionRecord>>{};
  bool fail = false;
  @override
  Future<List<AgentExecutionRecord>> load(String uid) async => [
    ...?records[uid],
  ];
  @override
  Future<void> save(String uid, List<AgentExecutionRecord> values) async {
    if (fail) throw StateError('disk');
    records[uid] = [...values];
  }
}

class FakeAgentBackend implements AgentBackend {
  final calls = <String>[];
  final records = <String, AgentExecutionResult>{};
  List<String> issues = [];
  String? failing;
  Future<void> Function()? onCheck, onPerform;
  @override
  Future<List<AgentRecord>> goals() async => [
    const AgentRecord('goalA', 'Laptop', currency: 'PHP'),
  ];
  @override
  Future<List<String>> check(AgentMission m) async {
    await onCheck?.call();
    return issues;
  }

  @override
  Future<AgentExecutionResult> perform(AgentMission m, AgentStep s) async {
    calls.add(s.id);
    await onPerform?.call();
    if (s.id == failing) throw const AgentFailure('Operation unavailable.');
    return records.putIfAbsent(
      '${m.id}/${s.id}',
      () => AgentExecutionResult(
        '${s.action.label} verified',
        recordId: 'record_${s.id}',
      ),
    );
  }
}

class FakeAgentVoice implements AgentVoiceAdapter {
  final controller = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  final starts = <String>[], spoken = <String>[];
  final systemStarts = <String>[];
  Object? startError;
  bool onDeviceAvailable = false;
  String session = '';
  int cancels = 0, stops = 0;
  bool fail = false;
  @override
  Stream<Map<String, dynamic>> get events => controller.stream;
  @override
  Future<Map<String, dynamic>> capabilities() async => {
    'recognition': true,
    'tts': true,
    'onDevice': onDeviceAvailable,
    'systemRecognition': true,
    'languages': ['en-PH', 'fil-PH'],
    'voices': ['test-voice'],
  };
  void emit(String type, {String? token, String? text}) => controller.add({
    'type': type,
    'session': token ?? session,
    'text': ?text,
  });
  @override
  Future<void> start({
    required String session,
    required String locale,
    required bool onDevice,
  }) async {
    if (startError != null) throw startError!;
    if (fail) throw StateError('permission');
    this.session = session;
    starts.add(session);
  }

  @override
  Future<void> startSystem({
    required String session,
    required String locale,
  }) async {
    this.session = session;
    systemStarts.add(session);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<void> speak({
    required String session,
    required String text,
    required String locale,
    required String voice,
    required double rate,
  }) async {
    this.session = session;
    spoken.add(text);
  }

  @override
  Future<void> stopSpeaking() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

AgentEngine testEngine({
  FakeAgentBackend? backend,
  MemoryAgentStore? store,
  String? Function()? currentUid,
  DateTime Function()? clock,
  AgentExecutionLedger? ledger,
}) => AgentEngine(
  uid: 'owner',
  currentUid: currentUid ?? () => 'owner',
  backend: backend ?? FakeAgentBackend(),
  store: store ?? MemoryAgentStore(),
  ledger: ledger ?? MemoryExecutionLedger(),
  clock: clock ?? () => agentNow,
);
Future<void> enableAgent(AgentEngine engine, {bool history = false}) async {
  await engine.initialize();
  await engine.updateSettings(
    AgentSettings(
      execute: true,
      history: history,
      permissions: AgentPermission.values.toSet(),
    ),
  );
}

Future<AgentApproval> reviewed(AgentEngine engine) async {
  final issues = await engine.review();
  if (issues.isNotEmpty) throw StateError(issues.join('\n'));
  return engine.approveReviewedSnapshot(engine.mission!.snapshot);
}
