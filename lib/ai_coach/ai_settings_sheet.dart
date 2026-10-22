import 'package:flutter/material.dart';

import '../atelier_preferences.dart';
import '../design_system.dart';
import 'ai_domain.dart';
import 'ai_widgets.dart';

Future<void> showAiSettings(
  BuildContext context, {
  required AiMode mode,
  required ValueChanged<AiMode> onModeChanged,
  required VoidCallback onPrivacy,
}) {
  final preferences = AtelierScope.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.atelierSurface,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _AiSettingsSheet(
      mode: mode,
      preferences: preferences,
      onModeChanged: onModeChanged,
      onPrivacy: onPrivacy,
    ),
  );
}

class _AiSettingsSheet extends StatefulWidget {
  const _AiSettingsSheet({
    required this.mode,
    required this.preferences,
    required this.onModeChanged,
    required this.onPrivacy,
  });
  final AiMode mode;
  final AtelierPreferences? preferences;
  final ValueChanged<AiMode> onModeChanged;
  final VoidCallback onPrivacy;
  @override
  State<_AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<_AiSettingsSheet> {
  late AiMode _mode = widget.mode;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const AiEmblem(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Make this space yours',
                  style: TextStyle(
                    color: context.atelierInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close settings',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _heading(context, 'CONVERSATION MODE'),
          const SizedBox(height: 12),
          AiModeSelector(
            mode: _mode,
            onChanged: (mode) {
              setState(() => _mode = mode);
              widget.onModeChanged(mode);
            },
          ),
          const SizedBox(height: 12),
          Text(
            _mode == AiMode.askAnything
                ? 'Explore general questions and ideas. No SaveTrack records are shared.'
                : 'Read-only guidance. Only a summary you review and approve can be shared; exact financial facts stay on your device.',
            style: TextStyle(
              color: context.atelierMuted,
              fontSize: 13,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 24),
          _heading(context, 'APPEARANCE'),
          const SizedBox(height: 8),
          if (widget.preferences case final preferences?)
            ListenableBuilder(
              listenable: preferences,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final mode in [
                    ThemeMode.light,
                    ThemeMode.dark,
                    ThemeMode.system,
                  ])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      titleTextStyle: _titleStyle(context),
                      leading: Icon(switch (mode) {
                        ThemeMode.light => Icons.light_mode_outlined,
                        ThemeMode.dark => Icons.dark_mode_outlined,
                        ThemeMode.system => Icons.brightness_auto_outlined,
                      }),
                      title: Text(switch (mode) {
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                        ThemeMode.system => 'Follow system',
                      }),
                      trailing: preferences.appearance == mode
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: context.atelierAccent,
                            )
                          : null,
                      selected: preferences.appearance == mode,
                      onTap: () async {
                        preferences.appearance = mode;
                        await preferences.save();
                      },
                    ),
                  if (preferences.error != null)
                    Text(
                      preferences.error!,
                      style: TextStyle(
                        color: context.atelierError,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            )
          else
            Text(
              'Follows your SaveTrack appearance preference.',
              style: TextStyle(color: context.atelierMuted, height: 1.6),
            ),
          const SizedBox(height: 24),
          _heading(context, 'YOUR CONVERSATIONS'),
          const SizedBox(height: 12),
          _information(
            context,
            Icons.chat_bubble_outline_rounded,
            'Here for this visit',
            'Each mode keeps its own conversation while this screen is open. Chats are cleared when you leave or sign out.',
          ),
          const SizedBox(height: 16),
          _information(
            context,
            Icons.translate_rounded,
            'Use your own words',
            'Ask in English, Filipino or Taglish. You can request a language or a shorter answer in your question.',
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            titleTextStyle: _titleStyle(context),
            subtitleTextStyle: TextStyle(
              inherit: false,
              fontFamily: 'Manrope',
              color: context.atelierMuted,
              fontSize: 13,
              height: 1.6,
            ),
            leading: Icon(Icons.shield_outlined, color: context.atelierAccent),
            title: const Text('AI privacy'),
            subtitle: const Text(
              'Review Google processing and your notice preference.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pop(context);
              widget.onPrivacy();
            },
          ),
        ],
      ),
    ),
  );

  Widget _heading(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: context.atelierMuted,
      fontSize: 10,
      letterSpacing: 1.5,
      fontWeight: FontWeight.w700,
    ),
  );

  // Keep typography consistent while the app animates between its themes.
  TextStyle _titleStyle(BuildContext context) => TextStyle(
    inherit: false,
    fontFamily: 'Manrope',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: context.atelierInk,
  );

  Widget _information(
    BuildContext context,
    IconData icon,
    String title,
    String detail,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: context.atelierAccent, size: 20),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.atelierInk,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(
                color: context.atelierMuted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
