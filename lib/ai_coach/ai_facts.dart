import '../currency_money.dart';
import '../smart_task_recommendation_service.dart';
import 'ai_domain.dart';

AiLocalFacts aiGoalFacts({
  required String key,
  required String uid,
  required String title,
  required num saved,
  required num target,
  required String currency,
  required String revision,
  DateTime? deadline,
  bool shared = false,
  DateTime? now,
}) {
  if (!saved.isFinite || !target.isFinite || saved < 0 || target < 0) {
    throw const AiFailure(
      AiErrorKind.privacy,
      'This goal has unavailable financial values.',
    );
  }
  final balance = ExactDecimal.fromNum(saved),
      goal = ExactDecimal.fromNum(target);
  final difference = goal - balance;
  final remaining = difference.positive ? difference : ExactDecimal.zero;
  final progress = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final days = deadline?.difference(today).inDays;
  final completed = target > 0 && balance.compareTo(goal) >= 0;
  final overdue = deadline?.isBefore(today) ?? false;
  final values = <String, String>{
    'Saved': formatCurrency(balance, currency),
    'Target': formatCurrency(goal, currency),
    'Remaining': formatCurrency(remaining, currency),
    'Progress': '${(progress * 100).toStringAsFixed(1)}%',
    'Deadline': deadline == null
        ? 'Not set'
        : SmartTaskRecommendationService.dateKey(deadline),
    'Days remaining': days == null
        ? 'No deadline'
        : days < 0
        ? 'Past deadline'
        : '$days',
    'Status': completed
        ? 'Completed'
        : overdue
        ? 'Overdue'
        : 'Active',
  };
  // Same deadline window and remaining-amount meaning as the existing goal card.
  // ExactDecimal preserves each original currency's rounding/precision.
  if (!completed && !overdue && days != null && remaining.positive) {
    final pace = remaining / ExactDecimal.fromNum(days.clamp(1, 365000));
    values['Daily pace'] = formatCurrency(pace, currency);
    values['Weekly pace'] = formatCurrency(
      pace * ExactDecimal.fromNum(7),
      currency,
    );
    values['Pace assumption'] =
        'Equal contributions until the deadline; a local estimate.';
  }
  values['Contribution history'] =
      'Not included; no historical trend inferred.';
  return AiLocalFacts(
    title: title,
    values: values,
    subjectKey: key,
    revision: revision,
    ownerUid: uid,
    shared: shared,
    progress: progress,
    summary: AiSafeSummary({
      AiContextField.subject: AiContextValue.savings,
      AiContextField.progress: completed
          ? AiContextValue.achieved
          : progress == 0
          ? AiContextValue.notStarted
          : progress < .4
          ? AiContextValue.early
          : progress < .75
          ? AiContextValue.midway
          : AiContextValue.advanced,
      AiContextField.deadline: deadline == null
          ? AiContextValue.noDeadline
          : overdue
          ? AiContextValue.overdue
          : (days ?? 0) <= 14
          ? AiContextValue.soon
          : AiContextValue.later,
    }),
  );
}

AiLocalFacts aiPlannerFacts({
  required String key,
  required String uid,
  required String title,
  required List<PlannerTask> tasks,
  required String revision,
  bool report = false,
}) {
  final completed = tasks.where((t) => t.completed).length;
  final high = tasks.where((t) => !t.completed && t.priority == 'High').length;
  return AiLocalFacts(
    title: title,
    ownerUid: uid,
    subjectKey: key,
    revision: revision,
    values: {
      'Scheduled tasks': '${tasks.length}',
      'Completed': '$completed',
      'Pending': '${tasks.length - completed}',
      'High-priority pending': '$high',
      'Completion': tasks.isEmpty
          ? 'No tasks'
          : '${(completed / tasks.length * 100).toStringAsFixed(0)}%',
      'Task deadlines': 'Not recorded by the current planner. Scheduled starts are not deadlines.',
    },
    summary: AiSafeSummary({
      AiContextField.subject: report
          ? AiContextValue.report
          : AiContextValue.planner,
      AiContextField.workload: tasks.isEmpty
          ? AiContextValue.noTasks
          : tasks.length <= 3
          ? AiContextValue.light
          : tasks.length <= 8
          ? AiContextValue.moderate
          : AiContextValue.busy,
      AiContextField.completion: completed == 0
          ? AiContextValue.noneComplete
          : completed == tasks.length
          ? AiContextValue.allComplete
          : AiContextValue.someComplete,
      AiContextField.priority: high == 0
          ? AiContextValue.noHighPriority
          : AiContextValue.highPriorityPresent,
    }),
  );
}

/// Report balances remain separate by original currency; no invented FX/trends.
Map<String, String> aiReportBalances(List<(num, num, String)> goals) {
  final saved = <String, ExactDecimal>{}, targets = <String, ExactDecimal>{};
  for (final goal in goals) {
    saved[goal.$3] =
        (saved[goal.$3] ?? ExactDecimal.zero) + ExactDecimal.fromNum(goal.$1);
    targets[goal.$3] =
        (targets[goal.$3] ?? ExactDecimal.zero) + ExactDecimal.fromNum(goal.$2);
  }
  return {
    for (final code in saved.keys)
      '$code balance / target':
          '${formatCurrency(saved[code]!, code)} / ${formatCurrency(targets[code]!, code)}',
    'Savings period': 'Current personal balances, matching Reports. No historical growth data provided.',
  };
}
