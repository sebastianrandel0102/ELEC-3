import 'package:flutter/material.dart';

import 'dart:math' as math;

const mint = Color(0xFFA8EDD5);
const teal = Color(0xFF0D5C4B);
const canvas = Color(0xFFF5FBF8);
const ink = Color(0xFF19382E);
const muted = Color(0xFF536F62);

abstract final class SaveTrackDesign {
  static const onHeroMuted = Color(0xFFE2FFF2);
  static const emerald = Color(0xFF137C63);
  static const fresh = Color(0xFF63DBB4);
  static const premiumMint = Color(0xFF31B995);
  static const lightMint = Color(0xFFDDF8EE);
  static const input = Color(0xFFF8FCFA);
  static const completed = Color(0xFFEDF7F1);
  static const errorSurface = Color(0xFFFFF3F3);
  static const warningSurface = Color(0xFFFFF6E5);
  static const border = Color(0xFFE2EEE8);
  static const error = Color(0xFFB83E48);
  static const warning = Color(0xFF926014);
  static const success = Color(0xFF239B72);
  static const space = 16.0;
  static const section = 24.0;
  static const radius = 22.0;
  static const maxWidth = 1080.0;
  static const motion = Duration(milliseconds: 240);
  static const signature = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, Color(0xFF116A54), emerald],
  );
  static const premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF073D33), teal, emerald],
  );
  static const soft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [canvas, Color(0xFFE8F8F0), lightMint],
  );
  // Bright mint is reserved for accents. Text-bearing gradients stay dark
  // enough for white labels, including their lightest stop.
  static const spectrum = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, Color(0xFF148B70), premiumMint, fresh],
  );
  static const progressOnDark = LinearGradient(
    colors: [mint, fresh, premiumMint],
  );
  static const amount = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const heading = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -.7,
    color: ink,
  );
  static const shadows = [
    BoxShadow(color: Color(0x14145C4B), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true);
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
          ),
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
            fontSize: 11,
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
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }
}

/// Keeps scrollable screens and forms comfortable on phones and wide windows.
class PageSurface extends StatelessWidget {
  const PageSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: SaveTrackDesign.soft),
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
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final bool deep;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: deep ? SaveTrackDesign.premium : SaveTrackDesign.signature,
      borderRadius: BorderRadius.circular(28),
      boxShadow: SaveTrackDesign.shadows,
    ),
    child: Stack(
      children: [
        Positioned(
          right: -64,
          top: -88,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x0FFFFFFF), width: 40),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: -12,
          bottom: -112,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x08FFFFFF), width: 1),
                ),
              ),
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
  const MintIcon(this.icon, {super.key, this.size = 44});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: SaveTrackDesign.lightMint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: teal, size: 23),
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
            ShaderMask(
              shaderCallback: (bounds) =>
                  (onDark
                          ? SaveTrackDesign.progressOnDark
                          : SaveTrackDesign.spectrum)
                      .createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.transparent,
                color: Colors.white,
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
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: .2,
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
      MintIcon(icon, size: 48),
      const SizedBox(height: 16),
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
    padding: EdgeInsets.all(compact ? 20 : 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          const Icon(Icons.savings_outlined, size: 44),
          const SizedBox(height: 48),
        ],
        Text(
          register
              ? 'Big plans.\nStart right here.'
              : 'Small steps.\nBrighter tomorrows.',
          style: TextStyle(
            fontSize: compact ? 24 : 38,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'A little intention, every day.',
          style: TextStyle(color: SaveTrackDesign.onHeroMuted),
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
      final form = Card(
        child: Padding(padding: EdgeInsets.all(wide ? 32 : 24), child: child),
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
                Expanded(child: form),
              ],
            )
          else ...[
            _showcase(compact: true),
            const SizedBox(height: 20),
            form,
          ],
        ],
      );
    },
  );
}
