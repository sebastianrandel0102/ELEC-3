import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'goal_cover_processing.dart';
import 'goal_cover_service.dart';

/// Bounded app-managed memory cache. Firestore retains its existing SDK cache
/// settings; no public download tokens or separate image files are created.
/// Session/revocation invalidation also evicts decoded Flutter image entries.
class GoalCoverCache extends ChangeNotifier {
  GoalCoverCache({required this.currentUid, required this.download});
  static GoalCoverCache? _instance;
  static GoalCoverCache? get active => _instance;
  static GoalCoverCache get instance {
    if (_instance != null) return _instance!;
    final cache = _instance = GoalCoverCache(
      currentUid: () => FirebaseAuth.instance.currentUser?.uid,
      download: (path) => path.contains('/coverPhotos/')
          ? loadFirestoreGoalCover(FirebaseFirestore.instance, path)
          : FirebaseStorage.instance
                .ref(path)
                .getData(GoalCoverLimits.uploadBytes)
                .timeout(const Duration(seconds: 20)),
    );
    var previousUid = FirebaseAuth.instance.currentUser?.uid;
    cache._auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (previousUid != user?.uid) {
        previousUid = user?.uid;
        cache.clear();
      }
    });
    return cache;
  }

  final String? Function() currentUid;
  final Future<Uint8List?> Function(String) download;
  StreamSubscription<User?>? _auth;
  static const maxBytes = 12 * 1024 * 1024;
  static const maxEntries = 24;
  final _cache = <String, Uint8List>{};
  final _inflight = <String, Future<Uint8List?>>{};
  final _providers = <String, Set<ImageProvider>>{};
  final _generations = <String, int>{};
  int _epoch = 0;
  final _sharedAccess = <String, Set<String>>{};
  int revision(String path) => _epoch * 1000000 + (_generations[path] ?? 0);
  bool canLoad(String uid, GoalCoverTarget target) =>
      currentUid() == uid &&
      (!target.shared ||
          !_sharedAccess.containsKey(uid) ||
          _sharedAccess[uid]!.contains(target.goalId));
  String _key(String uid, String path) => '$uid:$path';
  Future<Uint8List?> load(
    String uid,
    GoalCoverTarget target,
    String path,
  ) async {
    if (!canLoad(uid, target) || !target.ownsPath(path)) return null;
    final key = _key(uid, path), generation = _generations[path] ?? 0;
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    if (_inflight.containsKey(key)) return _inflight[key];
    final epoch = _epoch;
    final future = () async {
      try {
        final bytes = await download(path);
        if (epoch != _epoch ||
            currentUid() != uid ||
            generation != (_generations[path] ?? 0) ||
            bytes == null) {
          return null;
        }
        _cache[key] = bytes;
        while (_cache.length > maxEntries ||
            _cache.values.fold<int>(0, (n, b) => n + b.length) > maxBytes) {
          _evict(_cache.keys.first);
        }
        return bytes;
      } catch (_) {
        return null;
      }
    }();
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inflight[key], future)) _inflight.remove(key);
    }
  }

  void track(String uid, String path, ImageProvider provider) =>
      (_providers[_key(uid, path)] ??= {}).add(provider);
  void _evict(String key) {
    _cache.remove(key);
    for (final provider in _providers.remove(key) ?? <ImageProvider>{}) {
      unawaited(provider.evict());
    }
  }

  void forget(String uid, String path) {
    _generations[path] = (_generations[path] ?? 0) + 1;
    _evict(_key(uid, path));
    _inflight.remove(_key(uid, path));
    notifyListeners();
  }

  void retainShared(String uid, Set<String> ids) {
    _sharedAccess[uid] = ids;
    final keys = {..._cache.keys, ..._inflight.keys, ..._providers.keys};
    for (final key in keys) {
      final prefix = '$uid:sharedGoals/';
      if (key.startsWith(prefix) &&
          !ids.contains(key.substring(prefix.length).split('/').first)) {
        forget(uid, key.substring(uid.length + 1));
      }
    }
    notifyListeners();
  }

  void clear() {
    _epoch++;
    for (final key in _providers.keys.toList()) {
      _evict(key);
    }
    _cache.clear();
    _inflight.clear();
    _generations.clear();
    _sharedAccess.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _auth?.cancel();
    clear();
    super.dispose();
  }
}
