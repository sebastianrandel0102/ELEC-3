import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/intelligence/multilingual_evaluator.dart';

void main() {
  test('direct specification acceptance cases preserve intent and boundaries', () {
    final data = jsonDecode(
      File('test/fixtures/agent_language_acceptance_v2.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final cases = (data['cases'] as List).cast<Map<String, dynamic>>();
    final results = MultilingualEvaluator().evaluate(
      cases,
      DateTime.parse(data['clock'] as String),
    );
    final report = File(
      'build/reports/agent_language_acceptance_v2_results.json',
    );
    report.parent.createSync(recursive: true);
    report.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({...results, 'corpus': 'agent_language_acceptance_v2'})}\n',
    );
    final failures = results['failures'] as List;
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
  test(
    'versioned multilingual synthetic corpus has stable intents and slots',
    () {
      final data = jsonDecode(
        File('test/fixtures/agent_language_v1.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final fixtures = (data['cases'] as List).cast<Map<String, dynamic>>();
      expect(fixtures.length, greaterThanOrEqualTo(300));
      final results = MultilingualEvaluator().evaluate(
        fixtures,
        DateTime.parse(data['clock'] as String),
      );
      final report = File('build/reports/agent_language_v1_results.json');
      report.parent.createSync(recursive: true);
      report.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(results)}\n',
      );
      final failures = results['failures'] as List;
      expect(failures, isEmpty, reason: failures.take(35).join('\n'));
    },
  );
}
