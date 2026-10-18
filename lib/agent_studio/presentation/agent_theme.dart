import 'package:flutter/material.dart';

import '../../design_system.dart';
import '../agent_engine.dart';

/// Agent Atelier extends SaveTrack's existing palette, typeface and motion scale.
abstract final class AgentAtelier {
  static const gap = SaveTrackDesign.space;
  static const section = SaveTrackDesign.section;
  static const radius = SaveTrackDesign.radius;
  static const readingWidth = 780.0;

  static final _light = _build(Brightness.light);
  static final _dark = _build(Brightness.dark);
  static ThemeData theme(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = SaveTrackDesign.theme;
    final colors = ColorScheme.fromSeed(
      seedColor: SaveTrackDesign.emerald,
      brightness: brightness,
      primary: dark ? mint : teal,
      onPrimary: dark ? SaveTrackDesign.obsidian : Colors.white,
      secondary: dark ? SaveTrackDesign.luminous : teal,
      onSecondary: dark ? SaveTrackDesign.obsidian : Colors.white,
      surface: dark ? const Color(0xFF071F1B) : canvas,
      onSurface: dark ? const Color(0xFFF0F8F3) : ink,
      onSurfaceVariant: dark ? const Color(0xFFB1C9BD) : muted,
      surfaceContainerLow: dark ? const Color(0xFF0D2C25) : Colors.white,
      surfaceContainer: dark ? const Color(0xFF12382E) : SaveTrackDesign.mist,
      surfaceContainerHighest: dark
          ? const Color(0xFF1C4438)
          : SaveTrackDesign.lightMint,
      outline: dark ? const Color(0xFF94B5A5) : muted,
      outlineVariant: dark
          ? const Color(0xFF35594C)
          : SaveTrackDesign.elevatedBorder,
      error: dark ? const Color(0xFFFFB4B8) : SaveTrackDesign.error,
      secondaryContainer: dark
          ? const Color(0xFF204C3C)
          : SaveTrackDesign.lightMint,
      onSecondaryContainer: dark ? mint : teal,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SaveTrackDesign.radiusMedium),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return base.copyWith(
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      textTheme: base.textTheme.apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        iconTheme: IconThemeData(color: colors.onSurface),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: colors.onSurface,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: colors.surfaceContainerLow,
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.outlineVariant),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surfaceContainerLow,
        selectedColor: colors.secondaryContainer,
        labelStyle: base.chipTheme.labelStyle?.copyWith(
          color: colors.onSurface,
        ),
        checkmarkColor: colors.primary,
        side: BorderSide(color: colors.outlineVariant),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: colors.onSurface,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: colors.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dividerColor: colors.outlineVariant,
      listTileTheme: ListTileThemeData(
        textColor: colors.onSurface,
        iconColor: colors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

/// Each Navigator route gets the same persisted appearance preference.
class AgentAtelierScope extends StatelessWidget {
  const AgentAtelierScope({
    super.key,
    required this.engine,
    required this.child,
    this.voice = false,
  });
  final AgentEngine engine;
  final Widget child;
  final bool voice;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final brightness = voice
          ? Brightness.dark
          : switch (engine.settings.appearance) {
              'light' => Brightness.light,
              'dark' => Brightness.dark,
              _ => MediaQuery.platformBrightnessOf(context),
            };
      return Theme(data: AgentAtelier.theme(brightness), child: child);
    },
  );
}
