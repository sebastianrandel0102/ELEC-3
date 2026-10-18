import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system.dart';
import 'ai_controller.dart';
import 'ai_domain.dart';
import 'ai_response.dart';
import 'ai_widgets.dart';
import 'ai_setup_sheet.dart';
import 'firebase_ai_gateway.dart';
import 'firestore_ai_context_source.dart';

enum _ContextStep { idle, choosing, loading, reviewing }

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key, this.controller});
  final AiCoachController? controller;
  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  late final AiCoachController _controller;
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _drafts = <AiMode, String>{};
  StreamSubscription<User?>? _auth;
  int _selectionEpoch = 0;
  _ContextStep _contextStep = _ContextStep.idle;
  bool get _loadingContext => _contextStep != _ContextStep.idle;
  bool _showLatest = false;
  String? _lastSessionId;
  // Focus/selection can retain an outgoing scroll position for a frame when
  // the welcome list becomes a conversation. Operate on the current position.
  ScrollPosition? get _position =>
      _scroll.hasClients ? _scroll.positions.last : null;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        AiCoachController(
          gateway: FirebaseAiGateway(),
          contextSource: FirestoreAiContextSource(),
          currentUid: () => FirebaseAuth.instance.currentUser?.uid,
        );
    _controller.addListener(_stateChanged);
    _lastSessionId = _controller.active.id;
    _controller.streamingChanges.addListener(_streamChanged);
    _scroll.addListener(_scrollChanged);
    if (widget.controller == null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user?.uid != uid) {
          _selectionEpoch++;
          _input.clear();
          _drafts.clear();
          _controller.invalidateIdentity();
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      });
    }
  }

  void _stateChanged() {
    if (!mounted) return;
    setState(() {});
    final reset =
        _lastSessionId != _controller.active.id &&
        _controller.active.messages.isEmpty;
    _lastSessionId = _controller.active.id;
    if (reset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _position?.jumpTo(0);
      });
    } else {
      _followLatest();
    }
  }

  void _streamChanged() => _followLatest();
  void _scrollChanged() {
    final position = _position;
    if (position == null || !position.hasContentDimensions) return;
    if (_controller.active.messages.isEmpty) {
      if (_showLatest && mounted) setState(() => _showLatest = false);
      return;
    }
    final show = position.maxScrollExtent - position.pixels > 120;
    if (show != _showLatest && mounted) setState(() => _showLatest = show);
  }

  void _followLatest({bool force = false}) {
    if (_controller.active.messages.isEmpty) return;
    if (_showLatest && !force) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final position = _position;
      if (!mounted || position == null || !position.hasContentDimensions) {
        return;
      }
      position.jumpTo(position.maxScrollExtent);
    });
  }

  void _switch(AiMode mode) {
    if (_controller.mode == mode) return;
    _selectionEpoch++;
    _drafts[_controller.mode] = _input.text;
    _input.text = _drafts[mode] ?? '';
    _contextStep = _ContextStep.idle;
    _showLatest = false;
    _controller.switchMode(mode);
    _focus.unfocus();
    if (_controller.active.messages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _position?.jumpTo(0);
      });
    } else {
      _followLatest(force: true);
    }
  }

  void _fill(String question) {
    _input.text = question;
    _input.selection = TextSelection.collapsed(offset: question.length);
    _focus.requestFocus();
  }

  Future<bool> _providerNotice({bool always = false}) async {
    if (_controller.providerAcknowledged && !always) return true;
    final uid = _controller.currentUid();
    // Version the preference so a changed disclosure can be shown again.
    final preferenceKey = 'savetrack.ai.providerNotice.v1.$uid';
    var doNotShowAgain = false;
    SharedPreferences? preferences;
    if (uid != null && uid.isNotEmpty) {
      try {
        preferences = await SharedPreferences.getInstance();
        doNotShowAgain = preferences.getBool(preferenceKey) ?? false;
      } catch (_) {
        // If local storage is unavailable, keep showing the notice.
      }
    }
    if (!mounted || _controller.currentUid() != uid) return false;
    if (doNotShowAgain && !always) {
      _controller.acknowledgeProvider();
      return true;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(always ? 'AI privacy' : 'Before your first question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SaveTrack AI sends your questions, recent chat turns and any summary you explicitly approve to Google’s Gemini service.\n\n'
                  'The unpaid service may use questions and answers to improve products, including human review. Do not enter personal, sensitive or confidential information, passwords or tokens.\n\n'
                  'Exact SaveTrack financial facts stay local. Chat history is held in memory and cleared when you leave or sign out. AI answers can be inaccurate and have no live web search.',
                  style: TextStyle(height: 1.6),
                ),
                if (uid != null && uid.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Do not show again',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: doNotShowAgain,
                    onChanged: (value) =>
                        setDialogState(() => doNotShowAgain = value ?? false),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I understand'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || accepted != true || _controller.currentUid() != uid) {
      return false;
    }
    var saved = true;
    if (uid != null && uid.isNotEmpty) {
      try {
        preferences ??= await SharedPreferences.getInstance();
        saved = await preferences.setBool(preferenceKey, doNotShowAgain);
      } catch (_) {
        saved = false;
      }
    }
    if (!mounted || _controller.currentUid() != uid) return false;
    _controller.acknowledgeProvider();
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your privacy notice preference.'),
        ),
      );
    }
    return true;
  }

  Future<void> _submit() async {
    if (_controller.busy || _loadingContext || _input.text.trim().isEmpty) {
      return;
    }
    final mode = _controller.mode, question = _input.text;
    final previousLastId = _controller.active.messages.isEmpty
        ? null
        : _controller.active.messages.last.id;
    if (!await _providerNotice() || !mounted || _controller.mode != mode) {
      return;
    }
    final sent = _controller.send(question);
    if (_controller.busy) {
      _input.clear();
      _drafts[mode] = '';
      _showLatest = false;
      _followLatest(force: true);
    }
    await sent;
    if (mounted &&
        _controller.mode == mode &&
        _input.text.isEmpty &&
        (_controller.active.messages.isEmpty ||
            _controller.active.messages.last.id == previousLastId) &&
        _controller.active.failure != null) {
      _input.text = question;
    }
  }

  Future<void> _setup() async {
    final verified = await showAiSetup(
      context,
      verify: _controller.checkConnection,
    );
    if (!mounted || verified != true) return;
    _controller.clearFailure();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App protection verified. You can send your question.'),
      ),
    );
  }

  Future<void> _clear() async {
    if (_controller.active.messages.isEmpty &&
        _controller.active.facts == null) {
      _input.clear();
      _controller.newChat();
      return;
    }
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this chat?'),
        content: const Text(
          'This mode’s conversation and approved context will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep chat'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear chat'),
          ),
        ],
      ),
    );
    if (!mounted || clear != true) return;
    _selectionEpoch++;
    _input.clear();
    _drafts[_controller.mode] = '';
    _controller.newChat();
  }

  Future<void> _chooseContext(String action) async {
    final source = _controller.contextSource;
    if (source == null || _loadingContext || _controller.busy) return;
    final epoch = ++_selectionEpoch;
    _focus.unfocus();
    setState(
      () => _contextStep = action == 'goal' || action == 'plan'
          ? _ContextStep.loading
          : _ContextStep.choosing,
    );
    bool current() =>
        mounted && epoch == _selectionEpoch && _controller.mode == AiMode.coach;
    try {
      AiLocalFacts? facts;
      if (action == 'goal' || action == 'plan') {
        final goals = await source.goals().timeout(AiConfig.contextReadTimeout);
        if (!mounted || !current()) return;
        setState(() => _contextStep = _ContextStep.choosing);
        facts = await showModalBottomSheet<AiLocalFacts>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text(
                    action == 'plan'
                        ? 'Choose a goal for your plan'
                        : 'Analyze a Goal',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: context.atelierInk,
                    ),
                  ),
                ),
                if (goals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No authorized active goals are available. You can still ask for general savings advice.',
                    ),
                  ),
                if (action == 'plan')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _fill(
                          'Help me build a hypothetical savings plan. Ask me about the target, timeframe and contribution I can afford.',
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Use a hypothetical example'),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: goals.length,
                    itemBuilder: (context, index) => ListTile(
                      leading: Icon(
                        goals[index].shared
                            ? Icons.group_outlined
                            : Icons.flag_outlined,
                        color: context.atelierAccent,
                      ),
                      title: Text(goals[index].title),
                      subtitle: Text(
                        goals[index].shared
                            ? 'Local facts only'
                            : 'Review an anonymous summary',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, goals[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (action == 'day') {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (!current() || date == null) return;
        setState(() => _contextStep = _ContextStep.loading);
        facts = await source.planner(date).timeout(AiConfig.contextReadTimeout);
      } else {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          helpText: 'Select a week to explain',
        );
        if (!current() || date == null) return;
        final start = DateTime(
          date.year,
          date.month,
          date.day,
        ).subtract(Duration(days: date.weekday - 1));
        setState(() => _contextStep = _ContextStep.loading);
        facts = await source.report(start).timeout(AiConfig.contextReadTimeout);
      }
      if (!mounted || !current() || facts == null) return;
      setState(() => _contextStep = _ContextStep.reviewing);
      final review = await showAiContextReview(context, facts);
      if (!current() || review == null) return;
      _controller.selectFacts(facts, approve: review == AiReviewChoice.approve);
      _fill(
        review == AiReviewChoice.localOnly
            ? 'Offer general ${action == 'day'
                  ? 'daily planning'
                  : action == 'report'
                  ? 'report interpretation'
                  : 'savings'} advice without personal context.'
            : action == 'day'
            ? 'Help me organize my day using the approved summary. Respect the recorded priorities.'
            : action == 'report'
            ? 'Explain this report summary. What does it suggest about my planning habits?'
            : action == 'plan'
            ? 'Suggest a realistic savings routine using the approved summary. Clearly label assumptions.'
            : 'Explain my goal progress and deadline category using the approved summary.',
      );
    } catch (error) {
      if (mounted && current()) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mapAiError(error).message)));
      }
    } finally {
      if (mounted && epoch == _selectionEpoch) {
        setState(() => _contextStep = _ContextStep.idle);
      }
    }
  }

  @override
  void dispose() {
    _selectionEpoch++;
    _auth?.cancel();
    _controller.removeListener(_stateChanged);
    _controller.streamingChanges.removeListener(_streamChanged);
    if (widget.controller == null) _controller.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    backgroundColor: context.atelierCanvas,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
              final compact = constraints.maxHeight < 420 || largeText;
              final inset = constraints.maxWidth < 360 ? 12.0 : 20.0;
              final active = _controller.active;
              return Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 2 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.atelierSurface,
                      border: Border(
                        bottom: BorderSide(color: context.atelierBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        if (!largeText) ...[
                          const AiEmblem(size: 30),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SaveTrack AI',
                                style: TextStyle(
                                  color: context.atelierInk,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.4,
                                ),
                              ),
                              if (!compact)
                                Text(
                                  'Your intelligent companion',
                                  style: TextStyle(
                                    color: context.atelierMuted,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Chat actions',
                          icon: const Icon(Icons.more_horiz_rounded),
                          onSelected: (value) {
                            if (value == 'privacy') {
                              _providerNotice(always: true);
                            } else if (value == 'revoke') {
                              _controller.revokeContext();
                            } else {
                              _clear();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'new',
                              child: Text('New Chat'),
                            ),
                            const PopupMenuItem(
                              value: 'clear',
                              child: Text('Clear Chat'),
                            ),
                            if (active.facts != null)
                              const PopupMenuItem(
                                value: 'revoke',
                                child: Text('Revoke context & clear Coach'),
                              ),
                            const PopupMenuItem(
                              value: 'privacy',
                              child: Text('AI privacy'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      compact ? 4 : 12,
                      inset,
                      compact ? 4 : 10,
                    ),
                    child: AiModeSelector(
                      mode: _controller.mode,
                      onChanged: _switch,
                    ),
                  ),
                  if (!compact)
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 0, inset, 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: context.atelierMuted,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              _controller.mode == AiMode.askAnything
                                  ? 'No SaveTrack data is shared'
                                  : active.approval != null
                                  ? 'Anonymous summary approved · exact facts stay local'
                                  : 'Personalized insights use only information you approve',
                              style: TextStyle(
                                color: context.atelierMuted,
                                fontSize: 10,
                                height: 1.5,
                              ),
                            ),
                          ),
                          if (active.facts != null)
                            IconButton(
                              tooltip: 'Revoke context and clear Coach history',
                              visualDensity: VisualDensity.compact,
                              onPressed: _controller.revokeContext,
                              icon: const Icon(Icons.close_rounded, size: 16),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        _conversation(inset),
                        if (_showLatest)
                          Positioned(
                            bottom: 12,
                            right: inset,
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                _showLatest = false;
                                _followLatest(force: true);
                              },
                              icon: const Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                              ),
                              label: const Text('Latest'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (active.failure != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 4, inset, 4),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  active.failure!.message,
                                  style: TextStyle(
                                    color: context.atelierError,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              if (active.failure!.kind ==
                                  AiErrorKind.configuration)
                                TextButton(
                                  onPressed: _controller.busy ? null : _setup,
                                  child: const Text('AI setup'),
                                )
                              else if (active.messages.isNotEmpty &&
                                  active.messages.last.status !=
                                      AiMessageStatus.complete)
                                TextButton(
                                  onPressed: _controller.busy
                                      ? null
                                      : _controller.retry,
                                  child: const Text('Retry'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  _composer(inset, compact),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _conversation(double inset) {
    final active = _controller.active;
    if (active.messages.isEmpty) {
      return ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(inset, 4, inset, 20),
        children: [
          AiWelcomeHero(mode: _controller.mode),
          const SizedBox(height: 24),
          if (active.facts != null) ...[
            AiFactCard(facts: active.facts!),
            const SizedBox(height: 24),
          ],
          Text(
            _controller.mode == AiMode.askAnything
                ? 'A little inspiration'
                : 'Make room for progress',
            style: TextStyle(
              color: context.atelierInk,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _controller.mode == AiMode.askAnything
                ? 'Start with an idea. Make it your own.'
                : 'Choose a subject. Review what you share.',
            style: TextStyle(color: context.atelierMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_contextStep == _ContextStep.loading ||
              active.status == AiStatus.preparing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(
                semanticsLabel: 'Preparing context',
              ),
            ),
          _prompts(),
          const SizedBox(height: 20),
          Text(
            'Powered by Gemini · Guidance, with you in control',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.atelierMuted, fontSize: 10),
          ),
        ],
      );
    }
    final offset = active.facts == null ? 0 : 1;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(inset, 8, inset, 20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: active.messages.length + offset,
      itemBuilder: (context, index) {
        if (offset == 1 && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: AiFactCard(facts: active.facts!),
          );
        }
        final message = active.messages[index - offset];
        return ListenableBuilder(
          key: ValueKey(message.id),
          listenable: message.status == AiMessageStatus.streaming
              ? _controller.streamingChanges
              : const _NeverChanges(),
          builder: (context, _) {
            final current = _controller.active.messages.firstWhere(
              (m) => m.id == message.id,
              orElse: () => message,
            );
            return _bubble(current);
          },
        );
      },
    );
  }

  Widget _bubble(AiMessage message) {
    final user = message.role == AiRole.user;
    if (!user &&
        message.text.trim().isEmpty &&
        message.status != AiMessageStatus.streaming) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: user ? .85 : .94,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: user ? SaveTrackDesign.midnight : context.atelierSurface,
              borderRadius: BorderRadius.circular(20),
              border: user ? null : Border.all(color: context.atelierBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!user) ...[
                  Row(
                    children: [
                      AiEmblem(size: 24),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SaveTrack AI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.atelierAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (!user &&
                    message.status == AiMessageStatus.streaming &&
                    message.text.isEmpty)
                  Semantics(
                    liveRegion: true,
                    label: 'AI is thinking',
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.atelierAccent,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Thinking…',
                            style: TextStyle(
                              color: context.atelierMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (user)
                  SelectableText(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.7,
                    ),
                  )
                else if (message.text.isNotEmpty)
                  AiMarkdownResponse(
                    text: message.text,
                    streaming: message.status == AiMessageStatus.streaming,
                  ),
                if (!user)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.status == AiMessageStatus.streaming
                              ? 'Writing…'
                              : message.status == AiMessageStatus.canceled
                              ? 'Stopped · partial answer'
                              : message.status == AiMessageStatus.failed
                              ? 'Incomplete · AI-generated'
                              : 'AI-generated · verify important details',
                          style: TextStyle(
                            color: context.atelierMuted,
                            fontSize: 10,
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
                            size: 16,
                            color: context.atelierMuted,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _prompts() {
    final general = [
      (
        Icons.school_outlined,
        'Learn',
        'Explain a difficult topic simply.',
        'Explain how photosynthesis works in simple terms.',
      ),
      (
        Icons.calculate_outlined,
        'Solve',
        'Work through a math problem.',
        'Help me solve a math problem step by step. Ask me for the problem.',
      ),
      (
        Icons.edit_note_rounded,
        'Write',
        'Give your words a little polish.',
        'Help me improve a paragraph. Ask me for a non-sensitive example.',
      ),
      (
        Icons.code_rounded,
        'Code',
        'Make a Flutter concept click.',
        'Explain Flutter widgets with a small Dart example.',
      ),
      (
        Icons.lightbulb_outline_rounded,
        'Create',
        'Turn a spark into an idea.',
        'Brainstorm five interesting school project ideas.',
      ),
      (
        Icons.explore_outlined,
        'Explore',
        'Learn something unexpected.',
        'Teach me an interesting science concept.',
      ),
    ];
    final coach = [
      (
        Icons.flag_outlined,
        'Analyze a Goal',
        'Understand your progress.',
        'goal',
      ),
      (
        Icons.savings_outlined,
        'Build a Savings Plan',
        'Find a routine that fits.',
        'plan',
      ),
      (
        Icons.event_note_outlined,
        'Organize My Day',
        'Make space for what matters.',
        'day',
      ),
      (
        Icons.insights_outlined,
        'Understand Reports',
        'Put your progress in perspective.',
        'report',
      ),
      (
        Icons.eco_outlined,
        'Improve Saving Habits',
        'Small steps, lasting routines.',
        'habits',
      ),
    ];
    final prompts = _controller.mode == AiMode.askAnything ? general : coach;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(14) > 20
            ? 1
            : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final prompt in prompts)
              SizedBox(
                width: width,
                child: AiPromptCard(
                  icon: prompt.$1,
                  title: prompt.$2,
                  detail: prompt.$3,
                  onTap: () {
                    if (_controller.mode == AiMode.askAnything) {
                      _fill(prompt.$4);
                    } else if (prompt.$4 == 'habits') {
                      _fill(
                        'Suggest practical saving habits without using personal data.',
                      );
                    } else {
                      _chooseContext(prompt.$4);
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _composer(double inset, bool compact) => Padding(
    padding: EdgeInsets.fromLTRB(inset, 6, inset, compact ? 4 : 10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
          decoration: BoxDecoration(
            color: context.atelierSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.atelierBorder),
            boxShadow: SaveTrackDesign.shadows,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: compact ? 2 : 4,
                  maxLength: AiConfig.maxQuestionCharacters,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.atelierInk,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: _controller.mode == AiMode.askAnything
                        ? 'Ask anything…'
                        : 'Ask your Coach…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _input,
                builder: (context, value, _) => IconButton.filled(
                  tooltip: _controller.busy ? 'Stop response' : 'Send question',
                  style: IconButton.styleFrom(
                    backgroundColor: context.atelierAccent,
                    foregroundColor: context.atelierSurface,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _controller.busy
                      ? _controller.cancel
                      : _loadingContext || value.text.trim().isEmpty
                      ? null
                      : _submit,
                  icon: Icon(
                    _controller.busy
                        ? Icons.stop_rounded
                        : Icons.arrow_upward_rounded,
                    size: 21,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!compact)
          Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text(
              'Keep questions free of personal or sensitive information.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.atelierMuted, fontSize: 10),
            ),
          ),
      ],
    ),
  );
}

class _NeverChanges implements Listenable {
  const _NeverChanges();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
