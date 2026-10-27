import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/main.dart';
import 'package:myproject/currency_money.dart';

import 'precision_edition_test.dart' as preview;
import 'ui_preview_fonts.dart';

Widget pulseHome({bool mixedCurrencies = false, double heroHeight = 200}) =>
    Scaffold(
      body: PageSurface(
        child: AuroraPage(
          title: 'Today',
          child: FlowHomeLayout(
            header: SizedBox(height: heroHeight),
            quickActions: const SizedBox(height: 60),
            sectionCount: 1,
            sectionBuilder: (context, index) => SavingsPulse(
              uid: 'fixture',
              goals: const [],
              clock: () => DateTime(2026, 10, 25),
              load: (start, end) async => (
                [
                  for (final currency in ['PHP', if (mixedCurrencies) 'USD'])
                    for (final day in [10, 11, 16, 22])
                      if (!DateTime(2026, 10, day).isBefore(start) &&
                          DateTime(2026, 10, day).isBefore(end))
                        PulseEntry(
                          at: DateTime(2026, 10, day),
                          amount: ExactDecimal.fromNum(day == 16 ? 1 : 100),
                          currency: currency,
                        ),
                ],
                false,
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => loadManropeForPreviews(force: true));

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'scrolled month Pulse expands and collapses dark=$dark scale=$scale',
        (tester) async {
          await preview.mount(
            tester,
            pulseHome(),
            dark: dark,
            width: scale == 1 ? 360 : 320,
            height: 806,
            scale: scale,
          );
          await tester.ensureVisible(find.text('This month'));
          await tester.tap(find.text('This month'));
          await tester.pumpAndSettle();
          final details = find.text('Daily contribution details');
          await Scrollable.ensureVisible(
            tester.element(details),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(ErrorWidget), findsNothing);
          if (scale == 1) await capturePulse(tester, dark: dark);
          await tester.tap(details);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Oct 25, 2026'), findsOneWidget);
          await Scrollable.ensureVisible(
            tester.element(details),
            alignment: .5,
          );
          await tester.tap(details);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Oct 25, 2026'), findsNothing);
        },
      );
    }
  }

  testWidgets(
    'Pulse remembers details separately for each currency and period',
    (tester) async {
      await preview.mount(
        tester,
        pulseHome(mixedCurrencies: true),
        width: 360,
        height: 806,
      );
      Future<void> select(String label) async {
        final chip = find.widgetWithText(ChoiceChip, label);
        await Scrollable.ensureVisible(tester.element(chip), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      final details = find.text('Daily contribution details');
      Future<void> expand() async {
        await Scrollable.ensureVisible(tester.element(details), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(details);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await select('This month');
      await expand();
      expect(find.text('Oct 25, 2026'), findsOneWidget);
      await select('USD');
      expect(find.text('Oct 25, 2026'), findsNothing);
      await expand();
      await select('PHP');
      expect(find.text('Oct 25, 2026'), findsOneWidget);
      await select('30 days');
      expect(find.text('Oct 25, 2026'), findsNothing);
      await select('This month');
      expect(find.text('Oct 25, 2026'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    },
  );

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Home header follows the actual surface in both scroll directions dark=$dark scale=$scale',
        (tester) async {
          await preview.mount(
            tester,
            pulseHome(heroHeight: scale == 1 ? 200 : 420),
            dark: dark,
            width: 360,
            height: 806,
            scale: scale,
          );
          Color? headerColor() => tester
              .widget<SliverAppBar>(find.byType(SliverAppBar))
              .backgroundColor;
          final context = tester.element(find.byType(AuroraLargeTitle));
          final coordinator = tester.state<NestedScrollViewState>(
            find.byType(NestedScrollView),
          );
          expect(headerColor(), context.flowHero);
          coordinator.outerController.jumpTo(
            coordinator.outerController.position.maxScrollExtent,
          );
          await tester.pumpAndSettle();
          final sheet = find.byType(FlowContentSheet);
          final toolbar = find.byType(AppBar);
          final boundary =
              tester.getTopLeft(sheet).dy - tester.getBottomRight(toolbar).dy;
          expect(boundary, greaterThan(100));

          Future<void> check(double offset, {required bool onWhite}) async {
            coordinator.innerController.jumpTo(offset);
            await tester.pumpAndSettle();
            final sheetTop = tester.getTopLeft(sheet).dy;
            final toolbarBottom = tester.getBottomRight(toolbar).dy;
            expect(sheetTop <= toolbarBottom, onWhite);
            expect(
              headerColor(),
              onWhite ? context.atelierSurface : context.flowHero,
            );
            expect(tester.takeException(), isNull);
          }

          await check(boundary / 2, onWhite: false);
          await check(boundary - 1, onWhite: false);
          await check(boundary + 1, onWhite: true);
          await check(boundary + 60, onWhite: true);
          await check(boundary - 1, onWhite: false);
          await check(0, onWhite: false);
        },
      );
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
      'Home header fades smoothly and reverses without jumping dark=$dark',
      (tester) async {
        await preview.mount(
          tester,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: false, accessibleNavigation: false),
              child: pulseHome(),
            ),
          ),
          dark: dark,
          width: 360,
          height: 806,
        );
        Color paintedColor() =>
            (tester
                        .renderObject<RenderDecoratedBox>(
                          find.byKey(const ValueKey('home-header-background')),
                        )
                        .decoration
                    as BoxDecoration)
                .color!;
        final context = tester.element(find.byType(AuroraLargeTitle));
        final green = context.flowHero, white = context.atelierSurface;
        final coordinator = tester.state<NestedScrollViewState>(
          find.byType(NestedScrollView),
        );
        coordinator.outerController.jumpTo(
          coordinator.outerController.position.maxScrollExtent,
        );
        await tester.pumpAndSettle();
        final boundary =
            tester.getTopLeft(find.byType(FlowContentSheet)).dy -
            tester.getBottomRight(find.byType(AppBar)).dy;
        Future<void> cross(double offset) async {
          coordinator.innerController.jumpTo(offset);
          await tester.pump();
          await tester.pump();
        }

        expect(paintedColor(), green);
        await cross(boundary + 10);
        expect(paintedColor(), green);
        await tester.pump(const Duration(milliseconds: 80));
        final middle = paintedColor();
        expect(middle, isNot(green));
        expect(middle, isNot(white));
        expect(middle.a, 1);
        await cross(boundary - 10);
        expect(paintedColor(), middle);
        await tester.pump(const Duration(milliseconds: 80));
        final returning = paintedColor();
        double distance(Color value) =>
            (value.r - green.r).abs() +
            (value.g - green.g).abs() +
            (value.b - green.b).abs();
        expect(distance(returning), lessThan(distance(middle)));
        await tester.pumpAndSettle();
        expect(paintedColor(), green);
        await cross(boundary + 10);
        await tester.pumpAndSettle();
        expect(paintedColor(), white);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Home header skips the fade when reduced motion is enabled', (
    tester,
  ) async {
    await preview.mount(tester, pulseHome(), width: 360, height: 806);
    final coordinator = tester.state<NestedScrollViewState>(
      find.byType(NestedScrollView),
    );
    coordinator.outerController.jumpTo(
      coordinator.outerController.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    coordinator.innerController.jumpTo(260);
    await tester.pump();
    await tester.pump();
    final painted =
        (tester
                    .renderObject<RenderDecoratedBox>(
                      find.byKey(const ValueKey('home-header-background')),
                    )
                    .decoration
                as BoxDecoration)
            .color;
    final context = tester.element(find.byType(AuroraLargeTitle));
    expect(painted, context.atelierSurface);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home header rechecks the boundary when the hero changes height',
    (tester) async {
      final height = ValueNotifier<double>(200);
      addTearDown(height.dispose);
      await preview.mount(
        tester,
        ValueListenableBuilder<double>(
          valueListenable: height,
          builder: (context, value, child) => pulseHome(heroHeight: value),
        ),
        width: 360,
        height: 806,
      );
      final coordinator = tester.state<NestedScrollViewState>(
        find.byType(NestedScrollView),
      );
      coordinator.outerController.jumpTo(
        coordinator.outerController.position.maxScrollExtent,
      );
      coordinator.innerController.jumpTo(260);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AuroraLargeTitle));
      Color? headerColor() => tester
          .widget<SliverAppBar>(find.byType(SliverAppBar))
          .backgroundColor;
      expect(headerColor(), context.atelierSurface);
      height.value = 500;
      await tester.pumpAndSettle();
      expect(headerColor(), context.flowHero);
      height.value = 180;
      await tester.pumpAndSettle();
      expect(headerColor(), context.atelierSurface);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> capturePulse(WidgetTester tester, {required bool dark}) async {
  if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary =
        preview.capture.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      'build/ui-preview/pulse-scroll-${dark ? 'dark' : 'light'}.png',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
