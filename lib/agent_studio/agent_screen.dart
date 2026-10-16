import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../ai_coach/ai_response.dart';
import '../design_system.dart';
import '../reminder_widgets.dart';
import 'agent_ai_gateway.dart';
import 'agent_backend.dart';
import 'agent_domain.dart';
import 'agent_engine.dart';
import 'agent_planner.dart';
import 'agent_store.dart';
import 'agent_voice.dart';
import 'agent_step_editor.dart';
import 'agent_settings_screen.dart';

typedef AgentOpen = Future<void> Function(
  BuildContext context,
  String destination,
  String? id,
  String? amount,
);

class AgentStudioScreen extends StatefulWidget {
  const AgentStudioScreen({
    super.key,
    this.engine,
    this.voice,
    this.gateway,
    this.onOpen,
  });
  final AgentEngine? engine;
  final AgentVoiceController? voice;
  final AgentAiGateway? gateway;
  final AgentOpen? onOpen;
  @override
  State<AgentStudioScreen> createState() => _AgentStudioScreenState();
}

class _AgentStudioScreenState extends State<AgentStudioScreen>
    with WidgetsBindingObserver {
  late AgentEngine _engine;
  late AgentVoiceController _voice;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<User?>? _auth;
  bool _initialized = false, _voiceMode = false, _aiBusy = false;
  int _aiEpoch = 0;
  DateTime? _lastAi;
  String _lastTranscript = '';
  bool _voiceDisclosed = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final uid = widget.engine?.uid ?? FirebaseAuth.instance.currentUser!.uid;
    _engine =
        widget.engine ??
        AgentEngine(
          uid: uid,
          currentUid: () => FirebaseAuth.instance.currentUser?.uid,
          backend: FirestoreAgentBackend(
            uid: uid,
            reminders: ReminderScope.maybeOf(context),
            openContribution: (id, amount) => _open('contribution', id, amount),
          ),
          store: PreferenceAgentStore(),
        );
    _voice = widget.voice ?? AgentVoiceController(AndroidAgentVoice());
    _engine.addListener(_changed);
    _voice.addListener(_voiceChanged);
    WidgetsBinding.instance.addObserver(this);
    if (widget.engine == null) unawaited(_engine.initialize());
    unawaited(_voice.initialize());
    if (widget.engine == null) {
      _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user?.uid != uid) {
          _aiEpoch++;
          _input.clear();
          _engine.invalidateIdentity();
          unawaited(_voice.silence());
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _voiceChanged() {
    if (!mounted) return;
    if (_voice.transcript != _lastTranscript) {
      _lastTranscript = _voice.transcript;
      _input.value = TextEditingValue(
        text: _voice.transcript,
        selection: TextSelection.collapsed(offset: _voice.transcript.length),
      );
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        !_voice.usingSystemDialog &&
        !(state == AppLifecycleState.inactive &&
            _voice.state == AgentVoiceState.starting)) {
      _aiEpoch++;
      unawaited(_voice.silence());
      if (_engine.busy) _engine.cancel();
    }
  }

  @override
  void dispose() {
    _aiEpoch++;
    _auth?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _engine.removeListener(_changed);
    _voice.removeListener(_voiceChanged);
    if (widget.engine == null) _engine.dispose();
    if (widget.voice == null) _voice.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        _notice(
          e is AgentFailure
              ? e.message
              : 'This operation could not be completed. Try again.',
        );
      }
    }
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _open(String destination, [String? id, String? amount]) async {
    await _voice.silence();
    if (!mounted) return;
    if (widget.onOpen != null) {
      await widget.onOpen!(context, destination, id, amount);
    } else {
      _notice('Open this feature from the main SaveTrack navigation.');
    }
  }

  void _prefill(String text) {
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _send() async {
    if (_engine.busy ||
        _aiBusy ||
        _input.text.trim().isEmpty ||
        _voice.recording) {
      return;
    }
    final text = _input.text.trim();
    await _voice.silence();
    if (!mounted || !_engine.active) return;
    await _run(() async {
      final plan = LocalAgentPlanner().plan(
        text,
        mission: _engine.editable ? _engine.mission : null,
        language: _engine.settings.language,
        memory: _engine.settings.useMemory ? _engine.settings.memory : const {},
      );
      _engine.say(text, user: true, voice: _voiceMode);
      _input.clear();
      _lastTranscript = '';
      _voice.transcript = '';
      if (plan.cancel) {
        _engine.cancel();
      } else if (plan.replacement != null) {
        _engine.edit(plan.replaceStep!, action: plan.replacement);
      } else if (plan.actions.isNotEmpty) {
        // Keep a previous mission recoverable before replacing its draft.
        await _engine.save();
        _engine.draft(plan.actions);
      }
      _engine.say(plan.reply);
      unawaited(_voice.speak(plan.reply, _engine.settings));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: SaveTrackDesign.motion,
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _mic() async {
    if (_voice.recording) {
      await _voice.stop();
      return;
    }
    if (_engine.busy || _aiBusy) return;
    final accepted = _voiceDisclosed
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Speak a turn'),
              content: const Text(
                'The microphone starts only when you tap Start. You can stop at any time. Android’s speech service may send audio to its provider unless verified on-device recognition is selected. SaveTrack does not save raw audio. Review names, amounts, and dates in the editable transcript before sending. Mixed English and Filipino depends on the installed recognizer.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep typing'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Start microphone'),
                ),
              ],
            ),
          );
    if (accepted == true && mounted) {
      _voiceDisclosed = true;
      setState(() => _voiceMode = true);
      await _voice.initialize();
      await _voice.start(_engine.settings);
    }
  }

  Future<void> _edit(AgentStep step) async {
    await _voice.silence();
    if (!mounted) return;
    await _run(() async {
      final value = await showAgentStepEditor(
        context,
        step.action,
        engine: _engine,
      );
      if (value != null && mounted) {
        _aiEpoch++;
        _engine.edit(step.id, action: value);
      }
    });
  }

  Future<void> _voiceSettings() async {
    await _voice.silence();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AgentSettingsScreen(engine: _engine, voice: _voice),
      ),
    );
  }

  Future<void> _systemMic() async {
    if (_engine.busy || _aiBusy || _voice.recording) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Use Android speech dialog?'),
        content: const Text(
          'This opens your phone’s speech app. It may send audio to its provider and cannot guarantee on-device processing. The recognized text returns for your review; it is never sent or executed automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open speech dialog'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await _voice.initialize();
      await _voice.startSystem(_engine.settings);
    }
  }

  Future<void> _review() async {
    await _voice.silence();
    await _run(() async {
      final errors = await _engine.review();
      if (!mounted) return;
      if (errors.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Review these details'),
            content: SingleChildScrollView(child: Text(errors.join('\n\n'))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Back to mission'),
              ),
            ],
          ),
        );
        return;
      }
      final reviewed = _engine.mission!;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: const Text('Approve selected actions'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SaveTrack will perform only the actions listed below. Review every value.',
              ),
              const SizedBox(height: 16),
              for (final s in reviewed.pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.action.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(s.action.summary),
                      if (s.dependsOn.isNotEmpty)
                        Text('After: ${s.dependsOn.join(', ')}'),
                    ],
                  ),
                ),
              const Text(
                'Contributions open the existing Add Savings form for a separate confirmation. Calculations do not move money. Reminder delivery depends on this device’s notification permission. Already completed operations will remain if another step fails.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              key: const Key('agent-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Approve ${reviewed.pending.length} selected actions',
              ),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        final approval = _engine.approveReviewedSnapshot(reviewed.snapshot);
        await _engine.execute(approval);
      }
    });
  }

  Future<void> _aiHelp() async {
    if (_aiBusy || _engine.busy || _engine.mission == null) return;
    if (_lastAi != null &&
        DateTime.now().difference(_lastAi!) < const Duration(seconds: 10)) {
      _notice('Wait a moment before requesting guidance again.');
      return;
    }
    final request = AgentSafeRequest(
      _engine.mission!.steps.map((s) => s.action.type),
      _engine.settings.language,
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review external AI context'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Firebase AI Logic · Gemini Developer API\n\nOnly this abstract workflow is sent for planning guidance. Private text, amounts, schedules, records, voice transcripts, and memory stay local. Unpaid provider terms may permit use of submitted data for product improvement.',
              ),
              const SizedBox(height: 16),
              SelectableText(request.payload),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay local'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Get guidance'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final epoch = ++_aiEpoch, snapshot = _engine.mission!.snapshot;
    _lastAi = DateTime.now();
    setState(() => _aiBusy = true);
    try {
      final advice = await (widget.gateway ?? FirebaseAgentAiGateway()).advise(
        request,
      );
      if (!mounted ||
          !_engine.active ||
          epoch != _aiEpoch ||
          _engine.mission?.snapshot != snapshot) {
        return;
      }
      _engine.say(
        'Gemini planning guidance · advisory only\n\n${advice.explanation}\n\nSuggested workflow: ${advice.order.map((a) => a.name).join(' → ')}',
      );
    } catch (e) {
      if (mounted && epoch == _aiEpoch) {
        _notice(
          e is AgentFailure
              ? e.message
              : 'Guidance is unavailable. Keep using local planning.',
        );
      }
    } finally {
      if (mounted && epoch == _aiEpoch) setState(() => _aiBusy = false);
    }
  }

  void _history() {
    unawaited(_voice.silence());
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => ListenableBuilder(
          listenable: _engine,
          builder: (ctx, _) => Scaffold(
            appBar: AppBar(title: const Text('Mission history')),
            body: _engine.history.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No saved missions. Enable local mission history in Agent settings to keep drafts and execution recovery for 30 days.',
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      for (final m in _engine.history)
                        ListTile(
                          leading: const Icon(Icons.route_outlined),
                          title: Text(m.title),
                          subtitle: Text(
                            '${agentDay(m.createdAt)} · ${_status(m.status)} · ${m.steps.length} steps',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _run(() async {
                            _engine.open(m);
                            Navigator.pop(ctx);
                          }),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  static String _status(MissionStatus status) => switch (status) {
    MissionStatus.needsClarification => 'Needs details',
    MissionStatus.readyForReview => 'Ready for review',
    MissionStatus.partiallyCompleted => 'Partially completed',
    _ => status.name[0].toUpperCase() + status.name.substring(1),
  };
  @override
  Widget build(BuildContext context) {
    final dark = _voiceMode || Theme.of(context).brightness == Brightness.dark;
    final colors = dark
        ? ColorScheme.fromSeed(
            seedColor: mint,
            brightness: Brightness.dark,
            surface: SaveTrackDesign.obsidian,
          )
        : ColorScheme.fromSeed(seedColor: teal, surface: canvas);
    final theme = Theme.of(context).copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        iconTheme: IconThemeData(color: colors.onSurface),
      ),
      textTheme: Theme.of(context).textTheme
          .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => PopScope(
          canPop: !_engine.busy,
          child: Scaffold(
            appBar: AppBar(
              leading: Navigator.of(context).canPop()
                  ? BackButton(color: colors.onSurface)
                  : null,
              title: Text(
                _voiceMode ? 'SaveTrack Voice' : 'Agent Studio',
                style: TextStyle(
                  fontSize: _voiceMode ? 18 : 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                if (!_voiceMode)
                  IconButton(
                    tooltip: 'Mission history',
                    onPressed: _engine.busy ? null : _history,
                    icon: const Icon(Icons.history_rounded),
                  ),
                IconButton(
                  tooltip: 'Agent settings',
                  onPressed: () async {
                    await _voice.silence();
                    if (!context.mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AgentSettingsScreen(engine: _engine, voice: _voice),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Conversation options',
                  onSelected: (v) => _run(() async {
                    if (v == 'history') {
                      _history();
                    } else if (v == 'clear') {
                      _aiEpoch++;
                      await _voice.silence();
                      _engine.clearConversation();
                      _input.clear();
                    } else {
                      setState(() => _voiceMode = !_voiceMode);
                      await _voice.silence();
                    }
                  }),
                  itemBuilder: (_) => [
                    if (_voiceMode)
                      const PopupMenuItem(
                        value: 'history',
                        child: Text('Mission history'),
                      ),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Text('Clear conversation'),
                    ),
                    PopupMenuItem(
                      value: 'voice',
                      child: Text(
                        _voiceMode ? 'Switch to text' : 'Open voice mode',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(
                    children: [
                      Expanded(
                        child: _engine.loading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  24,
                                ),
                                children: [
                                  if (_voiceMode)
                                    _voicePanel(context)
                                  else if (_engine.messages.isEmpty &&
                                      _engine.mission == null)
                                    _welcome(context),
                                  if (_engine.error != null)
                                    _panel(
                                      context,
                                      Text(
                                        _engine.error!,
                                        style: TextStyle(color: colors.error),
                                      ),
                                    ),
                                  for (final message in _engine.messages)
                                    _bubble(context, message),
                                  if (_aiBusy)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Getting optional planning guidance…',
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              _aiEpoch++;
                                              setState(() => _aiBusy = false);
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_engine.mission != null)
                                    _mission(context),
                                ],
                              ),
                      ),
                      _composer(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
  Widget _welcome(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: SaveTrackDesign.premium,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, color: mint, size: 32),
            SizedBox(height: 24),
            Text(
              'YOUR PLANS, MADE ACTIONABLE',
              style: TextStyle(
                color: mint,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'A little intention.\nA clear next step.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Tell me what you want to accomplish. We’ll shape it into a plan you can edit and approve.',
              style: TextStyle(color: SaveTrackDesign.onHeroMuted, height: 1.6),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _panel(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Local planning. You’re in control.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _engine.settings.execute
                  ? 'Actions are enabled, and each mission still needs your explicit approval.'
                  : 'Action execution starts disabled. Draft freely, then choose permissions in Agent settings.',
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AgentSettingsScreen(engine: _engine, voice: _voice),
                ),
              ),
              child: const Text('Permissions & privacy'),
            ),
          ],
        ),
      ),
      LayoutBuilder(
        builder: (ctx, c) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in [
              (
                Icons.flag_outlined,
                'Plan a goal',
                'Create a savings goal for a laptop worth PHP 30000',
              ),
              (
                Icons.checklist_rounded,
                'Organize tasks',
                'Create three tasks for tomorrow',
              ),
              (
                Icons.notifications_outlined,
                'Draft a reminder',
                'Remind me every Saturday',
              ),
              (
                Icons.route_outlined,
                'Build a mission',
                'Create a phone savings goal, plan contributions and add a task to compare prices',
              ),
              (
                Icons.savings_outlined,
                'Prepare savings',
                'Prepare PHP 200 for my goal',
              ),
              (
                Icons.calculate_outlined,
                'What if…',
                'Simulate a PHP 30000 target with PHP 500 weekly',
              ),
            ])
              SizedBox(
                width: c.maxWidth < 350 ? c.maxWidth : (c.maxWidth - 10) / 2,
                child: OutlinedButton(
                  onPressed: () => _prefill(item.$3),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    alignment: Alignment.centerLeft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$1, size: 24),
                      const SizedBox(height: 16),
                      Text(
                        item.$2,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () => _open('reports'),
            child: const Text('Review my progress'),
          ),
          TextButton(
            onPressed: () => _open('planner'),
            child: const Text('Open Planner'),
          ),
          TextButton(
            onPressed: () => _open('general'),
            child: const Text('Ask Anything'),
          ),
        ],
      ),
    ],
  );
  Widget _bubble(BuildContext context, AgentMessage message) => Align(
    alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 650),
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: message.user
            ? teal
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.user
                ? (message.voice ? 'YOU · VOICE TRANSCRIPT' : 'YOU')
                : message.text.startsWith('Gemini planning guidance')
                ? 'SAVETRACK · GEMINI GUIDANCE'
                : 'SAVETRACK · LOCAL PLAN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: message.user
                  ? mint
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          if (!message.user)
            AiMarkdownResponse(
              text: message.text,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            )
          else
            SelectableText(
              message.text,
              style: TextStyle(
                color: message.user
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                height: 1.55,
              ),
            ),
          if (!message.user)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Speak response',
                onPressed: () => _run(() async {
                  if (!_engine.settings.spoken) {
                    _notice('Enable spoken replies in Voice settings first.');
                    return;
                  }
                  await _voice.initialize();
                  await _voice.speak(message.text, _engine.settings);
                }),
                icon: const Icon(Icons.volume_up_outlined, size: 20),
              ),
            ),
        ],
      ),
    ),
  );
  Widget _mission(BuildContext context) {
    final m = _engine.mission!;
    final errors = m.validate(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mission builder',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_status(m.status)} · ${m.steps.length} steps · Version ${m.version}',
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < m.steps.length; i++)
            _step(context, m.steps[i], i),
          if (errors.isNotEmpty && !_engine.busy)
            _panel(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A few details first',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final error in errors.take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(error),
                    ),
                ],
              ),
            ),
          if (_engine.busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Verifying and performing approved steps…'),
            TextButton(
              onPressed: _engine.cancel,
              child: const Text('Cancel remaining steps'),
            ),
          ] else if (m.status != MissionStatus.completed &&
              m.status != MissionStatus.canceled) ...[
            FilledButton.icon(
              key: const Key('agent-review'),
              onPressed: _review,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                m.steps.any((s) => s.attempts > 0)
                    ? 'Review & retry unfinished steps'
                    : 'Review mission',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: !_engine.editable
                      ? null
                      : () => _run(() async {
                          final action = await showAgentActionPicker(
                            context,
                            engine: _engine,
                          );
                          if (action != null && mounted) _engine.add(action);
                        }),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add step'),
                ),
                TextButton(
                  onPressed: () => _run(() async {
                    if (!_engine.settings.history) {
                      _notice(
                        'Enable local mission history in settings to save drafts.',
                      );
                      return;
                    }
                    await _engine.save();
                    _notice('Draft saved on this device.');
                  }),
                  child: const Text('Save draft'),
                ),
                TextButton(
                  onPressed: _engine.cancel,
                  child: const Text('Cancel mission'),
                ),
              ],
            ),
          ],
          if (m.status == MissionStatus.completed ||
              m.status == MissionStatus.partiallyCompleted)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _open('goals'),
                  child: const Text('View goals'),
                ),
                TextButton(
                  onPressed: () => _open('planner'),
                  child: const Text('View Planner'),
                ),
                TextButton(
                  onPressed: () => _open('reminders'),
                  child: const Text('View reminders'),
                ),
              ],
            ),
          TextButton.icon(
            onPressed: _aiBusy || _engine.busy ? null : _aiHelp,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('Optional Gemini planning guidance'),
          ),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, AgentStep step, int index) {
    final locked = step.attempts > 0 || !_engine.editable;
    final errors = step.action.validate(DateTime.now());
    return _panel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  step.action.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Checkbox(
                value: step.selected,
                onChanged: locked
                    ? null
                    : (value) => _run(() async {
                        _aiEpoch++;
                        _engine.edit(step.id, selected: value);
                      }),
                semanticLabel: 'Select step ${index + 1}',
              ),
            ],
          ),
          Text(step.action.summary, style: const TextStyle(height: 1.6)),
          if (step.dependsOn.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'After: ${step.dependsOn.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (step.status != StepStatus.waiting)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    step.done ? Icons.check_circle_outline : Icons.info_outline,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.status.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (step.result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(step.result),
            ),
          if (step.action is ScenarioDraft && errors.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                (step.action as ScenarioDraft).calculate(DateTime.now()),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          if (!locked)
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _edit(step),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit details'),
                ),
                IconButton(
                  tooltip: 'Move step up',
                  onPressed: index == 0
                      ? null
                      : () => _run(() async {
                          _engine.edit(step.id, move: -1);
                        }),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                ),
                IconButton(
                  tooltip: 'Remove step',
                  onPressed: () => _run(() async {
                    _engine.edit(step.id, remove: true);
                  }),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _voicePanel(BuildContext context) => Column(
    children: [
      const Text(
        'SPEAK NATURALLY',
        style: TextStyle(
          color: mint,
          letterSpacing: 2,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      AgentVoiceOrb(state: _voice.state, amplitude: _voice.amplitude),
      Text(
        switch (_voice.state) {
          AgentVoiceState.ready => 'Ready for your next turn',
          AgentVoiceState.starting =>
            _voice.usingSystemDialog
                ? 'Android speech dialog open'
                : 'Starting microphone…',
          AgentVoiceState.listening => 'Microphone active · Listening',
          AgentVoiceState.reviewing => 'Review your transcript below',
          AgentVoiceState.speaking => 'Speaking · Tap stop to interrupt',
          AgentVoiceState.error => 'Voice needs attention',
        },
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Turn-based voice · Review each transcript before sending',
        textAlign: TextAlign.center,
        style: TextStyle(color: mint, fontSize: 12),
      ),
      if (_voice.error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _voice.error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFD9B0)),
          ),
        ),
      if (_voice.error.isNotEmpty) ...[
        if (_voice.nativeErrorCode != null)
          Text(
            'Android speech error ${_voice.nativeErrorCode}',
            style: const TextStyle(color: mint, fontSize: 12),
          ),
        if (_engine.settings.onDevice)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'On-device recognition is required. A downloaded language model must be available. No remote fallback has been started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mint, fontSize: 12),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => _run(_voiceSettings),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Voice settings'),
            ),
            if (_voice.availability['systemRecognition'] == true &&
                !_engine.settings.onDevice)
              TextButton.icon(
                onPressed: () => _run(_systemMic),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Use Android speech dialog'),
              ),
            TextButton(
              onPressed: _voice.dismissError,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ],
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        children: [
          TextButton.icon(
            onPressed: () => _run(_mic),
            icon: Icon(
              _voice.recording
                  ? Icons.stop_circle_outlined
                  : Icons.mic_none_rounded,
            ),
            label: Text(_voice.recording ? 'Stop listening' : 'Speak a turn'),
          ),
          TextButton.icon(
            onPressed: () => _run(_voice.silence),
            icon: const Icon(Icons.volume_off_outlined),
            label: const Text('Stop audio'),
          ),
          TextButton(
            onPressed: () => _run(() async {
              await _voice.silence();
              setState(() => _voiceMode = false);
            }),
            child: const Text('Switch to text'),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );
  Widget _composer(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_voice.recording)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'LIVE TRANSCRIPT · Stop listening to edit and send',
              style: TextStyle(fontSize: 11),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: _voice.recording
                  ? 'Stop microphone'
                  : 'Start voice input',
              onPressed: _engine.busy || _aiBusy ? null : () => _run(_mic),
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              icon: Icon(
                _voice.recording ? Icons.stop_circle : Icons.mic_none_rounded,
              ),
            ),
            Expanded(
              child: TextField(
                key: const Key('agent-input'),
                controller: _input,
                readOnly: _voice.recording,
                enabled: !_engine.loading && !_engine.busy && !_aiBusy,
                minLines: 1,
                maxLines: 4,
                maxLength: AgentLimits.input,
                decoration: const InputDecoration(
                  hintText: 'What would you like to accomplish?',
                  counterText: '',
                  border: InputBorder.none,
                  filled: false,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton.filled(
              tooltip: 'Send reviewed text',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed:
                  _engine.loading || _engine.busy || _aiBusy || _voice.recording
                  ? null
                  : _send,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Local drafts · Changes require your approval',
          style: TextStyle(fontSize: 10),
        ),
      ],
    ),
  );
}

class AgentVoiceOrb extends StatelessWidget {
  const AgentVoiceOrb({super.key, required this.state, this.amplitude = 0});
  final AgentVoiceState state;
  final double amplitude;
  @override
  Widget build(BuildContext context) {
    final active =
        state == AgentVoiceState.listening ||
        state == AgentVoiceState.speaking ||
        state == AgentVoiceState.starting;
    final failed = state == AgentVoiceState.error;
    return Semantics(
      label: 'Voice ${state.name}',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: failed ? 12 : 28),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          width: (failed ? 96 : 170) + amplitude * 18,
          height: (failed ? 96 : 170) + amplitude * 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-.3, -.35),
              colors: [
                const Color(0xFFE0FFF0),
                mint,
                SaveTrackDesign.fresh,
                teal,
              ],
              stops: const [0, .35, .65, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: mint.withValues(alpha: active ? .25 : .12),
                blurRadius: active ? 55 : 35,
                spreadRadius: active ? 12 : 4,
              ),
            ],
            border: Border.all(color: mint.withValues(alpha: .4), width: 8),
          ),
          child: Icon(
            state == AgentVoiceState.speaking
                ? Icons.graphic_eq_rounded
                : Icons.auto_awesome_rounded,
            color: teal,
            size: 48,
          ),
        ),
      ),
    );
  }
}
