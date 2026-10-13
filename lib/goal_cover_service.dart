import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'goal_cover_processing.dart';

class GoalCoverTarget {
  const GoalCoverTarget.personal(this.ownerUid, this.goalId) : shared = false;
  const GoalCoverTarget.shared(this.ownerUid, this.goalId) : shared = true;
  final String ownerUid, goalId;
  final bool shared;
  String get documentPath =>
      shared ? 'sharedGoals/$goalId' : 'users/$ownerUid/goals/$goalId';
  String get folder => '$documentPath/cover';
  String get photoFolder => '$documentPath/coverPhotos';
  bool ownsStoragePath(String? path) =>
      path != null &&
      RegExp('^${RegExp.escape(folder)}/[A-Za-z0-9]{20}\\.jpg\$')
          .hasMatch(path);
  bool ownsFirestorePath(String? path) =>
      path != null &&
      RegExp('^${RegExp.escape(photoFolder)}/[A-Za-z0-9]{20}\$').hasMatch(path);
  bool ownsPath(String? path) =>
      ownsFirestorePath(path) || ownsStoragePath(path);
}

class GoalCoverRecord {
  const GoalCoverRecord({this.path});
  factory GoalCoverRecord.fromMap(
    Map<String, dynamic> data,
    GoalCoverTarget target,
  ) {
    final path = data['coverStoragePath'];
    return GoalCoverRecord(
      path: path is String && target.ownsPath(path) ? path : null,
    );
  }
  final String? path;
}

abstract class GoalCoverBackend {
  String? get currentUid;
  String newPath(GoalCoverTarget target);
  Future<GoalCoverRecord> read(GoalCoverTarget target);
  Future<void> journal(GoalCoverTarget target, String path);
  Future<void> upload(
    String path,
    Uint8List bytes,
    void Function(double) progress,
  );
  Future<void> commit(
    GoalCoverTarget target,
    String? expectedPath,
    String? path,
  );

  /// Must independently verify that the path is unreferenced before deletion.
  Future<void> cleanup(GoalCoverTarget target, String path);
}

class FirebaseGoalCoverBackend implements GoalCoverBackend {
  FirebaseGoalCoverBackend({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : auth = auth ?? FirebaseAuth.instance,
       db = firestore ?? FirebaseFirestore.instance,
       _storageOverride = storage;
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final FirebaseStorage? _storageOverride;
  // Compact covers never initialize or contact the legacy Storage bucket.
  FirebaseStorage get storage => _storageOverride ?? FirebaseStorage.instance;
  @override
  String? get currentUid => auth.currentUser?.uid;
  DocumentReference<Map<String, dynamic>> _goal(GoalCoverTarget target) =>
      db.doc(target.documentPath);
  DocumentReference<Map<String, dynamic>> _journal(
    GoalCoverTarget target,
    String path,
  ) => db
      .collection('users')
      .doc(target.ownerUid)
      .collection('goalCoverUploads')
      .doc(path.split('/').last.split('.').first);
  void _check(GoalCoverTarget target) {
    if (currentUid != target.ownerUid) {
      throw const GoalCoverFailure(
        'Your session changed. Sign in as the goal owner to manage its photo.',
      );
    }
  }

  void _exists(
    GoalCoverTarget target,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) {
      throw const GoalCoverFailure('This goal is no longer available.');
    }
    if (target.shared && snapshot.data()!['ownerId'] != target.ownerUid) {
      throw const GoalCoverFailure(
        'Only the shared goal owner can change its cover.',
      );
    }
  }

  @override
  String newPath(GoalCoverTarget target) =>
      '${target.folder}/${db.collection('_coverIds').doc().id}.jpg';
  @override
  Future<GoalCoverRecord> read(GoalCoverTarget target) async {
    _check(target);
    final snapshot = await _goal(target)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    _check(target);
    _exists(target, snapshot);
    return GoalCoverRecord.fromMap(snapshot.data()!, target);
  }

  @override
  Future<void> journal(GoalCoverTarget target, String path) async {
    _check(target);
    await _journal(target, path)
        .set({
          'goalId': target.goalId,
          'shared': target.shared,
          'storagePath': path,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<void> upload(
    String path,
    Uint8List bytes,
    void Function(double) progress,
  ) async {
    final task = storage
        .ref(path)
        .putData(
          bytes,
          SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'private,no-store',
          ),
        );
    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        progress(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    }, onError: (Object _) {});
    try {
      await task.timeout(const Duration(seconds: 90));
    } on TimeoutException {
      await task.cancel();
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> commit(
    GoalCoverTarget target,
    String? expectedPath,
    String? path,
  ) async {
    _check(target);
    await db.runTransaction(
      (tx) async {
        final snapshot = await tx.get(_goal(target));
        _check(target);
        _exists(target, snapshot);
        final record = GoalCoverRecord.fromMap(snapshot.data()!, target);
        if (record.path != expectedPath) {
          throw const GoalCoverFailure(
            'The cover changed on another device. Refresh and try again.',
          );
        }
        if (path != null) {
          if (!target.ownsPath(path)) {
            throw const GoalCoverFailure('The cover destination is invalid.');
          }
          if (target.ownsFirestorePath(path) &&
              !(await tx.get(db.doc(path))).exists) {
            throw const GoalCoverFailure(
              'The photo could not be confirmed. Please try again.',
            );
          }
          _check(target);
        }
        tx.update(_goal(target), {
          'coverStoragePath': path ?? FieldValue.delete(),
          'coverUpdatedAt': FieldValue.serverTimestamp(),
        });
      },
      timeout: const Duration(seconds: 20),
      maxAttempts: 3,
    );
  }

  @override
  Future<void> cleanup(GoalCoverTarget target, String path) async {
    _check(target);
    if (!target.ownsPath(path)) return;
    final snapshot = await _goal(target)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    _check(target);
    if (snapshot.exists) {
      _exists(target, snapshot);
      if (snapshot.data()!['coverStoragePath'] == path) return;
    }
    // Photo rules also reject deletion of the current cover, closing the race
    // between this read and a concurrent metadata commit.
    if (target.ownsFirestorePath(path)) {
      await db.doc(path).delete().timeout(const Duration(seconds: 15));
    } else {
      try {
        await storage.ref(path).delete().timeout(const Duration(seconds: 15));
      } on FirebaseException catch (error) {
        if (error.code.replaceFirst('storage/', '') != 'object-not-found') {
          rethrow;
        }
      }
    }
    await _journal(target, path).delete().timeout(const Duration(seconds: 15));
  }

  /// Journals survive crashes and can be swept on any device for this owner.
  /// A grace period avoids deleting an upload still running on another device.
  Future<void> maintain() async {
    final uid = currentUid;
    if (uid == null) return;
    final entries = await db
        .collection('users')
        .doc(uid)
        .collection('goalCoverUploads')
        .where(
          'createdAt',
          isLessThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
        )
        .orderBy('createdAt')
        .limit(100)
        .get(const GetOptions(source: Source.server));
    for (final entry in entries.docs) {
      if (currentUid != uid) return;
      final data = entry.data();
      if (data['goalId'] is! String || data['storagePath'] is! String) continue;
      final target = data['shared'] == true
          ? GoalCoverTarget.shared(uid, data['goalId'] as String)
          : GoalCoverTarget.personal(uid, data['goalId'] as String);
      try {
        await cleanup(target, data['storagePath'] as String);
      } catch (_) {
        /* retry next session */
      }
    }
  }
}

/// Spark-compatible covers, isolated from financial and goal snapshots.
class FirestoreGoalCoverBackend extends FirebaseGoalCoverBackend {
  FirestoreGoalCoverBackend({super.auth, super.firestore, super.storage});

  @override
  String newPath(GoalCoverTarget target) =>
      _goal(target).collection('coverPhotos').doc().path;

  GoalCoverTarget _target(String path) {
    final uid = currentUid;
    if (uid != null) {
      final parts = path.split('/');
      final GoalCoverTarget? target =
          parts.length == 6 &&
              parts[0] == 'users' &&
              parts[1] == uid &&
              parts[2] == 'goals'
          ? GoalCoverTarget.personal(uid, parts[3])
          : parts.length == 4 && parts[0] == 'sharedGoals'
          ? GoalCoverTarget.shared(uid, parts[1])
          : null;
      if (target != null && target.ownsFirestorePath(path)) return target;
    }
    throw const GoalCoverFailure(
      'Sign in as the goal owner to manage its cover.',
    );
  }

  @override
  Future<void> upload(
    String path,
    Uint8List bytes,
    void Function(double) progress,
  ) async {
    final target = _target(path);
    final compact = await compactGoalCover(bytes);
    _check(target);
    // Transactions fail offline instead of queueing an unconfirmed photo write.
    // Firestore provides no transfer progress, so the UI stays indeterminate.
    await db.runTransaction(
      (tx) async {
        final goal = await tx.get(_goal(target));
        final existing = await tx.get(db.doc(path));
        _check(target);
        _exists(target, goal);
        if (existing.exists) {
          throw const GoalCoverFailure('Please choose your photo again.');
        }
        tx.set(db.doc(path), {
          'bytes': Blob(compact),
          'contentType': 'image/jpeg',
          'width': GoalCoverLimits.firestoreWidth,
          'height': GoalCoverLimits.firestoreHeight,
          'createdAt': FieldValue.serverTimestamp(),
        });
      },
      timeout: const Duration(seconds: 20),
      maxAttempts: 3,
    );
  }
}

Future<Uint8List?> loadFirestoreGoalCover(
  FirebaseFirestore db,
  String path,
) async {
  final photo = await db
      .doc(path)
      .get(const GetOptions(source: Source.server))
      .timeout(const Duration(seconds: 20));
  final data = photo.data();
  if (data == null) return null;
  final blob = data['bytes'];
  if (blob is! Blob ||
      data['contentType'] != 'image/jpeg' ||
      data['width'] != GoalCoverLimits.firestoreWidth ||
      data['height'] != GoalCoverLimits.firestoreHeight) {
    throw const GoalCoverFailure('This goal photo could not be opened.');
  }
  await validateCompactGoalCover(blob.bytes);
  return blob.bytes;
}

class GoalCoverService {
  GoalCoverService(this.backend);
  final GoalCoverBackend backend;
  static final Set<String> _busy = {};
  bool isBusy(GoalCoverTarget target) => _busy.contains(target.documentPath);
  void _check(GoalCoverTarget target) {
    if (backend.currentUid != target.ownerUid) {
      throw const GoalCoverFailure(
        'Sign in as the goal owner to manage its cover.',
      );
    }
  }

  Future<void> replace(
    GoalCoverTarget target,
    Uint8List bytes, {
    void Function(double)? onProgress,
  }) async {
    _check(target);
    if (!_busy.add(target.documentPath)) {
      throw const GoalCoverFailure('A cover update is already in progress.');
    }
    String? uploaded;
    String? previous;
    var duringUpload = false;
    try {
      await validateGoalCoverUpload(bytes);
      final before = await backend.read(target);
      previous = before.path;
      _check(target);
      uploaded = backend.newPath(target);
      if (!target.ownsPath(uploaded)) {
        throw const GoalCoverFailure('The cover destination is invalid.');
      }
      await backend.journal(target, uploaded);
      _check(target);
      duringUpload = true;
      await backend.upload(uploaded, bytes, onProgress ?? (_) {});
      duringUpload = false;
      _check(target);
      await backend.commit(target, before.path, uploaded);
      if (before.path != null) await _cleanup(target, before.path!);
    } catch (error) {
      if (uploaded != null && backend.currentUid == target.ownerUid) {
        try {
          if ((await backend.read(target)).path == uploaded) {
            if (previous != null) await _cleanup(target, previous);
            return; // Confirmed an otherwise ambiguous transaction response.
          }
        } catch (_) {
          /* leave journal until the server can confirm */
        }
      }
      // A timed-out commit may already have succeeded. Cleanup checks the
      // authoritative server reference and never blindly removes this upload.
      if (uploaded != null) await _cleanup(target, uploaded);
      if (duringUpload && error is FirebaseException) {
        throw GoalCoverFailure(goalCoverError(error, duringUpload: true));
      }
      rethrow;
    } finally {
      _busy.remove(target.documentPath);
    }
  }

  Future<void> remove(GoalCoverTarget target) async {
    _check(target);
    if (!_busy.add(target.documentPath)) {
      throw const GoalCoverFailure('A cover update is already in progress.');
    }
    try {
      final record = await backend.read(target);
      _check(target);
      if (record.path == null) return;
      await backend.commit(target, record.path, null);
      await _cleanup(target, record.path!);
    } finally {
      _busy.remove(target.documentPath);
    }
  }

  Future<void> _cleanup(GoalCoverTarget target, String path) async {
    try {
      _check(target);
      await backend.cleanup(target, path);
    } catch (_) {
      /* durable journal retains retry */
    }
  }
}

String goalCoverError(Object error, {bool duringUpload = false}) {
  if (error is GoalCoverFailure) return error.message;
  if (error is TimeoutException) {
    return 'Could not confirm the cover update. Reconnect and check the goal before retrying.';
  }
  if (error is FirebaseException) {
    final code = error.code.replaceFirst('storage/', '');
    return switch (code) {
      'unauthenticated' ||
      'user-token-expired' => 'Please sign in again to manage the cover.',
      'unauthorized' || 'permission-denied' => 'Cover access was denied. Check your goal permissions and deployed photo rules.',
      'no-default-bucket' || 'bucket-not-found' || 'project-not-found' => 'Goal photo storage is not enabled for this app. The app administrator needs to create its Firebase Storage bucket and deploy the photo rules.',
      'object-not-found'
          when duringUpload && error.plugin == 'firebase_storage' =>
        'Goal photo storage is unavailable for this project. Its Firebase Storage bucket must be enabled before photos can be saved. Your goal and previous cover have been kept.',
      'object-not-found' => 'The cover or photo storage is unavailable. Check your connection or contact support.',
      'not-found' when error.plugin == 'cloud_firestore' => 'This goal is no longer available. Refresh your goals before trying again.',
      'unavailable' || 'retry-limit-exceeded' || 'network-request-failed' =>
        'Check your internet connection and try again.',
      'quota-exceeded' || 'resource-exhausted' =>
        'Photo storage is temporarily unavailable. Please try again later.',
      _ => 'The cover could not be saved. Please try again.',
    };
  }
  return 'The cover could not be saved. Please choose another photo or try again.';
}
