import 'package:flutter/material.dart';

import '../currency_money.dart';
import 'agent_domain.dart';
import 'agent_engine.dart';

Future<AgentAction?> showAgentActionPicker(
  BuildContext context, {
  required AgentEngine engine,
}) async {
  final type = await showModalBottomSheet<AgentActionType>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final item in [
            (AgentActionType.createGoal, Icons.flag_outlined, 'Savings goal'),
            (
              AgentActionType.createTask,
              Icons.checklist_rounded,
              'Planner task',
            ),
            (
              AgentActionType.createReminder,
              Icons.notifications_outlined,
              'Reminder',
            ),
            (
              AgentActionType.contribution,
              Icons.savings_outlined,
              'Prepare contribution',
            ),
            (
              AgentActionType.scenario,
              Icons.calculate_outlined,
              'Savings scenario',
            ),
            (
              AgentActionType.allocation,
              Icons.pie_chart_outline,
              'Equal goal allocation',
            ),
          ])
            ListTile(
              leading: Icon(item.$2),
              title: Text(item.$3),
              onTap: () => Navigator.pop(ctx, item.$1),
            ),
        ],
      ),
    ),
  );
  if (type == null || !context.mounted) return null;
  final action = switch (type) {
    AgentActionType.createGoal => const GoalDraft(),
    AgentActionType.createTask => const TaskDraft(),
    AgentActionType.createReminder => const ReminderDraft(),
    AgentActionType.contribution => const ContributionDraft(),
    AgentActionType.scenario => const ScenarioDraft(),
    AgentActionType.allocation => const AllocationDraft(),
  };
  return showAgentStepEditor(context, action, engine: engine);
}

Future<AgentAction?> showAgentStepEditor(
  BuildContext context,
  AgentAction action, {
  required AgentEngine engine,
}) => showDialog<AgentAction>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _StepEditor(action: action, engine: engine),
);

class _StepEditor extends StatefulWidget {
  const _StepEditor({required this.action, required this.engine});
  final AgentAction action;
  final AgentEngine engine;
  @override
  State<_StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<_StepEditor> {
  late final Map<String, Object?> values = Map.of(widget.action.toJson());
  final Map<String, TextEditingController> controllers = {};
  List<AgentRecord> goals = [];
  bool loading = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController controller(String key) => controllers.putIfAbsent(
    key,
    () => TextEditingController(text: values[key]?.toString() ?? ''),
  );
  Widget field(String key, String label, {bool money = false, String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: controller(key),
          maxLength: money ? 30 : 100,
          keyboardType: money
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            counterText: '',
          ),
          onChanged: (v) => setState(() => values[key] = v.trim()),
        ),
      );
  Widget choice(String key, String label, List<(String, String)> options) {
    final current = values[key]?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$key:$current'),
        isExpanded: true,
        initialValue: options.any((o) => o.$1 == current) ? current : null,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final option in options)
            DropdownMenuItem(
              value: option.$1,
              child: Text(option.$2, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => values[key] = v),
      ),
    );
  }

  Widget currency() => choice('currency', 'Currency (required)', [
    for (final code in CurrencyCatalog.byCode.keys)
      (code, '$code · ${CurrencyCatalog.byCode[code]!.name}'),
  ]);
  Widget date(String key, String label) {
    final value = values[key] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: OutlinedButton.icon(
        onPressed: () async {
          final today = DateTime.now(), parsed = DateTime.tryParse(value ?? '');
          final selected = await showDatePicker(
            context: context,
            firstDate: DateTime(today.year, today.month, today.day),
            lastDate: DateTime(today.year + 10, 12, 31),
            initialDate:
                parsed != null &&
                    !parsed.isBefore(
                      DateTime(today.year, today.month, today.day),
                    ) &&
                    parsed.year <= today.year + 10
                ? parsed
                : today,
          );
          if (selected != null && mounted) {
            setState(() => values[key] = selected.toIso8601String());
          }
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(
          '$label: ${value == null ? 'Choose date' : agentDay(DateTime.parse(value))}',
        ),
      ),
    );
  }

  Widget time() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: OutlinedButton.icon(
      onPressed: () async {
        final value = values['time'] as String? ?? '';
        final initial = agentTime(value)
            ? TimeOfDay(
                hour: int.parse(value.split(':')[0]),
                minute: int.parse(value.split(':')[1]),
              )
            : TimeOfDay.now();
        final selected = await showTimePicker(
          context: context,
          initialTime: initial,
        );
        if (selected != null && mounted) {
          setState(
            () => values['time'] =
                '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
          );
        }
      },
      icon: const Icon(Icons.schedule_outlined),
      label: Text(
        'Time: ${(values['time'] as String? ?? '').isEmpty ? 'Choose time' : values['time']}',
      ),
    ),
  );
  Future<void> loadGoals() async {
    if (!widget.engine.settings.permissions.contains(
      AgentPermission.privateContext,
    )) {
      setState(
        () => error = 'Enable Private Context Access in Agent settings to select your existing goals.',
      );
      return;
    }
    setState(() => loading = true);
    try {
      final result = await widget.engine.backend.goals().timeout(
        AgentLimits.requestTimeout,
      );
      if (mounted && widget.engine.active) setState(() => goals = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not load current goals. Check your connection.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Widget> target({bool contribution = false}) {
    final reference = contribution ? 'goalId' : 'targetId';
    final targetStep = values['targetStep'] as String? ?? '';
    return [
      if (!contribution)
        choice('targetStep', 'Link to a step', [
          ('', 'Choose an existing goal instead'),
          for (final s in widget.engine.mission?.steps ?? <AgentStep>[])
            if (s.action is GoalDraft || s.action is TaskDraft)
              (s.id, '${s.id}: ${s.action.summary}'),
        ]),
      if (!contribution && targetStep.isNotEmpty) ...[
        Builder(
          builder: (_) {
            final parent = widget.engine.mission?.steps
                .where((s) => s.id == targetStep)
                .firstOrNull;
            values['targetId'] = '';
            values['targetKind'] = parent?.action is TaskDraft
                ? 'task'
                : 'personalGoal';
            return Text(
              'Linked ${values['targetKind'] == 'task' ? 'task' : 'goal'} will be created first.',
            );
          },
        ),
      ] else ...[
        TextButton.icon(
          onPressed: loading ? null : loadGoals,
          icon: const Icon(Icons.refresh),
          label: Text(loading ? 'Loading…' : 'Load my personal goals'),
        ),
        if (goals.isNotEmpty)
          choice(
            reference,
            'Existing personal goal',
            goals.map((g) => (g.id, '${g.title} · ${g.currency}')).toList(),
          ),
        if ((values[reference] as String? ?? '').isNotEmpty &&
            goals.every((g) => g.id != values[reference]))
          const Text(
            'A goal is already selected. Load goals to review or change it.',
          ),
        if (goals.isEmpty)
          const Text(
            'No goal data is sent to external AI. You can also link a reminder to a new goal or task in this mission.',
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final reminderTask = values['targetKind'] == 'task';
    if (action is ReminderDraft &&
        reminderTask &&
        !['once', 'taskStart'].contains(values['frequency'])) {
      values['frequency'] = 'once';
    }
    final widgets = <Widget>[
      if (action is GoalDraft) ...[
        field('name', 'Goal name'),
        field('amount', 'Target amount', money: true),
        currency(),
        date('deadline', 'Goal deadline'),
      ],
      if (action is TaskDraft) ...[
        field('title', 'Task title'),
        date('day', 'Planner date'),
        field(
          'time',
          'Start time (optional)',
          hint: 'HH:mm · Leave blank for flexible time',
        ),
        choice('priority', 'Priority', [
          ('Low', 'Low'),
          ('Normal', 'Normal'),
          ('High', 'High'),
        ]),
      ],
      if (action is ReminderDraft) ...[
        ...target(),
        const SizedBox(height: 14),
        choice(
          'frequency',
          'Recurrence',
          reminderTask
              ? [('once', 'Once'), ('taskStart', 'Before task start')]
              : [
                  ('weekly', 'Weekly'),
                  ('daily', 'Daily'),
                  ('once', 'Once'),
                  ('deadline', 'On goal deadline'),
                ],
        ),
        if (values['frequency'] == 'weekly')
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownButtonFormField<int>(
              initialValue: values['weekday'] as int?,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Weekday'),
              items: [
                for (var i = 1; i <= 7; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday',
                        'Saturday',
                        'Sunday',
                      ][i - 1],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => values['weekday'] = v),
            ),
          ),
        if (values['frequency'] == 'once') date('day', 'Reminder date'),
        time(),
        if (values['frequency'] == 'taskStart')
          const Text(
            'Uses the existing reminder service’s 15-minute lead time. The target task needs a start time.',
          ),
      ],
      if (action is ContributionDraft) ...[
        ...target(contribution: true),
        const SizedBox(height: 14),
        field('amount', 'Prepared contribution amount', money: true),
        currency(),
        const Text(
          'This only opens the existing Add Savings form. Review and confirm the transaction separately there.',
        ),
      ],
      if (action is ScenarioDraft) ...[
        field('target', 'Target amount', money: true),
        field('saved', 'Already saved', money: true),
        field('contribution', 'Weekly contribution (optional)', money: true),
        currency(),
        date('deadline', 'Scenario deadline'),
        const Text(
          'Choose a weekly amount or a deadline. This is a local estimate and never creates deposits.',
        ),
      ],
      if (action is AllocationDraft) ...[
        field('budget', 'Budget to allocate', money: true),
        currency(),
        const Text(
          'Equal allocation across unfinished personal goals in the selected currency. Remainder minor units are distributed in goal order. No transfers occur. Requires Private Context Access.',
        ),
      ],
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ];
    return AlertDialog(
      scrollable: true,
      title: Text(action.label),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widgets,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: loading
              ? null
              : () {
                  try {
                    final draft = AgentAction.fromJson(values);
                    final issues = draft.validate(DateTime.now());
                    if (issues.isNotEmpty) {
                      setState(() => error = issues.join('\n'));
                      return;
                    }
                    Navigator.pop(context, draft);
                  } catch (_) {
                    setState(() => error = 'Review the entered details.');
                  }
                },
          child: const Text('Save draft details'),
        ),
      ],
    );
  }
}
