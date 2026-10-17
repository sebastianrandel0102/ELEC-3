import '../agent_planner.dart';

/// Synthetic text regression metrics only. These do not measure live speech,
/// general linguistic fluency, or unseen production conversations.
class MultilingualEvaluator {
  Map<String, Object?> evaluate(
    List<Map<String, dynamic>> fixtures,
    DateTime clock,
  ) {
    final groups = <String, List<Map<String, Object?>>>{},
        failures = <String>[];
    for (final fixture in fixtures) {
      final plan = LocalAgentPlanner().plan(
        fixture['input'] as String,
        now: clock,
      );
      final interpretation = plan.interpretation!;
      final expected = fixture['intent'] as String,
          actual = interpretation.intent.name;
      final fields = (fixture['slots'] as Map).cast<String, Object?>();
      var matched = 0;
      final fieldMatches = <String, bool>{};
      for (final e in fields.entries) {
        fieldMatches[e.key] = interpretation.slots[e.key] == e.value;
        if (interpretation.slots[e.key] == e.value) {
          matched++;
        } else {
          failures.add(
            '${fixture['id']}: ${e.key} expected ${e.value}, got ${interpretation.slots[e.key]}',
          );
        }
      }
      if (expected != actual) {
        failures.add(
          '${fixture['id']}: intent expected $expected, got $actual',
        );
      }
      if (fixture['noActions'] == true && plan.actions.isNotEmpty) {
        failures.add('${fixture['id']}: unexpected proposal');
      }
      if (fixture['draftOnly'] == true && !interpretation.draftOnly) {
        failures.add('${fixture['id']}: draft-only lost');
      }
      if (fixture['clarificationExpected'] != null &&
          fixture['clarificationExpected'] !=
              interpretation.questions.isNotEmpty) {
        failures.add('${fixture['id']}: clarification mismatch');
      }
      if (fixture['uncertain'] != null &&
          !interpretation.uncertain.any(
            (u) => u.name == fixture['uncertain'],
          )) {
        failures.add('${fixture['id']}: uncertainty lost');
      }
      groups.putIfAbsent(fixture['group'] as String, () => []).add({
        'expected': expected,
        'actual': actual,
        'matchedFields': matched,
        'fields': fields.length,
        'fieldMatches': fieldMatches,
        'clarificationExpected': fixture['clarificationExpected'],
        'clarificationAsked': interpretation.questions.isNotEmpty,
        'negative': fixture['noActions'] == true,
        'overtrigger': fixture['noActions'] == true && plan.actions.isNotEmpty,
      });
    }
    Map<String, Object?> metrics(List<Map<String, Object?>> rows) {
      final labels = rows.map((r) => r['expected'] as String).toSet();
      final perIntent = <String, Object?>{};
      final fieldTotals = <String, int>{}, fieldCorrect = <String, int>{};
      var sumF1 = 0.0, matched = 0, fields = 0;
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
        final precision = tp + fp == 0 ? 0.0 : tp / (tp + fp),
            recall = tp + fn == 0 ? 0.0 : tp / (tp + fn);
        final f1 = precision + recall == 0
            ? 0.0
            : 2 * precision * recall / (precision + recall);
        sumF1 += f1;
        perIntent[label] = {
          'precision': precision,
          'recall': recall,
          'f1': f1,
          'support': tp + fn,
        };
      }
      for (final r in rows) {
        matched += r['matchedFields'] as int;
        fields += r['fields'] as int;
        for (final e in (r['fieldMatches'] as Map<String, bool>).entries) {
          fieldTotals.update(e.key, (n) => n + 1, ifAbsent: () => 1);
          if (e.value) {
            fieldCorrect.update(e.key, (n) => n + 1, ifAbsent: () => 1);
          }
        }
      }
      final negatives = rows.where((r) => r['negative'] == true).length;
      final overtriggers = rows.where((r) => r['overtrigger'] == true).length;
      return {
        'cases': rows.length,
        'correctIntents': rows
            .where((r) => r['expected'] == r['actual'])
            .length,
        'macroF1': sumF1 / labels.length,
        'intentMetrics': perIntent,
        'annotatedFields': fields,
        'matchedFields': matched,
        'fieldMetrics': {
          for (final e in fieldTotals.entries)
            e.key: {
              'annotated': e.value,
              'matched': fieldCorrect[e.key] ?? 0,
              'exactMatch': (fieldCorrect[e.key] ?? 0) / e.value,
            },
        },
        'annotatedClarifications': rows
            .where((r) => r['clarificationExpected'] != null)
            .length,
        'correctClarifications': rows
            .where(
              (r) =>
                  r['clarificationExpected'] != null &&
                  r['clarificationExpected'] == r['clarificationAsked'],
            )
            .length,
        'slotExactMatch': fields == 0 ? null : matched / fields,
        'negativeCases': negatives,
        'proposalOvertriggers': overtriggers,
        'proposalOvertriggerRate': negatives == 0
            ? null
            : overtriggers / negatives,
      };
    }

    return {
      'schema': 1,
      'corpus': 'agent_language_v1',
      'clock': clock.toIso8601String(),
      'scope': 'Deterministic synthetic text only; no live AI or real speech benchmark',
      'overall': metrics(groups.values.expand((v) => v).toList()),
      'groups': {for (final e in groups.entries) e.key: metrics(e.value)},
      'failures': failures,
    };
  }
}
