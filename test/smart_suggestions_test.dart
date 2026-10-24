// Firestore SDK interfaces are test doubles; production uses SDK snapshots.
// ignore_for_file: subtype_of_sealed_class

import 'ui_preview_fonts.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/main.dart';
import 'package:myproject/smart_suggestions.dart';
import 'package:myproject/smart_task_recommendation_service.dart';

class PlannerSnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  PlannerSnapshot(this.docs);
  @override
  final List<PlannerDocument> docs;
}

class PlannerDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  PlannerDocument(this.id, this.values) {
    reference = PlannerReference(this);
  }
  @override
  final String id;
  final Map<String, dynamic> values;
  @override
  late final PlannerReference reference;
  @override
  Map<String, dynamic> data() => Map.of(values);
}

// Mutable hooks simulate SDK persistence and listener errors in tests only.
// ignore: must_be_immutable
class PlannerReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  PlannerReference(this.doc);
  final PlannerDocument doc;
  final updates = <Map<Object, Object?>>[];
  VoidCallback? onUpdate;
  VoidCallback? onDelete;
  bool fail = false;

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (fail) throw StateError('Task is unavailable');
    updates.add(Map.of(data));
    doc.values.addAll(Map<String, dynamic>.from(data));
    onUpdate?.call();
  }

  @override
  Future<void> delete() async => onDelete?.call();
}

class PlannerStore {
  PlannerStore(this.docs) {
    controller = StreamController<QuerySnapshot<Map<String, dynamic>>>(
      onListen: emit,
    );
    connect();
  }
  final List<PlannerDocument> docs;
  late final StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
  void connect() {
    for (final doc in docs) {
      doc.reference.onUpdate = emit;
      doc.reference.onDelete = () {
        docs.remove(doc);
        emit();
      };
    }
  }

  void emit() => controller.add(PlannerSnapshot(List.of(docs)));
}

void main() {
  final date = DateTime(2026, 10, 13);
  var now = DateTime(2026, 10, 13, 13, 45);
  late SmartTaskRecommendationService service;
  final previewKey = GlobalKey();

  PlannerDocument task(
    String id, {
    String? title,
    String priority = 'Normal',
    String time = '',
    bool completed = false,
    String day = '2026-10-13',
  }) => PlannerDocument(id, {
    'title': title ?? id,
    'priority': priority,
    'time': time,
    'completed': completed,
    'dateKey': day,
  });

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
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
          child: RepaintBoundary(key: previewKey, child: child!),
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> mountPlanner(
    WidgetTester tester,
    PlannerStore store, {
    Size size = const Size(390, 844),
    double scale = 1,
    String day = '2026-10-13',
    bool compact = false,
  }) => mount(
    tester,
    TasksList(
      uid: 'fixture',
      dateKey: day,
      taskStream: store.controller.stream,
      recommendationService: service,
      compact: compact,
      header: PlannerDateHeader(
        title: day,
        onPrevious: () {},
        onNext: () {},
        onToday: () {},
      ),
    ),
    size: size,
    scale: scale,
  );

  Widget suggestions(
    List<PlannerTask> tasks, {
    DateTime? selectedDate,
    ValueChanged<String>? onOpen,
    Future<void> Function(String)? onComplete,
    VoidCallback? onAdd,
    bool active = true,
  }) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: SmartSuggestions(
      tasks: tasks,
      selectedDate: selectedDate ?? date,
      service: service,
      active: active,
      onOpenTask: onOpen ?? (_) {},
      onCompleteTask: onComplete ?? (_) async {},
      onAddTask: onAdd ?? () {},
    ),
  );

  List<PlannerTask> models(List<PlannerDocument> docs) =>
      docs.map((doc) => PlannerTask.fromData(doc.id, doc.data())).toList();

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
    await tester.runAsync(() async {
      final boundary =
          previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final screenshot = await boundary.toImage(pixelRatio: 1);
      final bytes = await screenshot.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      screenshot.dispose();
    });
  }

  setUpAll(() async {
    await loadManropeForPreviews();
    if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
    final config = jsonDecode(
      await File('.dart_tool/package_config.json').readAsString(),
    ) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((package) => package['name'] == 'flutter');
    final sdk = Uri.parse('${flutter['rootUri']}/').resolve('../../');
    for (final entry in {
      'Roboto': 'bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      'MaterialIcons':
          'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    }.entries) {
      final file = File.fromUri(sdk.resolve(entry.value));
      final loader = FontLoader(entry.key)
        ..addFont(file.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  setUp(() {
    now = DateTime(2026, 10, 13, 13, 45);
    service = SmartTaskRecommendationService(clock: () => now);
  });

  testWidgets(
    'real planner shows suggestions, reasons, Up Next and original list',
    (tester) async {
      final store = PlannerStore([
        task(
          'later',
          title: 'Finish Assignment',
          priority: 'High',
          time: '4:00 PM',
        ),
        task('soon', title: 'Review Notes', time: '2:00 PM'),
        task('flexible', title: 'Clean Room', priority: 'Low'),
      ]);
      await mountPlanner(tester, store, size: const Size(390, 1800));
      expect(find.text('Smart Suggestions'), findsOneWidget);
      expect(find.byKey(const ValueKey('smart-primary-soon')), findsOneWidget);
      expect(find.text('Starts in 15 minutes'), findsOneWidget);
      expect(find.textContaining('Prepare for it'), findsOneWidget);
      expect(find.text('Up Next'), findsOneWidget);
      expect(find.byKey(const ValueKey('smart-next-flexible')), findsOneWidget);
      expect(find.byKey(const ValueKey('smart-next-later')), findsOneWidget);
      expect(find.byKey(const ValueKey('smart-next-soon')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('planner-task-flexible')),
        300,
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      for (final id in ['soon', 'later', 'flexible']) {
        final row = find.byKey(ValueKey('planner-task-$id'));
        await tester.scrollUntilVisible(row, 300);
        expect(tester.widget<FlowTaskGroupEntry>(row).doc.id, id);
      }
      expect(store.docs.length, 3);
      expect(store.docs.every((doc) => doc.reference.updates.isEmpty), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'complete uses existing persistence and keeps completed item in original list',
    (tester) async {
      final first = task('high', priority: 'High');
      final store = PlannerStore([first, task('low', priority: 'Low')]);
      await mountPlanner(tester, store);
      await tester.ensureVisible(find.text('Mark Complete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark Complete'));
      await tester.pumpAndSettle();
      expect(first.reference.updates.single.keys.toSet(), {
        'completed',
        'updatedAt',
      });
      expect(first.reference.updates.single['completed'], isTrue);
      expect(find.byKey(const ValueKey('smart-primary-low')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('planner-task-low')),
        -300,
      );
      await tester.pumpAndSettle();
      final completedRow = find.byKey(const ValueKey('planner-task-high'));
      await tester.scrollUntilVisible(completedRow, -300);
      expect(
        tester.widget<FlowTaskGroupEntry>(completedRow).doc.data()['completed'],
        isTrue,
      );
      expect(store.docs.length, 2);
      expect(first.values['priority'], 'High');
      expect(first.values['time'], '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('original checkbox can reopen a task and refresh suggestions', (
    tester,
  ) async {
    final first = task('high', priority: 'High', completed: true);
    final store = PlannerStore([first, task('low', priority: 'Low')]);
    await mountPlanner(tester, store);
    final original = find.byKey(const ValueKey('planner-task-high'));
    await tester.scrollUntilVisible(original, 400);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: original, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    expect(first.reference.updates.single['completed'], isFalse);
    await tester.scrollUntilVisible(find.text('Smart Suggestions'), -400);
    expect(find.byKey(const ValueKey('smart-primary-high')), findsOneWidget);
  });

  testWidgets('Edit Task opens and saves through the existing editor', (
    tester,
  ) async {
    final document = task('task', title: 'Review notes');
    final store = PlannerStore([document]);
    await mountPlanner(tester, store);
    await tester.ensureVisible(find.text('Edit Task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Task'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Review updated notes');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(document.values['title'], 'Review updated notes');
    expect(document.reference.updates.single.keys.toSet(), {
      'title',
      'time',
      'priority',
      'dateKey',
      'updatedAt',
    });
    expect(
      find.descendant(
        of: find.byType(SmartSuggestionCard),
        matching: find.text('Review updated notes'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('original deletion action updates suggestions and task records', (
    tester,
  ) async {
    final first = task('high', priority: 'High');
    final store = PlannerStore([first, task('low', priority: 'Low')]);
    await mountPlanner(tester, store);
    final original = find.byKey(const ValueKey('planner-task-high'));
    await tester.scrollUntilVisible(original, 400);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: original, matching: find.byTooltip('Task actions')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this task?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.docs.map((doc) => doc.id), ['low']);
    await tester.scrollUntilVisible(find.text('Smart Suggestions'), -400);
    expect(find.byKey(const ValueKey('smart-primary-low')), findsOneWidget);
  });

  testWidgets(
    'Firestore snapshot additions and priority edits update immediately',
    (tester) async {
      final store = PlannerStore([task('first')]);
      await mountPlanner(tester, store);
      store.docs.add(task('added', priority: 'High'));
      store.connect();
      store.emit();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('smart-primary-added')), findsOneWidget);
      store.docs.first.values['priority'] = 'High';
      store.docs.last.values['priority'] = 'Low';
      store.emit();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('smart-primary-first')), findsOneWidget);
    },
  );

  testWidgets('date changes show future order then historical review', (
    tester,
  ) async {
    final documents = [
      task('tomorrow', time: '2:00 PM', day: '2026-10-14'),
      task('yesterday', day: '2026-10-12'),
    ];
    await mount(
      tester,
      suggestions(models(documents), selectedDate: DateTime(2026, 10, 14)),
    );
    expect(find.text('Recommended Order'), findsOneWidget);
    expect(find.textContaining('Starts in'), findsNothing);
    await mount(
      tester,
      suggestions(models(documents), selectedDate: DateTime(2026, 10, 12)),
    );
    expect(find.text('Review Unfinished Tasks'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('smart-primary-yesterday')),
      findsOneWidget,
    );
  });

  testWidgets('empty state adds through original form with selected date', (
    tester,
  ) async {
    final store = PlannerStore([]);
    await mountPlanner(tester, store, day: '2026-10-14');
    expect(find.text('Your day is clear.'), findsOneWidget);
    expect(
      find.text('Add a task to get personalized suggestions.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();
    expect(find.text('14/10/2026'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.docs, isEmpty);
  });

  testWidgets('all completed state leaves the original task list accessible', (
    tester,
  ) async {
    final store = PlannerStore([task('done', completed: true)]);
    await mountPlanner(tester, store);
    expect(find.text('All done for today!'), findsOneWidget);
    expect(find.byType(SmartSuggestionCard), findsNothing);
    expect(find.text('Your Tasks'), findsOneWidget);
    expect(find.text('1 of 1 tasks completed'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(TaskTile), 100);
    expect(find.byType(TaskTile), findsOneWidget);
  });

  testWidgets('Why this task shows actual overlap names without writes', (
    tester,
  ) async {
    final documents = [
      task('a', title: 'Class', time: '1:00 PM–2:00 PM', priority: 'High'),
      task('b', title: 'Study group', time: '1:30 PM–2:30 PM'),
    ];
    await mount(tester, suggestions(models(documents)));
    await tester.ensureVisible(find.text('Why this task?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Why this task?'));
    await tester.pumpAndSettle();
    expect(
      find.text('These tasks have overlapping schedules.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Study group'),
      ),
      findsOneWidget,
    );
    expect(documents.every((doc) => doc.reference.updates.isEmpty), isTrue);
  });

  testWidgets('minute boundary recalculates from memory, including midnight', (
    tester,
  ) async {
    final documents = [task('soon', time: '2:00 PM')];
    await mount(tester, suggestions(models(documents)));
    now = DateTime(2026, 10, 13, 14);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Scheduled for now'), findsOneWidget);
    now = DateTime(2026, 10, 14);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Review Unfinished Tasks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background pauses ticks; resume uses current time immediately', (
    tester,
  ) async {
    await mount(tester, suggestions(models([task('task', time: '14:00')])));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    now = DateTime(2026, 10, 13, 14, 10);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Starts in 15 minutes'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Scheduled start passed'), findsOneWidget);
  });

  testWidgets('inactive tab pauses ticks and refreshes on activation', (
    tester,
  ) async {
    final tasks = models([task('task', time: '14:00')]);
    await mount(tester, suggestions(tasks, active: false));
    now = DateTime(2026, 10, 13, 14, 10);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Starts in 15 minutes'), findsOneWidget);
    await mount(tester, suggestions(tasks, active: true));
    expect(find.text('Scheduled start passed'), findsOneWidget);
  });

  testWidgets('completion failure preserves advisory state and reports error', (
    tester,
  ) async {
    final document = task('task');
    document.reference.fail = true;
    final store = PlannerStore([document]);
    await mountPlanner(tester, store);
    await tester.ensureVisible(find.text('Mark Complete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark Complete'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not complete this task. Please try again.'),
      findsOneWidget,
    );
    expect(document.values['completed'], isFalse);
    expect(find.byKey(const ValueKey('smart-primary-task')), findsOneWidget);
  });

  testWidgets('loading and listener errors retain the date header', (
    tester,
  ) async {
    final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();
    await tester.pumpWidget(
      MaterialApp(
        theme: SaveTrackDesign.theme,
        home: Scaffold(
          body: TasksList(
            uid: 'fixture',
            dateKey: '2026-10-13',
            taskStream: controller.stream,
            header: const Text('Date navigation'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingPanel), findsOneWidget);
    expect(find.text('Date navigation'), findsOneWidget);
    controller.addError(StateError('listener failed'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorPanel), findsOneWidget);
    expect(find.text('Date navigation'), findsOneWidget);
    expect(find.byType(SmartSuggestions), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(controller.close());
  });

  testWidgets('compact dashboard retains its original task-only presentation', (
    tester,
  ) async {
    final store = PlannerStore([task('task')]);
    await mountPlanner(tester, store, compact: true);
    expect(find.byType(TaskTile), findsOneWidget);
    expect(find.byType(SmartSuggestions), findsNothing);
  });

  testWidgets('task deletion during editing shows the existing save error', (
    tester,
  ) async {
    final document = task('task', title: 'Review notes');
    final store = PlannerStore([document]);
    await mountPlanner(tester, store);
    await tester.ensureVisible(find.text('Edit Task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Task'));
    await tester.pumpAndSettle();
    store.docs.clear();
    document.reference.fail = true;
    store.emit();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save task:'), findsOneWidget);
    expect(find.text('Edit task'), findsOneWidget);
    expect(document.reference.updates, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy optional data remains usable and preserves its priority',
    (tester) async {
      final document = task('legacy', priority: 'Legacy priority');
      document.values['time'] = 999;
      final store = PlannerStore([document]);
      await mountPlanner(tester, store);
      expect(find.text('Time needs review'), findsOneWidget);
      await tester.ensureVisible(find.text('Edit Task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Task'));
      await tester.pumpAndSettle();
      expect(find.text('Legacy priority'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(document.values['priority'], 'Legacy priority');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow screen and 200 percent text have no overflow', (
    tester,
  ) async {
    final documents = [
      task(
        'primary',
        title: 'Review the household budget and prepare for the study group',
        priority: 'High',
      ),
      task(
        'next',
        title: 'A longer task title that should wrap naturally',
        time: '16:00',
      ),
    ];
    await mount(
      tester,
      suggestions(models(documents)),
      size: const Size(320, 640),
      scale: 2,
    );
    await tester.ensureVisible(find.text('Why this task?'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Up Next'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'premium suggestions visual previews on mobile, narrow and wide screens',
    (tester) async {
      final documents = [
        task('soon', title: 'Review Notes', time: '2:00 PM'),
        task('flexible', title: 'Clean Room', priority: 'Low'),
        task(
          'later',
          title: 'Finish Assignment',
          priority: 'High',
          time: '4:00 PM',
        ),
      ];
      await mount(tester, suggestions(models(documents)));
      await capture(tester, 'smart-suggestions-mobile');
      await mount(
        tester,
        suggestions(models(documents)),
        size: const Size(320, 844),
      );
      await capture(tester, 'smart-suggestions-narrow');
      await mount(
        tester,
        Center(
          child: SizedBox(width: 900, child: suggestions(models(documents))),
        ),
        size: const Size(1280, 1000),
      );
      await capture(tester, 'smart-suggestions-wide');
      await mountPlanner(tester, PlannerStore(documents));
      await capture(tester, 'smart-planner-top');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('planner-task-later')),
        300,
      );
      await tester.pumpAndSettle();
      await capture(tester, 'smart-planner-original-list');
      expect(tester.takeException(), isNull);
    },
  );
}
