import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../smart_task_recommendation_service.dart';
import 'widget_bridge.dart';
import 'widget_data_source.dart';
import 'widget_models.dart';

class HomeWidgetController extends ChangeNotifier {
  HomeWidgetController({
    required this.bridge,
    required this.source,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final HomeWidgetBridge bridge;
  final WidgetDataSource source;
  final DateTime Function() clock;
  List<HomeWidgetInstance> instances = [];
  String? uid, error;
  final Map<String, WidgetGoalFacts?> _goals = {};
  final Map<String, StreamSubscription<WidgetGoalFacts?>> _goalSubscriptions =
      {};
  final Map<String, Object> _goalEpochs = {};
  final Map<String, String?> _thumbnails = {};
  final Set<int> _dirty = {};
  StreamSubscription<WidgetPlannerFacts>? _plannerSubscription;
  Object? _plannerEpoch;
  WidgetPlannerFacts? _planner;
  String? _day;
  Timer? _debounce;
  int _generation = 0;
  int _loadRevision = 0;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> switchAccount(String? nextUid) async {
    final generation = ++_generation;
    uid = nextUid;
    _debounce?.cancel();
    final old = _goalSubscriptions.values.toList();
    _goalSubscriptions.clear();
    _goalEpochs.clear();
    final oldPlanner = _plannerSubscription;
    _plannerSubscription = null;
    _plannerEpoch = null;
    _goals.clear();
    _thumbnails.clear();
    _planner = null;
    _day = null;
    instances = [];
    _dirty.clear();
    _notify();
    // Clear private native content before waiting for old subscriptions.
    await bridge.setSession(nextUid);
    for (final subscription in old) {
      await subscription.cancel();
    }
    await oldPlanner?.cancel();
    if (_disposed || generation != _generation || nextUid == null) return;
    await reload();
  }

  Future<void> reload() async {
    final generation = _generation;
    final loadRevision = ++_loadRevision;
    final found = await bridge.instances();
    if (_disposed ||
        generation != _generation ||
        loadRevision != _loadRevision) {
      return;
    }
    instances = found;
    _reconcile();
    _mark(instances.map((i) => i.id));
    _notify();
  }

  HomeWidgetInstance? instance(int id) {
    for (final item in instances) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _reconcile() {
    final owner = uid;
    if (owner == null) return;
    final generation = _generation;
    final configs = instances
        .map((i) => i.config)
        .whereType<HomeWidgetConfig>()
        .where((c) => c.uid == owner)
        .toList();
    final refs = {
      for (final c in configs)
        if (c.goal != null && c.privacy != WidgetPrivacy.hidden)
          c.goal!.key: c.goal!,
    };
    for (final key in _goalSubscriptions.keys.toList()) {
      if (!refs.containsKey(key)) {
        unawaited(_goalSubscriptions.remove(key)!.cancel());
        _goalEpochs.remove(key);
        _goals.remove(key);
        _thumbnails.removeWhere((path, _) => path.startsWith('$key:'));
      }
    }
    for (final entry in refs.entries) {
      if (_goalSubscriptions.containsKey(entry.key)) continue;
      final epoch = Object();
      _goalEpochs[entry.key] = epoch;
      _goalSubscriptions[entry.key] = source
          .watchGoal(owner, entry.value)
          .listen(
            (facts) {
              if (_disposed ||
                  generation != _generation ||
                  _goalEpochs[entry.key] != epoch) {
                return;
              }
              _goals[entry.key] = facts;
              _thumbnails.removeWhere(
                (path, _) =>
                    path.startsWith('${entry.key}:') &&
                    path != '${entry.key}:${facts?.coverPath}',
              );
              _markGoal(entry.key);
            },
            onError: (Object _) {
              if (_disposed ||
                  generation != _generation ||
                  _goalEpochs[entry.key] != epoch) {
                return;
              }
              _goalEpochs.remove(entry.key);
              unawaited(_goalSubscriptions.remove(entry.key)?.cancel());
              _goals[entry.key] = null;
              _thumbnails.removeWhere(
                (path, _) => path.startsWith('${entry.key}:'),
              );
              // Revocation invalidates the payload promptly, without the debounce.
              _markGoal(entry.key);
              unawaited(flush());
            },
          );
    }
    final day = SmartTaskRecommendationService.dateKey(clock());
    final needsPlanner = configs.any(
      (c) => c.needsPlanner && c.privacy != WidgetPrivacy.hidden,
    );
    if (!needsPlanner || day != _day) {
      unawaited(_plannerSubscription?.cancel());
      _plannerSubscription = null;
      _plannerEpoch = null;
      _planner = null;
      _day = day;
    }
    if (needsPlanner && _plannerSubscription == null) {
      final epoch = Object();
      _plannerEpoch = epoch;
      _plannerSubscription = source
          .watchPlanner(owner, day)
          .listen(
            (facts) {
              if (_disposed ||
                  generation != _generation ||
                  facts.day != _day ||
                  _plannerEpoch != epoch) {
                return;
              }
              _planner = facts;
              _markPlanner();
            },
            onError: (Object _) {
              if (_disposed ||
                  generation != _generation ||
                  _plannerEpoch != epoch) {
                return;
              }
              _plannerEpoch = null;
              unawaited(_plannerSubscription?.cancel());
              _plannerSubscription = null;
              _planner = null;
              _markPlanner();
              unawaited(flush());
            },
          );
    }
  }

  void checkDate() {
    if (_day != SmartTaskRecommendationService.dateKey(clock())) {
      _reconcile();
      _markPlanner();
    }
  }

  void _markGoal(String key) => _mark(
    instances.where((i) => i.config?.goal?.key == key).map((i) => i.id),
  );
  void _markPlanner() => _mark(
    instances.where((i) => i.config?.needsPlanner == true).map((i) => i.id),
  );
  void _mark(Iterable<int> ids) {
    _dirty.addAll(ids);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 180),
      () => unawaited(flush()),
    );
  }

  Future<void> flush() async {
    final owner = uid, generation = _generation;
    if (owner == null || _disposed) return;
    final ids = _dirty.toSet();
    _dirty.clear();
    final snapshots = <HomeWidgetSnapshot>[];
    for (final item in instances.where((i) => ids.contains(i.id))) {
      final config = item.config;
      if (config == null || config.uid != owner) continue;
      final goal = _goals[config.goal?.key];
      final snapshot = HomeWidgetSnapshot.build(
        config: config,
        now: clock(),
        goal: goal,
        planner: _planner,
      );
      if (config.showCover &&
          config.privacy == WidgetPrivacy.full &&
          goal?.coverPath != null) {
        final key = '${goal!.ref.key}:${goal.coverPath}';
        if (_thumbnails.containsKey(key)) {
          if (_thumbnails[key] != null) {
            snapshot.data['thumbnail'] = _thumbnails[key];
          }
        } else {
          _thumbnails[key] = null;
          unawaited(
            source
                .thumbnail(owner, goal)
                .then((bytes) {
                  if (_disposed ||
                      generation != _generation ||
                      _goals[goal.ref.key]?.coverPath != goal.coverPath) {
                    return;
                  }
                  _thumbnails[key] = bytes == null ? null : base64Encode(bytes);
                  if (bytes != null) _markGoal(goal.ref.key);
                })
                .catchError((Object _) {}),
          );
        }
      }
      snapshots.add(snapshot);
    }
    if (generation != _generation || _disposed) return;
    try {
      await bridge.publish(owner, snapshots);
      error = null;
    } catch (_) {
      error = 'Widgets could not refresh. Open Home Screen Widgets to retry.';
    }
    _notify();
  }

  Future<void> save(HomeWidgetConfig config) async {
    if (uid != config.uid) throw StateError('Your session changed.');
    final saved = await bridge.save(config);
    if (uid != saved.uid) throw StateError('Your session changed.');
    await reload();
    // Publish a privacy-safe initial state before returning RESULT_OK.
    _dirty.add(saved.id);
    await flush();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    for (final subscription in _goalSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    unawaited(_plannerSubscription?.cancel());
    super.dispose();
  }
}
