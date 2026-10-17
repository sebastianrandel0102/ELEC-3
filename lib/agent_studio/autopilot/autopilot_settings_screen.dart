import 'package:flutter/material.dart';

import '../agent_domain.dart';
import '../agent_engine.dart';
import 'autopilot_settings.dart';
import 'autopilot_activity_screen.dart';

class AgentAutopilotSettingsScreen extends StatelessWidget {
  const AgentAutopilotSettingsScreen({super.key, required this.engine});
  final AgentEngine engine;

  Future<void> _change(
    BuildContext context,
    Map<String, Object?> values,
  ) async {
    try {
      final permissions = {...engine.settings.permissions};
      for (final category in {
        'autoCreatePersonalGoals': AgentPermission.createGoal,
        'autoCreateTasks': AgentPermission.createTask,
        'autoCreateReminders': AgentPermission.createReminder,
        'autoPrepareContributions': AgentPermission.contribution,
      }.entries) {
        if (values[category.key] == true) permissions.add(category.value);
      }
      await engine.updateSettings(
        engine.settings.change({
          'autopilot': engine.settings.autopilot.change(values).toJson(),
          'permissions': permissions.map((p) => p.name).toList(),
        }),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Autopilot settings could not be saved. Automatic actions are disabled.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _mode(BuildContext context, AgentExecutionMode mode) async {
    final enabling =
        mode == AgentExecutionMode.smartAuto ||
        mode == AgentExecutionMode.customAuto;
    if (enabling) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable automatic actions?'),
          content: SingleChildScrollView(
            child: Text(
              mode == AgentExecutionMode.smartAuto
                  ? 'Smart Auto can create personal goals, Planner tasks, reminders, and eligible missions without another approval screen. Each action is validated and checked against your limits.\n\nFinancial transactions and destructive changes still require confirmation. Spoken commands have a separate permission. Mistaken but valid instructions remain possible.\n\nSettings and minimal recovery metadata stay on this device, separately for each account.'
                  : 'Only the categories you enable below can run without another approval screen. Each action must pass validation and your execution limits.\n\nFinancial transactions and destructive changes still require confirmation. Mistaken but valid instructions remain possible. Settings and recovery metadata are local to this device and account.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Ask First'),
            ),
            FilledButton(
              key: const Key('autopilot-consent'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable Auto-Execute'),
            ),
          ],
        ),
      );
      if (accepted != true || !context.mounted || !engine.active) return;
    }
    try {
      final smart = mode == AgentExecutionMode.smartAuto;
      final auto = engine.settings.autopilot.change({
        'mode': mode.name,
        if (enabling) 'consentVersion': AgentAutopilotSettings.schema,
        if (smart) ...{
          'autoCreatePersonalGoals': true,
          'autoCreateTasks': true,
          'autoCreateReminders': true,
          'autoExecuteEligibleMissions': true,
          'autoPrepareContributions': false,
        },
      });
      await engine.updateSettings(
        engine.settings.change({
          'autopilot': auto.toJson(),
          if (enabling) 'execute': true,
          if (smart)
            'permissions': {
              ...engine.settings.permissions,
              AgentPermission.createGoal,
              AgentPermission.createTask,
              AgentPermission.createReminder,
            }.map((p) => p.name).toList(),
        }),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save the execution mode. Automatic actions are disabled.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final auto = engine.settings.autopilot;
      final colors = Theme.of(context).colorScheme;
      Widget toggle(String key, String title, String description, bool value) =>
          SwitchListTile.adaptive(
            key: Key('autopilot-$key'),
            title: Text(title),
            subtitle: Text(description),
            value: value,
            onChanged: (v) => _change(context, {key: v}),
          );
      Widget limit(String key, String title, int value, int maximum) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: DropdownButtonFormField<int>(
          isExpanded: true,
          key: ValueKey('$key-$value'),
          initialValue: value,
          decoration: InputDecoration(labelText: title),
          items: [
            for (var n = 1; n <= maximum; n++)
              DropdownMenuItem(value: n, child: Text('$n actions')),
          ],
          onChanged: (n) {
            if (n != null) _change(context, {key: n});
          },
        ),
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Agent Autopilot')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 32),
                      const SizedBox(height: 16),
                      Text(
                        'Your Agent. Your Rules.',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose which actions SaveTrack can complete automatically.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        auto.mode.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Text('Mint Aurora 6.5 · Agent Autopilot'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                for (final item in [
                  (
                    AgentExecutionMode.askBeforeEveryAction,
                    'Ask Before Every Action',
                    'Review and approve each mutating action. The default for every account.',
                  ),
                  (
                    AgentExecutionMode.smartAuto,
                    'Smart Auto-Execute',
                    'Create permitted personal goals, tasks, reminders, and eligible missions when instructions are clear.',
                  ),
                  (
                    AgentExecutionMode.customAuto,
                    'Custom Auto-Execute',
                    'Choose exactly which supported categories can run automatically.',
                  ),
                  (
                    AgentExecutionMode.paused,
                    'Paused',
                    'Stop new automatic actions. Manual review remains available.',
                  ),
                ])
                  Card(
                    child: ListTile(
                      key: Key('autopilot-mode-${item.$1.name}'),
                      title: Text(item.$2),
                      subtitle: Text(item.$3),
                      trailing: Icon(
                        auto.mode == item.$1
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: () => _mode(context, item.$1),
                    ),
                  ),
                if (auto.enabled)
                  FilledButton.tonalIcon(
                    onPressed: () => _mode(context, AgentExecutionMode.paused),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Pause Autopilot'),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Automatic action permissions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Text(
                  'Both these settings and the individual Agent action permissions must allow an action. Changes apply immediately.',
                ),
                toggle(
                  'autoCreatePersonalGoals',
                  'Automatically Create Personal Goals',
                  'Creates empty personal goals. Never records a starting deposit.',
                  auto.autoCreatePersonalGoals,
                ),
                toggle(
                  'autoCreateTasks',
                  'Automatically Create Tasks',
                  'New personal Planner tasks, with duplicate and schedule checks.',
                  auto.autoCreateTasks,
                ),
                toggle(
                  'autoCreateReminders',
                  'Automatically Create Reminders',
                  'Supported reminders linked to personal goals or tasks. Phone notification access is required.',
                  auto.autoCreateReminders,
                ),
                toggle(
                  'autoExecuteEligibleMissions',
                  'Automatically Execute Eligible Missions',
                  'Every step must qualify. Mixed sensitive missions go to review together.',
                  auto.autoExecuteEligibleMissions,
                ),
                toggle(
                  'autoRunSimulations',
                  'Automatically Run What-If Simulations',
                  'Local read-only calculations can run in Ask First and Paused modes too.',
                  auto.autoRunSimulations,
                ),
                toggle(
                  'autoPrepareContributions',
                  'Automatically Prepare Savings Contributions',
                  'Opens Add Savings for a single request. The financial confirmation remains mandatory.',
                  auto.autoPrepareContributions,
                ),
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Existing records and shared goals'),
                  subtitle: Text(
                    'Goal edits, task rescheduling, completion, reminder changes, deletion, withdrawals, and shared-goal changes retain their existing review workflows.',
                  ),
                ),
                const Divider(height: 32),
                SwitchListTile.adaptive(
                  key: const Key('autopilot-voice'),
                  title: const Text(
                    'Allow Automatic Actions from Voice Commands',
                  ),
                  subtitle: const Text(
                    'Off by default. Final speech can contain misheard names, amounts, and dates.',
                  ),
                  value: auto.voiceAutoExecutionEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final accepted = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Allow spoken automatic actions?'),
                          content: const Text(
                            'Eligible final spoken commands may execute without Mission Review. Speech recognition can mishear critical details. Financial confirmations remain required. The microphone still starts only when you tap it.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Enable voice Auto-Execute'),
                            ),
                          ],
                        ),
                      );
                      if (accepted != true || !context.mounted) return;
                    }
                    if (context.mounted) {
                      await _change(context, {'voiceAutoExecutionEnabled': v});
                    }
                  },
                ),
                DropdownButtonFormField<AgentVoiceReviewMode>(
                  key: ValueKey(auto.voiceReviewMode),
                  initialValue: auto.voiceReviewMode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Spoken transcript review',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AgentVoiceReviewMode.alwaysReview,
                      child: Text('Always review before sending'),
                    ),
                    DropdownMenuItem(
                      value: AgentVoiceReviewMode.reviewUncertain,
                      child: Text('Review uncertain recognition'),
                    ),
                    DropdownMenuItem(
                      value: AgentVoiceReviewMode.autoRunEligible,
                      child: Text('Auto-run eligible final speech'),
                    ),
                  ],
                  onChanged: !auto.voiceAutoExecutionEnabled
                      ? null
                      : (v) {
                          if (v != null) {
                            _change(context, {'voiceReviewMode': v.name});
                          }
                        },
                ),
                const Divider(height: 32),
                const Text(
                  'Safety limits',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Text(
                  'At most 2 goals, 6 tasks, or 3 reminders per request, within the total limit. Attempts with uncertain outcomes still count. Hourly limits survive an app restart on this device.',
                ),
                limit(
                  'maxActionsPerMission',
                  'Actions per request',
                  auto.maxActionsPerMission,
                  AgentAutopilotSettings.maxMission,
                ),
                limit(
                  'maxActionsPerSession',
                  'Actions per session',
                  auto.maxActionsPerSession,
                  AgentAutopilotSettings.maxSession,
                ),
                limit(
                  'maxActionsPerHour',
                  'Actions per hour',
                  auto.maxActionsPerHour,
                  AgentAutopilotSettings.maxHour,
                ),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('View Automatic Actions'),
                  subtitle: const Text(
                    'Results, policy authorization, and recovery status. Up to 500 local operations.',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AgentAutopilotActivityScreen(engine: engine),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'SaveTrack checks permissions and validates each action before applying it. Financial transactions and destructive changes still require confirmation. Settings are specific to this device and account; they do not sync to other devices.',
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('autopilot-reset'),
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset Autopilot Settings'),
                  onPressed: () async {
                    try {
                      await engine.updateSettings(
                        engine.settings.change({
                          'autopilot': const AgentAutopilotSettings().toJson(),
                        }),
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not persist reset. Automatic actions are disabled for this session.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
