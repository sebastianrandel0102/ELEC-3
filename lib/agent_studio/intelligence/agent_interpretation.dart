import '../agent_domain.dart';
import 'semantic_text.dart';
import 'title_resolver.dart';

enum AgentIntent {
  createGoalDraft,
  editGoalDraft,
  taskPlanning,
  reminderPlanning,
  missionPlanning,
  prepareContribution,
  askQuestion,
  simulateSavings,
  allocation,
  cancelMission,
  modifyMission,
  unknown,
}

extension CanonicalAgentIntent on AgentIntent {
  String get identifier => switch (this) {
    AgentIntent.createGoalDraft => 'create_goal_draft',
    AgentIntent.editGoalDraft => 'update_goal_draft',
    AgentIntent.taskPlanning => 'organize_tasks',
    AgentIntent.reminderPlanning => 'create_reminder_draft',
    AgentIntent.missionPlanning => 'create_mission_draft',
    AgentIntent.prepareContribution => 'prepare_savings_contribution',
    AgentIntent.simulateSavings => 'simulate_savings_scenario',
    AgentIntent.allocation => 'allocate_savings',
    AgentIntent.askQuestion => 'ask_question',
    AgentIntent.cancelMission => 'cancel_draft',
    AgentIntent.modifyMission => 'update_draft',
    AgentIntent.unknown => 'unknown',
  };
}

/// Ephemeral provenance attached to an object, never used as execution authority.
class TitleBinding {
  const TitleBinding(this.object, this.title, {this.actionIndex});
  final SemanticObject object;
  final ResolvedTitle title;
  final int? actionIndex;
}

enum UnderstandingStatus { resolved, needsClarification, unsupported }

enum AgentDomain {
  planGoal,
  organizeTasks,
  makeReminder,
  buildMission,
  prepareSavings,
  whatIf,
  generalQuestion,
}

enum Uncertainty {
  amount,
  currency,
  date,
  time,
  target,
  intent,
  recurrence,
  title,
}

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
    Iterable<TitleBinding> titles = const [],
  }) : candidates = List.unmodifiable(candidates),
       slots = Map.unmodifiable(slots),
       evidence = List.unmodifiable(evidence),
       uncertain = Set.unmodifiable(uncertain),
       missing = List.unmodifiable(missing),
       negated = Set.unmodifiable(negated),
       corrections = List.unmodifiable(corrections),
       questions = List.unmodifiable(questions),
       titles = List.unmodifiable(titles);
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
  final List<TitleBinding> titles;
  String get canonicalIntent => intent.identifier;
  AgentDomain get domain => switch (intent) {
    AgentIntent.createGoalDraft ||
    AgentIntent.editGoalDraft => AgentDomain.planGoal,
    AgentIntent.taskPlanning => AgentDomain.organizeTasks,
    AgentIntent.reminderPlanning => AgentDomain.makeReminder,
    AgentIntent.missionPlanning ||
    AgentIntent.modifyMission ||
    AgentIntent.cancelMission => AgentDomain.buildMission,
    AgentIntent.prepareContribution => AgentDomain.prepareSavings,
    AgentIntent.simulateSavings || AgentIntent.allocation => AgentDomain.whatIf,
    _ => AgentDomain.generalQuestion,
  };

  /// Preview only. A structured interpretation cannot contain an approval.
  Map<String, Object?> get structured => {
    'intent': canonicalIntent,
    'fields': {
      ...slots,
      if (titles.length == 1) 'title': titles.single.title.value,
      if (titles.length == 1)
        'titleSource': titles.single.title.origin.identifier,
    },
    'status': 'draft',
    'requiresApproval': true,
  };
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
    String key(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    List<AgentRecord> exact(String title) =>
        authorized.where((r) => key(r.title) == key(title)).toList();
    final source = SemanticText(text);
    for (final quote in source.quotes) {
      final prefix = lower.substring(0, quote.start);
      if (RegExp(
        r'\b(?:to|into|in|for|sa|yung|(?:goal|one)\s+(?:called|named))\s*$',
        caseSensitive: false,
      ).hasMatch(prefix)) {
        return exact(text.substring(quote.start + 1, quote.end - 1));
      }
    }
    final naming = RegExp(
      r'\b(?:goal|one)\s+(?:named|called|titled)\s+',
      caseSensitive: false,
    ).firstMatch(text);
    if (naming != null) {
      final value = text
          .substring(naming.end)
          .split(
            RegExp(
              r'[,;.!?]|\s+(?:at|every|by|tomorrow)\b',
              caseSensitive: false,
            ),
          )
          .first;
      return exact(value);
    }
    final referenceText = source.withoutQuotes.toLowerCase();
    final full = authorized
        .where(
          (r) =>
              key(r.title).split(' ').length > 1 &&
              RegExp(
                '(?<![a-z0-9])${RegExp.escape(key(r.title)).replaceAll(' ', r'\s+')}(?![a-z0-9])',
              ).hasMatch(referenceText),
        )
        .toList();
    if (full.length == 1) return full;
    if (full.length > 1) return full;
    // A short unqualified reference can overlap several authorized records.
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
        (w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(referenceText),
      );
    }).toList();
  }
}
