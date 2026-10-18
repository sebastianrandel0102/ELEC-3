import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'currency_money.dart';
import 'currency_service.dart';
import 'design_system.dart';

class CurrencyScope extends InheritedNotifier<CurrencyController> {
  const CurrencyScope({
    super.key,
    required CurrencyController controller,
    required super.child,
  }) : super(notifier: controller);
  static CurrencyController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrencyScope>()?.notifier;
  static CurrencyController of(BuildContext context) => maybeOf(context)!;
}

String displayMoney(BuildContext context, num value, [String code = 'PHP']) =>
    CurrencyScope.maybeOf(context)?.display(value, code) ??
    originalMoney(value, code);

/// Above Navigator so pushed routes and dialogs use the same user/snapshot.
class CurrencyHost extends StatefulWidget {
  const CurrencyHost({super.key, required this.child});
  final Widget child;
  @override
  State<CurrencyHost> createState() => _CurrencyHostState();
}

class _CurrencyHostState extends State<CurrencyHost>
    with WidgetsBindingObserver {
  CurrencyController? controller;
  StreamSubscription<User?>? authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  profileSubscription;
  Timer? timer;
  String? uid;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _session,
    );
    timer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (foreground) unawaited(controller?.refresh());
    });
  }

  void _session(User? user) {
    if (!mounted || uid == user?.uid) return;
    profileSubscription?.cancel();
    controller?.dispose();
    uid = user?.uid;
    if (user == null) {
      setState(() => controller = null);
      return;
    }
    final currentUid = user.uid;
    final profile = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid);
    late final CurrencyController current;
    current = CurrencyController(
      savePreference: (code) async {
        if (FirebaseAuth.instance.currentUser?.uid != currentUid) {
          throw const CurrencyFailure('Your session changed.');
        }
        final preferences = await SharedPreferences.getInstance();
        if (!await preferences.setString(
              'savetrack.currency.$currentUid',
              code,
            ) ||
            !await preferences.setBool(
              'savetrack.currencyPending.$currentUid',
              true,
            )) {
          throw const CurrencyFailure(
            'Unable to save the currency preference.',
          );
        }
        // Queue the profile merge, keeping selection usable while offline.
        _syncPreference(current, profile, preferences, currentUid, code);
      },
    );
    setState(() => controller = current);
    unawaited(_initializePreference(current, profile, currentUid));
    unawaited(current.initialize());
  }

  Future<void> _initializePreference(
    CurrencyController current,
    DocumentReference<Map<String, dynamic>> profile,
    String currentUid,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString('savetrack.currency.$currentUid');
      if (!current.disposed) current.receivePreference(saved);
      if (!current.disposed &&
          saved != null &&
          CurrencyCatalog.byCode.containsKey(saved) &&
          preferences.getBool('savetrack.currencyPending.$currentUid') ==
              true) {
        _syncPreference(current, profile, preferences, currentUid, saved);
      }
    } catch (_) {
      /* PHP is the safe offline default. */
    }
    if (current.disposed) return;
    profileSubscription = profile.snapshots().listen(
      (snapshot) {
        if (current.disposed) return;
        if (current.preferencePending) return;
        if (snapshot.metadata.isFromCache && !snapshot.exists) return;
        final data = snapshot.data();
        // A profile missing currency metadata is always an original PHP account.
        final code =
            data?['preferredCurrencyCode'] ?? data?['currency'] ?? 'PHP';
        current.receivePreference(code is String ? code : null);
      },
      onError: (_) {
        /* Keep the user's locally cached preference offline. */
      },
    );
  }

  void _syncPreference(
    CurrencyController current,
    DocumentReference<Map<String, dynamic>> profile,
    SharedPreferences preferences,
    String currentUid,
    String code,
  ) {
    current.preferencePending = true;
    current.changed();
    unawaited(
      profile
          .set({'preferredCurrencyCode': code}, SetOptions(merge: true))
          .then((_) async {
            if (preferences.getString('savetrack.currency.$currentUid') !=
                code) {
              return;
            }
            await preferences.remove('savetrack.currencyPending.$currentUid');
            if (!current.disposed) {
              current.preferencePending = false;
              current.changed();
            }
          })
          .catchError((Object error) {
            if (!current.disposed) {
              current.preferenceError = 'Unable to sync your preferred currency. It is saved on this device; apply again to retry.';
              current.changed();
            }
          }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) unawaited(controller?.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    authSubscription?.cancel();
    profileSubscription?.cancel();
    timer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => controller == null
      ? widget.child
      : CurrencyScope(controller: controller!, child: widget.child);
}

String rateTime(DateTime date) =>
    DateFormat('MMM d, y · HH:mm').format(date.toLocal());

class ExchangeRateStatus extends StatelessWidget {
  const ExchangeRateStatus({super.key, this.detailed = false});
  final bool detailed;
  @override
  Widget build(BuildContext context) {
    final controller = CurrencyScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                controller.stale || controller.usingCache
                    ? Icons.history
                    : Icons.public,
                size: 14,
                color: context.atelierMuted,
              ),
              Text(
                '${controller.preferred} · ${controller.status}',
                style: TextStyle(fontSize: 11, color: context.atelierMuted),
              ),
              if (controller.loading)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              InkWell(
                onTap: () async {
                  final launched = await launchUrl(
                    Uri.parse('https://www.exchangerate-api.com'),
                  );
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Rates by ExchangeRate-API: https://www.exchangerate-api.com',
                        ),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    'Rates by ExchangeRate-API',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.atelierAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (detailed) ...[
            if (controller.snapshot != null) ...[
              Text(
                'Provider updated: ${rateTime(controller.snapshot!.providerTime)}',
                style: TextStyle(color: context.atelierMuted, fontSize: 12),
              ),
              Text(
                'Fetched: ${rateTime(controller.snapshot!.fetchedAt)}',
                style: TextStyle(color: context.atelierMuted, fontSize: 12),
              ),
            ],
            Text(
              'Daily reference rates. Converted values are tracking estimates.',
              style: TextStyle(color: context.atelierMuted, fontSize: 12),
            ),
            if (controller.error != null)
              Text(
                controller.error!,
                style: TextStyle(color: context.atelierWarning, fontSize: 12),
              ),
            TextButton.icon(
              key: const ValueKey('refresh-rates'),
              onPressed: controller.loading
                  ? null
                  : () async {
                      await controller.refresh(force: true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.error ??
                                  '${controller.status}. Refresh requests are limited to once per hour.',
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh exchange rates'),
            ),
          ],
        ],
      ),
    );
  }
}

class CurrencyContextLabel extends StatelessWidget {
  const CurrencyContextLabel({
    super.key,
    required this.source,
    this.historical = false,
  });
  final String source;
  final bool historical;
  @override
  Widget build(BuildContext context) {
    final controller = CurrencyScope.maybeOf(context);
    if (controller == null || controller.preferred == source) {
      return const SizedBox.shrink();
    }
    return Text(
      '${historical ? 'Current-rate estimated equivalent' : 'Display estimate'} · stored in $source${controller.stale || controller.usingCache ? ' · saved rates' : ''}',
      style: TextStyle(fontSize: 11, color: context.atelierMuted),
    );
  }
}

/// Searchable lazy catalog reused by goal and transaction forms.
Future<String?> chooseCurrency(
  BuildContext context,
  String selected, {
  bool allowSame = true,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (context) =>
      CurrencyPicker(selected: selected, allowSame: allowSame),
);

class CurrencyPicker extends StatefulWidget {
  const CurrencyPicker({
    super.key,
    required this.selected,
    this.allowSame = true,
  });
  final String selected;
  final bool allowSame;
  @override
  State<CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<CurrencyPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final service = CurrencyScope.maybeOf(context);
    final list = CurrencyCatalog.all.where((c) => c.matches(query)).toList();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SizedBox(
          height:
              (MediaQuery.sizeOf(context).height - keyboardInset) *
              (keyboardInset > 0 ? .95 : .8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  keyboardInset > 0 ? 'Currencies' : 'Choose Your Currency',
                  style: keyboardInset > 0
                      ? const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        )
                      : SaveTrackDesign.heading.copyWith(
                          color: context.atelierInk,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const ValueKey('currency-search'),
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search currency or country',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final c = list[index],
                        enabled =
                            c.code == 'PHP' ||
                            service?.supports(c.code) == true ||
                            (widget.allowSame && c.code == widget.selected);
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        key: ValueKey('pick-${c.code}'),
                        selected: c.code == widget.selected,
                        selectedTileColor: context.atelierTonal,
                        title: Text('${c.code} · ${c.name}'),
                        subtitle: Text(
                          enabled
                              ? c.regions.join(', ')
                              : 'No applicable rate available',
                        ),
                        leading: CircleAvatar(
                          backgroundColor: context.atelierSelected,
                          foregroundColor: context.atelierAccent,
                          child: Text(
                            c.symbol,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        trailing: c.code == widget.selected
                            ? Icon(
                                Icons.check_circle,
                                color: context.atelierAccent,
                              )
                            : null,
                        enabled: enabled,
                        onTap: () => Navigator.pop(context, c.code),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GoalCurrencyField extends StatelessWidget {
  const GoalCurrencyField({
    super.key,
    required this.code,
    required this.onChanged,
    this.enabled = true,
  });
  final String code;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('goal-currency'),
    onPressed: !enabled
        ? null
        : () async {
            final next = await chooseCurrency(context, code);
            if (next != null) onChanged(next);
          },
    icon: const Icon(Icons.currency_exchange),
    label: Text(
      'Goal Currency: $code · ${CurrencyCatalog.byCode[code]?.name ?? code}',
    ),
  );
}

class TransactionConversionDetails extends StatelessWidget {
  const TransactionConversionDetails({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final timestamp = data['rateTimestamp'];
    return Text(
      'Recorded input: ${originalMoney(data['inputAmount'] as num? ?? 0, data['inputCurrencyCode'] as String? ?? 'PHP')}\n'
      'Locked rate: ${data['exchangeRate']} ${data['goalCurrencyCode']} per ${data['inputCurrencyCode']}\n'
      '${data['rateProvider']} · ${timestamp is Timestamp ? rateTime(timestamp.toDate()) : 'Rate timestamp unavailable'}',
      style: TextStyle(color: context.atelierMuted, fontSize: 12),
    );
  }
}
