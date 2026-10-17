import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_planner.dart';

import 'fixtures/universal_intelligence_cases.dart';

void main() {
  test('universal semantics synthetic corpus', () {
    const baseline = bool.fromEnvironment('AGENT_BASELINE');
    final rows = <Map<String, Object?>>[];
    final failures = <String>[];
    final fixtures = universalCases();
    expect(fixtures.length, greaterThanOrEqualTo(1000));
    for (var i = 0; i < fixtures.length; i++) {
      final c = fixtures[i];
      final p = LocalAgentPlanner().plan(
        c.input,
        now: DateTime(2026, 10, 17, 10),
      );
      final actual = p.actions.map((a) => a.toJson()).toList();
      final intentOK = p.interpretation!.intent.name == c.intent;
      var fields = 0, correct = 0;
      var titleOK =
          c.missionTitle == null &&
          !c.actions.any(
            (a) => a.containsKey('name') || a.containsKey('title'),
          );
      if (c.actions.length == actual.length) {
        for (var j = 0; j < c.actions.length; j++) {
          for (final field in c.actions[j].entries) {
            fields++;
            if (actual[j][field.key] == field.value) correct++;
            if (field.key == 'name' || field.key == 'title') {
              titleOK = actual[j][field.key] == field.value;
            }
          }
        }
      } else {
        fields = c.actions.fold(0, (sum, a) => sum + a.length);
      }
      // Mission metadata is available in the interpretation even with no steps.
      if (c.missionTitle != null) {
        fields++;
        titleOK = p.interpretation!.slots['missionTitle'] == c.missionTitle;
        if (titleOK) correct++;
      }
      final safe = !c.noActions || actual.isEmpty;
      final provenanceOK =
          c.titleOrigin == null ||
          p.interpretation!.titles.firstOrNull?.title.origin.identifier ==
              c.titleOrigin;
      if (!baseline && !provenanceOK) {
        failures.add(
          '$i ${c.input}: title provenance expected ${c.titleOrigin}',
        );
      }
      final passed = intentOK && correct == fields && safe;
      if (!passed) {
        failures.add(
          '$i ${c.input}: expected ${c.intent} ${c.actions} ${c.missionTitle ?? ''}; got ${p.interpretation!.intent.name} $actual',
        );
      }
      rows.add({
        'expected': c.intent,
        'actual': p.interpretation!.intent.name,
        'intentOK': intentOK,
        'fields': fields,
        'correctFields': correct,
        if (c.titleOrigin != null) 'titleOK': titleOK,
        if (c.titleOrigin != null) 'provenanceOK': provenanceOK,
        'titleOrigin': c.titleOrigin,
        'negative': c.noActions,
        'overtrigger': !safe,
        'passed': passed,
        'domain': c.missionTitle != null
            ? 'mission'
            : c.actions.firstOrNull?['type'] ?? 'negative',
      });
    }
    final labels = rows.map((r) => r['expected']).toSet();
    final perIntent = <String, Object?>{};
    var totalF1 = 0.0;
    for (final label in labels) {
      final tp = rows
          .where((r) => r['expected'] == label && r['actual'] == label)
          .length;
      final fp = rows
          .where((r) => r['expected'] != label && r['actual'] == label)
          .length;
      final fn = rows
          .where((r) => r['expected'] == label && r['actual'] != label)
          .length;
      final precision = tp + fp == 0 ? 0.0 : tp / (tp + fp);
      final recall = tp + fn == 0 ? 0.0 : tp / (tp + fn);
      final f1 = precision + recall == 0
          ? 0.0
          : 2 * precision * recall / (precision + recall);
      totalF1 += f1;
      perIntent[label as String] = {
        'precision': precision,
        'recall': recall,
        'f1': f1,
        'support': tp + fn,
      };
    }
    final report = <String, Object?>{
      'corpus': 'universal_intelligence_v3',
      'scope': 'Synthetic text development regression; no live speech, provider calls, or user records',
      'clock': '2026-10-17T10:00:00',
      'cases': rows.length,
      'correctIntents': rows.where((r) => r['intentOK'] == true).length,
      'passedCases': rows.where((r) => r['passed'] == true).length,
      'annotatedFields': rows.fold<int>(0, (n, r) => n + (r['fields'] as int)),
      'correctFields': rows.fold<int>(
        0,
        (n, r) => n + (r['correctFields'] as int),
      ),
      'macroF1': totalF1 / labels.length,
      'intentMetrics': perIntent,
      'confusionMatrix': {
        for (final label in labels)
          label as String: {
            for (final actual in rows.map((r) => r['actual']).toSet())
              actual as String: rows
                  .where((r) => r['expected'] == label && r['actual'] == actual)
                  .length,
          },
      },
      'titleExactMatch': {
        for (final domain in [
          'createGoal',
          'createTask',
          'createReminder',
          'mission',
          'scenario',
        ])
          domain: {
            'annotated': rows
                .where((r) => r['domain'] == domain && r.containsKey('titleOK'))
                .length,
            'matched': rows
                .where((r) => r['domain'] == domain && r['titleOK'] == true)
                .length,
          },
      },
      'negativeCases': rows.where((r) => r['negative'] == true).length,
      'proposalOvertriggers': rows
          .where((r) => r['overtrigger'] == true)
          .length,
      'titleProvenance': {
        'annotated': rows.where((r) => r.containsKey('provenanceOK')).length,
        'matched': rows.where((r) => r['provenanceOK'] == true).length,
      },
      'explicitTitleExactMatch': {
        for (final domain in [
          'createGoal',
          'createTask',
          'createReminder',
          'mission',
          'scenario',
        ])
          domain: {
            'annotated': rows
                .where(
                  (r) =>
                      r['domain'] == domain &&
                      r['titleOrigin'] == 'explicit_user_title',
                )
                .length,
            'matched': rows
                .where(
                  (r) =>
                      r['domain'] == domain &&
                      r['titleOrigin'] == 'explicit_user_title' &&
                      r['titleOK'] == true,
                )
                .length,
          },
      },
      'failures': failures,
    };
    final file = File(
      'build/reports/agent_universal_${baseline ? 'baseline' : 'results'}.json',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
    if (!baseline) {
      expect(failures, isEmpty, reason: failures.take(35).join('\n'));
    }
  });
}
