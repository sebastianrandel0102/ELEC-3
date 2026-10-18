import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system.dart';
import '../agent_domain.dart';
import '../intelligence/agent_language.dart';
import 'agent_widgets.dart';

IconData agentActionIcon(AgentAction action) => switch (action) {
  GoalDraft() => Icons.track_changes_rounded,
  TaskDraft() => Icons.checklist_rounded,
  ReminderDraft() => Icons.notifications_none_rounded,
  ContributionDraft() => Icons.savings_outlined,
  ScenarioDraft() => Icons.insights_rounded,
  AllocationDraft() => Icons.pie_chart_outline_rounded,
};

/// All values come from the authoritative draft. This widget cannot execute it.
class AgentActionPreview extends StatelessWidget {
  const AgentActionPreview({
    super.key,
    required this.action,
    required this.strings,
    required this.now,
    this.referenceLabel,
  });
  final AgentAction action;
  final AgentStrings strings;
  final DateTime now;
  final String? referenceLabel;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    String date(DateTime? value) => value == null
        ? strings.choose('Choose a date', 'Pumili ng petsa')
        : agentDay(value);
    String money(String value, String currency) => value.isEmpty
        ? strings.choose('Amount needed', 'Kailangan ng halaga')
        : agentMoney(value, currency);
    final title = switch (action) {
      GoalDraft a => a.name,
      TaskDraft a => a.title,
      ReminderDraft a => a.title,
      ScenarioDraft a => a.title,
      ContributionDraft() => strings.choose(
        'Contribution draft',
        'Draft ng dagdag ipon',
      ),
      AllocationDraft() => strings.choose(
        'Explore your allocation',
        'Tingnan ang hatian ng ipon',
      ),
    };
    final amount = switch (action) {
      GoalDraft a => money(a.amount, a.currency),
      ContributionDraft a => money(a.amount, a.currency),
      ScenarioDraft a => money(a.target, a.currency),
      AllocationDraft a => money(a.budget, a.currency),
      _ => null,
    };
    final details = switch (action) {
      GoalDraft a => [
        (strings.choose('Target date', 'Takdang petsa'), date(a.deadline)),
        (strings.choose('Currency', 'Salapi'), a.currency),
      ],
      TaskDraft a => [
        (strings.choose('Scheduled', 'Nakatakda'), date(a.day)),
        (
          strings.choose('Time', 'Oras'),
          a.time.isEmpty ? strings.choose('Flexible', 'Anumang oras') : a.time,
        ),
        (strings.choose('Priority', 'Prayoridad'), a.priority),
      ],
      ReminderDraft a => [
        (
          strings.choose('Linked to', 'Kaugnay na goal o gawain'),
          referenceLabel ??
              (a.targetId.isNotEmpty || a.targetStep.isNotEmpty
                  ? strings.choose(
                      'Selected goal or task',
                      'Napiling goal o gawain',
                    )
                  : strings.choose(
                      'Choose a goal or task',
                      'Pumili ng goal o gawain',
                    )),
        ),
        (
          strings.choose('Repeat', 'Ulit'),
          switch (a.frequency) {
            'weekly' =>
              a.weekday != null && a.weekday! >= 1 && a.weekday! <= 7
                  ? '${strings.choose('Every', 'Tuwing')} ${['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][a.weekday! - 1]}'
                  : strings.choose('Weekly', 'Lingguhan'),
            'daily' => strings.choose('Every day', 'Araw-araw'),
            'deadline' => strings.choose(
              'On goal deadline',
              'Sa takdang petsa ng goal',
            ),
            'taskStart' => strings.choose(
              'Before task starts',
              'Bago magsimula ang gawain',
            ),
            _ => date(a.day),
          },
        ),
        (
          strings.choose('Time', 'Oras'),
          a.time.isEmpty
              ? strings.choose('Choose a time', 'Pumili ng oras')
              : a.time,
        ),
        (
          strings.choose('Delivery', 'Abiso'),
          strings.choose(
            'Uses device notification permissions',
            'Batay sa pahintulot ng device sa notification',
          ),
        ),
      ],
      ContributionDraft a => [
        (
          strings.choose('Goal', 'Goal'),
          a.goalId.isEmpty
              ? strings.choose(
                  'Choose a personal goal',
                  'Pumili ng personal na goal',
                )
              : referenceLabel ??
                    strings.choose(
                      'Selected personal goal',
                      'Napiling personal na goal',
                    ),
        ),
        (
          strings.choose('Next step', 'Susunod'),
          strings.choose(
            'Confirm in Add Savings',
            'Kumpirmahin sa Add Savings',
          ),
        ),
      ],
      ScenarioDraft a => [
        (
          strings.choose('Already saved', 'Naipon na'),
          money(a.saved, a.currency),
        ),
        (
          strings.choose('Contribution', 'Dagdag ipon'),
          a.contribution.isEmpty
              ? strings.choose(
                  'Calculated from deadline',
                  'Batay sa takdang petsa',
                )
              : '${money(a.contribution, a.currency)} / ${a.frequency}',
        ),
        if (a.deadline != null)
          (strings.choose('Target date', 'Takdang petsa'), date(a.deadline)),
      ],
      AllocationDraft a => [
        (
          strings.choose('Method', 'Paraan'),
          strings.choose(
            'Equal split · ${a.currency}',
            'Pantay na hatian · ${a.currency}',
          ),
        ),
      ],
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 21),
            ),
          if (amount != null) ...[
            const SizedBox(height: 8),
            Text(
              amount,
              style: SaveTrackDesign.amount.copyWith(
                fontSize: 30,
                color: c.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              action is ContributionDraft
                  ? strings.choose(
                      'Draft · No money recorded',
                      'Draft · Wala pang naitalang pera',
                    )
                  : strings.choose('Planning amount', 'Halaga sa plano'),
              style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          for (final detail in details)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.$1,
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail.$2,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          if (action case GoalDraft a
              when a.validate(now).isEmpty && a.deadline!.isAfter(now))
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: Text(
                  strings.choose(
                    'Suggested weekly pace',
                    'Mungkahing lingguhang hulog',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                  Text(
                    ScenarioDraft(
                      target: a.amount,
                      saved: '0',
                      currency: a.currency,
                      deadline: a.deadline,
                    ).calculate(now),
                    style: TextStyle(
                      color: c.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          if (action case ScenarioDraft a) ...[
            if (a.validate(now).isEmpty && a.contribution.isNotEmpty)
              _Projection(action: a, strings: strings),
            AgentStatusChip(
              label: strings.choose(
                'Simulation · No balance changes',
                'Simulation · Walang pagbabago sa balanse',
              ),
              icon: Icons.insights_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

class _Projection extends StatelessWidget {
  const _Projection({required this.action, required this.strings});
  final ScenarioDraft action;
  final AgentStrings strings;
  @override
  Widget build(BuildContext context) {
    // Doubles are used only for chart coordinates; financial results continue
    // to come from ScenarioDraft.calculate's exact decimal arithmetic.
    final target = double.parse(action.target);
    final saved = double.parse(action.saved);
    final contribution = double.parse(action.contribution);
    final periods = ((target - saved) / contribution).ceil().clamp(1, 12);
    final points = List.generate(
      periods + 1,
      (i) => ((saved + contribution * i) / target).clamp(0.0, 1.0),
    );
    final c = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '${strings.choose('Projection', 'Tantiyang ipon')}: $periods ${action.frequency} contributions',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.choose(
                'Your projected pace',
                'Tantiyang bilis ng pag-ipon',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              width: double.infinity,
              child: CustomPaint(
                painter: _ProjectionPainter(
                  points,
                  c.primary,
                  c.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${strings.choose('Now →', 'Ngayon →')} $periods ${action.frequency} · ${strings.choose('Fixed contributions, no interest', 'Pare-parehong hulog, walang interes')}',
              style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectionPainter extends CustomPainter {
  const _ProjectionPainter(this.values, this.color, this.grid);
  final List<double> values;
  final Color color, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = 5 + (size.height - 10) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * size.width / math.max(1, values.length - 1);
      final y = 5 + (1 - values[i]) * (size.height - 10);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: .09));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ProjectionPainter old) =>
      old.color != color ||
      old.grid != grid ||
      old.values.toString() != values.toString();
}
