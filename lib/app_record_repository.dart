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

  Future<void> create({
    required String uid,
    required String collection,
    required String id,
    required Map<String, dynamic> data,
    String? operation,
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
      tx.set(ref, {...data, 'agentOperation': ?operation});
    });
    session();
  }
}
