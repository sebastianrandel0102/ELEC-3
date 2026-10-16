import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'widget_models.dart';

class HomeWidgetBridge {
  HomeWidgetBridge({MethodChannel? channel, bool? supported})
    : channel = channel ?? const MethodChannel('savetrack/home_widgets'),
      supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  final MethodChannel channel;
  final bool supported;
  void Function(WidgetLaunch)? onLaunch;
  Future<void> initialize() async {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'launch') {
        final launch = WidgetLaunch.parse(call.arguments);
        if (launch != null) onLaunch?.call(launch);
      }
    });
    final launch = WidgetLaunch.parse(
      await channel.invokeMethod<dynamic>('takeLaunch'),
    );
    if (launch != null) onLaunch?.call(launch);
  }

  Future<void> setSession(String? uid) async {
    if (supported) await channel.invokeMethod<void>('setSession', {'uid': uid});
  }

  Future<List<HomeWidgetInstance>> instances() async {
    if (!supported) return [];
    final raw = await channel.invokeListMethod<dynamic>('instances') ?? [];
    return raw.map((entry) {
      final map = Map<String, dynamic>.from(entry as Map);
      HomeWidgetConfig? config;
      try {
        if (map['config'] is String) {
          config = HomeWidgetConfig.fromMap(
            jsonDecode(map['config'] as String) as Map<String, dynamic>,
          );
        }
      } catch (_) {
        /* An old schema requires explicit reconfiguration. */
      }
      return HomeWidgetInstance(
        map['id'] as int,
        HomeWidgetType.values.byName(map['type'] as String),
        config,
      );
    }).toList();
  }

  Future<HomeWidgetConfig> save(HomeWidgetConfig config) async {
    config.validate();
    final raw = await channel.invokeMethod<String>(
      'saveConfig',
      jsonEncode(config.toMap()),
    );
    return HomeWidgetConfig.fromMap(jsonDecode(raw!) as Map<String, dynamic>);
  }

  Future<void> publish(String uid, List<HomeWidgetSnapshot> snapshots) async {
    if (supported && snapshots.isNotEmpty) {
      await channel.invokeMethod<void>('publish', {
        'uid': uid,
        'snapshots': snapshots.map((s) => jsonEncode(s.data)).toList(),
      });
    }
  }

  Future<void> completeConfiguration(int id, bool saved) async {
    if (supported) {
      await channel.invokeMethod<void>('completeConfiguration', {
        'id': id,
        'saved': saved,
      });
    }
  }

  Future<bool> canPin() async =>
      supported && (await channel.invokeMethod<bool>('canPin') ?? false);
  Future<bool> pin(HomeWidgetType type) async =>
      supported &&
      (await channel.invokeMethod<bool>('pin', {'type': type.name}) ?? false);
  void dispose() {
    if (supported) channel.setMethodCallHandler(null);
  }
}
