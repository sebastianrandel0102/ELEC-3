import 'dart:async';

import 'ui_preview_fonts.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myproject/currency_savings_dialog.dart';
import 'package:myproject/currency_service.dart';
import 'package:myproject/currency_settings_screen.dart';
import 'package:myproject/currency_transactions.dart';
import 'package:myproject/currency_widgets.dart';
import 'package:myproject/main.dart';

import 'currency_system_test.dart' as fixtures;
import 'redesign_test.dart' as ui;
import 'savings_decrease_test.dart' as store;

Future<void> mountCurrency(
  WidgetTester tester,
  CurrencyController controller,
  Widget home, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    CurrencyScope(
      controller: controller,
      child: MaterialApp(
        theme: const bool.fromEnvironment('SAVE_UI_PREVIEWS')
            ? SaveTrackDesign.theme.copyWith(
                textTheme: SaveTrackDesign.theme.textTheme.apply(
                  fontFamily: 'Manrope',
                ),
              )
            : SaveTrackDesign.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: ui.previewKey, child: child!),
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 250,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadManropeForPreviews();
    if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
    final config = jsonDecode(
      await File('.dart_tool/package_config.json').readAsString(),
    ) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == 'flutter');
    final sdk = Uri.parse('${flutter['rootUri']}/').resolve('../../');
    for (final entry in {
      'Roboto': 'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      'MaterialIcons':
          'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final file = File.fromUri(sdk.resolve(entry.value));
      if (await file.exists()) {
        await (FontLoader(entry.key)..addFont(
              file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
      }
    }
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetViewInsets();
  });
  testWidgets('Profile opens functional Currency Settings', (tester) async {
    final controller = fixtures.fixtureController();
    addTearDown(controller.dispose);
    await mountCurrency(
      tester,
      controller,
      Scaffold(
        body: ProfileContent(
          name: 'Alex',
          email: 'a@example.com',
          onPassword: () {},
          onSignOut: () {},
        ),
      ),
    );
    await reveal(
      tester,
      find.byKey(const ValueKey('open-currency-settings')),
      delta: 250,
    );
    await tester.tap(find.byKey(const ValueKey('open-currency-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Choose Your Currency'), findsOneWidget);
    expect(find.text('PHP  ₱'), findsOneWidget);
    expect(find.textContaining('Provider updated:'), findsWidgets);
  });
  testWidgets('search by country/code/name and selected indication', (
    tester,
  ) async {
    final controller = fixtures.fixtureController();
    addTearDown(controller.dispose);
    await mountCurrency(tester, controller, const CurrencySettingsScreen());
    await tester.enterText(
      find.byKey(const ValueKey('settings-currency-search')),
      'Japan',
    );
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const ValueKey('currency-JPY')),
      delta: 300,
    );
    expect(find.byKey(const ValueKey('currency-USD')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('currency-JPY')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('currency-JPY')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    await reveal(
      tester,
      find.byKey(const ValueKey('settings-currency-search')),
      delta: -300,
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-currency-search')),
      'peso',
    );
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const ValueKey('currency-ARS')),
      delta: 300,
    );
    expect(find.byKey(const ValueKey('currency-ARS')), findsOneWidget);
  });
  testWidgets(
    'popular selection updates preview and Apply persists preference',
    (tester) async {
      String? saved;
      final controller = fixtures.fixtureController(
        save: (code) async => saved = code,
      );
      addTearDown(controller.dispose);
      await mountCurrency(tester, controller, const CurrencySettingsScreen());
      await reveal(
        tester,
        find.byKey(const ValueKey('popular-USD')),
        delta: 250,
      );
      await tester.tap(find.byKey(const ValueKey('popular-USD')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('apply-currency')));
      expect(find.text('USD \$20.00'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('apply-currency')));
      await tester.pumpAndSettle();
      expect(saved, 'USD');
      expect(controller.preferred, 'USD');
      await reveal(tester, find.text('USD  \$'), delta: -250);
      expect(find.text('USD  \$'), findsOneWidget);
    },
  );
  testWidgets('missing and unsupported quotes cannot be applied', (
    tester,
  ) async {
    final controller = fixtures.fixtureController();
    addTearDown(controller.dispose);
    await mountCurrency(tester, controller, const CurrencySettingsScreen());
    await tester.enterText(
      find.byKey(const ValueKey('settings-currency-search')),
      'KPW',
    );
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const ValueKey('currency-KPW')),
      delta: 300,
    );
    await tester.tap(find.byKey(const ValueKey('currency-KPW')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('apply-currency')));
    final button = tester.widget<GradientButton>(
      find.byKey(const ValueKey('apply-currency')),
    );
    expect(button.onPressed, isNull);
    expect(controller.preferred, 'PHP');
    expect(find.textContaining('no current applicable quote'), findsOneWidget);
  });
  testWidgets('refresh uses provider, loading and cached state appear', (
    tester,
  ) async {
    var calls = 0;
    final completer = Completer<http.Response>();
    final controller = CurrencyController(
      clock: () => fixtures.fixtureTime,
      cache: fixtures.MemoryRateCache(),
      provider: ExchangeRateProvider(
        client: MockClient((_) {
          calls++;
          return completer.future;
        }),
      ),
    );
    addTearDown(controller.dispose);
    await mountCurrency(tester, controller, const CurrencySettingsScreen());
    await tester.tap(find.byKey(const ValueKey('refresh-rates')));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(http.Response(jsonEncode(fixtures.rateFixture()), 200));
    await tester.pumpAndSettle();
    expect(controller.snapshot, isNotNull);
    expect(controller.loading, isFalse);
    controller.usingCache = true;
    controller.changed();
    await tester.pumpAndSettle();
    expect(find.textContaining('Using saved rates'), findsOneWidget);
  });
  testWidgets('converter input and real direction swap change calculation', (
    tester,
  ) async {
    final controller = fixtures.fixtureController();
    addTearDown(controller.dispose);
    await mountCurrency(
      tester,
      controller,
      const Scaffold(body: CurrencyConverter()),
    );
    expect(find.text('USD \$20.00'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('converter-amount')),
      '500',
    );
    await tester.pumpAndSettle();
    expect(find.text('USD \$10.00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('swap-currencies')));
    await tester.pumpAndSettle();
    expect(find.text('PHP ₱25,000.00'), findsOneWidget);
  });
  testWidgets('currency picker finds country and retains PHP without rates', (
    tester,
  ) async {
    final controller = fixtures.fixtureController();
    addTearDown(controller.dispose);
    await mountCurrency(
      tester,
      controller,
      const Scaffold(body: CurrencyPicker(selected: 'PHP')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('currency-search')),
      'Japan',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pick-JPY')), findsOneWidget);
    controller.snapshot = null;
    controller.changed();
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListTile>(find.byKey(const ValueKey('pick-JPY'))).enabled,
      isFalse,
    );
  });
  testWidgets('goal amounts and progress react to display preference only', (
    tester,
  ) async {
    final controller = fixtures.fixtureController();
    addTearDown(controller.dispose);
    final data = {
      'title': 'Japan trip',
      'targetAmount': 100000.0,
      'savedAmount': 50000.0,
      'currencyCode': 'JPY',
    };
    await mountCurrency(
      tester,
      controller,
      ui.scrollPage(GoalCard(uid: 'owner', doc: ui.TestDocument(data))),
    );
    expect(find.text('PHP ₱16,666.67 saved'), findsOneWidget);
    expect(find.text('50% saved'), findsOneWidget);
    await controller.apply('USD');
    await tester.pumpAndSettle();
    expect(find.text('USD \$333.33 saved'), findsOneWidget);
    expect(find.text('50% saved'), findsOneWidget);
    expect(data['savedAmount'], 50000);
    expect(data['currencyCode'], 'JPY');
  });
  for (final size in [const Size(320, 640), const Size(1280, 800)]) {
    testWidgets('currency screen readable at $size and 200 percent text', (
      tester,
    ) async {
      final controller = fixtures.fixtureController();
      addTearDown(controller.dispose);
      await mountCurrency(
        tester,
        controller,
        const CurrencySettingsScreen(),
        size: size,
        scale: 2,
      );
      await reveal(
        tester,
        find.byKey(const ValueKey('apply-currency')),
        delta: 250,
      );
      expect(tester.takeException(), isNull);
      await reveal(
        tester,
        find.byKey(const ValueKey('currency-AED')),
        delta: 250,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'decrease previews authoritative balance and locks confirmed entry',
    (tester) async {
      final controller = fixtures.fixtureController();
      addTearDown(controller.dispose);
      LockedMoneyEntry? received;
      await mountCurrency(
        tester,
        controller,
        CurrencySavingsDialog(
          initialGoal: {
            'title': 'Trip',
            'savedAmount': 1000.0,
            'targetAmount': 2000.0,
            'currencyCode': 'PHP',
          },
          goalUpdates: const Stream.empty(),
          withdrawal: true,
          onConfirm: (entry, _) async => received = entry,
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('decrease-amount')),
        '150',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Preview · New Savings Balance: PHP ₱850.00'),
        findsOneWidget,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await ui.capture(tester, 'decrease-savings');
      await tester.ensureVisible(find.text('Confirm Decrease'));
      await tester.tap(find.text('Confirm Decrease'));
      await tester.pumpAndSettle();
      expect(received?.amount.fixed(2), '150.00');
    },
  );
  testWidgets('small-screen cross deposit previews source before saving', (
    tester,
  ) async {
    final controller = fixtures.fixtureController();
    addTearDown(controller.dispose);
    final goal = store.SavingsSnapshot({
      'title': 'Trip',
      'savedAmount': 1000.0,
      'targetAmount': 2000.0,
      'currencyCode': 'PHP',
    });
    await mountCurrency(
      tester,
      controller,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => CurrencySavingsDialog(
                initialGoal: goal.data()!,
                goalUpdates: Stream.value(goal),
                onConfirm: (_, _) async {},
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
      size: const Size(320, 640),
      scale: 1.5,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Input Currency: PHP'));
    await tester.tap(find.text('Input Currency: PHP'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('currency-search')),
      'USD',
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('pick-USD'))),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-USD')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('deposit-amount')), '10');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Preview · New Savings Balance: PHP ₱1,500.00'),
    );
    expect(find.text('PHP ₱500.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await ui.capture(tester, 'cross-currency-deposit');
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
  testWidgets('currency picker remains usable above a mobile keyboard', (
    tester,
  ) async {
    final controller = fixtures.fixtureController();
    addTearDown(controller.dispose);
    await mountCurrency(
      tester,
      controller,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => chooseCurrency(context, 'PHP'),
            child: const Text('Choose'),
          ),
        ),
      ),
      size: const Size(320, 640),
      scale: 1.5,
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('currency-search')),
      'Japan',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pick-JPY')), findsOneWidget);
    expect(tester.takeException(), isNull);
    FocusManager.instance.primaryFocus?.unfocus();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-JPY')));
    await tester.pumpAndSettle();
    expect(find.byType(CurrencyPicker), findsNothing);
  });
  testWidgets('currency visual previews', (tester) async {
    final controller = fixtures.fixtureController();
    addTearDown(controller.dispose);
    await mountCurrency(tester, controller, const CurrencySettingsScreen());
    await ui.capture(tester, 'currency-settings');
    await reveal(tester, find.byKey(const ValueKey('popular-USD')), delta: 250);
    await tester.tap(find.byKey(const ValueKey('popular-USD')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('apply-currency')));
    await ui.capture(tester, 'currency-preview');
    await mountCurrency(
      tester,
      controller,
      const CurrencySettingsScreen(),
      size: const Size(320, 640),
      scale: 2,
    );
    await reveal(
      tester,
      find.byKey(const ValueKey('apply-currency')),
      delta: 250,
    );
    await ui.capture(tester, 'currency-narrow');
    expect(tester.takeException(), isNull);
  });
}
