import 'agent_domain.dart';
import 'intelligence/agent_interpretation.dart';
import 'intelligence/agent_language.dart';
import 'intelligence/date_expression_parser.dart';
import 'intelligence/money_expression_parser.dart';
import 'intelligence/semantic_text.dart';
import 'intelligence/title_resolver.dart';
import 'intelligence/domain_slot_resolvers.dart';
import 'intelligence/draft_field_resolver.dart';
import 'intelligence/financial_role_resolver.dart';

class LocalAgentPlan {
  const LocalAgentPlan(
    this.reply, {
    this.actions = const [],
    this.replacement,
    this.replaceStep,
    this.cancel = false,
    this.interpretation,
    this.missionTitle,
    this.removeSteps = const [],
    this.moveStep,
    this.moveBy,
  });
  final String reply;
  final List<AgentAction> actions;
  final AgentAction? replacement;
  final String? replaceStep;
  final bool cancel;
  final AgentInterpretation? interpretation;
  final String? missionTitle;
  final List<String> removeSteps;
  final String? moveStep;
  final int? moveBy;
}

/// Local interpretation only. No provider call, writes, or approvals.
class LocalAgentPlanner {
  static final _goalTerms = RegExp(
    r'\b(goal|fund|ipon|pag-iipunan|save for|want save|savings target|savings(?=\s+(?:ko|para|for|target|worth|named|called)))\b',
  );
  static final _creationTerms = RegExp(
    r'\b(create|pa-create|new|make|want|gusto|gawa|gawan|gumawa|bagong|save for|mag-ipon|mag.set)\b',
  );
  LocalAgentPlan plan(
    String input, {
    AgentMission? mission,
    DateTime? now,
    AgentLanguage language = AgentLanguage.automatic,
    AgentLanguage previousLanguage = AgentLanguage.automatic,
    Map<String, String> memory = const {},
    List<AgentRecord> goals = const [],
    String defaultCurrency = '',
    AgentInterpretation? previous,
  }) {
    if (input.trim().isEmpty || input.length > AgentLimits.input) {
      throw const AgentFailure('Enter a request up to 3,000 characters.');
    }
    final text = SemanticText(input);
    if (mission?.status == MissionStatus.completed ||
        mission?.status == MissionStatus.canceled) {
      mission = null;
      previous = null;
    }
    final scopes = text.commands;
    if (scopes.length == 1) {
      return _planSingle(
        input,
        mission: mission,
        now: now,
        language: language,
        previousLanguage: previousLanguage,
        memory: memory,
        goals: goals,
        defaultCurrency: defaultCurrency,
        previous: previous,
      );
    }
    final plans = [
      for (final scope in scopes)
        _planSingle(
          scope.text(input),
          now: now,
          language: language,
          previousLanguage: previousLanguage,
          memory: memory,
          goals: goals,
          defaultCurrency: defaultCurrency,
        ),
    ];
    final actions = <AgentAction>[], titles = <TitleBinding>[];
    String? missionTitle;
    for (var i = 0; i < plans.length; i++) {
      final plan = plans[i];
      missionTitle ??= plan.missionTitle;
      for (final binding in plan.interpretation!.titles) {
        final t = binding.title, e = t.evidence;
        titles.add(
          TitleBinding(
            binding.object,
            ResolvedTitle(
              value: t.value,
              origin: t.origin,
              relation: t.relation,
              purpose: t.purpose,
              evidence: e == null
                  ? null
                  : SemanticSpan(
                      e.start + scopes[i].start,
                      e.end + scopes[i].start,
                    ),
            ),
            actionIndex: binding.actionIndex == null
                ? null
                : actions.length + binding.actionIndex!,
          ),
        );
      }
      for (final action in plan.actions) {
        var value = action;
        if (value is ReminderDraft &&
            value.targetId.isEmpty &&
            value.targetStep.isEmpty) {
          final reminder = value;
          final explicitGoal = RegExp(r'\bgoal\b')
              .hasMatch(plan.interpretation!.normalized);
          final needsGoal =
              explicitGoal ||
              !['once', 'taskStart', ''].contains(reminder.frequency);
          final parent = actions.lastIndexWhere(
            (a) => a is GoalDraft || !needsGoal && a is TaskDraft,
          );
          if (parent >= 0) {
            value = AgentAction.fromJson({
              ...value.toJson(),
              'targetStep': 'step_${parent + 1}',
              'targetKind': actions[parent] is TaskDraft
                  ? 'task'
                  : 'personalGoal',
            });
          }
        }
        actions.add(value);
      }
    }
    final languageResult = const AgentLanguageDetector().detect(
      input,
      previous: previousLanguage,
    );
    final uncertain = plans.expand((p) => p.interpretation!.uncertain).toSet();
    final questions = plans.expand((p) => p.interpretation!.questions).toSet();
    final intent = missionTitle != null
        ? AgentIntent.missionPlanning
        : plans
              .map((p) => p.interpretation!.intent)
              .firstWhere(
                (i) => i != AgentIntent.unknown,
                orElse: () => AgentIntent.unknown,
              );
    return LocalAgentPlan(
      AgentStrings(
        language == AgentLanguage.automatic ? languageResult : language,
      ).draftNotice,
      actions: actions,
      missionTitle: missionTitle,
      interpretation: AgentInterpretation(
        original: input,
        normalized: const MultilingualNormalizer().normalize(input),
        language: languageResult,
        intent: intent,
        candidates: plans.expand((p) => p.interpretation!.candidates),
        slots: {
          for (final p in plans) ...p.interpretation!.slots,
          'missionTitle': ?missionTitle,
        },
        titles: titles,
        evidence: [
          for (var i = 0; i < plans.length; i++)
            for (final e in plans[i].interpretation!.evidence)
              SlotEvidence(
                e.field,
                e.text,
                e.start + scopes[i].start,
                e.end + scopes[i].start,
              ),
        ],
        status: uncertain.isNotEmpty
            ? UnderstandingStatus.needsClarification
            : UnderstandingStatus.resolved,
        uncertain: uncertain,
        missing: plans.expand((p) => p.interpretation!.missing),
        questions: questions,
        negated: plans.expand((p) => p.interpretation!.negated),
        corrections: plans.expand((p) => p.interpretation!.corrections),
        draftOnly: plans.any((p) => p.interpretation!.draftOnly),
      ),
    );
  }

  LocalAgentPlan _planSingle(
    String input, {
    AgentMission? mission,
    DateTime? now,
    AgentLanguage language = AgentLanguage.automatic,
    AgentLanguage previousLanguage = AgentLanguage.automatic,
    Map<String, String> memory = const {},
    List<AgentRecord> goals = const [],
    String defaultCurrency = '',
    AgentInterpretation? previous,
  }) {
    if (input.trim().isEmpty || input.length > AgentLimits.input) {
      throw const AgentFailure('Enter a request up to 3,000 characters.');
    }
    now ??= DateTime.now();
    final normalized = const MultilingualNormalizer().normalize(input);
    final semantic = SemanticText(input);
    final listedTasks = const TaskListResolver().resolve(semantic);
    final object =
        semantic.tokens
            .where((t) => !semantic.quoted(t.start))
            .map((t) => SemanticText.object(t.value))
            .whereType<SemanticObject>()
            .firstOrNull ??
        (RegExp(
              r'\b(save for|want save|want to save|saving up for|to buy|pambili ng|pang|savings target|savings ko)\b',
              caseSensitive: false,
            ).hasMatch(normalized)
            ? SemanticObject.goal
            : null);
    var title = object == null
        ? const ResolvedTitle()
        : const UniversalTitleResolver().resolve(
            semantic,
            object,
            contextual: !semantic.tokens.any(
              (t) => SemanticText.object(t.value) == object,
            ),
          );
    if (object == null &&
        mission != null &&
        RegExp(
          r'\b(call|name|title|label|pangalan|tawag|pangalanan)\b',
          caseSensitive: false,
        ).hasMatch(input)) {
      title = const UniversalTitleResolver().resolve(
        semantic,
        SemanticObject.goal,
        contextual: true,
      );
    }
    if (title.present && ['object_title', 'purpose'].contains(title.relation)) {
      final embedded = const MoneyExpressionParser().parse(title.value);
      final number = embedded.candidates.firstOrNull;
      if (number != null &&
          number.evidence.start > 0 &&
          title.evidence != null) {
        final end = title.evidence!.start + number.evidence.start;
        title = ResolvedTitle(
          value: input.substring(title.evidence!.start, end).trim(),
          origin: title.origin,
          relation: title.relation,
          evidence: SemanticSpan(title.evidence!.start, end),
          purpose: title.purpose,
        );
      }
    }
    if (!title.present &&
        object == SemanticObject.goal &&
        !semantic.tokens.any(
          (t) => SemanticText.object(t.value) == SemanticObject.goal,
        )) {
      final save = RegExp(
        r'\b(?:save|savings)\s+(?:ko\s+)?',
        caseSensitive: false,
      ).firstMatch(input);
      if (save != null) {
        final resolved = const UniversalTitleResolver().resolve(
          SemanticText(input.substring(save.end)),
          SemanticObject.goal,
          contextual: true,
          pendingTitle: true,
        );
        if (resolved.present &&
            !RegExp(r'^(?:target|for|to)\b')
                .hasMatch(resolved.value.toLowerCase())) {
          title = ResolvedTitle(
            value: resolved.value,
            origin: SlotOrigin.inferredPurpose,
            relation: 'purpose',
            evidence: SemanticSpan(
              save.end + resolved.evidence!.start,
              save.end + resolved.evidence!.end,
            ),
          );
        }
      }
    }
    final roleText = semantic.mask([
      ...semantic.quotes,
      if (title.evidence != null) title.evidence!,
      for (final item in listedTasks)
        if (item.evidence != null) item.evidence!,
    ]);
    final command = const MultilingualNormalizer().normalize(
      SemanticText.commandText(roleText),
    );
    final titleBindings = <TitleBinding>[];
    final detected = const AgentLanguageDetector().detect(
      normalized,
      previous: previousLanguage,
    );
    final s = AgentStrings(
      language == AgentLanguage.automatic ? detected : language,
    );
    final uncertain = <Uncertainty>{},
        negated = <String>{},
        corrections = <String>[];
    final questions = <String>[], intents = <AgentIntent>[];
    final slots = <String, Object?>{}, evidence = <SlotEvidence>[];
    if (semantic.unclosedQuote) {
      uncertain.add(Uncertainty.title);
      questions.add(
        s.choose(
          'The quoted title is unfinished. Close the quote or edit the title.',
          'Hindi pa tapos ang pangalan sa panipi. Kumpletuhin o i-edit ang pangalan.',
        ),
      );
    }
    if (title.relation == 'object_title' &&
        RegExp(r'^cold\s+', caseSensitive: false).hasMatch(title.value)) {
      uncertain.add(Uncertainty.title);
      questions.add(
        s.choose(
          'Did you mean a title introduced by “called”? Review the recognized text.',
          'Pangalan ba ang kasunod ng “called”? Suriin ang narinig na teksto.',
        ),
      );
    }
    final conditional =
        RegExp(r'\b(?:if|kung|kapag|pag|when)\s+').hasMatch(command) &&
        !RegExp(r'\bwhat[ -]if\b').hasMatch(normalized);
    var draftOnly = RegExp(
      r"\b(plan lang|draft only|plan only|not yet|wag muna|huwag muna|huwag pa|don't save|do not save|dont save|maybe|siguro|baka|sana|thinking about|plano ko)\b",
    ).hasMatch(command);
    if (draftOnly) negated.add('execute_now');
    LocalAgentPlan result(
      String reply, {
      List<AgentAction> actions = const [],
      AgentAction? replacement,
      String? replaceStep,
      bool cancel = false,
      AgentIntent? intent,
      bool unsupported = false,
      String? missionTitle,
      List<String> removeSteps = const [],
      String? moveStep,
      int? moveBy,
    }) {
      final missing = <String>[];
      final proposed = [...actions, ?replacement];
      if (conditional &&
          (proposed.any((a) => a.permission != null && a is! AllocationDraft) ||
              (proposed.isEmpty &&
                  mission?.pending.any(
                        (st) =>
                            st.action.permission != null &&
                            st.action is! AllocationDraft,
                      ) ==
                      true))) {
        draftOnly = true;
        slots['conditional'] = true;
        negated.add('execute_until_condition_confirmed');
        questions.add(
          s.choose(
            'Keep this as a plan until the condition is met. Enable review when you are ready.',
            'Plano lang muna ito hanggang matupad ang kondisyon. Payagan ang pagsusuri kapag handa ka na.',
          ),
        );
      }
      for (final a in proposed) {
        missing.addAll(_requiredMissing(a));
      }
      for (final binding in titleBindings) {
        final span = binding.title.evidence;
        if (span != null) {
          evidence.add(
            SlotEvidence(
              '${binding.object.name}.title',
              span.text(input),
              span.start,
              span.end,
            ),
          );
        }
      }
      return LocalAgentPlan(
        reply,
        actions: actions,
        replacement: replacement,
        replaceStep: replaceStep,
        cancel: cancel,
        missionTitle: missionTitle,
        removeSteps: removeSteps,
        moveStep: moveStep,
        moveBy: moveBy,
        interpretation: AgentInterpretation(
          original: input,
          normalized: normalized,
          language: detected,
          status: unsupported
              ? UnderstandingStatus.unsupported
              : uncertain.isNotEmpty || missing.isNotEmpty
              ? UnderstandingStatus.needsClarification
              : UnderstandingStatus.resolved,
          intent: intent ?? intents.firstOrNull ?? AgentIntent.unknown,
          candidates: intents,
          slots: slots,
          evidence: evidence,
          uncertain: uncertain,
          missing: missing,
          negated: negated,
          corrections: corrections,
          questions: questions,
          draftOnly: draftOnly,
          titles: titleBindings,
        ),
      );
    }

    if (RegExp(
      r'\b(actually\s+)?(wag na|huwag na|ayoko na|never mind|nevermind|cancel mission|cancel proposal|kanselahin|i-cancel)\b|^(cancel|stop mission|start over|forget this draft|cancel that plan)[.!]?$',
    ).hasMatch(command)) {
      return result(
        s.choose(
          'Mission canceled. Completed operations remain in your records.',
          'Kinansela ang mission. Mananatili ang mga natapos na pagbabago.',
        ),
        cancel: true,
        intent: AgentIntent.cancelMission,
      );
    }
    if (RegExp(
      r'^(yes|approve|approved|do everything|oo|opo|sige|okay|ok|go|execute)[.!]?$',
    ).hasMatch(command)) {
      return result(
        s.choose(
          'Open Review Mission and use its dedicated confirmation button. A chat or spoken approval cannot authorize changes.',
          'Gamitin ang kumpirmasyon sa Suriin ang mission. Hindi sapat ang chat o boses para aprubahan ang pagbabago.',
        ),
        intent: AgentIntent.askQuestion,
      );
    }
    if (RegExp(
      r'^(explain|what is|what are|what does|how does|why|ano ang|ano yung|ipaliwanag|patingin|show me)\b',
    ).hasMatch(command)) {
      return result(
        s.choose(
          'Use Ask Anything for general explanations. Contributions add savings; withdrawals reduce a goal’s balance. Neither happens through a question.',
          'Buksan ang Ask Anything para sa paliwanag. Walang mababago sa ipon dahil sa tanong.',
        ),
        intent: AgentIntent.askQuestion,
      );
    }
    if (mission != null && RegExp(r'^remove\b').hasMatch(command)) {
      final wanted = object;
      final targets = mission.steps
          .where(
            (st) =>
                !st.done &&
                st.attempts == 0 &&
                (wanted == null || _objectFor(st.action) == wanted),
          )
          .toList();
      if (targets.length == 1 ||
          wanted == SemanticObject.reminder && targets.isNotEmpty) {
        return result(
          'Removed the selected draft steps. No saved records changed.',
          removeSteps: targets.map((s) => s.id).toList(),
          intent: AgentIntent.modifyMission,
        );
      }
      uncertain.add(Uncertainty.target);
      questions.add(s.step);
      return result(s.step, intent: AgentIntent.modifyMission);
    }
    if (mission != null && RegExp(r'^move\b').hasMatch(command)) {
      final order = RegExp(
        r'(first|second|third|\d+)\b.*\bbefore\s+(?:the\s+)?(first|second|third|\d+)',
      ).firstMatch(command);
      if (order != null) {
        int index(String s) =>
            const {'first': 0, 'second': 1, 'third': 2}[s] ?? int.parse(s) - 1;
        final from = index(order[1]!), to = index(order[2]!);
        if (from >= 0 &&
            from < mission.steps.length &&
            to >= 0 &&
            to < mission.steps.length &&
            mission.steps[from].attempts == 0 &&
            !mission.steps[from].dependsOn.contains(mission.steps[to].id)) {
          return result(
            'Updated the draft order. Review before approval.',
            moveStep: mission.steps[from].id,
            moveBy: to - from,
            intent: AgentIntent.modifyMission,
          );
        }
      }
      uncertain.add(Uncertainty.target);
      questions.add(s.step);
      return result(s.step, intent: AgentIntent.modifyMission);
    }
    final newRequest = RegExp(
      r'\b(create|new|build|gawa|pakigawa|gawan|gumawa|add|pa-create|i-create)\b',
    ).hasMatch(command);
    final naming = RegExp(
      r'\b(call|name|title|label|named|called|titled|pangalan|tawag|pangalanan|tawagin|ipangalan)\b|\bmake\s+(?:the\s+)?(?:first|second|third)\s+task\b',
    ).hasMatch(command);
    if (mission == null && object == null && naming) {
      uncertain.add(Uncertainty.intent);
      final question = s.choose(
        'Which draft should I name: a goal, task, reminder, mission, or scenario?',
        'Aling draft ang papangalanan: goal, gawain, paalala, mission, o scenario?',
      );
      questions.add(question);
      return result(question);
    }
    if (mission != null && !newRequest) {
      final candidates = mission.steps
          .where(
            (st) =>
                st.selected &&
                !st.done &&
                st.attempts == 0 &&
                (object == null || _objectFor(st.action) == object),
          )
          .toList();
      final pending = candidates
          .where(
            (st) =>
                _requiredMissing(st.action)
                    .any((f) => f == 'name' || f == 'title'),
          )
          .toList();
      final possibleBareTitle =
          const MoneyExpressionParser().parse(input).candidates.isEmpty &&
          !RegExp(
            r'\b(target|deadline|tomorrow|bukas|today|ngayon|priority|every|tuwing)\b',
            caseSensitive: false,
          ).hasMatch(input);
      if (naming ||
          mission.steps.isEmpty && possibleBareTitle ||
          pending.length == 1 &&
              possibleBareTitle &&
              previous?.missing.any((f) => f == 'name' || f == 'title') ==
                  true) {
        if (object == SemanticObject.mission || mission.steps.isEmpty) {
          final resolved = const UniversalTitleResolver().resolve(
            semantic,
            SemanticObject.mission,
            contextual: true,
            pendingTitle: mission.steps.isEmpty,
          );
          if (resolved.present) {
            slots['missionTitle'] = resolved.value;
            titleBindings.add(TitleBinding(SemanticObject.mission, resolved));
            return result(
              'Updated the mission title. Review before approval.',
              missionTitle: resolved.value,
              intent: AgentIntent.modifyMission,
            );
          }
        }
        final numbered = RegExp(r'\b(?:step|hakbang)\s+(\d+)')
            .firstMatch(command);
        final ordinal = RegExp(
          r'\b(first|second|third)\s+(?:goal|task|reminder|scenario)\b',
        ).firstMatch(command);
        final ordinalIndex = ordinal == null
            ? -1
            : const ['first', 'second', 'third'].indexOf(ordinal[1]!);
        final selected = numbered != null
            ? candidates
                  .where((st) => st.id == 'step_${numbered[1]}')
                  .firstOrNull
            : ordinalIndex >= 0 && ordinalIndex < candidates.length
            ? candidates[ordinalIndex]
            : candidates.length == 1
            ? candidates.single
            : pending.length == 1
            ? pending.single
            : null;
        if (selected != null) {
          final domain = _objectFor(selected.action);
          final resolved = const UniversalTitleResolver().resolve(
            semantic,
            domain,
            contextual: true,
            pendingTitle: pending.contains(selected),
          );
          if (resolved.present) {
            final key = selected.action is GoalDraft ? 'name' : 'title';
            final updatedTitle = resolved.origin == SlotOrigin.contextFollowUp
                ? resolved
                : resolved.withOrigin(SlotOrigin.userCorrection);
            titleBindings.add(
              TitleBinding(
                domain,
                updatedTitle,
                actionIndex: mission.steps.indexOf(selected),
              ),
            );
            slots['title'] = resolved.value;
            slots['titleSource'] = updatedTitle.origin.identifier;
            final patchMoney = const MoneyExpressionParser().parse(roleText);
            final patchCalendar = const DateExpressionParser().parse(
              roleText,
              now,
            );
            if (patchMoney.ambiguous) {
              uncertain.add(Uncertainty.amount);
              questions.add(s.amount);
            }
            if (patchMoney.currencyAmbiguous) {
              uncertain.add(Uncertainty.currency);
              questions.add(s.currency);
            }
            if (patchCalendar.ambiguousDate) {
              uncertain.add(Uncertainty.date);
              questions.add(s.date);
            }
            if (patchCalendar.ambiguousTime) {
              uncertain.add(Uncertainty.time);
              questions.add(s.time);
            }
            final patched = const DraftFieldResolver().apply(
              selected.action,
              patchMoney,
              patchCalendar,
              command,
            );
            return result(
              'Updated the draft title. Review before approval.',
              replacement: AgentAction.fromJson({
                ...patched.toJson(),
                key: resolved.value,
              }),
              replaceStep: selected.id,
              intent: AgentIntent.modifyMission,
            );
          }
        } else {
          uncertain.add(Uncertainty.target);
          questions.add(s.step);
          return result(s.step, intent: AgentIntent.modifyMission);
        }
      }
    }
    if (RegExp(r'^(cancel|stop|remove|disable)\b').hasMatch(command)) {
      negated.add('operation');
      return result(
        s.choose(
          'Choose the existing item in its SaveTrack screen to cancel or disable it. Pending mission review is paused.',
          'Piliin ang kasalukuyang item sa SaveTrack para kanselahin ito. Naka-pause ang pagsusuri ng mission.',
        ),
        intent: AgentIntent.modifyMission,
      );
    }
    final positive = <String>[];
    for (final clause in command.split(
      RegExp(r'[;!]|\.(?!\d)|\b(?:pero|but)\b'),
    )) {
      if (RegExp(r"\b(hindi|di|huwag|wag|ayoko|dont|don't|do not|not|never)\b")
          .hasMatch(clause)) {
        if (RegExp(r'\b(save|i-save|execute|commit)\b').hasMatch(clause)) {
          draftOnly = true;
          negated.add('execute_now');
          final before = clause
              .split(RegExp(r"\b(huwag|wag|dont|don't|do not|not yet)\b"))
              .first;
          if (before.trim().isNotEmpty) positive.add(before);
        } else {
          negated.add(
            clause.contains('remind')
                ? 'createReminder'
                : clause.contains('bawas')
                ? 'withdrawal'
                : 'operation',
          );
        }
      } else {
        positive.add(clause);
      }
    }
    var actionText = positive.join(' ').trim();
    var money = const MoneyExpressionParser().parse(
      roleText.replaceAllMapped(
        RegExp(r'\bhow\s+about\b', caseSensitive: false),
        (m) => ' ' * m[0]!.length,
      ),
    );
    var calendar = const DateExpressionParser().parse(roleText, now);
    final correction = RegExp(
      r'\b(?:ay wait|wait actually|actually|sorry|wait|no|ay hindi|hindi pala|ay|instead)\b\s*[,.:]*\s*',
      caseSensitive: false,
    ).allMatches(roleText).lastOrNull;
    if (correction != null) {
      final tail = roleText.substring(correction.end);
      final cm = const MoneyExpressionParser().parse(tail);
      final cd = const DateExpressionParser().parse(tail, now);
      if (cm.candidates.isNotEmpty) {
        corrections.add('amount');
        money = MoneyExpression(
          amount: cm.amount,
          currency: cm.currency.isEmpty ? money.currency : cm.currency,
          ambiguous: cm.ambiguous,
          invalid: cm.invalid,
          approximate: cm.approximate,
          currencyAmbiguous: cm.currencyAmbiguous,
          candidates: [
            for (final candidate in cm.candidates)
              MoneyCandidate(
                candidate.amount,
                SlotEvidence(
                  'amount',
                  candidate.evidence.text,
                  candidate.evidence.start + correction.end,
                  candidate.evidence.end + correction.end,
                ),
              ),
          ],
        );
      }
      if (cd.date != null || cd.weekday != null || cd.time.isNotEmpty) {
        calendar = cd;
        corrections.add('schedule');
      }
      if (RegExp(r'^(edit|change|modify|palitan|ayusin)\b').hasMatch(tail)) {
        actionText = tail;
      }
    } else if (RegExp(
      r'\b(?:friday|biyernes|saturday|sabado|monday|lunes),?\s+hindi,?\s+',
    ).hasMatch(normalized)) {
      calendar = const DateExpressionParser().parse(
        normalized.split(RegExp(r',?\s+hindi,?\s+')).last,
        now,
      );
      corrections.add('schedule');
      actionText = normalized.replaceFirst(
        RegExp(
          r'\b(?:friday|biyernes|saturday|sabado|monday|lunes),?\s+hindi,?\s+',
        ),
        '',
      );
    }
    final recurringContext =
        RegExp(r'\b(every|tuwing|weekly)\b').hasMatch(normalized) ||
        mission?.steps
                .where(
                  (st) =>
                      st.selected &&
                      st.action is ReminderDraft &&
                      (st.action as ReminderDraft).frequency == 'weekly',
                )
                .length ==
            1;
    if (calendar.weekday != null &&
        recurringContext &&
        !RegExp(r'\d{4}-\d{2}-\d{2}|\b(next|susunod|once|sa|on)\b')
            .hasMatch(normalized)) {
      calendar = DateExpression(
        time: calendar.time,
        weekday: calendar.weekday,
        frequency: 'weekly',
        ambiguousTime: calendar.ambiguousTime,
        unsupportedRecurrence: calendar.unsupportedRecurrence,
      );
    }
    final bareReference = RegExp(
      r'^(?:(?:step|hakbang)\s+\d+|(?:yung|the)\s+(?:una|pangalawa|first|second))[.!]?$',
    ).hasMatch(normalized);
    if (bareReference &&
        mission != null &&
        previous?.uncertain.length == 1 &&
        previous!.uncertain.contains(Uncertainty.target)) {
      money = MoneyExpression(
        amount: previous.slots['amount'] as String? ?? '',
        currency: previous.slots['currency'] as String? ?? '',
      );
      calendar = DateExpression(
        date: DateTime.tryParse(previous.slots['date'] as String? ?? ''),
        time: previous.slots['time'] as String? ?? '',
        weekday: previous.slots['weekday'] as int?,
        frequency: previous.slots['recurrence'] as String? ?? '',
      );
      corrections.add('target_selected_from_current_draft');
    }
    if (money.ambiguous) {
      uncertain.add(Uncertainty.amount);
      questions.add(s.amount);
    }
    if (money.currencyAmbiguous) {
      uncertain.add(Uncertainty.currency);
      questions.add(s.currency);
    }
    if (calendar.ambiguousDate) {
      uncertain.add(Uncertainty.date);
      questions.add(s.date);
    }
    if (calendar.ambiguousTime) {
      uncertain.add(Uncertainty.time);
      questions.add(s.time);
    }
    if (calendar.unsupportedRecurrence &&
        RegExp(r'\b(remind|reminder|paalala|alarm)\b').hasMatch(command)) {
      uncertain.add(Uncertainty.recurrence);
      questions.add(
        s.choose(
          'Choose a supported schedule in the reminder editor. Monthly and payday schedules are unavailable here.',
          'Pumili ng iskedyul sa paalala. Hindi pa suportado rito ang buwanan o payday.',
        ),
      );
    }
    final amount = money.amount,
        currency = money.currency,
        date = calendar.date,
        time = calendar.time;
    final weekday = calendar.weekday ?? _weekday(memory['reminderDay'] ?? '');
    slots.addAll({
      'amount': amount,
      'currency': currency,
      'date': date == null ? null : agentDay(date),
      'time': time,
      'weekday': weekday,
      'recurrence': calendar.frequency,
      'amountCandidates': money.candidates.map((m) => m.amount).toList(),
    });
    evidence.addAll(money.candidates.map((m) => m.evidence));
    if (RegExp(
      r'\b(withdraw\w*|delete|decrease|burahin|bawasan|bawas|alisin)\b',
    ).hasMatch(actionText)) {
      return result(
        s.choose(
          'Use the goal’s existing Delete or Decrease Savings controls. Agent missions do not delete records or withdraw savings.',
          'Gamitin ang Delete o Decrease Savings sa goal. Hindi nagbubura o nagbabawas ng ipon ang Agent.',
        ),
        unsupported: true,
      );
    }
    final edit = RegExp(
      r'\b(edit|modify|palitan|gawin mong|gawin mo|change|ayusin|pakiayos)\b',
    ).hasMatch(actionText);
    final hasGoal = _goalTerms.hasMatch(actionText);
    final creatingGoal =
        !edit &&
        actionText.isNotEmpty &&
        (_createsGoal(actionText) ||
            object == SemanticObject.goal &&
                title.present &&
                !_isReferenceCommand(command) &&
                (title.relation == 'inverse_assignment' ||
                    !RegExp(
                      r'\b(add|pa-add|prepare|deposit|put|dagdagan|maglagay|save)\b',
                    ).hasMatch(command)));
    final task =
        RegExp(
          r'\b(task|tasks|to-do|to do|activity|organize|organise|planner|study|assignment|gawain|aral)\b',
        ).hasMatch(actionText) &&
        (object == null || object == SemanticObject.task);
    final reminder =
        RegExp(r'\b(remind|pa-remind|reminder|paalala|ipaalala|alarm)\b')
            .hasMatch(actionText) &&
        (object == null || object == SemanticObject.reminder);
    final allocation = RegExp(r'\b(allocat\w*|split|balance my goals|hatiin)\b')
        .hasMatch(actionText);
    final scenario = RegExp(
      r'\b(simulat\w*|compare\s+sav\w*|what.if|what happens if|suppose|imagine|how long if|paano kung|kung (?=magtabi|mag-ipon|\d)|when will i finish|scenario|weekly plan|savings plan|plan.*savings|plan.*ipon|weekly contributions)\b',
    ).hasMatch(actionText);
    final contribution =
        !creatingGoal &&
        !task &&
        !reminder &&
        !scenario &&
        !allocation &&
        RegExp(
          r'\b(add|pa-add|prepare|deposit|put|maglagay|magdagdag|dagdag|dagdagan|magtabi|maghulog|save|saving)\b',
        ).hasMatch(actionText);
    final nameRepair =
        previous?.missing.contains('name') == true &&
        mission?.steps
                .where(
                  (st) =>
                      st.action is GoalDraft &&
                      (st.action as GoalDraft).name.isEmpty,
                )
                .length ==
            1 &&
        amount.isEmpty &&
        !money.ambiguous &&
        currency.isEmpty &&
        date == null &&
        time.isEmpty &&
        weekday == null &&
        !edit &&
        input.trim().length <= 100;
    final patchSignal =
        nameRepair ||
        amount.isNotEmpty ||
        money.candidates.isNotEmpty ||
        money.ambiguous ||
        currency.isNotEmpty ||
        date != null ||
        time.isNotEmpty ||
        weekday != null ||
        calendar.ambiguousDate ||
        calendar.ambiguousTime ||
        edit ||
        draftOnly;
    if (mission != null &&
        !creatingGoal &&
        !allocation &&
        (!contribution || edit) &&
        (!task || edit) &&
        (!reminder || edit) &&
        patchSignal) {
      final candidates = mission.steps
          .where((s) => s.selected && !s.done && s.attempts == 0)
          .toList();
      final numbered = RegExp(r'\b(?:step|hakbang)\s+(\d+)\b')
          .firstMatch(normalized);
      final ordinal = RegExp(r'\b(?:yung|the)\s+(una|pangalawa|first|second)\b')
          .firstMatch(normalized);
      AgentStep? selected;
      if (numbered != null || ordinal != null) {
        final n = numbered != null
            ? int.parse(numbered[1]!)
            : (['una', 'first'].contains(ordinal![1]) ? 1 : 2);
        if (n > 0 &&
            n <= mission.steps.length &&
            candidates.contains(mission.steps[n - 1])) {
          selected = mission.steps[n - 1];
        }
      } else {
        final compatible = candidates.where((st) {
          final a = st.action;
          if (nameRepair) return a is GoalDraft && a.name.isEmpty;
          if (amount.isNotEmpty || money.ambiguous || currency.isNotEmpty) {
            return a is GoalDraft ||
                a is ContributionDraft ||
                a is ScenarioDraft ||
                a is AllocationDraft;
          }
          if (time.isNotEmpty || calendar.ambiguousTime || weekday != null) {
            return a is ReminderDraft || (a is TaskDraft && weekday == null);
          }
          if (date != null || calendar.ambiguousDate) {
            return a is GoalDraft ||
                a is TaskDraft ||
                a is ReminderDraft ||
                a is ScenarioDraft;
          }
          return true;
        }).toList();
        if (compatible.length == 1) selected = compatible.single;
      }
      if (selected != null) {
        final values = selected.action.toJson(), a = selected.action;
        if (nameRepair && a is GoalDraft) {
          values['name'] = input.trim().replaceAll(RegExp('^["“]|["”]\$'), '');
        }
        final action = const DraftFieldResolver().apply(
          AgentAction.fromJson(values),
          money,
          calendar,
          command,
        );
        questions.addAll(_missingQuestions(action, s));
        return result(
          '${s.choose('Updated the draft. Review its values before approval.', 'Na-update ang draft. Suriin ang mga detalye bago aprubahan.')}\n${questions.toSet().take(2).join('\n')}',
          replacement: action,
          replaceStep: selected.id,
          intent: AgentIntent.modifyMission,
        );
      }
      uncertain.add(Uncertainty.target);
      questions.add(s.step);
      return result(s.step, intent: AgentIntent.modifyMission);
    }
    if (edit && hasGoal) {
      return result(
        s.choose(
          'Use the goal editor for existing goal changes.',
          'Buksan ang goal editor para baguhin ang kasalukuyang goal.',
        ),
        intent: AgentIntent.editGoalDraft,
        unsupported: true,
      );
    }
    if (task && edit) {
      return result(
        s.choose(
          'Open Planner to choose the tasks to organize. Existing tasks are never moved automatically.',
          'Buksan ang Planner at piliin ang mga gawaing aayusin. Walang awtomatikong pagbabago.',
        ),
        intent: AgentIntent.taskPlanning,
      );
    }
    final actions = <AgentAction>[];
    if (object == SemanticObject.mission &&
        actionText.isNotEmpty &&
        !_isReferenceCommand(command)) {
      intents.add(AgentIntent.missionPlanning);
      slots['missionTitle'] = title.value;
      if (title.present) {
        titleBindings.add(TitleBinding(SemanticObject.mission, title));
      } else {
        questions.add(
          s.choose(
            'What should I call the mission?',
            'Anong pangalan ng mission?',
          ),
        );
      }
      return result(
        s.draftNotice,
        missionTitle: title.value,
        intent: AgentIntent.missionPlanning,
      );
    }
    if (allocation) {
      intents.add(AgentIntent.allocation);
      actions.add(AllocationDraft(budget: amount, currency: currency));
    }
    if (creatingGoal) {
      intents.add(AgentIntent.createGoalDraft);
      final name = title.value;
      slots['goalName'] = name;
      slots['title'] = name;
      slots['titleSource'] = title.origin.identifier;
      slots['purpose'] = title.purpose;
      if (title.present) {
        titleBindings.add(
          TitleBinding(SemanticObject.goal, title, actionIndex: actions.length),
        );
      }
      final goalCurrency = currency.isEmpty && !money.currencyAmbiguous
          ? defaultCurrency
          : currency;
      slots['currency'] = goalCurrency;
      actions.add(
        GoalDraft(
          name: name,
          amount: amount,
          currency: goalCurrency,
          deadline: date,
        ),
      );
      if (scenario ||
          RegExp(r'\b(weekly plan|plan contributions|lingguhan)\b')
              .hasMatch(actionText)) {
        actions.add(
          ScenarioDraft(target: amount, currency: currency, deadline: date),
        );
      }
    }
    if (task) {
      intents.add(AgentIntent.taskPlanning);
      final countMatch = RegExp(
        r'\b([1-6]|one|two|three|four|five|six|tatlo)\s+(?:\w+\s+)?tasks?\b',
      ).firstMatch(actionText);
      const counts = {
        'one': 1,
        'two': 2,
        'three': 3,
        'four': 4,
        'five': 5,
        'six': 6,
        'tatlo': 3,
      };
      final count = countMatch == null
          ? 1
          : int.tryParse(countMatch[1]!) ?? counts[countMatch[1]] ?? 1;
      final taskCount = listedTasks.isEmpty ? count : listedTasks.length;
      for (var i = 0; i < taskCount; i++) {
        actions.add(
          TaskDraft(
            title: listedTasks.isNotEmpty
                ? listedTasks[i].value
                : count > 1
                ? ''
                : title.value,
            day: date,
            time: time,
            priority:
                RegExp(r'\b(high priority|priority high|urgent|mataas)\b')
                    .hasMatch(actionText)
                ? 'High'
                : RegExp(r'\b(low priority|priority low|mababa)\b')
                      .hasMatch(actionText)
                ? 'Low'
                : 'Normal',
          ),
        );
      }
      if (listedTasks.isNotEmpty) {
        for (var i = 0; i < listedTasks.length; i++) {
          titleBindings.add(
            TitleBinding(
              SemanticObject.task,
              listedTasks[i],
              actionIndex: actions.length - listedTasks.length + i,
            ),
          );
        }
      } else if (title.present) {
        titleBindings.add(
          TitleBinding(
            SemanticObject.task,
            title,
            actionIndex: actions.length - 1,
          ),
        );
      }
    }
    if (reminder) {
      intents.add(AgentIntent.reminderPlanning);
      final parent = actions.indexWhere(
        (a) => a is GoalDraft || a is TaskDraft,
      );
      final targetKind = parent >= 0 && actions[parent] is TaskDraft
          ? 'task'
          : 'personalGoal';
      final matches = const GoalReferenceResolver().matches(
        title.evidence == null ? input : semantic.mask([title.evidence!]),
        goals,
      );
      if (matches.length > 1) {
        uncertain.add(Uncertainty.target);
        questions.add(s.goal);
      }
      actions.add(
        ReminderDraft(
          title: title.value,
          targetStep: parent < 0 ? '' : 'step_${parent + 1}',
          targetId: parent < 0 && matches.length == 1 ? matches.single.id : '',
          targetKind: targetKind,
          frequency: calendar.unsupportedRecurrence
              ? ''
              : calendar.frequency.isNotEmpty
              ? calendar.frequency
              : date != null || calendar.ambiguousDate
              ? 'once'
              : weekday != null
              ? 'weekly'
              : '',
          weekday: weekday,
          time: time,
          day: date,
        ),
      );
      if (title.present) {
        titleBindings.add(
          TitleBinding(
            SemanticObject.reminder,
            title,
            actionIndex: actions.length - 1,
          ),
        );
      }
    }
    if (contribution) {
      intents.add(AgentIntent.prepareContribution);
      final matches = const GoalReferenceResolver().matches(input, goals);
      if (matches.length > 1) uncertain.add(Uncertainty.target);
      final selected = matches.length == 1 ? matches.single : null;
      actions.add(
        ContributionDraft(
          goalId: selected?.id ?? '',
          amount: amount,
          currency: currency.isNotEmpty ? currency : selected?.currency ?? '',
        ),
      );
    }
    if (scenario && !creatingGoal && !allocation) {
      intents.add(AgentIntent.simulateSavings);
      final roles = const FinancialRoleResolver().resolve(roleText, money);
      if (roles.resolved) {
        uncertain.remove(Uncertainty.amount);
        questions.remove(s.amount);
      }
      final reference = const GoalReferenceResolver().matches(
        object == SemanticObject.scenario && title.evidence != null
            ? semantic.mask([title.evidence!])
            : input,
        goals,
      );
      if (reference.length > 1) {
        uncertain.add(Uncertainty.target);
        questions.add(s.goal);
      }
      final baseline = reference.length == 1 ? reference.single : null;
      final contributionRole =
          !RegExp(r'\b(target|worth|budget)\b').hasMatch(actionText) &&
          RegExp(
            r'\b(save|saving|put|add|magtabi|mag-ipon|daily|weekly|monthly|week|month|every|per)\b',
          ).hasMatch(actionText);
      if (baseline != null &&
          currency.isNotEmpty &&
          currency != baseline.currency) {
        uncertain.add(Uncertainty.currency);
        questions.add(s.currency);
      }
      final contributions = roles.resolved && roles.contributions.isNotEmpty
          ? roles.contributions
          : [contributionRole ? amount : ''];
      for (final contribution in contributions) {
        actions.add(
          ScenarioDraft(
            title: title.value,
            frequency: const ContributionPeriodResolver().resolve(actionText),
            target: roles.resolved && roles.target.isNotEmpty
                ? roles.target
                : contributionRole
                ? baseline?.target ?? ''
                : amount.isNotEmpty
                ? amount
                : baseline?.target ?? '',
            saved: roles.resolved && roles.saved.isNotEmpty
                ? roles.saved
                : baseline?.saved ?? '0',
            contribution: contribution,
            currency: currency.isNotEmpty
                ? currency
                : baseline?.currency ?? defaultCurrency,
            deadline: calendar.ambiguousDate
                ? null
                : date ?? baseline?.deadline,
          ),
        );
      }
      if (title.present) {
        titleBindings.add(
          TitleBinding(
            SemanticObject.scenario,
            title,
            actionIndex: actions.length - 1,
          ),
        );
      }
    }
    if (actions.isNotEmpty) {
      for (final a in actions) {
        questions.addAll(_missingQuestions(a, s));
      }
      return result(
        '${s.draftNotice}\n${questions.toSet().take(2).join('\n')}',
        actions: actions,
      );
    }
    if (negated.isNotEmpty) {
      return result(
        s.choose(
          'Nothing will be saved. You can keep planning or change the draft.',
          'Walang ise-save. Puwede munang magplano o baguhin ang draft.',
        ),
        intent: AgentIntent.modifyMission,
      );
    }
    return result(
      s.choose(
        'I can draft a savings goal, task, reminder, contribution, savings scenario, or allocation. Include a currency and exact date when relevant. For general questions, open Ask Anything.',
        'Maaari akong maghanda ng goal, gawain, paalala, dagdag ipon, o savings plan. Ano ang gusto mong gawin?',
      ),
      unsupported: true,
    );
  }

  List<String> _missingQuestions(AgentAction a, AgentStrings s) {
    final m = a.toJson();
    return [
      if (a is GoalDraft && a.name.isEmpty)
        s.choose(
          'What should the goal be called?',
          'Ano ang pangalan ng goal?',
        ),
      if (a is TaskDraft && a.title.isEmpty)
        s.choose(
          'What should the task be called?',
          'Anong pangalan ng gawain?',
        ),
      if (a is ScenarioDraft && a.target.isEmpty)
        s.choose(
          'What target amount should this scenario use?',
          'Anong target na halaga ang gagamitin sa scenario?',
        ),
      if ((a is GoalDraft || a is ContributionDraft) && m['amount'] == '')
        s.amount,
      if (m.containsKey('currency') && m['currency'] == '') s.currency,
      if (a is GoalDraft && a.deadline == null ||
          a is TaskDraft && a.day == null)
        s.date,
      if (a is ReminderDraft && a.time.isEmpty) s.time,
      if (a is ContributionDraft && a.goalId.isEmpty ||
          a is ReminderDraft && a.targetId.isEmpty && a.targetStep.isEmpty)
        s.goal,
    ];
  }

  /// Bind a creation verb to its object. Mentioning a goal as the target of a
  /// reminder/task does not ask for a new goal.
  bool _createsGoal(String text) {
    final otherObject = RegExp(
      r'\b(task|tasks|remind|reminder|paalala|gawain|activity|to-do|to do|alarm)\b',
    );
    for (final clause in text.split(RegExp(r',|\b(?:tapos|then|and)\b'))) {
      for (final verb in _creationTerms.allMatches(clause)) {
        // Commands inside a task description or referring to a "new goal"
        // still belong to that task/reminder, not an independent goal request.
        if (otherObject.hasMatch(clause.substring(0, verb.start))) continue;
        final tail = clause.substring(verb.start);
        final noun = _goalTerms.firstMatch(tail);
        if (noun == null) continue;
        if (otherObject.hasMatch(tail.substring(0, noun.start))) continue;
        return true;
      }
    }
    return false;
  }

  int? _weekday(String text) {
    for (var i = 0; i < DateExpressionParser.days.length; i++) {
      if (DateExpressionParser.days[i].contains(text.toLowerCase())) {
        return i + 1;
      }
    }
    return null;
  }

  bool _isReferenceCommand(String text) => RegExp(
    r'^(?:open|show|view|delete|remove|edit|update|withdraw|take out)\b',
  ).hasMatch(text);

  SemanticObject _objectFor(AgentAction a) => switch (a) {
    GoalDraft() => SemanticObject.goal,
    TaskDraft() => SemanticObject.task,
    ReminderDraft() => SemanticObject.reminder,
    ScenarioDraft() => SemanticObject.scenario,
    _ => SemanticObject.goal,
  };

  List<String> _requiredMissing(AgentAction a) {
    final fields = switch (a) {
      GoalDraft() => ['name', 'amount', 'currency', 'deadline'],
      TaskDraft() => ['title', 'day'],
      ReminderDraft() => [
        'frequency',
        'time',
        if (a.frequency == 'weekly') 'weekday',
        if (a.frequency == 'once') 'day',
        if (a.targetId.isEmpty && a.targetStep.isEmpty) 'targetId',
      ],
      ContributionDraft() => ['goalId', 'amount', 'currency'],
      ScenarioDraft() => ['target', 'currency'],
      AllocationDraft() => ['budget', 'currency'],
    };
    final values = a.toJson();
    return fields.where((f) => values[f] == null || values[f] == '').toList();
  }
}
