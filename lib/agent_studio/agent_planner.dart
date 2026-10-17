import 'agent_domain.dart';
import 'intelligence/agent_interpretation.dart';
import 'intelligence/agent_language.dart';
import 'intelligence/date_expression_parser.dart';
import 'intelligence/money_expression_parser.dart';

class LocalAgentPlan {
  const LocalAgentPlan(
    this.reply, {
    this.actions = const [],
    this.replacement,
    this.replaceStep,
    this.cancel = false,
    this.interpretation,
  });
  final String reply;
  final List<AgentAction> actions;
  final AgentAction? replacement;
  final String? replaceStep;
  final bool cancel;
  final AgentInterpretation? interpretation;
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
    now ??= DateTime.now();
    final normalized = const MultilingualNormalizer().normalize(input);
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
    final conditional =
        RegExp(r'\b(?:if|kung|kapag|pag|when)\s+')
            .hasMatch(normalized.replaceAll(RegExp(r'"[^"]*"'), '')) &&
        !RegExp(r'\bwhat[ -]if\b').hasMatch(normalized);
    var draftOnly = RegExp(
      r"\b(plan lang|draft only|plan only|not yet|wag muna|huwag muna|huwag pa|don't save|do not save|dont save|maybe|siguro|baka|sana|thinking about|plano ko)\b",
    ).hasMatch(normalized);
    if (draftOnly) negated.add('execute_now');
    LocalAgentPlan result(
      String reply, {
      List<AgentAction> actions = const [],
      AgentAction? replacement,
      String? replaceStep,
      bool cancel = false,
      AgentIntent? intent,
      bool unsupported = false,
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
        for (final entry in a.toJson().entries) {
          if (entry.key != 'type' &&
              (entry.value == null || entry.value == '')) {
            missing.add(entry.key);
          }
        }
      }
      return LocalAgentPlan(
        reply,
        actions: actions,
        replacement: replacement,
        replaceStep: replaceStep,
        cancel: cancel,
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
        ),
      );
    }

    if (RegExp(
      r'\b(actually\s+)?(wag na|huwag na|ayoko na|never mind|nevermind|cancel mission|cancel proposal|kanselahin|i-cancel)\b|^(cancel|stop mission)[.!]?$',
    ).hasMatch(normalized)) {
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
    ).hasMatch(normalized)) {
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
    ).hasMatch(normalized)) {
      return result(
        s.choose(
          'Use Ask Anything for general explanations. Contributions add savings; withdrawals reduce a goal’s balance. Neither happens through a question.',
          'Buksan ang Ask Anything para sa paliwanag. Walang mababago sa ipon dahil sa tanong.',
        ),
        intent: AgentIntent.askQuestion,
      );
    }
    if (RegExp(r'^(cancel|stop|remove|disable)\b').hasMatch(normalized)) {
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
    for (final clause in normalized.split(
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
    var money = const MoneyExpressionParser().parse(normalized);
    var calendar = const DateExpressionParser().parse(normalized, now);
    final correction = RegExp(
      r'\b(?:ay wait|wait actually|actually|sorry|ay hindi|hindi pala|ay|instead)\b\s*[,.:]*\s*',
    ).allMatches(normalized).lastOrNull;
    if (correction != null) {
      final tail = normalized.substring(correction.end);
      final cm = const MoneyExpressionParser().parse(tail);
      final cd = const DateExpressionParser().parse(tail, now);
      if (cm.candidates.isNotEmpty) {
        corrections.add('amount');
        money = MoneyExpression(
          amount: cm.amount,
          currency: cm.currency.isEmpty ? money.currency : cm.currency,
          ambiguous: cm.ambiguous,
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
    if (calendar.unsupportedRecurrence) {
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
    final creatingGoal = !edit && _createsGoal(actionText);
    final task = RegExp(
      r'\b(task|tasks|to-do|to do|activity|organize|organise|planner|study|assignment|gawain|aral)\b',
    ).hasMatch(actionText);
    final reminder = RegExp(
      r'\b(remind|pa-remind|reminder|paalala|ipaalala|alarm)\b',
    ).hasMatch(actionText);
    final allocation = RegExp(r'\b(allocat\w*|split|balance my goals|hatiin)\b')
        .hasMatch(actionText);
    final scenario = RegExp(
      r'\b(simulat\w*|what.if|scenario|weekly plan|savings plan|plan.*savings|plan.*ipon|weekly contributions)\b',
    ).hasMatch(actionText);
    final contribution =
        !creatingGoal &&
        !task &&
        !reminder &&
        !scenario &&
        !allocation &&
        RegExp(
          r'\b(add|pa-add|prepare|deposit|magdagdag|dagdag|dagdagan|magtabi|maghulog|save|saving)\b',
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
        if (a is GoalDraft ||
            a is ContributionDraft ||
            a is ScenarioDraft ||
            a is AllocationDraft) {
          final key = a is ScenarioDraft
              ? 'target'
              : a is AllocationDraft
              ? 'budget'
              : 'amount';
          if (amount.isNotEmpty || money.ambiguous) values[key] = amount;
          if (currency.isNotEmpty || money.currencyAmbiguous) {
            values['currency'] = currency;
          }
        }
        if (a is GoalDraft || a is ScenarioDraft) {
          if (date != null || calendar.ambiguousDate) {
            values['deadline'] = date?.toIso8601String();
          }
        }
        if (a is TaskDraft || a is ReminderDraft) {
          if (date != null || calendar.ambiguousDate) {
            values['day'] = date?.toIso8601String();
          }
          if (time.isNotEmpty || calendar.ambiguousTime) values['time'] = time;
        }
        if (a is ReminderDraft) {
          if (weekday != null) values['weekday'] = weekday;
          if (calendar.frequency.isNotEmpty) {
            values['frequency'] = calendar.frequency;
          } else if (date != null) {
            values['frequency'] = 'once';
          }
        }
        final action = AgentAction.fromJson(values);
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
    if (allocation) {
      intents.add(AgentIntent.allocation);
      actions.add(AllocationDraft(budget: amount, currency: currency));
    }
    if (creatingGoal) {
      intents.add(AgentIntent.createGoalDraft);
      final name = _goalName(input);
      slots['goalName'] = name;
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
        r'\b([1-6]|one|two|three|four|five|six|tatlo)\s+(?:study\s+)?tasks?\b',
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
      for (var i = 0; i < count; i++) {
        actions.add(
          TaskDraft(
            title: count > 1 ? '' : _taskName(input),
            day: date,
            time: time,
            priority: actionText.contains('high priority') ? 'High' : 'Normal',
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
      final matches = const GoalReferenceResolver().matches(input, goals);
      if (matches.length > 1) {
        uncertain.add(Uncertainty.target);
        questions.add(s.goal);
      }
      actions.add(
        ReminderDraft(
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
      final values = money.candidates;
      final paired =
          values.length == 2 &&
          RegExp(r'\bwith\b|\bweekly\b').hasMatch(actionText) &&
          !RegExp(r'\b(or|o)\b').hasMatch(actionText);
      if (paired) {
        uncertain.remove(Uncertainty.amount);
        questions.remove(s.amount);
      }
      actions.add(
        ScenarioDraft(
          target: paired ? values[0].amount : amount,
          contribution: paired ? values[1].amount : '',
          currency: currency,
          deadline: date,
        ),
      );
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

  String _goalName(String text) {
    final quoted = RegExp('["“]([^"”]{1,100})["”]').firstMatch(text);
    if (quoted != null) return quoted[1]!;
    final match = RegExp(
      r'(?:for (?:a |an |my |the )?|para sa (?:bagong )?|goal sa |ipon sa )(.+?)(?=\s+(?:worth|with|target|by|and|tapos|ko|halaga)|[,!.]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    var name = match?[1]?.trim() ?? '';
    if (const MoneyExpressionParser().parse(name).candidates.isNotEmpty) {
      name = '';
    }
    if (name.isEmpty) {
      final m = RegExp(
        r'\b(laptop|phone|motorcycle|motor|emergency|travel|tuition)\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (m != null) name = m[0]!;
    }
    return name.length > 100 ? '' : name;
  }

  String _taskName(String text) {
    if (text.toLowerCase().contains('compare prices')) return 'Compare prices';
    var title = text.replaceFirst(
      RegExp(
        r'^.*?(?:task(?: called| to)?|gawain(?: na)?|remind me to)\s+',
        caseSensitive: false,
      ),
      '',
    );
    title = title
        .replaceFirst(
          RegExp(
            r'\s+(?:tomorrow|today|bukas|ngayon|on 20\d\d|by 20\d\d|at \d|tapos|and remind).*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return title.length <= 100 &&
            !RegExp(
              r'^(organize|organise|plan my|ayusin|yung task)',
              caseSensitive: false,
            ).hasMatch(title)
        ? title
        : '';
  }
}
