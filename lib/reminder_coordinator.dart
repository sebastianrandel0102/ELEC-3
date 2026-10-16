import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_models.dart';
import 'reminder_repository.dart';
import 'reminder_scheduler.dart';

abstract class ReminderDeviceStore {
  Future<int> idFor(String uid, String key);
  Future<String?> signature(int id);
  Future<void> setSignature(int id, String? value);
}

/// Device metadata only, never a second reminder preference repository.
/// Monotonic persisted IDs avoid hash collisions and survive account switches.
class PreferenceReminderDeviceStore implements ReminderDeviceStore {
  SharedPreferences? _prefs;
  Map<String, dynamic>? _data;
  Future<Map<String, dynamic>> _load() async {
    if (_data != null) return _data!;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString('reminder_native_ids_v1');
    _data = raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
    return _data!;
  }

  Future<void> _persist() async {
    if (!await _prefs!.setString('reminder_native_ids_v1', jsonEncode(_data))) {
      throw const ReminderFailure(
        'Could not store notification identifiers on this device.',
      );
    }
  }

  @override
  Future<int> idFor(String uid, String key) async {
    final data = await _load();
    final name = jsonEncode([uid, key]);
    final ids = (data['ids'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    if (ids[name] is int) return ids[name] as int;
    final next = (data['next'] as int? ?? 1000) + 1;
    if (next >= 2147483647) {
      throw const ReminderFailure('Notification identifier capacity reached.');
    }
    data['next'] = next;
    ids[name] = next;
    await _persist();
    return next;
  }

  @override
  Future<String?> signature(int id) async =>
      (await _load())['signature_$id'] as String?;
  @override
  Future<void> setSignature(int id, String? value) async {
    final data = await _load();
    if (value == null) {
      data.remove('signature_$id');
    } else {
      data['signature_$id'] = value;
    }
    await _persist();
  }
}

class ReminderCoordinator extends ChangeNotifier {
  ReminderCoordinator({
    required this.repository,
    required this.scheduler,
    required this.deviceStore,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final ReminderRepository repository;
  final NotificationScheduler scheduler;
  final ReminderDeviceStore deviceStore;
  final DateTime Function() clock;
  final calculator = const ReminderTimeCalculator();
  final Map<String, ReminderConfiguration> configurations = {};
  final Map<String, ReminderTarget?> targets = {};
  final Map<String, ReminderStatus> statuses = {};
  final Map<String, StreamSubscription<ReminderTarget?>> _targetSubscriptions =
      {};
  StreamSubscription<ReminderSnapshot>? _preferences;
  Future<void> _queue = Future.value();
  String? uid, error;
  bool pendingWrites = false, cached = false, loading = false;
  bool _disposed = false;
  int _generation = 0;
  tz.Location? zone;
  ReminderPayload? pendingTap;
  void Function(ReminderPayload)? onTap;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _serial(Future<void> Function() operation) {
    final next = _queue.then((_) => operation());
    _queue = next.catchError((Object e) {
      error = reminderError(e);
      _notify();
    });
    return next;
  }

  Future<void> initialize() async {
    await scheduler.initialize((payload) {
      pendingTap = payload;
      onTap?.call(payload);
      _notify();
    });
    zone = await scheduler.timezone();
  }

  Future<void> switchAccount(String? nextUid) async {
    final generation = ++_generation;
    uid = nextUid;
    configurations.clear();
    targets.clear();
    statuses.clear();
    pendingWrites = false;
    cached = false;
    error = null;
    loading = nextUid != null;
    final previousPreferences = _preferences;
    _preferences = null;
    final previousTargets = _targetSubscriptions.values.toList();
    _targetSubscriptions.clear();
    _notify();
    await _serial(() async {
      await previousPreferences?.cancel();
      for (final subscription in previousTargets) {
        await subscription.cancel();
      }
      if (generation != _generation || _disposed) return;
      // Cancel delivered notifications as well as pending alarms from old accounts.
      await scheduler.cancelAll();
      if (generation != _generation || _disposed || nextUid == null) return;
      _preferences = repository
          .watch(nextUid)
          .listen(
            (snapshot) {
              if (generation != _generation || _disposed) return;
              pendingWrites = snapshot.pendingWrites;
              cached = snapshot.cached;
              loading = false;
              error = null;
              final keys = snapshot.reminders.map((c) => c.key).toSet();
              for (final key in _targetSubscriptions.keys.toList()) {
                if (!keys.contains(key)) {
                  _targetSubscriptions.remove(key)?.cancel();
                  targets.remove(key);
                }
              }
              configurations
                ..clear()
                ..addEntries(snapshot.reminders.map((c) => MapEntry(c.key, c)));
              statuses.removeWhere((key, _) => !keys.contains(key));
              for (final key in snapshot.invalidKeys) {
                statuses[key] = const ReminderStatus(
                  ReminderDelivery.failed,
                  'Invalid saved reminder. Remove it in Smart Reminders.',
                );
              }
              for (final config in snapshot.reminders) {
                if (_targetSubscriptions.containsKey(config.key)) continue;
                _targetSubscriptions[config.key] = repository
                    .watchTarget(nextUid, config)
                    .listen(
                      (target) {
                        if (generation != _generation || _disposed) return;
                        targets[config.key] = target;
                        final current = configurations[config.key];
                        if (current?.enabled == true &&
                            (target == null || !target.available)) {
                          // Do not silently reactivate a departed member's preference on rejoin.
                          unawaited(
                            repository
                                .save(current!.withEnabled(false))
                                .catchError((Object e) {
                                  error = reminderError(e);
                                  _notify();
                                }),
                          );
                        }
                        unawaited(reconcile().catchError((Object _) {}));
                      },
                      onError: (Object failure) {
                        if (generation != _generation || _disposed) return;
                        targets[config.key] = null;
                        error = reminderError(failure);
                        unawaited(reconcile().catchError((Object _) {}));
                        final current = configurations[config.key];
                        if (current?.enabled == true &&
                            failure.toString().contains('permission-denied')) {
                          unawaited(
                            repository
                                .save(current!.withEnabled(false))
                                .catchError((Object _) {}),
                          );
                        }
                      },
                    );
              }
              _notify();
              unawaited(reconcile().catchError((Object _) {}));
            },
            onError: (Object failure) {
              if (generation != _generation || _disposed) return;
              configurations.clear();
              targets.clear();
              statuses.clear();
              loading = false;
              error = reminderError(failure);
              _notify();
              unawaited(
                _serial(() => scheduler.cancelAll()).catchError((Object _) {}),
              );
            },
          );
    });
  }

  ReminderStatus status(String key) =>
      statuses[key] ??
      const ReminderStatus(ReminderDelivery.off, 'Reminder off');

  Future<void> save(
    ReminderConfiguration config,
    ReminderTarget target, {
    Future<void> Function(ReminderConfiguration)? persist,
  }) async {
    if (uid != config.uid) {
      throw const ReminderFailure(
        'Your account changed. Open the reminder again.',
      );
    }
    config.validate();
    if (config.enabled) {
      if (!target.available) {
        throw const ReminderFailure('This item is no longer available.');
      }
      if (target.completed) {
        throw const ReminderFailure(
          'Reminders pause for completed items. Mark this item incomplete first.',
        );
      }
      // Validate future time even on web; no browser scheduling is promised.
      zone ??= await scheduler.timezone();
      if (calculator.next(config, target, zone!, clock()) == null) {
        throw const ReminderFailure('Please choose a future reminder time.');
      }
    }
    // Mobile Firestore already persists offline writes. Do not report cloud
    // confirmation while waiting; its snapshot metadata drives the sync label.
    try {
      await (persist ?? repository.save)(config)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw const ReminderFailure(
        'The reminder change is awaiting cloud confirmation. Check Smart Reminders for sync and phone scheduling status.',
      );
    }
    if (uid != config.uid) throw const ReminderFailure('Your account changed.');
    configurations[config.key] = config;
    targets[config.key] = target;
    await reconcile();
  }

  Future<void> remove(String key) async {
    final account = uid;
    if (account == null) {
      throw const ReminderFailure('Sign in to manage reminders.');
    }
    await repository.remove(account, key).timeout(const Duration(seconds: 8));
    if (uid != account) return;
    configurations.remove(key);
    targets.remove(key);
    statuses.remove(key);
    await reconcile();
  }

  Future<void> resume() async {
    try {
      zone = await scheduler.timezone();
    } catch (e) {
      zone = null;
      error = reminderError(e);
    }
    await reconcile();
  }

  Future<void> reconcile() {
    final generation = _generation;
    return _serial(() async {
      if (generation != _generation || _disposed) return;
      final account = uid;
      if (account == null) return;
      final pending = await scheduler.pending();
      if (generation != _generation) return;
      for (final entry in pending.entries) {
        final payload = ReminderPayload.decode(entry.value);
        if (payload == null ||
            payload.uid != account ||
            !configurations.containsKey(payload.key)) {
          await scheduler.cancel(entry.key);
          await deviceStore.setSignature(entry.key, null);
        }
      }
      var count = 0;
      final capabilities = <ReminderTargetType, NotificationCapability>{};
      final ordered = configurations.values.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final config in ordered) {
        if (generation != _generation || _disposed) return;
        final id = await deviceStore.idFor(account, config.key);
        Future<void> stop(ReminderStatus status) async {
          try {
            if (pending.containsKey(id) ||
                await deviceStore.signature(id) != null) {
              await scheduler.cancel(id);
              await deviceStore.setSignature(id, null);
              pending.remove(id);
            }
            statuses[config.key] = status;
          } catch (_) {
            statuses[config.key] = const ReminderStatus(
              ReminderDelivery.failed,
              'Unable to cancel the old phone reminder. Retry or disable notifications in system settings.',
            );
            rethrow;
          }
        }

        try {
          if (!config.enabled) {
            await stop(
              const ReminderStatus(ReminderDelivery.off, 'Reminder off'),
            );
            continue;
          }
          final target = targets[config.key];
          if (!targets.containsKey(config.key)) {
            await stop(
              const ReminderStatus(
                ReminderDelivery.waiting,
                'Checking item access…',
              ),
            );
            continue;
          }
          if (target == null || !target.available || target.completed) {
            await stop(
              ReminderStatus(
                ReminderDelivery.paused,
                target?.completed == true
                    ? 'Paused · item completed'
                    : 'Item unavailable · phone reminder canceled',
              ),
            );
            continue;
          }
          final capability = capabilities[config.type] ??= await scheduler
              .capability(config.type);
          if (!capability.supported) {
            await stop(
              const ReminderStatus(
                ReminderDelivery.unsupported,
                'Preference saved · phone reminders require Android or iOS',
              ),
            );
            continue;
          }
          if (!capability.allowed) {
            await stop(
              const ReminderStatus(
                ReminderDelivery.blocked,
                'Preference saved · notifications disabled in system settings',
              ),
            );
            continue;
          }
          if (zone == null) {
            throw const ReminderFailure('Device timezone unavailable.');
          }
          final date = calculator.next(config, target, zone!, clock());
          if (date == null) {
            await stop(
              const ReminderStatus(
                ReminderDelivery.expired,
                'Reminder time passed · choose a future time',
              ),
            );
            continue;
          }
          if (count >= scheduler.limit) {
            await stop(
              const ReminderStatus(
                ReminderDelivery.limit,
                'Device reminder limit reached · disable another reminder',
              ),
            );
            continue;
          }
          count++;
          final repeating = [
            ReminderFrequency.daily,
            ReminderFrequency.weekly,
          ].contains(config.frequency);
          final signature = jsonEncode([
            config.toMap(),
            zone!.name,
            capability.exact,
            config.showTitle ? target.title : '',
            repeating ? null : date.toUtc().toIso8601String(),
          ]);
          if (!pending.containsKey(id) ||
              await deviceStore.signature(id) != signature) {
            // Replace the old alarm before scheduling. A failure never leaves an
            // old time presented as successfully scheduled.
            await scheduler.cancel(id);
            if (generation != _generation) return;
            // A native exception can occur after part of an alarm was saved.
            // The failure path must still attempt to cancel that alarm.
            pending[id] = ReminderPayload(
              config.uid,
              config.type,
              config.targetId,
            ).encode();
            await scheduler.schedule(
              id,
              config,
              target,
              date,
              exact: capability.exact,
            );
            if (generation != _generation) {
              await scheduler.cancel(id);
              return;
            }
            await deviceStore.setSignature(id, signature);
          }
          statuses[config.key] = ReminderStatus(
            capability.exact
                ? ReminderDelivery.scheduled
                : ReminderDelivery.approximate,
            capability.exact
                ? 'Phone reminder scheduled'
                : 'Phone reminder scheduled · timing may be approximate',
          );
        } catch (e) {
          await stop(
            ReminderStatus(
              ReminderDelivery.failed,
              'Preference saved · unable to schedule: ${reminderError(e)}',
            ),
          );
        }
      }
      if (generation == _generation) _notify();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _preferences?.cancel();
    for (final subscription in _targetSubscriptions.values) {
      subscription.cancel();
    }
    // App shutdown retains native alarms. Auth changes explicitly cancel them.
    super.dispose();
  }
}

String reminderError(Object error) {
  if (error is ReminderFailure) return error.message;
  if (error is TimeoutException) {
    return 'Cloud confirmation is pending. Check your connection.';
  }
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Access was denied. Your membership or reminder rules may need checking.';
  }
  if (text.contains('unavailable')) {
    return 'Firebase is unavailable. Reconnect to confirm this change.';
  }
  return 'Unable to update phone reminders. Please try again.';
}
