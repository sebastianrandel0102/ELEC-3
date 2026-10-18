import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'currency_money.dart';
import 'currency_settings_screen.dart';
import 'currency_transactions.dart';
import 'currency_widgets.dart';
import 'design_system.dart';

class CurrencySavingsDialog extends StatefulWidget {
  const CurrencySavingsDialog({
    super.key,
    required this.initialGoal,
    required this.goalUpdates,
    required this.onConfirm,
    this.withdrawal = false,
    this.initialAmount,
  });
  final Map<String, dynamic> initialGoal;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> goalUpdates;
  final Future<void> Function(LockedMoneyEntry entry, String note) onConfirm;
  final bool withdrawal;
  final String? initialAmount;
  @override
  State<CurrencySavingsDialog> createState() => _CurrencySavingsDialogState();
}

class _CurrencySavingsDialogState extends State<CurrencySavingsDialog> {
  final form = GlobalKey<FormState>(),
      amount = TextEditingController(),
      note = TextEditingController();
  late String inputCurrency = goalCurrency(widget.initialGoal);
  LockedMoneyEntry? submitted;
  String? submittedNote, error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmount;
    if (initial != null &&
        parseCurrencyAmount(initial, inputCurrency)?.positive == true) {
      amount.text = initial;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> confirm(LockedMoneyEntry? preview) async {
    if (busy || (submitted == null && !form.currentState!.validate())) return;
    if (submitted == null && preview == null) return;
    submitted ??= preview;
    submittedNote ??= note.text.trim();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onConfirm(submitted!, submittedNote!);
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        error = failure is CurrencyFailure ? failure.message : 'Unable to confirm savings. Check your connection and retry the same request.';
        if (failure is CurrencyFailure ||
            failure is FirebaseException &&
                [
                  'permission-denied',
                  'unauthenticated',
                  'not-found',
                  'aborted',
                ].contains(failure.code)) {
          submitted = null;
          submittedNote = null;
        }
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = CurrencyScope.maybeOf(context),
        code = goalCurrency(widget.initialGoal);
    LockedMoneyEntry? preview;
    String? conversionError;
    if (amount.text.isNotEmpty) {
      try {
        preview =
            submitted ??
            LockedMoneyEntry.create(
              text: amount.text,
              from: inputCurrency,
              to: code,
              snapshot: controller?.snapshot,
              now: controller?.clock(),
              maximumRateAge:
                  controller?.refreshInterval ?? const Duration(days: 1),
            );
      } on CurrencyFailure catch (failure) {
        conversionError = failure.message;
      }
    }
    final locked = busy || submitted != null;
    return PopScope(
      canPop: !busy,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.goalUpdates,
        builder: (context, snapshot) {
          final missing = snapshot.hasData && !snapshot.data!.exists,
              data = snapshot.data?.data() ?? widget.initialGoal;
          final balance = data['savedAmount'] is num
              ? data['savedAmount'] as num
              : 0;
          final available =
              !missing &&
              !snapshot.hasError &&
              balance.isFinite &&
              (!widget.withdrawal || balance > 0);
          final validBalance =
              preview == null ||
              !widget.withdrawal ||
              preview.amount.compareTo(ExactDecimal.fromNum(balance)) <= 0;
          return AlertDialog(
            scrollable: true,
            title: FormHeading(
              icon: widget.withdrawal
                  ? Icons.south_east
                  : Icons.savings_outlined,
              title: widget.withdrawal
                  ? 'Decrease Savings'
                  : 'Add to ${data['title']}',
              detail: '${data['title']} · savings recorded in $code',
            ),
            content: SizedBox(
              width: 440,
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TonalPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Savings: ${originalMoney(balance, code)}',
                            style: SaveTrackDesign.amount.copyWith(
                              fontSize: 24,
                              color: context.atelierAccent,
                            ),
                          ),
                          Text(
                            'Target Amount: ${originalMoney(data['targetAmount'] as num? ?? 0, code)}',
                          ),
                          CurrencyContextLabel(source: code),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: locked
                          ? null
                          : () async {
                              final next = await chooseCurrency(
                                context,
                                inputCurrency,
                              );
                              if (next != null && mounted) {
                                setState(() => inputCurrency = next);
                              }
                            },
                      icon: const Icon(Icons.currency_exchange),
                      label: Text('Input Currency: $inputCurrency'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      style: SaveTrackDesign.amount.copyWith(
                        fontSize: 28,
                        color: context.atelierAccent,
                      ),
                      key: ValueKey(
                        widget.withdrawal
                            ? 'decrease-amount'
                            : 'deposit-amount',
                      ),
                      controller: amount,
                      enabled: !locked && available,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: widget.withdrawal
                            ? 'Amount to Decrease'
                            : 'Amount saved',
                        prefixText: '$inputCurrency ',
                      ),
                      onChanged: (_) => setState(() => error = null),
                      validator: (_) => preview == null
                          ? conversionError ??
                                'Enter an amount greater than zero.'
                          : !validBalance
                          ? 'You cannot decrease more than your available savings.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: ValueKey(
                        widget.withdrawal ? 'decrease-note' : 'deposit-note',
                      ),
                      controller: note,
                      enabled: !locked,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: widget.withdrawal
                            ? 'Reason / Note'
                            : 'Note (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (preview != null) ...[
                      ConversionPreview(
                        amount: preview.input,
                        from: inputCurrency,
                        to: code,
                        snapshot: preview.snapshot,
                      ),
                      if (validBalance)
                        Text(
                          'New Savings Balance: ${formatCurrency(widget.withdrawal ? ExactDecimal.fromNum(balance) - preview.amount : ExactDecimal.fromNum(balance) + preview.amount, code)}',
                        ),
                      if (inputCurrency != code)
                        Text(
                          'Confirming records this estimate with a locked rate. No money is exchanged.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.atelierMuted,
                          ),
                        ),
                    ],
                    if (conversionError != null)
                      Text(
                        conversionError,
                        style: TextStyle(color: context.atelierWarning),
                      ),
                    if (!validBalance)
                      Text(
                        'You cannot decrease more than your available savings.',
                        style: TextStyle(color: context.atelierError),
                      ),
                    if (!available)
                      Text(
                        'This savings goal is unavailable for this operation.',
                        style: TextStyle(color: context.atelierError),
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(color: context.atelierError),
                      ),
                    if (submitted != null && error != null)
                      Text(
                        'Retry confirms the same amount and locked rate.',
                        style: TextStyle(color: context.atelierMuted),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              GradientButton(
                expand: false,
                onPressed: busy || !available ? null : () => confirm(preview),
                child: SaveActionLabel(
                  busy: busy,
                  label: widget.withdrawal ? 'Confirm Decrease' : 'Add savings',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
