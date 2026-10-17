import '../agent_domain.dart';

enum AgentIntent {
  createGoalDraft,
  editGoalDraft,
  taskPlanning,
  reminderPlanning,
  prepareContribution,
  askQuestion,
  simulateSavings,
  allocation,
  cancelMission,
  modifyMission,
  unknown,
}

enum UnderstandingStatus { resolved, needsClarification, unsupported }

enum Uncertainty { amount, currency, date, time, target, intent, recurrence }

class SlotEvidence {
  const SlotEvidence(this.field, this.text, this.start, this.end);
  final String field, text;
  final int start, end;
}

/// Ephemeral local interpretation. This object is never sent to a provider or
/// serialized into mission history. Typed drafts remain the execution contract.
class AgentInterpretation {
  AgentInterpretation({
    required this.original,
    required this.normalized,
    required this.language,
    required this.status,
    required this.intent,
    Iterable<AgentIntent> candidates = const [],
    Map<String, Object?> slots = const {},
    Iterable<SlotEvidence> evidence = const [],
    Iterable<Uncertainty> uncertain = const [],
    Iterable<String> missing = const [],
    Iterable<String> negated = const [],
    Iterable<String> corrections = const [],
    Iterable<String> questions = const [],
    this.draftOnly = false,
  }) : candidates = List.unmodifiable(candidates),
       slots = Map.unmodifiable(slots),
       evidence = List.unmodifiable(evidence),
       uncertain = Set.unmodifiable(uncertain),
       missing = List.unmodifiable(missing),
       negated = Set.unmodifiable(negated),
       corrections = List.unmodifiable(corrections),
       questions = List.unmodifiable(questions);
  final String original, normalized;
  final AgentLanguage language;
  final UnderstandingStatus status;
  final AgentIntent intent;
  final List<AgentIntent> candidates;
  final Map<String, Object?> slots;
  final List<SlotEvidence> evidence;
  final Set<Uncertainty> uncertain;
  final Set<String> negated;
  final List<String> missing, corrections, questions;
  final bool draftOnly;
  Map<String, Object?> get diagnostics => {
    'language': language.name,
    'intent': intent.name,
    'status': status.name,
    'missing': missing,
    'uncertain': uncertain.map((s) => s.name).toList(),
  };
}

class GoalReferenceResolver {
  const GoalReferenceResolver();
  List<AgentRecord> matches(String text, List<AgentRecord> authorized) {
    final lower = text.toLowerCase();
    final quoted = RegExp('["“]([^"”]+)["”]')
        .firstMatch(text)?[1]
        ?.toLowerCase();
    if (quoted != null) {
      return authorized.where((r) => r.title.toLowerCase() == quoted).toList();
    }
    // Even an exact short title can overlap another title: keep both choices.
    return authorized.where((r) {
      final words = r.title
          .toLowerCase()
          .split(RegExp(r'\W+'))
          .where(
            (w) =>
                w.length > 2 &&
                !['fund', 'goal', 'savings', 'ipon'].contains(w),
          );
      return words.any(
        (w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(lower),
      );
    }).toList();
  }
}
