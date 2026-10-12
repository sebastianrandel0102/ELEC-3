import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'currency_money.dart';
import 'currency_catalog_data.dart';

enum CurrencyAvailability { supported, temporarilyUnavailable, unsupported }

class ExchangeRateSnapshot {
  ExchangeRateSnapshot({
    required this.base,
    required Map<String, ExactDecimal> rates,
    required this.providerTime,
    required this.fetchedAt,
    required this.nextUpdate,
  }) : rates = Map.unmodifiable(rates);
  final String base;
  final Map<String, ExactDecimal> rates;
  final DateTime providerTime, fetchedAt, nextUpdate;
  String get provider => 'ExchangeRate-API';
  String get id => '$provider:$base:${providerTime.millisecondsSinceEpoch}';
  bool stale(DateTime now, Duration interval) =>
      !now.isBefore(nextUpdate) || now.difference(providerTime) >= interval;
  factory ExchangeRateSnapshot.fromProvider(
    Map<String, dynamic> data,
    DateTime fetchedAt,
  ) {
    if (data['result'] != 'success' ||
        data['base_code'] != 'USD' ||
        data['rates'] is! Map) {
      throw const CurrencyFailure('Invalid exchange-rate response.');
    }
    DateTime timestamp(String key) {
      final seconds = data[key];
      if (seconds is! int || seconds <= 0) {
        throw const CurrencyFailure('Invalid rate timestamp.');
      }
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }

    final providerTime = timestamp('time_last_update_unix'),
        next = timestamp('time_next_update_unix');
    if (providerTime.isAfter(fetchedAt.add(const Duration(minutes: 10))) ||
        !next.isAfter(providerTime) ||
        next.difference(providerTime) > const Duration(days: 7)) {
      throw const CurrencyFailure('Invalid rate timestamp.');
    }
    final quotes = <String, ExactDecimal>{};
    for (final entry in (data['rates'] as Map).entries) {
      if (entry.key is! String ||
          !RegExp(r'^[A-Z]{3}$').hasMatch(entry.key as String) ||
          entry.value is! num) {
        throw const CurrencyFailure('Invalid exchange-rate response.');
      }
      final quote = ExactDecimal.fromNum(entry.value as num);
      if (!quote.positive ||
          quote.compareTo(ExactDecimal.parse('1000000000')) > 0) {
        throw const CurrencyFailure('Invalid exchange-rate quote.');
      }
      quotes[entry.key as String] = quote;
    }
    if (quotes['USD']?.compareTo(ExactDecimal.one) != 0 || quotes.length < 2) {
      throw const CurrencyFailure('Invalid base currency quote.');
    }
    return ExchangeRateSnapshot(
      base: 'USD',
      rates: quotes,
      providerTime: providerTime,
      fetchedAt: fetchedAt.toUtc(),
      nextUpdate: next,
    );
  }
  Map<String, dynamic> toCache() => {
    'version': 1,
    'provider': provider,
    'base_code': base,
    'result': 'success',
    'time_last_update_unix': providerTime.millisecondsSinceEpoch ~/ 1000,
    'time_next_update_unix': nextUpdate.millisecondsSinceEpoch ~/ 1000,
    'fetchedAt': fetchedAt.toIso8601String(),
    'rates': {for (final e in rates.entries) e.key: e.value.toDouble()},
  };
  factory ExchangeRateSnapshot.fromCache(
    Map<String, dynamic> data,
    DateTime now,
  ) {
    if (data['version'] != 1 ||
        data['provider'] != 'ExchangeRate-API' ||
        data['fetchedAt'] is! String) {
      throw const CurrencyFailure('Invalid saved rates.');
    }
    final fetched = DateTime.tryParse(data['fetchedAt'] as String);
    if (fetched == null ||
        fetched.isAfter(now.add(const Duration(minutes: 10)))) {
      throw const CurrencyFailure('Invalid saved rate timestamp.');
    }
    return ExchangeRateSnapshot.fromProvider(data, fetched);
  }
}

class CurrencyConversionService {
  const CurrencyConversionService(this.snapshot);
  final ExchangeRateSnapshot? snapshot;
  ExactDecimal quote(String from, String to) {
    CurrencyCatalog.require(from);
    CurrencyCatalog.require(to);
    if (from == to) return ExactDecimal.one;
    final a = snapshot?.rates[from], b = snapshot?.rates[to];
    if (a == null || b == null) {
      throw const CurrencyFailure(
        'Exchange rate unavailable for this currency.',
      );
    }
    return b / a;
  }

  ExactDecimal convert(ExactDecimal value, String from, String to) =>
      value * quote(from, to);
  ExactDecimal total(Iterable<(num, String)> amounts, String to) =>
      amounts.fold(
        ExactDecimal.zero,
        (sum, item) =>
            sum + convert(ExactDecimal.fromNum(item.$1), item.$2, to),
      );
}

abstract interface class RateCache {
  Future<String?> read();
  Future<void> write(String data);
}

class DeviceRateCache implements RateCache {
  static const key = 'savetrack.exchangeRates.v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String data) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, data)) {
      throw const CurrencyFailure('Unable to save rates for offline use.');
    }
  }
}

class ExchangeRateProvider {
  ExchangeRateProvider({http.Client? client})
    : client = client ?? http.Client();
  final http.Client client;
  static final endpoint = Uri.parse('https://open.er-api.com/v6/latest/USD');
  Future<ExchangeRateSnapshot> fetch(DateTime now) async {
    final response = await client
        .get(endpoint)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 429) {
      throw const CurrencyFailure(
        'Too many rate requests. Please try again later.',
      );
    }
    if (response.statusCode != 200 || response.body.length > 100000) {
      throw const CurrencyFailure(
        'Exchange rates are temporarily unavailable.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const CurrencyFailure('Invalid exchange-rate response.');
    }
    return ExchangeRateSnapshot.fromProvider(decoded, now);
  }

  void dispose() => client.close();
}

/// One validated snapshot shared by every amount. No fetches during builds.
class CurrencyController extends ChangeNotifier {
  CurrencyController({
    ExchangeRateProvider? provider,
    RateCache? cache,
    DateTime Function()? clock,
    this.refreshInterval = const Duration(days: 1),
    this.minimumRequestInterval = const Duration(hours: 1),
    this.savePreference,
    this.initialCurrency = 'PHP',
  }) : provider = provider ?? ExchangeRateProvider(),
       cache = cache ?? DeviceRateCache(),
       clock = clock ?? DateTime.now,
       preferred = initialCurrency;
  final ExchangeRateProvider provider;
  final RateCache cache;
  final DateTime Function() clock;
  final Duration refreshInterval, minimumRequestInterval;
  final Future<void> Function(String code)? savePreference;
  final String initialCurrency;
  String preferred;
  ExchangeRateSnapshot? snapshot;
  bool loading = false, saving = false, usingCache = false, disposed = false;
  String? error, preferenceError;
  bool preferencePending = false;
  DateTime? _lastAttempt;
  Future<void>? _pending;
  CurrencyConversionService get conversion =>
      CurrencyConversionService(snapshot);
  bool get stale => snapshot?.stale(clock().toUtc(), refreshInterval) ?? true;
  bool supports(String code) =>
      CurrencyCatalog.byCode.containsKey(code) &&
      snapshot?.rates.containsKey(code) == true;
  CurrencyAvailability availability(String code) => supports(code)
      ? CurrencyAvailability.supported
      : providerCatalogCodes.contains(code)
      ? CurrencyAvailability.temporarilyUnavailable
      : CurrencyAvailability.unsupported;
  String get status => snapshot == null
      ? 'Exchange rates unavailable'
      : usingCache || stale || error != null
      ? 'Using saved rates'
      : 'Updated recently';
  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final saved = await cache.read();
      if (disposed) return;
      if (saved != null) {
        snapshot = ExchangeRateSnapshot.fromCache(
          Map<String, dynamic>.from(jsonDecode(saved) as Map),
          clock().toUtc(),
        );
        usingCache = true;
        changed();
      }
    } catch (_) {
      /* Invalid cache never becomes a conversion snapshot. */
    }
    if (disposed) return;
    if (stale) await refresh();
  }

  Future<void> refresh({bool force = false}) {
    if (disposed) return Future.value();
    if (_pending != null) return _pending!;
    final now = clock().toUtc();
    if (!force && !stale) return Future.value();
    if (_lastAttempt != null &&
        now.difference(_lastAttempt!) < minimumRequestInterval) {
      return Future.value();
    }
    // Also respect a successful fetch cached across app restarts.
    if (snapshot != null &&
        now.difference(snapshot!.fetchedAt) < minimumRequestInterval) {
      return Future.value();
    }
    _lastAttempt = now;
    loading = true;
    error = null;
    changed();
    return _pending = _fetch(now).whenComplete(() => _pending = null);
  }

  Future<void> _fetch(DateTime now) async {
    try {
      final value = await provider.fetch(now);
      if (disposed) return;
      // Do not replace a newer snapshot with an older provider response.
      if (snapshot != null &&
          value.providerTime.isBefore(snapshot!.providerTime)) {
        throw const CurrencyFailure(
          'The provider returned older exchange rates.',
        );
      }
      snapshot = value;
      usingCache = false;
      try {
        await cache.write(jsonEncode(value.toCache()));
      } catch (_) {
        error = 'Rates updated; offline cache could not be saved.';
      }
    } catch (failure) {
      if (disposed) return;
      error = failure is CurrencyFailure ? failure.message : 'Exchange rates are temporarily unavailable. Check your connection.';
      usingCache = snapshot != null;
    } finally {
      if (!disposed) {
        loading = false;
        changed();
      }
    }
  }

  void receivePreference(String? code) {
    final next = CurrencyCatalog.byCode.containsKey(code) ? code! : 'PHP';
    if (next != preferred && !saving) {
      preferred = next;
      changed();
    }
  }

  Future<bool> apply(String code) async {
    if (saving || disposed) return false;
    if (!CurrencyCatalog.byCode.containsKey(code) ||
        (code != 'PHP' && !supports(code))) {
      preferenceError =
          'This currency is not currently available for conversion.';
      changed();
      return false;
    }
    saving = true;
    preferenceError = null;
    changed();
    try {
      if (savePreference == null) {
        throw const CurrencyFailure(
          'Sign in to save your currency preference.',
        );
      }
      await savePreference!(code);
      if (disposed) return false;
      preferred = code;
      return true;
    } catch (_) {
      preferenceError =
          'Unable to update your preferred currency. Please try again.';
      return false;
    } finally {
      if (!disposed) {
        saving = false;
        changed();
      }
    }
  }

  String display(num amount, [String from = 'PHP']) {
    if (!amount.isFinite) return '$from amount unavailable';
    try {
      return formatCurrency(
        conversion.convert(ExactDecimal.fromNum(amount), from, preferred),
        preferred,
      );
    } on CurrencyFailure {
      return '${originalMoney(amount, from)} · conversion unavailable';
    }
  }

  String totalDisplay(Iterable<(num, String)> values) {
    final items = values.toList();
    if (items.any((item) => !item.$1.isFinite)) {
      return 'Total unavailable · invalid stored amount';
    }
    try {
      return formatCurrency(conversion.total(items, preferred), preferred);
    } on CurrencyFailure {
      // Never silently omit an unavailable goal or mix denominations.
      final grouped = <String, ExactDecimal>{};
      for (final item in items) {
        grouped[item.$2] =
            (grouped[item.$2] ?? ExactDecimal.zero) +
            ExactDecimal.fromNum(item.$1);
      }
      return '${grouped.entries.map((e) => formatCurrency(e.value, e.key)).join(' + ')} · conversion unavailable';
    }
  }

  @override
  void dispose() {
    disposed = true;
    provider.dispose();
    super.dispose();
  }
}
