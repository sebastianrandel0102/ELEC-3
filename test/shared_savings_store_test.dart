import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/shared_savings_store.dart';

// Capture the real store's transaction payload, not a duplicate implementation.
// Authorization and transforms are independently exercised in the rules emulator.
class StoreAuth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => StoreUser();
}

class StoreUser extends Fake implements User {
  @override
  String get uid => 'owner';
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      StoreToken();
}

class StoreToken extends Fake implements IdTokenResult {
  @override
  Map<String, dynamic> get claims => {'name': 'Owner'};
}

// Test-only payload recorder for the SDK's sealed reference interface.
// ignore: subtype_of_sealed_class
class StoreDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  StoreDocument(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      StoreCollection('$path/$collectionPath');
}

// ignore: subtype_of_sealed_class
class StoreCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  StoreCollection(this.path);
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      StoreDocument('${this.path}/${path ?? 'generated_goal_id'}');
}

// ignore: subtype_of_sealed_class
class StoreSnapshot<T> extends Fake implements DocumentSnapshot<T> {
  StoreSnapshot(this.value);
  final T? value;
  @override
  T? data() => value;
}

class StoreTransaction extends Fake implements Transaction {
  StoreTransaction(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  final writes = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async {
    expect(
      writes,
      isEmpty,
      reason: 'Firestore transactions require all reads before writes.',
    );
    return StoreSnapshot<T>(documents[ref.path] as T?);
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    writes[ref.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }
}

class StoreFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{
    'sharedGoals/goal_1234567890123': {
      'ownerId': 'owner',
      'memberIds': ['owner'],
      'status': 'active',
      'name': 'Group',
      'ownerName': 'Owner',
      'targetAmount': 1000,
    },
    'sharedGoals/goal_1234567890123/members/owner': {'status': 'active'},
  };
  late StoreTransaction last;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      StoreDocument(path);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      StoreCollection(path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    last = StoreTransaction(documents);
    return handler(last);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const requestId = 'request_1234567890123';
  const goalId = 'goal_1234567890123';
  const receiptPath = 'sharedOperations/owner/requests/$requestId';

  test(
    'owner invite uses a server timestamp with no device-derived expiry',
    () async {
      final db = StoreFirestore();
      final result = await SharedSavingsStore(
        db,
        StoreAuth(),
      ).execute('invite', {'goalId': goalId}, requestId);
      final code = result['token'] as String;
      final invitation = db.last.writes['sharedInvitations/$code']!;
      expect(code, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(invitation.containsKey('expiresAt'), isFalse);
      expect(invitation['createdAt'], FieldValue.serverTimestamp());
      expect(invitation['createdBy'], 'owner');
      expect(db.last.writes['sharedInviteLimits/owner']!['lastCode'], code);
      expect(db.last.writes[receiptPath]!['result'], result);
      expect(db.last.writes.length, 3);
    },
  );

  test('retry returns its original code without issuing or charging another invitation', () async {
    final db = StoreFirestore();
    final store = SharedSavingsStore(db, StoreAuth());
    final original = await store.execute('invite', {
      'goalId': goalId,
    }, requestId);
    db.documents[receiptPath] = db.last.writes[receiptPath]!;
    final retried = await store.execute('invite', {
      'goalId': goalId,
    }, requestId);
    expect(retried, original);
    expect(db.last.writes, isEmpty);
  });

  test('a contributor cannot issue a code through the client store', () async {
    final db = StoreFirestore();
    db.documents['sharedGoals/$goalId']!['ownerId'] = 'another-owner';
    await expectLater(
      SharedSavingsStore(
        db,
        StoreAuth(),
      ).execute('invite', {'goalId': goalId}, requestId),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.message,
          'message',
          contains('Only the owner'),
        ),
      ),
    );
    expect(db.last.writes, isEmpty);
  });
}
