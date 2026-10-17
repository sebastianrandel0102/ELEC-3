import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'reminder_models.dart';

class ReminderSnapshot {
  const ReminderSnapshot(
    this.reminders, {
    this.pendingWrites = false,
    this.cached = false,
    this.invalidKeys = const [],
  });
  final List<ReminderConfiguration> reminders;
  final bool pendingWrites, cached;
  final List<String> invalidKeys;
}

abstract class ReminderRepository {
  Stream<ReminderSnapshot> watch(String uid);
  Stream<ReminderTarget?> watchTarget(String uid, ReminderConfiguration config);
  Future<ReminderTarget?> target(
    String uid,
    ReminderTargetType type,
    String id,
  );
  Future<void> save(ReminderConfiguration config);
  Future<void> remove(String uid, String key);
}

class FirestoreReminderRepository implements ReminderRepository {
  FirestoreReminderRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : db = db ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  CollectionReference<Map<String, dynamic>> records(String uid) =>
      db.collection('users').doc(uid).collection('reminders');
  DocumentReference<Map<String, dynamic>> targetRef(
    String uid,
    ReminderTargetType type,
    String id,
  ) => type == ReminderTargetType.sharedGoal
      ? db.collection('sharedGoals').doc(id)
      : db
            .collection('users')
            .doc(uid)
            .collection(type == ReminderTargetType.task ? 'tasks' : 'goals')
            .doc(id);

  void _session(String uid) {
    if (auth.currentUser?.uid != uid) {
      throw const ReminderFailure('Sign in to manage your reminders.');
    }
  }

  ReminderTarget? _target(
    String uid,
    ReminderTargetType type,
    String id,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final shared = type == ReminderTargetType.sharedGoal;
    return ReminderTarget.fromData(
      type,
      id,
      data,
      authorized:
          !shared ||
          (data['memberIds'] is List &&
              (data['memberIds'] as List).contains(uid)),
      deadline: data['deadline'] is Timestamp
          ? (data['deadline'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  Stream<ReminderSnapshot> watch(String uid) {
    _session(uid);
    return records(uid).snapshots(includeMetadataChanges: true).map((snapshot) {
      final result = <ReminderConfiguration>[];
      final invalid = <String>[];
      for (final doc in snapshot.docs) {
        try {
          final config = ReminderConfiguration.fromMap(doc.data());
          if (config.uid != uid || config.key != doc.id) {
            throw const FormatException();
          }
          result.add(config);
        } catch (_) {
          invalid.add(doc.id);
        }
      }
      return ReminderSnapshot(
        result,
        pendingWrites: snapshot.metadata.hasPendingWrites,
        cached: snapshot.metadata.isFromCache,
        invalidKeys: invalid,
      );
    });
  }

  @override
  Stream<ReminderTarget?> watchTarget(
    String uid,
    ReminderConfiguration config,
  ) {
    _session(uid);
    // The root membership list is updated atomically with the active member doc
    // by existing Save Together operations; permission errors cancel scheduling.
    return targetRef(uid, config.type, config.targetId)
        .snapshots(includeMetadataChanges: true)
        .map((s) => _target(uid, config.type, config.targetId, s.data()));
  }

  @override
  Future<ReminderTarget?> target(
    String uid,
    ReminderTargetType type,
    String id,
  ) async {
    _session(uid);
    final snapshot = await targetRef(
      uid,
      type,
      id,
    ).get(const GetOptions(source: Source.server));
    _session(uid);
    final value = _target(uid, type, id, snapshot.data());
    if (type == ReminderTargetType.sharedGoal && value != null) {
      final member = await db
          .collection('sharedGoals')
          .doc(id)
          .collection('members')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      _session(uid);
      if (member.data()?['status'] != 'active') return null;
    }
    return value;
  }

  @override
  Future<void> save(ReminderConfiguration config) async {
    _session(config.uid);
    config.validate();
    // Server rules validate ownership/membership again, including concurrent revocation.
    await records(config.uid)
        .doc(config.key)
        .set({...config.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
    _session(config.uid);
  }

  /// Agent creation is conditional: never replace a reminder edited since review.
  /// Exact replays reconcile the existing preference without another write.
  Future<void> createReviewed(
    ReminderConfiguration config, {
    void Function()? beforeWrite,
  }) async {
    _session(config.uid);
    config.validate();
    final ref = records(config.uid).doc(config.key);
    await db.runTransaction((tx) async {
      _session(config.uid);
      final current = await tx.get(ref);
      _session(config.uid);
      if (current.exists) {
        final old = ReminderConfiguration.fromMap(current.data()!);
        if (jsonEncode(old.toMap()) != jsonEncode(config.toMap())) {
          throw const ReminderFailure(
            'This reminder changed. Review it in Smart Reminders.',
          );
        }
        return;
      }
      beforeWrite?.call();
      tx.set(ref, {
        ...config.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    _session(config.uid);
  }

  @override
  Future<void> remove(String uid, String key) async {
    _session(uid);
    await records(uid).doc(key).delete();
  }
}
