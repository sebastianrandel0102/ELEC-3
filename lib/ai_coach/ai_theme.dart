import 'package:flutter/material.dart';

import '../design_system.dart';

/// Conversation Atelier roles extend the app's existing Mint Aurora palette.
/// Appearance always comes from SaveTrack's global theme.
extension AiConversationTheme on BuildContext {
  Color get aiUserSurface => isDark ? atelierSelected : FigmaFlowPalette.soft;
  Color get aiOnUser => atelierInk;
  Color get aiInputSurface => atelierSurface;
  Color get aiAssistantSurface => atelierSurface;
  Color get aiAction => atelierAccent;
  Color get aiOnAction => Theme.of(this).colorScheme.onPrimary;
  Color get aiDisabled => atelierTonal;
  Color get aiOnDisabled => atelierMuted;
}

abstract final class AiLayout {
  static const conversationWidth = 760.0;
  static const composerRadius = 24.0;
  static const bubbleRadius = SaveTrackDesign.radius;
  static const readingStyle = TextStyle(fontSize: 17, height: 1.65);
}
