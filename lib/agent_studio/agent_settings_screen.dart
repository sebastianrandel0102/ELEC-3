import 'package:flutter/material.dart';

import 'agent_domain.dart';
import 'agent_engine.dart';
import 'agent_voice.dart';

class AgentSettingsScreen extends StatelessWidget {
  const AgentSettingsScreen({
    super.key,
    required this.engine,
    required this.voice,
  });
  final AgentEngine engine;
  final AgentVoiceController voice;
  Future<void> _change(
    BuildContext context,
    Map<String, Object?> values,
  ) async {
    try {
      await voice.silence();
      await engine.updateSettings(engine.settings.change(values));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings could not be saved on this device.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([engine, voice]),
    builder: (ctx, _) {
      final settings = engine.settings;
      return Scaffold(
        appBar: AppBar(title: const Text('Agent settings')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Plans you approve. Actions you control.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Agent Studio is separate from Ask Anything and the read-only AI Coach. A model cannot authorize writes. Every mission requires an exact on-screen review. Shared goal edits, withdrawals, deletion, and edits to existing records remain in their dedicated SaveTrack screens.',
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text('Execute approved actions'),
                  subtitle: const Text(
                    'Explicitly enable reviewed goal, task, reminder, and contribution preparation workflows.',
                  ),
                  value: settings.execute,
                  onChanged: (v) => _change(context, {'execute': v}),
                ),
                for (final item in [
                  (AgentPermission.createGoal, 'Create personal goals'),
                  (AgentPermission.createTask, 'Create Planner tasks'),
                  (AgentPermission.createReminder, 'Create reminders'),
                  (AgentPermission.contribution, 'Prepare contributions'),
                  (AgentPermission.privateContext, 'Private context access'),
                ])
                  SwitchListTile(
                    title: Text(item.$2),
                    subtitle: item.$1 == AgentPermission.privateContext
                        ? const Text(
                            'Locally read personal goals for selection and allocation. No records are sent to Gemini.',
                          )
                        : null,
                    value: settings.permissions.contains(item.$1),
                    onChanged: (v) {
                      final set = {...settings.permissions};
                      v ? set.add(item.$1) : set.remove(item.$1);
                      _change(context, {
                        'permissions': set.map((p) => p.name).toList(),
                      });
                    },
                  ),
                const Divider(height: 32),
                const Text(
                  'Voice & audio privacy',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap-to-talk and turn-based responses use Android speech services and installed TTS voices. Recognition and some TTS engines may process data remotely. SaveTrack keeps no raw recordings. Text remains available on unsupported platforms.',
                ),
                SwitchListTile(
                  title: const Text('Spoken replies'),
                  subtitle: const Text(
                    'Off by default. Stops when you leave or background the app.',
                  ),
                  value: settings.spoken,
                  onChanged: (v) => _change(context, {'spoken': v}),
                ),
                SwitchListTile(
                  title: const Text('Hide financial details in speech'),
                  subtitle: const Text(
                    'Speak a generic notice instead of amounts, task titles, or conversation text.',
                  ),
                  value: settings.hideSpokenDetails,
                  onChanged: (v) => _change(context, {'hideSpokenDetails': v}),
                ),
                SwitchListTile(
                  title: const Text('Require on-device recognition'),
                  subtitle: Text(
                    voice.availability['onDevice'] == true
                        ? 'Requires a downloaded local language model as well as the recognizer. If speech fails immediately, choose an installed model or turn this off to explicitly allow the device speech provider.'
                        : 'No verified on-device recognizer is available. Turn this off to allow the device speech provider, which may use the internet. There is no automatic remote fallback.',
                  ),
                  value: settings.onDevice,
                  onChanged: (v) => _change(context, {'onDevice': v}),
                ),
                ListTile(
                  title: const Text('Recognition & speech language'),
                  subtitle: Text(
                    settings.locale.isEmpty
                        ? 'Device default'
                        : settings.locale,
                  ),
                  onTap: () async {
                    await voice.initialize();
                    if (!context.mounted) return;
                    final languageKey =
                        settings.onDevice &&
                            voice.availability.containsKey('onDeviceLanguages')
                        ? 'onDeviceLanguages'
                        : 'languages';
                    final languages =
                        (voice.availability[languageKey] as List? ?? [])
                            .cast<String>()
                            .toSet()
                            .toList()
                          ..sort();
                    final selected = await showDialog<String>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Device speech languages'),
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Only languages reported by the speech service are listed. With on-device recognition required, the last verified installed model list is used when available. A service being installed does not guarantee that a language model is downloaded. Mixed Taglish is best-effort.',
                            ),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, ''),
                            child: const Text('Device default'),
                          ),
                          for (final language in languages)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, language),
                              child: Text(language),
                            ),
                        ],
                      ),
                    );
                    if (selected != null && context.mounted) {
                      await _change(context, {'locale': selected, 'voice': ''});
                    }
                  },
                ),
                ListTile(
                  title: const Text('Installed TTS voice'),
                  subtitle: Text(
                    settings.voice.isEmpty ? 'Engine default' : settings.voice,
                  ),
                  onTap: () async {
                    await voice.initialize();
                    if (!context.mounted) return;
                    final voices = (voice.availability['voices'] as List? ?? [])
                        .cast<String>();
                    final value = await showDialog<String>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Installed voices'),
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, ''),
                            child: const Text('Engine default'),
                          ),
                          for (final v in voices)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, v),
                              child: Text(v),
                            ),
                        ],
                      ),
                    );
                    if (value != null && context.mounted) {
                      await _change(context, {'voice': value});
                    }
                  },
                ),
                ListTile(
                  title: const Text('Speech speed'),
                  subtitle: Slider(
                    value: settings.rate,
                    min: .5,
                    max: 1.5,
                    divisions: 10,
                    label: '${settings.rate.toStringAsFixed(1)}×',
                    onChanged: (v) => _change(context, {'rate': v}),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await voice.initialize();
                    await voice.speak(
                      'Your SaveTrack voice is ready.',
                      settings,
                    );
                  },
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Preview voice'),
                ),
                const Divider(height: 32),
                const Text(
                  'Local history & memory',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SwitchListTile(
                  title: const Text('Save mission history on this device'),
                  subtitle: const Text(
                    'Stores draft values and actual results for recovery. Retained for 30 days, up to 50 missions. App-local storage is not an encrypted vault. Chat and audio are never persisted. Turning this off deletes saved missions.',
                  ),
                  value: settings.history,
                  onChanged: engine.busy
                      ? null
                      : (v) => _change(context, {'history': v}),
                ),
                ListTile(
                  title: const Text('Clear mission history'),
                  leading: const Icon(Icons.delete_outline),
                  onTap: engine.busy
                      ? null
                      : () async {
                          await engine.clearHistory();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Local mission history deleted.'),
                              ),
                            );
                          }
                        },
                ),
                SwitchListTile(
                  title: const Text('Use approved preference memory'),
                  subtitle: const Text(
                    'Only preferences you explicitly save below. Nothing is sent to external AI.',
                  ),
                  value: settings.useMemory,
                  onChanged: (v) => _change(context, {'useMemory': v}),
                ),
                ListTile(
                  title: const Text('Memory center'),
                  subtitle: Text(
                    settings.memory.isEmpty
                        ? 'No saved preferences'
                        : '${settings.memory.length} approved preferences',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _MemoryScreen(engine: engine, voice: voice),
                    ),
                  ),
                ),
                DropdownButtonFormField<AgentLanguage>(
                  initialValue: settings.language,
                  decoration: const InputDecoration(
                    labelText: 'Local reply language',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AgentLanguage.english,
                      child: Text('English'),
                    ),
                    DropdownMenuItem(
                      value: AgentLanguage.filipino,
                      child: Text('Filipino · best-effort'),
                    ),
                  ],
                  onChanged: (v) => _change(context, {'language': v!.name}),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Optional Gemini guidance uses the existing Firebase AI Logic and App Check configuration. It requires project model access and available quota. Core local planning needs no paid AI or server. Continuous live audio is not enabled.',
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _MemoryScreen extends StatelessWidget {
  const _MemoryScreen({required this.engine, required this.voice});
  final AgentEngine engine;
  final AgentVoiceController voice;
  static const options = {
    'contributionFrequency': ['weekly', 'monthly'],
    'reminderDay': [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ],
    'studyTime': ['morning', 'afternoon', 'evening'],
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (ctx, _) => Scaffold(
      appBar: AppBar(title: const Text('Memory center')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Save only the preferences you want Agent Studio to remember. These are local suggestions; dates and reminder times still require review.',
          ),
          for (final entry in options.entries)
            ListTile(
              title: Text(switch (entry.key) {
                'contributionFrequency' => 'Contribution frequency',
                'reminderDay' => 'Preferred reminder day',
                _ => 'Study time',
              }),
              subtitle: Text(engine.settings.memory[entry.key] ?? 'Not saved'),
              trailing: IconButton(
                tooltip: 'Forget preference',
                onPressed: () async {
                  final memory = {...engine.settings.memory}..remove(entry.key);
                  await engine.updateSettings(
                    engine.settings.change({'memory': memory}),
                  );
                },
                icon: const Icon(Icons.close),
              ),
              onTap: () async {
                final value = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Save this preference?'),
                    children: [
                      for (final value in entry.value)
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, value),
                          child: Text('Remember: $value'),
                        ),
                    ],
                  ),
                );
                if (value != null && engine.active) {
                  await voice.silence();
                  await engine.updateSettings(
                    engine.settings.change({
                      'memory': {...engine.settings.memory, entry.key: value},
                    }),
                  );
                }
              },
            ),
        ],
      ),
    ),
  );
}
