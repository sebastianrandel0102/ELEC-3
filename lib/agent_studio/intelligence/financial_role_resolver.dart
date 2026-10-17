import 'money_expression_parser.dart';

class FinancialRoles {
  const FinancialRoles({
    this.target = '',
    this.saved = '',
    this.contributions = const [],
    this.resolved = false,
  });
  final String target, saved;
  final List<String> contributions;
  final bool resolved;
}

/// Assigns exact amounts to semantic roles from adjacent labels and cadence.
/// Two amounts are never assumed to mean target + contribution by their order.
class FinancialRoleResolver {
  const FinancialRoleResolver();
  FinancialRoles resolve(String text, MoneyExpression money) {
    final lower = text.toLowerCase();
    final targets = <String>[],
        savings = <String>[],
        contributions = <String>[];
    var assigned = 0;
    for (var i = 0; i < money.candidates.length; i++) {
      final candidate = money.candidates[i];
      final start = i == 0 ? 0 : money.candidates[i - 1].evidence.end;
      final end = i + 1 == money.candidates.length
          ? lower.length
          : money.candidates[i + 1].evidence.start;
      var before = lower.substring(start, candidate.evidence.start);
      var after = lower.substring(candidate.evidence.end, end);
      // A role after the previous amount belongs to that amount, not this one.
      before = before.split(RegExp(r'\bwith\b|\band\b|[,;]|\bthen\b')).last;
      after = after.split(RegExp(r'\bwith\b|\band\b|[,;]|\bthen\b')).first;
      final target =
          RegExp(r'\b(target|worth|budget|halaga)\b').hasMatch(before) ||
          RegExp(r'^\s*(?:pesos?\s+)?target\b').hasMatch(after);
      final saved =
          RegExp(
            r'\b(already saved|saved|already have|naipon|initial savings)\b',
          ).hasMatch(before) ||
          RegExp(r'^\s*(?:pesos?\s+)?(?:already saved|saved|naipon)\b')
              .hasMatch(after);
      final contribution =
          RegExp(
            r'\b(contribution|contribute|save|saving|put aside|magtabi|mag-ipon|dagdag)\b',
          ).hasMatch(before) ||
          RegExp(
            r'\b(weekly|daily|monthly|per week|per day|per month|every|each week|bawat|tuwing)\b',
          ).hasMatch(after);
      if (saved) {
        savings.add(candidate.amount);
        assigned++;
      } else if (target) {
        targets.add(candidate.amount);
        assigned++;
      } else if (contribution) {
        contributions.add(candidate.amount);
        assigned++;
      }
    }
    final comparison = RegExp(r'\b(compare|versus|vs|ihambing)\b')
        .hasMatch(lower);
    final resolved =
        assigned == money.candidates.length &&
        money.candidates.isNotEmpty &&
        targets.length <= 1 &&
        savings.length <= 1 &&
        (contributions.length <= 1 || comparison) &&
        !money.invalid &&
        !money.approximate &&
        !RegExp(r'\b(or|o)\b').hasMatch(lower);
    return FinancialRoles(
      target: targets.singleOrNull ?? '',
      saved: savings.singleOrNull ?? '',
      contributions: List.unmodifiable(contributions),
      resolved: resolved,
    );
  }
}
