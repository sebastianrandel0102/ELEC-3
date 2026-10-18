import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system.dart';
import 'ai_domain.dart';
import 'ai_response.dart';
import 'ai_theme.dart';
import 'ai_widgets.dart';

class AiComposer extends StatelessWidget {
  const AiComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.mode,
    required this.busy,
    required this.blocked,
    required this.compact,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AiMode mode;
  final bool busy, blocked, compact;
  final VoidCallback onSend, onStop;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, focusNode]),
    builder: (context, _) {
      final ready = !busy && !blocked && controller.text.trim().isNotEmpty;
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
            if (ready) onSend();
          },
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
            if (ready) onSend();
          },
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: SaveTrackDesign.duration(
                context,
                SaveTrackDesign.pressMotion,
              ),
              decoration: BoxDecoration(
                color: context.aiInputSurface,
                borderRadius: BorderRadius.circular(AiLayout.composerRadius),
                border: Border.all(
                  color: focusNode.hasFocus
                      ? context.aiAction
                      : context.atelierBorder,
                ),
                boxShadow: context.isDark ? null : SaveTrackDesign.shadows,
              ),
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: compact ? 2 : 5,
                      maxLength: AiConfig.maxQuestionCharacters,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      style: AiLayout.readingStyle.copyWith(
                        color: context.atelierInk,
                        height: compact ? 1.4 : 1.75,
                      ),
                      decoration: InputDecoration(
                        hintText: mode == AiMode.askAnything
                            ? 'Ask SaveTrack AI anything…'
                            : 'Ask about your savings plan…',
                        hintStyle: TextStyle(
                          color: context.atelierMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: compact ? 8 : 14,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: IconButton.filled(
                      tooltip: busy ? 'Stop response' : 'Send question',
                      style: IconButton.styleFrom(
                        backgroundColor: context.aiAction,
                        foregroundColor: context.aiOnAction,
                        disabledBackgroundColor: context.aiDisabled,
                        disabledForegroundColor: context.aiOnDisabled,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: busy
                          ? onStop
                          : ready
                          ? onSend
                          : null,
                      icon: Icon(
                        busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!compact)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'AI can make mistakes. Keep sensitive details out of chat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.atelierMuted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Small entrance animation runs once per message, never once per token.
class AiMessageEntrance extends StatelessWidget {
  const AiMessageEntrance({super.key, required this.child});
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
        offset: Offset(0, 8 * (1 - value)),
        child: child,
      ),
    ),
  );
}

class AiConversationMessage extends StatelessWidget {
  const AiConversationMessage({super.key, required this.message});
  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == AiRole.user;
    if (!user &&
        message.text.trim().isEmpty &&
        message.status != AiMessageStatus.streaming) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: user ? 8 : 4, bottom: user ? 24 : 20),
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: user ? .86 : 1,
          child: user
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: context.aiUserSurface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AiLayout.bubbleRadius),
                      topRight: Radius.circular(AiLayout.bubbleRadius),
                      bottomLeft: Radius.circular(AiLayout.bubbleRadius),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: SelectableText(
                    message.text,
                    style: AiLayout.readingStyle.copyWith(
                      color: context.aiOnUser,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const AiEmblem(size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SaveTrack AI',
                            style: TextStyle(
                              color: context.atelierInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (message.status == AiMessageStatus.streaming &&
                        message.text.isEmpty)
                      const AiThinkingIndicator()
                    else
                      AiMarkdownResponse(
                        text: message.text,
                        streaming: message.status == AiMessageStatus.streaming,
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            switch (message.status) {
                              AiMessageStatus.streaming => 'Writing…',
                              AiMessageStatus.canceled =>
                                'Stopped · partial answer',
                              AiMessageStatus.failed =>
                                'Incomplete · AI-generated',
                              AiMessageStatus.complete =>
                                'AI-generated · verify important details',
                            },
                            style: TextStyle(
                              color: context.atelierMuted,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (message.text.isNotEmpty &&
                            message.status != AiMessageStatus.streaming)
                          IconButton(
                            tooltip: 'Copy answer',
                            onPressed: () => copyAiText(context, message.text),
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 17,
                              color: context.atelierMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AiThinkingIndicator extends StatefulWidget {
  const AiThinkingIndicator({super.key});
  @override
  State<AiThinkingIndicator> createState() => _AiThinkingIndicatorState();
}

class _AiThinkingIndicatorState extends State<AiThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SaveTrackDesign.duration(context, SaveTrackDesign.motion) ==
        Duration.zero) {
      _animation.stop();
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Working on your response',
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.aiAction.withValues(
                          alpha:
                              .35 +
                              .65 *
                                  (math.sin(
                                        _animation.value * math.pi * 2 - i * .7,
                                      ) +
                                      1) /
                                  2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Thinking…',
              style: TextStyle(color: context.atelierMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

class AiFollowUpSuggestions extends StatelessWidget {
  const AiFollowUpSuggestions({super.key, required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final question in ['Show an example.', 'Explain more simply.'])
          ActionChip(
            avatar: Icon(
              Icons.subdirectory_arrow_right_rounded,
              size: 16,
              color: context.aiAction,
            ),
            label: Text(question),
            onPressed: () => onSelected(question),
            backgroundColor: context.atelierSurface,
            labelStyle: Theme.of(context).textTheme.labelMedium!
                .copyWith(color: context.atelierInk, fontSize: 12),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
      ],
    ),
  );
}

class AiErrorNotice extends StatelessWidget {
  const AiErrorNotice({
    super.key,
    required this.failure,
    this.actionLabel,
    this.onAction,
  });
  final AiFailure failure;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = Text(
            failure.message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontSize: 12,
              height: 1.5,
            ),
          );
          final action = actionLabel == null
              ? null
              : TextButton(onPressed: onAction, child: Text(actionLabel!));
          if (constraints.maxWidth < 320 &&
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                text,
                if (action != null)
                  Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              ?action,
            ],
          );
        },
      ),
    ),
  );
}
