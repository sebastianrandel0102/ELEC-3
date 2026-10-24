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
  });
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final Map<int, int> counts;
  @override
  Widget build(BuildContext context) {
    final monday = DateTime(
      selected.year,
      selected.month,
      selected.day - selected.weekday + 1,
    );
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
                        final count = counts[i + 1];
                        return Semantics(
                          selected: active,
                          button: true,
                          onTap: () => onSelected(day),
                          label:
                              '${localizations.formatFullDate(day)}${count == null ? '' : ', $count tasks'}',
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
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? context.flowAction
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      localizations.narrowWeekdays[day.weekday %
                                          7],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: active
                                            ? context.flowOnAction
                                            : context.atelierMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                        color: active
                                            ? context.flowOnAction
                                            : context.atelierInk,
                                      ),
                                    ),
                                    if (count != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: active
                                              ? context.flowOnAction
                                              : context.atelierMuted,
                                        ),
                                      ),
                                    ],
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
              width: 64,
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
                    left: BorderSide(color: context.atelierBorder),
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
