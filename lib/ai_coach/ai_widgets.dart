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
        color: SaveTrackDesign.midnight,
        borderRadius: BorderRadius.circular(size * .3),
        border: Border.all(color: SaveTrackDesign.fresh.withValues(alpha: .3)),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size * .56,
        color: SaveTrackDesign.luminous,
      ),
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
                const Expanded(
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
      color: SaveTrackDesign.lightMint,
      borderRadius: BorderRadius.circular(16),
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
        color: item == mode ? teal : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: item == mode ? Colors.white : ink,
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: aiGradient,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -36,
          top: -40,
          child: ExcludeSemantics(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    SaveTrackDesign.fresh.withValues(alpha: .18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                AiEmblem(size: 42),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'YOUR AI COMPANION',
                    style: TextStyle(
                      color: mint,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              mode == AiMode.askAnything
                  ? 'What can we\nexplore today?'
                  : 'Your goals.\nSmarter decisions.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 29,
                height: 1.2,
                letterSpacing: -.7,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              mode == AiMode.askAnything
                  ? 'Ask questions, learn something new, write better, or solve a problem.'
                  : 'Understand your progress, explore realistic plans, and organize your day.',
              style: const TextStyle(
                color: SaveTrackDesign.onHeroMuted,
                height: 1.6,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),
            const Row(
              children: [
                Icon(Icons.shield_outlined, size: 15, color: mint),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thoughtful answers. You stay in control.',
                    style: TextStyle(color: mint, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
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
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: SaveTrackDesign.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: teal, size: 21),
                const Spacer(),
                const Icon(Icons.north_east_rounded, color: muted, size: 14),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: ink,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              style: const TextStyle(color: muted, height: 1.5, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
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
        color: SaveTrackDesign.mist,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SaveTrackDesign.elevatedBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.verified_outlined, color: teal, size: 18),
              Text(
                'Verified by SaveTrack',
                style: TextStyle(
                  color: teal,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                '· On this device',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            facts.title,
            style: const TextStyle(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (facts.values['Saved'] != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Saved toward your goal',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            SelectableText(
              facts.values['Saved']!,
              style: const TextStyle(
                color: ink,
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
                backgroundColor: SaveTrackDesign.lightMint,
                color: teal,
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
                    style: const TextStyle(color: muted, fontSize: 12),
                  );
                  final value = SelectableText(
                    entry.value,
                    style: const TextStyle(
                      color: ink,
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
          const Text(
            'Exact values stay local. AI guidance is separate and may be inaccurate.',
            style: TextStyle(color: muted, height: 1.5, fontSize: 11),
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
  backgroundColor: Colors.white,
  builder: (context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.shield_outlined, color: teal, size: 32),
        const SizedBox(height: 14),
        const Text(
          'Review AI Context',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          facts.shared
              ? 'Shared goal facts stay on your device. Member participation does not authorize external sharing.'
              : 'Only these anonymous categories would be sent. Names, exact amounts, dates, notes and identifiers stay on your device.',
          style: const TextStyle(color: muted, height: 1.6),
        ),
        const SizedBox(height: 16),
        if (!facts.shared)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SaveTrackDesign.mist,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              facts.summary.text,
              style: const TextStyle(
                color: ink,
                fontFamily: 'monospace',
                height: 1.6,
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Google processes questions and answers. Unpaid API content may be used to improve products and reviewed by people. Do not include personal, confidential or sensitive information. Approval expires in 10 minutes and can be revoked.',
          style: TextStyle(color: muted, height: 1.6, fontSize: 12),
        ),
        const SizedBox(height: 20),
        if (!facts.shared)
          FilledButton(
            onPressed: () => Navigator.pop(context, AiReviewChoice.approve),
            child: const Text('Approve this summary'),
          ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, AiReviewChoice.localOnly),
          child: const Text('General advice instead'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  ),
);
