import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/autopilot/autopilot_settings.dart';
import 'package:myproject/agent_studio/autopilot/auto_execution_policy.dart';
import 'package:myproject/agent_studio/agent_engine.dart';

import 'agent_studio_fixtures.dart';

AgentAutopilotSettings smartAutopilot({
  Map<String, Object?> changes = const {},
}) => const AgentAutopilotSettings().change({
  'mode': AgentExecutionMode.smartAuto.name,
  'consentVersion': 1,
  'autoCreatePersonalGoals': true,
  'autoCreateTasks': true,
  'autoCreateReminders': true,
  'autoExecuteEligibleMissions': true,
  ...changes,
});

Future<void> enableAutopilot(
  AgentEngine engine, {
  Map<String, Object?> changes = const {},
}) async {
  await enableAgent(engine);
  await engine.updateSettings(
    engine.settings.change({
      'autopilot': smartAutopilot(changes: changes).toJson(),
    }),
  );
}

void main() {
  const policy = AgentAutoExecutionPolicyEngine();
  AgentPolicyDecision decide({
    AgentAutopilotSettings? auto,
    AgentAction? action,
    AgentRequestOrigin origin = AgentRequestOrigin.userText,
    String? uid = 'owner',
    bool resolved = true,
    bool foreground = true,
    bool checked = true,
    bool planOnly = false,
    int session = 0,
    int hour = 0,
    Set<AgentPermission>? permissions,
    bool execute = true,
    DateTime? created,
  }) => policy.evaluate(
    mission: AgentMission(
      id: 'missionA',
      uid: 'owner',
      title: 'Plan',
      createdAt: created ?? agentNow,
      planOnly: planOnly,
      steps: [AgentStep(id: 'step_1', action: action ?? goalDraft())],
    ),
    settings: AgentSettings(
      execute: execute,
      permissions: permissions ?? AgentPermission.values.toSet(),
      autopilot: auto ?? smartAutopilot(),
    ),
    context: AgentExecutionContext(
      uid: uid,
      origin: origin,
      now: agentNow,
      foreground: foreground,
      resolved: resolved,
      serverChecked: checked,
      sessionActions: session,
      hourActions: hour,
    ),
  );

  test(
    'legacy settings migrate to Ask First with every mutation category off',
    () {
      final old = AgentSettings.fromJson({
        'execute': true,
        'permissions': ['createGoal'],
      });
      expect(old.autopilot.mode, AgentExecutionMode.askBeforeEveryAction);
      expect(old.autopilot.autoCreatePersonalGoals, false);
      expect(old.autopilot.voiceAutoExecutionEnabled, false);
      expect(old.execute, true);
      expect(old.permissions, {AgentPermission.createGoal});
    },
  );
  test(
    'versioned settings round trip; invalid types, limits, consent fail closed',
    () {
      final smart = smartAutopilot();
      expect(
        AgentAutopilotSettings.fromJson(smart.toJson()).mode,
        AgentExecutionMode.smartAuto,
      );
      for (final change in [
        {'schema': 2},
        {'mode': 'unrestricted'},
        {'autoCreateTasks': 'yes'},
        {'maxActionsPerHour': 10000},
        {'maxActionsPerMission': 0},
        {'consentVersion': 0},
        {'arbitraryWrites': true},
      ]) {
        expect(
          AgentAutopilotSettings.fromJson({...smart.toJson(), ...change})
              .enabled,
          false,
        );
      }
    },
  );
  for (final mode in AgentExecutionMode.values) {
    test('${mode.name} has explicit mutation behavior', () {
      expect(
        decide(auto: smartAutopilot(changes: {'mode': mode.name})).decision,
        mode == AgentExecutionMode.smartAuto ||
                mode == AgentExecutionMode.customAuto
            ? AgentAutoDecision.executeAutomatically
            : AgentAutoDecision.requireReview,
      );
    });
  }
  test('trusted classifier covers every current action without model-supplied risk', () {
    const classifier = AgentActionRiskClassifier();
    expect(classifier.classify(goalDraft()), AgentActionRisk.low);
    expect(classifier.classify(taskDraft()), AgentActionRisk.low);
    expect(classifier.classify(const ReminderDraft()), AgentActionRisk.low);
    expect(
      classifier.classify(const ContributionDraft()),
      AgentActionRisk.high,
    );
    expect(
      classifier.classify(const ScenarioDraft()),
      AgentActionRisk.readOnly,
    );
    expect(
      classifier.classify(const AllocationDraft()),
      AgentActionRisk.readOnly,
    );
  });
  for (final origin in AgentRequestOrigin.values) {
    test('origin ${origin.name} cannot widen execution authority', () {
      final result = decide(origin: origin);
      expect(
        result.decision,
        origin == AgentRequestOrigin.userText
            ? AgentAutoDecision.executeAutomatically
            : origin == AgentRequestOrigin.finalVoice
            ? AgentAutoDecision.requireReview
            : AgentAutoDecision.blocked,
      );
    });
  }
  for (final pair in [
    (goalDraft(), 'autoCreatePersonalGoals'),
    (taskDraft(), 'autoCreateTasks'),
    (
      const ReminderDraft(
        targetId: 'goalA',
        frequency: 'weekly',
        weekday: 5,
        time: '19:00',
      ),
      'autoCreateReminders',
    ),
  ]) {
    test('separate permission is required for ${pair.$2}', () {
      expect(
        decide(
          action: pair.$1,
          auto: smartAutopilot(changes: {pair.$2: false}),
        ).reasonCode,
        'category_permission',
      );
      expect(
        decide(action: pair.$1, permissions: {}).reasonCode,
        'category_permission',
      );
    });
  }
  test('identity, foreground, stale data, validation, draft intent and offline fail closed', () {
    expect(decide(uid: null).reasonCode, 'identity');
    expect(decide(uid: 'other').reasonCode, 'identity');
    expect(decide(foreground: false).decision, AgentAutoDecision.deferred);
    expect(decide(resolved: false).decision, AgentAutoDecision.clarify);
    expect(
      decide(action: const GoalDraft()).decision,
      AgentAutoDecision.clarify,
    );
    expect(decide(planOnly: true).decision, AgentAutoDecision.draftOnly);
    expect(decide(checked: false).decision, AgentAutoDecision.deferred);
    expect(
      decide(created: agentNow.subtract(const Duration(hours: 1))).reasonCode,
      'stale',
    );
    expect(decide(execute: false).reasonCode, 'execute_permission');
  });
  test('rolling and session budgets are bounded', () {
    expect(decide(session: 20).reasonCode, 'session_limit');
    expect(decide(hour: 30).reasonCode, 'hour_limit');
    expect(decide(session: 19, hour: 29).mayRun, true);
  });
  test(
    'read-only scenarios run in every mode without mutation permissions',
    () {
      for (final mode in AgentExecutionMode.values) {
        expect(
          decide(
            auto: smartAutopilot(changes: {'mode': mode.name}),
            execute: false,
            permissions: {},
            action: const ScenarioDraft(
              target: '30000',
              contribution: '700',
              currency: 'PHP',
            ),
          ).decision,
          AgentAutoDecision.readOnly,
        );
      }
    },
  );
  test('single contribution can only prepare the dedicated form after separate opt in', () {
    const action = ContributionDraft(
      goalId: 'goalA',
      amount: '500',
      currency: 'PHP',
    );
    expect(decide(action: action).reasonCode, 'financial_confirmation');
    expect(
      decide(
        action: action,
        auto: smartAutopilot(changes: {'autoPrepareContributions': true}),
      ).mayRun,
      true,
    );
  });
}
