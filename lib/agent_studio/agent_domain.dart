import 'dart:convert';
import 'dart:math';

import '../currency_money.dart';
import 'autopilot/autopilot_settings.dart';

abstract final class AgentLimits {
  static const steps = 12;
  static const tasks = 6;
  static const reminders = 3;
  static const input = 3000;
  static const attempts = 3;
  static const approvalLifetime = Duration(minutes: 10);
  static const requestTimeout = Duration(seconds: 45);
}

String agentId() => List.generate(
  20,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
String agentDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

enum AgentActionType {
  createGoal,
  createTask,
  createReminder,
  contribution,
  scenario,
  allocation,
}

enum MissionStatus {
  draft,
  needsClarification,
  readyForReview,
  approved,
  executing,
  partiallyCompleted,
  completed,
  failed,
  canceled,
}

enum StepStatus { waiting, executing, completed, failed, blocked, canceled }

enum AgentPermission {
  createGoal,
  createTask,
  createReminder,
  contribution,
  privateContext,
}

enum AgentLanguage { automatic, english, filipino, taglish }

class AgentFailure implements Exception {
  const AgentFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// No permissions or approval fields are accepted from a planner/model.
sealed class AgentAction {
  const AgentAction();
  AgentActionType get type;
  AgentPermission? get permission;
  Map<String, Object?> toJson();
  List<String> validate(DateTime now);
  String get label;
  String get summary;

  static AgentAction fromJson(Map<String, dynamic> map) {
    final type = AgentActionType.values.byName(map['type'] as String);
    final allowed = switch (type) {
      AgentActionType.createGoal => {
        'type',
        'name',
        'amount',
        'currency',
        'deadline',
      },
      AgentActionType.createTask => {
        'type',
        'title',
        'day',
        'time',
        'priority',
      },
      AgentActionType.createReminder => {
        'type',
        'title',
        'targetId',
        'targetStep',
        'targetKind',
        'frequency',
        'weekday',
        'time',
        'day',
      },
      AgentActionType.contribution => {'type', 'goalId', 'amount', 'currency'},
      AgentActionType.scenario => {
        'type',
        'title',
        'frequency',
        'target',
        'saved',
        'contribution',
        'currency',
        'deadline',
      },
      AgentActionType.allocation => {'type', 'budget', 'currency'},
    };
    if (map.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Unknown action field');
    }
    DateTime? date(String key) =>
        map[key] == null ? null : DateTime.parse(map[key] as String);
    String text(String key) => map[key] as String? ?? '';
    return switch (type) {
      AgentActionType.createGoal => GoalDraft(
        name: text('name'),
        amount: text('amount'),
        currency: text('currency'),
        deadline: date('deadline'),
      ),
      AgentActionType.createTask => TaskDraft(
        title: text('title'),
        day: date('day'),
        time: text('time'),
        priority: text('priority'),
      ),
      AgentActionType.createReminder => ReminderDraft(
        title: text('title'),
        targetId: text('targetId'),
        targetStep: text('targetStep'),
        targetKind: text('targetKind'),
        frequency: text('frequency'),
        weekday: map['weekday'] as int?,
        time: text('time'),
        day: date('day'),
      ),
      AgentActionType.contribution => ContributionDraft(
        goalId: text('goalId'),
        amount: text('amount'),
        currency: text('currency'),
      ),
      AgentActionType.scenario => ScenarioDraft(
        title: text('title'),
        frequency: map['frequency'] as String? ?? 'weekly',
        target: text('target'),
        saved: text('saved'),
        contribution: text('contribution'),
        currency: text('currency'),
        deadline: date('deadline'),
      ),
      AgentActionType.allocation => AllocationDraft(
        budget: text('budget'),
        currency: text('currency'),
      ),
    };
  }
}

List<String> _moneyErrors(String amount, String currency) =>
    parseCurrencyAmount(amount, currency)?.positive == true
    ? []
    : ['Enter a positive amount in a supported currency.'];
bool _short(String value) =>
    value.trim().isNotEmpty &&
    value.length <= 100 &&
    !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);
bool agentRecordId(String id) => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id);
bool agentTime(String value) =>
    RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

String agentMoney(String amount, String currency) {
  final parsed = parseCurrencyAmount(amount, currency);
  return parsed == null
      ? '$currency $amount'.trim()
      : formatCurrency(parsed, currency);
}

final class GoalDraft extends AgentAction {
  const GoalDraft({
    this.name = '',
    this.amount = '',
    this.currency = '',
    this.deadline,
  });
  final String name, amount, currency;
  final DateTime? deadline;
  @override
  AgentActionType get type => AgentActionType.createGoal;
  @override
  AgentPermission get permission => AgentPermission.createGoal;
  @override
  String get label => 'Create savings goal';
  @override
  String get summary =>
      '$name · ${agentMoney(amount, currency)} · ${deadline == null ? 'Deadline needed' : agentDay(deadline!)}';
  @override
  List<String> validate(DateTime now) => [
    if (!_short(name)) 'Enter a goal name (up to 100 characters).',
    ..._moneyErrors(amount, currency),
    if (deadline == null ||
        deadline!.isBefore(DateTime(now.year, now.month, now.day)))
      'Choose a current or future deadline.',
  ];
  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'name': name,
    'amount': amount,
    'currency': currency,
    'deadline': deadline?.toIso8601String(),
  };
}

final class TaskDraft extends AgentAction {
  const TaskDraft({
    this.title = '',
    this.day,
    this.time = '',
    this.priority = 'Normal',
  });
  final String title, time, priority;
  final DateTime? day;
  @override
  AgentActionType get type => AgentActionType.createTask;
  @override
  AgentPermission get permission => AgentPermission.createTask;
  @override
  String get label => 'Create Planner task';
  @override
  String get summary =>
      '$title · ${day == null ? 'Date needed' : agentDay(day!)} ${time.isEmpty ? '· Flexible time' : time} · $priority';
  @override
  List<String> validate(DateTime now) => [
    if (!_short(title)) 'Enter a task title (up to 100 characters).',
    if (day == null || day!.isBefore(DateTime(now.year, now.month, now.day)))
      'Choose a current or future task date.',
    if (time.isNotEmpty && !agentTime(time))
      'Use a 24-hour start time (HH:mm), or leave it flexible.',
    if (!['Low', 'Normal', 'High'].contains(priority))
      'Choose a supported priority.',
  ];
  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'title': title,
    'day': day?.toIso8601String(),
    'time': time,
    'priority': priority,
  };
}

final class ReminderDraft extends AgentAction {
  const ReminderDraft({
    this.title = '',
    this.targetId = '',
    this.targetStep = '',
    this.targetKind = 'personalGoal',
    this.frequency = 'weekly',
    this.weekday,
    this.time = '',
    this.day,
  });
  final String title, targetId, targetStep, targetKind, frequency, time;
  final int? weekday;
  final DateTime? day;
  @override
  AgentActionType get type => AgentActionType.createReminder;
  @override
  AgentPermission get permission => AgentPermission.createReminder;
  @override
  String get label => 'Create reminder';
  @override
  String get summary =>
      '$frequency · ${weekday == null ? '' : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday!.clamp(1, 7) - 1]} ${day == null ? '' : agentDay(day!)} · ${time.isEmpty ? 'Time needed' : time} · ${targetStep.isEmpty ? 'Existing personal item' : 'Linked to a mission step'}';
  @override
  List<String> validate(DateTime now) => [
    if (title.isNotEmpty && !_short(title))
      'Use a reminder title up to 100 characters.',
    if ((targetStep.isEmpty && !agentRecordId(targetId)) ||
        (targetStep.isNotEmpty && targetId.isNotEmpty))
      'Select exactly one existing item or mission step.',
    if (!['personalGoal', 'task'].contains(targetKind)) 'Use a personal goal or task. Shared reminders use the existing reminder screen.',
    if (![
      'once',
      'daily',
      'weekly',
      'deadline',
      'taskStart',
    ].contains(frequency))
      'Choose a supported recurrence.',
    if (targetKind == 'task' && !['once', 'taskStart'].contains(frequency))
      'Task reminders support once or task start.',
    if (targetKind != 'task' && frequency == 'taskStart')
      'Task start requires a task.',
    if (!agentTime(time)) 'Choose a reminder time (HH:mm).',
    if (frequency == 'weekly' &&
        (weekday == null || weekday! < 1 || weekday! > 7))
      'Choose a reminder weekday.',
    if (frequency == 'once' &&
        (day == null ||
            !DateTime(
              day!.year,
              day!.month,
              day!.day,
              int.tryParse(time.split(':').first) ?? 0,
              int.tryParse(time.split(':').last) ?? 0,
            ).isAfter(now)))
      'Choose a future reminder date and time.',
  ];
  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'title': title,
    'targetId': targetId,
    'targetStep': targetStep,
    'targetKind': targetKind,
    'frequency': frequency,
    'weekday': weekday,
    'time': time,
    'day': day?.toIso8601String(),
  };
}

final class ContributionDraft extends AgentAction {
  const ContributionDraft({
    this.goalId = '',
    this.amount = '',
    this.currency = '',
  });
  final String goalId, amount, currency;
  @override
  AgentActionType get type => AgentActionType.contribution;
  @override
  AgentPermission get permission => AgentPermission.contribution;
  @override
  String get label => 'Prepare savings contribution';
  @override
  String get summary =>
      '${agentMoney(amount, currency)} · Opens Add Savings for separate confirmation';
  @override
  List<String> validate(DateTime now) => [
    if (!agentRecordId(goalId)) 'Select a personal goal.',
    ..._moneyErrors(amount, currency),
  ];
  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'goalId': goalId,
    'amount': amount,
    'currency': currency,
  };
}

final class ScenarioDraft extends AgentAction {
  const ScenarioDraft({
    this.title = '',
    this.frequency = 'weekly',
    this.target = '',
    this.saved = '0',
    this.contribution = '',
    this.currency = '',
    this.deadline,
  });
  final String title, frequency, target, saved, contribution, currency;
  final DateTime? deadline;
  @override
  AgentActionType get type => AgentActionType.scenario;
  @override
  AgentPermission? get permission => null;
  @override
  String get label => 'Calculate savings scenario';
  @override
  String get summary =>
      '${title.isEmpty ? '' : '$title · '}$currency $target target · $saved saved · $contribution $frequency · ${deadline == null ? 'No deadline' : agentDay(deadline!)}';
  @override
  List<String> validate(DateTime now) => [
    if (title.isNotEmpty && !_short(title))
      'Use a scenario title up to 100 characters.',
    if (!['daily', 'weekly', 'monthly'].contains(frequency))
      'Choose daily, weekly or monthly contributions.',
    ..._moneyErrors(target, currency),
    if (parseCurrencyAmount(saved, currency) == null)
      'Enter a non-negative saved amount.',
    if (contribution.isNotEmpty) ..._moneyErrors(contribution, currency),
    if (contribution.isEmpty && (deadline == null || !deadline!.isAfter(now)))
      'Choose a future deadline or a weekly contribution.',
  ];
  String calculate(DateTime now) {
    final errors = validate(now);
    if (errors.isNotEmpty) throw AgentFailure(errors.first);
    final remaining = ExactDecimal.parse(target) - ExactDecimal.parse(saved);
    if (!remaining.positive) {
      return 'Target already reached. No contribution is required.';
    }
    if (contribution.isNotEmpty) {
      final periods = remaining / ExactDecimal.parse(contribution);
      final count =
          (periods.numerator + periods.denominator - BigInt.one) ~/
          periods.denominator;
      return '$count $frequency contributions of ${formatCurrency(ExactDecimal.parse(contribution), currency)} (last payment may be smaller). Assumes no withdrawals, interest, or currency changes.';
    }
    final start = DateTime.utc(now.year, now.month, now.day);
    final end = DateTime.utc(deadline!.year, deadline!.month, deadline!.day);
    final days = end.difference(start).inDays;
    var count = frequency == 'daily' ? days : ((days + 6) ~/ 7);
    if (frequency == 'monthly') {
      final months = (end.year - start.year) * 12 + end.month - start.month;
      final firstOfMonth = DateTime.utc(start.year, start.month + months);
      final lastDay = DateTime.utc(
        firstOfMonth.year,
        firstOfMonth.month + 1,
        0,
      ).day;
      final anchor = DateTime.utc(
        firstOfMonth.year,
        firstOfMonth.month,
        start.day.clamp(1, lastDay),
      );
      count = months + (end.isAfter(anchor) ? 1 : 0);
    }
    count = count.clamp(1, 100000);
    final units = remaining.roundedUnits(
      CurrencyCatalog.require(currency).digits,
    );
    final perPeriod = (units + BigInt.from(count - 1)) ~/ BigInt.from(count);
    final interval = frequency == 'monthly'
        ? 'calendar month'
        : frequency == 'daily'
        ? 'day'
        : '7 days';
    return '${formatCurrency(ExactDecimal(perPeriod, BigInt.from(10).pow(CurrencyCatalog.require(currency).digits)), currency)} across $count contributions, every $interval with the final payment by ${agentDay(deadline!)}. The final interval may be shorter than a ${frequency == 'monthly'
        ? 'month'
        : frequency == 'daily'
        ? 'day'
        : 'week'}. Rounded up; last contribution may be smaller. No interest or withdrawals assumed.';
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'title': title,
    'frequency': frequency,
    'target': target,
    'saved': saved,
    'contribution': contribution,
    'currency': currency,
    'deadline': deadline?.toIso8601String(),
  };
}

final class AllocationDraft extends AgentAction {
  const AllocationDraft({this.budget = '', this.currency = ''});
  final String budget, currency;
  @override
  AgentActionType get type => AgentActionType.allocation;
  @override
  AgentPermission get permission => AgentPermission.privateContext;
  @override
  String get label => 'Calculate equal goal allocation';
  @override
  String get summary =>
      '$currency $budget · Equal split across active personal goals in this currency. Calculation only.';
  @override
  List<String> validate(DateTime now) => _moneyErrors(budget, currency);
  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'budget': budget,
    'currency': currency,
  };
}

class AgentStep {
  AgentStep({
    required this.id,
    required this.action,
    List<String> dependsOn = const [],
    this.selected = true,
    this.status = StepStatus.waiting,
    this.result = '',
    this.recordId = '',
    this.attempts = 0,
    Map<String, String> uncertainFields = const {},
  }) : dependsOn = List.unmodifiable(dependsOn),
       uncertainFields = Map.unmodifiable(uncertainFields);
  final String id, result, recordId;
  final AgentAction action;
  final List<String> dependsOn;
  final bool selected;
  final StepStatus status;
  final int attempts;
  final Map<String, String> uncertainFields;
  bool get done => status == StepStatus.completed;
  AgentStep copyWith({
    AgentAction? action,
    List<String>? dependsOn,
    bool? selected,
    StepStatus? status,
    String? result,
    String? recordId,
    int? attempts,
    Map<String, String>? uncertainFields,
  }) => AgentStep(
    id: id,
    action: action ?? this.action,
    dependsOn: dependsOn ?? this.dependsOn,
    selected: selected ?? this.selected,
    status: status ?? this.status,
    result: result ?? this.result,
    recordId: recordId ?? this.recordId,
    attempts: attempts ?? this.attempts,
    uncertainFields: uncertainFields ?? this.uncertainFields,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'action': action.toJson(),
    'dependsOn': dependsOn,
    'selected': selected,
    'status': status.name,
    'result': result,
    'recordId': recordId,
    'attempts': attempts,
    'uncertainFields': uncertainFields,
  };
  factory AgentStep.fromJson(Map<String, dynamic> m) => AgentStep(
    id: m['id'] as String,
    action: AgentAction.fromJson(m['action'] as Map<String, dynamic>),
    dependsOn: (m['dependsOn'] as List).cast<String>(),
    selected: m['selected'] as bool,
    status: StepStatus.values.byName(m['status'] as String),
    result: m['result'] as String,
    recordId: m['recordId'] as String,
    attempts: m['attempts'] as int,
    uncertainFields: (m['uncertainFields'] as Map? ?? {})
        .cast<String, String>(),
  );
}

class AgentMission {
  AgentMission({
    required this.id,
    required this.uid,
    required this.title,
    required this.createdAt,
    required List<AgentStep> steps,
    this.version = 1,
    this.status = MissionStatus.draft,
    this.planOnly = false,
    List<String> languageIssues = const [],
  }) : steps = List.unmodifiable(steps),
       languageIssues = List.unmodifiable(languageIssues);
  final String id, uid, title;
  final DateTime createdAt;
  final int version;
  final MissionStatus status;
  final bool planOnly;
  final List<String> languageIssues;
  final List<AgentStep> steps;
  Iterable<AgentStep> get pending => steps.where((s) => s.selected && !s.done);
  String get snapshot => jsonEncode({
    'id': id,
    'uid': uid,
    'title': title,
    'version': version,
    'planOnly': planOnly,
    'languageIssues': languageIssues,
    'steps': [
      for (final s in steps)
        {
          'id': s.id,
          'selected': s.selected,
          'dependsOn': s.dependsOn,
          'action': s.action.toJson(),
          'uncertainFields': s.uncertainFields,
        },
    ],
  });
  AgentMission copyWith({
    String? title,
    List<AgentStep>? steps,
    MissionStatus? status,
    int? version,
    bool? planOnly,
    List<String>? languageIssues,
  }) => AgentMission(
    id: id,
    uid: uid,
    title: title ?? this.title,
    createdAt: createdAt,
    steps: steps ?? this.steps,
    status: status ?? this.status,
    version: version ?? this.version,
    planOnly: planOnly ?? this.planOnly,
    languageIssues: languageIssues ?? this.languageIssues,
  );
  List<String> validate(DateTime now) {
    final errors = <String>[];
    if (planOnly) {
      errors.add('Draft only. Enable review on screen when you are ready.');
    }
    errors.addAll(languageIssues);
    if (!agentRecordId(id) ||
        uid.isEmpty ||
        steps.isEmpty ||
        steps.length > AgentLimits.steps) {
      errors.add('A mission needs 1–${AgentLimits.steps} steps.');
    }
    final ids = steps.map((s) => s.id).toSet();
    if (ids.length != steps.length || steps.any((s) => !agentRecordId(s.id))) {
      errors.add('Step identifiers must be unique and valid.');
    }
    if (steps.where((s) => s.action is TaskDraft).length > AgentLimits.tasks ||
        steps.where((s) => s.action is ReminderDraft).length >
            AgentLimits.reminders) {
      errors.add('Too many tasks or reminders.');
    }
    if (!steps.any((s) => s.selected)) errors.add('Select at least one step.');
    final visited = <String>{}, visiting = <String>{};
    void visit(AgentStep step) {
      if (visited.contains(step.id)) return;
      if (!visiting.add(step.id)) {
        errors.add('Mission dependencies contain a cycle.');
        return;
      }
      for (final id in step.dependsOn) {
        final matches = steps.where((s) => s.id == id);
        if (matches.isEmpty) {
          errors.add('Step ${step.id} has a missing dependency.');
          continue;
        }
        final parent = matches.first;
        if (step.selected && !parent.selected && !parent.done) {
          errors.add('Select dependency $id before ${step.id}.');
        }
        visit(parent);
      }
      visiting.remove(step.id);
      visited.add(step.id);
    }

    for (final step in steps) {
      visit(step);
      if (step.selected && !step.done) {
        errors.addAll(step.uncertainFields.values);
        errors.addAll(
          step.action.validate(now).map((e) => '${step.action.label}: $e'),
        );
        final action = step.action;
        if (action is ReminderDraft && action.targetStep.isNotEmpty) {
          final parent = steps
              .where((s) => s.id == action.targetStep)
              .firstOrNull;
          if (!step.dependsOn.contains(action.targetStep) ||
              parent == null ||
              (action.targetKind == 'task'
                  ? parent.action is! TaskDraft
                  : parent.action is! GoalDraft)) {
            errors.add('Reminder dependency must match its target type.');
          }
        }
      }
    }
    final signatures = <String>{};
    final slots = <String>{};
    for (final s in pending) {
      if (!signatures.add(jsonEncode(s.action.toJson()))) {
        errors.add('Remove duplicate proposed steps.');
      }
      final a = s.action;
      if (a is TaskDraft &&
          a.day != null &&
          a.time.isNotEmpty &&
          !slots.add('${agentDay(a.day!)} ${a.time}')) {
        errors.add(
          'Two proposed tasks have the same start time. Edit a time or leave it flexible.',
        );
      }
    }
    return errors.toSet().toList();
  }

  Map<String, Object?> toJson() => {
    'schema': 1,
    'id': id,
    'uid': uid,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'version': version,
    'status': status.name,
    'planOnly': planOnly,
    'languageIssues': languageIssues,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
  factory AgentMission.fromJson(Map<String, dynamic> m) {
    if (m['schema'] != 1 || (m['steps'] as List).length > AgentLimits.steps) {
      throw const FormatException('Invalid mission');
    }
    return AgentMission(
      id: m['id'] as String,
      uid: m['uid'] as String,
      title: m['title'] as String,
      createdAt: DateTime.parse(m['createdAt'] as String),
      version: m['version'] as int,
      status: MissionStatus.values.byName(m['status'] as String),
      planOnly: m['planOnly'] == true,
      languageIssues: List<String>.unmodifiable(
        (m['languageIssues'] as List? ?? []).cast<String>(),
      ),
      steps: (m['steps'] as List)
          .map((s) => AgentStep.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AgentSettings {
  AgentSettings({
    Set<AgentPermission> permissions = const {},
    this.execute = false,
    this.history = false,
    this.spoken = false,
    this.hideSpokenDetails = true,
    this.onDevice = false,
    this.language = AgentLanguage.automatic,
    this.interfaceLanguage = AgentLanguage.automatic,
    this.speechLanguage = AgentLanguage.automatic,
    this.locale = '',
    this.ttsLocale = '',
    this.voice = '',
    this.rate = .9,
    Map<String, String> memory = const {},
    this.useMemory = false,
    this.autopilot = const AgentAutopilotSettings(),
  }) : permissions = Set.unmodifiable(permissions),
       memory = Map.unmodifiable(memory);
  final Set<AgentPermission> permissions;
  final AgentAutopilotSettings autopilot;
  final bool execute, history, spoken, hideSpokenDetails, onDevice, useMemory;
  final AgentLanguage language, interfaceLanguage, speechLanguage;
  final String locale, ttsLocale, voice;
  final double rate;
  final Map<String, String> memory;
  Map<String, Object?> toJson() => {
    'permissions': permissions.map((p) => p.name).toList(),
    'autopilot': autopilot.toJson(),
    'execute': execute,
    'history': history,
    'spoken': spoken,
    'hideSpokenDetails': hideSpokenDetails,
    'onDevice': onDevice,
    'language': language.name,
    'interfaceLanguage': interfaceLanguage.name,
    'speechLanguage': speechLanguage.name,
    'locale': locale,
    'ttsLocale': ttsLocale,
    'voice': voice,
    'rate': rate,
    'memory': memory,
    'useMemory': useMemory,
  };
  factory AgentSettings.fromJson(Map<String, dynamic> m) => AgentSettings(
    autopilot: AgentAutopilotSettings.fromJson(m['autopilot']),
    permissions: (m['permissions'] as List? ?? [])
        .map((p) => AgentPermission.values.byName(p as String))
        .toSet(),
    execute: m['execute'] == true,
    history: m['history'] == true,
    spoken: m['spoken'] == true,
    hideSpokenDetails: m['hideSpokenDetails'] != false,
    onDevice: m['onDevice'] == true,
    language: AgentLanguage.values.byName(
      m['language'] as String? ?? 'automatic',
    ),
    interfaceLanguage: AgentLanguage.values.byName(
      m['interfaceLanguage'] as String? ?? 'automatic',
    ),
    speechLanguage: AgentLanguage.values.byName(
      m['speechLanguage'] as String? ?? 'automatic',
    ),
    locale: m['locale'] as String? ?? '',
    ttsLocale: m['ttsLocale'] as String? ?? '',
    voice: m['voice'] as String? ?? '',
    rate: ((m['rate'] as num?)?.toDouble() ?? .9).clamp(.5, 1.5),
    memory: (m['memory'] as Map? ?? {}).cast<String, String>(),
    useMemory: m['useMemory'] == true,
  );
  AgentSettings change(Map<String, Object?> values) =>
      AgentSettings.fromJson({...toJson(), ...values});
}

class AgentMessage {
  const AgentMessage(this.text, {this.user = false, this.voice = false});
  final String text;
  final bool user, voice;
}

class AgentRecord {
  const AgentRecord(
    this.id,
    this.title, {
    this.currency = '',
    this.target = '0',
    this.saved = '0',
    this.day = '',
    this.time = '',
    this.deadline,
  });
  final String id, title, currency, target, saved, day, time;
  final DateTime? deadline;
}

class AgentExecutionResult {
  const AgentExecutionResult(this.message, {this.recordId = ''});
  final String message, recordId;
}
