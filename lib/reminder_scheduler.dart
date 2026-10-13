import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_models.dart';

class NotificationCapability {
  const NotificationCapability({
    required this.supported,
    required this.allowed,
    this.exact = false,
  });
  final bool supported, allowed, exact;
}

abstract class NotificationScheduler {
  bool get supported;
  int get limit;
  Future<void> initialize(void Function(ReminderPayload) onTap);
  Future<tz.Location> timezone();
  Future<NotificationCapability> capability(ReminderTargetType type);
  Future<bool> requestPermission();
  Future<void> openSettings();
  Future<void> requestPreciseTiming();
  Future<Map<int, String?>> pending();
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<void> schedule(
    int id,
    ReminderConfiguration config,
    ReminderTarget target,
    tz.TZDateTime date, {
    required bool exact,
  });
}

/// One native notification system. No Dart timers deliver reminders.
class NativeNotificationScheduler implements NotificationScheduler {
  NativeNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin plugin;
  bool _initialized = false;
  static bool _zoneDataReady = false;
  AndroidFlutterLocalNotificationsPlugin? get android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  IOSFlutterLocalNotificationsPlugin? get ios => plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();
  @override
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  @override
  int get limit => defaultTargetPlatform == TargetPlatform.iOS ? 60 : 400;

  static String channelId(ReminderTargetType type) => switch (type) {
    ReminderTargetType.personalGoal => 'savings_reminders',
    ReminderTargetType.sharedGoal => 'shared_goal_reminders',
    ReminderTargetType.task => 'planner_reminders',
  };
  static String channelName(ReminderTargetType type) => switch (type) {
    ReminderTargetType.personalGoal => 'Savings reminders',
    ReminderTargetType.sharedGoal => 'Shared goal reminders',
    ReminderTargetType.task => 'Planner reminders',
  };

  @override
  Future<void> initialize(void Function(ReminderPayload) onTap) async {
    if (_initialized || !supported) return;
    final result = await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_reminder'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = ReminderPayload.decode(response.payload);
        if (payload != null) onTap(payload);
      },
    );
    if (result != true) {
      throw const ReminderFailure('Phone notification initialization failed.');
    }
    for (final type in ReminderTargetType.values) {
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channelId(type),
          channelName(type),
          description: 'Reminders you choose in SaveTrack',
          importance: Importance.high,
        ),
      );
    }
    _initialized = true;
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final payload = ReminderPayload.decode(
        launch?.notificationResponse?.payload,
      );
      if (payload != null) onTap(payload);
    }
  }

  @override
  Future<tz.Location> timezone() async {
    if (!_zoneDataReady) {
      tzdata.initializeTimeZones();
      _zoneDataReady = true;
    }
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final zone = tz.getLocation(info.identifier);
      tz.setLocalLocation(zone);
      return zone;
    } catch (_) {
      throw const ReminderFailure(
        'Could not read the device timezone. Phone scheduling is unavailable.',
      );
    }
  }

  @override
  Future<NotificationCapability> capability(ReminderTargetType type) async {
    if (!supported) {
      return const NotificationCapability(supported: false, allowed: false);
    }
    if (android != null) {
      var allowed = await android!.areNotificationsEnabled() == true;
      final channels = await android!.getNotificationChannels();
      if (channels != null &&
          channels.any(
            (c) => c.id == channelId(type) && c.importance == Importance.none,
          )) {
        allowed = false;
      }
      return NotificationCapability(
        supported: true,
        allowed: allowed,
        exact: await android!.canScheduleExactNotifications() == true,
      );
    }
    final permission = await ios?.checkPermissions();
    return NotificationCapability(
      supported: true,
      allowed:
          permission?.isEnabled == true && permission?.isAlertEnabled == true,
      exact: true,
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    if (android != null) {
      return await android!.requestNotificationsPermission() == true;
    }
    return await ios?.requestPermissions(
          alert: true,
          sound: true,
          badge: false,
        ) ==
        true;
  }

  @override
  Future<void> openSettings() async {
    if (supported) await plugin.openAppNotificationSettings();
  }

  @override
  Future<void> requestPreciseTiming() async {
    if (supported) await android?.requestExactAlarmsPermission();
  }

  @override
  Future<Map<int, String?>> pending() async => !supported
      ? {}
      : {
          for (final request in await plugin.pendingNotificationRequests())
            request.id: request.payload,
        };
  @override
  Future<void> cancel(int id) async {
    if (supported) await plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    if (supported) await plugin.cancelAll();
  }

  @override
  Future<void> schedule(
    int id,
    ReminderConfiguration config,
    ReminderTarget target,
    tz.TZDateTime date, {
    required bool exact,
  }) async {
    if (!supported) {
      throw const ReminderFailure(
        'Phone reminders are available on Android and iOS.',
      );
    }
    await plugin.zonedSchedule(
      id: id,
      title: reminderTitle(config.type),
      body: reminderBody(target, config.showTitle),
      scheduledDate: date,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId(config.type),
          channelName(config.type),
          channelDescription: 'Reminders you choose in SaveTrack',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
          icon: 'ic_stat_reminder',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: false,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: switch (config.frequency) {
        ReminderFrequency.daily => DateTimeComponents.time,
        ReminderFrequency.weekly => DateTimeComponents.dayOfWeekAndTime,
        _ => null,
      },
      payload: ReminderPayload(
        config.uid,
        config.type,
        config.targetId,
      ).encode(),
    );
  }
}
