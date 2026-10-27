import '../currency_money.dart';
import '../smart_task_recommendation_service.dart';

enum HomeWidgetType { goal, planner, quickSave, today }

enum WidgetPrivacy { full, progress, hidden }

enum WidgetTheme { emerald, mint, white, system }

bool validWidgetReference(String value) =>
    value.isNotEmpty &&
    value.length <= 128 &&
    !value.contains('/') &&
    !RegExp(r'[\x00-\x1f]').hasMatch(value);

class WidgetGoalRef {
  const WidgetGoalRef(this.id, {this.shared = false});
  final String id;
  final bool shared;
  String get key => '${shared ? 'shared' : 'personal'}/$id';
  Map<String, dynamic> toMap() => {'id': id, 'shared': shared};
  factory WidgetGoalRef.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || !validWidgetReference(id) || map['shared'] is! bool) {
      throw const FormatException('Invalid widget goal.');
    }
    return WidgetGoalRef(id, shared: map['shared'] as bool);
  }
}

class HomeWidgetConfig {
  const HomeWidgetConfig({
    required this.id,
    required this.type,
    required this.uid,
    this.goal,
    this.theme = WidgetTheme.emerald,
    this.privacy = WidgetPrivacy.progress,
    this.showTaskTitles = false,
    this.showCover = false,
    this.presets = const [],
    this.currency,
    this.revision = 0,
  });
  final int id, revision;
  final HomeWidgetType type;
  final String uid;
  final WidgetGoalRef? goal;
  final WidgetTheme theme;
  final WidgetPrivacy privacy;
  final bool showTaskTitles, showCover;
  // Exact major-unit decimal strings, validated by the existing money parser.
  final List<String> presets;
  final String? currency;
  bool get needsGoal => type != HomeWidgetType.planner;
  bool get needsPlanner =>
      type == HomeWidgetType.planner || type == HomeWidgetType.today;
  void validate() {
    if (id <= 0 ||
        uid.isEmpty ||
        revision < 0 ||
        (needsGoal && goal == null) ||
        (goal != null && !validWidgetReference(goal!.id)) ||
        presets.length > 3) {
      throw const FormatException('Choose an available goal for this widget.');
    }
    if (goal != null && !CurrencyCatalog.byCode.containsKey(currency)) {
      throw const FormatException('Goal currency is unavailable.');
    }
    for (final text in presets) {
      final value = parseCurrencyAmount(text, currency ?? '');
      if (value == null || !value.positive) {
        throw const FormatException(
          'Shortcuts must be positive amounts in the goal currency.',
        );
      }
    }
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'id': id,
    'type': type.name,
    'uid': uid,
    'goal': goal?.toMap(),
    'theme': theme.name,
    'privacy': privacy.name,
    'showTaskTitles': showTaskTitles,
    'showCover': showCover,
    'presets': presets,
    'currency': currency,
    'revision': revision,
  };
  factory HomeWidgetConfig.fromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != 1) {
      throw const FormatException('Widget needs setup.');
    }
    final config = HomeWidgetConfig(
      id: map['id'] as int,
      type: HomeWidgetType.values.byName(map['type'] as String),
      uid: map['uid'] as String,
      goal: map['goal'] == null
          ? null
          : WidgetGoalRef.fromMap(
              Map<String, dynamic>.from(map['goal'] as Map),
            ),
      theme: WidgetTheme.values.byName(map['theme'] as String),
      privacy: WidgetPrivacy.values.byName(map['privacy'] as String),
      showTaskTitles: map['showTaskTitles'] == true,
      showCover: map['showCover'] == true,
      presets: List<String>.from(map['presets'] as List? ?? []),
      currency: map['currency'] as String?,
      revision: map['revision'] as int? ?? 0,
    );
    config.validate();
    return config;
  }
}

class HomeWidgetInstance {
  const HomeWidgetInstance(this.id, this.type, this.config);
  final int id;
  final HomeWidgetType type;
  final HomeWidgetConfig? config;
}

class WidgetGoalFacts {
  const WidgetGoalFacts({
    required this.ref,
    required this.title,
    required this.saved,
    required this.target,
    required this.currency,
    this.deadline,
    this.archived = false,
    this.coverPath,
    this.coverOwner,
    this.cached = false,
    this.confirmedAt,
  });
  final WidgetGoalRef ref;
  final String title, currency;
  final ExactDecimal saved, target;
  final DateTime? deadline, confirmedAt;
  final bool archived, cached;
  final String? coverPath, coverOwner;
  // Match GoalCard and SharedSavingsGoal: progress is visually capped at 100%.
  double get progress =>
      !target.positive ? 0 : (saved / target).toDouble().clamp(0, 1);
  ExactDecimal get remaining {
    final difference = target - saved;
    return difference.positive ? difference : ExactDecimal.zero;
  }

  bool get valid =>
      saved.compareTo(ExactDecimal.zero) >= 0 &&
      target.compareTo(ExactDecimal.zero) >= 0 &&
      CurrencyCatalog.byCode.containsKey(currency);
}

class WidgetPlannerFacts {
  const WidgetPlannerFacts(
    this.tasks,
    this.day, {
    this.cached = false,
    this.confirmedAt,
  });
  final List<PlannerTask> tasks;
  final String day;
  final bool cached;
  final DateTime? confirmedAt;
}

/// Versioned, cohesive display payload. Privacy is applied before serialization.
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot(this.data);
  final Map<String, dynamic> data;
  static HomeWidgetSnapshot build({
    required HomeWidgetConfig config,
    required DateTime now,
    WidgetGoalFacts? goal,
    WidgetPlannerFacts? planner,
  }) {
    final hidden = config.privacy == WidgetPrivacy.hidden;
    final full = config.privacy == WidgetPrivacy.full;
    final today = SmartTaskRecommendationService.dateKey(now);
    final validGoal =
        goal != null && goal.valid && goal.ref.key == config.goal?.key;
    final validPlanner = planner != null && planner.day == today;
    final data = <String, dynamic>{
      'schemaVersion': 1,
      'id': config.id,
      'type': config.type.name,
      'uid': config.uid,
      'revision': config.revision,
      'privacy': config.privacy.name,
      'updatedAt': now.millisecondsSinceEpoch,
      'day': today,
      'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'state': hidden
          ? 'hidden'
          : config.needsGoal && !validGoal
          ? 'unavailable'
          : 'ready',
      'cached':
          (config.needsGoal && goal?.cached == true) ||
          (config.needsPlanner && planner?.cached == true),
    };
    if (hidden) return HomeWidgetSnapshot(data);
    if (validGoal) {
      final deadline = goal.deadline;
      final overdue =
          deadline != null &&
          DateTime(
            deadline.year,
            deadline.month,
            deadline.day,
          ).isBefore(DateTime(now.year, now.month, now.day));
      data['goal'] = {
        'title': full ? goal.title : 'Savings goal',
        'percent': (goal.progress * 100).round(),
        'progress': (goal.progress * 1000).round(),
        'status': goal.archived
            ? 'Archived'
            : goal.progress >= 1
            ? 'Completed'
            : overdue
            ? 'Overdue'
            : 'Active',
        'canSave': !goal.archived && goal.currency == config.currency,
        if (full) ...{
          'saved': formatCurrency(goal.saved, goal.currency),
          'target': formatCurrency(goal.target, goal.currency),
          'remaining': formatCurrency(goal.remaining, goal.currency),
          'currency': goal.currency,
          'currencyDigits': CurrencyCatalog.require(goal.currency).digits,
          if (deadline != null)
            'deadline': SmartTaskRecommendationService.dateKey(deadline),
          'presets': [
            if (goal.currency == config.currency)
              for (final preset in config.presets)
                if (parseCurrencyAmount(preset, goal.currency)
                    case final amount?)
                  formatCurrency(amount, goal.currency),
          ],
        },
      };
    }
    if (config.needsPlanner) {
      if (!validPlanner) {
        data['planner'] = {'state': 'refresh'};
      } else {
        final tasks = planner.tasks.where((t) => t.dateKey == today).toList();
        final plan = SmartTaskRecommendationService(clock: () => now)
            .recommend(tasks: tasks, selectedDate: now);
        final done = tasks.where((t) => t.completed).length;
        data['planner'] = {
          'state': 'ready',
          'done': done,
          'total': tasks.length,
          'remaining': tasks.length - done,
          'progress': tasks.isEmpty ? 0 : (done / tasks.length * 1000).round(),
          'tasks': [
            if (full && config.showTaskTitles)
              for (final item in plan.recommendations.take(5))
                {
                  'id': item.task.id,
                  'title': item.task.title,
                  'priority': item.task.priority,
                  'time': item.timeLabel,
                },
          ],
        };
      }
    }
    final confirmed = <DateTime>[
      if (config.needsGoal && goal?.confirmedAt != null) goal!.confirmedAt!,
      if (config.needsPlanner && planner?.confirmedAt != null)
        planner!.confirmedAt!,
    ]..sort();
    if (confirmed.isNotEmpty) {
      data['confirmedAt'] = confirmed.first.millisecondsSinceEpoch;
    }
    return HomeWidgetSnapshot(data);
  }
}

enum WidgetLaunchAction {
  configure,
  goal,
  save,
  planner,
  task,
  dashboard,
  coach,
}

class WidgetLaunch {
  const WidgetLaunch(
    this.id,
    this.action, {
    this.preset,
    this.taskId,
    this.launcher = false,
  });
  final int id;
  final WidgetLaunchAction action;
  final int? preset;
  final String? taskId;
  final bool launcher;
  static WidgetLaunch? parse(dynamic raw) {
    try {
      final map = Map<String, dynamic>.from(raw as Map);
      final id = map['id'];
      if (id is! int || id <= 0) return null;
      final action = WidgetLaunchAction.values.byName(map['action'] as String);
      final preset = map['preset'];
      final taskId = map['taskId'];
      if (preset != null && (preset is! int || preset < 0 || preset > 2)) {
        return null;
      }
      if (taskId != null &&
          (taskId is! String || !validWidgetReference(taskId))) {
        return null;
      }
      if (action == WidgetLaunchAction.task && taskId == null) return null;
      return WidgetLaunch(
        id,
        action,
        preset: preset as int?,
        taskId: taskId as String?,
        launcher: map['launcher'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
