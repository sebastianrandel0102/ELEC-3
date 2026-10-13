import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'profile_photo_processing.dart';

bool ownsStorageAvatarPath(String uid, String? path) =>
    path != null &&
    RegExp(
      '^users/${RegExp.escape(uid)}/profile/avatar/[A-Za-z0-9]{20}\\.jpg\$',
    ).hasMatch(path);

bool ownsFirestoreAvatarPath(String uid, String? path) =>
    path != null &&
    RegExp('^users/${RegExp.escape(uid)}/profilePhotos/[A-Za-z0-9]{20}\$')
        .hasMatch(path);

bool ownsAvatarPath(String uid, String? path) =>
    ownsFirestoreAvatarPath(uid, path) || ownsStorageAvatarPath(uid, path);

class ProfilePhotoRecord {
  const ProfilePhotoRecord({this.path, this.cleanup = const []});
  factory ProfilePhotoRecord.fromMap(Map<String, dynamic> data) =>
      ProfilePhotoRecord(
        path: data['avatarStoragePath'] is String
            ? data['avatarStoragePath'] as String
            : null,
        cleanup: data['avatarCleanupPaths'] is List
            ? (data['avatarCleanupPaths'] as List).whereType<String>().toList()
            : const [],
      );
  final String? path;
  final List<String> cleanup;
}

/// The narrow boundary makes ordering, rollback, ownership and session changes
/// testable without replacing the app's existing Firebase infrastructure.
abstract class ProfilePhotoBackend {
  String? get currentUid;
  String newPath(String uid);
  Future<void> upload(
    String path,
    Uint8List bytes,
    void Function(double) progress,
  );
  Future<ProfilePhotoRecord> read(String uid);
  Future<void> commit(String uid, String? path);
  Future<void> delete(String path);
  Future<void> acknowledgeCleanup(String uid, String path);
  Future<List<String>> stalePaths(String uid);
  Future<Uint8List?> load(String path);
}

class FirebaseProfilePhotoBackend implements ProfilePhotoBackend {
  FirebaseProfilePhotoBackend({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : auth = auth ?? FirebaseAuth.instance,
       firestore = firestore ?? FirebaseFirestore.instance,
       _storageOverride = storage;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseStorage? _storageOverride;
  // Only resolve the Storage SDK for legacy objects. Firestore avatars never
  // initialize or call a Storage bucket and require no Blaze billing plan.
  FirebaseStorage get storage => _storageOverride ?? FirebaseStorage.instance;
  @override
  String? get currentUid => auth.currentUser?.uid;
  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      firestore.collection('users').doc(uid);
  @override
  String newPath(String uid) =>
      'users/$uid/profile/avatar/${_profile(uid).collection('_ids').doc().id}.jpg';

  void _check(String uid) {
    if (currentUid != uid) {
      throw const ProfilePhotoFailure(
        'Your session changed. Please sign in again.',
      );
    }
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
            cacheControl: 'private,max-age=86400',
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
  Future<ProfilePhotoRecord> read(String uid) async {
    _check(uid);
    final snapshot = await _profile(uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    if (!snapshot.exists) {
      throw const ProfilePhotoFailure(
        'Your account profile could not be loaded.',
      );
    }
    return ProfilePhotoRecord.fromMap(snapshot.data()!);
  }

  @override
  Future<void> commit(String uid, String? path) async {
    _check(uid);
    await firestore.runTransaction(
      (transaction) async {
        final ref = _profile(uid);
        final snapshot = await transaction.get(ref);
        _check(uid);
        if (!snapshot.exists) {
          throw const ProfilePhotoFailure(
            'Your account profile could not be loaded.',
          );
        }
        if (path != null && ownsFirestoreAvatarPath(uid, path)) {
          final photo = await transaction.get(firestore.doc(path));
          if (!photo.exists) {
            throw const ProfilePhotoFailure(
              'Your photo could not be saved. Please try again.',
            );
          }
        }
        final record = ProfilePhotoRecord.fromMap(snapshot.data()!);
        final queue = record.cleanup
            .where((p) => ownsAvatarPath(uid, p))
            .toSet();
        if (record.path != path && ownsAvatarPath(uid, record.path)) {
          queue.add(record.path!);
        }
        if (queue.length > 100) {
          throw const ProfilePhotoFailure(
            'Photo maintenance is temporarily unavailable. Please try again later.',
          );
        }
        // Field updates preserve names, currency, settings and all subcollections.
        transaction.update(ref, {
          'avatarStoragePath': path ?? FieldValue.delete(),
          'avatarCleanupPaths': queue.toList(),
        });
      },
      timeout: const Duration(seconds: 20),
      maxAttempts: 3,
    );
  }

  @override
  Future<void> delete(String path) async {
    try {
      await storage.ref(path).delete().timeout(const Duration(seconds: 15));
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<void> acknowledgeCleanup(String uid, String path) async {
    _check(uid);
    await _profile(uid)
        .update({
          'avatarCleanupPaths': FieldValue.arrayRemove([path]),
        })
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<List<String>> stalePaths(String uid) async {
    _check(uid);
    final listed = await storage
        .ref('users/$uid/profile/avatar')
        .list(ListOptions(maxResults: 100))
        .timeout(const Duration(seconds: 15));
    final paths = <String>[];
    for (final ref in listed.items) {
      _check(uid);
      if (!ownsAvatarPath(uid, ref.fullPath)) continue;
      final metadata = await ref.getMetadata().timeout(
        const Duration(seconds: 15),
      );
      final created = metadata.timeCreated;
      if (created != null &&
          DateTime.now().difference(created) > const Duration(days: 1)) {
        paths.add(ref.fullPath);
      }
    }
    return paths;
  }

  @override
  Future<Uint8List?> load(String path) => storage
      .ref(path)
      .getData(ProfilePhotoLimits.legacyUploadBytes)
      .timeout(const Duration(seconds: 20));
}

/// Spark-compatible avatar storage: small binary documents in the existing
/// Firestore database, isolated from the profile document and financial data.
class FirestoreProfilePhotoBackend extends FirebaseProfilePhotoBackend {
  FirestoreProfilePhotoBackend({super.auth, super.firestore, super.storage});

  @override
  String newPath(String uid) =>
      _profile(uid).collection('profilePhotos').doc().path;

  DocumentReference<Map<String, dynamic>> _photo(String path) {
    final uid = currentUid;
    if (uid == null || !ownsFirestoreAvatarPath(uid, path)) {
      throw const ProfilePhotoFailure(
        'Please sign in again to change your photo.',
      );
    }
    return firestore.doc(path);
  }

  @override
  Future<void> upload(
    String path,
    Uint8List bytes,
    void Function(double) progress,
  ) async {
    final ref = _photo(path);
    final uid = currentUid!;
    // Transactions fail offline rather than queueing an unconfirmed photo write.
    // Firestore exposes no byte-upload progress; the UI stays indeterminate.
    await firestore.runTransaction(
      (transaction) async {
        final existing = await transaction.get(ref);
        _check(uid);
        if (existing.exists) {
          throw const ProfilePhotoFailure('Please choose your photo again.');
        }
        transaction.set(ref, {
          'bytes': Blob(bytes),
          'contentType': 'image/jpeg',
          'width': ProfilePhotoLimits.avatarEdge,
          'height': ProfilePhotoLimits.avatarEdge,
          'createdAt': FieldValue.serverTimestamp(),
        });
      },
      timeout: const Duration(seconds: 20),
      maxAttempts: 3,
    );
  }

  @override
  Future<void> delete(String path) async {
    if (ownsFirestoreAvatarPath(currentUid ?? '', path)) {
      await _photo(path).delete().timeout(const Duration(seconds: 15));
    } else if (ownsStorageAvatarPath(currentUid ?? '', path)) {
      await super.delete(path);
    } else {
      throw const ProfilePhotoFailure(
        'This photo does not belong to your account.',
      );
    }
  }

  @override
  Future<List<String>> stalePaths(String uid) async {
    _check(uid);
    final current = (await read(uid)).path;
    Query<Map<String, dynamic>> query = _profile(uid)
        .collection('profilePhotos');
    if (ownsFirestoreAvatarPath(uid, current)) {
      // Excluding the current avatar avoids downloading its bytes on every
      // maintenance scan. Only three potential orphans are read per visit.
      query = query.where(
        FieldPath.documentId,
        isNotEqualTo: current!.split('/').last,
      );
    }
    final docs = await query
        .limit(3)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    _check(uid);
    return docs.docs
        .where((doc) {
          final created = doc.data()['createdAt'];
          return created is Timestamp &&
              DateTime.now().difference(created.toDate()) >
                  const Duration(days: 1);
        })
        .map((doc) => doc.reference.path)
        .toList();
  }

  @override
  Future<Uint8List?> load(String path) async {
    if (ownsStorageAvatarPath(currentUid ?? '', path)) return super.load(path);
    final photo = await _photo(path)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    final data = photo.data();
    if (data == null) return null;
    final bytes = data['bytes'];
    if (bytes is! Blob ||
        bytes.bytes.length > ProfilePhotoLimits.uploadBytes ||
        data['contentType'] != 'image/jpeg' ||
        data['width'] != 512 ||
        data['height'] != 512) {
      throw const ProfilePhotoFailure(
        'This profile picture could not be opened.',
      );
    }
    return bytes.bytes;
  }
}

class ProfilePhotoService {
  ProfilePhotoService(this.backend);
  final ProfilePhotoBackend backend;
  bool _busy = false;
  Future<void>? _maintenance;
  final _images = <String, Future<Uint8List?>>{};

  void _check(String uid) {
    if (backend.currentUid != uid) {
      throw const ProfilePhotoFailure(
        'Please sign in again to change your photo.',
      );
    }
  }

  Future<void> save(
    String uid,
    Uint8List bytes, {
    required void Function(double) onProgress,
  }) async {
    if (_busy) {
      throw const ProfilePhotoFailure('Your photo is already being saved.');
    }
    _check(uid);
    _busy = true;
    String? path;
    var uploaded = false;
    var committed = false;
    try {
      await compute(validateProfilePhotoUpload, bytes);
      _check(uid);
      path = backend.newPath(uid);
      if (!ownsAvatarPath(uid, path)) {
        throw const ProfilePhotoFailure(
          'Unable to create a safe photo destination.',
        );
      }
      await backend.upload(path, bytes, onProgress);
      uploaded = true;
      _check(uid);
      await backend.commit(uid, path);
      committed = true;
    } catch (error) {
      _diagnosticFailure(uploaded ? 'profile update' : 'upload', error);
      // A lost response is not proof a transaction failed. Only delete the new
      // object after a SERVER read confirms that it is not the current avatar.
      if (path != null &&
          ownsAvatarPath(uid, path) &&
          backend.currentUid == uid) {
        try {
          final record = await backend.read(uid);
          if (record.path == path) {
            committed = uploaded;
          } else {
            await backend.delete(path);
          }
        } catch (_) {
          _diagnostic(
            'Deferred photo rollback; retry maintenance on next visit.',
          );
        }
      }
      if (!committed) {
        throw ProfilePhotoFailure(
          profilePhotoErrorMessage(error, duringUpload: !uploaded),
        );
      }
    } finally {
      _busy = false;
    }
    unawaited(maintain(uid));
  }

  Future<void> remove(String uid) async {
    if (_busy) {
      throw const ProfilePhotoFailure('A photo update is already in progress.');
    }
    _check(uid);
    _busy = true;
    try {
      await backend.commit(uid, null);
    } catch (error) {
      _diagnosticFailure('removal', error);
      // Do not report removal until the authoritative profile confirms it.
      var removed = false;
      try {
        removed = (await backend.read(uid)).path == null;
      } catch (_) {}
      if (!removed) throw ProfilePhotoFailure(profilePhotoErrorMessage(error));
    } finally {
      _busy = false;
    }
    unawaited(maintain(uid));
  }

  Future<void> maintain(String uid) {
    return _maintenance ??= _cleanup(uid)
        .whenComplete(() => _maintenance = null);
  }

  Future<void> _cleanup(String uid) async {
    try {
      _check(uid);
      final record = await backend.read(uid);
      final candidates = record.cleanup.toSet();
      try {
        candidates.addAll(await backend.stalePaths(uid));
      } catch (_) {
        _diagnostic('Orphan scan deferred.');
      }
      for (final path in candidates) {
        _check(uid);
        if (!ownsAvatarPath(uid, path)) continue;
        try {
          if ((await backend.read(uid)).path == path) continue;
          _check(uid);
          await backend.delete(path);
          await backend.acknowledgeCleanup(uid, path);
        } catch (_) {
          _diagnostic('Photo cleanup deferred until next visit.');
        }
      }
    } catch (_) {
      _diagnostic('Photo maintenance deferred.');
    }
  }

  Future<Uint8List?> load(String uid, String path) async {
    _check(uid);
    if (!ownsAvatarPath(uid, path)) return null;
    if (!_images.containsKey(path) && _images.length >= 4) {
      _images.remove(_images.keys.first);
    }
    final bytes = await _images.putIfAbsent(path, () => _loadValidated(path));
    _check(uid);
    return bytes;
  }

  Future<Uint8List?> _loadValidated(String path) async {
    try {
      final bytes = await backend.load(path);
      if (bytes != null) {
        await compute(
          path.contains('/profilePhotos/')
              ? validateProfilePhotoUpload
              : validateLegacyProfilePhotoDownload,
          bytes,
        );
      }
      return bytes;
    } catch (_) {
      _images.remove(path);
      rethrow;
    }
  }
}

void _diagnostic(String message) {
  if (kDebugMode) debugPrint(message);
}

void _diagnosticFailure(String operation, Object error) {
  // SDK identifiers only: never exception messages, URLs, tokens or user data.
  final reason = error is FirebaseException
      ? '${error.plugin}/${error.code}'
      : error.runtimeType.toString();
  _diagnostic('Profile photo $operation failed ($reason).');
}

String profilePhotoErrorMessage(Object error, {bool duringUpload = false}) {
  if (error is ProfilePhotoFailure) return error.message;
  if (error is TimeoutException) {
    return 'The connection timed out. Please try again.';
  }
  if (error is FirebaseException) {
    final code = error.code.replaceFirst(
      RegExp(r'^(storage|firestore|auth)/'),
      '',
    );
    return switch (code) {
      'unauthenticated' ||
      'user-token-expired' => 'Please sign in again to change your photo.',
      'unauthorized' || 'permission-denied' => 'Your photo could not be saved. Please contact support or try again later.',
      'no-default-bucket' || 'bucket-not-found' || 'project-not-found' =>
        'Photo storage is not available yet. Please contact support.',
      // Android reports HTTP 404 from a missing bucket as object-not-found.
      // Only interpret this as unavailable storage during a NEW upload; a
      // missing old avatar or user document has different recovery semantics.
      'object-not-found'
          when duringUpload && error.plugin == 'firebase_storage' =>
        'Photo storage is not available yet. Please contact support.',
      'unknown' when duringUpload => 'Your photo could not be uploaded. Check your connection or contact support.',
      'quota-exceeded' =>
        'Photo storage is temporarily unavailable. Please try again later.',
      'resource-exhausted' =>
        'The app has reached its daily data limit. Please try again later.',
      'unavailable' || 'retry-limit-exceeded' || 'network-request-failed' =>
        'Check your internet connection and try again.',
      _ => 'Your profile picture could not be updated. Please try again.',
    };
  }
  return 'Unable to update your photo. Please try again.';
}
