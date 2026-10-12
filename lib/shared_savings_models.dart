import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'savings_decrease.dart';

double? parseSharedAmount(String? value) {
  final amount = parseDecreaseAmount(value);
  return amount != null && amount <= 1000000000 ? amount : null;
}

String sharedMoney(num value) =>
    'PHP ${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
DateTime sharedDate(dynamic value) => value is Timestamp
    ? value.toDate().toUtc()
    : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
String sharedDateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Match Firestore's seven-day lifetime from the authoritative creation time.
/// Older invitations retain their explicit expiry until they are consumed.
DateTime sharedInvitationExpiry(Map<String, dynamic> data) =>
    data['expiresAt'] is Timestamp
    ? sharedDate(data['expiresAt'])
    : sharedDate(data['createdAt']).add(const Duration(days: 7));

class SharedSavingsGoal {
  SharedSavingsGoal(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  String get name => data['name'] as String? ?? 'Shared goal';
  String get description => data['description'] as String? ?? '';
  String get ownerId => data['ownerId'] as String;
  String get iconKey => data['iconKey'] as String? ?? 'group';
  bool get archived => data['status'] == 'archived';
  double _amount(String key) => (data[key] as num? ?? 0).toDouble();
  double get target => _amount('targetAmount');
  double get balance => _amount('currentAmount');
  double get deposits => _amount('totalDeposits');
  double get decreases => _amount('totalDecreases');
  double get remaining => math.max(0, target - balance);
  double get progress => target <= 0 ? 0 : (balance / target).clamp(0, 1);
  DateTime get startDate => sharedDate(data['startDate']);
  DateTime get deadline => sharedDate(data['deadline']);
  int get memberCount => (data['memberCount'] as num? ?? 0).toInt();
  int daysRemaining(DateTime now) =>
      deadline.difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  String statusAt(DateTime now) => archived
      ? 'Archived'
      : progress >= 1
      ? 'Completed'
      : daysRemaining(now) < 0
      ? 'Overdue'
      : 'Active';
  double daily(DateTime now) => remaining / daysRemaining(now).clamp(1, 365000);
}

class SharedGoalMember {
  SharedGoalMember(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  String get name => data['displayName'] as String? ?? 'SaveTrack member';
  String get role => data['role'] as String? ?? 'contributor';
  String get status => data['status'] as String? ?? 'active';
  double get deposits => (data['totalDeposits'] as num? ?? 0).toDouble();
  DateTime get joinedAt => sharedDate(data['joinedAt']);
}

class SharedSavingsTransaction {
  SharedSavingsTransaction(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  String get contributorId => data['contributorId'] as String;
  String get name => data['displayName'] as String? ?? 'SaveTrack member';
  String get note => data['note'] as String? ?? '';
  bool get withdrawal => data['type'] == 'withdrawal';
  double get amount => (data['amount'] as num).toDouble();
  DateTime get date => sharedDate(data['date']);
}

class SharedGoalInvitation {
  SharedGoalInvitation(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  DateTime get expiresAt => sharedInvitationExpiry(data);
  String statusAt(DateTime now) =>
      data['status'] == 'pending' && !expiresAt.isAfter(now)
      ? 'expired'
      : data['status'] as String;
}
