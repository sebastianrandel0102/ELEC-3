/// Read-only planner data. No recommendation fields are persisted to Firestore.
class PlannerTask {
  const PlannerTask({
    required this.id,
    required this.dateKey,
    required this.title,
    this.priority = 'Normal',
    this.time = '',
    this.completed = false,
    this.createdAt,
  });

  factory PlannerTask.fromData(
    String id,
    Map<String, dynamic> data, {
    DateTime? createdAt,
  }) => PlannerTask(
    id: id,
    dateKey: data['dateKey'] is String ? data['dateKey'] as String : '',
    title:
        data['title'] is String && (data['title'] as String).trim().isNotEmpty
        ? (data['title'] as String).trim()
        : 'Untitled task',
    priority: data['priority'] is String
        ? data['priority'] as String
        : 'Normal',
    time: data['time'] == null ? '' : data['time'].toString(),
    completed: data['completed'] == true,
    createdAt: createdAt,
  );

  final String id, dateKey, title, priority, time;
  final bool completed;
  final DateTime? createdAt;

  int get priorityWeight => switch (priority) {
    'High' => 3,
    'Low' => 1,
    _ => 2,
  };
}

enum RecommendationDay { today, future, past }

enum RecommendationCategory {
  currentlyScheduled,
  startingSoon,
  needsAttention,
  flexible,
  scheduledLater,
  reviewTime,
}

/// A start time never implies an end time or a deadline.
class TaskSchedule {
  const TaskSchedule({this.start, this.end, this.invalid = false});
  final DateTime? start, end;
  final bool invalid;
  bool get hasWindow => start != null && end != null;
}

class TaskRecommendation {
  const TaskRecommendation({
    required this.task,
    required this.rank,
    required this.category,
    required this.explanation,
    required this.timeLabel,
    required this.schedule,
    required this.isRecommendedNow,
    required this.conflictingTaskIds,
    this.minutesUntilStart,
  });

  final PlannerTask task;
  String get taskId => task.id;
  final int rank;
  final RecommendationCategory category;
  final String explanation, timeLabel;
  final TaskSchedule schedule;
  final bool isRecommendedNow;
  final int? minutesUntilStart;
  final List<String> conflictingTaskIds;
  bool get hasScheduleConflict => conflictingTaskIds.isNotEmpty;
}

class SmartTaskPlan {
  const SmartTaskPlan({
    required this.day,
    required this.totalTasks,
    required this.highPriorityRemaining,
    required this.recommendations,
    this.nextScheduledTask,
    this.nextScheduledStart,
    this.minutesBeforeNextSchedule,
  });

  final RecommendationDay day;
  final int totalTasks, highPriorityRemaining;
  final List<TaskRecommendation> recommendations;
  final PlannerTask? nextScheduledTask;
  final DateTime? nextScheduledStart;
  final int? minutesBeforeNextSchedule;
  int get remainingTasks => recommendations.length;
  bool get allCompleted => totalTasks > 0 && recommendations.isEmpty;
  TaskRecommendation? get first =>
      recommendations.isEmpty ? null : recommendations.first;
}

/// Deterministic local rules using the existing dateKey, time, priority,
/// completed and createdAt fields. The clock is injectable for fixed-time tests.
class SmartTaskRecommendationService {
  SmartTaskRecommendationService({
    DateTime Function()? clock,
    this.startingSoonThreshold = const Duration(minutes: 30),
  }) : clock = clock ?? DateTime.now {
    if (startingSoonThreshold.isNegative) {
      throw ArgumentError.value(startingSoonThreshold, 'startingSoonThreshold');
    }
  }

  final DateTime Function() clock;
  final Duration startingSoonThreshold;

  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime? parseDateKey(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final parsed = DateTime.tryParse(value);
    return parsed != null && dateKey(parsed) == value ? parsed : null;
  }

  /// Accept unambiguous 12h/24h times and explicit same-day ranges in the
  /// existing free-text field. Never infer a missing AM/PM suffix in a range.
  static TaskSchedule parseSchedule(String value, DateTime day) {
    if (value.trim().isEmpty) return const TaskSchedule();
    final parts = value.trim().split(
      RegExp(r'\s*(?:-|–|—|\bto\b)\s*', caseSensitive: false),
    );
    if (parts.length > 2) return const TaskSchedule(invalid: true);
    DateTime? parseTime(String text) {
      final match = RegExp(
        r'^(\d{1,2})(?::(\d{2}))?\s*([ap]m)?$',
        caseSensitive: false,
      ).firstMatch(text.trim());
      if (match == null) return null;
      var hour = int.parse(match[1]!);
      final minute = int.parse(match[2] ?? '0');
      final suffix = match[3]?.toLowerCase();
      if (minute > 59) return null;
      if (suffix != null) {
        if (hour < 1 || hour > 12) return null;
        hour = hour % 12 + (suffix == 'pm' ? 12 : 0);
      } else if (match[2] == null || hour > 23) {
        return null;
      }
      final result = DateTime(day.year, day.month, day.day, hour, minute);
      // Local DST gaps must not silently move an explicitly scheduled time.
      return result.hour == hour && result.minute == minute ? result : null;
    }

    final start = parseTime(parts.first);
    final end = parts.length == 2 ? parseTime(parts.last) : null;
    if (start == null ||
        (parts.length == 2 && (end == null || !end.isAfter(start)))) {
      return const TaskSchedule(invalid: true);
    }
    return TaskSchedule(start: start, end: end);
  }

  SmartTaskPlan recommend({
    required Iterable<PlannerTask> tasks,
    required DateTime selectedDate,
  }) {
    final now = clock().toLocal();
    final selectedKey = dateKey(selectedDate);
    final todayKey = dateKey(now);
    final day = selectedKey == todayKey
        ? RecommendationDay.today
        : selectedKey.compareTo(todayKey) > 0
        ? RecommendationDay.future
        : RecommendationDay.past;
    final seen = <String>{};
    final selected = tasks
        .where(
          (task) =>
              task.id.isNotEmpty &&
              task.dateKey == selectedKey &&
              parseDateKey(task.dateKey) != null &&
              seen.add(task.id),
        )
        .toList();
    final pending = selected.where((task) => !task.completed).toList();
    final schedules = {
      for (final task in pending)
        task.id: parseSchedule(task.time, selectedDate),
    };
    final upcoming =
        pending.where((task) {
          final start = schedules[task.id]!.start;
          return start != null && start.isAfter(now);
        }).toList()..sort((a, b) {
          final time = schedules[a.id]!.start!.compareTo(
            schedules[b.id]!.start!,
          );
          return time != 0 ? time : _priorityAndStableOrder(a, b);
        });
    final next = day == RecommendationDay.today && upcoming.isNotEmpty
        ? upcoming.first
        : null;
    final nextStart = next == null ? null : schedules[next.id]!.start;
    final availableMinutes = nextStart == null
        ? null
        : _minutesUntil(nextStart, now);
    final conflicts = _findConflicts(pending, schedules);
    RecommendationCategory category(PlannerTask task) {
      final schedule = schedules[task.id]!;
      if (day == RecommendationDay.past) {
        return RecommendationCategory.needsAttention;
      }
      if (schedule.invalid) return RecommendationCategory.reviewTime;
      final start = schedule.start;
      if (start == null) return RecommendationCategory.flexible;
      if (day == RecommendationDay.future) {
        return RecommendationCategory.scheduledLater;
      }
      if (!now.isBefore(start)) {
        if (schedule.end != null && now.isBefore(schedule.end!)) {
          return RecommendationCategory.currentlyScheduled;
        }
        if (schedule.end == null &&
            now.hour == start.hour &&
            now.minute == start.minute) {
          return RecommendationCategory.currentlyScheduled;
        }
        return RecommendationCategory.needsAttention;
      }
      return start.difference(now) <= startingSoonThreshold
          ? RecommendationCategory.startingSoon
          : RecommendationCategory.scheduledLater;
    }

    final categories = {for (final task in pending) task.id: category(task)};
    final hasCurrentActivity = categories.values.contains(
      RecommendationCategory.currentlyScheduled,
    );
    int categoryOrder(RecommendationCategory value) {
      if (day == RecommendationDay.future) {
        return switch (value) {
          RecommendationCategory.scheduledLater => 0,
          RecommendationCategory.flexible => 1,
          _ => 2,
        };
      }
      return switch (value) {
        RecommendationCategory.currentlyScheduled => 0,
        RecommendationCategory.startingSoon => 1,
        RecommendationCategory.needsAttention => 2,
        RecommendationCategory.flexible => 3,
        RecommendationCategory.scheduledLater => 4,
        RecommendationCategory.reviewTime => 5,
      };
    }

    pending.sort((a, b) {
      final categoryA = categories[a.id]!;
      final categoryB = categories[b.id]!;
      final group = categoryOrder(categoryA)
          .compareTo(categoryOrder(categoryB));
      if (group != 0) return group;
      // Fixed commitments stay chronological. Priority breaks equal starts.
      if (categoryA == RecommendationCategory.startingSoon ||
          categoryA == RecommendationCategory.scheduledLater) {
        final time = schedules[a.id]!.start!.compareTo(schedules[b.id]!.start!);
        if (time != 0) return time;
      }
      final priority = b.priorityWeight.compareTo(a.priorityWeight);
      if (priority != 0) return priority;
      final startA = schedules[a.id]!.start;
      final startB = schedules[b.id]!.start;
      if (startA != null && startB != null) {
        final time = startA.compareTo(startB);
        if (time != 0) return time;
      } else if (startA != null || startB != null) {
        // Include missing starts in a total order, including historical tasks.
        return startA != null ? -1 : 1;
      }
      return _stableOrder(a, b);
    });

    final recommendations = <TaskRecommendation>[];
    for (var index = 0; index < pending.length; index++) {
      final task = pending[index];
      final schedule = schedules[task.id]!;
      final value = categories[task.id]!;
      final minutes =
          day == RecommendationDay.today &&
              schedule.start != null &&
              schedule.start!.isAfter(now)
          ? _minutesUntil(schedule.start!, now)
          : null;
      final String explanation;
      final String timeLabel;
      if (day == RecommendationDay.past) {
        explanation = 'Unfinished on the selected day. Review its plan before choosing what to do.';
        timeLabel = 'Past day · review unfinished task';
      } else if (day == RecommendationDay.future) {
        explanation = schedule.invalid
            ? 'Review the recorded time; it could not be read as a same-day schedule.'
            : schedule.start != null
            ? 'Ordered by this day’s scheduled start; priority breaks equal start times.'
            : '${_priorityLabel(task)} Flexible work after fixed commitments.';
        timeLabel = schedule.invalid
            ? 'Time needs review'
            : 'Plan for selected day';
      } else {
        switch (value) {
          case RecommendationCategory.currentlyScheduled:
            explanation = schedule.hasWindow
                ? 'Your current scheduled activity. Priority orders simultaneous activities.'
                : 'Its scheduled start is now. No end time is recorded.';
            timeLabel = schedule.hasWindow
                ? 'In your scheduled window'
                : 'Scheduled for now';
          case RecommendationCategory.startingSoon:
            explanation = next?.id == task.id
                ? 'Your next scheduled activity is approaching. Prepare for it before starting other work.'
                : 'A scheduled activity is approaching. Keep this commitment in mind after the earlier schedule.';
            timeLabel =
                'Starts in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
          case RecommendationCategory.needsAttention:
            explanation = schedule.hasWindow
                ? 'This task’s scheduled window has already passed. Review it before your next commitment.'
                : 'Its scheduled start has passed. No end time or deadline is recorded.';
            timeLabel = schedule.hasWindow
                ? 'Scheduled window passed'
                : 'Scheduled start passed';
          case RecommendationCategory.flexible:
            explanation = hasCurrentActivity
                ? '${_priorityLabel(task)} Consider this flexible work after your current scheduled activity; duration is unknown.'
                : availableMinutes != null
                ? '${_priorityLabel(task)} You have $availableMinutes minutes before your next scheduled task; duration is unknown.'
                : '${_priorityLabel(task)} No upcoming scheduled tasks are blocking this.';
            timeLabel = 'No scheduled time';
          case RecommendationCategory.scheduledLater:
            explanation = 'A later commitment. Keep its scheduled time in mind when choosing other work.';
            timeLabel = 'Starts in $minutes minutes';
          case RecommendationCategory.reviewTime:
            explanation = 'Review the recorded time; it could not be read as a same-day schedule.';
            timeLabel = 'Time needs review';
        }
      }
      final taskConflicts = conflicts[task.id] ?? const <String>[];
      recommendations.add(
        TaskRecommendation(
          task: task,
          rank: index + 1,
          category: value,
          explanation: taskConflicts.isEmpty
              ? explanation
              : '$explanation Its schedule overlaps another unfinished task; choose which to follow.',
          timeLabel: timeLabel,
          schedule: schedule,
          minutesUntilStart: minutes,
          isRecommendedNow:
              index == 0 &&
              day == RecommendationDay.today &&
              (value == RecommendationCategory.currentlyScheduled ||
                  value == RecommendationCategory.flexible),
          conflictingTaskIds: List.unmodifiable(taskConflicts),
        ),
      );
    }
    return SmartTaskPlan(
      day: day,
      totalTasks: selected.length,
      highPriorityRemaining: pending
          .where((task) => task.priority == 'High')
          .length,
      recommendations: List.unmodifiable(recommendations),
      nextScheduledTask: next,
      nextScheduledStart: nextStart,
      minutesBeforeNextSchedule: availableMinutes,
    );
  }

  static int _minutesUntil(DateTime start, DateTime now) =>
      (start.difference(now).inMicroseconds / Duration.microsecondsPerMinute)
          .ceil();

  static String _priorityLabel(PlannerTask task) =>
      ['High', 'Normal', 'Low'].contains(task.priority)
      ? '${task.priority} priority.'
      : 'Priority is unspecified.';

  static int _priorityAndStableOrder(PlannerTask a, PlannerTask b) {
    final priority = b.priorityWeight.compareTo(a.priorityWeight);
    return priority != 0 ? priority : _stableOrder(a, b);
  }

  // Firestore's iteration order is never used as a ranking factor. Existing
  // creation timestamps supply stable order; legacy records fall back to ID.
  static int _stableOrder(PlannerTask a, PlannerTask b) {
    if (a.createdAt != null && b.createdAt != null) {
      final result = a.createdAt!.compareTo(b.createdAt!);
      if (result != 0) return result;
    } else if (a.createdAt != null || b.createdAt != null) {
      return a.createdAt != null ? -1 : 1;
    }
    return a.id.compareTo(b.id);
  }

  static Map<String, List<String>> _findConflicts(
    List<PlannerTask> tasks,
    Map<String, TaskSchedule> schedules,
  ) {
    final windows =
        tasks.where((task) => schedules[task.id]!.hasWindow).toList()
          ..sort((a, b) {
            final time = schedules[a.id]!.start!.compareTo(
              schedules[b.id]!.start!,
            );
            return time != 0 ? time : a.id.compareTo(b.id);
          });
    final active = <PlannerTask>[];
    final conflicts = <String, List<String>>{};
    for (final task in windows) {
      final start = schedules[task.id]!.start!;
      active.removeWhere((other) => !schedules[other.id]!.end!.isAfter(start));
      for (final other in active) {
        (conflicts[task.id] ??= []).add(other.id);
        (conflicts[other.id] ??= []).add(task.id);
      }
      active.add(task);
    }
    for (final ids in conflicts.values) {
      ids.sort();
    }
    return conflicts;
  }
}
