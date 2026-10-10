import 'package:flutter/material.dart';

const mint = Color(0xFFB8F3DF);
const teal = Color(0xFF145C4B);
const canvas = Color(0xFFF0FAF6);
const ink = Color(0xFF18352D);
const muted = Color(0xFF576F64);

abstract final class SaveTrackDesign {
  static const onHeroMuted = Color(0xFFE2FFF2);
  static const emerald = Color(0xFF167D65);
  static const fresh = Color(0xFF72E0BF);
  static const border = Color(0xFFE2EEE8);
  static const error = Color(0xFFB83E48);
  static const warning = Color(0xFF926014);
  static const success = Color(0xFF239B72);
  static const space = 16.0;
  static const section = 24.0;
  static const radius = 22.0;
  static const maxWidth = 760.0;
  static const motion = Duration(milliseconds: 240);
  static const signature = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, Color(0xFF166F59), emerald],
  );
  static const premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF103E34), teal, emerald],
  );
  static const soft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE4F7EE), Color(0xFFF8FCFA)],
  );
  static const amount = TextStyle(
    fontSize: 34,
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
            bodyMedium: const TextStyle(fontSize: 14, height: 1.45, color: ink),
            bodySmall: const TextStyle(fontSize: 12, height: 1.4, color: muted),
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
        fillColor: const Color(0xFFF8FCFA),
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
        indicatorColor: mint,
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
  const MintHero({super.key, required this.child, this.deep = false});
  final Widget child;
  final bool deep;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: deep ? SaveTrackDesign.premium : SaveTrackDesign.signature,
      borderRadius: BorderRadius.circular(28),
      boxShadow: SaveTrackDesign.shadows,
    ),
    child: Stack(
      children: [
        Positioned(
          right: -36,
          top: -60,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x06FFFFFF), width: 24),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
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
      gradient: SaveTrackDesign.soft,
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
      builder: (_, progress, _) => LinearProgressIndicator(
        value: progress,
        minHeight: 8,
        borderRadius: BorderRadius.circular(8),
        backgroundColor: onDark
            ? const Color(0x33FFFFFF)
            : SaveTrackDesign.border,
        color: onDark ? SaveTrackDesign.fresh : SaveTrackDesign.emerald,
      ),
    ),
  );
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
  });
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: onPressed == null ? null : SaveTrackDesign.signature,
      color: onPressed == null ? teal : null,
      borderRadius: BorderRadius.circular(16),
    ),
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        disabledForegroundColor: SaveTrackDesign.onHeroMuted,
        minimumSize: const Size.fromHeight(54),
      ),
      child: child,
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: teal,
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: SaveTrackDesign.heading),
        const SizedBox(height: 6),
        Text(detail, style: const TextStyle(color: muted, height: 1.5)),
      ],
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
          child: CircularProgressIndicator(strokeWidth: 2, color: teal),
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
