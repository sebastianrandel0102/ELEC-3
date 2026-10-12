import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/smart_task_recommendation_service.dart';

void main() {
  final today = DateTime(2026, 10, 13);
  var now = DateTime(2026, 10, 13, 13, 30);
  late SmartTaskRecommendationService service;

  PlannerTask task(
    String id, {
    String priority = 'Normal',
    String time = '',
    bool completed = false,
    DateTime? date,
    DateTime? createdAt,
  }) => PlannerTask(
    id: id,
    title: id,
    dateKey: SmartTaskRecommendationService.dateKey(date ?? today),
    priority: priority,
    time: time,
    completed: completed,
    createdAt: createdAt,
  );

  SmartTaskPlan plan(List<PlannerTask> tasks, {DateTime? date}) =>
      service.recommend(tasks: tasks, selectedDate: date ?? today);

  List<String> ids(SmartTaskPlan result) =>
      result.recommendations.map((value) => value.taskId).toList();

  setUp(() {
    now = DateTime(2026, 10, 13, 13, 30);
    service = SmartTaskRecommendationService(clock: () => now);
  });

  test('unscheduled tasks use actual High, Normal, Low priorities', () {
    final result = plan([
      task('low', priority: 'Low'),
      task('normal'),
      task('high', priority: 'High'),
    ]);
    expect(ids(result), ['high', 'normal', 'low']);
    expect(result.first!.category, RecommendationCategory.flexible);
    expect(result.first!.isRecommendedNow, isTrue);
    expect(result.first!.schedule.start, isNull);
    expect(result.highPriorityRemaining, 1);
    expect(result.first!.explanation, contains('High priority'));
  });

  test(
    'low priority starting soon outranks flexible and high priority later',
    () {
      final result = plan([
        task('later', priority: 'High', time: '4:00 PM'),
        task('flexible', priority: 'High'),
        task('soon', priority: 'Low', time: '2:00 PM'),
      ]);
      expect(ids(result), ['soon', 'flexible', 'later']);
      expect(result.first!.category, RecommendationCategory.startingSoon);
      expect(result.first!.timeLabel, 'Starts in 30 minutes');
      expect(result.first!.isRecommendedNow, isFalse);
      expect(result.minutesBeforeNextSchedule, 30);
    },
  );

  test(
    'earliest imminent commitment wins before a higher priority later one',
    () {
      expect(
        ids(
          plan([
            task('second', time: '1:55 PM', priority: 'High'),
            task('first', time: '1:45 PM', priority: 'Low'),
          ]),
        ),
        ['first', 'second'],
      );
    },
  );

  test('current window wins, with actual conflict and priority ordering', () {
    final result = plan([
      task('low', priority: 'Low', time: '1:00 PM–2:00 PM'),
      task('high', priority: 'High', time: '1:15 PM–2:15 PM'),
      task('soon', time: '1:45 PM'),
    ]);
    expect(ids(result), ['high', 'low', 'soon']);
    expect(result.first!.category, RecommendationCategory.currentlyScheduled);
    expect(result.first!.conflictingTaskIds, ['low']);
    expect(result.first!.explanation, contains('choose which to follow'));
  });

  test('missed window needs attention without calling it a deadline', () {
    final result = plan([task('missed', time: '10:00 AM–11:00 AM')]);
    expect(result.first!.category, RecommendationCategory.needsAttention);
    expect(result.first!.timeLabel, 'Scheduled window passed');
    expect(result.first!.explanation, isNot(contains('overdue')));
  });

  test('past start with no end does not imply a missed window', () {
    final first = plan([task('start-only', time: '1:00 PM')]).first!;
    expect(first.category, RecommendationCategory.needsAttention);
    expect(first.schedule.end, isNull);
    expect(first.timeLabel, 'Scheduled start passed');
    expect(first.explanation, contains('No end time or deadline'));
  });

  test('completed high priority is excluded but counted in daily total', () {
    final result = plan([
      task('done', priority: 'High', completed: true),
      task('remaining'),
    ]);
    expect(ids(result), ['remaining']);
    expect(result.totalTasks, 2);
    expect(result.highPriorityRemaining, 0);
  });

  test('same priority uses creation timestamp then ID, never input order', () {
    final tasks = [
      task('z', createdAt: DateTime(2026, 10, 1)),
      task('a', createdAt: DateTime(2026, 10, 2)),
      task('legacy-b'),
      task('legacy-a'),
    ];
    expect(ids(plan(tasks)), ['z', 'a', 'legacy-a', 'legacy-b']);
    expect(ids(plan(tasks.reversed.toList())), ids(plan(tasks)));
  });

  test('same start uses priority and stable tie-breaking', () {
    expect(
      ids(
        plan([
          task('z', time: '2:00 PM'),
          task('b', time: '2:00 PM', priority: 'High'),
          task('a', time: '2:00 PM', priority: 'High'),
        ]),
      ),
      ['a', 'b', 'z'],
    );
  });

  test('empty and all completed plans have separate states', () {
    expect(plan([]).totalTasks, 0);
    expect(plan([]).allCompleted, isFalse);
    final result = plan([task('done', completed: true)]);
    expect(result.allCompleted, isTrue);
    expect(result.first, isNull);
    expect(result.remainingTasks, 0);
  });

  test('tomorrow plans by scheduled time without today clock claims', () {
    final tomorrow = DateTime(2026, 10, 14);
    final result = plan([
      task('high-later', priority: 'High', time: '4:00 PM', date: tomorrow),
      task('early', priority: 'Low', time: '9:00 AM', date: tomorrow),
      task('flexible', priority: 'High', date: tomorrow),
      task('today'),
    ], date: tomorrow);
    expect(result.day, RecommendationDay.future);
    expect(ids(result), ['early', 'high-later', 'flexible']);
    for (final recommendation in result.recommendations) {
      expect(recommendation.minutesUntilStart, isNull);
      expect(recommendation.isRecommendedNow, isFalse);
      expect(recommendation.timeLabel, isNot(contains('Starts in')));
    }
    expect(result.minutesBeforeNextSchedule, isNull);
  });

  test('yesterday is historical review, including unscheduled tasks', () {
    final yesterday = DateTime(2026, 10, 12);
    final result = plan([
      task('scheduled', time: '9:00 AM', date: yesterday),
      task('flexible', priority: 'High', date: yesterday),
    ], date: yesterday);
    expect(result.day, RecommendationDay.past);
    expect(result.first!.taskId, 'flexible');
    for (final recommendation in result.recommendations) {
      expect(recommendation.category, RecommendationCategory.needsAttention);
      expect(recommendation.isRecommendedNow, isFalse);
      expect(
        recommendation.explanation,
        contains('Unfinished on the selected day'),
      );
    }
  });

  test('today never includes yesterday or tomorrow', () {
    expect(
      ids(
        plan([
          task('today'),
          task('tomorrow', date: DateTime(2026, 10, 14)),
          task('yesterday', date: DateTime(2026, 10, 12)),
        ]),
      ),
      ['today'],
    );
  });

  test('just before start rounds up without claiming already started', () {
    now = DateTime(2026, 10, 13, 13, 59, 59);
    final first = plan([task('task', time: '2:00 PM')]).first!;
    expect(first.minutesUntilStart, 1);
    expect(first.timeLabel, 'Starts in 1 minute');
    expect(first.category, RecommendationCategory.startingSoon);
  });

  test('exact start is current, exact end needs review (half-open window)', () {
    final tasks = [task('task', time: '2:00 PM–3:00 PM')];
    now = DateTime(2026, 10, 13, 14);
    expect(
      plan(tasks).first!.category,
      RecommendationCategory.currentlyScheduled,
    );
    now = DateTime(2026, 10, 13, 15);
    expect(plan(tasks).first!.category, RecommendationCategory.needsAttention);
  });

  test(
    'start-only is now in the start minute, later becomes needs attention',
    () {
      final tasks = [task('task', time: '2:00 PM')];
      now = DateTime(2026, 10, 13, 14, 0, 30);
      expect(
        plan(tasks).first!.category,
        RecommendationCategory.currentlyScheduled,
      );
      expect(plan(tasks).first!.schedule.end, isNull);
      now = DateTime(2026, 10, 13, 14, 1);
      expect(
        plan(tasks).first!.category,
        RecommendationCategory.needsAttention,
      );
    },
  );

  test('only later appointments remain upcoming without start-now claims', () {
    final result = plan([task('later', time: '4:00 PM', priority: 'High')]);
    expect(result.first!.category, RecommendationCategory.scheduledLater);
    expect(result.first!.isRecommendedNow, isFalse);
    expect(result.nextScheduledTask!.id, 'later');
  });

  test(
    'conflicts require actual windows; adjoining windows do not overlap',
    () {
      final result = plan([
        task('a', time: '14:00–15:00'),
        task('b', time: '14:30–15:30'),
        task('adjoining', time: '15:30–16:00'),
        task('start-only', time: '14:45'),
        task('flexible'),
        task('completed-window', time: '14:00–15:00', completed: true),
      ]);
      final byId = {
        for (final value in result.recommendations) value.taskId: value,
      };
      expect(byId['a']!.conflictingTaskIds, ['b']);
      expect(byId['b']!.conflictingTaskIds, ['a']);
      for (final id in ['adjoining', 'start-only', 'flexible']) {
        expect(byId[id]!.hasScheduleConflict, isFalse);
      }
    },
  );

  test('flexible tasks between appointments never invent duration or fit', () {
    now = DateTime(2026, 10, 13, 13);
    final result = plan([
      task('flexible', priority: 'High'),
      task('next', time: '14:30'),
      task('previous', time: '11:00–12:00', completed: true),
    ]);
    expect(result.first!.taskId, 'flexible');
    expect(result.minutesBeforeNextSchedule, 90);
    expect(result.first!.explanation, contains('duration is unknown'));
    expect(result.first!.explanation, isNot(contains('fits')));
  });

  test(
    'short gap selects preparation; a later explicit long window stays later',
    () {
      now = DateTime(2026, 10, 13, 13, 50);
      final result = plan([
        task('long-window', priority: 'High', time: '15:00–17:00'),
        task('next', priority: 'Low', time: '14:00–14:30'),
        task('unknown-duration', priority: 'High'),
      ]);
      expect(result.first!.taskId, 'next');
      expect(result.minutesBeforeNextSchedule, 10);
      // There is no estimated-duration field in SaveTrack's task records.
      expect(result.first!.explanation, contains('Prepare'));
    },
  );

  test('active activity does not imply flexible work is unblocked', () {
    final result = plan([
      task('current', time: '13:00–14:00'),
      task('flexible'),
    ]);
    expect(
      result.recommendations.last.explanation,
      contains('after your current'),
    );
  });

  test(
    'priority, completion, reopening, editing and deletion update the plan',
    () {
      expect(plan([task('a'), task('b', priority: 'High')]).first!.taskId, 'b');
      expect(
        plan([task('a', priority: 'High'), task('b', priority: 'Low')])
            .first!
            .taskId,
        'a',
      );
      expect(plan([task('a', completed: true), task('b')]).first!.taskId, 'b');
      expect(plan([task('a'), task('b')]).first!.taskId, 'a');
      expect(plan([task('a'), task('b', time: '13:45')]).first!.taskId, 'b');
      expect(plan([task('a')]).first!.taskId, 'a');
    },
  );

  test('midnight rollover changes today into historical review', () {
    now = DateTime(2026, 10, 13, 23, 59);
    final tasks = [task('last', time: '23:59')];
    expect(plan(tasks).day, RecommendationDay.today);
    now = DateTime(2026, 10, 14);
    expect(plan(tasks).day, RecommendationDay.past);
    expect(plan(tasks).first!.isRecommendedNow, isFalse);
    expect(plan(tasks, date: DateTime(2026, 10, 14)).recommendations, isEmpty);
  });

  test('UTC clock is converted to the device local date boundary', () {
    now = DateTime.utc(2026, 10, 13, 23, 59);
    final local = now.toLocal();
    final taskDate = DateTime(local.year, local.month, local.day);
    expect(
      plan([task('local', date: taskDate)], date: taskDate).day,
      RecommendationDay.today,
    );
    now = now.add(const Duration(minutes: 2));
    final nextLocal = now.toLocal();
    final nextDate = DateTime(nextLocal.year, nextLocal.month, nextLocal.day);
    expect(
      plan([task('local', date: nextDate)], date: nextDate).day,
      RecommendationDay.today,
    );
  });

  test('legacy data stays safe; invalid dates are not assigned to today', () {
    final legacy = PlannerTask.fromData('legacy', {'dateKey': '2026-10-13'});
    expect(legacy.priority, 'Normal');
    expect(legacy.title, 'Untitled task');
    expect(plan([legacy]).first!.category, RecommendationCategory.flexible);
    expect(
      plan([
        PlannerTask.fromData('missing-date', {}),
        PlannerTask.fromData('invalid-date', {'dateKey': '2026-02-30'}),
      ]).recommendations,
      isEmpty,
    );
    final invalid = PlannerTask.fromData('bad-time', {
      'dateKey': '2026-10-13',
      'time': 999,
    });
    expect(plan([invalid]).first!.category, RecommendationCategory.reviewTime);
  });

  test(
    'invalid free-text time is explicitly reviewable, never a false time',
    () {
      for (final time in [
        'after lunch',
        '25:00',
        '2–3 PM',
        '9:60 AM',
        '0 AM',
        '23:00–01:00',
        '12:00–12:00',
      ]) {
        final first = plan([task('invalid', time: time)]).first!;
        expect(first.category, RecommendationCategory.reviewTime, reason: time);
        expect(first.schedule.start, isNull);
        expect(first.isRecommendedNow, isFalse);
        expect(first.hasScheduleConflict, isFalse);
      }
    },
  );

  test('explicit supported formats parse exactly without hidden durations', () {
    for (final time in ['2 PM', '2:00 pm', '14:00']) {
      final schedule = SmartTaskRecommendationService.parseSchedule(
        time,
        today,
      );
      expect(schedule.start, DateTime(2026, 10, 13, 14));
      expect(schedule.end, isNull);
    }
    for (final time in [
      '2 PM - 3 PM',
      '14:00–15:00',
      '2:00 PM to 3:00 PM',
      '2:00 PM—3:00 PM',
    ]) {
      final schedule = SmartTaskRecommendationService.parseSchedule(
        time,
        today,
      );
      expect(schedule.start, DateTime(2026, 10, 13, 14));
      expect(schedule.end, DateTime(2026, 10, 13, 15));
    }
    expect(
      SmartTaskRecommendationService.parseSchedule('12 AM', today).start!.hour,
      0,
    );
    expect(
      SmartTaskRecommendationService.parseSchedule('12 PM', today).start!.hour,
      12,
    );
  });

  test('configurable threshold uses exact duration boundaries', () {
    service = SmartTaskRecommendationService(
      clock: () => now,
      startingSoonThreshold: const Duration(minutes: 10),
    );
    expect(
      plan([task('task', time: '13:40')]).first!.category,
      RecommendationCategory.startingSoon,
    );
    now = DateTime(2026, 10, 13, 13, 29, 59);
    expect(
      plan([task('task', time: '13:40')]).first!.category,
      RecommendationCategory.scheduledLater,
    );
  });

  test(
    'large task lists keep stable ranks without mutating source records',
    () {
      final tasks = List.generate(
        5000,
        (index) => task(
          'task-${index.toString().padLeft(5, '0')}',
          priority: index.isEven ? 'High' : 'Normal',
        ),
      );
      final originalIds = tasks.map((value) => value.id).toList();
      final result = plan(tasks);
      expect(result.remainingTasks, 5000);
      expect(result.highPriorityRemaining, 2500);
      expect(result.recommendations.last.rank, 5000);
      expect(tasks.map((value) => value.id), originalIds);
      expect(ids(plan(tasks.reversed.toList())), ids(result));
    },
  );

  test('duplicate IDs do not produce duplicate recommendations', () {
    expect(plan([task('same'), task('same')]).remainingTasks, 1);
  });

  test(
    'mixed historical timing and creation factors form a stable total order',
    () {
      final past = DateTime(2026, 10, 12);
      final a = task(
        'a',
        date: past,
        time: '09:00',
        createdAt: DateTime(2026, 10, 3),
      );
      final b = task('b', date: past, createdAt: DateTime(2026, 10, 2));
      final c = task(
        'c',
        date: past,
        time: '10:00',
        createdAt: DateTime(2026, 10, 1),
      );
      for (final permutation in [
        [a, b, c],
        [a, c, b],
        [b, a, c],
        [b, c, a],
        [c, a, b],
        [c, b, a],
      ]) {
        expect(ids(plan(permutation, date: past)), ['a', 'c', 'b']);
      }
    },
  );
}
