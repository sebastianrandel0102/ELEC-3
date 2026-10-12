import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myproject/currency_money.dart';
import 'package:myproject/currency_service.dart';
import 'package:myproject/currency_transactions.dart';
import 'package:myproject/shared_savings_models.dart';

import 'savings_decrease_test.dart' as store;

final fixtureTime = DateTime.utc(2026, 1, 1, 12);
Map<String, dynamic> rateFixture({Map<String, num>? quotes}) => {
  'result': 'success',
  'base_code': 'USD',
  'time_last_update_unix':
      DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
  'time_next_update_unix':
      DateTime.utc(2026, 1, 2).millisecondsSinceEpoch ~/ 1000,
  'rates':
      quotes ??
      {
        'USD': 1,
        'PHP': 50,
        'EUR': .8,
        'JPY': 150,
        'KWD': .3,
        'SGD': 1.2,
        'GBP': .7,
      },
};
ExchangeRateSnapshot fixtureSnapshot() =>
    ExchangeRateSnapshot.fromProvider(rateFixture(), fixtureTime);

class MemoryRateCache implements RateCache {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    if (failWrite) throw StateError('disk');
    value = data;
  }
}

CurrencyController fixtureController({Future<void> Function(String)? save}) =>
    CurrencyController(
      clock: () => fixtureTime,
      cache: MemoryRateCache(),
      savePreference: save ?? (_) async {},
      provider: ExchangeRateProvider(
        client: MockClient(
          (_) async => http.Response(jsonEncode(rateFixture()), 200),
        ),
      ),
    )..snapshot = fixtureSnapshot();

void main() {
  group('ISO catalog and money precision', () {
    test('active fiat worldwide catalog and region searches', () {
      expect(CurrencyCatalog.all.length, 155);
      expect(CurrencyCatalog.require('JPY').matches('Japan'), isTrue);
      expect(CurrencyCatalog.require('USD').matches('usd'), isTrue);
      expect(CurrencyCatalog.require('PHP').matches('peso'), isTrue);
      expect(CurrencyCatalog.require('EUR').regions.length, greaterThan(20));
      for (final excluded in [
        'XAU',
        'XDR',
        'CLF',
        'BTC',
        'BGN',
        'ANG',
        'ZWL',
      ]) {
        expect(CurrencyCatalog.byCode.containsKey(excluded), isFalse);
      }
      expect(CurrencyCatalog.require('XCG').digits, 2);
      expect(CurrencyCatalog.require('ZWG').digits, 2);
    });
    for (final entry in [('PHP', '1.01'), ('JPY', '100'), ('KWD', '1.001')]) {
      test('${entry.$1} input precision', () {
        expect(parseCurrencyAmount(entry.$2, entry.$1), isNotNull);
        expect(
          parseCurrencyAmount('${entry.$2}9', entry.$1) != null,
          entry.$1 == 'JPY',
        );
      });
    }
    test('invalid amount, unknown metadata and exponent entry rejected', () {
      for (final text in [
        'NaN',
        'Infinity',
        '-1',
        '+1',
        '1e3',
        '1,000',
        '1.',
        '.5',
        '1.001',
      ]) {
        expect(parseCurrencyAmount(text, 'PHP'), isNull);
      }
      expect(parseCurrencyAmount('1', 'XXX'), isNull);
      expect(originalMoney(double.nan), 'PHP amount unavailable');
      expect(
        () => ExactDecimal.fromNum(double.nan),
        throwsA(isA<CurrencyFailure>()),
      );
      expect(
        () => ExactDecimal.parse('infinity'),
        throwsA(isA<CurrencyFailure>()),
      );
    });
    test('format PHP, USD, JPY, KWD and negative amounts', () {
      expect(originalMoney(1500), 'PHP ₱1,500.00');
      expect(originalMoney(1500, 'USD'), 'USD \$1,500.00');
      expect(originalMoney(1500, 'JPY'), 'JPY ¥1,500');
      expect(originalMoney(1500, 'KWD'), 'KWD 1,500.000');
      expect(originalMoney(-1500), '-PHP ₱1,500.00');
    });
    test('exact arithmetic and half-away currency boundaries', () {
      expect(
        (ExactDecimal.parse('0.1') + ExactDecimal.parse('0.2')).fixed(2),
        '0.30',
      );
      expect(ExactDecimal.parse('1.005').fixed(2), '1.01');
      expect(ExactDecimal.parse('-1.005').fixed(2), '-1.01');
      expect(ExactDecimal.parse('1.5').fixed(0), '2');
      expect(ExactDecimal.parse('1.2345').fixed(3), '1.235');
      expect(ExactDecimal.parse('0.0000001').fixed(8), '0.00000010');
    });
  });
  group('conversion and presentation', () {
    final engine = CurrencyConversionService(fixtureSnapshot());
    for (final conversion in [
      ('PHP', 'USD', '1000', '20.00'),
      ('USD', 'PHP', '20', '1000.00'),
      ('EUR', 'JPY', '8', '1500'),
      ('PHP', 'KWD', '50', '0.300'),
    ]) {
      test('${conversion.$1} to ${conversion.$2}', () {
        expect(
          engine
              .convert(
                ExactDecimal.parse(conversion.$3),
                conversion.$1,
                conversion.$2,
              )
              .fixed(CurrencyCatalog.require(conversion.$2).digits),
          conversion.$4,
        );
      });
    }
    test('cross quote correct direction and exact inversion', () {
      expect(engine.quote('PHP', 'USD').fixed(4), '0.0200');
      expect(
        (engine.quote('PHP', 'USD') * engine.quote('USD', 'PHP')).compareTo(
          ExactDecimal.one,
        ),
        0,
      );
    });
    test('same currency works without a snapshot, zero and signed amounts', () {
      expect(
        const CurrencyConversionService(null).quote('JPY', 'JPY').fixed(0),
        '1',
      );
      expect(engine.convert(ExactDecimal.zero, 'EUR', 'JPY').fixed(0), '0');
      expect(
        engine.convert(ExactDecimal.parse('-100'), 'USD', 'PHP').fixed(2),
        '-5000.00',
      );
    });
    test('missing rate never defaults to one and missing metadata fails', () {
      expect(() => engine.quote('PHP', 'KPW'), throwsA(isA<CurrencyFailure>()));
      expect(() => engine.quote('PHP', 'XXX'), throwsA(isA<CurrencyFailure>()));
      expect(
        () => const CurrencyConversionService(null).quote('PHP', 'USD'),
        throwsA(isA<CurrencyFailure>()),
      );
    });
    test('very large values retain decimal digits', () {
      final value = ExactDecimal.parse('123456789012345678901234567890.01');
      expect(
        engine.convert(value, 'USD', 'PHP').fixed(2),
        '6172839450617283945061728394500.50',
      );
    });
    test('no cumulative rounding and preference PHP to USD to PHP', () async {
      final controller = fixtureController();
      addTearDown(controller.dispose);
      final stored = {'savedAmount': 1234.57};
      final original = controller.display(stored['savedAmount']!);
      for (var i = 0; i < 30; i++) {
        expect(await controller.apply('USD'), isTrue);
        expect(controller.display(stored['savedAmount']!), 'USD \$24.69');
        expect(await controller.apply('PHP'), isTrue);
        expect(controller.display(stored['savedAmount']!), original);
      }
      expect(stored['savedAmount'], 1234.57);
    });
    test('mixed savings total uses one snapshot and rounds after addition', () {
      expect(
        engine
            .total([
              (1000, 'PHP'),
              (10, 'USD'),
              (8, 'EUR'),
              (1500, 'JPY'),
            ], 'PHP')
            .fixed(2),
        '2500.00',
      );
      expect(
        engine.total([(0.01, 'USD'), (0.01, 'USD')], 'KWD').fixed(3),
        '0.006',
      );
    });
    test('completed progress and daily/weekly requirements preserved', () {
      final goal = SharedSavingsGoal('g', {
        'targetAmount': 1000,
        'currentAmount': 1000,
      });
      expect(goal.progress, 1);
      final target = engine.convert(ExactDecimal.parse('1000'), 'PHP', 'USD');
      final saved = engine.convert(ExactDecimal.parse('500'), 'PHP', 'USD');
      expect((saved / target).fixed(2), '0.50');
      expect(
        engine.convert(ExactDecimal.parse('100'), 'PHP', 'USD').fixed(2),
        '2.00',
      );
      expect(
        engine.convert(ExactDecimal.parse('700'), 'PHP', 'USD').fixed(2),
        '14.00',
      );
    });
    test('legacy goals default PHP and shared balance remains PHP', () {
      expect(goalCurrency({'targetAmount': 100}), 'PHP');
      final controller = fixtureController();
      addTearDown(controller.dispose);
      controller.receivePreference('EUR');
      expect(controller.display(1000, 'PHP'), 'EUR €16.00');
      expect(goalCurrency({'targetAmount': 100}), 'PHP');
    });
    test(
      'unavailable mixed total shows original grouped amounts without omission',
      () {
        final controller = fixtureController();
        addTearDown(controller.dispose);
        controller.snapshot = null;
        expect(
          controller.totalDisplay([(1000, 'PHP'), (10, 'USD')]),
          'PHP ₱1,000.00 + USD \$10.00 · conversion unavailable',
        );
        expect(
          controller.display(10, 'USD'),
          contains('conversion unavailable'),
        );
      },
    );
  });
  group('provider validation and local cache', () {
    test('provider and fetch timestamp distinct and UTC', () {
      final value = fixtureSnapshot();
      expect(value.providerTime, DateTime.utc(2026, 1, 1));
      expect(value.fetchedAt, fixtureTime);
      expect(value.nextUpdate, DateTime.utc(2026, 1, 2));
      expect(value.stale(fixtureTime, const Duration(days: 1)), isFalse);
      expect(
        value.stale(DateTime.utc(2026, 1, 2), const Duration(days: 1)),
        isTrue,
      );
    });
    test('reject malformed provider data, invalid quotes and timestamps', () {
      for (final data in [
        {...rateFixture(), 'result': 'error'},
        {...rateFixture(), 'base_code': 'PHP'},
        {...rateFixture(), 'time_last_update_unix': 'invalid'},
        {...rateFixture(), 'time_next_update_unix': 1},
        {
          ...rateFixture(),
          'time_last_update_unix':
              DateTime.utc(2027).millisecondsSinceEpoch ~/ 1000,
        },
        rateFixture(quotes: {'USD': 2, 'PHP': 50}),
        rateFixture(quotes: {'USD': 1, 'PHP': 0}),
        rateFixture(quotes: {'USD': 1, 'PHP': -1}),
        rateFixture(quotes: {'USD': 1, 'PHP': double.infinity}),
      ]) {
        expect(
          () => ExchangeRateSnapshot.fromProvider(data, fixtureTime),
          throwsA(isA<CurrencyFailure>()),
        );
      }
    });
    test('cache round trip validates origin, version and timestamps', () {
      final data = jsonDecode(
        jsonEncode(fixtureSnapshot().toCache()),
      ) as Map<String, dynamic>;
      final cached = ExchangeRateSnapshot.fromCache(data, fixtureTime);
      expect(
        CurrencyConversionService(cached).quote('PHP', 'USD').fixed(4),
        '0.0200',
      );
      expect(
        () => ExchangeRateSnapshot.fromCache({
          ...data,
          'version': 2,
        }, fixtureTime),
        throwsA(isA<CurrencyFailure>()),
      );
      expect(
        () => ExchangeRateSnapshot.fromCache({
          ...data,
          'fetchedAt': 'bad',
        }, fixtureTime),
        throwsA(isA<CurrencyFailure>()),
      );
    });
    test(
      'HTTP retrieval validates endpoint and keeps one successful snapshot',
      () async {
        var calls = 0;
        final cache = MemoryRateCache();
        final controller = CurrencyController(
          clock: () => fixtureTime,
          cache: cache,
          provider: ExchangeRateProvider(
            client: MockClient((request) async {
              calls++;
              expect(request.url, ExchangeRateProvider.endpoint);
              return http.Response(jsonEncode(rateFixture()), 200);
            }),
          ),
        );
        addTearDown(controller.dispose);
        await Future.wait([
          controller.refresh(),
          controller.refresh(),
          controller.refresh(),
        ]);
        expect(calls, 1);
        expect(cache.value, isNotNull);
        expect(controller.status, 'Updated recently');
        await controller.refresh(force: true);
        expect(calls, 1);
      },
    );
    test('fresh cache prevents refetch across app restarts', () async {
      var calls = 0;
      final cache = MemoryRateCache()
        ..value = jsonEncode(fixtureSnapshot().toCache());
      final controller = CurrencyController(
        clock: () => fixtureTime,
        cache: cache,
        provider: ExchangeRateProvider(
          client: MockClient((_) async {
            calls++;
            return http.Response('', 500);
          }),
        ),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(calls, 0);
      expect(controller.status, 'Using saved rates');
      expect(controller.display(50, 'PHP'), 'PHP ₱50.00');
    });
    test(
      'stale cache survives provider outage and is clearly labeled',
      () async {
        final cache = MemoryRateCache()
          ..value = jsonEncode(fixtureSnapshot().toCache());
        final controller = CurrencyController(
          clock: () => DateTime.utc(2026, 1, 3),
          cache: cache,
          provider: ExchangeRateProvider(
            client: MockClient((_) async => http.Response('', 503)),
          ),
        );
        addTearDown(controller.dispose);
        await controller.initialize();
        controller.receivePreference('USD');
        expect(controller.stale, isTrue);
        expect(controller.status, 'Using saved rates');
        expect(controller.display(1000), 'USD \$20.00');
        expect(controller.error, isNotNull);
      },
    );
    test(
      'invalid cache and invalid JSON never produce fabricated rates',
      () async {
        final cache = MemoryRateCache()..value = '{broken';
        final controller = CurrencyController(
          clock: () => fixtureTime,
          cache: cache,
          provider: ExchangeRateProvider(
            client: MockClient((_) async => http.Response('not JSON', 200)),
          ),
        );
        addTearDown(controller.dispose);
        await controller.initialize();
        expect(controller.snapshot, isNull);
        expect(controller.error, isNotNull);
        expect(controller.status, 'Exchange rates unavailable');
      },
    );
    test(
      '429 yields a clear rate limit error and requests are throttled',
      () async {
        var calls = 0;
        final controller = CurrencyController(
          clock: () => fixtureTime,
          cache: MemoryRateCache(),
          provider: ExchangeRateProvider(
            client: MockClient((_) async {
              calls++;
              return http.Response('', 429);
            }),
          ),
        );
        addTearDown(controller.dispose);
        await controller.refresh();
        await controller.refresh(force: true);
        expect(calls, 1);
        expect(controller.error, contains('Too many rate requests'));
      },
    );
    test('coverage separates unsupported and temporarily missing quotes', () {
      final controller = fixtureController();
      addTearDown(controller.dispose);
      expect(controller.availability('KPW'), CurrencyAvailability.unsupported);
      expect(
        controller.availability('AUD'),
        CurrencyAvailability.temporarilyUnavailable,
      );
      expect(controller.availability('JPY'), CurrencyAvailability.supported);
    });
    test(
      'preference failure keeps original and never saves unsupported choice',
      () async {
        var calls = 0;
        final controller = fixtureController(
          save: (_) async {
            calls++;
            throw StateError('denied');
          },
        );
        addTearDown(controller.dispose);
        expect(await controller.apply('USD'), isFalse);
        expect(controller.preferred, 'PHP');
        expect(controller.preferenceError, contains('Unable to update'));
        expect(await controller.apply('KPW'), isFalse);
        expect(calls, 1);
        controller.receivePreference('BGN');
        expect(controller.preferred, 'PHP');
      },
    );
  });
  group('atomic currency-aware tracking', () {
    LockedMoneyEntry entry(
      String text, {
      String from = 'USD',
      String to = 'PHP',
    }) => LockedMoneyEntry.create(
      text: text,
      from: from,
      to: to,
      snapshot: fixtureSnapshot(),
      now: fixtureTime,
    );
    test('locked cross rate and metadata retain the source and authoritative amount', () {
      final value = entry('10');
      expect(value.amount.fixed(2), '500.00');
      expect(value.metadata!['inputAmount'], 10);
      expect(value.metadata!['exchangeRate'], 50);
      validateConversionMetadata(value.metadata!, 500, 'PHP');
      expect(
        () => validateConversionMetadata(value.metadata!, 501, 'PHP'),
        throwsA(isA<CurrencyFailure>()),
      );
    });
    test(
      'stale cross entries blocked while original currency works offline',
      () {
        expect(
          () => LockedMoneyEntry.create(
            text: '10',
            from: 'USD',
            to: 'PHP',
            snapshot: fixtureSnapshot(),
            now: DateTime.utc(2026, 1, 3),
          ),
          throwsA(isA<CurrencyFailure>()),
        );
        expect(
          LockedMoneyEntry.create(
            text: '10',
            from: 'JPY',
            to: 'JPY',
          ).amount.fixed(0),
          '10',
        );
        expect(
          () => entry('0.01', from: 'PHP', to: 'JPY'),
          throwsA(isA<CurrencyFailure>()),
        );
      },
    );
    test(
      'zero-decimal cross input metadata accepts numeric Firestore doubles',
      () {
        final value = entry('150', from: 'JPY');
        expect(value.metadata!['inputAmount'], 150.0);
        validateConversionMetadata(value.metadata!, 50.0, 'PHP');
        expect(value.amount.fixed(2), '50.00');
      },
    );
    Future<(store.SavingsFirestore, store.SavingsReference)> savings({
      String currency = 'PHP',
      double balance = 1000,
    }) async {
      final db = store.SavingsFirestore();
      final ref = store.SavingsReference(db, 'users/owner/goals/trip');
      db.documents[ref.path] = {
        'savedAmount': balance,
        'currencyCode': currency,
        'targetAmount': 5000,
      };
      return (db, ref);
    }

    test('deposit, retry and legacy deposit history stay accurate', () async {
      final (db, ref) = await savings();
      db.documents['${ref.path}/transactions/old'] = {
        'amount': 100,
        'note': 'legacy',
      };
      final value = entry('10');
      Future<void> save() => recordCurrencySavings(
        goal: ref,
        uid: 'owner',
        entry: value,
        note: 'saved',
        requestId: 'deposit_request',
        withdrawal: false,
        auth: store.SavingsAuth(),
      );
      await save();
      await save();
      expect(db.documents[ref.path]!['savedAmount'], 1500);
      expect(
        db.documents['${ref.path}/transactions/deposit_request']!['amount'],
        500,
      );
      expect(db.documents['${ref.path}/transactions/old'], {
        'amount': 100,
        'note': 'legacy',
      });
      expect(db.documents.length, 3);
    });
    test('decrease is atomic, constrained and retains confirmed conversion', () async {
      final (db, ref) = await savings();
      await recordCurrencySavings(
        goal: ref,
        uid: 'owner',
        entry: entry('10'),
        note: 'expense',
        requestId: 'withdrawal_request',
        withdrawal: true,
        auth: store.SavingsAuth(),
      );
      expect(db.documents[ref.path]!['savedAmount'], 500);
      expect(
        db.documents['${ref.path}/transactions/withdrawal_request']!['conversion'],
        isNotNull,
      );
      await expectLater(
        recordCurrencySavings(
          goal: ref,
          uid: 'owner',
          entry: entry('11'),
          note: '',
          requestId: 'overdraw',
          withdrawal: true,
          auth: store.SavingsAuth(),
        ),
        throwsA(isA<CurrencyFailure>()),
      );
      expect(db.documents[ref.path]!['savedAmount'], 500);
    });
    test('concurrent balance changes retry without losing a deposit', () async {
      final (db, ref) = await savings();
      db.beforeCommit = () {
        db.documents[ref.path]!['savedAmount'] = 1200;
        db.version++;
      };
      await recordCurrencySavings(
        goal: ref,
        uid: 'owner',
        entry: entry('10'),
        note: '',
        requestId: 'request',
        withdrawal: false,
        auth: store.SavingsAuth(),
      );
      expect(db.attempts, 2);
      expect(db.documents[ref.path]!['savedAmount'], 1700);
    });
    test(
      'JPY and KWD goals record their own precision without revaluation',
      () async {
        for (final code in ['JPY', 'KWD']) {
          final (db, ref) = await savings(currency: code);
          final value = entry(
            code == 'JPY' ? '10' : '0.001',
            from: code,
            to: code,
          );
          await recordCurrencySavings(
            goal: ref,
            uid: 'owner',
            entry: value,
            note: '',
            requestId: 'request',
            withdrawal: false,
            auth: store.SavingsAuth(),
          );
          expect(db.documents[ref.path]!['currencyCode'], code);
          expect(
            db.documents[ref.path]!['savedAmount'],
            code == 'JPY' ? 1010 : 1000.001,
          );
        }
      },
    );
    test(
      'historical locked amount is independent of today’s display quote',
      () {
        final recorded = entry('10');
        final newer = ExchangeRateSnapshot.fromProvider(
          rateFixture(quotes: {'USD': 1, 'PHP': 60}),
          fixtureTime,
        );
        expect(recorded.amount.fixed(2), '500.00');
        expect(recorded.metadata!['exchangeRate'], 50);
        expect(
          CurrencyConversionService(newer)
              .convert(recorded.amount, 'PHP', 'USD')
              .fixed(2),
          '8.33',
        );
      },
    );
  });
}
