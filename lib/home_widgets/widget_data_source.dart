import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../currency_money.dart';
import '../goal_cover_cache.dart';
import '../goal_cover_service.dart';
import '../shared_savings_models.dart';
import '../shared_savings_repository.dart';
import '../smart_task_recommendation_service.dart';
import 'widget_models.dart';

abstract class WidgetDataSource {
  Stream<WidgetGoalFacts?> watchGoal(String uid, WidgetGoalRef ref);
  Stream<WidgetPlannerFacts> watchPlanner(String uid, String day);
  Future<List<WidgetGoalFacts>> choices(String uid);
  Future<Uint8List?> thumbnail(String uid, WidgetGoalFacts goal);
}

/// Read adapter over the same collections and shared repository used by the app.
/// It never writes records, reads transactions, or performs currency conversion.
class FirestoreWidgetDataSource implements WidgetDataSource {
  FirestoreWidgetDataSource({FirebaseFirestore? db, FirebaseAuth? auth})
    : db = db ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  void check(String uid) {
    if (auth.currentUser?.uid != uid) throw StateError('Your session changed.');
  }

  DocumentReference<Map<String, dynamic>> goalDocument(
    String uid,
    WidgetGoalRef ref,
  ) => ref.shared
      ? SharedSavingsRepository(firestore: db, auth: auth).goal(ref.id)
      : db.collection('users').doc(uid).collection('goals').doc(ref.id);
  WidgetGoalFacts? goalFacts(
    String uid,
    WidgetGoalRef ref,
    Map<String, dynamic>? data, {
    required bool cached,
  }) {
    if (data == null) return null;
    if (ref.shared &&
        (data['memberIds'] is! List ||
            !(data['memberIds'] as List).contains(uid))) {
      return null;
    }
    final shared = ref.shared ? SharedSavingsGoal(ref.id, data) : null;
    final saved = data[ref.shared ? 'currentAmount' : 'savedAmount'];
    final target = data['targetAmount'];
    if (saved is! num ||
        target is! num ||
        !saved.isFinite ||
        !target.isFinite) {
      return null;
    }
    final owner = ref.shared ? data['ownerId'] : uid;
    final coverTarget = owner is String
        ? (ref.shared
              ? GoalCoverTarget.shared(owner, ref.id)
              : GoalCoverTarget.personal(owner, ref.id))
        : null;
    final facts = WidgetGoalFacts(
      ref: ref,
      title: shared?.name ?? (data['title'] as String? ?? 'Savings goal'),
      saved: ExactDecimal.fromNum(saved),
      target: ExactDecimal.fromNum(target),
      currency: shared?.currencyCode ?? goalCurrency(data),
      archived: shared?.archived ?? (data['archived'] == true),
      deadline: data['deadline'] is Timestamp
          ? (ref.shared
                ? (data['deadline'] as Timestamp).toDate().toUtc()
                : (data['deadline'] as Timestamp).toDate())
          : null,
      cached: cached,
      confirmedAt: cached ? null : DateTime.now(),
      coverOwner: owner is String ? owner : null,
      coverPath: coverTarget == null
          ? null
          : GoalCoverRecord.fromMap(data, coverTarget).path,
    );
    return facts.valid ? facts : null;
  }

  @override
  Stream<WidgetGoalFacts?> watchGoal(String uid, WidgetGoalRef ref) {
    check(uid);
    return goalDocument(uid, ref)
        .snapshots(includeMetadataChanges: true)
        // Optimistic writes are never published as confirmed contributions.
        .where((event) => !event.metadata.hasPendingWrites)
        .map((event) {
          check(uid);
          return goalFacts(
            uid,
            ref,
            event.data(),
            cached: event.metadata.isFromCache,
          );
        });
  }

  @override
  Stream<WidgetPlannerFacts> watchPlanner(String uid, String day) {
    check(uid);
    return db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where('dateKey', isEqualTo: day)
        .snapshots(includeMetadataChanges: true)
        .where((event) => !event.metadata.hasPendingWrites)
        .map((event) {
          check(uid);
          return WidgetPlannerFacts(
            event.docs
                .map(
                  (doc) => PlannerTask.fromData(
                    doc.id,
                    doc.data(),
                    createdAt: doc.data()['createdAt'] is Timestamp
                        ? (doc.data()['createdAt'] as Timestamp).toDate()
                        : null,
                  ),
                )
                .toList(),
            day,
            cached: event.metadata.isFromCache,
            confirmedAt: event.metadata.isFromCache ? null : DateTime.now(),
          );
        });
  }

  @override
  Future<List<WidgetGoalFacts>> choices(String uid) async {
    check(uid);
    final personal = await db
        .collection('users')
        .doc(uid)
        .collection('goals')
        .get();
    check(uid);
    final shared = await SharedSavingsRepository(
      firestore: db,
      auth: auth,
    ).goals().first;
    check(uid);
    final result = <WidgetGoalFacts>[
      for (final doc in personal.docs)
        ?goalFacts(
          uid,
          WidgetGoalRef(doc.id),
          doc.data(),
          cached: personal.metadata.isFromCache,
        ),
      for (final goal in shared)
        ?goalFacts(
          uid,
          WidgetGoalRef(goal.id, shared: true),
          goal.data,
          cached: true,
        ),
    ]..removeWhere((g) => g.archived);
    return result
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  @override
  Future<Uint8List?> thumbnail(String uid, WidgetGoalFacts goal) async {
    check(uid);
    final owner = goal.coverOwner, path = goal.coverPath;
    if (owner == null || path == null) return null;
    final target = goal.ref.shared
        ? GoalCoverTarget.shared(owner, goal.ref.id)
        : GoalCoverTarget.personal(owner, goal.ref.id);
    final data = await GoalCoverCache.instance.load(uid, target, path);
    check(uid);
    return data == null ? null : compute(_thumbnail, data);
  }
}

Uint8List? _thumbnail(Uint8List bytes) {
  if (bytes.length > 1024 * 1024) return null;
  final decoder = img.JpegDecoder(maxPixels: 1280 * 720);
  final source = decoder.decode(bytes);
  if (source == null) return null;
  return Uint8List.fromList(
    img.encodeJpg(img.copyResize(source, width: 128, height: 72), quality: 75),
  );
}
