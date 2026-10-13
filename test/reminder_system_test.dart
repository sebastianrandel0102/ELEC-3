import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:myproject/reminder_models.dart';
import 'package:myproject/reminder_coordinator.dart';
import 'package:myproject/reminder_repository.dart';
import 'package:myproject/reminder_scheduler.dart';

class MemoryReminders implements ReminderRepository {
  final values = <String, Map<String, ReminderConfiguration>>{};
  final items = <String, ReminderTarget?>{};
  final changes = <String, StreamController<ReminderSnapshot>>{};
  final itemChanges = <String, StreamController<ReminderTarget?>>{};
  bool rejectWrite = false;
  ReminderSnapshot snapshot(String uid) =>
      ReminderSnapshot(values[uid]?.values.toList() ?? []);
  @override
  Stream<ReminderSnapshot> watch(String uid) async* {
    yield snapshot(uid);
    yield* (changes[uid] ??= StreamController.broadcast()).stream;
  }

  @override
  Stream<ReminderTarget?> watchTarget(
    String uid,
    ReminderConfiguration config,
  ) async* {
    final key = '$uid/${config.key}';
    yield items[key];
    yield* (itemChanges[key] ??= StreamController.broadcast()).stream;
  }

  @override
  Future<ReminderTarget?> target(
    String uid,
    ReminderTargetType type,
    String id,
  ) async => items['$uid/${type.name}_$id'];
  @override
  Future<void> save(ReminderConfiguration config) async {
    if (rejectWrite) throw const ReminderFailure('Firestore write failed.');
    (values[config.uid] ??= {})[config.key] = config;
    changes[config.uid]?.add(snapshot(config.uid));
  }

  @override
  Future<void> remove(String uid, String key) async {
    values[uid]?.remove(key);
    changes[uid]?.add(snapshot(uid));
  }

  void update(String uid, ReminderTarget? target, String key) {
    items['$uid/$key'] = target;
    itemChanges['$uid/$key']?.add(target);
  }

  Future<void> close() async {
    for (final stream in [...changes.values, ...itemChanges.values]) {
      await stream.close();
    }
  }
}

class MemoryDeviceStore implements ReminderDeviceStore {
  final ids = <String, int>{};
  final signatures = <int, String>{};
  @override
  Future<int> idFor(String uid, String key) async =>
      ids.putIfAbsent('$uid/$key', () => 1000 + ids.length);
  @override
  Future<String?> signature(int id) async => signatures[id];
  @override
  Future<void> setSignature(int id, String? value) async {
    if (value == null) {
      signatures.remove(id);
    } else {
      signatures[id] = value;
    }
  }
}

class RecordingScheduler implements NotificationScheduler {
  RecordingScheduler(this.location);
  tz.Location location;
  bool allowed = true, exact = true, fail = false;
  bool failCancel = false;
  @override
  bool supported = true;
  @override
  int limit = 60;
  int scheduled = 0, canceled = 0;
  final alarms = <int, String?>{};
  final dates = <int, tz.TZDateTime>{};
  void Function(ReminderPayload)? onTap;
  @override
  Future<void> initialize(void Function(ReminderPayload) onTap) async {
    this.onTap = onTap;
  }

  @override
  Future<tz.Location> timezone() async => location;
  @override
  Future<NotificationCapability> capability(ReminderTargetType type) async =>
      NotificationCapability(
        supported: supported,
        allowed: allowed,
        exact: exact,
      );
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> requestPreciseTiming() async {}
  @override
  Future<Map<int, String?>> pending() async => Map.of(alarms);
  @override
  Future<void> cancel(int id) async {
    if (failCancel) throw const ReminderFailure('Native cancellation failed.');
    canceled++;
    alarms.remove(id);
    dates.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    alarms.clear();
    dates.clear();
  }

  @override
  Future<void> schedule(
    int id,
    ReminderConfiguration config,
    ReminderTarget target,
    tz.TZDateTime date, {
    required bool exact,
  }) async {
    if (fail) throw const ReminderFailure('Native scheduling failed.');
    scheduled++;
    alarms[id] = ReminderPayload(
      config.uid,
      config.type,
      config.targetId,
    ).encode();
    dates[id] = date;
  }
}

ReminderConfiguration preference({
  String uid = 'alex',
  String id = 'fund',
  ReminderTargetType type = ReminderTargetType.personalGoal,
  ReminderFrequency frequency = ReminderFrequency.daily,
  int hour = 20,
  int minute = 0,
  int weekday = 1,
  DateTime? instant,
  int offset = 15,
  int days = 0,
}) => ReminderConfiguration(
  uid: uid,
  targetId: id,
  type: type,
  enabled: true,
  frequency: frequency,
  hour: hour,
  minute: minute,
  weekday: weekday,
  instant: instant,
  offsetMinutes: offset,
  daysBefore: days,
);

const fund = ReminderTarget(
  type: ReminderTargetType.personalGoal,
  id: 'fund',
  title: 'Emergency Fund',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  final manila = tz.getLocation('Asia/Manila');
  final newYork = tz.getLocation('America/New_York');
  const calculator = ReminderTimeCalculator();

  group('timezone-aware calculations', () {
    for (final value in [
      (DateTime.utc(2026, 10, 13, 10), DateTime.utc(2026, 10, 13, 12)),
      (DateTime.utc(2026, 10, 13, 13), DateTime.utc(2026, 10, 14, 12)),
      (DateTime.utc(2026, 1, 31, 13), DateTime.utc(2026, 2, 1, 12)),
      (DateTime.utc(2026, 12, 31, 13), DateTime.utc(2027, 1, 1, 12)),
      (DateTime.utc(2028, 2, 28, 13), DateTime.utc(2028, 2, 29, 12)),
    ]) {
      test('daily rollover at ${value.$1}', () {
        expect(
          calculator.next(preference(), fund, manila, value.$1)!.toUtc(),
          value.$2,
        );
      });
    }
    test('midnight does not fire immediately', () {
      expect(
        calculator
            .next(
              preference(hour: 0),
              fund,
              manila,
              DateTime.utc(2026, 10, 13, 16),
            )!
            .toUtc(),
        DateTime.utc(2026, 10, 14, 16),
      );
    });
    test('weekly honors chosen weekday and skips elapsed occurrence', () {
      final next = calculator.next(
        preference(frequency: ReminderFrequency.weekly, weekday: 1),
        fund,
        manila,
        DateTime.utc(2026, 10, 12, 13),
      )!;
      expect(next.weekday, 1);
      expect(next.day, 19);
      expect(next.hour, 20);
    });
    test('one-time represents the same absolute instant while traveling', () {
      final config = preference(
        frequency: ReminderFrequency.once,
        instant: DateTime.utc(2026, 10, 20, 12),
      );
      expect(
        calculator
            .next(config, fund, manila, DateTime.utc(2026, 10, 13))!
            .toUtc(),
        calculator
            .next(config, fund, newYork, DateTime.utc(2026, 10, 13))!
            .toUtc(),
      );
    });
    test('daily follows new device wall clock', () {
      final now = DateTime.utc(2026, 10, 13, 10);
      expect(calculator.next(preference(), fund, manila, now)!.hour, 20);
      expect(calculator.next(preference(), fund, newYork, now)!.hour, 20);
      expect(
        calculator.next(preference(), fund, manila, now)!.toUtc(),
        isNot(calculator.next(preference(), fund, newYork, now)!.toUtc()),
      );
    });
    test('DST gap rejects custom local time and daily skips invalid day', () {
      expect(
        () => calculator.local(newYork, DateTime(2026, 3, 8), 2, 30),
        throwsA(isA<ReminderFailure>()),
      );
      final next = calculator.next(
        preference(hour: 2, minute: 30),
        fund,
        newYork,
        DateTime.utc(2026, 3, 8, 5),
      )!;
      expect(next.day, 9);
      expect(next.hour, 2);
      expect(next.minute, 30);
    });
    test('ambiguous time picks first occurrence, never schedules the second duplicate', () {
      final time = calculator.local(newYork, DateTime(2026, 11, 1), 1, 30);
      expect(time.toUtc(), DateTime.utc(2026, 11, 1, 5, 30));
      final next = calculator.next(
        preference(hour: 1, minute: 30),
        fund,
        newYork,
        DateTime.utc(2026, 11, 1, 5, 45),
      )!;
      expect(next.day, 2);
    });
    test('deadline uses actual date and rejects an elapsed occurrence', () {
      final target = ReminderTarget(
        type: fund.type,
        id: fund.id,
        title: fund.title,
        deadline: DateTime(2026, 10, 20),
      );
      final config = preference(frequency: ReminderFrequency.deadline, days: 3);
      expect(
        calculator
            .next(config, target, manila, DateTime.utc(2026, 10, 13))!
            .day,
        17,
      );
      expect(
        calculator.next(config, target, manila, DateTime.utc(2026, 10, 21)),
        isNull,
      );
      expect(
        () => calculator.next(config, fund, manila, DateTime.utc(2026, 10, 13)),
        throwsA(isA<ReminderFailure>()),
      );
    });
    test('task offsets use existing schedule without changing it', () {
      final data = {
        'title': 'Review notes',
        'dateKey': '2026-10-13',
        'time': '4:00 PM',
        'priority': 'High',
        'completed': false,
      };
      final before = Map.of(data);
      final target = ReminderTarget.fromData(
        ReminderTargetType.task,
        'notes',
        data,
      );
      final config = preference(
        type: ReminderTargetType.task,
        id: 'notes',
        frequency: ReminderFrequency.taskStart,
      );
      expect(
        calculator
            .next(config, target, manila, DateTime.utc(2026, 10, 13, 7))!
            .hour,
        15,
      );
      expect(
        calculator
            .next(config, target, manila, DateTime.utc(2026, 10, 13, 7))!
            .minute,
        45,
      );
      expect(data, before);
      expect(
        calculator.next(config, target, manila, DateTime.utc(2026, 10, 13, 9)),
        isNull,
      );
    });
    test(
      'missing task start is unavailable and custom time remains supported',
      () {
        const target = ReminderTarget(
          type: ReminderTargetType.task,
          id: 'task',
          title: 'Task',
        );
        expect(
          () => calculator.next(
            preference(
              type: target.type,
              id: target.id,
              frequency: ReminderFrequency.taskStart,
            ),
            target,
            manila,
            DateTime.utc(2026, 10, 13),
          ),
          throwsA(isA<ReminderFailure>()),
        );
        expect(
          calculator.next(
            preference(
              type: target.type,
              id: target.id,
              frequency: ReminderFrequency.once,
              instant: DateTime.utc(2026, 10, 14),
            ),
            target,
            manila,
            DateTime.utc(2026, 10, 13),
          ),
          isNotNull,
        );
      },
    );
    test('strict serialization rejects invalid types, normalized dates, and incompatible recurrence', () {
      final data = preference().toMap();
      expect(ReminderConfiguration.fromMap(data).toMap(), data);
      for (final bad in [
        {...data, 'hour': 24},
        {...data, 'minute': -1},
        {...data, 'enabled': 'yes'},
        {...data, 'weekday': 0},
        {...data, 'offsetMinutes': 2},
        {...data, 'targetId': 'a/b'},
        {...data, 'type': 'task', 'frequency': 'weekly'},
        {...data, 'instant': '2026-02-31T00:00:00.000Z'},
      ]) {
        expect(
          () => ReminderConfiguration.fromMap(bad),
          throwsA(isA<ReminderFailure>()),
        );
      }
    });
    test('payloads contain no names or financial values and reject malformed input', () {
      const payload = ReminderPayload(
        'alex',
        ReminderTargetType.sharedGoal,
        'trip',
      );
      expect(ReminderPayload.decode(payload.encode())!.targetId, 'trip');
      expect(payload.encode(), isNot(contains('Japan')));
      expect(
        ReminderPayload.decode(
          '{"v":1,"uid":"alex","type":"sharedGoal","id":"a/b"}',
        ),
        isNull,
      );
      expect(ReminderPayload.decode('not json'), isNull);
      expect(reminderBody(fund, false), isNot(contains(fund.title)));
      expect(reminderBody(fund, true), contains(fund.title));
    });
  });

  group('central reconciliation with mocked native alarms', () {
    late MemoryReminders repo;
    late RecordingScheduler scheduler;
    late ReminderCoordinator coordinator;
    late MemoryDeviceStore store;
    Future<void> settle() async {
      await Future<void>.delayed(Duration.zero);
      await coordinator.reconcile();
      await Future<void>.delayed(Duration.zero);
      await coordinator.reconcile();
    }

    setUp(() async {
      repo = MemoryReminders();
      scheduler = RecordingScheduler(manila);
      store = MemoryDeviceStore();
      coordinator = ReminderCoordinator(
        repository: repo,
        scheduler: scheduler,
        deviceStore: store,
        clock: () => DateTime.utc(2026, 10, 13, 10),
      );
      repo.items['alex/${fund.key}'] = fund;
      await coordinator.initialize();
      await coordinator.switchAccount('alex');
      await settle();
    });
    tearDown(() async {
      coordinator.dispose();
      await repo.close();
    });
    test(
      'save, repeat reconcile, edit, disable, remove use one stable native ID',
      () async {
        await coordinator.save(preference(), fund);
        await settle();
        expect(scheduler.alarms.length, 1);
        final id = scheduler.alarms.keys.single;
        final scheduled = scheduler.scheduled;
        await coordinator.resume();
        await settle();
        expect(scheduler.scheduled, scheduled);
        await coordinator.save(preference(hour: 21), fund);
        await settle();
        expect(scheduler.alarms.keys.single, id);
        expect(scheduler.dates[id]!.hour, 21);
        await coordinator.save(preference().withEnabled(false), fund);
        await settle();
        expect(scheduler.alarms, isEmpty);
        expect(coordinator.status(fund.key).delivery, ReminderDelivery.off);
        await coordinator.remove(fund.key);
        expect(repo.values['alex'], isEmpty);
      },
    );
    test('completed task cancels; incomplete reschedules only valid future occurrence', () async {
      const task = ReminderTarget(
        type: ReminderTargetType.task,
        id: 'notes',
        title: 'Notes',
      );
      repo.items['alex/${task.key}'] = task;
      final config = preference(
        type: task.type,
        id: task.id,
        frequency: ReminderFrequency.once,
        instant: DateTime.utc(2026, 10, 14),
      );
      await coordinator.save(config, task);
      await settle();
      expect(scheduler.alarms.length, 1);
      repo.update(
        'alex',
        const ReminderTarget(
          type: ReminderTargetType.task,
          id: 'notes',
          title: 'Notes',
          completed: true,
        ),
        task.key,
      );
      await settle();
      expect(scheduler.alarms, isEmpty);
      expect(repo.values['alex']![task.key]!.enabled, isTrue);
      repo.update('alex', task, task.key);
      await settle();
      expect(scheduler.alarms.length, 1);
    });
    test('completed goal pauses and keeps financial data unchanged', () async {
      await coordinator.save(preference(), fund);
      await settle();
      repo.update(
        'alex',
        const ReminderTarget(
          type: ReminderTargetType.personalGoal,
          id: 'fund',
          title: 'Emergency Fund',
          completed: true,
        ),
        fund.key,
      );
      await settle();
      expect(scheduler.alarms, isEmpty);
      expect(coordinator.status(fund.key).delivery, ReminderDelivery.paused);
    });
    test(
      'deletion or membership revocation cancels and disables the preference',
      () async {
        await coordinator.save(preference(), fund);
        await settle();
        repo.update('alex', null, fund.key);
        await settle();
        expect(scheduler.alarms, isEmpty);
        expect(repo.values['alex']![fund.key]!.enabled, isFalse);
      },
    );
    test('shared preferences are independent and account switching cancels old alarms', () async {
      const shared = ReminderTarget(
        type: ReminderTargetType.sharedGoal,
        id: 'trip',
        title: 'Japan Vacation',
      );
      repo.items['alex/${shared.key}'] = shared;
      repo.items['jamie/${shared.key}'] = shared;
      await coordinator.save(
        preference(type: shared.type, id: shared.id),
        shared,
      );
      await settle();
      final alexId = scheduler.alarms.keys.single;
      await coordinator.switchAccount('jamie');
      await settle();
      expect(scheduler.alarms, isEmpty);
      await coordinator.save(
        preference(
          uid: 'jamie',
          type: shared.type,
          id: shared.id,
          hour: 18,
          frequency: ReminderFrequency.weekly,
        ),
        shared,
      );
      await settle();
      expect(scheduler.alarms.keys.single, isNot(alexId));
      expect(repo.values['alex']![shared.key]!.hour, 20);
      expect(repo.values['jamie']![shared.key]!.hour, 18);
      await expectLater(
        coordinator.save(preference(type: shared.type, id: shared.id), shared),
        throwsA(isA<ReminderFailure>()),
      );
      await coordinator.switchAccount(null);
      expect(scheduler.alarms, isEmpty);
    });
    test(
      'rapid edits and duplicate submissions replace rather than add alarms',
      () async {
        await Future.wait([
          coordinator.save(preference(hour: 21), fund),
          coordinator.save(preference(hour: 22), fund),
          coordinator.save(preference(hour: 22), fund),
        ]);
        await settle();
        expect(scheduler.alarms.length, 1);
        expect(scheduler.dates.values.single.hour, 22);
      },
    );
    test('denied permission, approximate timing, native failure and web are honest', () async {
      scheduler.allowed = false;
      await coordinator.save(preference(), fund);
      await settle();
      expect(scheduler.alarms, isEmpty);
      expect(coordinator.status(fund.key).delivery, ReminderDelivery.blocked);
      scheduler.allowed = true;
      scheduler.exact = false;
      await coordinator.resume();
      expect(
        coordinator.status(fund.key).delivery,
        ReminderDelivery.approximate,
      );
      scheduler.fail = true;
      await coordinator.save(preference(hour: 21), fund);
      expect(scheduler.alarms, isEmpty);
      expect(coordinator.status(fund.key).delivery, ReminderDelivery.failed);
      scheduler.fail = false;
      scheduler.supported = false;
      await coordinator.resume();
      expect(
        coordinator.status(fund.key).delivery,
        ReminderDelivery.unsupported,
      );
    });
    test('write failure cannot schedule a fake success', () async {
      repo.rejectWrite = true;
      await expectLater(
        coordinator.save(preference(), fund),
        throwsA(isA<ReminderFailure>()),
      );
      expect(scheduler.alarms, isEmpty);
      expect(coordinator.configurations, isEmpty);
    });
    test('failed cancellation remains visible and can be retried', () async {
      await coordinator.save(preference(), fund);
      await settle();
      scheduler.failCancel = true;
      await expectLater(
        coordinator.save(preference().withEnabled(false), fund),
        throwsA(isA<ReminderFailure>()),
      );
      expect(coordinator.status(fund.key).delivery, ReminderDelivery.failed);
      expect(scheduler.alarms.length, 1);
      scheduler.failCancel = false;
      await coordinator.resume();
      await settle();
      expect(scheduler.alarms, isEmpty);
      expect(coordinator.status(fund.key).delivery, ReminderDelivery.off);
    });
    test('task edits reschedule actual offsets; timezone changes reschedule recurring alarms', () async {
      final task = ReminderTarget(
        type: ReminderTargetType.task,
        id: 'task',
        title: 'Task',
        taskStart: DateTime(2026, 10, 14, 16),
      );
      repo.items['alex/${task.key}'] = task;
      await coordinator.save(
        preference(
          type: task.type,
          id: task.id,
          frequency: ReminderFrequency.taskStart,
        ),
        task,
      );
      await settle();
      expect(scheduler.dates.values.single.hour, 15);
      repo.update(
        'alex',
        ReminderTarget(
          type: task.type,
          id: task.id,
          title: 'Task',
          taskStart: DateTime(2026, 10, 14, 18),
        ),
        task.key,
      );
      await settle();
      expect(scheduler.dates.values.single.hour, 17);
      await coordinator.save(preference(), fund);
      await settle();
      final count = scheduler.scheduled;
      scheduler.location = newYork;
      await coordinator.resume();
      expect(scheduler.scheduled, greaterThan(count));
    });
    test('bounded capacity reports unscheduled reminders without dropping preferences', () async {
      scheduler.limit = 1;
      await coordinator.save(preference(), fund);
      await settle();
      const other = ReminderTarget(
        type: ReminderTargetType.personalGoal,
        id: 'z',
        title: 'Second',
      );
      repo.items['alex/${other.key}'] = other;
      await coordinator.save(preference(id: 'z'), other);
      await settle();
      expect(scheduler.alarms.length, 1);
      expect(coordinator.status(other.key).delivery, ReminderDelivery.limit);
      expect(repo.values['alex']!.length, 2);
    });
    test(
      'expired custom reminder rejects save and never fires immediately',
      () async {
        await expectLater(
          coordinator.save(
            preference(
              frequency: ReminderFrequency.once,
              instant: DateTime.utc(2026, 10, 12),
            ),
            fund,
          ),
          throwsA(isA<ReminderFailure>()),
        );
        expect(scheduler.alarms, isEmpty);
      },
    );
  });

  test('device IDs persist across restarts and never collide across type or account', () async {
    SharedPreferences.setMockInitialValues({});
    final first = PreferenceReminderDeviceStore();
    final id = await first.idFor('alex', 'personalGoal_fund');
    expect(
      await PreferenceReminderDeviceStore().idFor('alex', 'personalGoal_fund'),
      id,
    );
    expect(await first.idFor('alex', 'task_fund'), isNot(id));
    expect(await first.idFor('jamie', 'personalGoal_fund'), isNot(id));
  });
}
