import '../agent_domain.dart';
import 'autopilot_settings.dart';

enum AgentActionRisk { readOnly, low, moderate, high, prohibited }

enum AgentAutoDecision {
  executeAutomatically,
  clarify,
  requireReview,
  blocked,
  readOnly,
  draftOnly,
  deferred,
}

enum AgentRequestOrigin {
  userText,
  finalVoice,
  partialVoice,
  history,
  externalData,
}

class AgentPolicyDecision {
  const AgentPolicyDecision(this.decision, this.reasonCode, this.message);
  static const version = 'autopilot-1';
  final AgentAutoDecision decision;
  final String reasonCode, message;
  String get policyVersion => version;
  bool get mayRun =>
      decision == AgentAutoDecision.executeAutomatically ||
      decision == AgentAutoDecision.readOnly;
}

class AgentExecutionContext {
  const AgentExecutionContext({
    required this.uid,
    required this.origin,
    required this.now,
    required this.foreground,
    required this.resolved,
    required this.serverChecked,
    this.sessionActions = 0,
    this.hourActions = 0,
    this.units,
  });
  final String? uid;
  final AgentRequestOrigin origin;
  final DateTime now;
  final bool foreground, resolved, serverChecked;
  final int sessionActions, hourActions;
  final int? units;
}

/// Trusted, exhaustive classification. Provider output never supplies risk.
class AgentActionRiskClassifier {
  const AgentActionRiskClassifier();
  AgentActionRisk classify(AgentAction action) => switch (action) {
    GoalDraft() || TaskDraft() || ReminderDraft() => AgentActionRisk.low,
    ContributionDraft() => AgentActionRisk.high,
    ScenarioDraft() || AllocationDraft() => AgentActionRisk.readOnly,
  };
}

/// Evaluates the whole request before any step, then again before every write.
/// Mixed-risk missions stay together for review; no surprising partial dispatch.
class AgentAutoExecutionPolicyEngine {
  const AgentAutoExecutionPolicyEngine();
  AgentPolicyDecision evaluate({
    required AgentMission mission,
    required AgentSettings settings,
    required AgentExecutionContext context,
  }) {
    AgentPolicyDecision d(AgentAutoDecision kind, String code, String text) =>
        AgentPolicyDecision(kind, code, text);
    final auto = settings.autopilot;
    if (context.uid == null || context.uid != mission.uid) {
      return d(
        AgentAutoDecision.blocked,
        'identity',
        'Your account changed. Reopen Agent Studio.',
      );
    }
    if (![
      AgentRequestOrigin.userText,
      AgentRequestOrigin.finalVoice,
    ].contains(context.origin)) {
      return d(
        AgentAutoDecision.blocked,
        'origin',
        'Only a current, explicit user request may run automatically.',
      );
    }
    if (!context.foreground) {
      return d(
        AgentAutoDecision.deferred,
        'foreground',
        'Return to Agent Studio and send the request again.',
      );
    }
    if (mission.status == MissionStatus.canceled || mission.pending.isEmpty) {
      return d(
        AgentAutoDecision.blocked,
        'inactive',
        'No new actions are available.',
      );
    }
    if (mission.planOnly) {
      return d(
        AgentAutoDecision.draftOnly,
        'draft_only',
        'Kept as a draft as requested.',
      );
    }
    if (!context.resolved || mission.validate(context.now).isNotEmpty) {
      return d(
        AgentAutoDecision.clarify,
        'validation',
        'Complete or clarify the highlighted details before execution.',
      );
    }
    if (context.now.isBefore(mission.createdAt) ||
        context.now.difference(mission.createdAt) >
            AgentLimits.approvalLifetime) {
      return d(
        AgentAutoDecision.requireReview,
        'stale',
        'This request is stale. Review it again.',
      );
    }
    if (!auto.valid) {
      return d(
        AgentAutoDecision.requireReview,
        'settings',
        'Reset invalid Autopilot settings before enabling automatic actions.',
      );
    }
    final actions = mission.pending.map((s) => s.action).toList();
    final readOnly = actions.every(
      (a) =>
          const AgentActionRiskClassifier().classify(a) ==
          AgentActionRisk.readOnly,
    );
    if (readOnly) {
      if (!auto.autoRunSimulations ||
          actions.any((a) => a is AllocationDraft) &&
              !settings.permissions.contains(AgentPermission.privateContext)) {
        return d(
          AgentAutoDecision.requireReview,
          'simulation_permission',
          'Enable local simulations and any required private context access.',
        );
      }
      return d(
        AgentAutoDecision.readOnly,
        'local_calculation',
        'Read-only calculation; balances remain unchanged.',
      );
    }
    if (!auto.enabled) {
      return d(
        AgentAutoDecision.requireReview,
        'mode',
        auto.mode == AgentExecutionMode.paused
            ? 'Autopilot is paused. You can review actions manually.'
            : 'Review and approve this mission to continue.',
      );
    }
    if (!settings.execute) {
      return d(
        AgentAutoDecision.requireReview,
        'execute_permission',
        'Enable action execution in Agent settings.',
      );
    }
    if (context.origin == AgentRequestOrigin.finalVoice &&
        !auto.voiceAutoExecutionEnabled) {
      return d(
        AgentAutoDecision.requireReview,
        'voice_permission',
        'Spoken commands require review unless voice Auto-Execute is enabled.',
      );
    }
    if (mission.steps.where((s) => s.selected).length > 1 &&
        !auto.autoExecuteEligibleMissions) {
      return d(
        AgentAutoDecision.requireReview,
        'mission_permission',
        'Enable eligible missions or review the steps together.',
      );
    }
    for (final step in mission.pending) {
      final a = step.action;
      if (step.attempts > 0 && context.units == null) {
        return d(
          AgentAutoDecision.requireReview,
          'retry',
          'Review unfinished operations to reconcile their stable record IDs.',
        );
      }
      final allowed = switch (a) {
        GoalDraft() => auto.autoCreatePersonalGoals,
        TaskDraft() => auto.autoCreateTasks,
        ReminderDraft() => auto.autoCreateReminders,
        ContributionDraft() =>
          auto.autoPrepareContributions && actions.length == 1,
        ScenarioDraft() || AllocationDraft() => auto.autoRunSimulations,
      };
      if (a is ContributionDraft && !allowed) {
        return d(
          AgentAutoDecision.requireReview,
          'financial_confirmation',
          'Savings contributions keep their dedicated confirmation. Review this mission first.',
        );
      }
      if (!allowed ||
          a.permission != null &&
              !settings.permissions.contains(a.permission)) {
        return d(
          AgentAutoDecision.requireReview,
          'category_permission',
          '${a.label} needs its separate permission or manual review.',
        );
      }
    }
    final total = mission.steps.where((s) => s.selected).length;
    if (total > auto.maxActionsPerMission ||
        mission.steps.where((s) => s.action is GoalDraft).length > 2) {
      return d(
        AgentAutoDecision.requireReview,
        'request_limit',
        'This request exceeds automatic action limits. Review the full batch.',
      );
    }
    final units = context.units ?? actions.length;
    if (context.sessionActions + units > auto.maxActionsPerSession) {
      return d(
        AgentAutoDecision.deferred,
        'session_limit',
        'Session action limit reached. Autopilot is paused; manual review remains available.',
      );
    }
    if (context.hourActions + units > auto.maxActionsPerHour) {
      return d(
        AgentAutoDecision.deferred,
        'hour_limit',
        'Hourly action limit reached. Wait or review manually.',
      );
    }
    if (!context.serverChecked) {
      return d(
        AgentAutoDecision.deferred,
        'server_check',
        'Online validation is required. Draft retained; no automatic offline replay.',
      );
    }
    return d(
      AgentAutoDecision.executeAutomatically,
      'permitted',
      'Validated and authorized by your Autopilot settings.',
    );
  }
}
