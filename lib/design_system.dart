import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTheme,
        CupertinoThemeData;

import 'dart:math' as math;

import 'branding/savetrack_logo.dart';

part 'precision_components.dart';
part 'figma_flow_components.dart';
part 'platform_pickers.dart';

const mint = Color(0xFFB7F0D3);
const teal = Color(0xFF236C57);
const canvas = Color(0xFFF6FAF8);
const ink = Color(0xFF202C29);
// A darker supporting tone than the decorative muted mint, for readable text.
const muted = Color(0xFF626F69);

/// Semantic surface and text roles used by every application feature.
extension AtelierColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get atelierInk => Theme.of(this).colorScheme.onSurface;
  Color get atelierMuted => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get atelierAccent => isDark ? Theme.of(this).colorScheme.primary : teal;
  Color get atelierSurface => Theme.of(this).colorScheme.surface;
  Color get atelierCanvas => Theme.of(this).scaffoldBackgroundColor;
  Color get atelierBorder => Theme.of(this).colorScheme.outlineVariant;
  Color get atelierTonal => Theme.of(this).colorScheme.surfaceContainer;
  Color get atelierSelected => Theme.of(this).colorScheme.secondaryContainer;
  Color get atelierInput => Theme.of(this).inputDecorationTheme.fillColor!;
  Color get atelierTrack =>
      isDark ? const Color(0xFF315D50) : const Color(0xFFD8E8E0);
  Color get atelierError => Theme.of(this).colorScheme.error;
  Color get atelierWarning =>
      isDark ? const Color(0xFFFFD38A) : SaveTrackDesign.warning;
  Color atelierColor(Color value) => !isDark
      ? value
      : switch (value) {
          teal ||
          SaveTrackDesign.emerald ||
          SaveTrackDesign.success => atelierAccent,
          ink => atelierInk,
          muted || SaveTrackDesign.textMuted => atelierMuted,
          SaveTrackDesign.error => atelierError,
          SaveTrackDesign.warning => atelierWarning,
          _ => value,
        };
  LinearGradient get atelierSurfaceGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [atelierSurface, atelierTonal],
  );
}

abstract final class SaveTrackDesign {
  static const obsidian = Color(0xFF052F28);
  static const onHeroMuted = Color(0xFFD9F6E9);
  static const midnight = Color(0xFF073F34);
  static const emerald = Color(0xFF13876D);
  // The text-bearing stop is deeper than the accent emerald to meet AA.
  static const heroEnd = Color(0xFF106550);
  static const fresh = Color(0xFF65D5A9);
  static const luminous = Color(0xFF75E7BF);
  static const premiumMint = Color(0xFF26B58E);
  static const lightMint = Color(0xFFDDF5E9);
  static const mist = Color(0xFFF0FAF5);
  static const cloud = Color(0xFFF4FCF8);
  static const textMuted = Color(0xFF91A59A);
  static const divider = Color(0xFFEDF1EF);
  static const info = Color(0xFF326C94);
  static const input = Color(0xFFF4F6F5);
  static const completed = Color(0xFFEDF7F1);
  static const errorSurface = Color(0xFFFFF3F3);
  static const warningSurface = Color(0xFFFFF6E5);
  static const border = Color(0xFFE6EDE9);
  static const elevatedBorder = Color(0xFFD7EAE0);
  static const heroTrack = Color(0x33FFFFFF);
  static const heroSurface = Color(0x14FFFFFF);
  static const heroHighlight = Color(0x2475E7BF);
  static const error = Color(0xFFB83E48);
  static const warning = Color(0xFF80520E);
  static const success = Color(0xFF187F5B);
  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 12.0;
  static const space = 16.0;
  static const spaceLg = 20.0;
  static const section = 24.0;
  static const region = 32.0;
  static const spaceXl = 40.0;
  static const spaceXxl = 48.0;
  static const radius = 20.0;
  static const radiusSmall = 12.0;
  static const radiusMedium = 16.0;
  static const radiusHero = 28.0;
  static const radiusSheet = 28.0;
  static const touchMin = 48.0;
  static const buttonHeight = 52.0;
  static const maxWidth = 1080.0;
  static const pressMotion = Duration(milliseconds: 120);
  static const selectionMotion = Duration(milliseconds: 190);
  static const motion = Duration(milliseconds: 240);
  static const progressMotion = Duration(milliseconds: 420);
  static const motionCurve = Curves.easeOutCubic;
  static const signature = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [midnight, teal, heroEnd],
    stops: [0, .6, 1],
  );
  static const premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [obsidian, midnight, teal],
    stops: [0, .48, 1],
  );
  static const soft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, mist, lightMint],
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
    colors: [Colors.white, cloud, mist],
  );
  static const progressOnDark = LinearGradient(colors: [mint, luminous]);
  static const progressOnLight = LinearGradient(
    colors: [Color(0xFF197C68), Color(0xFF268B67)],
  );
  static const amount = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 38,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const heading = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -.7,
    color: ink,
  );
  static const shadows = [
    BoxShadow(color: Color(0x0B073F34), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static double pageInset(double width) => width < 360 ? space : spaceLg;

  static EdgeInsets pagePadding(double width, {double bottom = spaceXl}) =>
      EdgeInsets.fromLTRB(pageInset(width), spaceMd, pageInset(width), bottom);

  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context)
      ? Duration.zero
      : value;

  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, fontFamily: 'Manrope');
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF7A8D83)),
    );
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: emerald,
        primary: teal,
        onPrimary: Colors.white,
        secondary: teal,
        surface: Colors.white,
        onSurface: ink,
        onSurfaceVariant: muted,
        surfaceContainer: FigmaFlowPalette.neutral,
        surfaceContainerLow: Colors.white,
        error: error,
        errorContainer: errorSurface,
        onErrorContainer: error,
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
            headlineLarge: amount.copyWith(color: ink, fontSize: 44),
            titleLarge: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -.4,
              color: ink,
            ),
            titleMedium: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
            bodyLarge: const TextStyle(fontSize: 17, height: 1.5, color: ink),
            bodyMedium: const TextStyle(fontSize: 15, height: 1.5, color: ink),
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
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide.none,
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
        hintStyle: const TextStyle(color: muted),
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
          backgroundColor: FigmaFlowPalette.mint,
          foregroundColor: ink,
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: shape,
          foregroundColor: teal,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: teal,
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
        backgroundColor: FigmaFlowPalette.mint,
        foregroundColor: ink,
        elevation: 0,
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
        height: 72,
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

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: fresh,
      brightness: Brightness.dark,
      primary: luminous,
      onPrimary: obsidian,
      secondary: fresh,
      onSecondary: obsidian,
      surface: FigmaFlowPalette.darkSurface,
      onSurface: const Color(0xFFEFFAF5),
      onSurfaceVariant: const Color(0xFFB7D4C7),
      surfaceContainerLow: FigmaFlowPalette.darkSurface,
      surfaceContainer: FigmaFlowPalette.darkElevated,
      surfaceContainerHighest: const Color(0xFF355247),
      secondaryContainer: FigmaFlowPalette.darkElevated,
      onSecondaryContainer: mint,
      outlineVariant: const Color(0xFF315D50),
      outline: const Color(0xFF9BB9AA),
      error: const Color(0xFFFFADB4),
      onError: const Color(0xFF650D20),
      errorContainer: const Color(0xFF4A252B),
      onErrorContainer: const Color(0xFFFFADB4),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Manrope',
      colorScheme: scheme,
    );
    return base.copyWith(
      scaffoldBackgroundColor: FigmaFlowPalette.darkCanvas,
      textTheme: theme.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FigmaFlowPalette.darkCanvas,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
      ),
      cardTheme: theme.cardTheme.copyWith(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        fillColor: FigmaFlowPalette.darkCanvas,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: scheme.primary,
        suffixIconColor: scheme.onSurfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6E9F89)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.primary,
        ),
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        textColor: scheme.onSurface,
        iconColor: scheme.primary,
        titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
          color: scheme.onSurface,
        ),
        subtitleTextStyle: theme.listTileTheme.subtitleTextStyle?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      tabBarTheme: theme.tabBarTheme.copyWith(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicator: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: scheme.surface,
        selectedColor: scheme.secondaryContainer,
        labelStyle: theme.chipTheme.labelStyle?.copyWith(
          color: scheme.onSurface,
        ),
        checkmarkColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: theme.dialogTheme.titleTextStyle?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(color: scheme.surface),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      datePickerTheme: theme.datePickerTheme.copyWith(
        backgroundColor: scheme.surface,
        headerBackgroundColor: scheme.surfaceContainer,
        headerForegroundColor: scheme.onSurface,
      ),
      timePickerTheme: theme.timePickerTheme.copyWith(
        backgroundColor: scheme.surface,
        hourMinuteColor: scheme.secondaryContainer,
        hourMinuteTextColor: scheme.onSurface,
        dialBackgroundColor: obsidian,
        dialHandColor: scheme.primary,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.secondaryContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: scheme.onSurface),
      ),
    );
  }
}

class AuroraEmblem extends StatelessWidget {
  const AuroraEmblem({
    super.key,
    this.size = 40,
    this.onDark = false,
    this.animate = false,
  });
  final double size;
  final bool onDark, animate;
  @override
  Widget build(BuildContext context) =>
      SaveTrackLogo(size: size, onDark: onDark, animate: animate);
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
      color: context.atelierTonal,
      border: Border.all(color: context.atelierBorder),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

/// A compact bento cell. Values and labels are supplied by the existing screen.
class AuroraMetricCard extends StatelessWidget {
  const AuroraMetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(SaveTrackDesign.space),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: SaveTrackDesign.amount.copyWith(
                    fontSize: 28,
                    color: context.atelierInk,
                    letterSpacing: -.6,
                  ),
                ),
              ),
              const SizedBox(width: SaveTrackDesign.spaceSm),
              MintIcon(icon, size: 32),
            ],
          ),
          const SizedBox(height: SaveTrackDesign.spaceMd),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

/// Shared analytical surface, deliberately quieter than financial heroes.
class AuroraChartSurface extends StatelessWidget {
  const AuroraChartSurface({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(SaveTrackDesign.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: SaveTrackDesign.spaceMd),
              MintIcon(icon, size: 36),
            ],
          ),
          const SizedBox(height: SaveTrackDesign.space),
          const Divider(height: 1),
          const SizedBox(height: SaveTrackDesign.section),
          child,
        ],
      ),
    ),
  );
}

class AuroraLoadingSurface extends StatelessWidget {
  const AuroraLoadingSurface({
    super.key,
    this.featured = false,
    this.minHeight = 0,
  });
  final bool featured;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    if (featured) {
      return Semantics(
        label: 'Loading savings',
        liveRegion: true,
        child: ExcludeSemantics(
          child: MintHero(
            soft: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined),
                  const SizedBox(height: 32),
                  FractionallySizedBox(
                    widthFactor: .7,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.atelierInk.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FractionallySizedBox(
                    widthFactor: .9,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: context.atelierInk.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: 'Loading content',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Card(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.all(SaveTrackDesign.section),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 140) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MintIcon(Icons.hourglass_empty_rounded, size: 32),
                        const SizedBox(height: 16),
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: context.atelierBorder,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      MintIcon(Icons.hourglass_empty_rounded, size: 44),
                      const SizedBox(width: SaveTrackDesign.space),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FractionallySizedBox(
                              widthFactor: .65,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: context.atelierBorder,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(height: SaveTrackDesign.spaceMd),
                            FractionallySizedBox(
                              widthFactor: .9,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: context.atelierTonal,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: SaveTrackDesign.space),
                      if (SaveTrackDesign.duration(
                            context,
                            SaveTrackDesign.motion,
                          ) !=
                          Duration.zero)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps currency strings intact at large text scales. Overflow stays readable
/// through a horizontal gesture and an explicit hint, without shrinking text.
class AmountText extends StatelessWidget {
  const AmountText(
    this.text, {
    super.key,
    required this.style,
    this.onDark = false,
    this.compactCurrency = false,
    this.stackCurrency = false,
    this.supportingSuffix,
  });
  final String text;
  final TextStyle style;
  final bool onDark;
  final bool compactCurrency;
  final bool stackCurrency;
  final String? supportingSuffix;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final resolved = DefaultTextStyle.of(context).style.merge(style);
      // Only typographic emphasis changes; the formatter's exact string,
      // currency, signs and decimals remain intact, including in semantics.
      final prefix = compactCurrency
          ? RegExp(r'^[^0-9]+').stringMatch(text)
          : null;
      final suffix =
          supportingSuffix != null && text.endsWith(supportingSuffix!)
          ? supportingSuffix!
          : '';
      if (stackCurrency && prefix != null && prefix.length < text.length) {
        return Semantics(
          label: text,
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prefix.trim(),
                style: resolved.copyWith(
                  fontSize: (resolved.fontSize ?? 24) * .55,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              AmountText(text.substring(prefix.length), style: resolved),
            ],
          ),
        );
      }
      final span = prefix == null || prefix.length == text.length
          ? TextSpan(text: text, style: resolved)
          : TextSpan(
              style: resolved,
              children: [
                TextSpan(
                  text: prefix,
                  style: TextStyle(
                    fontSize: (resolved.fontSize ?? 38) * .55,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                TextSpan(
                  text: text.substring(
                    prefix.length,
                    text.length - suffix.length,
                  ),
                ),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: suffix,
                    style: TextStyle(
                      fontSize: (resolved.fontSize ?? 28) * .55,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            );
      final measure = TextPainter(
        text: span,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final overflow = measure.width > constraints.maxWidth;
      measure.dispose();
      Widget figure({bool? softWrap}) => compactCurrency
          ? Text.rich(span, softWrap: softWrap)
          : Text(text, style: style, softWrap: softWrap);
      if (!overflow) return figure();
      // Let the currency move onto its own line before requiring horizontal
      // scrolling. The exact formatted value remains one accessibility value.
      if (compactCurrency && prefix != null && prefix.length < text.length) {
        final digits = text.substring(prefix.length);
        final digitsMeasure = TextPainter(
          text: TextSpan(text: digits, style: resolved),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fits = digitsMeasure.width <= constraints.maxWidth;
        digitsMeasure.dispose();
        if (fits) {
          return Semantics(
            label: text,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prefix.trim(), style: resolved.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(digits, style: resolved),
              ],
            ),
          );
        }
      }
      final hintColor = onDark
          ? SaveTrackDesign.onHeroMuted
          : context.atelierMuted;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: figure(softWrap: false),
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
  const AuroraNotice(this.message, {super.key, this.error = false, this.icon});
  final String message;
  final bool error;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: error,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error
            ? Theme.of(context).colorScheme.errorContainer
            : context.atelierTonal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error
              ? context.atelierError.withValues(alpha: .18)
              : context.atelierBorder,
        ),
      ),
      child: DetailLine(
        icon:
            icon ??
            (error ? Icons.error_outline_rounded : Icons.info_outline_rounded),
        label: message,
        color: error ? context.atelierError : context.atelierMuted,
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
      color: context.atelierSurface,
      border: Border.all(color: context.atelierBorder),
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
    decoration: BoxDecoration(color: context.atelierCanvas),
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
    this.soft = false,
    this.edgeToEdge = false,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final bool deep, soft;
  final bool edgeToEdge;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: soft ? context.flowHero : null,
      gradient: soft
          ? null
          : deep
          ? SaveTrackDesign.premium
          : SaveTrackDesign.signature,
      borderRadius: edgeToEdge
          ? BorderRadius.zero
          : BorderRadius.circular(SaveTrackDesign.radiusHero),
      border: Border.all(color: mint.withValues(alpha: .16)),
    ),
    child: Stack(
      children: [
        Positioned(
          top: -80,
          right: -70,
          child: ExcludeSemantics(
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [SaveTrackDesign.heroHighlight, Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: soft ? context.atelierInk : Colors.white),
            child: IconTheme(
              data: IconThemeData(color: soft ? context.atelierInk : mint),
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
      color: context.atelierTonal,
      borderRadius: BorderRadius.circular(SaveTrackDesign.radiusSmall),
    ),
    child: Icon(icon, color: context.atelierColor(color), size: 23),
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
      color: context.atelierColor(color).withValues(alpha: .08),
      border: Border.all(
        color: context.atelierColor(color).withValues(alpha: .12),
      ),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.atelierColor(color),
      ),
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
      tween: Tween(begin: value, end: value),
      duration: SaveTrackDesign.duration(
        context,
        SaveTrackDesign.progressMotion,
      ),
      curve: SaveTrackDesign.motionCurve,
      builder: (_, progress, _) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Container(
              height: 8,
              color: onDark ? SaveTrackDesign.heroTrack : context.atelierTrack,
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0, 1),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: onDark
                      ? SaveTrackDesign.progressOnDark
                      : context.isDark
                      ? SaveTrackDesign.progressOnDark
                      : SaveTrackDesign.progressOnLight,
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
      duration: SaveTrackDesign.duration(context, SaveTrackDesign.pressMotion),
      curve: SaveTrackDesign.motionCurve,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.onPressed == null
              ? context.atelierTonal
              : context.flowAction,
          borderRadius: BorderRadius.circular(16),
        ),
        child: FilledButton(
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: context.flowOnAction,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: context.atelierMuted,
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.atelierAccent,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => Text(
                title,
                style: SaveTrackDesign.heading
                    .copyWith(color: context.atelierInk)
                    .copyWith(fontSize: constraints.maxWidth < 340 ? 26 : 29),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(color: context.atelierMuted, height: 1.5),
            ),
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
    duration: SaveTrackDesign.duration(context, SaveTrackDesign.motion),
    curve: SaveTrackDesign.motionCurve,
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
  const SaveActionLabel({
    super.key,
    required this.busy,
    required this.label,
    this.busyLabel = 'Saving',
  });
  final bool busy;
  final String label, busyLabel;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (busy) ...[
        SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.atelierAccent,
          ),
        ),
        const SizedBox(width: 8),
      ],
      Flexible(child: Text(busy ? busyLabel : label)),
    ],
  );
}

/// Disposes controllers only after the dialog's exit transition has unmounted
/// its fields. Popping a route completes its result before that transition.
/// Protects local form edits. Successful saves retain their existing close path.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.controllers,
    required this.child,
    this.hasChanges,
    this.busy = false,
    this.enabled = true,
  });
  final List<TextEditingController> controllers;
  final Widget child;
  final bool Function()? hasChanges;
  final bool busy, enabled;
  @override
  State<UnsavedChangesGuard> createState() => UnsavedChangesGuardState();
}

class UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  late final initial = widget.controllers.map((c) => c.text).toList();
  bool asking = false, approved = false;
  bool get dirty =>
      widget.enabled &&
      ((widget.hasChanges?.call() ?? false) ||
          widget.controllers.indexed.any(
            (entry) => entry.$2.text != initial[entry.$1],
          ));
  @override
  void initState() {
    super.initState();
    for (final c in widget.controllers) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in widget.controllers) {
      c.removeListener(_changed);
    }
    super.dispose();
  }

  Future<void> requestClose() async {
    if (asking || widget.busy) return;
    if (!dirty || approved) {
      Navigator.pop(context);
      return;
    }
    asking = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved edits will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    asking = false;
    if (discard != true || !mounted) return;
    setState(() => approved = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.busy && (!dirty || approved),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !widget.busy) requestClose();
    },
    child: widget.child,
  );
}

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
        padding: SaveTrackDesign.pagePadding(constraints.maxWidth, bottom: 100),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintIcon(icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(detail, style: Theme.of(context).textTheme.bodySmall),
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
        style: TextStyle(
          color: context.atelierMuted,
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
        child: Icon(icon, size: 16, color: context.atelierColor(color)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: context.atelierColor(color),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    ],
  );
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 72,
    this.onDark = false,
  });
  final double value, size;
  final bool onDark;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Completion',
    value: '${(value * 100).round()}%',
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: SaveTrackDesign.duration(
        context,
        SaveTrackDesign.progressMotion,
      ),
      curve: SaveTrackDesign.motionCurve,
      builder: (context, progress, _) => SizedBox.square(
        dimension:
            size *
            (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1, 1.7),
        child: CustomPaint(
          painter: _RingPainter(
            progress,
            track: onDark ? SaveTrackDesign.heroTrack : context.atelierTrack,
            gradient: onDark || context.isDark
                ? SaveTrackDesign.progressOnDark
                : SaveTrackDesign.progressOnLight,
          ),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: onDark ? Colors.white : context.atelierAccent,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
  const _RingPainter(this.value, {required this.track, required this.gradient});
  final double value;
  final Color track;
  final LinearGradient gradient;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(6);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(bounds, stroke..color = track);
    if (value > 0) {
      canvas.drawArc(
        bounds,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0, 1),
        false,
        stroke..shader = gradient.createShader(bounds),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.track != track ||
      oldDelegate.gradient != gradient;
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
  Widget _showcase(BuildContext context, {required bool compact}) => MintHero(
    soft: true,
    padding: EdgeInsets.all(compact ? 24 : 36),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AuroraEmblem(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'A little closer, every day.',
                style: TextStyle(color: context.atelierInk, fontSize: 12),
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
        Text(
          'Your financial goals and daily plans, beautifully organized.',
          style: TextStyle(
            color: context.atelierInk,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 48),
          const Divider(color: SaveTrackDesign.heroTrack),
          const SizedBox(height: 20),
          DetailLine(
            icon: Icons.flag_outlined,
            label: 'Save for what matters to you.',
            color: context.atelierInk,
          ),
          const SizedBox(height: 16),
          DetailLine(
            icon: Icons.event_available_outlined,
            label: 'Make room for a more focused day.',
            color: context.atelierInk,
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
        padding: EdgeInsets.all(wide ? 32 : 0),
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
                Expanded(child: _showcase(context, compact: false)),
                const SizedBox(width: 32),
                Expanded(child: Card(child: form)),
              ],
            )
          else ...[
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: context.flowCategory(FlowAccent.mint),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your progress, beautifully in flow.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const FlowSavingsArt(size: 84),
                ],
              ),
            ),
            form,
          ],
        ],
      );
    },
  );
}
