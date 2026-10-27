import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'currency_money.dart';
import 'currency_service.dart';

/// A confirmed form owns this immutable entry, including its rate. Retries never
/// fetch a different quote or reuse rounded display equivalents as inputs.
class LockedMoneyEntry {
  LockedMoneyEntry._(
    this.input,
    this.inputCurrency,
    this.goalCurrencyCode,
    this.amount,
    this.rate,
    this.snapshot,
  );
  final ExactDecimal input, amount, rate;
  final String inputCurrency, goalCurrencyCode;
  final ExchangeRateSnapshot? snapshot;
  factory LockedMoneyEntry.create({
    required String text,
    required String from,
    required String to,
    ExchangeRateSnapshot? snapshot,
    DateTime? now,
    Duration maximumRateAge = const Duration(days: 1),
  }) {
    final input = parseCurrencyAmount(text, from);
    if (input == null || !input.positive) {
      throw const CurrencyFailure(
        'Enter a valid positive amount with the currency’s allowed decimal places.',
      );
    }
    if (from != to &&
        (snapshot == null ||
            snapshot.stale((now ?? DateTime.now()).toUtc(), maximumRateAge))) {
      throw const CurrencyFailure(
        'Fresh exchange rates are required to record a cross-currency entry. Refresh rates or enter the goal currency.',
      );
    }
    final conversion = CurrencyConversionService(snapshot),
        rate = conversion.quote(from, to);
    final amount = ExactDecimal.parse(
      (input * rate).fixed(CurrencyCatalog.require(to).digits),
    );
    if (!amount.positive) {
      throw const CurrencyFailure(
        'The converted amount rounds to zero in the goal currency.',
      );
    }
    for (final value in [input, amount]) {
      if (value.compareTo(ExactDecimal.parse('1000000000000')) > 0 ||
          ExactDecimal.fromNum(value.toDouble()).compareTo(value) != 0) {
        throw const CurrencyFailure(
          'This amount is too large to record accurately.',
        );
      }
    }
    return LockedMoneyEntry._(input, from, to, amount, rate, snapshot);
  }
  Map<String, dynamic>? get metadata => inputCurrency == goalCurrencyCode
      ? null
      : {
          'inputAmount': input.toDouble(),
          'inputCurrencyCode': inputCurrency,
          'goalCurrencyCode': goalCurrencyCode,
          'exchangeRate': rate.toDouble(),
          'rateNumerator': rate.numerator.toString(),
          'rateDenominator': rate.denominator.toString(),
          'rateTimestamp': Timestamp.fromDate(snapshot!.providerTime),
          'rateProvider': snapshot!.provider,
          'rateSnapshotId': snapshot!.id,
        };
}

/// Shared client transactions also validate confirmed metadata before writes.
/// Rates are informational tracking estimates, not authorization to transfer funds.
void validateConversionMetadata(
  Map<String, dynamic> data,
  num amount,
  String code,
) {
  final inputCode = data['inputCurrencyCode'];
  if (inputCode is! String ||
      inputCode == code ||
      data['goalCurrencyCode'] != code ||
      data['inputAmount'] is! num ||
      data['exchangeRate'] is! num ||
      data['rateProvider'] != 'ExchangeRate-API' ||
      data['rateTimestamp'] is! Timestamp ||
      data['rateSnapshotId'] is! String ||
      data['rateNumerator'] is! String ||
      data['rateDenominator'] is! String) {
    throw const CurrencyFailure('Invalid confirmed currency conversion.');
  }
  CurrencyCatalog.require(inputCode);
  final rawInput = ExactDecimal.fromNum(data['inputAmount'] as num);
  final input = parseCurrencyAmount(
    rawInput.fixed(CurrencyCatalog.require(inputCode).digits),
    inputCode,
  );
  final n = BigInt.tryParse(data['rateNumerator'] as String),
      d = BigInt.tryParse(data['rateDenominator'] as String);
  if (input == null ||
      input.compareTo(rawInput) != 0 ||
      !input.positive ||
      n == null ||
      d == null ||
      n <= BigInt.zero ||
      d <= BigInt.zero) {
    throw const CurrencyFailure('Invalid confirmed currency conversion.');
  }
  final rate = ExactDecimal(n, d);
  if (rate.toDouble() != data['exchangeRate'] ||
      (input * rate).fixed(CurrencyCatalog.require(code).digits) !=
          ExactDecimal.fromNum(amount)
              .fixed(CurrencyCatalog.require(code).digits)) {
    throw const CurrencyFailure(
      'The confirmed amount does not match its locked exchange rate.',
    );
  }
}

Future<void> recordCurrencySavings({
  required DocumentReference<Map<String, dynamic>> goal,
  required String uid,
  required LockedMoneyEntry entry,
  required String note,
  required String requestId,
  required bool withdrawal,
  bool requireActiveGoal = false,
  FirebaseAuth? auth,
}) async {
  final authentication = auth ?? FirebaseAuth.instance;
  void checkOwner() {
    if (authentication.currentUser?.uid != uid ||
        goal.path.split('/').length != 4 ||
        !goal.path.startsWith('users/$uid/goals/')) {
      throw const CurrencyFailure('Sign in to access your own savings goal.');
    }
  }

  checkOwner();
  if (requestId.isEmpty || requestId.contains('/')) {
    throw const CurrencyFailure('Invalid savings request.');
  }
  final record = goal.collection('transactions').doc(requestId),
      metadata = entry.metadata;
  await goal.firestore.runTransaction<void>((tx) async {
    checkOwner();
    final snapshot = await tx.get(goal), existing = await tx.get(record);
    if (!snapshot.exists) {
      throw const CurrencyFailure('This savings goal is no longer available.');
    }
    final data = snapshot.data()!;
    if (goalCurrency(data) != entry.goalCurrencyCode) {
      throw const CurrencyFailure(
        'The goal currency has changed. Reopen this form.',
      );
    }
    if (existing.exists) {
      final before = existing.data()!;
      final old = before['conversion'];
      final sameMetadata = metadata == null
          ? old == null
          : old is Map &&
                old.length == metadata.length &&
                metadata.entries.every((e) => old[e.key] == e.value);
      if (before['type'] == (withdrawal ? 'withdrawal' : 'deposit') &&
          before['amount'] == entry.amount.toDouble() &&
          before['note'] == note.trim() &&
          sameMetadata) {
        return;
      }
      throw const CurrencyFailure(
        'This request was already used. Reopen the form before changing the amount.',
      );
    }
    if (requireActiveGoal &&
        (data['archived'] == true || data['status'] == 'archived')) {
      throw const CurrencyFailure('This savings goal is archived.');
    }
    final balance = data['savedAmount'];
    if (balance is! num || !balance.isFinite || balance < 0) {
      throw const CurrencyFailure('Your savings balance is unavailable.');
    }
    final current = ExactDecimal.fromNum(balance);
    // Only legacy binary noise is tolerated; goal values are never revalued.
    final result = withdrawal ? current - entry.amount : current + entry.amount;
    if (withdrawal && result.compareTo(ExactDecimal.parse('-0.00000001')) < 0) {
      throw const CurrencyFailure(
        'You cannot decrease more than your available savings.',
      );
    }
    final updated = result.numerator.isNegative ? 0.0 : result.toDouble();
    if (!updated.isFinite || updated > 1000000000000) {
      throw const CurrencyFailure(
        'The savings balance is too large to record accurately.',
      );
    }
    checkOwner();
    tx.update(goal, {
      'savedAmount': updated,
      'updatedAt': FieldValue.serverTimestamp(),
      if (withdrawal)
        'lastWithdrawalId': requestId
      else
        'lastDepositId': requestId,
    });
    tx.set(record, {
      'amount': entry.amount.toDouble(),
      'note': note.trim(),
      'date': FieldValue.serverTimestamp(),
      'type': withdrawal ? 'withdrawal' : 'deposit',
      'currencyCode': entry.goalCurrencyCode,
      'conversion': ?metadata,
    });
  });
}
