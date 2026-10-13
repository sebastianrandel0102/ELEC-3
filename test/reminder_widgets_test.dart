import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/design_system.dart';
import 'package:myproject/reminder_widgets.dart';

import 'ui_preview_fonts.dart';

const target = ReminderTarget(
  type: ReminderTargetType.personalGoal,
  id: 'fund',
  title: 'Emergency Fund',
);

Future<void> editor(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  bool twentyFour = false,
  ReminderConfiguration? initial,
  ReminderTarget item = target,
  Future<ReminderStatus> Function(ReminderConfiguration)? save,
  Key? boundaryKey,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        theme: SaveTrackDesign.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: twentyFour,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<ReminderConfiguration>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => ReminderEditor(
                    uid: 'alex',
                    target: item,
                    initial: initial,
                    clock: () => DateTime(2026, 10, 13, 12),
                    onSave:
                        save ??
                        (_) async => const ReminderStatus(
                          ReminderDelivery.scheduled,
                          'Phone reminder scheduled',
                        ),
                  ),
                ),
                child: const Text('Open reminder'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open reminder'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadManropeForPreviews);
  testWidgets(
    'clock selects hour, minute and AM/PM, confirms structured values and saves',
    (tester) async {
      ReminderConfiguration? saved;
      await editor(
        tester,
        save: (config) async {
          saved = config;
          return const ReminderStatus(ReminderDelivery.scheduled, 'Scheduled');
        },
      );
      await tester.tap(find.text('Enable Reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reminder-time')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      final dial = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_Dial',
      );
      final center = tester.getCenter(dial);
      await tester.tapAt(center + const Offset(50, 0));
      await tester.pumpAndSettle();
      await tester.tapAt(center + const Offset(-50, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('3:45 AM'), findsOneWidget);
      await tester.ensureVisible(find.text('Save Reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Reminder'));
      await tester.pumpAndSettle();
      expect(saved!.hour, 3);
      expect(saved!.minute, 45);
      expect(saved!.enabled, isTrue);
      expect(saved!.frequency, ReminderFrequency.daily);
      expect(find.byType(ReminderEditor), findsNothing);
    },
  );
  testWidgets('picker cancel preserves saved time and reopening loads it', (
    tester,
  ) async {
    const config = ReminderConfiguration(
      uid: 'alex',
      type: ReminderTargetType.personalGoal,
      targetId: 'fund',
      hour: 18,
      minute: 30,
      frequency: ReminderFrequency.daily,
      enabled: true,
    );
    await editor(tester, initial: config);
    expect(find.text('6:30 PM'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reminder-time')));
    await tester.pumpAndSettle();
    final dial = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_Dial',
    );
    await tester.tapAt(tester.getCenter(dial) + const Offset(50, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('6:30 PM'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reminder-time')));
    await tester.pumpAndSettle();
    expect(find.text('PM'), findsOneWidget);
    expect(find.text('30'), findsWidgets);
  });
  testWidgets('24-hour preference is respected and clock remains interactive', (
    tester,
  ) async {
    const config = ReminderConfiguration(
      uid: 'alex',
      type: ReminderTargetType.personalGoal,
      targetId: 'fund',
      hour: 18,
      minute: 30,
      frequency: ReminderFrequency.daily,
    );
    await editor(tester, initial: config, twentyFour: true);
    expect(find.text('18:30'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reminder-time')));
    await tester.pumpAndSettle();
    expect(find.text('AM'), findsNothing);
    expect(find.text('PM'), findsNothing);
    expect(find.text('18'), findsWidgets);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('18:30'), findsOneWidget);
  });
  testWidgets('semantics describe the interactive clock field', (tester) async {
    final semantics = tester.ensureSemantics();
    await editor(tester);
    expect(
      find.bySemanticsLabel(RegExp('Reminder time.*Opens clock picker')),
      findsOneWidget,
    );
    semantics.dispose();
  });
  testWidgets('unavailable scheduling stays visible without a fake success', (
    tester,
  ) async {
    await editor(
      tester,
      save: (_) async => const ReminderStatus(
        ReminderDelivery.blocked,
        'Notifications disabled in system settings',
      ),
    );
    await tester.tap(find.text('Enable Reminder'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Reminder'));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderEditor), findsOneWidget);
    expect(
      find.text('Notifications disabled in system settings'),
      findsOneWidget,
    );
  });
  testWidgets('task options use actual schedule and retain custom clock', (
    tester,
  ) async {
    await editor(
      tester,
      item: ReminderTarget(
        type: ReminderTargetType.task,
        id: 'notes',
        title: 'Review Notes',
        taskStart: DateTime(2026, 10, 14, 16),
      ),
    );
    expect(find.text('Custom date & time'), findsOneWidget);
    expect(find.text('At / before task start'), findsOneWidget);
    await tester.ensureVisible(find.text('At / before task start'));
    await tester.tap(find.text('At / before task start'));
    await tester.pumpAndSettle();
    expect(find.text('15 minutes before'), findsOneWidget);
    await editor(
      tester,
      item: const ReminderTarget(
        type: ReminderTargetType.task,
        id: 'notes',
        title: 'Review Notes',
      ),
    );
    expect(find.text('At / before task start'), findsNothing);
  });
  for (final width in [320.0, 321.0, 322.0, 323.0, 324.0, 600.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('editor and clock fit width $width with text scale $scale', (
        tester,
      ) async {
        await editor(
          tester,
          width: width,
          scale: scale,
          item: const ReminderTarget(
            type: ReminderTargetType.sharedGoal,
            id: 'trip',
            title: 'Our very long shared savings goal for a family holiday and the next chapter',
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const ValueKey('reminder-time')));
        await tester.tap(find.byKey(const ValueKey('reminder-time')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save Reminder'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('render reminder sheet and native clock for visual review', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
    final boundary = GlobalKey();
    await editor(tester, boundaryKey: boundary);
    Future<void> screenshot(String name) async {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/reminder-preview/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await screenshot('sheet');
    await tester.tap(find.byKey(const ValueKey('reminder-time')));
    await tester.pumpAndSettle();
    await screenshot('clock');
  });
}
