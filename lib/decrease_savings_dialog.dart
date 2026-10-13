import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'design_system.dart';
import 'savings_decrease.dart';

class DecreaseSavingsDialog extends StatefulWidget {
  const DecreaseSavingsDialog({
    super.key,
    required this.initialGoal,
    required this.goalUpdates,
    required this.formatMoney,
    required this.onConfirm,
  });

  final Map<String, dynamic> initialGoal;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> goalUpdates;
  final String Function(num) formatMoney;
  final Future<void> Function(double amount, String note) onConfirm;

  @override
  State<DecreaseSavingsDialog> createState() => _DecreaseSavingsDialogState();
}

class _DecreaseSavingsDialogState extends State<DecreaseSavingsDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;
  // Freeze an uncertain request's payload until it is resolved. Editing after a
  // lost server response must not turn a retry into a second withdrawal.
  double? _submittedAmount;
  String? _submittedNote;

  Future<void> _confirm() async {
    if (_busy) return;
    if (_submittedAmount == null && !_form.currentState!.validate()) return;
    _submittedAmount ??= parseDecreaseAmount(_amount.text)!;
    _submittedNote ??= _note.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(_submittedAmount!, _submittedNote!);
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = savingsDecreaseError(error);
        // These failures are known not to commit. Permit correcting the fields.
        if (error is SavingsDecreaseFailure ||
            (error is FirebaseException &&
                [
                  'permission-denied',
                  'unauthenticated',
                  'not-found',
                  'aborted',
                ].contains(error.code))) {
          _submittedAmount = null;
          _submittedNote = null;
        }
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.goalUpdates,
      builder: (context, snapshot) {
        final missing = snapshot.hasData && !snapshot.data!.exists;
        final data = snapshot.data?.data() ?? widget.initialGoal;
        final rawBalance = data['savedAmount'];
        final balance = rawBalance is num ? rawBalance.toDouble() : double.nan;
        final target = data['targetAmount'] is num
            ? data['targetAmount'] as num
            : 0;
        final amount = parseDecreaseAmount(_amount.text);
        final valid = validateDecreaseAmount(_amount.text, balance) == null;
        final available =
            !missing && !snapshot.hasError && balance.isFinite && balance > 0;
        final locked = _busy || _submittedAmount != null;
        return AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          title: const FormHeading(
            icon: Icons.south_east,
            title: 'Decrease Savings',
            detail:
                'Enter the amount you want to subtract from this savings goal.',
          ),
          content: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SaveTrackDesign.lightMint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Goal: ${data['title'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Savings: ${balance.isFinite ? widget.formatMoney(balance) : 'Unavailable'}',
                      ),
                      const SizedBox(height: 4),
                      Text('Target Amount: ${widget.formatMoney(target)}'),
                      const SizedBox(height: 4),
                      Text(
                        'Available savings balance: ${balance.isFinite ? widget.formatMoney(balance) : 'Unavailable'}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('decrease-amount'),
                  controller: _amount,
                  style: SaveTrackDesign.amount.copyWith(
                    fontSize: 28,
                    color: teal,
                  ),
                  enabled: !locked && available,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount to Decrease',
                    hintText: 'Enter amount',
                    prefixText: 'PHP ',
                  ),
                  validator: (value) => validateDecreaseAmount(value, balance),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('decrease-note'),
                  controller: _note,
                  enabled: !locked,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Note',
                    hintText: 'Why are you decreasing your savings?',
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    valid
                        ? 'Decrease Amount: ${widget.formatMoney(amount!)}\nNew Savings Balance: ${widget.formatMoney(decreasedSavingsBalance(balance, amount))}'
                        : 'New Savings Balance: —',
                    style: const TextStyle(
                      color: teal,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),
                ),
                if (missing || snapshot.hasError || !available) ...[
                  const SizedBox(height: 12),
                  Text(
                    missing
                        ? 'This savings goal is no longer available.'
                        : snapshot.hasError
                        ? 'Unable to load your savings balance. Please try again.'
                        : 'This goal has no available savings to decrease.',
                    style: const TextStyle(color: SaveTrackDesign.error),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: SaveTrackDesign.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            GradientButton(
              expand: false,
              onPressed: _busy || (!available && _submittedAmount == null)
                  ? null
                  : _confirm,
              child: SaveActionLabel(busy: _busy, label: 'Confirm Decrease'),
            ),
          ],
        );
      },
    ),
  );

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }
}
