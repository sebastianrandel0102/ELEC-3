import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'presentation/agent_theme.dart';
import 'presentation/agent_widgets.dart';
import 'presentation/agent_action_preview.dart';
import 'presentation/agent_history_screen.dart';
import 'presentation/agent_orb_artwork.dart';

import '../ai_coach/ai_response.dart';
import '../design_system.dart';
import '../currency_widgets.dart';
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
import 'agent_language_settings.dart';
import 'intelligence/agent_language.dart';
import 'intelligence/agent_interpretation.dart';
import 'intelligence/interpretation_preview.dart';
import 'autopilot/autopilot_settings.dart';
import 'autopilot/auto_execution_policy.dart';
import 'autopilot/autopilot_settings_screen.dart';
import 'autopilot/autopilot_activity_screen.dart';

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
  final _inputFocus = FocusNode();
  BuildContext? _presentationContext;
  BuildContext get _uiContext => _presentationContext ?? context;
  final _goalNames = <String, String>{};
  bool _followLatest = true;
  AgentMessage? _latestMessage;
  Object? _voiceUiState;
  StreamSubscription<User?>? _auth;
  bool _initialized = false, _voiceMode = false, _aiBusy = false;
  int _aiEpoch = 0;
  DateTime? _lastAi;
  String _lastTranscript = '';
  bool _voiceDisclosed = false;
  bool _submitting = false;
  String _handledVoiceTurn = '';
  AgentStrings get _strings => AgentStrings(_engine.settings.interfaceLanguage);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _scroll.addListener(_onScroll);
    _input.addListener(_inputChanged);
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
    _engine.setForeground(true);
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

  void _inputChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final follow = !_scroll.hasClients || _scroll.position.extentAfter < 120;
    if (follow != _followLatest && mounted) {
      setState(() => _followLatest = follow);
    }
  }

  void _scrollToLatest({bool force = false}) {
    if (!force && !_followLatest) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (!force && !_followLatest) return;
      final duration = SaveTrackDesign.duration(
        context,
        SaveTrackDesign.motion,
      );
      final end = _scroll.position.maxScrollExtent;
      if (duration == Duration.zero) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: duration,
          curve: SaveTrackDesign.motionCurve,
        );
      }
    });
  }

  void _changed() {
    if (!mounted) return;
    if (!_engine.settings.permissions.contains(
      AgentPermission.privateContext,
    )) {
      _goalNames.clear();
    }
    if (_latestMessage != _engine.messages.lastOrNull) {
      _latestMessage = _engine.messages.lastOrNull;
      _scrollToLatest();
    }
    setState(() {});
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
    final auto = _engine.settings.autopilot;
    if (_voice.state == AgentVoiceState.reviewing &&
        _voice.originalTranscript.isNotEmpty &&
        _voice.transcript == _voice.originalTranscript &&
        _handledVoiceTurn != _voice.turnId &&
        auto.enabled &&
        auto.voiceAutoExecutionEnabled &&
        auto.voiceReviewMode != AgentVoiceReviewMode.alwaysReview &&
        _engine.foreground &&
        !_submitting &&
        !_engine.busy) {
      _handledVoiceTurn = _voice.turnId;
      final confidence = _voice.confidences.firstOrNull;
      final uncertainRecognition =
          _voice.alternatives.toSet().length > 1 ||
          confidence != null && confidence < .85;
      if (!uncertainRecognition &&
          (auto.voiceReviewMode == AgentVoiceReviewMode.autoRunEligible ||
              confidence != null)) {
        scheduleMicrotask(() {
          if (mounted &&
              _engine.foreground &&
              _voice.state == AgentVoiceState.reviewing &&
              _input.text == _voice.originalTranscript) {
            unawaited(_send());
          }
        });
      }
    }
    final uiState = (
      _voice.state,
      _voice.transcript,
      _voice.originalTranscript,
      _voice.error,
      _voice.nativeErrorCode,
      _voice.recognitionLocale,
      _voice.turnId,
      _voice.usingSystemDialog,
      _voice.availability,
      _voice.alternatives,
      _voice.confidences,
    );
    if (uiState != _voiceUiState) {
      _voiceUiState = uiState;
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _engine.setForeground(state == AppLifecycleState.resumed);
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
    _engine.setForeground(false);
    _voice.removeListener(_voiceChanged);
    if (widget.engine == null) _engine.dispose();
    if (widget.voice == null) _voice.dispose();
    _input.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
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
    _inputFocus.requestFocus();
  }

  Future<void> _send() async {
    if (_submitting ||
        _engine.busy ||
        _aiBusy ||
        _input.text.trim().isEmpty ||
        _voice.recording) {
      return;
    }
    final text = _input.text.trim();
    final fromVoice = _voice.originalTranscript.isNotEmpty;
    final voiceUncertain =
        fromVoice &&
        (_voice.alternatives.toSet().length > 1 ||
            _voice.confidences.firstOrNull != null &&
                _voice.confidences.first! < .85);
    final origin = fromVoice || _voiceMode
        ? AgentRequestOrigin.finalVoice
        : AgentRequestOrigin.userText;
    _submitting = true;
    try {
      await _voice.silence();
      if (!mounted || !_engine.active) return;
      await _run(() async {
        var plan = LocalAgentPlanner().plan(
          text,
          mission: _engine.editable ? _engine.mission : null,
          language: _engine.settings.language,
          previousLanguage: _engine.sessionLanguage,
          previous: _engine.activeInterpretation,
          now: _engine.clock(),
          defaultCurrency: CurrencyScope.maybeOf(context)?.preferred ?? '',
          memory: _engine.settings.useMemory
              ? _engine.settings.memory
              : const {},
        );
        if (plan.actions.any(
              (a) =>
                  a is ContributionDraft ||
                  a is ScenarioDraft ||
                  a is ReminderDraft && a.targetStep.isEmpty,
            ) &&
            _engine.settings.permissions.contains(
              AgentPermission.privateContext,
            )) {
          final snapshot = _engine.mission?.snapshot;
          try {
            final goals = await _engine.backend.goals().timeout(
              AgentLimits.requestTimeout,
            );
            if (!mounted ||
                !_engine.active ||
                snapshot != _engine.mission?.snapshot) {
              return;
            }
            if (_engine.settings.permissions.contains(
              AgentPermission.privateContext,
            )) {
              _goalNames.addEntries(
                goals.map((goal) => MapEntry(goal.id, goal.title)),
              );
              plan = LocalAgentPlanner().plan(
                text,
                goals: goals,
                mission: _engine.editable ? _engine.mission : null,
                language: _engine.settings.language,
                previousLanguage: _engine.sessionLanguage,
                previous: _engine.activeInterpretation,
                now: _engine.clock(),
                defaultCurrency:
                    CurrencyScope.maybeOf(context)?.preferred ?? '',
                memory: _engine.settings.useMemory
                    ? _engine.settings.memory
                    : const {},
              );
            }
          } catch (_) {
            if (!mounted || !_engine.active) return;
            _notice(
              _strings.choose(
                'Goal details could not be loaded. Choose a goal in Edit details.',
                'Hindi ma-load ang mga goal. Pumili ng goal sa Edit details.',
              ),
            );
          }
        }
        _engine.say(text, user: true, voice: _voiceMode);
        _input.clear();
        _lastTranscript = '';
        _voice.transcript = '';
        _voice.originalTranscript = '';
        _voice.alternatives = const [];
        // Alternative recognition candidates require manual review, even when
        // the selected transcript happens to parse into complete fields.
        if (voiceUncertain) {
          await _engine.applyPlan(plan);
        } else {
          await _engine.handleUserPlan(plan, origin: origin);
        }
        final m = _engine.mission;
        final completed = m?.steps.where((s) => s.done).length ?? 0;
        final reply = completed > 0
            ? '$completed of ${m!.steps.where((s) => s.selected).length} steps completed. Inspect the results below.'
            : _engine.error ??
                  (voiceUncertain
                      ? 'Recognition was uncertain. Review the transcript and mission before execution.'
                      : _engine.autoDecision?.message ?? plan.reply);
        _engine.say(reply);
        unawaited(_voice.speak(reply, _engine.settings));
        if (_engine.interpretation?.uncertain.isEmpty != false) {
          _scrollToLatest();
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
            context: _uiContext,
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
        _uiContext,
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
      context: _uiContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Use Android speech dialog?'),
        content: const Text(
          'This opens your phone’s speech app. It may send audio to its provider and cannot guarantee on-device processing. Final recognized text follows your separate voice review and Autopilot settings.',
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
          context: _uiContext,
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
        context: _uiContext,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text(_strings.confirm),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _strings.choose(
                  'SaveTrack will perform only the actions listed below. Review every value.',
                  'Ang mga nakalistang hakbang lang ang isasagawa. Suriin ang bawat detalye.',
                ),
              ),
              const SizedBox(height: 16),
              AgentStatusChip(
                label: _strings.choose(
                  'Review required',
                  'Kailangan ng pagsusuri',
                ),
                icon: Icons.fact_check_outlined,
              ),
              const SizedBox(height: 16),
              for (final s in reviewed.pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AgentSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _strings.action(s.action),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(_strings.summary(s.action)),
                        if (s.dependsOn.isNotEmpty)
                          Text(
                            'After step: ${s.dependsOn.map((id) => reviewed.steps.indexWhere((step) => step.id == id) + 1).join(', ')}',
                          ),
                      ],
                    ),
                  ),
                ),
              Text(
                _strings.choose(
                  'Contributions open the existing Add Savings form for a separate confirmation. Calculations do not move money. Reminder delivery depends on this device’s notification permission. Already completed operations will remain if another step fails.',
                  'Bubuksan ang Add Savings para sa hiwalay na kumpirmasyon ng dagdag ipon. Walang perang gagalawin sa pagkukuwenta. Kailangan ng pahintulot sa notification para sa paalala. Mananatili ang mga natapos na pagbabago kung may ibang hakbang na pumalya.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_strings.text('Keep editing')),
            ),
            FilledButton(
              key: const Key('agent-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                _strings.choose(
                  'Approve ${reviewed.pending.length} selected actions',
                  'Kumpirmahin ang ${reviewed.pending.length} napiling hakbang',
                ),
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
      detectedLanguage: _engine.sessionLanguage,
    );
    final accepted = await showDialog<bool>(
      context: _uiContext,
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
        builder: (ctx) => AgentHistoryScreen(
          engine: _engine,
          onOpen: (mission) => _run(() async {
            _engine.open(mission);
            Navigator.pop(ctx);
          }),
        ),
      ),
    );
  }

  static String _status(MissionStatus status) => agentMissionStatus(status);

  List<WidgetBuilder> _items() => [
    (context) => _executionModeBar(context),
    if (_voiceMode)
      (context) => _voicePanel(context)
    else if (_engine.messages.isEmpty && _engine.mission == null)
      (context) => _welcome(context),
    if (_engine.error != null)
      (context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AgentSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _engine.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _voiceSettings,
                icon: const Icon(Icons.tune),
                label: Text(
                  _strings.choose('Review settings', 'Suriin ang settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    if (_engine.autoDecision != null && !_engine.autoDecision!.mayRun)
      (context) => _panel(context, Text(_engine.autoDecision!.message)),
    for (var i = 0; i < _engine.messages.length; i++)
      (context) => _bubble(
        context,
        _engine.messages[i],
        grouped:
            i > 0 && _engine.messages[i - 1].user == _engine.messages[i].user,
      ),
    if (_engine.activeInterpretation != null && _engine.editable)
      (context) => _clarification(context),
    if (_aiBusy)
      (context) => AgentProcessingIndicator(
        label: _strings.choose(
          'Getting optional planning guidance…',
          'Kumukuha ng gabay sa pagpaplano…',
        ),
        onCancel: () {
          _aiEpoch++;
          setState(() => _aiBusy = false);
        },
      ),
    if (_engine.mission != null) (context) => _mission(context),
  ];

  @override
  Widget build(BuildContext context) => AgentAtelierScope(
    engine: _engine,
    voice: _voiceMode,
    child: Builder(
      builder: (context) {
        _presentationContext = context;
        final colors = Theme.of(context).colorScheme;
        final items = _items();
        final compact =
            MediaQuery.sizeOf(context).width < 360 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4;
        return PopScope(
          canPop: !_engine.busy,
          child: Scaffold(
            appBar: AppBar(
              leading: Navigator.of(context).canPop()
                  ? const BackButton()
                  : const Padding(
                      padding: EdgeInsets.all(10),
                      child: AgentEmblem(size: 36),
                    ),
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _voiceMode ? 'SaveTrack Voice' : 'Agent Studio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!compact)
                    Text(
                      _strings.choose(
                        'Your intelligent companion',
                        'Kasama mo sa pagplano',
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              actions: [
                if (_engine.settings.autopilot.enabled)
                  IconButton(
                    tooltip: 'Pause Autopilot',
                    onPressed: () => _run(_engine.pauseAutopilot),
                    icon: const Icon(Icons.pause_circle_outline),
                  ),
                if (!_voiceMode && !compact)
                  IconButton(
                    tooltip: 'Mission history',
                    onPressed: _engine.busy ? null : _history,
                    icon: const Icon(Icons.history_rounded),
                  ),
                IconButton(
                  tooltip: 'Agent settings',
                  onPressed: _voiceSettings,
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
                    if (_voiceMode || compact)
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
              top: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AgentAtelier.readingWidth,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            if (_engine.loading)
                              Center(
                                child: AgentProcessingIndicator(
                                  label: _strings.choose(
                                    'Opening your workspace…',
                                    'Binubuksan ang workspace…',
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                controller: _scroll,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(
                                  SaveTrackDesign.pageInset(
                                    MediaQuery.sizeOf(context).width,
                                  ),
                                  4,
                                  SaveTrackDesign.pageInset(
                                    MediaQuery.sizeOf(context).width,
                                  ),
                                  24,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, index) =>
                                    items[index](context),
                              ),
                            if (!_followLatest && _engine.messages.isNotEmpty)
                              Positioned(
                                right: 16,
                                bottom: 12,
                                child: FloatingActionButton.small(
                                  heroTag: 'agent-latest',
                                  tooltip: _strings.choose(
                                    'Jump to latest',
                                    'Pumunta sa pinakabago',
                                  ),
                                  onPressed: () => _scrollToLatest(force: true),
                                  child: const Icon(
                                    Icons.arrow_downward_rounded,
                                  ),
                                ),
                              ),
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
        );
      },
    ),
  );

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

  Widget _executionModeBar(BuildContext context) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ActionChip(
        key: const Key('agent-execution-mode'),
        avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
        label: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 140,
          ),
          child: Text(_engine.settings.autopilot.mode.label),
        ),
        onPressed: () async {
          await _voice.silence();
          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AgentAutopilotSettingsScreen(engine: _engine),
            ),
          );
        },
      ),
      if (_engine.settings.autopilot.enabled)
        TextButton.icon(
          onPressed: () => _run(_engine.pauseAutopilot),
          icon: const Icon(Icons.pause, size: 16),
          label: const Text('Pause'),
        ),
      IconButton(
        tooltip: 'Autopilot Activity',
        icon: const Icon(Icons.manage_history),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AgentAutopilotActivityScreen(engine: _engine),
          ),
        ),
      ),
    ],
  );
  Widget _languageChip(
    BuildContext context, {
    bool recognition = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          avatar: const Icon(Icons.translate, size: 18),
          label: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 140,
            ),
            child: Text(
              recognition
                  ? '${_strings.choose('Recognition', 'Pagkilala')}: ${_voice.recognitionLocale.isEmpty ? _strings.choose('Device default', 'Default ng device') : _voice.recognitionLocale}'
                  : '${agentLanguageLabel(_engine.settings.language)} · Mint Aurora 7.0',
            ),
          ),
          onPressed: () async {
            await _voice.silence();
            await _voice.initialize();
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    AgentLanguageSettingsScreen(engine: _engine, voice: _voice),
              ),
            );
          },
        ),
        if (recognition &&
            _engine.settings.speechLanguage == AgentLanguage.taglish)
          const Text('Taglish · Best effort'),
      ],
    ),
  );

  Widget _clarification(BuildContext context) {
    final understanding = _engine.activeInterpretation!;
    final choices = (understanding.slots['amountCandidates'] as List? ?? [])
        .cast<String>()
        .toSet();
    final needsGoal =
        _engine.mission?.steps.any(
          (s) =>
              s.action is ContributionDraft &&
                  (s.action as ContributionDraft).goalId.isEmpty ||
              s.action is ReminderDraft &&
                  (s.action as ReminderDraft).targetId.isEmpty &&
                  (s.action as ReminderDraft).targetStep.isEmpty,
        ) ??
        false;
    if (understanding.questions.isEmpty && !needsGoal) {
      return const SizedBox.shrink();
    }
    return _panel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _strings.choose('Let’s confirm the details', 'Linawin muna natin'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final q in understanding.questions.toSet().take(2)) Text(q),
          if (understanding.uncertain.contains(Uncertainty.amount) &&
              choices.length <= 5)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final amount in choices)
                  ActionChip(
                    label: Text(amount),
                    onPressed: () {
                      _prefill(amount);
                      _send();
                    },
                  ),
              ],
            ),
          if (needsGoal)
            TextButton.icon(
              key: const Key('agent-choose-goal'),
              onPressed: () => _run(_chooseGoal),
              icon: const Icon(Icons.flag_outlined),
              label: Text(
                _strings.choose(
                  'Choose a personal goal',
                  'Pumili ng personal na goal',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _chooseGoal() async {
    if (!_engine.settings.permissions.contains(
      AgentPermission.privateContext,
    )) {
      _notice(
        _strings.choose(
          'Enable Private context access in Agent settings to choose local goals.',
          'Payagan ang Private context access sa Agent settings para pumili ng goal.',
        ),
      );
      return;
    }
    final snapshot = _engine.mission?.snapshot;
    final goals = await _engine.backend.goals();
    if (!mounted ||
        !_engine.active ||
        snapshot != _engine.mission?.snapshot ||
        !_engine.settings.permissions.contains(
          AgentPermission.privateContext,
        )) {
      return;
    }
    final goal = await showDialog<AgentRecord>(
      context: _uiContext,
      builder: (ctx) => SimpleDialog(
        title: Text(_strings.goal),
        children: [
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _strings.choose(
                  'No active personal goals.',
                  'Walang aktibong personal na goal.',
                ),
              ),
            ),
          if (goals.isEmpty)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                _prefill(
                  _strings.choose(
                    'Create a savings goal',
                    'Gumawa ng savings goal',
                  ),
                );
              },
              child: Text(_strings.choose('Plan a goal', 'Gumawa ng Goal')),
            ),
          for (final g in goals)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, g),
              child: Text('${g.title} · ${g.currency}'),
            ),
        ],
      ),
    );
    if (_engine.settings.permissions.contains(AgentPermission.privateContext)) {
      _goalNames.addEntries(goals.map((goal) => MapEntry(goal.id, goal.title)));
    }
    if (goal == null ||
        !_engine.active ||
        snapshot != _engine.mission?.snapshot ||
        !_engine.settings.permissions.contains(
          AgentPermission.privateContext,
        )) {
      return;
    }
    final candidates = _engine.mission!.steps
        .where(
          (st) =>
              st.selected &&
              !st.done &&
              st.attempts == 0 &&
              (st.action is ContributionDraft &&
                      (st.action as ContributionDraft).goalId.isEmpty ||
                  st.action is ReminderDraft &&
                      (st.action as ReminderDraft).targetId.isEmpty &&
                      (st.action as ReminderDraft).targetStep.isEmpty),
        )
        .toList();
    if (candidates.length != 1) {
      _notice(_strings.step);
      return;
    }
    final step = candidates.single, values = candidates.single.action.toJson();
    if (step.action is ContributionDraft) {
      values['goalId'] = goal.id;
      if (values['currency'] == '') values['currency'] = goal.currency;
    } else {
      values['targetId'] = goal.id;
    }
    _engine.edit(step.id, action: AgentAction.fromJson(values));
  }

  Widget _welcome(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      AgentHero(
        eyebrow: 'MINT AURORA 7.0 / AGENT ATELIER',
        title: _strings.welcome,
        subtitle: _strings.choose(
          'Plan your savings, organize your day, and turn ideas into action.',
          'Planuhin ang ipon, ayusin ang araw, at gawing hakbang ang mga ideya.',
        ),
        footer: Row(
          children: [
            const Icon(Icons.shield_outlined, size: 15, color: mint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _strings.choose(
                  'Intelligence, beautifully in motion.',
                  'Matalinong kasama sa bawat hakbang.',
                ),
                style: const TextStyle(fontSize: 12, color: mint, height: 1.5),
              ),
            ),
          ],
        ),
      ),
      AgentSectionHeader(
        title: _strings.choose(
          'Make room for progress',
          'Simulan ang pag-unlad',
        ),
        subtitle: _strings.choose(
          'A little help, right where you need it.',
          'Kaunting tulong para sa mga plano mo.',
        ),
      ),
      LayoutBuilder(
        builder: (ctx, c) {
          final single =
              c.maxWidth < 310 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          final columns = single
              ? 1
              : c.maxWidth >= 650
              ? 3
              : 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in [
                (
                  Icons.track_changes_rounded,
                  _strings.choose('Plan a goal', 'Gumawa ng Goal'),
                  _strings.choose(
                    'Give your savings direction',
                    'Bigyan ng direksyon ang ipon',
                  ),
                  _strings.choose(
                    'Create a savings goal for a laptop worth PHP 30000',
                    'Gawa ka ng goal para sa laptop target PHP 30000',
                  ),
                ),
                (
                  Icons.checklist_rounded,
                  _strings.choose('Organize tasks', 'Ayusin ang Araw Ko'),
                  _strings.choose(
                    'Find your next clear step',
                    'Ayusin ang susunod na hakbang',
                  ),
                  _strings.choose(
                    'Create three tasks for tomorrow',
                    'Gawa ng task para bukas',
                  ),
                ),
                (
                  Icons.notifications_none_rounded,
                  _strings.choose('Draft a reminder', 'Mag-set ng Paalala'),
                  _strings.choose(
                    'Keep the important things close',
                    'Tandaan ang mahahalagang bagay',
                  ),
                  _strings.choose(
                    'Remind me every Saturday',
                    'Pa-remind ako tuwing Sabado',
                  ),
                ),
                (
                  Icons.route_outlined,
                  _strings.choose('Build a mission', 'Bumuo ng mission'),
                  _strings.choose(
                    'One idea. A connected plan.',
                    'Isang ideya, magkakaugnay na plano.',
                  ),
                  _strings.choose(
                    'Create a phone savings goal, plan contributions and add a task to compare prices',
                    'Gumawa ng phone savings goal at task para magkumpara ng presyo',
                  ),
                ),
                (
                  Icons.savings_outlined,
                  _strings.choose('Prepare savings', 'Magplano ng Ipon'),
                  _strings.choose(
                    'Prepare your next contribution',
                    'Ihanda ang susunod na hulog',
                  ),
                  _strings.choose(
                    'Prepare PHP 200 for my goal',
                    'Pa-add PHP 200 sa goal ko',
                  ),
                ),
                (
                  Icons.insights_rounded,
                  _strings.choose('What if…', 'Paano kung…'),
                  _strings.choose(
                    'Explore a different savings pace',
                    'Subukan ang ibang bilis ng ipon',
                  ),
                  _strings.choose(
                    'Simulate a PHP 30000 target with PHP 500 weekly',
                    'Paano kung PHP 30000 target at PHP 500 lingguhan',
                  ),
                ),
              ])
                SizedBox(
                  width: (c.maxWidth - (columns - 1) * 12) / columns,
                  child: AgentQuickActionCard(
                    icon: item.$1,
                    title: item.$2,
                    description: item.$3,
                    featured:
                        item.$1 == Icons.track_changes_rounded ||
                        item.$1 == Icons.route_outlined,
                    onTap: () => _prefill(item.$4),
                  ),
                ),
            ],
          );
        },
      ),
      AgentSectionHeader(
        title: _strings.choose(
          'Start with a thought',
          'Magsimula sa isang ideya',
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final prompt in [
            _strings.choose(
              'Help me plan tomorrow',
              'Tulungan akong magplano para bukas',
            ),
            _strings.choose(
              'Compare two savings plans',
              'Ihambing ang dalawang plano sa ipon',
            ),
          ])
            ActionChip(
              label: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 120,
                ),
                child: Text(prompt),
              ),
              avatar: const Icon(Icons.add, size: 16),
              onPressed: () => _prefill(prompt),
            ),
        ],
      ),
      AgentSectionHeader(
        title: _strings.choose('Recent activity', 'Kamakailang aktibidad'),
        action: TextButton(
          onPressed: _history,
          child: Text(_strings.choose('View all', 'Tingnan lahat')),
        ),
      ),
      if (_engine.history.isEmpty)
        AgentEmptyState(
          title: _strings.choose(
            'Your next plan starts here.',
            'Dito magsisimula ang susunod mong plano.',
          ),
          message: _strings.choose(
            'A goal, a reminder, a fresh start. Tell me what you have in mind.',
            'Goal, paalala, o bagong simula. Sabihin ang nasa isip mo.',
          ),
        )
      else
        for (final mission
            in (_engine.history.toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
                .take(3))
          AgentMissionActivityTile(
            mission: mission,
            onTap: () => _run(() async => _engine.open(mission)),
          ),
      const SizedBox(height: 16),
      _languageChip(context),
      _panel(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _strings.choose(
                      'Local planning. You’re in control.',
                      'Lokal na pagplano. Ikaw ang may kontrol.',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _engine.settings.autopilot.enabled
                  ? _strings.choose(
                      'Autopilot follows your permissions and limits. Financial transactions still require confirmation.',
                      'Sinusunod ng Autopilot ang pahintulot at limitasyon mo. Kailangan pa rin ng kumpirmasyon sa transaksyon.',
                    )
                  : _engine.settings.execute
                  ? _strings.choose(
                      'Each mission needs your explicit approval.',
                      'Kailangan ng kumpirmasyon mo sa bawat mission.',
                    )
                  : _strings.choose(
                      'Draft freely. Enable action permissions in Agent settings when you are ready.',
                      'Malayang gumawa ng draft. I-on ang pahintulot sa settings kapag handa ka na.',
                    ),
            ),
            TextButton(
              onPressed: _voiceSettings,
              child: Text(
                _strings.choose(
                  'Permissions & privacy',
                  'Pahintulot at privacy',
                ),
              ),
            ),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () => _open('reports'),
            child: Text(
              _strings.choose('Review my progress', 'Tingnan ang pag-unlad'),
            ),
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

  Widget _bubble(
    BuildContext context,
    AgentMessage message, {
    bool grouped = false,
  }) {
    final c = Theme.of(context).colorScheme;
    return Align(
      alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: message.user ? .88 : 1,
        child: Container(
          margin: EdgeInsets.only(top: grouped ? 4 : 18, bottom: 4),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          decoration: BoxDecoration(
            color: message.user ? c.primary : c.surfaceContainerLow,
            border: message.user ? null : Border.all(color: c.outlineVariant),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(message.user ? 20 : 6),
              bottomRight: Radius.circular(message.user ? 6 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!grouped) ...[
                Row(
                  children: [
                    if (!message.user) ...[
                      const AgentEmblem(size: 24),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        message.user
                            ? (message.voice ? 'YOU · VOICE TRANSCRIPT' : 'YOU')
                            : message.text.startsWith(
                                'Gemini planning guidance',
                              )
                            ? 'SAVETRACK · GEMINI GUIDANCE'
                            : 'SAVETRACK · LOCAL PLAN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                          color: message.user ? c.onPrimary : c.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (!message.user)
                AiMarkdownResponse(
                  text: message.text,
                  foregroundColor: c.onSurface,
                )
              else
                SelectableText(
                  message.text,
                  style: TextStyle(color: c.onPrimary, height: 1.6),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: _strings.choose(
                      'Copy message',
                      'Kopyahin ang mensahe',
                    ),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: message.text),
                      );
                      if (mounted) {
                        _notice(
                          _strings.choose(
                            'Message copied',
                            'Nakopya ang mensahe',
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Icons.copy_outlined,
                      size: 17,
                      color: message.user ? c.onPrimary : c.onSurfaceVariant,
                    ),
                  ),
                  if (!message.user)
                    IconButton(
                      tooltip: 'Speak response',
                      onPressed: () => _run(() async {
                        if (!_engine.settings.spoken) {
                          _notice(
                            'Enable spoken replies in Voice settings first.',
                          );
                          return;
                        }
                        await _voice.initialize();
                        await _voice.speak(message.text, _engine.settings);
                      }),
                      icon: const Icon(Icons.volume_up_outlined, size: 19),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameMission() async {
    final controller = TextEditingController(
      text: _engine.mission?.title ?? '',
    );
    final snapshot = _engine.mission?.snapshot;
    final title = await showDialog<String>(
      context: _uiContext,
      builder: (ctx) => AlertDialog(
        title: Text(_strings.choose('Mission title', 'Pangalan ng mission')),
        content: TextField(
          controller: controller,
          maxLength: 100,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _strings.choose('Title', 'Pangalan'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: Text(_strings.text('Save draft details')),
          ),
        ],
      ),
    );
    // A dialog result cannot edit another mission opened while it was visible.
    if (title != null &&
        mounted &&
        _engine.active &&
        snapshot == _engine.mission?.snapshot) {
      _engine.renameMission(title);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  Widget _mission(BuildContext context) {
    final m = _engine.mission!;
    final errors = m.validate(_engine.clock());
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
                  _strings.choose('Mission builder', 'Mga hakbang ng mission'),
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
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                m.title.isEmpty
                    ? _strings.choose(
                        'Mission title needed',
                        'Kailangan ng pangalan ng mission',
                      )
                    : m.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (_engine.editable)
                IconButton(
                  key: const Key('agent-rename-mission'),
                  tooltip: _strings.choose(
                    'Edit mission title',
                    'I-edit ang pangalan ng mission',
                  ),
                  onPressed: _renameMission,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _panel(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AgentStatusChip(
                      label: _status(m.status),
                      icon: m.status == MissionStatus.completed
                          ? Icons.check_circle_outline
                          : Icons.route_outlined,
                    ),
                    AgentStatusChip(
                      label:
                          '${m.steps.where((s) => s.done).length} / ${m.steps.length} ${_strings.choose('steps completed', 'natapos na hakbang')}',
                      icon: Icons.checklist_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: m.steps.isEmpty
                      ? 0
                      : m.steps.where((s) => s.done).length / m.steps.length,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
          if (m.planOnly)
            _panel(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _strings.choose(
                      'Draft only · Review is paused',
                      'Draft pa lang · Hindi pa puwedeng aprubahan',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _strings.choose(
                      'You asked to keep this as a plan. Enable review when you are ready; approval is still required.',
                      'Hiniling mong plano lang muna. Puwedeng paganahin ang review kapag handa ka na. Kailangan pa rin ng kumpirmasyon.',
                    ),
                  ),
                  TextButton(
                    key: const Key('agent-enable-review'),
                    onPressed: _engine.enableDraftReview,
                    child: Text(
                      _strings.choose(
                        'Allow mission review',
                        'Payagan ang pagsusuri ng mission',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < m.steps.length; i++)
            _step(context, m.steps[i], i),
          if (errors.isNotEmpty && !_engine.busy)
            _panel(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _strings.text('A few details first'),
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
            const Text('Validating actions and waiting for verified results…'),
            TextButton(
              onPressed: _engine.cancel,
              child: const Text('Stop Remaining Actions'),
            ),
          ] else if (m.status != MissionStatus.completed &&
              m.status != MissionStatus.canceled) ...[
            FilledButton.icon(
              key: const Key('agent-review'),
              onPressed: m.planOnly ? null : _review,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                m.steps.any((s) => s.attempts > 0)
                    ? 'Review & retry unfinished steps'
                    : _strings.review,
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
                  label: Text(_strings.text('Add step')),
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
                  child: Text(_strings.text('Save draft')),
                ),
                TextButton(
                  onPressed: _engine.cancel,
                  child: Text(_strings.text('Cancel mission')),
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

  bool _canMoveStep(int index, int offset) {
    final steps = [..._engine.mission!.steps];
    final destination = index + offset;
    if (destination < 0 || destination >= steps.length) return false;
    steps.insert(destination, steps.removeAt(index));
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].dependsOn.any((id) {
        final dependency = steps.indexWhere((step) => step.id == id);
        return dependency < 0 || dependency >= i;
      })) {
        return false;
      }
    }
    return true;
  }

  Widget _step(BuildContext context, AgentStep step, int index) {
    final locked = step.attempts > 0 || !_engine.editable;
    final errors = step.action.validate(_engine.clock());
    return Stack(
      children: [
        Positioned(
          left: 13,
          top: 0,
          bottom: index == _engine.mission!.steps.length - 1 ? null : 0,
          child: Container(
            width: 1,
            height: index == _engine.mission!.steps.length - 1 ? 28 : null,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        Positioned(
          left: 0,
          top: 16,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: step.done
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.primary),
            ),
            child: step.done
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimary,
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: _panel(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10, top: 3),
                      child: Icon(
                        agentActionIcon(step.action),
                        size: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step.done
                            ? switch (step.action) {
                                GoalDraft() => 'Savings Goal Created',
                                TaskDraft() => 'Task Created',
                                ReminderDraft() => 'Reminder Preference Saved',
                                ContributionDraft() =>
                                  'Add Savings Review Opened',
                                ScenarioDraft() ||
                                AllocationDraft() => 'Simulation Result',
                              }
                            : _strings.action(step.action),
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
                AgentActionPreview(
                  action: step.action,
                  strings: _strings,
                  now: _engine.clock(),
                  referenceLabel: switch (step.action) {
                    ContributionDraft a => _goalNames[a.goalId],
                    ReminderDraft a => _goalNames[a.targetId],
                    _ => null,
                  },
                ),
                if (!step.done)
                  AgentInterpretationPreview(
                    action: step.action,
                    strings: _strings,
                    binding: _engine.activeInterpretation?.titles
                        .where((t) => t.actionIndex == index)
                        .firstOrNull,
                  ),
                Text(
                  _strings.summary(step.action),
                  style: const TextStyle(height: 1.6),
                ),
                if (step.dependsOn.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_strings.choose('After step', 'Pagkatapos ng hakbang')} ${step.dependsOn.map((id) => _engine.mission!.steps.indexWhere((s) => s.id == id) + 1).join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (step.status != StepStatus.waiting)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Icon(
                          step.done
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
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
                if (step.done &&
                    step.action is GoalDraft &&
                    step.recordId.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _open('goal', step.recordId),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View Goal'),
                  ),
                if (step.action is ScenarioDraft && errors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      (step.action as ScenarioDraft).calculate(_engine.clock()),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                if (errors.isNotEmpty && !step.done)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      errors.first,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (!locked)
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _edit(step),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(_strings.text('Edit details')),
                      ),
                      IconButton(
                        tooltip: 'Move step up',
                        onPressed: !_canMoveStep(index, -1)
                            ? null
                            : () => _run(() async {
                                _engine.edit(step.id, move: -1);
                              }),
                        icon: const Icon(Icons.arrow_upward, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Move step down',
                        onPressed: !_canMoveStep(index, 1)
                            ? null
                            : () => _run(() async {
                                _engine.edit(step.id, move: 1);
                              }),
                        icon: const Icon(Icons.arrow_downward, size: 18),
                      ),
                      IconButton(
                        key: Key('agent-remove-${step.id}'),
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
          ),
        ),
      ],
    );
  }

  Widget _voicePanel(BuildContext context) => Column(
    children: [
      _languageChip(context, recognition: true),
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          tooltip: _strings.choose(
            'Microphone privacy',
            'Privacy ng mikropono',
          ),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                _strings.choose(
                  'Your voice, your choice',
                  'Boses mo, desisyon mo',
                ),
              ),
              content: Text(
                _strings.choose(
                  'The microphone starts only when you tap it. Android speech and TTS providers may process audio remotely. SaveTrack does not retain raw recordings. You can require verified on-device recognition in Voice settings.',
                  'Magsisimula lang ang mikropono kapag pinindot mo. Maaaring iproseso ng Android speech at TTS provider ang audio online. Hindi nagtatago ang SaveTrack ng raw recording. Puwedeng piliin ang on-device recognition sa Voice settings.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_strings.choose('Got it', 'Nauunawaan ko')),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.privacy_tip_outlined, size: 20),
        ),
      ),
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
      ListenableBuilder(
        listenable: _voice,
        builder: (context, _) =>
            AgentVoiceOrb(state: _voice.state, amplitude: _voice.amplitude),
      ),
      Text(
        switch (_voice.state) {
          AgentVoiceState.ready => 'Ready for your next turn',
          AgentVoiceState.starting =>
            _voice.usingSystemDialog
                ? 'Android speech dialog open'
                : 'Starting microphone…',
          AgentVoiceState.listening => _strings.choose(
            'Microphone active · Listening',
            'Nakikinig · Naka-on ang mikropono',
          ),
          AgentVoiceState.reviewing => _strings.transcript,
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
      Text(
        _engine.settings.autopilot.enabled &&
                _engine.settings.autopilot.voiceAutoExecutionEnabled &&
                _engine.settings.autopilot.voiceReviewMode !=
                    AgentVoiceReviewMode.alwaysReview
            ? 'Turn-based voice · Eligible final speech may run automatically'
            : 'Turn-based voice · Review each transcript before sending',
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
            label: Text(
              _voice.state == AgentVoiceState.speaking
                  ? 'Stop speaking'
                  : 'Stop audio',
            ),
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
  Widget _composer(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final available =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final compact =
        available < 430 ||
        largeText && MediaQuery.viewInsetsOf(context).bottom > 0;
    final transcript =
        !_voice.recording && _voice.originalTranscript.isNotEmpty;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: (available * .48).clamp(100.0, 340.0),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.outlineVariant),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? SaveTrackDesign.shadows
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (transcript)
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _strings.transcript,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (!compact)
                          Text(
                            _strings.choose(
                              'Check amounts, names, and dates before sending.',
                              'Suriin ang halaga, pangalan, at petsa bago ipadala.',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _inputFocus.requestFocus(),
                              child: Text(
                                _strings.choose(
                                  'Edit transcript',
                                  'I-edit ang teksto',
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _run(_mic),
                              child: Text(
                                _strings.choose('Try again', 'Subukan Ulit'),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await _voice.silence();
                                _voice.originalTranscript = '';
                                _voice.transcript = '';
                                _lastTranscript = '';
                                _input.clear();
                                if (mounted) setState(() {});
                              },
                              child: Text(
                                _strings.choose(
                                  'Cancel transcript',
                                  'Kanselahin ang teksto',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_voice.alternatives.toSet().length > 1)
                          Text(
                            _strings.choose(
                              'Recognition returned alternatives. Verify the intended amount.',
                              'May ibang narinig ang recognizer. Suriin ang tamang halaga.',
                            ),
                            style: TextStyle(color: c.error, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_voice.recording && !compact)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _strings.choose(
                      'LIVE TRANSCRIPT · Stop listening to edit and send',
                      'LIVE NA TEKSTO · Ihinto ang pakikinig bago i-edit at ipadala',
                    ),
                    style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: _voice.recording
                      ? 'Stop microphone'
                      : 'Start voice input',
                  onPressed: _engine.loading || _engine.busy || _aiBusy
                      ? null
                      : () => _run(_mic),
                  icon: Icon(
                    _voice.recording
                        ? Icons.stop_circle
                        : Icons.mic_none_rounded,
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('agent-input'),
                    controller: _input,
                    focusNode: _inputFocus,
                    readOnly: _voice.recording,
                    enabled: !_engine.loading && !_engine.busy && !_aiBusy,
                    minLines: 1,
                    maxLines: available < 300
                        ? 1
                        : compact || largeText
                        ? 2
                        : 4,
                    maxLength: AgentLimits.input,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: _strings.hint,
                      hintMaxLines: 1,
                      hintStyle: TextStyle(
                        color: c.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 4,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton.filled(
                  key: const Key('agent-send'),
                  tooltip: 'Send reviewed text',
                  onPressed:
                      _input.text.trim().isEmpty ||
                          _submitting ||
                          _engine.loading ||
                          _engine.busy ||
                          _aiBusy ||
                          _voice.recording
                      ? null
                      : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    disabledBackgroundColor: c.surfaceContainerHighest,
                    disabledForegroundColor: c.onSurfaceVariant,
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
            if (!compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Text(
                  _engine.settings.autopilot.enabled
                      ? _strings.choose(
                          'Sensitive changes still require confirmation',
                          'Kailangan pa rin ng kumpirmasyon sa sensitibong pagbabago',
                        )
                      : _strings.choose(
                          'Changes require your approval',
                          'Kailangan ng pahintulot mo sa mga pagbabago',
                        ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
          duration: SaveTrackDesign.duration(
            context,
            const Duration(milliseconds: 180),
          ),
          width:
              (failed ? 96 : 170) +
              (MediaQuery.disableAnimationsOf(context)
                  ? 0
                  : amplitude.clamp(0, 1) * 18),
          height:
              (failed ? 96 : 170) +
              (MediaQuery.disableAnimationsOf(context)
                  ? 0
                  : amplitude.clamp(0, 1) * 18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: mint.withValues(alpha: active ? .25 : .12),
                blurRadius: active ? 36 : 24,
                spreadRadius: active ? 6 : 0,
              ),
            ],
            border: Border.all(color: mint.withValues(alpha: .3), width: 1),
          ),
          child: AgentOrbArtwork(speaking: state == AgentVoiceState.speaking),
        ),
      ),
    );
  }
}
