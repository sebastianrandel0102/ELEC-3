import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavingsDecreaseFailure implements Exception {
  const SavingsDecreaseFailure(this.message);
  final String message;
}

// Amounts remain numeric pesos in Firestore, as in the existing deposit flow.
// Parse decimal digits rather than accepting signs, exponents or NaN/Infinity.
double? parseDecreaseAmount(String? input) {
  final text = (input ?? '').trim();
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final cents = int.tryParse(
    '${parts.first}${parts.length == 1 ? '00' : parts.last.padRight(2, '0')}',
  );
  if (cents == null || cents > 9007199254740991) return null;
  return cents / 100;
}

String? validateDecreaseAmount(String? input, double balance) {
  if ((input ?? '').trim().isEmpty) return 'Please enter an amount.';
  final amount = parseDecreaseAmount(input);
  if (amount == null) return 'Please enter a valid positive amount.';
  if (amount <= 0) return 'Please enter an amount greater than zero.';
  if (!balance.isFinite || balance < 0) {
    return 'Your savings balance is unavailable. Please try again.';
  }
  // Ignore only floating-point noise from existing peso-valued deposits.
  if (amount - balance > 0.00000001) {
    return 'You cannot decrease more than your available savings.';
  }
  return null;
}

double decreasedSavingsBalance(double balance, double amount) {
  if (!amount.isFinite ||
      amount <= 0 ||
      amount > 90071992547409.91 ||
      amount != double.parse(amount.toStringAsFixed(2))) {
    throw const SavingsDecreaseFailure('Please enter a valid positive amount.');
  }
  if (!balance.isFinite || balance < 0) {
    throw const SavingsDecreaseFailure(
      'Your savings balance is unavailable. Please try again.',
    );
  }
  if (amount - balance > 0.00000001) {
    throw const SavingsDecreaseFailure(
      'You cannot decrease more than your available savings.',
    );
  }
  return math.max(0, balance - amount);
}

/// The existing goal balance and its history change in one Firestore commit.
/// A form keeps the same request ID (and payload) across uncertain retries.
Future<void> decreaseSavings({
  required DocumentReference<Map<String, dynamic>> goal,
  required String uid,
  required double amount,
  required String note,
  required String requestId,
  FirebaseAuth? auth,
}) async {
  final authentication = auth ?? FirebaseAuth.instance;
  void checkOwner() {
    if (authentication.currentUser?.uid != uid ||
        goal.path.split('/').length != 4 ||
        !goal.path.startsWith('users/$uid/goals/')) {
      throw const SavingsDecreaseFailure(
        'Please sign in to access your own savings goal.',
      );
    }
  }

  checkOwner();
  if (requestId.isEmpty || requestId.contains('/')) {
    throw const SavingsDecreaseFailure(
      'Unable to decrease savings. Please try again.',
    );
  }
  // Validate before reading; final balance validation happens in the transaction.
  decreasedSavingsBalance(amount, amount);
  final record = goal.collection('transactions').doc(requestId);
  await goal.firestore.runTransaction<void>((transaction) async {
    checkOwner();
    final snapshot = await transaction.get(goal);
    final previousRequest = await transaction.get(record);
    if (!snapshot.exists) {
      throw const SavingsDecreaseFailure(
        'This savings goal is no longer available.',
      );
    }
    if (previousRequest.exists) {
      final data = previousRequest.data()!;
      if (data['type'] == 'withdrawal' &&
          data['amount'] == amount &&
          data['note'] == note.trim()) {
        return;
      }
      throw const SavingsDecreaseFailure(
        'This request has already been used. Reopen Decrease Savings to try again.',
      );
    }
    final balance = snapshot.data()?['savedAmount'];
    if (balance is! num) {
      throw const SavingsDecreaseFailure(
        'Your savings balance is unavailable. Please try again.',
      );
    }
    final updated = decreasedSavingsBalance(balance.toDouble(), amount);
    checkOwner();
    transaction.update(goal, {
      'savedAmount': updated,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastWithdrawalId': requestId,
    });
    transaction.set(record, {
      'amount': amount,
      'note': note.trim(),
      'date': FieldValue.serverTimestamp(),
      'type': 'withdrawal',
    });
  });
}

String savingsDecreaseError(Object error) {
  if (error is SavingsDecreaseFailure) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' || 'unauthenticated' => 'You do not have permission to decrease this savings goal. Please sign in again.',
      'not-found' => 'This savings goal is no longer available.',
      'unavailable' || 'deadline-exceeded' => 'Unable to confirm the decrease. Check your connection and retry the same request.',
      'aborted' =>
        'Your savings changed during confirmation. Please try again.',
      _ => 'Unable to decrease savings. Please try again.',
    };
  }
  return 'Unable to decrease savings. Please try again.';
}
