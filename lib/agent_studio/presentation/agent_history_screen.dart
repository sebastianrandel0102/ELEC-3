import 'package:flutter/material.dart';

import '../agent_domain.dart';
import '../agent_engine.dart';
import '../intelligence/agent_language.dart';
import 'agent_theme.dart';
import 'agent_widgets.dart';

String agentMissionStatus(MissionStatus status) => switch (status) {
  MissionStatus.needsClarification => 'Needs details',
  MissionStatus.readyForReview => 'Ready for review',
  MissionStatus.partiallyCompleted => 'Partially completed',
  _ => status.name[0].toUpperCase() + status.name.substring(1),
};

class AgentMissionActivityTile extends StatelessWidget {
  const AgentMissionActivityTile({
    super.key,
    required this.mission,
    required this.onTap,
  });
  final AgentMission mission;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ListTile(
        leading: Icon(
          mission.status == MissionStatus.completed
              ? Icons.check_circle_outline
              : Icons.route_outlined,
        ),
        title: Text(
          mission.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${agentDay(mission.createdAt)} · ${mission.steps.length} steps',
              ),
              const SizedBox(height: 8),
              AgentStatusChip(
                label: agentMissionStatus(mission.status),
                error: mission.status == MissionStatus.failed,
                icon: mission.status == MissionStatus.completed
                    ? Icons.check_circle_outline
                    : Icons.schedule,
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );
}

class AgentHistoryScreen extends StatefulWidget {
  const AgentHistoryScreen({
    super.key,
    required this.engine,
    required this.onOpen,
  });
  final AgentEngine engine;
  final ValueChanged<AgentMission> onOpen;
  @override
  State<AgentHistoryScreen> createState() => _AgentHistoryScreenState();
}

class _AgentHistoryScreenState extends State<AgentHistoryScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) => AgentAtelierScope(
    engine: widget.engine,
    child: ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        final s = AgentStrings(widget.engine.settings.interfaceLanguage);
        final missions =
            widget.engine.history
                .where(
                  (m) => switch (filter) {
                    'Completed' => m.status == MissionStatus.completed,
                    'Drafts' => [
                      MissionStatus.draft,
                      MissionStatus.needsClarification,
                      MissionStatus.readyForReview,
                    ].contains(m.status),
                    'Failed' => [
                      MissionStatus.failed,
                      MissionStatus.partiallyCompleted,
                    ].contains(m.status),
                    _ => true,
                  },
                )
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return Scaffold(
          appBar: AppBar(
            title: Text(s.choose('Mission history', 'Kasaysayan ng mission')),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AgentAtelier.readingWidth,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: missions.length + 1,
                  itemBuilder: (context, index) {
                    if (index > 0) {
                      return AgentMissionActivityTile(
                        mission: missions[index - 1],
                        onTap: () => widget.onOpen(missions[index - 1]),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AgentHero(
                          eyebrow: s.choose(
                            'YOUR PROGRESS',
                            'ANG PAG-UNLAD MO',
                          ),
                          title: s.choose(
                            'Small steps.\nMeaningful progress.',
                            'Maliliit na hakbang.\nMalaking pag-unlad.',
                          ),
                          subtitle: s.choose(
                            'Your saved plans and verified mission results, together in one place.',
                            'Mga naka-save na plano at resulta ng mission sa iisang lugar.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final value in [
                              'All',
                              'Completed',
                              'Drafts',
                              'Failed',
                            ])
                              ChoiceChip(
                                label: Text(s.text(value)),
                                selected: filter == value,
                                onSelected: (_) =>
                                    setState(() => filter = value),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (missions.isEmpty)
                          AgentEmptyState(
                            title: s.choose(
                              'Your next plan starts here.',
                              'Dito magsisimula ang susunod mong plano.',
                            ),
                            message: widget.engine.settings.history
                                ? s.choose(
                                    'No saved missions in this view yet.',
                                    'Wala pang naka-save na mission dito.',
                                  )
                                : s.choose(
                                    'Enable local mission history in Agent settings to keep drafts and recovery for 30 days.',
                                    'I-on ang lokal na kasaysayan sa settings para itago ang mga draft at recovery sa loob ng 30 araw.',
                                  ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
