import 'package:flutter/material.dart';

import '../design_system.dart';
import 'ai_domain.dart';

const aiGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    SaveTrackDesign.obsidian,
    SaveTrackDesign.midnight,
    SaveTrackDesign.heroEnd,
  ],
  stops: [0, .35, 1],
);

class AiEmblem extends StatelessWidget {
  const AiEmblem({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.isDark
            ? context.atelierSelected
            : SaveTrackDesign.lightMint,
        shape: BoxShape.circle,
        border: Border.all(color: context.atelierAccent.withValues(alpha: .16)),
      ),
      child: Center(child: AuroraEmblem(size: size * .72)),
    ),
  );
}

class AiDashboardCard extends StatelessWidget {
  const AiDashboardCard({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open AI Coach. Ask anything. Plan smarter.',
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(gradient: aiGradient),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const AiEmblem(size: 44),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SaveTrack AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Ask anything. Plan smarter.',
                        style: TextStyle(
                          color: SaveTrackDesign.onHeroMuted,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Open AI Coach',
                        style: TextStyle(
                          color: mint,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: mint, size: 22),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AiModeSelector extends StatelessWidget {
  const AiModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });
  final AiMode mode;
  final ValueChanged<AiMode> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: context.atelierTonal,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.atelierBorder),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final vertical =
            constraints.maxWidth < 420 &&
            MediaQuery.textScalerOf(context).scale(14) > 21;
        final options = [
          for (final item in AiMode.values) _option(context, item),
        ];
        return vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: options,
              )
            : Row(
                children: [
                  for (final option in options) Expanded(child: option),
                ],
              );
      },
    ),
  );

  Widget _option(BuildContext context, AiMode item) => Semantics(
    selected: item == mode,
    button: true,
    child: AnimatedContainer(
      duration: SaveTrackDesign.duration(
        context,
        SaveTrackDesign.selectionMotion,
      ),
      decoration: BoxDecoration(
        color: item == mode ? context.atelierSurface : Colors.transparent,
        border: Border.all(
          color: item == mode ? context.atelierBorder : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: item == mode
              ? context.atelierAccent
              : context.atelierMuted,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        onPressed: () => onChanged(item),
        child: Text(
          item == AiMode.askAnything ? 'Ask Anything' : 'SaveTrack Coach',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    ),
  );
}

class AiWelcomeHero extends StatelessWidget {
  const AiWelcomeHero({super.key, required this.mode});
  final AiMode mode;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: FlowWorkspaceIntro(
      icon: Icons.auto_awesome_outlined,
      eyebrow: mode == AiMode.askAnything
          ? 'A space for your curiosity'
          : 'AI Coach Lite · Read only',
      title: mode == AiMode.askAnything
          ? 'A little clarity\ngoes a long way.'
          : 'Small steps.\nMeaningful progress.',
      detail: mode == AiMode.askAnything
          ? 'Explore ideas, untangle a question, and find a little direction.'
          : 'Understand your savings and make room for what matters, one thoughtful step at a time.',
    ),
  );
}

class AiPromptCard extends StatelessWidget {
  const AiPromptCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title, detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => FlowActionCard(
    icon: icon,
    title: title,
    detail: detail,
    onTap: onTap,
    accent: icon == Icons.event_note_outlined
        ? FlowAccent.lavender
        : icon == Icons.pie_chart_outline_rounded
        ? FlowAccent.peach
        : icon == Icons.code_rounded
        ? FlowAccent.coral
        : FlowAccent.mint,
  );
}

class AiFactCard extends StatelessWidget {
  const AiFactCard({super.key, required this.facts});
  final AiLocalFacts facts;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Verified SaveTrack facts. Calculated locally.',
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.atelierTonal,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.atelierBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.verified_outlined,
                color: context.atelierAccent,
                size: 18,
              ),
              Text(
                'Verified by SaveTrack',
                style: TextStyle(
                  color: context.atelierAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                '· On this device',
                style: TextStyle(color: context.atelierMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            facts.title,
            style: TextStyle(
              color: context.atelierInk,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (facts.values['Saved'] != null) ...[
            const SizedBox(height: 16),
            Text(
              'Saved toward your goal',
              style: TextStyle(color: context.atelierMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            SelectableText(
              facts.values['Saved']!,
              style: TextStyle(
                color: context.atelierInk,
                fontSize: 26,
                height: 1.3,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (facts.progress != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: facts.progress,
                backgroundColor: context.atelierSelected,
                color: context.atelierAccent,
                minHeight: 6,
                semanticsLabel: 'Goal progress',
                semanticsValue: '${(facts.progress! * 100).round()}',
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final entry in facts.values.entries.where(
            (entry) => entry.key != 'Saved',
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow =
                      constraints.maxWidth < 320 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20;
                  final label = Text(
                    entry.key,
                    style: TextStyle(color: context.atelierMuted, fontSize: 12),
                  );
                  final value = SelectableText(
                    entry.value,
                    style: TextStyle(
                      color: context.atelierInk,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  );
                  return narrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [label, const SizedBox(height: 2), value],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: label),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: value),
                          ],
                        );
                },
              ),
            ),
          Text(
            'Exact values stay local. AI guidance is separate and may be inaccurate.',
            style: TextStyle(
              color: context.atelierMuted,
              height: 1.5,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

enum AiReviewChoice { approve, localOnly }

Future<AiReviewChoice?> showAiContextReview(
  BuildContext context,
  AiLocalFacts facts,
) => showModalBottomSheet<AiReviewChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: context.atelierSurface,
  constraints: const BoxConstraints(maxWidth: 560),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (context) => _AiContextReviewSheet(facts: facts),
);

class _AiContextReviewSheet extends StatelessWidget {
  const _AiContextReviewSheet({required this.facts});
  final AiLocalFacts facts;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.atelierSelected,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: context.atelierAccent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Review AI Context',
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.25,
                          letterSpacing: -.5,
                          fontWeight: FontWeight.w700,
                          color: context.atelierInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  facts.shared
                      ? 'Shared goal facts stay on your device. Member participation does not authorize external sharing.'
                      : 'Only the broad categories below will be shared. Names, exact amounts, dates, notes and identifiers stay on your device.',
                  style: TextStyle(
                    color: context.atelierMuted,
                    height: 1.6,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                if (facts.shared)
                  const _AiReviewNotice(
                    icon: Icons.lock_outline_rounded,
                    title: 'Shared goals stay private',
                    detail: 'You can still get general advice without sharing this goal’s context.',
                    tonal: true,
                  )
                else
                  _AiReviewSummary(summary: facts.summary),
                const SizedBox(height: 20),
                const _AiReviewNotice(
                  icon: Icons.info_outline_rounded,
                  title: 'About Google processing',
                  detail: 'Google processes questions and answers. Unpaid API content may be used to improve products and reviewed by people. Do not include personal, confidential or sensitive information.',
                ),
                if (!facts.shared) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: context.atelierMuted,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Approval lasts 10 minutes. Revoke it anytime.',
                          style: TextStyle(
                            color: context.atelierMuted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
          final actions = Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!facts.shared) ...[
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.atelierAccent,
                      foregroundColor: context.atelierSurface,
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pop(context, AiReviewChoice.approve),
                    child: const Text(
                      'Approve this summary',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.atelierAccent,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    side: BorderSide(color: context.atelierBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pop(context, AiReviewChoice.localOnly),
                  child: const Text(
                    'General advice instead',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
          // Short screens and large text scroll as one unit so the footer
          // cannot crowd out the summary or overflow above an open keyboard.
          if (constraints.maxHeight < 560 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [content, const Divider(height: 1), actions],
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: SingleChildScrollView(child: content)),
              const Divider(height: 1),
              actions,
            ],
          );
        },
      ),
    ),
  );
}

class _AiReviewSummary extends StatelessWidget {
  const _AiReviewSummary({required this.summary});
  final AiSafeSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.atelierTonal,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.atelierBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Text(
            'What AI will see',
            style: TextStyle(
              color: context.atelierAccent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Column(
            children: [
              for (final entry in summary.fields.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final label = Text(
                        _fieldLabel(entry.key),
                        style: TextStyle(
                          color: context.atelierMuted,
                          fontSize: 13,
                        ),
                      );
                      final value = Text(
                        _valueLabel(entry.value),
                        style: TextStyle(
                          color: context.atelierInk,
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                      if (constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(13) > 19.5) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [label, const SizedBox(height: 3), value],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: label),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: value),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: context.atelierBorder),
        ExpansionTile(
          title: Text(
            'View exact data',
            style: TextStyle(
              color: context.atelierAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 18),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          iconColor: context.atelierAccent,
          collapsedIconColor: context.atelierAccent,
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            SelectableText(
              summary.text,
              style: TextStyle(
                color: context.atelierInk,
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  static String _fieldLabel(AiContextField field) => switch (field) {
    AiContextField.subject => 'Subject',
    AiContextField.progress => 'Progress',
    AiContextField.deadline => 'Deadline',
    AiContextField.workload => 'Workload',
    AiContextField.completion => 'Completion',
    AiContextField.priority => 'Priority',
  };

  static String _valueLabel(AiContextValue value) => switch (value) {
    AiContextValue.savings => 'Savings goal',
    AiContextValue.planner => 'Daily planner',
    AiContextValue.report => 'Weekly report',
    AiContextValue.notStarted => 'Not started',
    AiContextValue.early => 'Early stage',
    AiContextValue.midway => 'Midway',
    AiContextValue.advanced => 'Well underway',
    AiContextValue.achieved => 'Goal achieved',
    AiContextValue.noDeadline => 'No deadline set',
    AiContextValue.overdue => 'Overdue',
    AiContextValue.soon => 'Coming up soon',
    AiContextValue.later => 'Further away',
    AiContextValue.noTasks => 'No tasks',
    AiContextValue.light => 'Light',
    AiContextValue.moderate => 'Moderate',
    AiContextValue.busy => 'Busy',
    AiContextValue.noneComplete => 'No tasks completed',
    AiContextValue.someComplete => 'Some tasks completed',
    AiContextValue.allComplete => 'All tasks completed',
    AiContextValue.highPriorityPresent => 'High-priority tasks pending',
    AiContextValue.noHighPriority => 'No high-priority tasks pending',
  };
}

class _AiReviewNotice extends StatelessWidget {
  const _AiReviewNotice({
    required this.icon,
    required this.title,
    required this.detail,
    this.tonal = false,
  });
  final IconData icon;
  final String title, detail;
  final bool tonal;

  @override
  Widget build(BuildContext context) => Container(
    padding: tonal ? const EdgeInsets.all(16) : EdgeInsets.zero,
    decoration: tonal
        ? BoxDecoration(
            color: context.atelierTonal,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.atelierBorder),
          )
        : null,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.atelierAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.atelierInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: TextStyle(
                  color: context.atelierMuted,
                  height: 1.6,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
