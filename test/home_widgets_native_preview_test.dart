import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/home_widgets/widget_models.dart';
import 'package:myproject/home_widgets/widget_native_preview.dart';
import 'package:myproject/home_widgets/widget_preview.dart';
import 'package:myproject/home_widgets/widget_visuals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('savetrack/home_widgets');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets(
    'all twelve Android previews request the production native renderer',
    (tester) async {
      final calls = <Map<Object?, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'preview');
            calls.add(call.arguments as Map<Object?, Object?>);
            return null; // Unsupported hosts retain the read-only Flutter fallback.
          });
      for (final type in HomeWidgetType.values) {
        for (final size in WidgetPreviewSize.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: WidgetPreviewCard(
                    type: type,
                    size: size,
                    privacy: WidgetPrivacy.hidden,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final args = calls.last;
          expect(args['type'], type.name);
          expect(args['width'], size == WidgetPreviewSize.compact ? 180 : 300);
          expect(
            args['height'],
            type == HomeWidgetType.quickSave
                ? (size == WidgetPreviewSize.expanded ? 420 : 220)
                : size == WidgetPreviewSize.compact
                ? 100
                : size == WidgetPreviewSize.expanded
                ? 360
                : 220,
          );
          final snapshot = jsonDecode(args['snapshot']! as String) as Map;
          expect(snapshot['state'], 'hidden');
          expect(snapshot.containsKey('goal'), isFalse);
          expect(snapshot.containsKey('planner'), isFalse);
          expect(tester.takeException(), isNull);
        }
      }
      expect(calls.length, 12);
    },
  );

  testWidgets(
    'a privacy change immediately discards the previous native image',
    (tester) async {
      final next = Completer<Uint8List?>();
      final bytes = File('assets/branding/google_g.png').readAsBytesSync();
      var requests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (++requests == 1) {
              return bytes;
            }
            return next.future;
          });
      Widget preview(String privacy) => MaterialApp(
        home: NativeWidgetPreview(
          type: 'goal',
          config: {'privacy': privacy},
          snapshot: {'updatedAt': 1},
          width: 180,
          height: 100,
          child: Text('Safe $privacy preview'),
        ),
      );
      await tester.pumpWidget(preview('full'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(preview('hidden'));
      expect(find.byType(Image), findsNothing);
      expect(find.text('Safe hidden preview'), findsOneWidget);
      next.complete(null);
      await tester.pumpAndSettle();
    },
  );
}
