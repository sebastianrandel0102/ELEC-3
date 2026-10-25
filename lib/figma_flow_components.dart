part of 'design_system.dart';

/// Reference-inspired roles extend the existing theme, keeping financial and
/// scheduling state in their original screens and services.
abstract final class FigmaFlowPalette {
  static const mint = Color(0xFF48BF91);
  static const fresh = Color(0xFF65D5A9);
  static const soft = Color(0xFFDDF5E9);
  static const mist = Color(0xFFF0FAF5);
  static const charcoal = Color(0xFF202C29);
  static const secondary = Color(0xFF626F69);
  static const coral = Color(0xFFFF805D);
  static const lavender = Color(0xFF8B8CF4);
  static const peach = Color(0xFFFFC681);
  static const neutral = Color(0xFFF4F6F5);
  static const darkCanvas = Color(0xFF142824);
  static const darkSurface = Color(0xFF203630);
  static const darkElevated = Color(0xFF2B453C);
}

/// Calendar navigation uses local calendar constructors, never 24-hour jumps.
abstract final class FlowCalendar {
  static DateTime shift(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);
  static DateTime monday(DateTime day) => shift(day, 1 - day.weekday);
}

enum FlowAccent { mint, coral, lavender, peach }

class FlowCategoryDecoration extends StatelessWidget {
  const FlowCategoryDecoration({
    super.key,
    required this.accent,
    required this.child,
  });
  final FlowAccent accent;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        right: -30,
        top: -42,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                color: context
                    .flowAccent(accent)
                    .withValues(alpha: context.isDark ? .12 : .22),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(78),
                  bottomRight: Radius.circular(36),
                ),
              ),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

extension FlowColors on BuildContext {
  Color get flowAction =>
      isDark ? Theme.of(this).colorScheme.primary : FigmaFlowPalette.mint;
  Color get flowOnAction => isDark ? Theme.of(this).colorScheme.onPrimary : ink;
  Color get flowHero =>
      isDark ? FigmaFlowPalette.darkElevated : FigmaFlowPalette.fresh;
  Color flowCategory(FlowAccent accent) {
    final color = switch (accent) {
      FlowAccent.mint => FigmaFlowPalette.soft,
      FlowAccent.coral => const Color(0xFFFFE1D7),
      FlowAccent.lavender => const Color(0xFFE8E5FF),
      FlowAccent.peach => const Color(0xFFFFEBCF),
    };
    return isDark
        ? Color.alphaBlend(color.withValues(alpha: .13), atelierSurface)
        : color;
  }

  Color flowAccent(FlowAccent accent) => switch (accent) {
    FlowAccent.mint => FigmaFlowPalette.mint,
    FlowAccent.coral => FigmaFlowPalette.coral,
    FlowAccent.lavender => FigmaFlowPalette.lavender,
    FlowAccent.peach => FigmaFlowPalette.peach,
  };
}

/// The surface overlaps through layout, so its full painted area also owns its
/// hit targets. No translated content falls outside a scrollable's hit bounds.
class FlowContentSheet extends StatelessWidget {
  const FlowContentSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: context.atelierSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
    ),
    child: child,
  );
}

/// Seven real calendar dates with a stable minimum touch target. Narrow phones
/// and enlarged text can scroll the strip without compressing the labels.
class FlowWeekSelector extends StatelessWidget {
  const FlowWeekSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.counts = const {},
    this.today,
  });
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final Map<int, int> counts;
  final DateTime? today;
  @override
  Widget build(BuildContext context) {
    final monday = FlowCalendar.monday(selected);
    final current = today ?? DateTime.now();
    final localizations = MaterialLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = math.max(48.0, MediaQuery.textScalerOf(context).scale(26));
        final width = math.max(constraints.maxWidth, cell * 7);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = DateTime(
                          monday.year,
                          monday.month,
                          monday.day + i,
                        );
                        final active = DateUtils.isSameDay(day, selected);
                        final isToday = DateUtils.isSameDay(day, current);
                        final count = counts[i + 1];
                        return Semantics(
                          selected: active,
                          button: true,
                          onTap: () => onSelected(day),
                          label:
                              '${localizations.formatFullDate(day)}${isToday ? ', Today' : ''}${count == null ? '' : ', $count tasks'}',
                          excludeSemantics: true,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onSelected(day),
                              borderRadius: BorderRadius.circular(15),
                              child: AnimatedContainer(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                duration: SaveTrackDesign.duration(
                                  context,
                                  SaveTrackDesign.selectionMotion,
                                ),
                                curve: SaveTrackDesign.motionCurve,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? context.flowAction
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: isToday && !active
                                        ? context.atelierAccent
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      localizations.narrowWeekdays[day.weekday %
                                          7],
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.2,
                                        color: active
                                            ? context.flowOnAction
                                            : context.atelierMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                        color: active
                                            ? context.flowOnAction
                                            : context.atelierInk,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: count == null
                                          ? 6
                                          : math.max(
                                              14,
                                              MediaQuery.textScalerOf(context)
                                                      .scale(11) *
                                                  1.2,
                                            ),
                                      child: count != null
                                          ? Text(
                                              '$count',
                                              style: TextStyle(
                                                fontSize: 11,
                                                height: 1.2,
                                                fontWeight: isToday
                                                    ? FontWeight.w700
                                                    : FontWeight.w400,
                                                color: active
                                                    ? context.flowOnAction
                                                    : context.atelierMuted,
                                              ),
                                            )
                                          : Center(
                                              child: Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isToday
                                                      ? (active
                                                            ? context
                                                                  .flowOnAction
                                                            : context
                                                                  .atelierAccent)
                                                      : Colors.transparent,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FlowDateHeading extends StatelessWidget {
  const FlowDateHeading({
    super.key,
    required this.date,
    required this.onToday,
    this.onPick,
  });
  final DateTime date;
  final VoidCallback onToday;
  final VoidCallback? onPick;
  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    final parts = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          label:
              '${onPick == null ? '' : 'Choose planner date. '}${l.formatFullDate(date)}',
          button: onPick != null,
          onTap: onPick,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${date.day}',
                  style: SaveTrackDesign.amount.copyWith(
                    fontSize: 48,
                    color: context.atelierInk,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    DateFormat('EEE\nMMM yyyy').format(date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final today = TextButton(
      onPressed: onToday,
      style: TextButton.styleFrom(
        backgroundColor: context.atelierSelected,
        foregroundColor: context.isDark ? context.atelierInk : teal,
      ),
      child: const Text('Today'),
    );
    return Row(
      children: [
        Expanded(child: parts),
        const SizedBox(width: 12),
        today,
      ],
    );
  }
}

/// A shared rail for tasks and reminders. Content height controls the rail and
/// large text moves metadata above the card instead of squeezing its contents.
class FlowTimelineEntry extends StatelessWidget {
  const FlowTimelineEntry({
    super.key,
    required this.time,
    required this.child,
    this.caption,
    this.featured = false,
  });
  final String time;
  final String? caption;
  final Widget child;
  final bool featured;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final metadata = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: context.atelierInk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 5),
            Text(caption!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [metadata, const SizedBox(height: 8), child],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(top: 18, right: 8),
                child: metadata,
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: featured
                          ? context.atelierAccent.withValues(alpha: .35)
                          : context.atelierBorder,
                    ),
                  ),
                ),
                child: child,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Shared title treatment for secondary workspaces, sized for real content.
class FlowWorkspaceIntro extends StatelessWidget {
  const FlowWorkspaceIntro({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.detail,
    this.footer,
  });
  final IconData icon;
  final String eyebrow, title, detail;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(SaveTrackDesign.spaceLg),
    decoration: BoxDecoration(
      color: context.flowCategory(FlowAccent.mint),
      borderRadius: BorderRadius.circular(SaveTrackDesign.radiusHero),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: context.atelierAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: context.atelierAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 26, height: 1.2),
          ),
        ),
        const SizedBox(height: 8),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
        if (footer != null) ...[const SizedBox(height: 16), footer!],
      ],
    ),
  );
}

class FlowSectionHeader extends StatelessWidget {
  const FlowSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        );
        if (trailing == null) return label;
        if (constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, const SizedBox(height: 4), trailing!],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: 12),
            trailing!,
          ],
        );
      },
    ),
  );
}

/// Functional category tiles shared by AI prompts and Agent shortcuts.
class FlowActionCard extends StatelessWidget {
  const FlowActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.accent = FlowAccent.mint,
  });
  final IconData icon;
  final String title, detail;
  final VoidCallback onTap;
  final FlowAccent accent;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: context.flowCategory(accent),
      borderRadius: BorderRadius.circular(SaveTrackDesign.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: FlowCategoryDecoration(
          accent: accent,
          child: Padding(
            padding: const EdgeInsets.all(SaveTrackDesign.space),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: context.atelierInk, size: 24),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      size: 16,
                      color: context.atelierInk,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A task's data and mutations are supplied by its owning feature.
class FlowTaskCard extends StatelessWidget {
  const FlowTaskCard({
    super.key,
    required this.title,
    required this.priority,
    required this.completed,
    required this.onComplete,
    required this.onOpen,
    required this.menu,
    this.featured = false,
    this.schedule,
    this.description,
    this.footer,
  });
  final String title, priority;
  final bool completed, featured;
  final String? schedule, description;
  final ValueChanged<bool> onComplete;
  final VoidCallback onOpen;
  final Widget menu;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final highlighted = featured && !completed;
    final background = highlighted
        ? (context.isDark ? context.atelierSelected : FigmaFlowPalette.fresh)
        : context.atelierTonal;
    return AnimatedContainer(
      duration: SaveTrackDesign.duration(context, SaveTrackDesign.motion),
      curve: SaveTrackDesign.motionCurve,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SaveTrackDesign.radius),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(SaveTrackDesign.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontSize: 16,
                                height: 1.4,
                                color: completed
                                    ? context.atelierMuted
                                    : context.atelierInk,
                                decoration: completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                      ),
                    ),
                    menu,
                  ],
                ),
                if (description?.trim().isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Text(
                      description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: highlighted
                            ? context.atelierInk
                            : context.atelierMuted,
                      ),
                    ),
                  ),
                if (schedule?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      schedule!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusPill(
                            '$priority priority',
                            color: highlighted
                                ? context.atelierInk
                                : priority == 'High'
                                ? context.atelierWarning
                                : context.atelierAccent,
                          ),
                          if (completed) const StatusPill('Completed'),
                          if (highlighted)
                            Text(
                              'Up next',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: context.atelierInk),
                            ),
                        ],
                      ),
                    ),
                    Checkbox(
                      semanticLabel: completed
                          ? 'Mark $title incomplete'
                          : 'Complete $title',
                      value: completed,
                      onChanged: (value) => onComplete(value == true),
                    ),
                  ],
                ),
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FlowTimelineHeader extends StatelessWidget {
  const FlowTimelineHeader({super.key, this.title = 'Your tasks'});
  final String title;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (constraints.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21)
            SizedBox(
              width: 73,
              child: Text('Time', style: Theme.of(context).textTheme.bodySmall),
            ),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodySmall),
          ),
          Icon(Icons.sort_rounded, size: 18, color: context.atelierMuted),
        ],
      ),
    ),
  );
}

class FlowPlannerSummary extends StatelessWidget {
  const FlowPlannerSummary({
    super.key,
    required this.done,
    required this.total,
    this.label = 'Daily progress',
  });
  final int done, total;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.flowCategory(FlowAccent.mint),
      borderRadius: BorderRadius.circular(SaveTrackDesign.radius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            Text(
              '$done of $total tasks completed',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        MintProgress(value: total == 0 ? 0 : done / total),
      ],
    ),
  );
}

/// Receives a formatted amount; currency arithmetic stays in the report model.
class FlowFinancialMetric extends StatelessWidget {
  const FlowFinancialMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = FlowAccent.mint,
  });
  final String label, value;
  final IconData icon;
  final FlowAccent accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.flowCategory(accent),
      borderRadius: BorderRadius.circular(SaveTrackDesign.radiusMedium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Icon(icon, size: 20, color: context.atelierInk),
        ),
        const SizedBox(height: 16),
        AmountText(
          value,
          compactCurrency: true,
          stackCurrency: true,
          style: SaveTrackDesign.amount.copyWith(
            fontSize: 24,
            letterSpacing: -.6,
            color: context.atelierInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

/// Keeps loading geometry close to the schedule it will replace.
class FlowTimelineSkeleton extends StatelessWidget {
  const FlowTimelineSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading your schedule',
    child: ExcludeSemantics(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            FlowTimelineEntry(
              time: '',
              child: Container(
                height: 128,
                decoration: BoxDecoration(
                  color: context.atelierTonal,
                  borderRadius: BorderRadius.circular(SaveTrackDesign.radius),
                ),
                child: const AuroraSkeleton(),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Original vector savings illustration; no network, image decode or ticker.
class FlowSavingsArt extends StatelessWidget {
  const FlowSavingsArt({super.key, this.size = 128});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _FlowSavingsPainter(dark: context.isDark)),
      ),
    ),
  );
}

class _FlowSavingsPainter extends CustomPainter {
  const _FlowSavingsPainter({required this.dark});
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 160);
    final p = Paint();
    canvas.drawCircle(
      const Offset(90, 82),
      66,
      p..color = const Color(0x2282F0BA),
    );
    // Botanical leaves frame the savings jar.
    final stem = Path()
      ..moveTo(122, 137)
      ..quadraticBezierTo(116, 86, 141, 38);
    canvas.drawPath(
      stem,
      p
        ..color = const Color(0xFF2C8B6B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    p.style = PaintingStyle.fill;
    for (final y in [55.0, 77.0, 99.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(127, y + 18)
          ..quadraticBezierTo(108, y + 8, 109, y - 6)
          ..quadraticBezierTo(129, y - 4, 127, y + 18),
        p..color = const Color(0xFF39A77D),
      );
      canvas.drawPath(
        Path()
          ..moveTo(126, y + 15)
          ..quadraticBezierTo(149, y + 10, 151, y - 6)
          ..quadraticBezierTo(133, y - 4, 126, y + 15),
        p..color = const Color(0xFFB4F0C9),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(29, 65, 82, 79),
        const Radius.circular(22),
      ),
      p..color = dark ? const Color(0xFF5AB795) : const Color(0xFFE6FFF0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 58, 84, 17),
        const Radius.circular(7),
      ),
      p..color = const Color(0xFF2A8B6C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(48, 62, 43, 5),
        const Radius.circular(3),
      ),
      p..color = const Color(0xFF185B47),
    );
    canvas.drawCircle(
      const Offset(69, 108),
      22,
      p..color = const Color(0xFFFFCC86),
    );
    canvas.drawCircle(
      const Offset(69, 108),
      16,
      p..color = const Color(0xFFE6A759),
    );
    canvas.drawPath(
      Path()
        ..moveTo(59, 108)
        ..lineTo(66, 115)
        ..lineTo(79, 101),
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF2D8),
    );
    p.style = PaintingStyle.fill;
    canvas.drawOval(
      const Rect.fromLTWH(52, 23, 30, 25),
      p..color = const Color(0xFFFFD89A),
    );
    canvas.drawOval(
      const Rect.fromLTWH(57, 27, 20, 16),
      p..color = const Color(0xFFE9AD62),
    );
    canvas.drawCircle(
      const Offset(26, 39),
      4,
      p..color = const Color(0xFFC7F5D7),
    );
    canvas.drawCircle(
      const Offset(105, 22),
      3,
      p..color = const Color(0xFFE6FFF0),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlowSavingsPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
