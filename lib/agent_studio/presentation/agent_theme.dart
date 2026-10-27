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
    final base = brightness == Brightness.dark
        ? SaveTrackDesign.darkTheme
        : SaveTrackDesign.theme;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        surfaceContainerLow: base.colorScheme.surface,
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
