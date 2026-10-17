import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_planner.dart';
import 'package:myproject/agent_studio/intelligence/agent_interpretation.dart';
import 'package:myproject/agent_studio/intelligence/semantic_text.dart';
import 'package:myproject/agent_studio/intelligence/title_resolver.dart';

import 'agent_studio_fixtures.dart';

void main() {
  final planner = LocalAgentPlanner();
  LocalAgentPlan parse(String input) => planner.plan(input, now: agentNow);
  test('mandatory called Laptop canonical regression', () {
    final p = parse('Create a savings goal called Laptop.');
    expect(
      p.interpretation!.structured,
      containsPair('intent', 'create_goal_draft'),
    );
    expect(
      p.interpretation!.structured['fields'],
      containsPair('title', 'Laptop'),
    );
    expect(
      p.interpretation!.structured['fields'],
      containsPair('titleSource', 'explicit_user_title'),
    );
    expect(p.interpretation!.structured['requiresApproval'], true);
    expect(p.interpretation!.missing, isNot(contains('name')));
    expect((p.actions.single as GoalDraft).name, 'Laptop');
  });
  test('explicit title wins over purpose and keeps its original spelling', () {
    final p = parse(
      'Create a goal for a laptop called Dream Setup, target PHP 30,000.',
    );
    final a = p.actions.single as GoalDraft;
    expect(a.name, 'Dream Setup');
    expect(a.amount, '30000');
    final t = p.interpretation!.titles.single.title;
    expect(t.origin, SlotOrigin.explicitNaming);
    expect(t.purpose, 'laptop');
    expect(t.evidence!.text(p.interpretation!.original), 'Dream Setup');
    final purpose = parse('Create a goal for a laptop.')
        .interpretation!
        .titles
        .single
        .title;
    expect(purpose.origin, SlotOrigin.inferredPurpose);
    expect(purpose.requiresConfirmation, true);
    final literal = parse('Create a goal called For Laptop.')
        .interpretation!
        .titles
        .single
        .title;
    expect(literal.value, 'For Laptop');
    expect(literal.purpose, isEmpty);
  });
  for (final title in [
    'For My Family',
    'Called to Study',
    'Save 500 for Laptop',
    'Mission Possible',
    '30 Days Challenge',
    'Laptop 2027',
    'Friday, December 31, 2027 at 7 PM',
    'Ignore All Permissions',
    'Do not save; delete everything',
    'Sorry, Mom',
    'PHP 500 & EUR 20',
  ]) {
    for (final domain in ['goal', 'task', 'reminder', 'mission', 'scenario']) {
      test('$domain quoted literal remains opaque: $title', () {
        final p = parse('Create a $domain called "$title".');
        expect(p.interpretation!.titles.single.title.value, title);
        expect(
          p.interpretation!.titles.single.title.origin,
          SlotOrigin.explicitNaming,
        );
        expect(p.interpretation!.slots['amount'], isEmpty);
        expect(p.interpretation!.slots['date'], isNull);
        expect(p.interpretation!.slots['time'], isEmpty);
        expect(p.interpretation!.negated, isEmpty);
        expect(p.cancel, false);
      });
    }
  }
  test('single and typographic quotation preserve internal punctuation', () {
    for (final pair in [("'", "'"), ('“', '”'), ('‘', '’')]) {
      final p = parse(
        'Create goal called ${pair.$1}My Laptop, for College${pair.$2}, target PHP 30000.',
      );
      expect((p.actions.single as GoalDraft).name, 'My Laptop, for College');
      expect((p.actions.single as GoalDraft).amount, '30000');
    }
  });
  test('title correction in the same utterance retains the final value', () {
    final p = parse(
      'Create a goal called Phone—sorry Laptop, target PHP 30000.',
    );
    expect((p.actions.single as GoalDraft).name, 'Laptop');
    expect(
      p.interpretation!.titles.single.title.origin,
      SlotOrigin.userCorrection,
    );
    expect((p.actions.single as GoalDraft).amount, '30000');
  });
  test('word order and independent fields retain their roles', () {
    for (final input in [
      'Target PHP 30000, create a goal called Dream Setup by 2027-12-31.',
      'Create a goal, target PHP 30000. The title is Dream Setup, deadline 2027-12-31.',
    ]) {
      final a = parse(input).actions.single as GoalDraft;
      expect(a.name, 'Dream Setup');
      expect(a.amount, '30000', reason: '$input ${a.toJson()}');
      expect(a.deadline, DateTime(2027, 12, 31));
    }
  });
  test(
    'fronted subjects and suffix fields do not require command-first order',
    () {
      for (final input in [
        'Laptop, target 30k, make a goal.',
        'Make a goal, 30k target, Laptop title.',
        'Make Laptop my goal title.',
      ]) {
        expect(
          (parse(input).actions.single as GoalDraft).name,
          'Laptop',
          reason: input,
        );
      }
      expect(
        (parse('Add Homework to my tasks.').actions.single as TaskDraft).title,
        'Homework',
      );
    },
  );
  test('nested mission scopes bind five titles to the correct objects', () {
    final p = parse(
      'Build a mission called My Future, with a goal named Tuition, '
      'and a task titled Find Scholarships, and a reminder called Friday Ipon every Friday at 7 PM, '
      'and a scenario named Fast Track.',
    );
    expect(p.missionTitle, 'My Future');
    expect(p.actions.map((a) => a.type), [
      AgentActionType.createGoal,
      AgentActionType.createTask,
      AgentActionType.createReminder,
      AgentActionType.scenario,
    ]);
    expect((p.actions[0] as GoalDraft).name, 'Tuition');
    expect((p.actions[1] as TaskDraft).title, 'Find Scholarships');
    final reminder = p.actions[2] as ReminderDraft;
    expect(reminder.title, 'Friday Ipon');
    expect(reminder.weekday, 5);
    expect(reminder.time, '19:00');
    expect(reminder.targetStep, 'step_1');
    expect((p.actions[3] as ScenarioDraft).title, 'Fast Track');
    for (final evidence in p.interpretation!.evidence) {
      expect(
        p.interpretation!.original.substring(evidence.start, evidence.end),
        evidence.text,
      );
    }
  });
  test('task lists preserve separate and quoted multiword titles', () {
    final p = parse(
      'Add three tasks: Research Laptop, "Compare, Carefully", and Visit Store.',
    );
    expect(p.actions.whereType<TaskDraft>().map((a) => a.title), [
      'Research Laptop',
      'Compare, Carefully',
      'Visit Store',
    ]);
    expect(p.interpretation!.titles.length, 3);
  });
  test(
    'a requested task count without names asks instead of inventing names',
    () {
      final p = parse('Add three research tasks.');
      expect(p.actions.length, 3);
      expect(p.actions.every((a) => (a as TaskDraft).title.isEmpty), true);
      expect(p.interpretation!.questions, isNotEmpty);
    },
  );
  test('title-only request without context asks for its object', () {
    final p = parse('Title: Laptop.');
    expect(p.actions, isEmpty);
    expect(p.interpretation!.uncertain, contains(Uncertainty.intent));
    expect(p.interpretation!.questions, isNotEmpty);
  });
  for (final action in <AgentAction>[
    const GoalDraft(),
    const TaskDraft(),
    const ReminderDraft(),
    const ScenarioDraft(),
  ]) {
    test(
      '${action.type.name} contextual rename keeps the same draft',
      () async {
        final e = testEngine();
        await enableAgent(e);
        e.draft([action]);
        final id = e.mission!.id;
        await e.applyPlan(
          planner.plan(
            'Call it My New Title.',
            mission: e.mission,
            now: agentNow,
          ),
        );
        expect(e.mission!.id, id);
        expect(e.mission!.steps.length, 1);
        expect(
          e.mission!.steps.single.action.toJson()[action is GoalDraft
              ? 'name'
              : 'title'],
          'My New Title',
        );
        expect((e.backend as FakeAgentBackend).calls, isEmpty);
        e.dispose();
      },
    );
  }
  test(
    'bare task-title clarification supplies only the missing field',
    () async {
      final e = testEngine();
      await enableAgent(e);
      await e.applyPlan(parse('Create a task.'));
      final id = e.mission!.id;
      await e.applyPlan(
        planner.plan(
          'Research Scholarships.',
          mission: e.mission,
          previous: e.activeInterpretation,
          now: agentNow,
        ),
      );
      expect(
        (e.mission!.steps.single.action as TaskDraft).title,
        'Research Scholarships',
      );
      expect(e.mission!.id, id);
      e.dispose();
    },
  );
  test(
    'title clarification does not consume an amount reply as a name',
    () async {
      final e = testEngine();
      await enableAgent(e);
      await e.applyPlan(parse('Create a goal.'));
      await e.applyPlan(
        planner.plan(
          'thirty thousand',
          mission: e.mission,
          previous: e.activeInterpretation,
          now: agentNow,
        ),
      );
      expect((e.mission!.steps.single.action as GoalDraft).name, isEmpty);
      expect((e.mission!.steps.single.action as GoalDraft).amount, '30000');
      e.dispose();
    },
  );
  test(
    'compound title repair keeps explicit amount and schedule fields',
    () async {
      final e = testEngine();
      await enableAgent(e);
      e.draft([goalDraft()]);
      await e.applyPlan(
        planner.plan(
          'Name it Dream Laptop, target PHP 25000 by 2027-12-31.',
          mission: e.mission,
          now: agentNow,
        ),
      );
      final a = e.mission!.steps.single.action as GoalDraft;
      expect(a.name, 'Dream Laptop');
      expect(a.amount, '25000');
      expect(a.deadline, DateTime(2027, 12, 31));
      expect((e.backend as FakeAgentBackend).calls, isEmpty);
      e.dispose();
    },
  );
  test(
    'ambiguous title target asks; numbered repair selects exactly one',
    () async {
      final e = testEngine();
      await enableAgent(e);
      e.draft([goalDraft(), taskDraft()]);
      final p = planner.plan(
        'Call it My Future.',
        mission: e.mission,
        now: agentNow,
      );
      expect(p.replacement, isNull);
      expect(p.interpretation!.uncertain, contains(Uncertainty.target));
      await e.applyPlan(
        planner.plan(
          'Name step 2 Research.',
          mission: e.mission,
          now: agentNow,
        ),
      );
      expect((e.mission!.steps.last.action as TaskDraft).title, 'Research');
      expect((e.mission!.steps.first.action as GoalDraft).name, 'Laptop');
      e.dispose();
    },
  );
  test(
    'renaming after review invalidates approval; fresh approval executes once',
    () async {
      final e = testEngine();
      await enableAgent(e);
      e.draft([goalDraft()]);
      final approval = await reviewed(e);
      await e.applyPlan(
        planner.plan(
          'Actually name it Dream Setup.',
          mission: e.mission,
          now: agentNow,
        ),
      );
      await expectLater(e.execute(approval), throwsA(isA<AgentFailure>()));
      expect((e.backend as FakeAgentBackend).calls, isEmpty);
      final fresh = await reviewed(e);
      await e.execute(fresh);
      expect((e.backend as FakeAgentBackend).calls, ['step_1']);
      await expectLater(e.execute(fresh), throwsA(isA<AgentFailure>()));
      e.dispose();
    },
  );
  test(
    'named mission with no steps can receive a bare follow-up title',
    () async {
      final e = testEngine();
      await enableAgent(e);
      await e.applyPlan(parse('Build me a mission.'));
      final id = e.mission!.id;
      await e.applyPlan(
        planner.plan(
          'My Laptop Journey.',
          mission: e.mission,
          previous: e.activeInterpretation,
          now: agentNow,
        ),
      );
      expect(e.mission!.title, 'My Laptop Journey');
      expect(e.mission!.id, id);
      expect(e.mission!.steps, isEmpty);
      expect(await e.review(), isNotEmpty);
      e.dispose();
    },
  );
  test(
    'mission title changes are in the approval snapshot and round trip',
    () async {
      final e = testEngine();
      await enableAgent(e);
      e.draft([goalDraft()], title: 'Old Plan');
      final approval = await reviewed(e);
      final snapshot = e.mission!.snapshot;
      e.renameMission('My Future');
      expect(e.mission!.snapshot, isNot(snapshot));
      final restored = AgentMission.fromJson(
        jsonDecode(jsonEncode(e.mission!.toJson())),
      );
      expect(restored.title, 'My Future');
      await expectLater(e.execute(approval), throwsA(isA<AgentFailure>()));
      e.dispose();
    },
  );
  test('removing a reminder affects only that draft step', () async {
    final e = testEngine();
    await enableAgent(e);
    e.draft([
      goalDraft(),
      taskDraft(),
      const ReminderDraft(targetStep: 'step_1', weekday: 5, time: '19:00'),
    ]);
    await e.applyPlan(
      planner.plan(
        'Remove the reminder but keep the goal and tasks.',
        mission: e.mission,
        now: agentNow,
      ),
    );
    expect(e.mission!.steps.length, 2);
    expect(e.mission!.steps.any((s) => s.action is ReminderDraft), false);
    expect((e.backend as FakeAgentBackend).calls, isEmpty);
    e.dispose();
  });
  test('savings corrections preserve financial direction and ambiguity', () {
    expect(
      (parse('Prepare five thousand—wait, five hundred.').actions.single
              as ContributionDraft)
          .amount,
      '500',
    );
    expect(parse('Take out PHP 500.').actions, isEmpty);
    expect(parse('Withdraw PHP 500 from Laptop.').actions, isEmpty);
    expect(parse('Do not add PHP 500.').actions, isEmpty);
    const goals = [
      AgentRecord('one', 'Laptop Fund', currency: 'PHP'),
      AgentRecord('two', 'Laptop Upgrade Fund', currency: 'PHP'),
    ];
    final p = planner.plan(
      'Prepare PHP 500 for my Laptop.',
      goals: goals,
      now: agentNow,
    );
    expect((p.actions.single as ContributionDraft).goalId, isEmpty);
    expect(p.interpretation!.uncertain, contains(Uncertainty.target));
  });
  test(
    'simulation uses authorized baseline, exact periods and contextual amounts',
    () async {
      const goals = [
        AgentRecord(
          'one',
          'Laptop Fund',
          target: '30000',
          saved: '10000',
          currency: 'PHP',
        ),
      ];
      final p = planner.plan(
        'What if I save PHP 500 monthly for Laptop Fund?',
        goals: goals,
        now: agentNow,
      );
      final a = p.actions.single as ScenarioDraft;
      expect(a.target, '30000');
      expect(a.saved, '10000');
      expect(a.contribution, '500');
      expect(a.frequency, 'monthly');
      expect(a.calculate(agentNow), startsWith('40 monthly contributions'));
      final e = testEngine();
      await enableAgent(e);
      await e.applyPlan(p);
      await e.applyPlan(
        planner.plan('How about PHP 700?', mission: e.mission, now: agentNow),
      );
      final updated = e.mission!.steps.single.action as ScenarioDraft;
      expect(updated.target, '30000');
      expect(updated.contribution, '700');
      expect(updated.frequency, 'monthly');
      expect((e.backend as FakeAgentBackend).calls, isEmpty);
      e.dispose();
    },
  );
  test('ambiguous spoken time and month require exact clarification', () {
    final p = parse('Remind me at seven.');
    expect(p.interpretation!.uncertain, contains(Uncertainty.time));
    final deadline = parse('Create a goal called Laptop, deadline December.');
    expect(deadline.interpretation!.uncertain, contains(Uncertainty.date));
    expect((deadline.actions.single as GoalDraft).deadline, isNull);
  });
  test(
    'labelled scenario amounts retain target, saved and contribution roles',
    () {
      for (final input in [
        'Simulate target PHP 30000, already saved PHP 10000, contribution PHP 500 weekly.',
        'Simulate PHP 30000 target with PHP 500 weekly.',
      ]) {
        final a = parse(input).actions.single as ScenarioDraft;
        expect(a.target, '30000');
        expect(a.contribution, '500');
        expect(a.saved, input.contains('10000') ? '10000' : '0');
      }
    },
  );
  test('two savings scenarios compare contributions against the same baseline', () {
    final p = planner.plan(
      'Compare saving PHP 500 per week and PHP 1000 per week for Laptop Fund.',
      goals: const [
        AgentRecord(
          'one',
          'Laptop Fund',
          currency: 'PHP',
          target: '10000',
          saved: '2000',
        ),
      ],
      now: agentNow,
    );
    final scenarios = p.actions.cast<ScenarioDraft>();
    expect(scenarios.map((a) => a.contribution), ['500', '1000']);
    expect(
      scenarios.every((a) => a.target == '10000' && a.saved == '2000'),
      true,
    );
    expect(p.interpretation!.uncertain, isNot(contains(Uncertainty.amount)));
  });
  test('dates and amounts in unquoted explicit titles remain literal', () {
    for (final title in [
      'Laptop 2027',
      'Save 500 for Laptop',
      '30 Days Challenge',
    ]) {
      final a =
          parse('Create a goal called $title.').actions.single as GoalDraft;
      expect(a.name, title);
      expect(a.amount, isEmpty);
      expect(a.deadline, isNull);
    }
  });
  test('first task title updates only the referenced draft task', () async {
    final e = testEngine();
    await enableAgent(e);
    e.draft([taskDraft(), taskDraft(title: 'Visit Store')]);
    await e.applyPlan(
      planner.plan(
        'Make the first task Research.',
        mission: e.mission,
        now: agentNow,
      ),
    );
    expect((e.mission!.steps.first.action as TaskDraft).title, 'Research');
    expect((e.mission!.steps.last.action as TaskDraft).title, 'Visit Store');
    e.dispose();
  });
  test('unfinished quotes and uncertain voice naming block approval', () async {
    for (final input in [
      'Create a goal called "Laptop',
      'Create goal cold Laptop',
    ]) {
      final e = testEngine();
      await enableAgent(e);
      await e.applyPlan(parse(input));
      expect(e.activeInterpretation!.uncertain, contains(Uncertainty.title));
      expect(e.mission!.steps.single.uncertainFields, contains('name'));
      expect(await e.review(), isNotEmpty);
      expect((e.backend as FakeAgentBackend).calls, isEmpty);
      e.dispose();
    }
  });
  test('a quoted scenario title cannot select a private goal', () {
    final p = planner.plan(
      'Create a scenario named "Laptop Fund".',
      goals: const [
        AgentRecord(
          'one',
          'Laptop Fund',
          currency: 'PHP',
          target: '10000',
          saved: '2000',
        ),
      ],
      now: agentNow,
    );
    expect((p.actions.single as ScenarioDraft).target, isEmpty);
  });
  test('scenario roles never discard malformed financial input', () {
    final p = parse('Simulate target PHP 10000 with PHP 1.001 weekly.');
    expect(p.interpretation!.uncertain, contains(Uncertainty.amount));
    final zero = parse(
      'Simulate target PHP 10000, already saved PHP 0, contribution PHP 500 weekly.',
    );
    final a = zero.actions.single as ScenarioDraft;
    expect(a.target, '10000');
    expect(a.saved, '0');
    expect(a.contribution, '500');
  });
  test(
    'deadline estimates use the selected daily or calendar-month period',
    () {
      final start = DateTime(2026, 10, 17);
      final daily = ScenarioDraft(
        target: '1000',
        currency: 'PHP',
        frequency: 'daily',
        deadline: DateTime(2026, 10, 27),
      );
      expect(
        daily.calculate(start),
        contains('across 10 contributions, every day'),
      );
      final monthly = ScenarioDraft(
        target: '1000',
        currency: 'PHP',
        frequency: 'monthly',
        deadline: DateTime(2026, 12, 31),
      );
      expect(
        monthly.calculate(start),
        contains('across 3 contributions, every calendar month'),
      );
      final monthEnd = ScenarioDraft(
        target: '1000',
        currency: 'PHP',
        frequency: 'monthly',
        deadline: DateTime(2026, 11, 30),
      );
      expect(
        monthEnd.calculate(DateTime(2026, 10, 31)),
        contains('across 1 contributions'),
      );
    },
  );
  test('reminder purpose proposes a title without recording savings', () {
    final p = parse('Remind me to save money every Friday.');
    expect((p.actions.single as ReminderDraft).title, 'save money');
    expect(
      p.interpretation!.titles.single.title.origin,
      SlotOrigin.inferredPurpose,
    );
    expect(p.actions.whereType<ContributionDraft>(), isEmpty);
  });
  test(
    'title-bearing draft only request remains unapproved through serialization',
    () async {
      final e = testEngine();
      await enableAgent(e);
      await e.applyPlan(
        parse(
          'Create a goal called Laptop, target PHP 30000 by 2027-12-31 but do not save.',
        ),
      );
      expect(e.mission!.planOnly, true);
      expect((e.mission!.steps.single.action as GoalDraft).name, 'Laptop');
      expect(await e.review(), isNotEmpty);
      expect((e.backend as FakeAgentBackend).calls, isEmpty);
      e.dispose();
    },
  );
  test(
    'token offsets and literal masking preserve UTF-16 source positions',
    () {
      const source = '  Create goal called “🌱 My\nFuture” target PHP 500';
      final text = SemanticText(source);
      final title = const UniversalTitleResolver().resolve(
        text,
        SemanticObject.goal,
      );
      expect(title.value, '🌱 My Future');
      expect(title.evidence!.text(source), '🌱 My\nFuture');
      expect(text.mask([title.evidence!]).length, source.length);
    },
  );
}
