import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/home_widgets/widget_controller.dart';
import 'package:myproject/home_widgets/widget_models.dart';

import 'home_widgets_test.dart' as fixtures;

void main() {
  test('a currency precision change cannot reuse incompatible presets', () {
    final snapshot = HomeWidgetSnapshot.build(
      config: fixtures.config(currency: 'USD', presets: ['1.25']),
      now: fixtures.now,
      goal: fixtures.facts(currency: 'JPY'),
    ).data;
    expect((snapshot['goal'] as Map)['presets'], isEmpty);
    expect((snapshot['goal'] as Map)['canSave'], false);
  });

  test(
    'foreground reload can recover a terminated permission listener',
    () async {
      final bridge = fixtures.FakeBridge()
        ..installed = [
          HomeWidgetInstance(42, HomeWidgetType.goal, fixtures.config()),
        ];
      final source = fixtures.FakeSource();
      final controller = HomeWidgetController(
        bridge: bridge,
        source: source,
        clock: () => fixtures.now,
      );
      try {
        await controller.switchAccount('alice');
        source.goals[fixtures.goalRef.key]!.addError(
          StateError('permission-denied'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(bridge.published.last.data['state'], 'unavailable');
        await controller.reload();
        expect(source.subscriptions[fixtures.goalRef.key], 2);
        source.goals[fixtures.goalRef.key]!.add(fixtures.facts());
        await Future<void>.delayed(Duration.zero);
        await controller.flush();
        expect(bridge.published.last.data['state'], 'ready');
      } finally {
        controller.dispose();
        await source.close();
      }
    },
  );
}
