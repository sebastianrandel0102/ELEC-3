import 'semantic_text.dart';
import 'title_resolver.dart';

/// List punctuation is meaningful only outside a quoted task name.
class TaskListResolver {
  const TaskListResolver();
  List<ResolvedTitle> resolve(SemanticText text) {
    final marker = RegExp(
      r'\b(?:tasks|gawain)\s*:',
      caseSensitive: false,
    ).firstMatch(text.withoutQuotes);
    if (marker == null) return const [];
    final work = text.source;
    final separators =
        RegExp(r',\s*(?:and\s+)?|\s+and\s+|\r?\n|;|(?:^|\s)\d+[.)]\s+')
            .allMatches(work)
            .where((m) => m.start >= marker.end && !text.quoted(m.start))
            .toList();
    final spans = <SemanticSpan>[];
    var start = marker.end;
    for (final separator in separators) {
      if (separator.start > start) {
        spans.add(SemanticSpan(start, separator.start));
      }
      start = separator.end;
    }
    if (start < text.source.length) {
      spans.add(SemanticSpan(start, text.source.length));
    }
    final titles = <ResolvedTitle>[];
    for (final span in spans) {
      final fragment = span
          .text(text.source)
          .trim()
          .replaceFirst(RegExp(r'^\d+[.)]\s*'), '');
      if (fragment.isEmpty) continue;
      final offset = text.source.indexOf(fragment, span.start);
      final result = const UniversalTitleResolver().resolve(
        SemanticText(fragment),
        SemanticObject.task,
        contextual: true,
        pendingTitle: true,
      );
      if (result.present) {
        titles.add(
          ResolvedTitle(
            value: result.value,
            origin: SlotOrigin.explicitNaming,
            relation: 'task_list',
            evidence: SemanticSpan(
              offset + result.evidence!.start,
              offset + result.evidence!.end,
            ),
          ),
        );
      }
    }
    return titles;
  }
}

/// Calendar recurrence for reminders and contribution periods for simulations
/// are different roles. A monthly simulation needs no monthly scheduler.
class ContributionPeriodResolver {
  const ContributionPeriodResolver();
  String resolve(String text) {
    if (RegExp(
      r'\b(monthly|every month|per month|buwanan|bawat buwan)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'monthly';
    }
    if (RegExp(
      r'\b(daily|every day|per day|araw-araw|bawat araw)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'daily';
    }
    return 'weekly';
  }
}
