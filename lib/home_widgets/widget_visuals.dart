import 'package:flutter/material.dart';

import 'widget_models.dart';

enum WidgetPreviewSize { compact, medium, expanded }

String widgetTypeName(HomeWidgetType type) => switch (type) {
  HomeWidgetType.goal => 'Savings Goal',
  HomeWidgetType.planner => "Today's Planner",
  HomeWidgetType.quickSave => 'Quick Save',
  HomeWidgetType.today => 'Today Overview',
};

String widgetTypeDescription(HomeWidgetType type) => switch (type) {
  HomeWidgetType.goal => 'Your next milestone, always in view.',
  HomeWidgetType.planner => 'Today’s progress and what comes next.',
  HomeWidgetType.quickSave => 'Start a save. Review and confirm in the app.',
  HomeWidgetType.today => 'Savings and daily focus, together.',
};

String widgetPrivacyName(WidgetPrivacy privacy) => switch (privacy) {
  WidgetPrivacy.full => 'Full Details',
  WidgetPrivacy.progress => 'Progress Only',
  WidgetPrivacy.hidden => 'Hide Private Details',
};

String widgetThemeName(WidgetTheme theme) => switch (theme) {
  WidgetTheme.emerald => 'Dark',
  WidgetTheme.mint => 'Light',
  WidgetTheme.white => 'White',
  WidgetTheme.system => 'System',
};

IconData widgetTypeIcon(HomeWidgetType type) => switch (type) {
  HomeWidgetType.goal => Icons.savings_outlined,
  HomeWidgetType.planner => Icons.event_note_rounded,
  HomeWidgetType.quickSave => Icons.add_circle_outline,
  HomeWidgetType.today => Icons.dashboard_outlined,
};

/// Widget-only tokens mirror the native WidgetVisualTokens contract.
class WidgetAtelierPalette {
  const WidgetAtelierPalette(this.dark, {this.white = false});
  final bool dark, white;
  factory WidgetAtelierPalette.resolve(
    WidgetTheme? preference,
    HomeWidgetType type,
    Brightness brightness,
  ) => WidgetAtelierPalette(switch (preference) {
    WidgetTheme.emerald => true,
    WidgetTheme.mint || WidgetTheme.white => false,
    WidgetTheme.system => brightness == Brightness.dark,
    null => type != HomeWidgetType.planner,
  }, white: preference == WidgetTheme.white);
  Color get background => white
      ? Colors.white
      : dark
      ? const Color(0xFF073F34)
      : const Color(0xFFEDFAF3);
  Color get surface => dark ? const Color(0xFF165346) : Colors.white;
  Color get secondarySurface =>
      dark ? const Color(0xFF0B5B4B) : const Color(0xFFE3F5EA);
  Color get text => dark ? Colors.white : const Color(0xFF14362B);
  Color get secondary =>
      dark ? const Color(0xFFDCF8EB) : const Color(0xFF526E61);
  Color get accent => dark ? const Color(0xFF75E7BF) : const Color(0xFF13876D);
  Color get track => dark ? const Color(0xFF286A5B) : const Color(0xFFD6EDE0);
  Color get action => dark ? const Color(0xFF4BD4A8) : const Color(0xFF0F745D);
  Color get onAction => dark ? const Color(0xFF052F28) : Colors.white;
  Color get border => dark ? const Color(0xFF286A5B) : const Color(0xFFD5EEDF);
  Gradient? get gradient => dark
      ? const LinearGradient(
          colors: [Color(0xFF052F28), Color(0xFF073F34), Color(0xFF0B5B4B)],
        )
      : null;
}
