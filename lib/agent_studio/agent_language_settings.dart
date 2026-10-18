import 'package:flutter/material.dart';

import 'presentation/agent_theme.dart';

import 'agent_domain.dart';
import 'agent_engine.dart';
import 'agent_voice.dart';
import 'intelligence/agent_language.dart';
import 'intelligence/voice_locale_repository.dart';

class AgentLanguageSettingsScreen extends StatelessWidget {
  const AgentLanguageSettingsScreen({
    super.key,
    required this.engine,
    required this.voice,
  });
  final AgentEngine engine;
  final AgentVoiceController voice;
  Future<void> change(BuildContext context, Map<String, Object?> values) async {
    try {
      await voice.silence();
      await engine.updateSettings(engine.settings.change(values));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save language settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AgentAtelierScope(
    engine: engine,
    child: ListenableBuilder(
      listenable: Listenable.merge([engine, voice]),
      builder: (context, _) {
        final settings = engine.settings;
        final s = AgentStrings(settings.interfaceLanguage);
        final locales = (voice.availability['languages'] as List? ?? [])
            .cast<String>();
        final tts =
            (voice.availability['ttsLanguages'] as List? ?? [])
                .cast<String>()
                .toSet()
                .toList()
              ..sort();
        Widget language(
          String key,
          String label,
          AgentLanguage value, {
          bool speech = false,
        }) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: DropdownButtonFormField<AgentLanguage>(
            key: ValueKey('$key:${value.name}'),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: [
              for (final l in AgentLanguage.values)
                DropdownMenuItem(
                  value: l,
                  child: Text(
                    '${agentLanguageLabel(l)}${speech && l == AgentLanguage.taglish ? ' · Best effort' : ''}',
                  ),
                ),
            ],
            onChanged: (v) =>
                change(context, {key: v!.name, if (speech) 'locale': ''}),
          ),
        );
        return Scaffold(
          appBar: AppBar(title: Text(s.languageSettings)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Mint Aurora 6.1',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.choose(
                      'Speak naturally. Keep your intention.',
                      'Magsalita nang natural. Panatilihin ang iyong layunin.',
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.choose(
                      'These preferences are independent. Switching language keeps your draft and permissions. Automatic replies follow the conversation; short replies keep its language.',
                      'Magkahiwalay ang mga pagpipiliang ito. Mananatili ang draft at pahintulot kapag nagpalit ng wika. Sinusundan ng Automatic ang usapan.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  language(
                    'interfaceLanguage',
                    s.choose(
                      'Agent interface language',
                      'Wika ng Agent interface',
                    ),
                    settings.interfaceLanguage,
                  ),
                  language(
                    'language',
                    s.choose('Written response language', 'Wika ng mga sagot'),
                    settings.language,
                  ),
                  language(
                    'speechLanguage',
                    s.choose(
                      'Speech recognition preference',
                      'Wika ng pagkilala sa boses',
                    ),
                    settings.speechLanguage,
                    speech: true,
                  ),
                  Text(
                    s.choose(
                          'Reported recognition locales: ',
                          'Mga iniulat na wika ng recognizer: ',
                        ) +
                        (locales.isEmpty
                            ? 'Not reported — device default or text input'
                            : locales.join(', ')),
                  ),
                  if (!locales.any(VoiceLocaleRepository.filipino))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        s.choose(
                          'Filipino / Tagalog is not reported by this recognizer. Filipino text input remains available.',
                          'Hindi iniulat ng recognizer ang Filipino / Tagalog. Puwede pa ring mag-type sa Filipino.',
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    key: ValueKey('tts:${settings.ttsLocale}'),
                    isExpanded: true,
                    initialValue: tts.contains(settings.ttsLocale)
                        ? settings.ttsLocale
                        : '',
                    decoration: InputDecoration(
                      labelText: s.choose(
                        'Spoken-response language',
                        'Wika ng binibigkas na sagot',
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Device TTS default'),
                      ),
                      for (final locale in tts)
                        DropdownMenuItem(value: locale, child: Text(locale)),
                    ],
                    onChanged: (v) =>
                        change(context, {'ttsLocale': v, 'voice': ''}),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.choose(
                      'Only device-reported TTS languages are listed. If Filipino is unavailable, keep Filipino text or explicitly choose an English voice. TTS engines may use a network connection.',
                      'Mga iniulat na TTS language lang ang nakalista. Kung walang Filipino voice, basahin ang teksto o pumili ng English voice. Maaaring gumamit ng internet ang TTS engine.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: voice.initialize,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      s.choose(
                        'Refresh device capabilities',
                        'Suriin muli ang mga wika',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
