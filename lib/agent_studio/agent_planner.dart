import '../currency_money.dart';
import 'agent_domain.dart';

class LocalAgentPlan {
  const LocalAgentPlan(
    this.reply, {
    this.actions = const [],
    this.replacement,
    this.replaceStep,
    this.cancel = false,
  });
  final String reply;
  final List<AgentAction> actions;
  final AgentAction? replacement;
  final String? replaceStep;
  final bool cancel;
}

/// Deterministic command assistance, not a claim of general language fluency.
/// All strings and amounts remain on-device. Unknown/ambiguous fields stay blank.
class LocalAgentPlanner {
  LocalAgentPlan plan(
    String input, {
    AgentMission? mission,
    DateTime? now,
    AgentLanguage language = AgentLanguage.english,
    Map<String, String> memory = const {},
  }) {
    if (input.trim().isEmpty || input.length > AgentLimits.input) {
      throw const AgentFailure('Enter a request up to 3,000 characters.');
    }
    now ??= DateTime.now();
    final text = input.trim(), lower = text.toLowerCase();
    String answer(String en, String fil) =>
        language == AgentLanguage.filipino ? fil : en;
    if (RegExp(r'^(cancel|stop mission|kanselahin)( mission| proposal)?[.!]?$')
        .hasMatch(lower)) {
      return LocalAgentPlan(
        answer(
          'Mission canceled. Completed operations remain in your records.',
          'Kinansela ang mission. Mananatili ang mga natapos na pagbabago.',
        ),
        cancel: true,
      );
    }
    if (RegExp(r'\b(withdraw|delete|decrease|burahin|bawasan)\b')
        .hasMatch(lower)) {
      return const LocalAgentPlan(
        'Use the goal’s existing Delete or Decrease Savings controls. Agent missions do not delete records or withdraw savings.',
      );
    }
    if (RegExp(r'^(yes|approve|approved|do everything|oo|sige|execute)[.!]?$')
        .hasMatch(lower)) {
      return const LocalAgentPlan(
        'Open Review Mission and use its dedicated confirmation button. A chat or spoken approval cannot authorize changes.',
      );
    }
    final currency = _currency(text);
    final amount = _amount(text);
    final date = _date(text, now);
    final time = _time(text);
    final weekday =
        _weekday(lower) ??
        (memory['reminderDay'] == null
            ? null
            : _weekday(memory['reminderDay']!.toLowerCase()));
    final creatingGoal =
        RegExp(r'\b(goal|save for|ipon para|mag.ipon para)\b')
            .hasMatch(lower) &&
        RegExp(
          r'\b(create|new|make|help|gawa|bagong|save for|ipon para|mag.ipon)\b',
        ).hasMatch(lower);
    final task = RegExp(
      r'\b(task|tasks|organize|organise|planner|study|assignment|gawain|aral)\b',
    ).hasMatch(lower);
    final reminder = RegExp(r'\b(remind|reminder|paalala|ipaalala)\b')
        .hasMatch(lower);
    final contribution =
        RegExp(r'\b(add|prepare|deposit|magdagdag|dagdag)\b').hasMatch(lower) &&
        !creatingGoal &&
        !task &&
        !reminder;
    final scenario = RegExp(
      r'\b(simulat\w*|what.if|scenario|weekly plan|savings plan|weekly contributions)\b',
    ).hasMatch(lower);
    final allocation = RegExp(r'\b(allocat\w*|split|balance my goals|hatiin)\b')
        .hasMatch(lower);

    // Follow-up values update one explicit/missing field, never execute it.
    if (mission != null &&
        !creatingGoal &&
        !contribution &&
        !allocation &&
        (!task || lower.startsWith('change')) &&
        (!reminder || lower.startsWith('change'))) {
      final stepNumber = RegExp(r'(?:step|hakbang)\s+(\d+)').firstMatch(lower);
      final candidates = mission.steps
          .where((s) => s.selected && !s.done && s.attempts == 0)
          .toList();
      AgentStep? selected;
      if (stepNumber != null) {
        final n = int.parse(stepNumber[1]!);
        if (n > 0 && n <= mission.steps.length) selected = mission.steps[n - 1];
      } else {
        selected = candidates
            .where((s) => s.action.validate(now!).isNotEmpty)
            .firstOrNull;
        if (lower.startsWith('change') || lower.startsWith('make the')) {
          selected = candidates.length == 1 ? candidates.first : selected;
        }
      }
      if (selected != null &&
          (date != null ||
              time.isNotEmpty ||
              amount.isNotEmpty ||
              currency.isNotEmpty ||
              weekday != null)) {
        final a = selected.action;
        final m = a.toJson();
        if (a is GoalDraft) {
          if (amount.isNotEmpty) m['amount'] = amount;
          if (currency.isNotEmpty) m['currency'] = currency;
          if (date != null) m['deadline'] = date.toIso8601String();
        } else if (a is TaskDraft) {
          if (date != null) m['day'] = date.toIso8601String();
          if (time.isNotEmpty) m['time'] = time;
        } else if (a is ReminderDraft) {
          if (time.isNotEmpty) m['time'] = time;
          if (weekday != null) m['weekday'] = weekday;
          if (date != null) {
            m['day'] = date.toIso8601String();
            m['frequency'] = 'once';
          }
        } else if (a is ScenarioDraft) {
          if (amount.isNotEmpty) m['target'] = amount;
          if (currency.isNotEmpty) m['currency'] = currency;
          if (date != null) m['deadline'] = date.toIso8601String();
        }
        return LocalAgentPlan(
          answer(
            'Updated the draft. Review its values before approval.',
            'Na-update ang draft. Suriin ang mga detalye bago aprubahan.',
          ),
          replacement: AgentAction.fromJson(m),
          replaceStep: selected.id,
        );
      }
      if (RegExp(r'\b(change|instead|it|amount|deadline)\b').hasMatch(lower) &&
          candidates.length > 1) {
        return const LocalAgentPlan(
          'Which step should change? Use “step 1”, “step 2”, or edit a card.',
        );
      }
    }

    final actions = <AgentAction>[];
    if (allocation) {
      actions.add(AllocationDraft(budget: amount, currency: currency));
    }
    if (creatingGoal) {
      actions.add(
        GoalDraft(
          name: _goalName(text),
          amount: amount,
          currency: currency,
          deadline: date,
        ),
      );
      if (scenario ||
          RegExp(r'\b(weekly|contributions|plan contributions|linggo)\b')
              .hasMatch(lower)) {
        actions.add(
          ScenarioDraft(target: amount, currency: currency, deadline: date),
        );
      }
    }
    if (task) {
      final countMatch = RegExp(
        r'\b([1-6]|one|two|three|four|five|six|tatlo)\s+(?:study\s+)?tasks?\b',
      ).firstMatch(lower);
      final counts = {
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
        String title = count > 1 ? '' : _taskName(text);
        if (lower.contains('compare prices')) {
          title = count > 1
              ? [
                  'Compare prices',
                  'Compare product specifications',
                  'Review the purchase budget',
                ][i % 3]
              : 'Compare prices';
        }
        actions.add(
          TaskDraft(
            title: title,
            day: date,
            time: time,
            priority: lower.contains('high priority') ? 'High' : 'Normal',
          ),
        );
      }
    }
    if (reminder) {
      final parent = actions.indexWhere(
        (a) => a is GoalDraft || a is TaskDraft,
      );
      final targetKind = parent >= 0 && actions[parent] is TaskDraft
          ? 'task'
          : 'personalGoal';
      actions.add(
        ReminderDraft(
          targetStep: parent < 0 ? '' : 'step_${parent + 1}',
          targetKind: targetKind,
          frequency: targetKind == 'task' || date != null
              ? 'once'
              : lower.contains('daily') || lower.contains('araw-araw')
              ? 'daily'
              : 'weekly',
          weekday: weekday,
          time: time,
          day: date,
        ),
      );
    }
    if (contribution) {
      actions.add(ContributionDraft(amount: amount, currency: currency));
    }
    if (scenario && !creatingGoal && !allocation) {
      final values = _moneyValues(text);
      actions.add(
        ScenarioDraft(
          target: values.firstOrNull ?? '',
          contribution: values.length > 1 ? values[1] : '',
          currency: currency,
          deadline: date,
        ),
      );
    }
    if (actions.isNotEmpty) {
      final missing = actions.expand((a) => a.validate(now!)).toSet();
      final reply = answer(
        'I prepared an editable local proposal. No records have changed.',
        'Naghanda ako ng lokal na draft na puwedeng i-edit. Wala pang nabagong rekord.',
      );
      return LocalAgentPlan(
        '$reply${missing.isEmpty ? ' Open Review Mission when ready.' : '\n${missing.take(3).join('\n')}'}',
        actions: actions,
      );
    }
    if (RegExp(r'\b(progress|goals|reports|organize tomorrow|plan my week)\b')
        .hasMatch(lower)) {
      return const LocalAgentPlan(
        'Use the local progress and Planner shortcuts below, or describe tasks and dates to draft. Existing tasks are never moved automatically.',
      );
    }
    return LocalAgentPlan(
      answer(
        'I can draft a savings goal, task, reminder, contribution, savings scenario, or allocation. Include a currency and exact date when relevant. For general questions, open Ask Anything.',
        'Maaari akong maghanda ng goal, gawain, paalala, kontribusyon, o savings plan. Ilagay ang currency at petsa. Para sa pangkalahatang tanong, buksan ang Ask Anything.',
      ),
    );
  }

  String _currency(String text) {
    for (final code in CurrencyCatalog.byCode.keys) {
      if (RegExp('\\b$code\\b', caseSensitive: false).hasMatch(text)) {
        return code;
      }
    }
    return text.contains('₱') ||
            RegExp(r'\b(pesos?|piso)\b', caseSensitive: false).hasMatch(text)
        ? 'PHP'
        : text.contains('€')
        ? 'EUR'
        : text.contains('£')
        ? 'GBP'
        : '';
  }

  List<String> _moneyValues(String text) => RegExp(
    '(?:₱|€|£|\\b(?:${CurrencyCatalog.byCode.keys.join('|')})\\b\\s*)\\s*([0-9][0-9,]*(?:\\.[0-9]+)?)|([0-9][0-9,]*(?:\\.[0-9]+)?)\\s*(?:pesos?|piso)\\b',
    caseSensitive: false,
  ).allMatches(text).map((m) => (m[1] ?? m[2]!).replaceAll(',', '')).toList();
  String _amount(String text) {
    final values = _moneyValues(text);
    if (values.isNotEmpty) return values.first;
    final m = RegExp(
      r'(?:worth|target|amount|halagang|budget)\s*(?:of\s*)?([0-9][0-9,]*(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    return m?[1]?.replaceAll(',', '') ?? '';
  }

  DateTime? _date(String text, DateTime now) {
    final iso = RegExp(r'\b(20\d\d)-(\d{2})-(\d{2})\b').firstMatch(text);
    if (iso != null) {
      final y = int.parse(iso[1]!),
          m = int.parse(iso[2]!),
          d = int.parse(iso[3]!);
      final result = DateTime(y, m, d);
      return result.year == y && result.month == m && result.day == d
          ? result
          : null;
    }
    final named = RegExp(
      r'\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(20\d\d)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (named != null) {
      const months = [
        'january',
        'february',
        'march',
        'april',
        'may',
        'june',
        'july',
        'august',
        'september',
        'october',
        'november',
        'december',
      ];
      final m = months.indexOf(named[1]!.toLowerCase()) + 1,
          d = int.parse(named[2]!),
          y = int.parse(named[3]!);
      final result = DateTime(y, m, d);
      return result.month == m && result.day == d ? result : null;
    }
    if (RegExp(r'\b(tomorrow|bukas)\b', caseSensitive: false).hasMatch(text)) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    if (RegExp(r'\b(today|ngayon)\b', caseSensitive: false).hasMatch(text)) {
      return DateTime(now.year, now.month, now.day);
    }
    return null;
  }

  String _time(String text) {
    final m = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (m != null) {
      final h = int.parse(m[1]!);
      if (h < 1 || h > 12) return '';
      final hour = h % 12 + (m[3]!.toLowerCase() == 'pm' ? 12 : 0);
      return '${hour.toString().padLeft(2, '0')}:${m[2] ?? '00'}';
    }
    return RegExp(r'\b(?:[01]\d|2[0-3]):[0-5]\d\b').firstMatch(text)?[0] ?? '';
  }

  int? _weekday(String text) {
    const days = [
      ['monday', 'lunes'],
      ['tuesday', 'martes'],
      ['wednesday', 'miyerkules'],
      ['thursday', 'huwebes'],
      ['friday', 'biyernes'],
      ['saturday', 'sabado'],
      ['sunday', 'linggo'],
    ];
    final matches = <int>[];
    for (var i = 0; i < days.length; i++) {
      if (days[i].any((d) => RegExp('\\b$d\\b').hasMatch(text))) {
        matches.add(i + 1);
      }
    }
    return matches.length == 1 ? matches.first : null;
  }

  String _goalName(String text) {
    final quoted = RegExp('["“]([^"”]{1,100})["”]').firstMatch(text);
    if (quoted != null) return quoted[1]!;
    final match = RegExp(
      r'(?:for (?:a |an |my |the )?|para sa (?:bagong )?)(.+?)(?=\s+(?:worth|with|target|by|and|tapos|ko)|[,!.]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    var name = match?[1]?.trim() ?? '';
    if (name.isEmpty) {
      for (final item in [
        'laptop',
        'phone',
        'motorcycle',
        'emergency',
        'travel',
        'tuition',
      ]) {
        if (text.toLowerCase().contains(item)) {
          name = '$item fund';
          break;
        }
      }
    }
    return name.length > 100 ? '' : name;
  }

  String _taskName(String text) {
    var title = text.replaceFirst(
      RegExp(
        r'^.*?(?:task(?: called| to)?|remind me to)\s+',
        caseSensitive: false,
      ),
      '',
    );
    title = title
        .replaceFirst(
          RegExp(
            r'\s+(?:tomorrow|today|bukas|on 20\d\d|by 20\d\d|at \d).*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return title.length <= 100 &&
            !RegExp(
              r'^(organize|organise|plan my)',
              caseSensitive: false,
            ).hasMatch(title)
        ? title
        : '';
  }
}
