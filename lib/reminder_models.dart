import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;

import 'smart_task_recommendation_service.dart';

enum ReminderTargetType { personalGoal, sharedGoal, task }

enum ReminderFrequency { once, daily, weekly, deadline, taskStart }

class ReminderFailure implements Exception {
  const ReminderFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReminderTarget {
  const ReminderTarget({
    required this.type,
    required this.id,
    required this.title,
    this.deadline,
    this.taskDay,
    this.taskStart,
    this.available = true,
    this.completed = false,
  });
  final ReminderTargetType type;
  final String id, title;
  final DateTime? deadline, taskDay, taskStart;
  final bool available, completed;
  String get key => '${type.name}_$id';

  factory ReminderTarget.fromData(
    ReminderTargetType type,
    String id,
    Map<String, dynamic> data, {
    bool authorized = true,
    DateTime? deadline,
  }) {
    final day = SmartTaskRecommendationService.parseDateKey(
      data['dateKey']?.toString() ?? '',
    );
    final start = day == null
        ? null
        : SmartTaskRecommendationService.parseSchedule(
            data['time']?.toString() ?? '',
            day,
          ).start;
    final shared = type == ReminderTargetType.sharedGoal;
    final saved = data[shared ? 'currentAmount' : 'savedAmount'];
    final amount = data['targetAmount'];
    return ReminderTarget(
      type: type,
      id: id,
      title:
          data[shared ? 'name' : 'title']?.toString() ?? 'SaveTrack reminder',
      deadline: deadline,
      taskDay: day,
      taskStart: start,
      available:
          authorized &&
          data['archived'] != true &&
          data['status'] != 'archived',
      completed: type == ReminderTargetType.task
          ? data['completed'] == true
          : saved is num && amount is num && amount > 0 && saved >= amount,
    );
  }
}

/// Only preferences are persisted. Financial and task records are never written.
class ReminderConfiguration {
  const ReminderConfiguration({
    required this.uid,
    required this.type,
    required this.targetId,
    this.enabled = false,
    this.hour = 20,
    this.minute = 0,
    this.frequency = ReminderFrequency.once,
    this.instant,
    this.weekday = DateTime.monday,
    this.offsetMinutes = 15,
    this.daysBefore = 0,
    this.showTitle = false,
  });
  final String uid, targetId;
  final ReminderTargetType type;
  final bool enabled, showTitle;
  final int hour, minute, weekday, offsetMinutes, daysBefore;
  final ReminderFrequency frequency;
  final DateTime? instant;
  String get key => '${type.name}_$targetId';

  void validate() {
    if (uid.isEmpty ||
        targetId.isEmpty ||
        targetId.contains('/') ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        weekday < 1 ||
        weekday > 7 ||
        ![0, 5, 10, 15, 30, 60].contains(offsetMinutes) ||
        ![0, 1, 3, 7].contains(daysBefore) ||
        (type == ReminderTargetType.task &&
            ![
              ReminderFrequency.once,
              ReminderFrequency.taskStart,
            ].contains(frequency)) ||
        (type != ReminderTargetType.task &&
            frequency == ReminderFrequency.taskStart)) {
      throw const ReminderFailure('Review the reminder settings.');
    }
    if (enabled && frequency == ReminderFrequency.once && instant == null) {
      throw const ReminderFailure('Choose a reminder date and time.');
    }
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'type': type.name,
    'targetId': targetId,
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'frequency': frequency.name,
    'instant': instant?.toUtc().toIso8601String(),
    'weekday': weekday,
    'offsetMinutes': offsetMinutes,
    'daysBefore': daysBefore,
    'showTitle': showTitle,
    'version': 1,
  };

  factory ReminderConfiguration.fromMap(Map<String, dynamic> data) {
    try {
      final value = ReminderConfiguration(
        uid: data['uid'] as String,
        type: ReminderTargetType.values.byName(data['type'] as String),
        targetId: data['targetId'] as String,
        enabled: data['enabled'] as bool,
        hour: data['hour'] as int,
        minute: data['minute'] as int,
        frequency: ReminderFrequency.values.byName(data['frequency'] as String),
        instant: data['instant'] == null
            ? null
            : DateTime.parse(data['instant'] as String).toUtc(),
        weekday: data['weekday'] as int,
        offsetMinutes: data['offsetMinutes'] as int,
        daysBefore: data['daysBefore'] as int,
        showTitle: data['showTitle'] as bool,
      );
      if (data['version'] != 1) throw const FormatException();
      if (value.instant != null &&
          value.instant!.toIso8601String() != data['instant']) {
        throw const FormatException();
      }
      value.validate();
      return value;
    } catch (_) {
      throw const ReminderFailure(
        'A saved reminder has invalid settings. Edit or remove it.',
      );
    }
  }

  ReminderConfiguration withEnabled(bool value) =>
      ReminderConfiguration.fromMap({...toMap(), 'enabled': value});
}

/// Payloads contain identifiers only. Treat them as untrusted at navigation time.
class ReminderPayload {
  const ReminderPayload(this.uid, this.type, this.targetId);
  final String uid, targetId;
  final ReminderTargetType type;
  String get key => '${type.name}_$targetId';
  String encode() =>
      jsonEncode({'v': 1, 'uid': uid, 'type': type.name, 'id': targetId});
  static ReminderPayload? decode(String? text) {
    try {
      final d = jsonDecode(text!) as Map<String, dynamic>;
      if (d['v'] != 1 ||
          d['uid'] is! String ||
          (d['uid'] as String).isEmpty ||
          d['id'] is! String ||
          (d['id'] as String).isEmpty ||
          (d['id'] as String).contains('/')) {
        return null;
      }
      return ReminderPayload(
        d['uid'],
        ReminderTargetType.values.byName(d['type']),
        d['id'],
      );
    } catch (_) {
      return null;
    }
  }
}

class ReminderTimeCalculator {
  const ReminderTimeCalculator();

  /// Reject nonexistent wall times; choose the first instant during a fall-back.
  /// Enumerating the zone offsets avoids silently normalizing a DST gap.
  tz.TZDateTime local(tz.Location zone, DateTime date, int hour, int minute) {
    final wall = DateTime.utc(date.year, date.month, date.day, hour, minute);
    final candidates = <tz.TZDateTime>[];
    for (final offset in zone.zones.map((z) => z.offset).toSet()) {
      final candidate = tz.TZDateTime.fromMillisecondsSinceEpoch(
        zone,
        wall.millisecondsSinceEpoch - offset.inMilliseconds,
      );
      if (candidate.year == date.year &&
          candidate.month == date.month &&
          candidate.day == date.day &&
          candidate.hour == hour &&
          candidate.minute == minute) {
        candidates.add(candidate);
      }
    }
    candidates.sort();
    if (candidates.isEmpty) {
      throw const ReminderFailure(
        'This local time does not exist because the clocks change. Choose another time.',
      );
    }
    return candidates.first;
  }

  tz.TZDateTime? next(
    ReminderConfiguration config,
    ReminderTarget target,
    tz.Location zone,
    DateTime now,
  ) {
    config.validate();
    if (!config.enabled || !target.available || target.completed) return null;
    final current = tz.TZDateTime.from(now, zone);
    tz.TZDateTime? result;
    switch (config.frequency) {
      case ReminderFrequency.once:
        result = tz.TZDateTime.from(config.instant!, zone);
      case ReminderFrequency.deadline:
        if (target.deadline == null) {
          throw const ReminderFailure('This goal has no deadline.');
        }
        final d = target.deadline!;
        final day = DateTime.utc(d.year, d.month, d.day - config.daysBefore);
        result = local(zone, day, config.hour, config.minute);
      case ReminderFrequency.taskStart:
        final start = target.taskStart;
        if (start == null) {
          throw const ReminderFailure(
            'Set a valid task start time first, or choose a custom reminder.',
          );
        }
        result = local(
          zone,
          start,
          start.hour,
          start.minute,
        ).subtract(Duration(minutes: config.offsetMinutes));
      case ReminderFrequency.daily:
      case ReminderFrequency.weekly:
        for (var i = 0; i < 370; i++) {
          final day = DateTime.utc(
            current.year,
            current.month,
            current.day + i,
          );
          if (config.frequency == ReminderFrequency.weekly &&
              day.weekday != config.weekday) {
            continue;
          }
          try {
            final candidate = local(zone, day, config.hour, config.minute);
            if (candidate.isAfter(current)) return candidate;
          } on ReminderFailure {
            // Skip the day whose selected wall time falls in a DST gap.
          }
        }
        throw const ReminderFailure(
          'No valid future reminder could be calculated.',
        );
    }
    return result.isAfter(current) ? result : null;
  }
}

enum ReminderDelivery {
  off,
  waiting,
  scheduled,
  approximate,
  blocked,
  expired,
  paused,
  failed,
  unsupported,
  limit,
}

class ReminderStatus {
  const ReminderStatus(this.delivery, this.message);
  final ReminderDelivery delivery;
  final String message;
  bool get scheduled =>
      delivery == ReminderDelivery.scheduled ||
      delivery == ReminderDelivery.approximate;
}

String reminderTitle(ReminderTargetType type) => switch (type) {
  ReminderTargetType.personalGoal => 'SaveTrack — Savings Reminder',
  ReminderTargetType.sharedGoal => 'SaveTrack — Shared Savings Reminder',
  ReminderTargetType.task => 'SaveTrack — Task Reminder',
};

String reminderBody(ReminderTarget target, bool showTitle) {
  final name = target.title.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
  final safeName = name.length > 100 ? '${name.substring(0, 100)}…' : name;
  return switch (target.type) {
    ReminderTargetType.personalGoal =>
      showTitle
          ? 'Time to check your $safeName savings goal.'
          : 'Time to check your savings goal.',
    ReminderTargetType.sharedGoal =>
      showTitle
          ? 'Time to check your $safeName shared goal.'
          : 'Time to check your shared savings goal.',
    ReminderTargetType.task =>
      showTitle
          ? "It's time to work on $safeName."
          : 'It’s time to work on your planned task.',
  };
}
