import 'package:flutter/material.dart';

import '../agent_domain.dart';
import 'agent_interpretation.dart';
import 'agent_language.dart';
import 'title_resolver.dart';

/// Displays the actual editable action, so a stale interpretation cannot show
/// values different from those submitted for review.
class AgentInterpretationPreview extends StatelessWidget {
  const AgentInterpretationPreview({
    super.key,
    required this.action,
    required this.strings,
    this.binding,
  });
  final AgentAction action;
  final AgentStrings strings;
  final TitleBinding? binding;
  @override
  Widget build(BuildContext context) {
    final title = switch (action) {
      GoalDraft a => a.name,
      TaskDraft a => a.title,
      ReminderDraft a => a.title,
      ScenarioDraft a => a.title,
      _ => '',
    };
    final titleLabel = switch (action) {
      GoalDraft() => strings.choose('Goal Title', 'Pangalan ng goal'),
      TaskDraft() => strings.choose('Task Title', 'Pamagat ng gawain'),
      ReminderDraft() => strings.choose(
        'Reminder Title',
        'Pangalan ng paalala',
      ),
      ScenarioDraft() => strings.choose(
        'Scenario Title',
        'Pangalan ng scenario',
      ),
      _ => strings.choose('Title', 'Pangalan'),
    };
    final origin = binding?.title.origin;
    final rows = <(String, String)>[
      if (action is! ContributionDraft && action is! AllocationDraft)
        (
          titleLabel,
          title.isEmpty
              ? strings.choose('Not specified', 'Hindi pa tinukoy')
              : title,
        ),
      if (origin != null)
        (
          strings.choose('Title source', 'Pinagmulan ng pangalan'),
          switch (origin) {
            SlotOrigin.explicitNaming => strings.choose(
              'Your title',
              'Pangalan mo',
            ),
            SlotOrigin.inferredPurpose => strings.choose(
              'Suggested from purpose · Please review',
              'Mungkahi mula sa layunin · Suriin muna',
            ),
            SlotOrigin.contextFollowUp => strings.choose(
              'Your follow-up',
              'Mula sa kasunod mong sagot',
            ),
            SlotOrigin.userCorrection => strings.choose(
              'Your correction',
              'Pagwawasto mo',
            ),
            SlotOrigin.missing => strings.choose(
              'Missing detail',
              'May kulang na detalye',
            ),
          },
        ),
      if (binding?.title.purpose.isNotEmpty == true)
        (strings.choose('Purpose', 'Layunin'), binding!.title.purpose),
      if (action case GoalDraft a) ...[
        (
          strings.choose('Target', 'Target'),
          a.amount.isEmpty
              ? strings.choose('Not specified', 'Hindi pa tinukoy')
              : agentMoney(a.amount, a.currency),
        ),
        (
          strings.choose('Deadline', 'Takdang petsa'),
          a.deadline == null
              ? strings.choose('Not selected', 'Hindi pa napili')
              : agentDay(a.deadline!),
        ),
      ],
    ];
    return Container(
      key: const Key('agent-interpretation-preview'),
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.choose('I understood · Draft', 'Naunawaan ko · Draft'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${row.$1}: ${row.$2}',
                style: const TextStyle(height: 1.5),
              ),
            ),
          if (action is ScenarioDraft)
            Text(
              strings.choose(
                'Simulation · No balance changes',
                'Simulation · Walang pagbabago sa balanse',
              ),
            ),
        ],
      ),
    );
  }
}
