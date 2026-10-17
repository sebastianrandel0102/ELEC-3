import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shared creation seam for the existing forms and reviewed Agent actions.
/// Agent transactions require a server response and never overwrite an existing
/// ID. The original task form retains its offline-capable set semantics.
class AppRecordRepository {
  AppRecordRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : db = db ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  /// Direct user undo only. A transaction refuses edited/completed tasks and
  /// tasks with reminders; neither goals nor financial records can use this seam.
  Future<void> undoAgentTask({
    required String uid,
    required String id,
    required String operation,
    required Map<String, Object?> expected,
    required void Function() beforeWrite,
  }) async {
    if (!RegExp(r'^agent_[A-Za-z0-9_]+$').hasMatch(id)) {
      throw const FormatException('Invalid task ID');
    }
    void session() {
      if (auth.currentUser?.uid != uid) throw StateError('Account changed');
      beforeWrite();
    }

    session();
    final user = db.collection('users').doc(uid);
    final ref = user.collection('tasks').doc(id);
    await db.runTransaction((tx) async {
      session();
      final snapshot = await tx.get(ref);
      final reminder = await tx.get(
        user.collection('reminders').doc('task_$id'),
      );
      session();
      if (!snapshot.exists) return; // Idempotent explicit undo retry.
      final data = snapshot.data()!;
      final created = data['createdAt'];
      if (data['agentOperation'] != operation ||
          reminder.exists ||
          expected.entries.any((e) => data[e.key] != e.value) ||
          created is! Timestamp ||
          data['updatedAt'] != created ||
          created.toDate().isAfter(DateTime.now()) ||
          DateTime.now().difference(created.toDate()) >
              const Duration(minutes: 10)) {
        throw StateError(
          'Undo is unavailable because this task changed, has a reminder, or expired.',
        );
      }
      session();
      tx.delete(ref);
    });
    session();
  }

  Future<void> create({
    required String uid,
    required String collection,
    required String id,
    required Map<String, dynamic> data,
    String? operation,
    void Function()? beforeWrite,
  }) async {
    if (!['goals', 'tasks'].contains(collection) ||
        id.contains('/') ||
        id.isEmpty) {
      throw const FormatException('Unsupported record');
    }
    void session() {
      if (auth.currentUser?.uid != uid) throw StateError('Account changed');
    }

    session();
    final ref = db.collection('users').doc(uid).collection(collection).doc(id);
    if (collection == 'tasks' && operation == null) {
      beforeWrite?.call();
      await ref.set(data);
      session();
      return;
    }
    await db.runTransaction((tx) async {
      session();
      final existing = await tx.get(ref);
      session();
      if (existing.exists) {
        if (operation != null &&
            existing.data()?['agentOperation'] != operation) {
          throw StateError(
            'The operation changed. Review the existing record.',
          );
        }
        return;
      }
      beforeWrite?.call();
      tx.set(ref, {...data, 'agentOperation': ?operation});
    });
    session();
  }
}
