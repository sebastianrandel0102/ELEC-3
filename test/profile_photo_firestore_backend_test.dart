// Firestore sealed interfaces are implemented only as isolated SDK test doubles.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/profile_photo_service.dart';
import 'package:myproject/profile_photo_processing.dart';

import 'profile_photo_test.dart' show fixture;

const photoPath = 'users/owner/profilePhotos/FFFFFFFFFFFFFFFFFFFF';

class PhotoUser extends Fake implements User {
  PhotoUser(this.uid);
  @override
  final String uid;
}

class PhotoAuth extends Fake implements FirebaseAuth {
  User? session = PhotoUser('owner');
  @override
  User? get currentUser => session;
}

class PhotoDatabase extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{
    'users/owner': {
      'displayName': 'Jamie',
      'preferredCurrencyCode': 'USD',
      'notifications': true,
    },
  };
  final reads = <(String, Source?)>[];
  final writes = <(String, Map<String, dynamic>)>[];
  final deletions = <String>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      PhotoCollection(this, path);
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      PhotoReference(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = PhotoTransaction(this);
    final result = await handler(transaction);
    for (final (path, values) in transaction.staged) {
      writes.add((path, values));
      final next = Map<String, dynamic>.from(documents[path] ?? {});
      for (final entry in values.entries) {
        if (entry.value is FieldValue && entry.key == 'avatarStoragePath') {
          next.remove(entry.key);
        } else if (entry.value is FieldValue && entry.key == 'createdAt') {
          next[entry.key] = Timestamp.now();
        } else {
          next[entry.key] = entry.value;
        }
      }
      documents[path] = next;
    }
    return result;
  }
}

class PhotoCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  PhotoCollection(this.database, this.path);
  final PhotoDatabase database;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      PhotoReference(database, '$path/${id ?? 'FFFFFFFFFFFFFFFFFFFF'}');
}

class PhotoReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  PhotoReference(this.database, this.path);
  final PhotoDatabase database;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      PhotoCollection(database, '$path/$name');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    database.reads.add((path, options?.source));
    return PhotoSnapshot(database.documents[path]);
  }

  @override
  Future<void> delete() async {
    database.deletions.add(path);
    database.documents.remove(path);
  }
}

class PhotoSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  PhotoSnapshot(this.values);
  final Map<String, dynamic>? values;
  @override
  bool get exists => values != null;
  @override
  Map<String, dynamic>? data() => values;
}

class PhotoTransaction extends Fake implements Transaction {
  PhotoTransaction(this.database);
  final PhotoDatabase database;
  final staged = <(String, Map<String, dynamic>)>[];
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async =>
      PhotoSnapshot(database.documents[reference.path]) as DocumentSnapshot<T>;
  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    staged.add((reference.path, Map<String, dynamic>.from(data as Map)));
    return this;
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    staged.add((reference.path, Map<String, dynamic>.from(data)));
    return this;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Firestore adapter uploads real bytes without initializing Firebase Storage or inventing progress', () async {
    final database = PhotoDatabase();
    final backend = FirestoreProfilePhotoBackend(
      auth: PhotoAuth(),
      firestore: database,
    );
    final avatar = await cropProfilePhoto(
      await prepareProfilePhoto(fixture()),
      const ProfilePhotoCrop(),
    );
    final path = backend.newPath('owner');
    expect(path, photoPath);
    final progress = <double>[];
    await backend.upload(path, avatar, progress.add);
    expect(progress, isEmpty);
    expect(database.documents[path]!['bytes'], isA<Blob>());
    expect((database.documents[path]!['bytes'] as Blob).bytes, avatar);
    expect(database.documents[path]!['createdAt'], isA<Timestamp>());
    await backend.commit('owner', path);
    expect(database.documents['users/owner']!['avatarStoragePath'], path);
    expect(database.writes.last.$2.keys.toSet(), {
      'avatarStoragePath',
      'avatarCleanupPaths',
    });
    expect(database.documents['users/owner']!['preferredCurrencyCode'], 'USD');
    expect(database.documents['users/owner']!['notifications'], true);
    expect(await backend.load(path), avatar);
    expect(database.reads.last, (path, Source.server));
  });
  test('Firestore adapter rejects missing referenced photos and immutable object replacement', () async {
    final database = PhotoDatabase();
    final backend = FirestoreProfilePhotoBackend(
      auth: PhotoAuth(),
      firestore: database,
    );
    await expectLater(
      backend.commit('owner', photoPath),
      throwsA(isA<ProfilePhotoFailure>()),
    );
    expect(database.writes, isEmpty);
    database.documents[photoPath] = {'existing': true};
    await expectLater(
      backend.upload(photoPath, fixture(), (_) {}),
      throwsA(isA<ProfilePhotoFailure>()),
    );
    expect(database.documents[photoPath], {'existing': true});
  });
  test(
    'Firestore adapter refuses unauthenticated and foreign document paths',
    () async {
      final auth = PhotoAuth();
      final database = PhotoDatabase();
      final backend = FirestoreProfilePhotoBackend(
        auth: auth,
        firestore: database,
      );
      final foreign = photoPath.replaceFirst('/owner/', '/other/');
      await expectLater(
        backend.upload(foreign, fixture(), (_) {}),
        throwsA(isA<ProfilePhotoFailure>()),
      );
      await expectLater(
        backend.delete(foreign),
        throwsA(isA<ProfilePhotoFailure>()),
      );
      auth.session = null;
      await expectLater(
        backend.load(photoPath),
        throwsA(isA<ProfilePhotoFailure>()),
      );
      expect(database.writes, isEmpty);
      expect(database.deletions, isEmpty);
    },
  );
  test('Firestore removal clears only the reference before deleting the owned photo', () async {
    final database = PhotoDatabase();
    final backend = FirestoreProfilePhotoBackend(
      auth: PhotoAuth(),
      firestore: database,
    );
    database.documents[photoPath] = {'existing': true};
    database.documents['users/owner']!['avatarStoragePath'] = photoPath;
    await backend.commit('owner', null);
    expect(
      database.documents['users/owner']!.containsKey('avatarStoragePath'),
      false,
    );
    expect(database.documents['users/owner']!['avatarCleanupPaths'], [
      photoPath,
    ]);
    await backend.delete(photoPath);
    expect(database.deletions, [photoPath]);
    expect(database.documents['users/owner']!['displayName'], 'Jamie');
  });
}
