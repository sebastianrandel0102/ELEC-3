import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'shared_savings_models.dart';

/// Spark-compatible transactions. Firestore rules independently validate every
/// write; these client checks provide useful errors, not an authorization boundary.
class SharedSavingsStore {
  SharedSavingsStore(this.db, this.auth);
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  static const maxCents = 100000000000;
  static String randomId() => base64UrlEncode(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');

  Never fail(String message) => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'failed-precondition',
    message: message,
  );
  String id(dynamic value) {
    if (value is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(value)) {
      fail('Invalid goal, invitation, or request ID.');
    }
    return value;
  }

  int cents(dynamic value, {bool zero = false}) {
    if (value is! String || !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value)) {
      fail('Use a PHP amount with at most two decimal places.');
    }
    final parts = value.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null || whole > 1000000000) fail('Amount is too large.');
    final result =
        whole * 100 +
        int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    if (result < (zero ? 0 : 1) || result > maxCents) {
      fail('Enter a valid positive amount.');
    }
    return result;
  }

  String text(dynamic value, int max, {bool required = false}) {
    if (value is! String ||
        value.trim().length > max ||
        (required && value.trim().isEmpty)) {
      fail('Review the text fields and try again.');
    }
    return value.trim();
  }

  Timestamp date(dynamic value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      fail('Invalid date.');
    }
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (parsed == null ||
        parsed.toIso8601String().substring(0, 10) != value ||
        parsed.year < 2000 ||
        parsed.year > 2100) {
      fail('Invalid date.');
    }
    return Timestamp.fromDate(parsed);
  }

  Map<String, dynamic> fields(Map<String, dynamic> data) {
    final start = date(data['startDate']), end = date(data['deadline']);
    if (start.compareTo(end) > 0) {
      fail('The deadline must be on or after the start date.');
    }
    if (![
      'group',
      'travel',
      'home',
      'school',
      'gift',
      'emergency',
    ].contains(data['iconKey'])) {
      fail('Invalid icon.');
    }
    final target = cents(data['targetAmount']);
    return {
      'name': text(data['name'], 100, required: true),
      'description': text(data['description'] ?? '', 1000),
      'targetCents': target,
      'targetAmount': target / 100,
      'startDate': start,
      'deadline': end,
      'iconKey': data['iconKey'],
    };
  }

  void eligibleDate(Timestamp value, Timestamp start) {
    final manila = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today = Timestamp.fromDate(
      DateTime.utc(manila.year, manila.month, manila.day),
    );
    if (value.compareTo(start) < 0 || value.compareTo(today) > 0) {
      fail('Choose a date between the start date and today.');
    }
  }

  Future<Map<String, dynamic>> execute(
    String action,
    Map<String, dynamic> data,
    String requestId,
  ) async {
    final user = auth.currentUser;
    if (user == null) fail('Sign in to use Save Together.');
    if (['ownerId', 'userId', 'contributorId'].any(data.containsKey)) {
      fail('Do not supply an actor identity.');
    }
    final uid = user.uid;
    final claims = (await user.getIdTokenResult()).claims;
    final name = (claims?['name'] is String
        ? claims!['name'] as String
        : 'SaveTrack member');
    final memberName = name.length > 100 ? name.substring(0, 100) : name;
    final operation = db.doc('sharedOperations/$uid/requests/${id(requestId)}');
    // Stable serialization detects a retry with changed values. Receipts are
    // private to this user and never authorize a balance or membership write.
    final keys = data.keys.toList()..sort();
    final fingerprint = jsonEncode({
      'action': action,
      for (final key in keys) key: data[key],
    });
    final newToken = randomId();
    final newGoal = db.collection('sharedGoals').doc();
    return db.runTransaction<Map<String, dynamic>>((tx) async {
      if (action != 'preview') {
        final receipt = (await tx.get(operation)).data();
        if (receipt != null) {
          if (receipt['fingerprint'] != fingerprint) {
            fail(
              'This request was already used with different values. Reopen the form.',
            );
          }
          return Map<String, dynamic>.from(receipt['result'] as Map);
        }
      }
      final stamp = FieldValue.serverTimestamp();
      Map<String, dynamic> complete(Map<String, dynamic> result) {
        tx.set(operation, {
          'fingerprint': fingerprint,
          'result': result,
          'createdAt': stamp,
        });
        return result;
      }

      Map<String, dynamic> change(String kind, {String? subject}) => {
        'lastKind': kind,
        'lastId': requestId,
        'lastActor': uid,
        'lastSubject': subject ?? uid,
        'updatedAt': stamp,
      };
      if (action == 'create') {
        final values = fields(data),
            initial = cents(data['initialAmount'] ?? '0', zero: true);
        if (initial > 0) {
          eligibleDate(
            values['startDate'] as Timestamp,
            values['startDate'] as Timestamp,
          );
        }
        tx.set(newGoal, {
          ...values,
          'schemaVersion': 2,
          'ownerId': uid,
          'ownerName': memberName,
          'memberIds': [uid],
          'memberNames': {uid: memberName},
          'personalDeposits': {uid: initial / 100},
          'memberCount': 1,
          'currentCents': initial,
          'depositCents': initial,
          'decreaseCents': 0,
          'currentAmount': initial / 100,
          'totalDeposits': initial / 100,
          'totalDecreases': 0,
          'createdAt': stamp,
          'status': initial >= values['targetCents'] ? 'completed' : 'active',
          ...change('create'),
        });
        tx.set(newGoal.collection('members').doc(uid), {
          'userId': uid,
          'displayName': memberName,
          'role': 'owner',
          'status': 'active',
          'depositCents': initial,
          'totalDeposits': initial / 100,
          'joinedAt': stamp,
          'invitationId': '',
        });
        if (initial > 0) {
          tx.set(newGoal.collection('transactions').doc(requestId), {
            'goalId': newGoal.id,
            'contributorId': uid,
            'displayName': memberName,
            'type': 'deposit',
            'amountCents': initial,
            'amount': initial / 100,
            'date': values['startDate'],
            'note': 'Initial savings',
            'createdAt': stamp,
          });
        }
        return complete({'goalId': newGoal.id});
      }
      if (['preview', 'accept', 'decline'].contains(action)) {
        final invitationRef = db
            .collection('sharedInvitations')
            .doc(id(data['token']));
        final invite = (await tx.get(invitationRef)).data();
        if (invite == null) fail('Invalid invitation code.');
        final goalId = invite['goalId'] as String;
        if (action == 'preview') {
          if (invite['status'] != 'pending') {
            fail('This invitation is ${invite['status']}.');
          }
          if (!sharedInvitationExpiry(invite).isAfter(DateTime.now())) {
            fail('This invitation has expired.');
          }
          return {
            'goalId': goalId,
            'name': invite['name'],
            'ownerName': invite['ownerName'],
            'targetAmount': invite['targetAmount'],
            'expiresAt': sharedInvitationExpiry(invite).millisecondsSinceEpoch,
          };
        }
        final goalRef = db.collection('sharedGoals').doc(goalId);
        final memberRef = goalRef.collection('members').doc(uid);
        final previous = (await tx.get(memberRef)).data();
        if (action == 'accept' &&
            invite['status'] == 'accepted' &&
            invite['recipientId'] == uid &&
            previous?['status'] == 'active') {
          return complete({'goalId': goalId, 'alreadyJoined': true});
        }
        if (invite['status'] != 'pending') {
          fail('This invitation is ${invite['status']}.');
        }
        if (!sharedInvitationExpiry(invite).isAfter(DateTime.now())) {
          fail('This invitation has expired.');
        }
        if (action == 'decline') {
          tx.update(invitationRef, {
            'status': 'declined',
            'recipientId': uid,
            'updatedAt': stamp,
          });
          return complete({'declined': true});
        }
        if (previous?['status'] == 'removed') {
          fail('Your membership was removed. Contact the owner.');
        }
        if (previous?['status'] == 'active') {
          return complete({'goalId': goalId, 'alreadyJoined': true});
        }
        final deposited = previous?['depositCents'] as int? ?? 0;
        tx.set(memberRef, {
          'userId': uid,
          'displayName': memberName,
          'role': 'contributor',
          'status': 'active',
          'depositCents': deposited,
          'totalDeposits': deposited / 100,
          'joinedAt': stamp,
          'invitationId': invitationRef.id,
        });
        // No pre-join read of the private goal: transforms apply to its current
        // state atomically, and rules validate the consumed invitation and limit.
        tx.update(goalRef, {
          'memberIds': FieldValue.arrayUnion([uid]),
          'memberCount': FieldValue.increment(1),
          FieldPath(['memberNames', uid]): memberName,
          FieldPath(['personalDeposits', uid]): deposited / 100,
          ...change('accept'),
        });
        tx.update(invitationRef, {
          'status': 'accepted',
          'recipientId': uid,
          'updatedAt': stamp,
        });
        return complete({'goalId': goalId});
      }
      final goalRef = db.collection('sharedGoals').doc(id(data['goalId']));
      final goal = (await tx.get(goalRef)).data();
      final memberRef = goalRef.collection('members').doc(uid);
      final member = (await tx.get(memberRef)).data();
      if (goal == null ||
          member?['status'] != 'active' ||
          !(goal['memberIds'] as List).contains(uid)) {
        fail('You no longer have access to this shared goal.');
      }
      if (!['contribute', 'leave'].contains(action) && goal['ownerId'] != uid) {
        fail('Only the owner can perform this action.');
      }
      if (!['revoke', 'remove', 'leave', 'archive'].contains(action) &&
          goal['status'] == 'archived') {
        fail('This goal is archived.');
      }
      if (action == 'invite') {
        final limitRef = db.collection('sharedInviteLimits').doc(uid);
        final limit = (await tx.get(limitRef)).data();
        final now = DateTime.now().toUtc();
        final reset =
            limit == null ||
            now.difference((limit['windowStart'] as Timestamp).toDate()) >=
                const Duration(hours: 1);
        if (!reset && (limit['count'] as int) >= 20) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'resource-exhausted',
            message: 'You can create 20 invitations per hour. Try again later.',
          );
        }
        tx.set(limitRef, {
          'count': reset ? 1 : (limit['count'] as int) + 1,
          'windowStart': reset ? stamp : limit['windowStart'],
          'updatedAt': stamp,
          'lastCode': newToken,
        });
        // Expiry is createdAt + seven days on the server. A device clock even
        // slightly ahead must not turn an owner's valid invitation into a denial.
        tx.set(db.collection('sharedInvitations').doc(newToken), {
          'goalId': goalRef.id,
          'createdBy': uid,
          'name': goal['name'],
          'ownerName': goal['ownerName'],
          'targetAmount': goal['targetAmount'],
          'status': 'pending',
          'recipientId': '',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        return complete({
          'goalId': goalRef.id,
          'invitationId': newToken,
          'token': newToken,
        });
      }
      if (action == 'revoke') {
        final ref = db
            .collection('sharedInvitations')
            .doc(id(data['invitationId']));
        final invite = (await tx.get(ref)).data();
        if (invite == null ||
            invite['goalId'] != goalRef.id ||
            invite['status'] != 'pending') {
          fail('Only a pending invitation for this goal can be revoked.');
        }
        tx.update(ref, {'status': 'revoked', 'updatedAt': stamp});
        return complete({'revoked': true});
      }
      if (action == 'contribute' || action == 'decrease') {
        final amount = cents(data['amount']), deposit = action == 'contribute';
        final current =
            (goal['currentCents'] as int) + (deposit ? amount : -amount);
        final deposits = (goal['depositCents'] as int) + (deposit ? amount : 0);
        final decreases =
            (goal['decreaseCents'] as int) + (deposit ? 0 : amount);
        if (current < 0) {
          fail('You cannot decrease more than the current shared balance.');
        }
        if ([current, deposits, decreases].any((value) => value > maxCents)) {
          fail('Recorded totals exceed the supported range.');
        }
        final day = date(data['date']);
        eligibleDate(day, goal['startDate'] as Timestamp);
        tx.set(goalRef.collection('transactions').doc(requestId), {
          'goalId': goalRef.id,
          'contributorId': uid,
          'displayName': member!['displayName'],
          'type': deposit ? 'deposit' : 'withdrawal',
          'amountCents': amount,
          'amount': amount / 100,
          'date': day,
          'note': text(data['note'] ?? '', 500),
          'createdAt': stamp,
        });
        final mine = (member['depositCents'] as int) + (deposit ? amount : 0);
        tx.update(goalRef, {
          'currentCents': current,
          'depositCents': deposits,
          'decreaseCents': decreases,
          'currentAmount': current / 100,
          'totalDeposits': deposits / 100,
          'totalDecreases': decreases / 100,
          if (deposit) FieldPath(['personalDeposits', uid]): mine / 100,
          'status': current >= goal['targetCents'] ? 'completed' : 'active',
          ...change(action),
        });
        if (deposit) {
          tx.update(memberRef, {
            'depositCents': mine,
            'totalDeposits': mine / 100,
          });
        }
        return complete({'goalId': goalRef.id, 'currentAmount': current / 100});
      }
      if (action == 'edit') {
        final values = fields(data);
        if (values['startDate'] != goal['startDate']) {
          fail('The start date cannot change after creation.');
        }
        tx.update(goalRef, {
          ...values,
          'status': goal['currentCents'] >= values['targetCents']
              ? 'completed'
              : 'active',
          ...change(action),
        });
        return complete({'goalId': goalRef.id});
      }
      if (action == 'remove' || action == 'leave') {
        final target = action == 'leave'
            ? uid
            : text(data['memberId'], 128, required: true);
        if (target.contains('/') || target == goal['ownerId']) {
          fail(
            'The owner cannot leave or be removed. Archive the goal instead.',
          );
        }
        final targetRef = goalRef.collection('members').doc(target);
        final departing = (await tx.get(targetRef)).data();
        if (departing?['status'] != 'active') {
          fail('This member is no longer active.');
        }
        tx.update(targetRef, {
          'status': action == 'leave' ? 'left' : 'removed',
          'departedAt': stamp,
        });
        tx.update(goalRef, {
          'memberIds': FieldValue.arrayRemove([target]),
          'memberCount': FieldValue.increment(-1),
          FieldPath(['memberNames', target]): FieldValue.delete(),
          FieldPath(['personalDeposits', target]): FieldValue.delete(),
          ...change(action, subject: target),
        });
        return complete({'left': true});
      }
      if (action == 'archive') {
        tx.update(goalRef, {'status': 'archived', ...change(action)});
        return complete({'goalId': goalRef.id});
      }
      fail('Unknown Save Together operation.');
    }, timeout: const Duration(seconds: 45));
  }
}
