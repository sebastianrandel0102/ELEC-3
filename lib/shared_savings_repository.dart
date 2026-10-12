import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'shared_savings_models.dart';
import 'currency_money.dart';
import 'shared_savings_store.dart';

class SharedSavingsFailure implements Exception {
  const SharedSavingsFailure(this.message);
  final String message;
}

String sharedSavingsError(Object error) {
  if (error is SharedSavingsFailure) return error.message;
  if (error is CurrencyFailure) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'unauthenticated' => 'Sign in again to use Save Together.',
      'permission-denied' => 'Firebase denied this request. Your access may have changed. Refresh and try again.',
      'unavailable' || 'deadline-exceeded' => 'Could not confirm the operation. Check your connection, then retry with the same values.',
      'not-found' => 'The goal or invitation is unavailable.',
      'resource-exhausted' =>
        error.message ?? 'Please wait before trying again.',
      'failed-precondition' ||
      'invalid-argument' ||
      'already-exists' => error.message ?? 'Review the values and try again.',
      _ => 'Save Together could not complete this operation. Check your connection and try again.',
    };
  }
  return 'Could not complete this operation. Please try again.';
}

/// Extends the existing Firebase integration only for shared collections.
class SharedSavingsRepository {
  SharedSavingsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : firestore = firestore ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  FirebaseFirestore get db => firestore;
  String newRequestId() => operationId();
  Stream<List<SharedSavingsGoal>> goals() => watchGoals();
  Stream<List<SharedGoalMember>> members(String id) => watchMembers(id);
  Stream<List<SharedGoalInvitation>> invitations(String id) =>
      watchInvitations(id);
  Query<Map<String, dynamic>> activity(String id) =>
      goal(id)
          .collection('transactions')
          .orderBy('createdAt', descending: true);
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> payload, {
    required String requestId,
  }) => execute(action, payload, requestId: requestId);
  String get uid => auth.currentUser!.uid;
  String get displayName => auth.currentUser?.displayName ?? 'SaveTrack member';
  String operationId() => SharedSavingsStore.randomId();
  DocumentReference<Map<String, dynamic>> goal(String id) =>
      firestore.collection('sharedGoals').doc(id);

  Stream<List<SharedSavingsGoal>> watchGoals() => firestore
      .collection('sharedGoals')
      .where('memberIds', arrayContains: uid)
      .snapshots(includeMetadataChanges: true)
      .map(
        (s) => s.docs.map((d) => SharedSavingsGoal(d.id, d.data())).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
      );
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGoal(String id) =>
      goal(id).snapshots(includeMetadataChanges: true);
  Stream<List<SharedGoalMember>> watchMembers(String id) => goal(id)
      .collection('members')
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((s) => s.docs.map((d) => SharedGoalMember(d.id, d.data())).toList());
  Stream<List<SharedGoalInvitation>> watchInvitations(String id) => firestore
      .collection('sharedInvitations')
      .where('createdBy', isEqualTo: uid)
      .where('goalId', isEqualTo: id)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => SharedGoalInvitation(d.id, d.data())).toList(),
      );
  Stream<List<SharedSavingsTransaction>> watchRecent(String id) => goal(id)
      .collection('transactions')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => SharedSavingsTransaction(d.id, d.data()))
            .toList(),
      );
  Future<QuerySnapshot<Map<String, dynamic>>> activityPage(
    String id, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) {
    Query<Map<String, dynamic>> query = goal(id)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .limit(30);
    if (after != null) query = query.startAfterDocument(after);
    return query.get(const GetOptions(source: Source.server));
  }

  Future<Map<String, dynamic>> execute(
    String action,
    Map<String, dynamic> data, {
    String? requestId,
  }) async {
    if (auth.currentUser == null) {
      throw const SharedSavingsFailure('Sign in to use Save Together.');
    }
    return SharedSavingsStore(
      firestore,
      auth,
    ).execute(action, data, requestId ?? operationId());
  }
}

typedef SharedSavingsService = SharedSavingsRepository;
String sharedError(Object error) => sharedSavingsError(error);

/// One user-specific goal listener shared by Savings, Home and Reports.
class SharedSavingsController extends ChangeNotifier {
  SharedSavingsController(this.repository) {
    _subscription = repository.watchGoals().listen(
      (value) {
        goals = value;
        error = null;
        loading = false;
        notifyListeners();
      },
      onError: (Object failure) {
        goals =
            []; // Never display stale shared financial data after revocation.
        error = sharedSavingsError(failure);
        loading = false;
        notifyListeners();
      },
    );
  }
  final SharedSavingsRepository repository;
  late final StreamSubscription<List<SharedSavingsGoal>> _subscription;
  List<SharedSavingsGoal> goals = [];
  bool loading = true;
  String? error;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class SharedSavingsScope extends InheritedNotifier<SharedSavingsController> {
  const SharedSavingsScope({
    super.key,
    required SharedSavingsController controller,
    required super.child,
  }) : super(notifier: controller);
  static SharedSavingsController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SharedSavingsScope>()!
      .notifier!;
}

class SharedSavingsHost extends StatefulWidget {
  const SharedSavingsHost({super.key, required this.child});
  final Widget child;
  @override
  State<SharedSavingsHost> createState() => _SharedSavingsHostState();
}

class _SharedSavingsHostState extends State<SharedSavingsHost> {
  late final _controller = SharedSavingsController(SharedSavingsRepository());
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SharedSavingsScope(controller: _controller, child: widget.child);
}
