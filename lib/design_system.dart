import 'package:flutter/material.dart';

import 'dart:math' as math;

const mint = Color(0xFFA8F0D5);
const teal = Color(0xFF0B5948);
const canvas = Color(0xFFF6FBF8);
const ink = Color(0xFF16382E);
// A darker supporting tone than the decorative muted mint, for readable text.
const muted = Color(0xFF526E61);

abstract final class SaveTrackDesign {
  static const onHeroMuted = Color(0xFFE2FFF2);
  static const midnight = Color(0xFF063F34);
  static const emerald = Color(0xFF117B63);
  static const fresh = Color(0xFF48CFA6);
  static const luminous = Color(0xFF75E2BE);
  static const premiumMint = Color(0xFF24A987);
  static const lightMint = Color(0xFFDDF9ED);
  static const mist = Color(0xFFEEFCF5);
  static const textMuted = Color(0xFF91A69A);
  static const divider = Color(0xFFEBF3EF);
  static const info = Color(0xFF326C94);
  static const input = Color(0xFFF8FCFA);
  static const completed = Color(0xFFEDF7F1);
  static const errorSurface = Color(0xFFFFF3F3);
  static const warningSurface = Color(0xFFFFF6E5);
  static const border = Color(0xFFE2EFE8);
  static const error = Color(0xFFB83E48);
  static const warning = Color(0xFF926014);
  static const success = Color(0xFF187F5B);
  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 12.0;
  static const space = 16.0;
  static const section = 24.0;
  static const radius = 22.0;
  static const radiusSmall = 12.0;
  static const radiusMedium = 16.0;
  static const radiusHero = 30.0;
  static const maxWidth = 1080.0;
  static const motion = Duration(milliseconds: 240);
  static const signature = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [midnight, teal, emerald],
    stops: [0, .55, 1],
  );
  static const premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF042E27), midnight, teal],
    stops: [0, .5, 1],
  );
  static const soft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [canvas, Color(0xFFE8F9F0), Color(0xFFD9F6E7)],
  );
  // Bright mint is reserved for accents. Text-bearing gradients stay dark
  // enough for white labels, including their lightest stop.
  static const spectrum = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [midnight, emerald, premiumMint, luminous],
    stops: [0, .35, .72, 1],
  );
  static const glow = LinearGradient(colors: [mint, luminous, fresh]);
  static const surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, Color(0xFFF4FCF8), Color(0xFFEAF9F1)],
  );
  static const progressOnDark = LinearGradient(
    colors: [mint, fresh, premiumMint],
  );
  static const amount = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 38,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const heading = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -.7,
    color: ink,
  );
  static const shadows = [
    BoxShadow(color: Color(0x0D063F34), blurRadius: 28, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x05063F34), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, fontFamily: 'Manrope');
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: border),
    );
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: emerald,
        primary: teal,
        onPrimary: Colors.white,
        secondary: emerald,
        surface: Colors.white,
        onSurface: ink,
        error: error,
        outline: muted,
        outlineVariant: border,
        surfaceContainerHighest: lightMint,
        secondaryContainer: lightMint,
        onSecondaryContainer: teal,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            headlineMedium: heading,
            titleLarge: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -.4,
              color: ink,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.5, color: ink),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.5, color: ink),
            bodySmall: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: muted,
            ),
            labelLarge: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: .1,
            ),
          )
          .apply(fontFamily: 'Manrope'),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: border),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: teal,
        unselectedLabelColor: muted,
        labelStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicator: BoxDecoration(
          color: lightMint,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: lightMint,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        labelStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: teal,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        checkmarkColor: teal,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: emerald, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: const TextStyle(color: muted),
        floatingLabelStyle: const TextStyle(
          color: teal,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: teal,
        suffixIconColor: muted,
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: shape,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: teal,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: lightMint,
        height: 76,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontFamily: 'Manrope',
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? teal : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected) ? teal : muted,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        constraints: const BoxConstraints(maxWidth: 480),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        hourMinuteColor: lightMint,
        hourMinuteTextColor: teal,
        dialBackgroundColor: canvas,
        dialHandColor: teal,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: teal,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.4,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          color: muted,
          height: 1.5,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: teal,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: teal,
        headerForegroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: emerald,
        linearTrackColor: border,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: teal,
        inactiveTrackColor: lightMint,
        thumbColor: teal,
        overlayColor: mint.withValues(alpha: .25),
        trackHeight: 4,
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
    );
  }
}

/// Static light and contour artwork; it never represents financial data.
class _AuroraPainter extends CustomPainter {
  const _AuroraPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Rect.fromCircle(
      center: Offset(size.width * .94, size.height * .12),
      radius: size.width * .72,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x2475E2BE), Color(0x0075E2BE)],
        ).createShader(glow),
    );
    final center = Offset(size.width * 1.07, size.height * .92);
    final stroke = Paint()
      ..color = const Color(0x12A8F0D5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final radius = size.width * (.28 + i * .095);
      canvas.drawCircle(center, radius, stroke);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => false;
}

class AuroraEmblem extends StatelessWidget {
  const AuroraEmblem({super.key, this.size = 40, this.onDark = false});
  final double size;
  final bool onDark;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: onDark ? SaveTrackDesign.glow : SaveTrackDesign.signature,
        borderRadius: BorderRadius.circular(size * .3),
        border: Border.all(color: mint.withValues(alpha: .25)),
      ),
      child: Icon(
        Icons.trending_up_rounded,
        color: onDark ? SaveTrackDesign.midnight : Colors.white,
        size: size * .62,
      ),
    ),
  );
}

/// Quiet surface for balances, form context, and secondary summaries.
class TonalPanel extends StatelessWidget {
  const TonalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      gradient: SaveTrackDesign.surface,
      border: Border.all(color: SaveTrackDesign.border),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

/// Keeps currency strings intact at large text scales. Overflow stays readable
/// through a horizontal gesture and an explicit hint, without shrinking text.
class AmountText extends StatelessWidget {
  const AmountText(
    this.text, {
    super.key,
    required this.style,
    this.onDark = false,
  });
  final String text;
  final TextStyle style;
  final bool onDark;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final resolved = DefaultTextStyle.of(context).style.merge(style);
      final measure = TextPainter(
        text: TextSpan(text: text, style: resolved),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final overflow = measure.width > constraints.maxWidth;
      measure.dispose();
      if (!overflow) return Text(text, style: style);
      final hintColor = onDark ? SaveTrackDesign.onHeroMuted : muted;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(text, style: style, softWrap: false),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.swap_horiz_rounded, color: hintColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Swipe to view full amount',
                  style: TextStyle(color: hintColor, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class AuroraNotice extends StatelessWidget {
  const AuroraNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: error,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? SaveTrackDesign.errorSurface : SaveTrackDesign.mist,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error
              ? SaveTrackDesign.error.withValues(alpha: .18)
              : SaveTrackDesign.border,
        ),
      ),
      child: DetailLine(
        icon: error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
        label: message,
        color: error ? SaveTrackDesign.error : muted,
      ),
    ),
  );
}

class AuroraTabs extends StatelessWidget {
  const AuroraTabs({super.key, required this.tabs});
  final List<Widget> tabs;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: SaveTrackDesign.border),
      borderRadius: BorderRadius.circular(19),
    ),
    child: TabBar(
      isScrollable: MediaQuery.textScalerOf(context).scale(14) > 20,
      tabAlignment: MediaQuery.textScalerOf(context).scale(14) > 20
          ? TabAlignment.center
          : TabAlignment.fill,
      tabs: tabs,
    ),
  );
}

/// Keeps scrollable screens and forms comfortable on phones and wide windows.
class PageSurface extends StatelessWidget {
  const PageSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: canvas,
      gradient: RadialGradient(
        center: Alignment(1, -1),
        radius: 1.6,
        colors: [SaveTrackDesign.lightMint, canvas],
        stops: [0, .75],
      ),
    ),
    child: SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: SaveTrackDesign.maxWidth),
          child: child,
        ),
      ),
    ),
  );
}

class MintHero extends StatelessWidget {
  const MintHero({
    super.key,
    required this.child,
    this.deep = false,
    this.edgeToEdge = false,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final bool deep;
  final bool edgeToEdge;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: deep ? SaveTrackDesign.premium : SaveTrackDesign.signature,
      borderRadius: edgeToEdge
          ? BorderRadius.zero
          : BorderRadius.circular(SaveTrackDesign.radiusHero),
      border: Border.all(color: mint.withValues(alpha: .16)),
      boxShadow: edgeToEdge ? null : SaveTrackDesign.shadows,
    ),
    child: Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _AuroraPainter()),
            ),
          ),
        ),
        Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: IconTheme(
              data: const IconThemeData(color: mint),
              child: child,
            ),
          ),
        ),
      ],
    ),
  );
}

class MintIcon extends StatelessWidget {
  const MintIcon(this.icon, {super.key, this.size = 44, this.color = teal});
  final IconData icon;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: SaveTrackDesign.surface,
      border: Border.all(color: SaveTrackDesign.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color, size: 23),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color = teal});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      border: Border.all(color: color.withValues(alpha: .12)),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class MintProgress extends StatelessWidget {
  const MintProgress({super.key, required this.value, this.onDark = false});
  final double value;
  final bool onDark;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Progress',
    value: '${(value * 100).round()}%',
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : SaveTrackDesign.motion,
      curve: Curves.easeOutCubic,
      builder: (_, progress, _) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Container(
              height: 8,
              color: onDark ? const Color(0x33FFFFFF) : SaveTrackDesign.border,
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0, 1),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: onDark
                      ? SaveTrackDesign.progressOnDark
                      : SaveTrackDesign.spectrum,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.expand = true,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final bool expand;
  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.onPressed == null
        ? null
        : (_) => setState(() => _pressed = true),
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: widget.onPressed == null ? null : SaveTrackDesign.signature,
          color: widget.onPressed == null ? muted : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: widget.onPressed == null ? null : SaveTrackDesign.shadows,
        ),
        child: FilledButton(
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: SaveTrackDesign.onHeroMuted,
            minimumSize: widget.expand
                ? const Size.fromHeight(54)
                : const Size(48, 52),
          ),
          child: widget.child,
        ),
      ),
    ),
  );
}

class ScreenIntro extends StatelessWidget {
  const ScreenIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.detail,
  });
  final String eyebrow, title, detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: SizedBox(
      width: double.infinity,
      child: EnterOnce(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: teal,
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: SaveTrackDesign.heading),
            const SizedBox(height: 6),
            Text(detail, style: const TextStyle(color: muted, height: 1.5)),
          ],
        ),
      ),
    ),
  );
}

/// The tween retains its endpoint across rebuilds, so live data does not
/// replay entrance motion. Reduced-motion users see the final frame directly.
class EnterOnce extends StatelessWidget {
  const EnterOnce({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SaveTrackDesign.motion,
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 8),
        child: child,
      ),
    ),
  );
}

class SaveActionLabel extends StatelessWidget {
  const SaveActionLabel({super.key, required this.busy, required this.label});
  final bool busy;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (busy) ...[
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 8),
      ],
      Flexible(child: Text(busy ? 'Saving' : label)),
    ],
  );
}

/// Disposes controllers only after the dialog's exit transition has unmounted
/// its fields. Popping a route completes its result before that transition.
class FormControllerScope extends StatefulWidget {
  const FormControllerScope({
    super.key,
    required this.controllers,
    required this.child,
  });
  final List<TextEditingController> controllers;
  final Widget child;
  @override
  State<FormControllerScope> createState() => _FormControllerScopeState();
}

class _FormControllerScopeState extends State<FormControllerScope> {
  @override
  Widget build(BuildContext context) => widget.child;
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Embedded states let their enclosing list scroll; standalone states scroll
/// themselves, including in landscape and with large accessibility text.
class StateSurface extends StatelessWidget {
  const StateSurface({super.key, required this.child, required this.padding});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return constraints.hasBoundedHeight
          ? SingleChildScrollView(padding: padding, child: child)
          : Padding(padding: padding, child: child);
    },
  );
}

/// Reflows content without shrinking text or constraining card heights.
class AdaptiveCards extends StatelessWidget {
  const AdaptiveCards({
    super.key,
    required this.children,
    this.breakpoint = 680,
  });
  final List<Widget> children;
  final double breakpoint;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= breakpoint &&
              MediaQuery.textScalerOf(context).scale(14) <= 21
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

/// Lazily builds variable-height rows on phones and pairs on wider screens.
class AdaptiveCardList extends StatelessWidget {
  const AdaptiveCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.header,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget header;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 720 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21
          ? 2
          : 1;
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: (itemCount / columns).ceil() + 1,
        itemBuilder: (context, row) {
          if (row == 0) return header;
          final first = (row - 1) * columns;
          if (columns == 1) return itemBuilder(context, first);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: itemBuilder(context, first)),
              const SizedBox(width: 16),
              Expanded(
                child: first + 1 < itemCount
                    ? itemBuilder(context, first + 1)
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      );
    },
  );
}

class FormHeading extends StatelessWidget {
  const FormHeading({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          MintIcon(icon, size: 48),
          const SizedBox(width: 12),
          const Expanded(child: Divider()),
        ],
      ),
      const SizedBox(height: 20),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(
        detail,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: muted, height: 1.5),
      ),
    ],
  );
}

class FieldCaption extends StatelessWidget {
  const FieldCaption(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: muted,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: .3,
        ),
      ),
    ),
  );
}

class DetailLine extends StatelessWidget {
  const DetailLine({
    super.key,
    required this.icon,
    required this.label,
    this.color = muted,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 13, height: 1.5),
        ),
      ),
    ],
  );
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 72});
  final double value, size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Completion',
    value: '${(value * 100).round()}%',
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(progress),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: teal,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(5);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(bounds, stroke..color = SaveTrackDesign.border);
    if (value > 0) {
      canvas.drawArc(
        bounds,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0, 1),
        false,
        stroke..shader = SaveTrackDesign.spectrum.createShader(bounds),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value;
}

class AuthComposition extends StatelessWidget {
  const AuthComposition({
    super.key,
    required this.brand,
    required this.child,
    this.register = false,
  });
  final Widget brand, child;
  final bool register;
  Widget _showcase({required bool compact}) => MintHero(
    deep: true,
    padding: EdgeInsets.all(compact ? 24 : 36),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AuroraEmblem(size: 40, onDark: true),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'A little closer, every day.',
                style: TextStyle(
                  color: SaveTrackDesign.onHeroMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 24 : 72),
        Text(
          register
              ? 'Big plans.\nStart right here.'
              : 'Small steps.\nBrighter tomorrows.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: compact ? 30 : 42,
            fontWeight: FontWeight.w700,
            height: 1.18,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your financial goals and daily plans, beautifully organized.',
          style: TextStyle(
            color: SaveTrackDesign.onHeroMuted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 48),
          const Divider(color: Color(0x33FFFFFF)),
          const SizedBox(height: 20),
          const DetailLine(
            icon: Icons.flag_outlined,
            label: 'Save for what matters to you.',
            color: SaveTrackDesign.onHeroMuted,
          ),
          const SizedBox(height: 16),
          const DetailLine(
            icon: Icons.event_available_outlined,
            label: 'Make room for a more focused day.',
            color: SaveTrackDesign.onHeroMuted,
          ),
        ],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final form = Padding(
        padding: EdgeInsets.all(wide ? 32 : 4),
        child: child,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          brand,
          const SizedBox(height: 24),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _showcase(compact: false)),
                const SizedBox(width: 32),
                Expanded(child: Card(child: form)),
              ],
            )
          else ...[
            _showcase(compact: true),
            const SizedBox(height: 32),
            form,
          ],
        ],
      );
    },
  );
}
