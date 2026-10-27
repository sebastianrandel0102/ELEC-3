import 'dart:async';

import 'package:flutter/material.dart';

import '../currency_money.dart';
import '../design_system.dart';
import 'widget_controller.dart';
import 'widget_host.dart';
import 'widget_models.dart';
import 'widget_preview.dart';
import 'widget_visuals.dart';

export 'widget_preview.dart' show WidgetPreviewCard;
export 'widget_visuals.dart';

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
            Text(
              'Your progress, closer.',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: context.atelierInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Give savings and daily plans a place on your Android home screen. Each widget has its own settings.',
              style: TextStyle(color: context.atelierMuted, height: 1.5),
            ),
            const SizedBox(height: 20),
            for (final type in HomeWidgetType.values) ...[
              Text(
                widgetTypeName(type),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.atelierInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widgetTypeDescription(type),
                style: TextStyle(color: context.atelierMuted, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                '${type == HomeWidgetType.today ? '4 × 3' : '4 × 2'} starting size · Resizable',
                style: TextStyle(fontSize: 11, color: context.atelierMuted),
              ),
              const SizedBox(height: 12),
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
              Text(_message!, style: TextStyle(color: context.atelierAccent)),
            const SizedBox(height: 16),
            const Text(
              'On your Android home screen',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '1. Long-press an empty area and open Widgets.\n2. Find SaveTrack and drag a widget onto your home screen.\n3. Choose your settings and save.\n4. Long-press the widget and drag the resize handles.\n\nSteps and available sizes vary by launcher.',
              style: TextStyle(color: context.atelierMuted, height: 1.7),
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
            Text(
              'Widgets use saved information and refresh as SaveTrack syncs. Background updates can be delayed by Android. Home-screen information can be seen even while your phone or app is locked.',
              style: TextStyle(
                fontSize: 12,
                color: context.atelierMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
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
                  Text(
                    'Make it yours.',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: context.atelierInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widgetTypeDescription(widget.instance.type),
                    style: TextStyle(color: context.atelierMuted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EDE7),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: WidgetPreviewCard(
                      type: widget.instance.type,
                      theme: _theme,
                      privacy: _privacy,
                      goal: _goal,
                      planner: _controller?.plannerFacts,
                      showTaskTitles: _tasks,
                      presets: _goal == null
                          ? const []
                          : [
                              for (final field in _amounts)
                                if (parseCurrencyAmount(
                                      field.text.trim(),
                                      _goal!.currency,
                                    )?.positive ==
                                    true)
                                  field.text.trim(),
                            ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Long-press the widget on your home screen and drag the resize handles. The layout adjusts automatically.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.atelierMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (needsGoal && !_loading) ...[
                    const _StudioHeading('Selected content'),
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
                          style: TextStyle(color: context.atelierMuted),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                  const _StudioHeading('Appearance'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final theme in [
                        WidgetTheme.mint,
                        WidgetTheme.emerald,
                        WidgetTheme.system,
                      ])
                        _StudioOption(
                          label: widgetThemeName(theme),
                          icon: switch (theme) {
                            WidgetTheme.mint => Icons.light_mode_outlined,
                            WidgetTheme.emerald => Icons.dark_mode_outlined,
                            _ => Icons.smartphone_rounded,
                          },
                          selected:
                              _theme == theme ||
                              theme == WidgetTheme.mint &&
                                  _theme == WidgetTheme.white,
                          onTap: _busy
                              ? null
                              : () => setState(() => _theme = theme),
                        ),
                    ],
                  ),
                  if (_theme == WidgetTheme.mint || _theme == WidgetTheme.white)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('White canvas'),
                      subtitle: const Text('A clean white variation of Light.'),
                      value: _theme == WidgetTheme.white,
                      onChanged: _busy
                          ? null
                          : (white) => setState(
                              () => _theme = white
                                  ? WidgetTheme.white
                                  : WidgetTheme.mint,
                            ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _theme == WidgetTheme.system
                        ? 'Follows your Android appearance.'
                        : _theme == WidgetTheme.emerald
                        ? 'Mint Aurora · Midnight Emerald'
                        : 'Mint Aurora · Daylight',
                    style: TextStyle(fontSize: 12, color: context.atelierMuted),
                  ),
                  const SizedBox(height: 20),
                  const _StudioHeading('Privacy'),
                  for (final privacy in WidgetPrivacy.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: _privacy == privacy
                            ? context.atelierSelected
                            : context.atelierSurface,
                        borderRadius: BorderRadius.circular(16),
                        child: Semantics(
                          selected: _privacy == privacy,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: Icon(
                              privacy == WidgetPrivacy.full
                                  ? Icons.visibility_outlined
                                  : privacy == WidgetPrivacy.progress
                                  ? Icons.shield_outlined
                                  : Icons.lock_outline,
                              color: context.atelierAccent,
                            ),
                            title: Text(widgetPrivacyName(privacy)),
                            subtitle: Text(switch (privacy) {
                              WidgetPrivacy.full =>
                                'Goal names and exact amounts.',
                              WidgetPrivacy.progress =>
                                'Progress and counts. Names stay private.',
                              WidgetPrivacy.hidden =>
                                'A private shortcut to SaveTrack.',
                            }),
                            trailing: Icon(
                              _privacy == privacy
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: context.atelierAccent,
                            ),
                            onTap: _busy
                                ? null
                                : () => setState(() => _privacy = privacy),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Full Details shows goal names and money amounts to anyone who can see your home screen. Progress Only hides names, amounts, and task titles. App lock does not hide widget content.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.atelierMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _StudioHeading('Additional options'),
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
                    Text(
                      'Optional amounts. Quick Save supports review and confirmation on the home screen with Full Details enabled.',
                      style: TextStyle(color: context.atelierMuted),
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < _amounts.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _amounts[index],
                          onChanged: (_) => setState(() {}),
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
                      style: TextStyle(color: context.atelierError),
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
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.maybePop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Resize the widget from your Android home screen. The launcher controls the available sizes.',
                    style: TextStyle(color: context.atelierMuted, fontSize: 12),
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

class _StudioHeading extends StatelessWidget {
  const _StudioHeading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: context.atelierInk,
      ),
    ),
  );
}

class _StudioOption extends StatelessWidget {
  const _StudioOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onTap != null,
    child: Material(
      color: selected ? context.atelierSelected : context.atelierSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? context.atelierAccent : context.atelierBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: context.atelierInk),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.atelierInk,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: context.atelierInk,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
