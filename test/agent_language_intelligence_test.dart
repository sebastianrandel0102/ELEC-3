import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_planner.dart';
import 'package:myproject/agent_studio/agent_ai_gateway.dart';
import 'package:myproject/agent_studio/agent_voice.dart';
import 'package:myproject/agent_studio/intelligence/agent_interpretation.dart';
import 'package:myproject/agent_studio/intelligence/agent_language.dart';
import 'package:myproject/agent_studio/intelligence/date_expression_parser.dart';
import 'package:myproject/agent_studio/intelligence/money_expression_parser.dart';
import 'package:myproject/agent_studio/intelligence/voice_locale_repository.dart';

import 'agent_studio_fixtures.dart';

void main() {
  final planner = LocalAgentPlanner();
  const money = MoneyExpressionParser(), dates = DateExpressionParser();
  test('a bare weekday repair keeps an existing weekly reminder recurring', () {
    final e = testEngine();
    e.draft([
      const ReminderDraft(
        targetId: 'goalA',
        frequency: 'weekly',
        weekday: 5,
        time: '19:00',
      ),
    ]);
    final p = planner.plan('Saturday', mission: e.mission, now: agentNow);
    final reminder = p.replacement as ReminderDraft;
    expect(reminder.frequency, 'weekly');
    expect(reminder.weekday, 6);
    expect(reminder.day, isNull);
    expect(reminder.time, '19:00');
    final corrected = planner.plan(
      'Remind me every Friday, hindi, Saturday at 7 pm',
      now: agentNow,
    );
    expect((corrected.actions.single as ReminderDraft).weekday, 6);
    expect((corrected.actions.single as ReminderDraft).frequency, 'weekly');
    e.dispose();
  });
  test(
    'a goal-name reply preserves its spelling and the other draft fields',
    () async {
      final e = testEngine();
      await enableAgent(e);
      await e.applyPlan(planner.plan('Create a goal', now: agentNow));
      await e.applyPlan(
        planner.plan(
          'Aking Pangarap',
          mission: e.mission,
          previous: e.activeInterpretation,
          now: agentNow,
        ),
      );
      expect(
        (e.mission!.steps.single.action as GoalDraft).name,
        'Aking Pangarap',
      );
      expect((e.mission!.steps.single.action as GoalDraft).amount, isEmpty);
      e.dispose();
    },
  );
  test('a short step choice repairs the pending field without repeating the request', () async {
    final e = testEngine();
    await enableAgent(e);
    e.draft([goalDraft(), goalDraft(name: 'Phone')]);
    await e.applyPlan(
      planner.plan('Gawin mong 25k', mission: e.mission, now: agentNow),
    );
    expect(e.activeInterpretation!.uncertain, contains(Uncertainty.target));
    final followup = planner.plan(
      'Yung pangalawa',
      mission: e.mission,
      previous: e.activeInterpretation,
      now: agentNow,
    );
    await e.applyPlan(followup);
    expect((e.mission!.steps[0].action as GoalDraft).amount, '30000');
    expect((e.mission!.steps[1].action as GoalDraft).amount, '25000');
    e.edit('step_1', action: goalDraft(amount: '123'));
    expect(e.activeInterpretation, isNull);
    e.dispose();
  });
  test(
    'unrelated step repair cannot clear an uncertain time; exact time can',
    () async {
      final e = testEngine();
      await enableAgent(e);
      await e.applyPlan(
        planner.plan(
          'Create goal for laptop target PHP 500 by 2027-01-31 and add task to compare prices alas siyete',
          now: agentNow,
        ),
      );
      expect(e.mission!.steps.last.uncertainFields, contains('time'));
      e.edit('step_1', action: goalDraft(amount: '600'));
      expect(await e.review(), isNotEmpty);
      await e.applyPlan(
        planner.plan('step 2 at 7 pm', mission: e.mission, now: agentNow),
      );
      expect(e.mission!.steps.last.uncertainFields, isEmpty);
      expect((e.backend as FakeAgentBackend).calls, isEmpty);
      e.dispose();
    },
  );
  test('a negated follow-up pauses a previously valid mission and invalidates approval', () async {
    final e = testEngine();
    await enableAgent(e);
    e.draft([goalDraft()]);
    final approval = await reviewed(e);
    await e.applyPlan(
      planner.plan(
        'Do not create that goal',
        mission: e.mission,
        now: agentNow,
      ),
    );
    expect(e.mission!.planOnly, true);
    expect(await e.review(), isNotEmpty);
    await expectLater(e.execute(approval), throwsA(isA<AgentFailure>()));
    expect((e.backend as FakeAgentBackend).calls, isEmpty);
    e.dispose();
  });
  test('corrected amount evidence points into original input and named dates are not amounts', () {
    const input = 'Add PHP 500, sorry 200 lang';
    final evidence = planner
        .plan(input, now: agentNow)
        .interpretation!
        .evidence
        .single;
    expect(input.substring(evidence.start, evidence.end), '200');
    expect(money.parse('target PHP 500 by 31 Disyembre 2026').amount, '500');
    expect(money.parse('1.500').ambiguous, true);
    expect(planner.plan('Cancel my reminder', now: agentNow).actions, isEmpty);
    expect(planner.plan('Never add PHP 500', now: agentNow).actions, isEmpty);
  });
  test('short replies preserve session language and explicit preferences persist independently', () {
    const detector = AgentLanguageDetector();
    expect(
      detector.detect('Okay.', previous: AgentLanguage.filipino),
      AgentLanguage.filipino,
    );
    expect(detector.detect('25k'), AgentLanguage.automatic);
    expect(detector.detect('Gawa goal para sa laptop'), AgentLanguage.taglish);
    expect(detector.detect('Gusto ko ng ipon'), AgentLanguage.filipino);
    expect(detector.detect('Create a savings goal'), AgentLanguage.english);
    final settings = AgentSettings(
      language: AgentLanguage.taglish,
      interfaceLanguage: AgentLanguage.filipino,
      speechLanguage: AgentLanguage.english,
      ttsLocale: 'fil-PH',
      locale: 'en-PH',
      execute: true,
    );
    final restored = AgentSettings.fromJson(
      jsonDecode(jsonEncode(settings.toJson())),
    );
    expect(restored.language, AgentLanguage.taglish);
    expect(restored.interfaceLanguage, AgentLanguage.filipino);
    expect(restored.locale, 'en-PH');
    expect(restored.ttsLocale, 'fil-PH');
    expect(restored.execute, true);
    expect(
      AgentSettings.fromJson({'language': 'filipino', 'locale': 'tl-PH'})
          .language,
      AgentLanguage.filipino,
    );
    expect(AgentSettings().language, AgentLanguage.automatic);
  });
  test('normalization preserves signs, negation, corrections, names and raw utterance', () {
    const raw = '  Huwag\u00a0 i-save ₱-500.50 — “Aking Goal”  ';
    final result = planner.plan(raw, now: agentNow).interpretation!;
    expect(result.original, raw);
    expect(result.normalized, contains('huwag'));
    expect(result.normalized, contains('-500.50'));
    expect(result.normalized, contains('aking goal'));
    expect(result.draftOnly, true);
  });
  final amounts = {
    'isa': '1',
    'dalawa': '2',
    'tatlo': '3',
    'apat': '4',
    'lima': '5',
    'sampu': '10',
    'dalawampu': '20',
    'limampu': '50',
    'isang daan': '100',
    'limang daang piso': '500',
    'isang libo': '1000',
    'sampung libo': '10000',
    'dalawampung libo': '20000',
    "dalawang libo't limang daan": '2500',
    'two thousand five hundred': '2500',
    'five hundred pesos': '500',
    '₱2.5k': '2500',
    '1.5 million': '1500000',
    'PHP 1,500.50': '1500.50',
  };
  for (final e in amounts.entries) {
    test('exact financial number: ${e.key}', () {
      expect(money.parse(e.key).amount, e.value);
    });
  }
  for (final text in [
    'PHP -500',
    'one fifty',
    'one five',
    'five hundred or five thousand',
    'mga two',
    'PHP 1.500',
    'PHP 1.001',
    'JPY 1.50',
    'PHP 1,50',
    'PHP 0',
    'PHP 1000000000001',
    'PHP 2.5.0',
    'PHP 500-5000',
  ]) {
    test('ambiguous or invalid money is blank: $text', () {
      expect(money.parse(text).amount, isEmpty);
      expect(money.parse(text).ambiguous, true);
    });
  }
  test(
    'currency conflict and dollar ambiguity do not inherit default currency',
    () {
      expect(money.parse(r'$500').currencyAmbiguous, true);
      expect(money.parse('PHP 500 USD').currencyAmbiguous, true);
      final plan = planner.plan(
        r'Create goal for laptop target $500',
        defaultCurrency: 'PHP',
        now: agentNow,
      );
      expect((plan.actions.single as GoalDraft).currency, isEmpty);
      expect(
        (planner
                    .plan(
                      'Create goal for laptop target 500',
                      defaultCurrency: 'EUR',
                      now: agentNow,
                    )
                    .actions
                    .single
                as GoalDraft)
            .currency,
        'EUR',
      );
    },
  );
  test(
    'date parsing uses supplied local calendar at month and year boundaries',
    () {
      expect(
        dates.parse('bukas', DateTime(2026, 12, 31, 23, 59)).date,
        DateTime(2027, 1, 1),
      );
      expect(
        dates.parse('makalawa', DateTime(2028, 2, 28)).date,
        DateTime(2028, 3, 1),
      );
      expect(
        dates.parse('31 Disyembre 2026', agentNow).date,
        DateTime(2026, 12, 31),
      );
      expect(
        dates.parse('December 31, 2026', agentNow).date,
        DateTime(2026, 12, 31),
      );
      expect(dates.parse('2027-02-31', agentNow).ambiguousDate, true);
      expect(dates.parse('2026-01-01', agentNow).ambiguousDate, true);
      expect(dates.parse('next Friday', agentNow).ambiguousDate, true);
      expect(dates.parse('by December', agentNow).ambiguousDate, true);
      expect(dates.parse('10/11/2026', agentNow).ambiguousDate, true);
    },
  );
  test('one time versus recurring and explicit versus vague times', () {
    expect(dates.parse('sa Friday', agentNow).date, DateTime(2026, 10, 23));
    expect(dates.parse('tuwing Friday', agentNow).frequency, 'weekly');
    expect(dates.parse('tuwing Friday', agentNow).date, isNull);
    expect(dates.parse('alas siyete', agentNow).ambiguousTime, true);
    expect(dates.parse('alas sais ng gabi', agentNow).time, '18:00');
    expect(dates.parse('eight in the morning', agentNow).time, '08:00');
    expect(dates.parse('12:99 pm', agentNow).ambiguousTime, true);
    expect(dates.parse('after lunch', agentNow).time, isEmpty);
    expect(dates.parse('every payday', agentNow).unsupportedRecurrence, true);
  });
  test(
    'negation overrides keywords and later positive direction is preserved',
    () {
      for (final text in [
        'Hindi ko gustong gumawa ng bagong goal',
        "Don't add PHP 500",
        'Huwag mo akong i-remind sa Friday',
      ]) {
        expect(planner.plan(text, now: agentNow).actions, isEmpty);
      }
      final positive = planner.plan(
        'Hindi ko gustong bawasan yung ipon. Gusto ko dagdagan.',
        now: agentNow,
      );
      expect(positive.actions.single, isA<ContributionDraft>());
      expect(positive.interpretation!.negated, contains('withdrawal'));
      expect(
        planner
            .plan(
              'Gawa goal na twenty thousand. Actually wag na.',
              now: agentNow,
            )
            .cancel,
        true,
      );
      expect(
        planner
            .plan('Explain what a savings withdrawal means', now: agentNow)
            .actions,
        isEmpty,
      );
    },
  );
  test('amount corrections and false starts supersede earlier values without execution', () {
    final p = planner.plan(
      'Add five hundred, ay wait, two hundred lang.',
      now: agentNow,
    );
    expect((p.actions.single as ContributionDraft).amount, '200');
    expect(p.interpretation!.corrections, contains('amount'));
    expect(
      planner
          .plan('Create... wait... actually edit my laptop goal', now: agentNow)
          .actions,
      isEmpty,
    );
  });
  test(
    'language changes and single field repairs preserve active draft identity',
    () async {
      final e = testEngine();
      await enableAgent(e);
      await e.applyPlan(planner.plan('Create a phone goal', now: agentNow));
      final id = e.mission!.id;
      await e.applyPlan(
        planner.plan('Gawin mong 25k', mission: e.mission, now: agentNow),
      );
      expect(e.mission!.id, id);
      expect((e.mission!.steps.single.action as GoalDraft).amount, '25000');
      await e.applyPlan(planner.plan('PHP', mission: e.mission, now: agentNow));
      await e.applyPlan(
        planner.plan('2027-01-31', mission: e.mission, now: agentNow),
      );
      final goal = e.mission!.steps.single.action as GoalDraft;
      expect(goal.name, 'phone');
      expect(goal.amount, '25000');
      expect(goal.currency, 'PHP');
      expect(goal.deadline, DateTime(2027, 1, 31));
      expect((e.backend as FakeAgentBackend).calls, isEmpty);
      e.dispose();
    },
  );
  test('multiple draft targets never choose the first incomplete record', () {
    final e = testEngine();
    e.draft([goalDraft(), goalDraft(name: 'Other', amount: '20000')]);
    final p = planner.plan('Gawin mong 25k', mission: e.mission, now: agentNow);
    expect(p.replacement, isNull);
    expect(p.interpretation!.uncertain, contains(Uncertainty.target));
    final explicit = planner.plan(
      'Yung pangalawa 25k',
      mission: e.mission,
      now: agentNow,
    );
    expect(explicit.replaceStep, 'step_2');
    expect((explicit.replacement as GoalDraft).amount, '25000');
    e.dispose();
  });
  test('local authorized goal matching retains similar targets and existing currency', () {
    const goals = [
      AgentRecord('a', 'Laptop Fund', currency: 'EUR'),
      AgentRecord('b', 'Laptop Upgrade Fund', currency: 'PHP'),
    ];
    final p = planner.plan(
      'Dagdagan mo yung laptop goal',
      goals: goals,
      now: agentNow,
    );
    expect((p.actions.single as ContributionDraft).goalId, isEmpty);
    expect(p.interpretation!.uncertain, contains(Uncertainty.target));
    final explicit = planner.plan(
      'Add 500 to "Laptop Fund"',
      goals: goals,
      now: agentNow,
    );
    expect((explicit.actions.single as ContributionDraft).goalId, 'a');
    expect((explicit.actions.single as ContributionDraft).currency, 'EUR');
  });
  test(
    'draft-only survives history, settings, chat approval, and blocks review',
    () async {
      final e = testEngine();
      await enableAgent(e);
      await e.applyPlan(
        planner.plan(
          'Gawa goal para sa laptop target PHP 500 by 2027-01-31 pero huwag mo muna i-save',
          now: agentNow,
        ),
      );
      expect(e.mission!.planOnly, true);
      expect(await e.review(), isNotEmpty);
      expect(
        AgentMission.fromJson(jsonDecode(jsonEncode(e.mission!.toJson())))
            .planOnly,
        true,
      );
      await e.updateSettings(e.settings.change({'language': 'filipino'}));
      await e.applyPlan(planner.plan('yes', mission: e.mission, now: agentNow));
      expect(e.mission!.planOnly, true);
      expect((e.backend as FakeAgentBackend).calls, isEmpty);
      e.enableDraftReview();
      expect(e.mission!.planOnly, false);
      expect(await e.review(), isEmpty);
      expect((e.backend as FakeAgentBackend).calls, isEmpty);
      e.dispose();
    },
  );
  test('uncertain correction blocks an already reviewed mission and stale approval', () async {
    final e = testEngine();
    await enableAgent(e);
    e.draft([goalDraft()]);
    final approval = await reviewed(e);
    await e.applyPlan(
      planner.plan('Mga 20k siguro', mission: e.mission, now: agentNow),
    );
    expect((e.mission!.steps.single.action as GoalDraft).amount, isEmpty);
    expect(await e.review(), isNotEmpty);
    await expectLater(e.execute(approval), throwsA(isA<AgentFailure>()));
    expect((e.backend as FakeAgentBackend).calls, isEmpty);
    e.dispose();
  });
  test(
    'recognition locale selection is capability based including Tagalog alias',
    () {
      const locales = VoiceLocaleRepository();
      expect(
        locales.recognition(
          AgentSettings(speechLanguage: AgentLanguage.filipino),
          {
            'languages': ['en-PH'],
          },
        ),
        isNull,
      );
      expect(
        locales.recognition(
          AgentSettings(speechLanguage: AgentLanguage.filipino),
          {
            'languages': ['en-PH', 'tl-PH'],
          },
        ),
        'tl-PH',
      );
      expect(
        locales.recognition(
          AgentSettings(speechLanguage: AgentLanguage.taglish),
          {
            'languages': ['en-PH'],
          },
        ),
        'en-PH',
      );
      expect(
        locales.recognition(AgentSettings(locale: 'xx-XX'), {
          'languages': ['en-PH'],
        }),
        isNull,
      );
      expect(
        locales.speech(AgentSettings(locale: 'fil-PH'), {
          'ttsLanguages': ['en-US'],
        }),
        '',
      );
      expect(
        locales.speech(AgentSettings(ttsLocale: 'fil-PH'), {
          'ttsLanguages': ['en-US'],
        }),
        isNull,
      );
    },
  );
  test('hypotheses and real confidence remain local review signals, partials never finalize', () async {
    final a = FakeAgentVoice(), v = AgentVoiceController(FakeAgentVoice());
    v.dispose();
    final voice = AgentVoiceController(a);
    await voice.initialize();
    await voice.start(AgentSettings());
    a.emit('partial', text: 'Add 50');
    expect(voice.originalTranscript, isEmpty);
    a.controller.add({
      'type': 'final',
      'session': a.session,
      'text': 'Add 500',
      'alternatives': ['Add 500', 'Add 5000'],
      'confidences': [0.8, -1],
    });
    expect(voice.originalTranscript, 'Add 500');
    expect(voice.alternatives, hasLength(2));
    expect(voice.confidences, [0.8, null]);
    expect(voice.state, AgentVoiceState.reviewing);
    voice.dispose();
  });
  test('safe AI requests never include the interpretation, history or financial slots', () {
    final p = planner.plan(
      'Gawa goal "Private name" target PHP 59321',
      now: agentNow,
    );
    final request = AgentSafeRequest(
      p.actions.map((a) => a.type),
      AgentLanguage.taglish,
    );
    expect(request.payload, isNot(contains('59321')));
    expect(request.payload, isNot(contains('Private name')));
    expect(p.interpretation!.diagnostics.toString(), isNot(contains('59321')));
  });
}
