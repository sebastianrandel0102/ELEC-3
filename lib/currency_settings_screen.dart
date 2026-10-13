import 'package:flutter/material.dart';

import 'currency_money.dart';
import 'currency_service.dart';
import 'currency_widgets.dart';
import 'design_system.dart';

class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});
  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  String? selected;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final service = CurrencyScope.maybeOf(context);
    if (service == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to choose your currency.')),
      );
    }
    selected ??= service.preferred;
    final chosen = CurrencyCatalog.require(selected!);
    final current = CurrencyCatalog.require(service.preferred);
    final currencies = CurrencyCatalog.all
        .where((c) => c.matches(query))
        .toList();
    final selectable = selected == 'PHP' || service.supports(selected!);
    return Scaffold(
      appBar: AppBar(title: const Text('Currency Settings')),
      body: PageSurface(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList.list(
                    children: [
                      const ScreenIntro(
                        eyebrow: 'Worldwide savings',
                        title: 'Choose Your Currency',
                        detail: 'View your savings in the currency that works for you.',
                      ),
                      MintHero(
                        deep: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your display currency',
                              style: TextStyle(
                                color: SaveTrackDesign.onHeroMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${current.code}  ${current.symbol}',
                              style: SaveTrackDesign.amount.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              current.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              current.regions.length == 1
                                  ? current.regions.first
                                  : 'Used across ${current.regions.length} countries and regions',
                              style: const TextStyle(
                                color: SaveTrackDesign.onHeroMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const ExchangeRateStatus(detailed: true),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('settings-currency-search'),
                        decoration: const InputDecoration(
                          hintText: 'Search currency or country',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => setState(() => query = value),
                      ),
                      const SizedBox(height: 20),
                      const FieldCaption('Popular currencies'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: CurrencyCatalog.popular
                            .map(
                              (code) => ChoiceChip(
                                key: ValueKey('popular-$code'),
                                label: Text(code),
                                selected: selected == code,
                                onSelected: (_) =>
                                    setState(() => selected = code),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Preview · ${chosen.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ConversionPreview(
                                amount: ExactDecimal.parse('1000'),
                                from: 'PHP',
                                to: chosen.code,
                              ),
                              if (!selectable)
                                const Text(
                                  'This recognized currency has no current applicable quote. Keep your existing preference or refresh rates.',
                                  style: TextStyle(
                                    color: SaveTrackDesign.warning,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              GradientButton(
                                key: const ValueKey('apply-currency'),
                                onPressed: !selectable || service.saving
                                    ? null
                                    : () async {
                                        final success = await service.apply(
                                          chosen.code,
                                        );
                                        if (success && context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Display currency updated to ${chosen.code}.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                child: Text(
                                  service.saving ? 'Saving…' : 'Apply Currency',
                                ),
                              ),
                              if (service.preferenceError != null)
                                Text(
                                  service.preferenceError!,
                                  style: const TextStyle(
                                    color: SaveTrackDesign.error,
                                  ),
                                ),
                              if (service.preferencePending)
                                const Text(
                                  'Preference saved on this device; syncing to your account.',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const CurrencyConverter(),
                      const SizedBox(height: 20),
                      Text(
                        'All active fiat currencies (${currencies.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'Only currencies with provider quotes can be selected. Your stored balances keep their original denomination.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.builder(
                    itemCount: currencies.length,
                    itemBuilder: (context, index) {
                      final currency = currencies[index],
                          available =
                              currency.code == 'PHP' ||
                              service.supports(currency.code);
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          key: ValueKey('currency-${currency.code}'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          selected: selected == currency.code,
                          selectedTileColor: SaveTrackDesign.lightMint,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.white,
                            foregroundColor: teal,
                            child: Text(
                              currency.symbol,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          title: Text('${currency.code} · ${currency.name}'),
                          subtitle: Text(
                            available
                                ? (currency.regions.length <= 2
                                      ? currency.regions.join(', ')
                                      : '${currency.regions.length} countries and regions')
                                : service.availability(currency.code) ==
                                      CurrencyAvailability.unsupported
                                ? 'Not supported by the provider'
                                : 'Quote temporarily unavailable',
                          ),
                          trailing: AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : SaveTrackDesign.motion,
                            child: selected == currency.code
                                ? Icon(
                                    Icons.check_circle,
                                    key: ValueKey(currency.code),
                                    color: teal,
                                  )
                                : const Icon(
                                    Icons.circle_outlined,
                                    size: 22,
                                    color: muted,
                                  ),
                          ),
                          onTap: () => setState(() => selected = currency.code),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConversionPreview extends StatelessWidget {
  const ConversionPreview({
    super.key,
    required this.amount,
    required this.from,
    required this.to,
    this.snapshot,
  });
  final ExactDecimal amount;
  final String from, to;
  final ExchangeRateSnapshot? snapshot;
  @override
  Widget build(BuildContext context) {
    final controller = CurrencyScope.maybeOf(context),
        rates = snapshot ?? controller?.snapshot;
    try {
      final conversion = CurrencyConversionService(rates),
          rate = conversion.quote(from, to);
      return Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatCurrency(amount, from),
              style: const TextStyle(color: muted),
            ),
            Text(
              formatCurrency(conversion.convert(amount, from, to), to),
              key: const ValueKey('converted-preview'),
              style: SaveTrackDesign.amount.copyWith(fontSize: 24, color: teal),
            ),
            if (from != to) ...[
              Text(
                '1 $from = ${rate.fixed(8)} $to',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              if (rates != null)
                Text(
                  'Provider updated: ${rateTime(rates.providerTime)}${controller?.stale == true ? ' · saved rates' : ''}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
            ],
          ],
        ),
      );
    } on CurrencyFailure {
      return const Text(
        'Exchange rates unavailable for this conversion.',
        style: TextStyle(color: SaveTrackDesign.warning),
      );
    }
  }
}

class CurrencyConverter extends StatefulWidget {
  const CurrencyConverter({super.key});
  @override
  State<CurrencyConverter> createState() => _CurrencyConverterState();
}

class _CurrencyConverterState extends State<CurrencyConverter> {
  final amount = TextEditingController(text: '1000');
  String from = 'PHP', to = 'USD';
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ExactDecimal? value;
    try {
      value = ExactDecimal.parse(amount.text);
    } on CurrencyFailure {
      /* show invalid input */
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Currency Converter',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text(
              'Preview only · no money is exchanged',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('converter-amount'),
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
              onChanged: (_) => setState(() {}),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () async {
                    final next = await chooseCurrency(context, from);
                    if (next != null && mounted) setState(() => from = next);
                  },
                  child: Text('From: $from'),
                ),
                IconButton(
                  key: const ValueKey('swap-currencies'),
                  tooltip: 'Swap currencies',
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () => setState(() {
                    final old = from;
                    from = to;
                    to = old;
                  }),
                ),
                TextButton(
                  onPressed: () async {
                    final next = await chooseCurrency(context, to);
                    if (next != null && mounted) setState(() => to = next);
                  },
                  child: Text('To: $to'),
                ),
              ],
            ),
            if (value == null)
              const Text('Enter a valid number.')
            else
              ConversionPreview(amount: value, from: from, to: to),
          ],
        ),
      ),
    );
  }
}
