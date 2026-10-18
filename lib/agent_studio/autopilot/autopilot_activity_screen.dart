import 'package:flutter/material.dart';

import '../presentation/agent_theme.dart';
import '../presentation/agent_widgets.dart';

import '../agent_domain.dart';
import '../agent_engine.dart';
import 'execution_ledger.dart';
import 'autopilot_settings.dart';

class AgentAutopilotActivityScreen extends StatefulWidget {
  const AgentAutopilotActivityScreen({super.key, required this.engine});
  final AgentEngine engine;
  @override
  State<AgentAutopilotActivityScreen> createState() => _ActivityState();
}

class _ActivityState extends State<AgentAutopilotActivityScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) => AgentAtelierScope(
    engine: widget.engine,
    child: ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        final records = widget.engine.automaticActivity
            .where(
              (r) => switch (filter) {
                'Goals' => r.action is GoalDraft,
                'Tasks' => r.action is TaskDraft,
                'Reminders' => r.action is ReminderDraft,
                'Needs attention' =>
                  r.status == AgentOperationStatus.uncertain ||
                      r.status == AgentOperationStatus.dispatched,
                _ => true,
              },
            )
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Autopilot Activity')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const AgentSectionHeader(
                    title: 'A clear view of every action',
                    subtitle: 'Automatic actions and verified results.',
                  ),
                  const Text(
                    'Actual results and minimal recovery metadata stay on this device. Pending or interrupted operations are never replayed automatically.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final value in [
                        'All',
                        'Goals',
                        'Tasks',
                        'Reminders',
                        'Needs attention',
                      ])
                        ChoiceChip(
                          label: Text(value),
                          selected: filter == value,
                          onSelected: (_) => setState(() => filter = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (records.isEmpty)
                    const AgentEmptyState(
                      title: 'Nothing here yet.',
                      message: 'Automatic actions will appear here with their actual results and recovery status.',
                    ),
                  for (final record in records)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.action.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(record.action.summary),
                            Text(
                              '${record.status.name.toUpperCase()} · ${record.createdAt.toLocal().toString().substring(0, 16)}',
                            ),
                            const SizedBox(height: 8),
                            Text(record.message),
                            Text(
                              record.mode.label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (widget.engine.canReconcileAutomaticRecord(
                              record,
                            ))
                              TextButton.icon(
                                icon: const Icon(Icons.sync),
                                label: const Text('Check server result'),
                                onPressed: widget.engine.busy
                                    ? null
                                    : () async {
                                        try {
                                          await widget.engine
                                              .reconcileAutomaticRecord(record);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      e is AgentFailure
                                                          ? e.message
                                                          : 'Could not read the server result. Nothing was replayed.',
                                                    ),
                                                  ),
                                                );
                                          }
                                        }
                                      },
                              ),
                            if (widget.engine.canUndoAutomaticTask(record))
                              TextButton.icon(
                                icon: const Icon(Icons.undo),
                                label: const Text('Undo task creation'),
                                onPressed: widget.engine.busy
                                    ? null
                                    : () async {
                                        try {
                                          await widget.engine.undoAutomaticTask(
                                            record,
                                          );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      e is AgentFailure
                                                          ? e.message
                                                          : 'Could not verify undo. Inspect the task before retrying.',
                                                    ),
                                                  ),
                                                );
                                          }
                                        }
                                      },
                              ),
                            if (record.status ==
                                    AgentOperationStatus.dispatched ||
                                record.status == AgentOperationStatus.uncertain)
                              const Text(
                                'Inspect the record in SaveTrack. Retry unfinished mission steps through manual review to reconcile the same operation ID.',
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
