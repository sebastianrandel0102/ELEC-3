import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/goal_cover_processing.dart';
import 'package:myproject/goal_cover_service.dart';
import 'package:myproject/goal_cover_widgets.dart';
import 'package:myproject/main.dart';
import 'package:myproject/shared_savings_models.dart';
import 'package:myproject/shared_savings_screens.dart';

import 'goal_cover_test.dart' as fixtures;
import 'redesign_test.dart' as preview;
import 'aurora4_layout_test.dart' show PreviewDocument;
import 'ui_preview_fonts.dart';

void main() {
  setUpAll(loadManropeForPreviews);
  Future<void> decodeVisibleImage(WidgetTester tester) async {
    final image = tester.widget<Image>(find.byType(Image));
    await tester.runAsync(
      () => precacheImage(image.image, tester.element(find.byType(Image))),
    );
    await tester.pumpAndSettle();
  }

  Widget frame(Widget child) => MaterialApp(
    theme: SaveTrackDesign.theme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
  testWidgets(
    'personal cards and Details select each goal image while retaining balances and actions',
    (tester) async {
      final a = fixtures.version(fixtures.personal, 1);
      final b = fixtures.version(
        const GoalCoverTarget.personal('owner', 'goalB'),
        1,
      );
      final photos = {
        a: fixtures.picture(),
        b: fixtures.picture(width: 90, height: 160),
      };
      final loaded = <String>[];
      for (final (id, path) in [('goalA', a), ('goalB', b)]) {
        final doc = PreviewDocument(id, {
          'title': 'Vacation $id',
          'savedAmount': 2000,
          'targetAmount': 5000,
          'coverStoragePath': path,
        });
        await preview.mount(
          tester,
          preview.scrollPage(
            GoalCard(
              uid: 'owner',
              doc: doc,
              details: id == 'goalB',
              coverLoad: (path) async {
                loaded.add(path);
                return photos[path];
              },
            ),
          ),
          size: const Size(390, 1100),
        );
        await tester.pumpAndSettle();
        final cover = tester.widget<GoalCoverImage>(
          find.byType(GoalCoverImage),
        );
        expect(cover.path, path);
        expect(cover.target.goalId, id);
        final image =
            tester.widget<Image>(find.byType(Image)).image as ResizeImage;
        expect((image.imageProvider as MemoryImage).bytes, same(photos[path]));
        expect(
          tester.widget<MintProgress>(find.byType(MintProgress)).value,
          .4,
        );
        expect(find.text('History'), findsOneWidget);
        expect(find.text('Add savings'), findsOneWidget);
        if (id == 'goalB') {
          expect(find.byTooltip('Change Goal Photo'), findsOneWidget);
          await decodeVisibleImage(tester);
          await preview.capture(tester, 'goal-cover-details-390');
        }
      }
      expect(loaded, [a, b]);
    },
  );
  testWidgets(
    'shared card loads the same shared cover for its contributor and retains group financial data',
    (tester) async {
      final path = fixtures.version(fixtures.shared, 1),
          bytes = fixtures.picture();
      final goal = SharedSavingsGoal('sharedA', {
        'ownerId': 'owner',
        'name': 'Japan Vacation',
        'currentAmount': 1200,
        'targetAmount': 5000,
        'memberCount': 2,
        'coverStoragePath': path,
      });
      String? requested;
      await tester.pumpWidget(
        frame(
          SharedGoalCard(
            goal: goal,
            uid: 'contributor',
            coverLoad: (path) async {
              requested = path;
              return bytes;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requested, path);
      expect(tester.widget<MintProgress>(find.byType(MintProgress)).value, .24);
      expect(find.textContaining('Contributor'), findsOneWidget);
      expect(find.byTooltip('Change Goal Photo'), findsNothing);
      final image =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect((image.imageProvider as MemoryImage).bytes, same(bytes));
    },
  );
  testWidgets(
    'optional form shows accessible gallery action and premium fallback',
    (tester) async {
      await tester.pumpWidget(
        frame(
          const Padding(
            padding: EdgeInsets.all(20),
            child: GoalCoverFormSection(target: fixtures.personal),
          ),
        ),
      );
      expect(find.text('Goal Cover Photo'), findsOneWidget);
      expect(
        find.text('Add a picture that inspires your savings goal.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Add Cover Photo'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      expect(find.text('A little closer, every day.'), findsOneWidget);
      expect(find.text('Remove Photo'), findsNothing);
    },
  );
  testWidgets(
    'owner edit control is omitted for members and appears for owner',
    (tester) async {
      Widget image(VoidCallback? edit) => frame(
        GoalCoverImage(
          target: fixtures.shared,
          name: 'Japan Vacation',
          onEdit: edit,
        ),
      );
      await tester.pumpWidget(image(null));
      expect(find.byTooltip('Add Goal Photo'), findsNothing);
      await tester.pumpWidget(image(() {}));
      expect(find.byTooltip('Add Goal Photo'), findsOneWidget);
    },
  );
  testWidgets(
    'authenticated load runs once and cover versions trigger a refresh',
    (tester) async {
      var calls = 0;
      final bytes = fixtures.picture();
      Future<Uint8List?> load(String _) async {
        calls++;
        return bytes;
      }

      Widget image(int n) => frame(
        GoalCoverImage(
          target: fixtures.personal,
          name: 'Travel',
          path: fixtures.version(fixtures.personal, n),
          load: load,
        ),
      );
      await tester.pumpWidget(image(1));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(image(1));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.pumpWidget(image(2));
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );
  testWidgets(
    'loading skeleton and failed downloads end in a stable fallback',
    (tester) async {
      final gate = Completer<Uint8List?>();
      await tester.pumpWidget(
        frame(
          GoalCoverImage(
            target: fixtures.personal,
            name: 'Travel',
            path: fixtures.version(fixtures.personal, 1),
            load: (_) => gate.future,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('A little closer, every day.'), findsOneWidget);
    },
  );
  testWidgets(
    'landscape preview uses actual selected image and exposes crop controls',
    (tester) async {
      final photo = await tester.runAsync(
        () => prepareGoalCover(fixtures.picture(width: 160, height: 320)),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: SaveTrackDesign.theme,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => GoalCoverPreview(
                    photo: photo!,
                    chooseAnother: () async => null,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Preview Goal Cover'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(3));
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        16 / 9,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Preview Goal Cover'), findsNothing);
    },
  );
  testWidgets(
    'cancel never uploads and choosing another updates the real preview',
    (tester) async {
      final photo = await tester.runAsync(
        () => prepareGoalCover(fixtures.picture()),
      );
      final other = await tester.runAsync(
        () => prepareGoalCover(fixtures.picture(width: 90, height: 160)),
      );
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => GoalCoverPreview(
                    photo: photo!,
                    chooseAnother: () async => other,
                    onSave: (_, progress) async => saves++,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Choose Another Photo'));
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(other!.bytes),
          tester.element(find.byType(GoalCoverPreview)),
        ),
      );
      await tester.tap(find.text('Choose Another Photo'));
      await tester.pumpAndSettle();
      final provider =
          tester.widget<Image>(find.byType(Image)).image as MemoryImage;
      expect(provider.bytes, same(other!.bytes));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saves, 0);
    },
  );
  testWidgets('upload progress is actual; failure retains preview for retry', (
    tester,
  ) async {
    final photo = await tester.runAsync(
      () => prepareGoalCover(fixtures.picture()),
    );
    final gate = Completer<void>();
    var uploading = false, calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => GoalCoverPreview(
                  photo: photo!,
                  chooseAnother: () async => null,
                  onSave: (_, progress) async {
                    calls++;
                    uploading = true;
                    progress(.4);
                    await gate.future;
                    throw const GoalCoverFailure(
                      'Check your connection and try again.',
                    );
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save Cover Photo'));
      for (var n = 0; n < 200 && !uploading; n++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(uploading, isTrue);
    expect(find.text('Uploading Goal Cover'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .4,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save Cover Photo'),
          )
          .onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(calls, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save Cover Photo'),
          )
          .onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'successful confirm returns processed landscape bytes only after upload',
    (tester) async {
      final photo = await tester.runAsync(
        () => prepareGoalCover(fixtures.picture()),
      );
      Uint8List? received, result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Uint8List>(
                    context: ctx,
                    builder: (_) => GoalCoverPreview(
                      photo: photo!,
                      chooseAnother: () async => null,
                      onSave: (bytes, progress) async {
                        received = bytes;
                        progress(1);
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Save Cover Photo'));
        for (var n = 0; n < 200 && result == null; n++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(received, isNotNull);
      expect(result, same(received));
      expect(find.text('Preview Goal Cover'), findsNothing);
    },
  );
  testWidgets(
    'goal photo actions preserve savings, shared, history and reminder actions',
    (tester) async {
      final record = preview.TestDocument({
        'title': 'Vacation',
        'savedAmount': 123,
        'targetAmount': 1000,
      });
      await tester.pumpWidget(frame(GoalCard(uid: 'owner', doc: record)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Goal actions'));
      await tester.pumpAndSettle();
      for (final label in [
        'Add Goal Photo',
        'Add savings',
        'Decrease Savings',
        'Edit goal',
        'Save Together',
        'Delete goal',
        'Set Reminder',
      ]) {
        expect(find.text(label), findsWidgets);
      }
    },
  );
  testWidgets(
    'narrow cards retain long names and large financial amounts with enlarged text',
    (tester) async {
      final doc = preview.TestDocument({
        'title': 'A home for our family and the next chapter of our lives',
        'savedAmount': 123456789.12,
        'targetAmount': 987654321.98,
      });
      await preview.mount(
        tester,
        preview.scrollPage(GoalCard(uid: 'owner', doc: doc)),
        size: const Size(320, 1400),
        scale: 1.6,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await preview.capture(tester, 'goal-cover-narrow-320');
    },
  );
  testWidgets('render landscape cover and optional form at phone width', (
    tester,
  ) async {
    final bytes = fixtures.picture(width: 480, height: 270);
    await preview.mount(
      tester,
      preview.scrollPage(
        GoalCoverFormSection(target: fixtures.personal, pending: bytes),
      ),
      size: const Size(390, 844),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await decodeVisibleImage(tester);
    await preview.capture(tester, 'goal-cover-form-390');
  });
  testWidgets(
    'crop dialog remains usable on a narrow phone with a fixed save action',
    (tester) async {
      final photo = await tester.runAsync(
        () => prepareGoalCover(fixtures.picture(width: 90, height: 160)),
      );
      await preview.mount(
        tester,
        Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => GoalCoverPreview(
                  photo: photo!,
                  chooseAnother: () async => null,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        size: const Size(320, 640),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getRect(find.widgetWithText(FilledButton, 'Save Cover Photo'))
            .bottom,
        lessThanOrEqualTo(640),
      );
      await decodeVisibleImage(tester);
      await preview.capture(tester, 'goal-cover-preview-320');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Preview Goal Cover'), findsNothing);
    },
  );
  testWidgets(
    'session change closes private cover modal even during processing',
    (tester) async {
      final session = StreamController<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  barrierDismissible: false,
                  builder: (_) => GoalCoverRouteGuard(
                    active: session.stream,
                    child: const PopScope(
                      canPop: false,
                      child: Dialog(child: Text('Private selected photo')),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Private selected photo'), findsOneWidget);
      session.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Private selected photo'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(session.close());
      await tester.pump();
    },
  );
}
