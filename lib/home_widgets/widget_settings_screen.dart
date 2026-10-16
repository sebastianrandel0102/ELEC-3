import 'dart:async';

import 'package:flutter/material.dart';

import '../currency_money.dart';
import '../design_system.dart';
import 'widget_controller.dart';
import 'widget_host.dart';
import 'widget_models.dart';

String widgetTypeName(HomeWidgetType type) => switch (type) {
  HomeWidgetType.goal => 'Savings Goal',
  HomeWidgetType.planner => "Today's Planner",
  HomeWidgetType.quickSave => 'Quick Save',
  HomeWidgetType.today => 'Today Overview',
};
String widgetPrivacyName(WidgetPrivacy privacy) => switch (privacy) {
  WidgetPrivacy.full => 'Full Details',
  WidgetPrivacy.progress => 'Progress Only',
  WidgetPrivacy.hidden => 'Hide All Private Details',
};
String widgetThemeName(WidgetTheme theme) => switch (theme) {
  WidgetTheme.emerald => 'Midnight Emerald',
  WidgetTheme.mint => 'Mint Light',
  WidgetTheme.white => 'Minimal White',
  WidgetTheme.system => 'Follow System',
};
IconData widgetTypeIcon(HomeWidgetType type) => switch (type) {
  HomeWidgetType.goal => Icons.savings_outlined,
  HomeWidgetType.planner => Icons.event_note_rounded,
  HomeWidgetType.quickSave => Icons.add_circle_outline,
  HomeWidgetType.today => Icons.dashboard_outlined,
};

class HomeWidgetsSettingsScreen extends StatefulWidget {
  const HomeWidgetsSettingsScreen({super.key});
  @override
  State<HomeWidgetsSettingsScreen> createState() =>
      _HomeWidgetsSettingsScreenState();
}

class _HomeWidgetsSettingsScreenState extends State<HomeWidgetsSettingsScreen> {
  bool _canPin = false, _loaded = false;
  String? _message;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final controller = HomeWidgetScope.of(context);
    unawaited(controller.reload().catchError((Object _) {}));
    unawaited(
      controller.bridge
          .canPin()
          .then((value) {
            if (mounted) setState(() => _canPin = value);
          })
          .catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = HomeWidgetScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Home Screen Widgets')),
      body: PageSurface(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Your progress, closer.',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Give savings and daily plans a place on your Android home screen. Each widget has its own settings.',
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            for (final type in HomeWidgetType.values) ...[
              WidgetPreviewCard(type: type),
              if (_canPin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text('Add ${widgetTypeName(type)}'),
                    onPressed: () async {
                      try {
                        final requested = await controller.bridge.pin(type);
                        if (mounted) {
                          setState(
                            () => _message = requested
                                ? 'Request sent to your launcher. Complete setup on the home screen.'
                                : 'Use the widget picker steps below.',
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () =>
                                _message = 'Use the widget picker steps below.',
                          );
                        }
                      }
                    },
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (_message != null)
              Text(_message!, style: const TextStyle(color: teal)),
            const SizedBox(height: 16),
            const Text(
              'On your Android home screen',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Long-press an empty area and open Widgets.\n2. Find SaveTrack and drag a widget onto your home screen.\n3. Choose your settings and save.\n4. Long-press the widget and drag the resize handles.\n\nSteps and available sizes vary by launcher.',
              style: TextStyle(color: muted, height: 1.7),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your widgets',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (controller.instances.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Add a widget from your home screen to customize it here.',
                ),
              ),
            for (final instance in controller.instances)
              Card(
                child: ListTile(
                  leading: MintIcon(widgetTypeIcon(instance.type)),
                  title: Text(widgetTypeName(instance.type)),
                  subtitle: Text(
                    instance.config == null
                        ? 'Setup needed'
                        : '${widgetThemeName(instance.config!.theme)} · ${widgetPrivacyName(instance.config!.privacy)}',
                  ),
                  trailing: const Icon(Icons.tune_rounded),
                  onTap: () {
                    final owner = controller.uid;
                    if (owner == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WidgetAccountGuard(
                          uid: owner,
                          child: WidgetConfigurationScreen(instance: instance),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (controller.error != null) Text(controller.error!),
            const SizedBox(height: 20),
            const Text(
              'Widgets use saved information and refresh as SaveTrack syncs. Background updates can be delayed by Android. Home-screen information can be seen even while your phone or app is locked.',
              style: TextStyle(fontSize: 12, color: muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class WidgetPreviewCard extends StatelessWidget {
  const WidgetPreviewCard({
    super.key,
    required this.type,
    this.theme,
    this.privacy,
    this.goal,
  });
  final HomeWidgetType type;
  final WidgetTheme? theme;
  final WidgetPrivacy? privacy;
  final WidgetGoalFacts? goal;
  @override
  Widget build(BuildContext context) {
    final light =
        theme == WidgetTheme.mint ||
        theme == WidgetTheme.white ||
        theme == WidgetTheme.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light ||
        theme == null && type == HomeWidgetType.planner;
    final color = light ? ink : Colors.white;
    final full = privacy == WidgetPrivacy.full;
    final hidden = privacy == WidgetPrivacy.hidden;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: light
            ? theme == WidgetTheme.white
                  ? Colors.white
                  : SaveTrackDesign.mist
            : null,
        gradient: light ? null : SaveTrackDesign.premium,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: light ? SaveTrackDesign.border : teal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widgetTypeIcon(type), color: SaveTrackDesign.premiumMint),
              const SizedBox(width: 8),
              Text(
                'SAVETRACK',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            hidden
                ? 'Open SaveTrack'
                : full && goal != null && type != HomeWidgetType.today
                ? goal!.title
                : widgetTypeName(type),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (type == HomeWidgetType.today && !hidden)
            _TodayPreview(goal: goal, full: full, light: light, color: color)
          else
            Text(
              hidden
                  ? 'Private details are hidden.'
                  : goal != null
                  ? (full
                        ? formatCurrency(goal!.saved, goal!.currency)
                        : '${(goal!.progress * 100).round()}% completed')
                  : switch (type) {
                      HomeWidgetType.goal =>
                        'A clear view of your savings progress.',
                      HomeWidgetType.planner =>
                        'Your tasks and progress for today.',
                      HomeWidgetType.quickSave =>
                        'Review and confirm every contribution in the app.',
                      HomeWidgetType.today =>
                        'Savings and daily plans, together.',
                    },
              style: TextStyle(
                color: light ? muted : SaveTrackDesign.onHeroMuted,
                height: 1.4,
              ),
            ),
          if (!hidden && type != HomeWidgetType.today) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal?.progress ?? 0,
                minHeight: 6,
                color: SaveTrackDesign.premiumMint,
                backgroundColor: light
                    ? SaveTrackDesign.border
                    : SaveTrackDesign.heroTrack,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayPreview extends StatelessWidget {
  const _TodayPreview({
    required this.goal,
    required this.full,
    required this.light,
    required this.color,
  });
  final WidgetGoalFacts? goal;
  final bool full;
  final bool light;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget summary(String label, String value, String detail, double progress) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: light ? Colors.white : const Color(0xFF124D40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: light ? SaveTrackDesign.border : const Color(0xFF286655),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 11)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(
                color: light ? muted : SaveTrackDesign.onHeroMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: SaveTrackDesign.premiumMint,
                backgroundColor: light
                    ? SaveTrackDesign.border
                    : SaveTrackDesign.heroTrack,
              ),
            ),
          ],
        ),
      );
    }

    final savings = summary(
      'Savings',
      goal == null ? 'Goal progress' : '${(goal!.progress * 100).round()}%',
      full && goal != null ? goal!.title : 'Your selected goal',
      goal?.progress ?? 0,
    );
    final tasks = summary(
      'Today’s tasks',
      'Daily plans',
      'Tasks and progress',
      0,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth / textScale < 240) {
          return Column(children: [savings, const SizedBox(height: 8), tasks]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: savings),
            const SizedBox(width: 8),
            Expanded(child: tasks),
          ],
        );
      },
    );
  }
}

class WidgetConfigurationScreen extends StatefulWidget {
  const WidgetConfigurationScreen({
    super.key,
    required this.instance,
    this.launcher = false,
  });
  final HomeWidgetInstance instance;
  final bool launcher;
  @override
  State<WidgetConfigurationScreen> createState() =>
      _WidgetConfigurationScreenState();
}

class _WidgetConfigurationScreenState extends State<WidgetConfigurationScreen> {
  final _form = GlobalKey<FormState>();
  final _amounts = List.generate(3, (_) => TextEditingController());
  HomeWidgetController? _controller;
  List<WidgetGoalFacts> _goals = [];
  WidgetGoalFacts? _goal;
  late WidgetTheme _theme;
  late WidgetPrivacy _privacy;
  bool _tasks = false,
      _cover = false,
      _busy = false,
      _loading = true,
      _finished = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final config = widget.instance.config;
    _theme =
        config?.theme ??
        (widget.instance.type == HomeWidgetType.planner
            ? WidgetTheme.mint
            : WidgetTheme.emerald);
    _privacy = config?.privacy ?? WidgetPrivacy.progress;
    _tasks = config?.showTaskTitles ?? false;
    _cover = config?.showCover ?? false;
    for (var i = 0; i < (config?.presets.length ?? 0); i++) {
      _amounts[i].text = config!.presets[i];
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller = HomeWidgetScope.of(context);
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = _controller!.uid;
      if (uid == null) throw StateError('Sign in to customize your widget.');
      final choices = widget.instance.type == HomeWidgetType.planner
          ? <WidgetGoalFacts>[]
          : await _controller!.source
                .choices(uid)
                .timeout(const Duration(seconds: 20));
      if (!mounted || uid != _controller!.uid) return;
      setState(() {
        _goals = choices;
        for (final goal in choices) {
          if (goal.ref.key == widget.instance.config?.goal?.key) _goal = goal;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load your goals. Open SaveTrack online and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final controller = _controller!, owner = _controller!.uid;
    if (owner == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final presets = <String>[];
      for (final field in _amounts) {
        if (field.text.trim().isEmpty) continue;
        final value = parseCurrencyAmount(
          field.text.trim(),
          _goal?.currency ?? '',
        );
        if (value == null || !value.positive) {
          throw const FormatException('Review the shortcut amounts.');
        }
        presets.add(
          value.fixed(CurrencyCatalog.require(_goal!.currency).digits),
        );
      }
      await controller.save(
        HomeWidgetConfig(
          id: widget.instance.id,
          type: widget.instance.type,
          uid: owner,
          goal: _goal?.ref,
          currency: _goal?.currency,
          theme: _theme,
          privacy: _privacy,
          showTaskTitles: _tasks,
          showCover: _cover,
          presets: presets,
        ),
      );
      if (!mounted) return;
      _finished = true;
      if (widget.launcher) {
        await controller.bridge.completeConfiguration(widget.instance.id, true);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Could not save this widget. Check your session and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final field in _amounts) {
      field.dispose();
    }
    if (widget.launcher && !_finished) {
      unawaited(
        _controller?.bridge.completeConfiguration(widget.instance.id, false),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsGoal = widget.instance.type != HomeWidgetType.planner;
    final planner =
        widget.instance.type == HomeWidgetType.planner ||
        widget.instance.type == HomeWidgetType.today;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Customize Your Widget')),
        body: PageSurface(
          child: Material(
            type: MaterialType.transparency,
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  WidgetPreviewCard(
                    type: widget.instance.type,
                    theme: _theme,
                    privacy: _privacy,
                    goal: _goal,
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (needsGoal && !_loading) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(_goal?.ref.key),
                      initialValue: _goal?.ref.key,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Choose Goal',
                      ),
                      items: [
                        for (final goal in _goals)
                          DropdownMenuItem(
                            value: goal.ref.key,
                            child: Text(
                              '${goal.title} · ${goal.currency}${goal.ref.shared ? ' · Shared' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Choose a savings goal.' : null,
                      onChanged: _busy
                          ? null
                          : (key) => setState(() {
                              _goal = _goals.firstWhere(
                                (g) => g.ref.key == key,
                              );
                              for (final field in _amounts) {
                                field.clear();
                              }
                            }),
                    ),
                    if (_goals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Create a savings goal in SaveTrack, then return here.',
                        ),
                      ),
                    if (_goal != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${(_goal!.progress * 100).round()}% completed · ${_goal!.currency}',
                          style: const TextStyle(color: muted),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                  DropdownButtonFormField<WidgetTheme>(
                    initialValue: _theme,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Choose Theme',
                    ),
                    items: [
                      for (final theme in WidgetTheme.values)
                        DropdownMenuItem(
                          value: theme,
                          child: Text(widgetThemeName(theme)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _theme = value!),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<WidgetPrivacy>(
                    initialValue: _privacy,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Home-screen Privacy',
                    ),
                    items: [
                      for (final privacy in WidgetPrivacy.values)
                        DropdownMenuItem(
                          value: privacy,
                          child: Text(widgetPrivacyName(privacy)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _privacy = value!),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Full Details shows goal names and money amounts to anyone who can see your home screen. Progress Only hides names, amounts, and task titles. App lock does not hide widget content.',
                    style: TextStyle(fontSize: 12, color: muted, height: 1.5),
                  ),
                  if (planner)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show task titles'),
                      subtitle: const Text('Task notes are never shown.'),
                      value: _tasks,
                      onChanged: _busy || _privacy != WidgetPrivacy.full
                          ? null
                          : (value) => setState(() => _tasks = value),
                    ),
                  if (needsGoal) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show goal cover'),
                      subtitle: const Text(
                        'Use a small thumbnail in larger layouts.',
                      ),
                      value: _cover,
                      onChanged: _busy || _privacy != WidgetPrivacy.full
                          ? null
                          : (value) => setState(() => _cover = value),
                    ),
                  ],
                  if (widget.instance.type == HomeWidgetType.quickSave) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Quick Save shortcuts${_goal == null ? '' : ' · ${_goal!.currency}'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Optional amounts. Every contribution is reviewed and confirmed in SaveTrack.',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < _amounts.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _amounts[index],
                          enabled: !_busy && _goal != null,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Shortcut ${index + 1} (optional)',
                            suffixText: _goal?.currency,
                          ),
                          validator: (text) {
                            if (text == null || text.trim().isEmpty) {
                              return null;
                            }
                            final value = parseCurrencyAmount(
                              text.trim(),
                              _goal?.currency ?? '',
                            );
                            return value == null || !value.positive
                                ? 'Enter a positive amount with valid currency precision.'
                                : null;
                          },
                        ),
                      ),
                  ],
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: SaveTrackDesign.error),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('Reload goals'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _busy || _loading ? null : _save,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Save Widget'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Resize the widget from your Android home screen. The launcher controls the available sizes.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
