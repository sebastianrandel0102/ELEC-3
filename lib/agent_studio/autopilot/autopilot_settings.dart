enum AgentExecutionMode { askBeforeEveryAction, smartAuto, customAuto, paused }

enum AgentVoiceReviewMode { alwaysReview, reviewUncertain, autoRunEligible }

extension AgentExecutionModeLabel on AgentExecutionMode {
  String get label => switch (this) {
    AgentExecutionMode.askBeforeEveryAction => 'Ask First',
    AgentExecutionMode.smartAuto => 'Auto-Execute Active',
    AgentExecutionMode.customAuto => 'Custom Auto',
    AgentExecutionMode.paused => 'Paused',
  };
}

/// Device-local and account-scoped. Older or malformed preferences never opt in.
class AgentAutopilotSettings {
  const AgentAutopilotSettings({
    this.mode = AgentExecutionMode.askBeforeEveryAction,
    this.consentVersion = 0,
    this.autoCreatePersonalGoals = false,
    this.autoCreateTasks = false,
    this.autoCreateReminders = false,
    this.autoExecuteEligibleMissions = false,
    this.autoRunSimulations = true,
    this.autoPrepareContributions = false,
    this.voiceAutoExecutionEnabled = false,
    this.voiceReviewMode = AgentVoiceReviewMode.alwaysReview,
    this.maxActionsPerMission = 4,
    this.maxActionsPerSession = 20,
    this.maxActionsPerHour = 30,
  });
  static const schema = 1;
  static const maxMission = 6, maxSession = 40, maxHour = 60;
  final AgentExecutionMode mode;
  final AgentVoiceReviewMode voiceReviewMode;
  final int consentVersion;
  final bool autoCreatePersonalGoals, autoCreateTasks, autoCreateReminders;
  final bool autoExecuteEligibleMissions, autoRunSimulations;
  final bool autoPrepareContributions, voiceAutoExecutionEnabled;
  final int maxActionsPerMission, maxActionsPerSession, maxActionsPerHour;
  bool get enabled =>
      mode == AgentExecutionMode.smartAuto ||
      mode == AgentExecutionMode.customAuto;
  bool get valid =>
      maxActionsPerMission >= 1 &&
      maxActionsPerMission <= maxMission &&
      maxActionsPerSession >= 1 &&
      maxActionsPerSession <= maxSession &&
      maxActionsPerHour >= 1 &&
      maxActionsPerHour <= maxHour &&
      (!enabled || consentVersion == schema);
  Map<String, Object?> toJson() => {
    'schema': schema,
    'mode': mode.name,
    'consentVersion': consentVersion,
    'autoCreatePersonalGoals': autoCreatePersonalGoals,
    'autoCreateTasks': autoCreateTasks,
    'autoCreateReminders': autoCreateReminders,
    'autoExecuteEligibleMissions': autoExecuteEligibleMissions,
    'autoRunSimulations': autoRunSimulations,
    'autoPrepareContributions': autoPrepareContributions,
    'voiceAutoExecutionEnabled': voiceAutoExecutionEnabled,
    'voiceReviewMode': voiceReviewMode.name,
    'maxActionsPerMission': maxActionsPerMission,
    'maxActionsPerSession': maxActionsPerSession,
    'maxActionsPerHour': maxActionsPerHour,
  };
  factory AgentAutopilotSettings.fromJson(Object? raw) {
    try {
      if (raw is! Map || raw['schema'] != schema) {
        return const AgentAutopilotSettings();
      }
      final m = Map<String, dynamic>.from(raw);
      // Reject unknown fields and wrong types rather than widening permissions.
      final defaults = const AgentAutopilotSettings().toJson();
      if (m.keys.any((k) => !defaults.containsKey(k))) {
        throw const FormatException();
      }
      for (final entry in defaults.entries) {
        final value = m[entry.key];
        if (value == null ||
            (entry.value is bool && value is! bool) ||
            (entry.value is int && value is! int)) {
          throw const FormatException();
        }
      }
      final result = AgentAutopilotSettings(
        mode: AgentExecutionMode.values.byName(m['mode'] as String),
        consentVersion: m['consentVersion'] as int,
        autoCreatePersonalGoals: m['autoCreatePersonalGoals'] as bool,
        autoCreateTasks: m['autoCreateTasks'] as bool,
        autoCreateReminders: m['autoCreateReminders'] as bool,
        autoExecuteEligibleMissions: m['autoExecuteEligibleMissions'] as bool,
        autoRunSimulations: m['autoRunSimulations'] as bool,
        autoPrepareContributions: m['autoPrepareContributions'] as bool,
        voiceAutoExecutionEnabled: m['voiceAutoExecutionEnabled'] as bool,
        voiceReviewMode: AgentVoiceReviewMode.values.byName(
          m['voiceReviewMode'] as String,
        ),
        maxActionsPerMission: m['maxActionsPerMission'] as int,
        maxActionsPerSession: m['maxActionsPerSession'] as int,
        maxActionsPerHour: m['maxActionsPerHour'] as int,
      );
      return result.valid ? result : const AgentAutopilotSettings();
    } catch (_) {
      return const AgentAutopilotSettings();
    }
  }
  AgentAutopilotSettings change(Map<String, Object?> values) =>
      AgentAutopilotSettings.fromJson({...toJson(), ...values});
}
