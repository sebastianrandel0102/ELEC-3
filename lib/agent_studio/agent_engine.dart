import 'dart:async';

import 'package:flutter/foundation.dart';

import 'agent_backend.dart';
import 'agent_domain.dart';
import 'agent_store.dart';
import 'agent_planner.dart';
import 'intelligence/agent_interpretation.dart';
import 'intelligence/agent_language.dart';

/// Only this application service can mint approvals. They are process-local,
/// single use, and bound to an exact snapshot, identity, permission revision,
/// and expiry. Model output and history cannot deserialize an approval.
class AgentApproval {
  AgentApproval._(
    this.snapshot,
    this.uid,
    this.epoch,
    this.createdAt,
    this.issuer,
  );
  final String snapshot, uid;
  final int epoch;
  final DateTime createdAt;
  final Object issuer;
  bool _used = false;
}

class AgentEngine extends ChangeNotifier {
  AgentEngine({
    required this.uid,
    required this.currentUid,
    required this.backend,
    required this.store,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final String uid;
  final String? Function() currentUid;
  final AgentBackend backend;
  final AgentStore store;
  final DateTime Function() clock;
  final Object _issuer = Object();
  AgentSettings settings = AgentSettings();
  AgentMission? mission;
  final List<AgentMission> history = [];
  final List<AgentMessage> messages = [];
  AgentInterpretation? interpretation;
  String? _interpretedSnapshot;
  AgentInterpretation? get activeInterpretation =>
      _interpretedSnapshot == mission?.snapshot ? interpretation : null;
  AgentLanguage sessionLanguage = AgentLanguage.automatic;
  bool loading = true, busy = false, _disposed = false, _cancel = false;
  int _epoch = 0;
  String? _reviewedSnapshot;
  int? _reviewedEpoch;
  Future<void> _localWrites = Future<void>.value();
  Future<void> _persist(Future<void> Function() action) {
    final next = _localWrites.catchError((Object _) {}).then((_) => action());
    _localWrites = next;
    return next;
  }

  String? error;
  bool get active => !_disposed && currentUid() == uid;
  bool get editable =>
      !busy &&
      mission?.status != MissionStatus.canceled &&
      mission?.status != MissionStatus.completed;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _session() {
    if (!active) {
      throw const AgentFailure('Your account changed. Reopen Agent Studio.');
    }
  }

  Future<void> initialize() async {
    try {
      final loaded = await store.settings(uid);
      _session();
      settings = loaded;
      if (settings.history) {
        final saved = await store.history(uid);
        _session();
        history.addAll(saved);
      }
    } catch (_) {
      if (active) error = 'Local Agent preferences could not be loaded.';
    } finally {
      loading = false;
      _notify();
    }
  }

  void say(String text, {bool user = false, bool voice = false}) {
    _session();
    messages.add(AgentMessage(text, user: user, voice: voice));
    if (messages.length > 100) messages.removeRange(0, messages.length - 100);
    _notify();
  }

  Future<void> updateSettings(AgentSettings value) async {
    _session();
    _epoch++;
    settings = value;
    if (busy) _cancel = true;
    _notify();
    if (!value.history) history.clear();
    await _persist(() async {
      await store.saveSettings(uid, value);
      if (!value.history) await store.clear(uid);
    });
    _notify();
  }

  void draft(
    List<AgentAction> actions, {
    String title = 'Your next steps',
    bool allowEmpty = false,
    bool planOnly = false,
    List<String> languageIssues = const [],
  }) {
    _session();
    if (busy) throw const AgentFailure('Wait for the current operation.');
    if (actions.isEmpty && !allowEmpty || actions.length > AgentLimits.steps) {
      throw const AgentFailure('Use a smaller mission.');
    }
    _epoch++;
    error = null;
    final steps = <AgentStep>[];
    for (var i = 0; i < actions.length; i++) {
      final a = actions[i];
      steps.add(
        AgentStep(
          id: 'step_${i + 1}',
          action: a,
          dependsOn: a is ReminderDraft && a.targetStep.isNotEmpty
              ? [a.targetStep]
              : [],
        ),
      );
    }
    mission = AgentMission(
      id: agentId(),
      uid: uid,
      title: title,
      createdAt: clock(),
      steps: steps,
      planOnly: planOnly,
      languageIssues: List.unmodifiable(languageIssues),
    );
    _revalidate();
    _notify();
  }

  void _revalidate() {
    final m = mission!;
    mission = m.copyWith(
      status: m.validate(clock()).isEmpty
          ? MissionStatus.readyForReview
          : MissionStatus.needsClarification,
    );
  }

  /// Interpretations can only change proposals. They cannot mint approvals.
  Future<void> applyPlan(LocalAgentPlan plan) async {
    _session();
    if (busy) throw const AgentFailure('Wait for the current operation.');
    _epoch++;
    final understanding = plan.interpretation;
    interpretation = understanding;
    if (understanding?.language != null &&
        understanding!.language != AgentLanguage.automatic) {
      sessionLanguage = understanding.language;
    }
    final issues = understanding?.uncertain.isNotEmpty == true
        ? understanding!.questions.toSet().toList()
        : <String>[];
    if (plan.cancel) {
      cancel();
    } else if (plan.removeSteps.isNotEmpty) {
      for (final id in plan.removeSteps) {
        edit(id, remove: true);
      }
    } else if (plan.moveStep != null) {
      edit(plan.moveStep!, move: plan.moveBy);
    } else if (plan.replacement != null) {
      final previous = mission!.steps.firstWhere(
        (s) => s.id == plan.replaceStep,
      );
      edit(plan.replaceStep!, action: plan.replacement);
      final remaining = {...previous.uncertainFields};
      final fields = plan.replacement!.toJson();
      final oldFields = previous.action.toJson();
      remaining.removeWhere(
        (key, _) =>
            fields[key] != oldFields[key] &&
            fields[key] != null &&
            fields[key] != '',
      );
      remaining.addAll(_uncertainSlots(plan.replacement!, understanding));
      mission = mission!.copyWith(
        planOnly: mission!.planOnly || understanding?.draftOnly == true,
        steps: [
          for (final step in mission!.steps)
            step.id == previous.id
                ? step.copyWith(uncertainFields: remaining)
                : step,
        ],
        languageIssues:
            understanding?.uncertain.contains(Uncertainty.target) == true
            ? issues
            : const [],
      );
      _revalidate();
    } else if (plan.actions.isNotEmpty) {
      await save();
      _session();
      draft(
        plan.actions,
        title: plan.missionTitle ?? 'Your next steps',
        planOnly: understanding?.draftOnly == true,
        languageIssues:
            understanding?.uncertain.contains(Uncertainty.target) == true
            ? issues
            : const [],
      );
      mission = mission!.copyWith(
        steps: [
          for (final step in mission!.steps)
            step.copyWith(
              uncertainFields: _uncertainSlots(step.action, understanding),
            ),
        ],
      );
      _revalidate();
    } else if (plan.missionTitle != null) {
      if (mission == null ||
          !editable ||
          understanding?.intent == AgentIntent.missionPlanning) {
        draft(
          const [],
          title: plan.missionTitle!,
          allowEmpty: true,
          planOnly: understanding?.draftOnly == true,
        );
      } else {
        renameMission(plan.missionTitle!);
      }
    } else if (mission != null &&
        editable &&
        (understanding?.draftOnly == true ||
            understanding?.negated.isNotEmpty == true ||
            issues.isNotEmpty)) {
      mission = mission!.copyWith(
        version: mission!.version + 1,
        planOnly:
            mission!.planOnly ||
            understanding?.draftOnly == true ||
            understanding?.negated.isNotEmpty == true,
        languageIssues: issues.isEmpty ? mission!.languageIssues : issues,
      );
      _revalidate();
    }
    _interpretedSnapshot = mission?.snapshot;
    _notify();
  }

  void renameMission(String title) {
    _session();
    if (!editable ||
        mission == null ||
        title.trim().isEmpty ||
        title.trim().length > 100) {
      throw const AgentFailure('Use a mission title up to 100 characters.');
    }
    _epoch++;
    mission = mission!.copyWith(
      title: title.trim(),
      version: mission!.version + 1,
    );
    _revalidate();
    _notify();
  }

  Map<String, String> _uncertainSlots(
    AgentAction action,
    AgentInterpretation? interpretation,
  ) {
    if (interpretation == null) return const {};
    final fields = action.toJson();
    final strings = AgentStrings(settings.interfaceLanguage);
    final result = <String, String>{};
    for (final issue in interpretation.uncertain) {
      final key = switch (issue) {
        Uncertainty.title => action is GoalDraft ? 'name' : 'title',
        Uncertainty.amount =>
          action is ScenarioDraft
              ? 'target'
              : action is AllocationDraft
              ? 'budget'
              : 'amount',
        Uncertainty.date =>
          action is GoalDraft || action is ScenarioDraft ? 'deadline' : 'day',
        Uncertainty.recurrence => 'frequency',
        _ => issue.name,
      };
      if (fields.containsKey(key)) {
        result[key] = switch (issue) {
          Uncertainty.amount => strings.amount,
          Uncertainty.currency => strings.currency,
          Uncertainty.date => strings.date,
          Uncertainty.time => strings.time,
          Uncertainty.title => strings.choose(
            'Review the title before approval.',
            'Suriin ang pangalan bago aprubahan.',
          ),
          _ => strings.choose(
            'Review the schedule for this step.',
            'Suriin ang iskedyul ng hakbang na ito.',
          ),
        };
      }
    }
    return result;
  }

  /// Dedicated on-screen choice; enabling review still does not approve anything.
  void enableDraftReview() {
    _session();
    if (!editable || mission == null) return;
    _epoch++;
    mission = mission!.copyWith(planOnly: false, version: mission!.version + 1);
    _revalidate();
    _notify();
  }

  void edit(
    String id, {
    AgentAction? action,
    bool? selected,
    bool remove = false,
    int? move,
  }) {
    _session();
    if (!editable) {
      throw const AgentFailure(
        'This mission cannot be edited while running or after completion.',
      );
    }
    final m = mission!;
    final step = m.steps.firstWhere((s) => s.id == id);
    if (step.attempts > 0 || step.done) {
      throw const AgentFailure(
        'A submitted step is locked. Retry it to reconcile its result.',
      );
    }
    final steps = [...m.steps];
    final index = steps.indexOf(step);
    if (remove) {
      steps.removeAt(index);
    } else {
      steps[index] = step.copyWith(
        action: action,
        dependsOn: action == null
            ? null
            : action is ReminderDraft && action.targetStep.isNotEmpty
            ? [action.targetStep]
            : [],
        selected: selected,
        status: StepStatus.waiting,
        result: '',
        uncertainFields: action == null
            ? null
            : {
                for (final entry in step.uncertainFields.entries)
                  if (action.toJson()[entry.key] == null ||
                      action.toJson()[entry.key] == '')
                    entry.key: entry.value,
              },
      );
    }
    if (move != null && !remove) {
      final destination = (index + move).clamp(0, steps.length - 1);
      steps.insert(destination, steps.removeAt(index));
    }
    _epoch++;
    mission = m.copyWith(
      steps: steps,
      version: m.version + 1,
      languageIssues: action == null ? m.languageIssues : const [],
    );
    _revalidate();
    _notify();
  }

  void add(AgentAction action) {
    _session();
    if (!editable || mission!.steps.length >= AgentLimits.steps) {
      throw const AgentFailure('Cannot add another step.');
    }
    final m = mission!;
    mission = m.copyWith(
      version: m.version + 1,
      steps: [
        ...m.steps,
        AgentStep(
          id: 'step_${agentId().substring(0, 8)}',
          action: action,
          dependsOn: action is ReminderDraft && action.targetStep.isNotEmpty
              ? [action.targetStep]
              : [],
        ),
      ],
    );
    _epoch++;
    _revalidate();
    _notify();
  }

  void _permissionCheck(AgentMission m, {bool checkAttempts = true}) {
    if (!settings.execute &&
        m.pending.any(
          (s) => s.action.permission != null && s.action is! AllocationDraft,
        )) {
      throw const AgentFailure(
        'Enable Execute Approved Actions in Agent settings.',
      );
    }
    for (final s in m.pending) {
      if (s.action.permission != null &&
          !settings.permissions.contains(s.action.permission)) {
        throw AgentFailure(
          'Enable the permission for ${s.action.label} in Agent settings.',
        );
      }
      if (checkAttempts && s.attempts >= AgentLimits.attempts) {
        throw const AgentFailure(
          'Retry limit reached. Inspect the existing records before creating another mission.',
        );
      }
    }
  }

  Future<List<String>> review() async {
    _session();
    if (busy || mission == null) {
      throw const AgentFailure('No mission is available for review.');
    }
    final m = mission!;
    final errors = m.validate(clock());
    if (errors.isNotEmpty) return errors;
    _permissionCheck(m);
    final epoch = _epoch;
    busy = true;
    error = null;
    _notify();
    try {
      final issues = await backend.check(m).timeout(AgentLimits.requestTimeout);
      _session();
      if (epoch != _epoch) {
        throw const AgentFailure(
          'The mission or permissions changed. Review again.',
        );
      }
      if (issues.isEmpty) {
        _reviewedSnapshot = m.snapshot;
        _reviewedEpoch = epoch;
      }
      return issues;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Called only by the dedicated confirmation control after review.
  AgentApproval approveReviewedSnapshot(String snapshot) {
    _session();
    final m = mission;
    if (busy ||
        m == null ||
        snapshot != m.snapshot ||
        _reviewedSnapshot != snapshot ||
        _reviewedEpoch != _epoch ||
        m.pending.isEmpty ||
        m.status == MissionStatus.canceled) {
      throw const AgentFailure(
        'This review is stale. Review the mission again.',
      );
    }
    final issues = m.validate(clock());
    if (issues.isNotEmpty) throw AgentFailure(issues.first);
    _permissionCheck(m);
    return AgentApproval._(snapshot, uid, _epoch, clock(), _issuer);
  }

  void _approval(AgentApproval approval) {
    _session();
    if (!identical(approval.issuer, _issuer) ||
        approval.uid != uid ||
        approval.epoch != _epoch ||
        approval.snapshot != mission?.snapshot ||
        clock().isBefore(approval.createdAt) ||
        clock().difference(approval.createdAt) > AgentLimits.approvalLifetime ||
        _cancel) {
      throw const AgentFailure(
        'Approval expired or the mission, account, or permissions changed. Review again.',
      );
    }
    _permissionCheck(mission!, checkAttempts: false);
  }

  Future<void> execute(AgentApproval approval) async {
    if (busy || approval._used) {
      throw const AgentFailure('This approval has already been used.');
    }
    _cancel = false;
    _approval(approval);
    approval._used = true;
    busy = true;
    error = null;
    mission = mission!.copyWith(status: MissionStatus.approved);
    _notify();
    try {
      final issues = await backend
          .check(mission!)
          .timeout(AgentLimits.requestTimeout);
      _approval(approval);
      if (issues.isNotEmpty) throw AgentFailure(issues.join('\n'));
      mission = mission!.copyWith(status: MissionStatus.executing);
      await save();
      final remaining = mission!.pending.map((s) => s.id).toSet();
      while (remaining.isNotEmpty && !_cancel) {
        _approval(approval);
        final ready = mission!.steps
            .where(
              (s) =>
                  remaining.contains(s.id) &&
                  s.dependsOn.every(
                    (id) => mission!.steps.any((p) => p.id == id && p.done),
                  ),
            )
            .firstOrNull;
        if (ready == null) {
          for (final id in remaining) {
            _step(
              id,
              status: StepStatus.blocked,
              result: 'A prerequisite did not complete. Review and retry.',
            );
          }
          break;
        }
        remaining.remove(ready.id);
        _step(
          ready.id,
          status: StepStatus.executing,
          attempts: ready.attempts + 1,
        );
        await save(); // Recovery state is durable before a write when enabled.
        _approval(approval);
        try {
          // Repeat server checks immediately before each mutation; recheck the
          // local approval after the asynchronous authorization read.
          final currentIssues = await backend
              .check(mission!)
              .timeout(AgentLimits.requestTimeout);
          _approval(approval);
          if (currentIssues.isNotEmpty) {
            throw AgentFailure(currentIssues.join('\n'));
          }
          final result = await backend.perform(mission!, ready);
          if (active) {
            _step(
              ready.id,
              status: StepStatus.completed,
              result: result.message,
              recordId: result.recordId,
            );
          }
        } catch (e) {
          if (active) {
            _step(
              ready.id,
              status: StepStatus.failed,
              result: e is AgentFailure ? e.message : 'Could not verify this operation. Review and retry to reconcile its stable record ID.',
            );
          }
        }
        if (!active) break;
        await save();
      }
    } catch (e) {
      if (active) error = e is AgentFailure ? e.message : 'Could not verify access or save recovery state. Review the mission and retry.';
    } finally {
      if (active && mission != null) {
        mission = mission!.copyWith(
          steps: [
            for (final s in mission!.steps)
              s.status == StepStatus.executing
                  ? s.copyWith(
                      status: StepStatus.failed,
                      result: 'The operation was interrupted. Review and retry to reconcile its record.',
                    )
                  : _cancel &&
                        s.selected &&
                        !s.done &&
                        s.status == StepStatus.waiting
                  ? s.copyWith(
                      status: StepStatus.canceled,
                      result: 'Not started. Remaining steps were canceled.',
                    )
                  : s,
          ],
        );
        final selected = mission!.steps.where((s) => s.selected).toList();
        final completed = selected.where((s) => s.done).length;
        mission = mission!.copyWith(
          status: completed == selected.length
              ? MissionStatus.completed
              : completed > 0
              ? MissionStatus.partiallyCompleted
              : _cancel
              ? MissionStatus.canceled
              : MissionStatus.failed,
        );
        try {
          await save();
        } catch (_) {
          error = 'Results could not be saved locally. Inspect the records before leaving.';
        }
      }
      busy = false;
      _notify();
    }
  }

  void _step(
    String id, {
    StepStatus? status,
    String? result,
    String? recordId,
    int? attempts,
  }) {
    mission = mission!.copyWith(
      steps: [
        for (final s in mission!.steps)
          s.id == id
              ? s.copyWith(
                  status: status,
                  result: result,
                  recordId: recordId,
                  attempts: attempts,
                )
              : s,
      ],
    );
    _notify();
  }

  Future<void> save() async {
    _session();
    final m = mission;
    if (m == null || !settings.history) return;
    history.removeWhere((h) => h.id == m.id);
    history.insert(0, m);
    if (history.length > 50) history.removeRange(50, history.length);
    final snapshot = List<AgentMission>.of(history);
    await _persist(() => store.saveHistory(uid, snapshot));
  }

  void open(AgentMission value) {
    _session();
    if (busy || value.uid != uid) {
      throw const AgentFailure('Cannot open this mission.');
    }
    _epoch++;
    mission = value;
    interpretation = null;
    _interpretedSnapshot = null;
    error = null;
    _notify();
  }

  void cancel() {
    _cancel = true;
    _epoch++;
    if (!busy && mission != null) {
      mission = mission!.copyWith(status: MissionStatus.canceled);
    }
    _notify();
  }

  Future<void> clearHistory() async {
    _session();
    if (busy) throw const AgentFailure('Wait for execution to finish.');
    await _persist(() => store.clear(uid));
    history.clear();
    _notify();
  }

  void clearConversation() {
    if (busy) return;
    _epoch++;
    messages.clear();
    interpretation = null;
    sessionLanguage = AgentLanguage.automatic;
    mission = null;
    error = null;
    _notify();
  }

  void invalidateIdentity() {
    _cancel = true;
    _epoch++;
    mission = null;
    history.clear();
    messages.clear();
    interpretation = null;
    sessionLanguage = AgentLanguage.automatic;
    settings = AgentSettings();
    error = null;
    _notify();
  }

  @override
  void dispose() {
    _cancel = true;
    _epoch++;
    _disposed = true;
    interpretation = null;
    messages.clear();
    super.dispose();
  }
}
