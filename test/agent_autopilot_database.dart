// In-memory SDK boundary double for production repository integration tests.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ai_coach_firestore_test.dart' show ContextDb, ContextSnapshot;

class AutopilotDatabase extends ContextDb {
  int writes = 0;
  Future<void> Function()? beforeTransactionRead;
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final result = await handler(transaction);
    for (final commit in transaction.commits) {
      commit();
    }
    return result;
  }
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.db);
  final AutopilotDatabase db;
  final commits = <void Function()>[];
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async {
    await db.beforeTransactionRead?.call();
    return ContextSnapshot(ref.path.split('/').last, db.documents[ref.path])
        as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    commits.add(() {
      final timestamp = Timestamp.now();
      db.documents[ref.path] = Map<String, dynamic>.from(data as Map)
          .map((k, v) => MapEntry(k, v is FieldValue ? timestamp : v));
      db.writes++;
    });
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    commits.add(() {
      db.documents.remove(ref.path);
      db.writes++;
    });
    return this;
  }
}
