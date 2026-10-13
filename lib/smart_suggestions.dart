import 'dart:async';

import 'package:flutter/material.dart';

import 'design_system.dart';
import 'smart_task_recommendation_service.dart';

/// Derives suggestions from the planner's existing in-memory snapshot. Only
/// this section rebuilds when the clock ticks; it never reads Firestore.
class SmartSuggestions extends StatefulWidget {
  const SmartSuggestions({
    super.key,
    required this.tasks,
    required this.selectedDate,
    required this.onOpenTask,
    required this.onCompleteTask,
    required this.onAddTask,
    this.active = true,
    this.service,
  });

  final List<PlannerTask> tasks;
  final DateTime selectedDate;
  final ValueChanged<String> onOpenTask;
  final Future<void> Function(String) onCompleteTask;
  final VoidCallback onAddTask;
  final bool active;
  final SmartTaskRecommendationService? service;

  @override
  State<SmartSuggestions> createState() => _SmartSuggestionsState();
}

class _SmartSuggestionsState extends State<SmartSuggestions>
    with WidgetsBindingObserver {
  late SmartTaskRecommendationService _service;
  late SmartTaskPlan _plan;
  Timer? _timer;
  String? _completing;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _service = widget.service ?? SmartTaskRecommendationService();
    _calculate();
    _scheduleTick();
  }

  void _calculate() {
    _plan = _service.recommend(
      tasks: widget.tasks,
      selectedDate: widget.selectedDate,
    );
  }

  // Align to a local minute boundary so a 2:00 PM commitment updates at
  // 2:00 PM, rather than a minute after this widget happened to mount.
  void _scheduleTick() {
    _timer?.cancel();
    if (!widget.active || !_foreground) return;
    final now = _service.clock().toLocal();
    final elapsed = Duration(
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );
    _timer = Timer(const Duration(minutes: 1) - elapsed, () {
      if (!mounted) return;
      setState(_calculate);
      _scheduleTick();
    });
  }

  @override
  void didUpdateWidget(covariant SmartSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _service = widget.service ?? SmartTaskRecommendationService();
    }
    if (oldWidget.tasks != widget.tasks ||
        oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.service != widget.service ||
        (!oldWidget.active && widget.active)) {
      _calculate();
    }
    if (oldWidget.active != widget.active ||
        oldWidget.service != widget.service) {
      _scheduleTick();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && widget.active) setState(_calculate);
    _scheduleTick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _complete(String id) async {
    if (_completing != null) return;
    setState(() => _completing = id);
    try {
      await widget.onCompleteTask(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not complete this task. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = null);
    }
  }

  void _showReason(TaskRecommendation recommendation) {
    final conflicts = {for (final task in widget.tasks) task.id: task.title};
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FormHeading(
                icon: Icons.auto_awesome_outlined,
                title: 'Why this task?',
                detail: 'A little clarity for your next move.',
              ),
              const SizedBox(height: 12),
              Text(
                recommendation.task.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(recommendation.explanation),
              if (recommendation.task.time.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                DetailLine(
                  icon: Icons.schedule_outlined,
                  label: 'Recorded time: ${recommendation.task.time}',
                ),
              ],
              if (recommendation.hasScheduleConflict) ...[
                const SizedBox(height: 16),
                const Text(
                  'These tasks have overlapping schedules.',
                  style: TextStyle(
                    color: SaveTrackDesign.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final id in recommendation.conflictingTaskIds)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(conflicts[id] ?? 'Task no longer available'),
                  ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Suggestions use your recorded priorities and schedule. You decide what to work on.',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = _plan.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const MintIcon(Icons.auto_awesome_outlined, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Suggestions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text(
                    'Know what to focus on next.',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (first == null)
          SmartSuggestionsEmptyState(plan: _plan, onAddTask: widget.onAddTask)
        else ...[
          SmartPlannerSummary(plan: _plan),
          const SizedBox(height: 12),
          SmartSuggestionCard(
            recommendation: first,
            day: _plan.day,
            busy: _completing != null,
            onOpen: () => widget.onOpenTask(first.taskId),
            onComplete: () => _complete(first.taskId),
            onWhy: () => _showReason(first),
          ),
          if (_plan.recommendations.length > 1) ...[
            const SizedBox(height: 20),
            Text(
              _plan.day == RecommendationDay.past
                  ? 'Also to review'
                  : 'Up Next',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final recommendation in _plan.recommendations.skip(1).take(3))
              RecommendedTaskTile(
                recommendation: recommendation,
                onOpen: () => widget.onOpenTask(recommendation.taskId),
                onWhy: () => _showReason(recommendation),
              ),
          ],
        ],
      ],
    );
  }
}

class SmartPlannerSummary extends StatelessWidget {
  const SmartPlannerSummary({super.key, required this.plan});
  final SmartTaskPlan plan;

  @override
  Widget build(BuildContext context) => TonalPanel(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            Text(
              '${plan.remainingTasks} remaining',
              style: const TextStyle(color: teal, fontWeight: FontWeight.w600),
            ),
            Text(
              '${plan.highPriorityRemaining} high priority',
              style: const TextStyle(color: teal),
            ),
          ],
        ),
        if (plan.nextScheduledTask != null) ...[
          const SizedBox(height: 8),
          Text(
            'Next schedule: ${plan.nextScheduledTask!.title} · ${_clockLabel(context, plan.nextScheduledStart!)}',
            style: const TextStyle(color: teal, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'You have ${plan.minutesBeforeNextSchedule} minutes before it starts.',
            style: const TextStyle(color: muted, fontSize: 13),
          ),
        ],
      ],
    ),
  );
}

class SmartSuggestionCard extends StatelessWidget {
  const SmartSuggestionCard({
    super.key,
    required this.recommendation,
    required this.day,
    required this.onOpen,
    required this.onComplete,
    required this.onWhy,
    this.busy = false,
  });

  final TaskRecommendation recommendation;
  final RecommendationDay day;
  final VoidCallback onOpen, onComplete, onWhy;
  final bool busy;

  @override
  Widget build(BuildContext context) => MintHero(
    key: ValueKey('smart-primary-${recommendation.taskId}'),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          switch (day) {
            RecommendationDay.today => 'Your Next Move',
            RecommendationDay.future => 'Recommended Order',
            RecommendationDay.past => 'Review Unfinished Tasks',
          },
          style: const TextStyle(
            color: SaveTrackDesign.onHeroMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Based on your priorities and schedule.',
          style: TextStyle(color: SaveTrackDesign.onHeroMuted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        Text(
          recommendation.task.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeroChip('${recommendation.task.priority} priority'),
            _HeroChip(_categoryLabel(recommendation.category)),
          ],
        ),
        const SizedBox(height: 16),
        DetailLine(
          icon: Icons.schedule_outlined,
          label: recommendation.timeLabel,
          color: Colors.white,
        ),
        if (recommendation.task.time.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Scheduled: ${recommendation.task.time}',
            style: const TextStyle(
              color: SaveTrackDesign.onHeroMuted,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          recommendation.explanation,
          style: const TextStyle(
            color: SaveTrackDesign.onHeroMuted,
            height: 1.5,
          ),
        ),
        if (recommendation.hasScheduleConflict) ...[
          const SizedBox(height: 12),
          const DetailLine(
            icon: Icons.warning_amber_rounded,
            label: 'Overlapping schedules · review before starting',
            color: mint,
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: mint,
                foregroundColor: teal,
              ),
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('Edit Task'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: mint),
              ),
              onPressed: busy ? null : onComplete,
              icon: const Icon(Icons.check, size: 18),
              label: Text(busy ? 'Saving…' : 'Mark Complete'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: mint),
          onPressed: onWhy,
          icon: const Icon(Icons.info_outline, size: 16),
          label: const Text('Why this task?'),
        ),
      ],
    ),
  );
}

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0x26FFFFFF),
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class RecommendedTaskTile extends StatelessWidget {
  const RecommendedTaskTile({
    super.key,
    required this.recommendation,
    required this.onOpen,
    required this.onWhy,
  });
  final TaskRecommendation recommendation;
  final VoidCallback onOpen, onWhy;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('smart-next-${recommendation.taskId}'),
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SaveTrackDesign.mist,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        recommendation.rank.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recommendation.task.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: muted, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusPill(
                  '${recommendation.task.priority} priority',
                  color: recommendation.task.priority == 'High'
                      ? SaveTrackDesign.warning
                      : teal,
                ),
                Text(
                  recommendation.timeLabel,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
            if (recommendation.task.time.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Scheduled: ${recommendation.task.time}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              recommendation.explanation,
              style: const TextStyle(color: muted, fontSize: 13),
            ),
            if (recommendation.hasScheduleConflict) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onWhy,
                icon: const Icon(Icons.warning_amber_rounded, size: 16),
                label: const Text('Review overlapping tasks'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class SmartSuggestionsEmptyState extends StatelessWidget {
  const SmartSuggestionsEmptyState({
    super.key,
    required this.plan,
    required this.onAddTask,
  });
  final SmartTaskPlan plan;
  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) => Card(
    color: SaveTrackDesign.lightMint,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            plan.allCompleted ? Icons.task_alt : Icons.event_available_outlined,
            color: teal,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            plan.allCompleted
                ? plan.day == RecommendationDay.today
                      ? 'All done for today!'
                      : 'All tasks completed for this day!'
                : 'Your day is clear.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            plan.allCompleted
                ? 'You’ve completed the tasks for this day.'
                : 'Add a task to get personalized suggestions.',
            style: const TextStyle(color: muted),
          ),
          if (!plan.allCompleted) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add),
              label: const Text('Add a task'),
            ),
          ],
        ],
      ),
    ),
  );
}

String _clockLabel(BuildContext context, DateTime value) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

String _categoryLabel(RecommendationCategory value) => switch (value) {
  RecommendationCategory.currentlyScheduled => 'Current scheduled task',
  RecommendationCategory.startingSoon => 'Starting Soon',
  RecommendationCategory.needsAttention => 'Needs Attention',
  RecommendationCategory.flexible => 'Flexible Task',
  RecommendationCategory.scheduledLater => 'Scheduled Later',
  RecommendationCategory.reviewTime => 'Review Time',
};
