import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../ai_coach/ai_app_check.dart';
import '../currency_transactions.dart';
import '../firebase_options.dart';
import '../shared_savings_repository.dart';
import 'widget_data_source.dart';
import 'widget_models.dart';

/// No routes, dialogs, timers or AI requests in this entrypoint.
Future<void> runWidgetBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('savetrack/widget_background');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AiAppCheck.initialize();
    final auth = FirebaseAuth.instance;
    await auth.authStateChanges().first;
    while (true) {
      final raw = await channel.invokeMethod<String>('next');
      if (raw == null) break;
      final operation = jsonDecode(raw) as Map<String, dynamic>;
      final identity = {
        'id': operation['id'],
        'requestId': operation['requestId'],
      };
      var success = false;
      try {
        final uid = operation['uid'] as String;
        void check() {
          if (auth.currentUser?.uid != uid) {
            throw StateError('Your session changed.');
          }
        }

        check();
        if (await channel.invokeMethod<bool>('authorize', identity) != true) {
          throw StateError('Widget configuration changed.');
        }
        final ref = WidgetGoalRef.fromMap(
          Map<String, dynamic>.from(operation['goal'] as Map),
        );
        final currency = operation['currency'] as String;
        final entry = LockedMoneyEntry.create(
          text: operation['amount'] as String,
          from: currency,
          to: currency,
        );
        if (ref.shared) {
          if (currency != 'PHP') throw StateError('Goal currency changed.');
          await SharedSavingsRepository().call('contribute', {
            'goalId': ref.id,
            'amount': entry.amount.fixed(2),
            'date': operation['date'],
            'note': 'Quick Save',
          }, requestId: operation['requestId'] as String);
        } else {
          await recordCurrencySavings(
            goal: FirebaseFirestore.instance.doc('users/$uid/goals/${ref.id}'),
            uid: uid,
            entry: entry,
            note: 'Quick Save',
            requestId: operation['requestId'] as String,
            withdrawal: false,
            requireActiveGoal: true,
          );
        }
        check();
        success = true;
        await channel.invokeMethod<void>('result', {
          ...identity,
          'success': true,
        });
        // Refresh only related instances with authorized facts and existing privacy.
        // A refresh error cannot undo a confirmed transaction receipt.
        try {
          final source = FirestoreWidgetDataSource();
          final snapshot = await source
              .goalDocument(uid, ref)
              .get(const GetOptions(source: Source.server));
          check();
          final facts = source.goalFacts(
            uid,
            ref,
            snapshot.data(),
            cached: false,
          );
          final configs =
              await channel.invokeListMethod<String>('configs') ?? [];
          final payloads = <String>[];
          for (final raw in configs) {
            final config = HomeWidgetConfig.fromMap(
              jsonDecode(raw) as Map<String, dynamic>,
            );
            if (config.uid != uid || config.goal?.key != ref.key) continue;
            WidgetPlannerFacts? planner;
            if (config.needsPlanner) {
              final now = DateTime.now();
              final day =
                  '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              planner = await source
                  .watchPlanner(uid, day)
                  .firstWhere((p) => !p.cached)
                  .timeout(const Duration(seconds: 10));
            }
            payloads.add(
              jsonEncode(
                HomeWidgetSnapshot.build(
                  config: config,
                  now: DateTime.now(),
                  goal: facts,
                  planner: planner,
                ).data,
              ),
            );
          }
          check();
          await channel.invokeMethod<void>('publish', {
            'uid': uid,
            'snapshots': payloads,
          });
        } catch (_) {
          /* A confirmed contribution stays confirmed. */
        }
      } catch (_) {
        /* Unknown outcomes retain the immutable operation for retry. */
      }
      if (!success) {
        await channel.invokeMethod<void>('result', {
          ...identity,
          'success': false,
        });
      }
    }
  } catch (_) {
    await channel.invokeMethod<void>('defer');
  } finally {
    await channel.invokeMethod<void>('done');
  }
}
