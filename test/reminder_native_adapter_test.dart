import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:myproject/reminder_models.dart';
import 'package:myproject/reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => true,
            'getNotificationAppLaunchDetails' => {
              'notificationLaunchedApp': false,
            },
            'areNotificationsEnabled' ||
            'requestNotificationsPermission' => true,
            'canScheduleExactNotifications' => false,
            'getNotificationChannels' ||
            'pendingNotificationRequests' => <dynamic>[],
            _ => null,
          };
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'native adapter creates three channels and marshals real timezone alarms',
    () async {
      final scheduler = NativeNotificationScheduler();
      await scheduler.initialize((_) {});
      expect(
        calls.where((c) => c.method == 'createNotificationChannel').length,
        3,
      );
      expect(
        (await scheduler.capability(ReminderTargetType.personalGoal)).exact,
        isFalse,
      );
      const target = ReminderTarget(
        type: ReminderTargetType.personalGoal,
        id: 'fund',
        title: 'Emergency Fund',
      );
      const config = ReminderConfiguration(
        uid: 'alex',
        type: ReminderTargetType.personalGoal,
        targetId: 'fund',
        enabled: true,
        frequency: ReminderFrequency.daily,
      );
      await scheduler.schedule(
        1001,
        config,
        target,
        tz.TZDateTime(tz.getLocation('Asia/Manila'), 2026, 10, 14, 20),
        exact: false,
      );
      final arguments = calls.last.arguments as Map;
      expect(calls.last.method, 'zonedSchedule');
      expect(arguments['id'], 1001);
      expect(arguments['timeZoneName'], 'Asia/Manila');
      expect(arguments['body'], 'Time to check your savings goal.');
      expect(ReminderPayload.decode(arguments['payload'])!.uid, 'alex');
      expect(arguments['matchDateTimeComponents'], isNotNull);
      await scheduler.cancel(1001);
      expect(calls.last.method, 'cancel');
      await scheduler.cancelAll();
      expect(calls.last.method, 'cancelAll');
    },
  );
}
