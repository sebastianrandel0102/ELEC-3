import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system.dart';

enum GoalPresentation { gallery, grid, list }

enum PulsePresentation { chart, metrics, compact }

enum ReminderPresentation { timeline, nextUp }

enum HomeSection {
  goals('Goal Gallery'),
  pulse('Savings Pulse'),
  reminders('Up Next'),
  planner('Daily Planner'),
  agent('AI & Agent');

  const HomeSection(this.label);
  final String label;
}

/// Device appearance and account-scoped presentation only. No cloud writes.
class AtelierPreferences extends ChangeNotifier {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  AtelierPreferences(this.storage, {this.account = 'guest'}) {
    _read();
  }
  final SharedPreferences storage;
  final String account;
  ThemeMode appearance = ThemeMode.system;
  GoalPresentation goals = GoalPresentation.gallery;
  PulsePresentation pulse = PulsePresentation.chart;
  ReminderPresentation reminders = ReminderPresentation.timeline;
  List<HomeSection> order = HomeSection.values.toList();
  Set<HomeSection> hidden = {HomeSection.agent};
  String? featuredGoal;
  String? error;
  String get _key => 'savetrack.atelier71.$account';
  Future<void> _writes = Future.value();
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  T _enum<T extends Enum>(List<T> values, Object? value, T fallback) =>
      values.where((e) => e.name == value).firstOrNull ?? fallback;

  void _read() {
    appearance = _enum(
      ThemeMode.values,
      storage.getString('savetrack.appearance'),
      ThemeMode.system,
    );
    themeMode.value = appearance;
    try {
      final raw = jsonDecode(storage.getString(_key) ?? '{}');
      if (raw is! Map) return;
      goals = _enum(GoalPresentation.values, raw['goals'], goals);
      pulse = _enum(PulsePresentation.values, raw['pulse'], pulse);
      reminders = _enum(
        ReminderPresentation.values,
        raw['reminders'],
        reminders,
      );
      if (raw['hidden'] is List) {
        hidden = HomeSection.values
            .where((e) => (raw['hidden'] as List).contains(e.name))
            .toSet();
      }
      if (raw['order'] is List) {
        order = {
          for (final name in raw['order'])
            ...HomeSection.values.where((e) => e.name == name),
          ...HomeSection.values,
        }.toList();
      }
      featuredGoal = raw['featuredGoal'] is String
          ? raw['featuredGoal'] as String
          : null;
    } on FormatException {
      /* Corrupt presentation preferences use defaults. */
    }
  }

  Future<void> save() {
    if (_disposed) return Future.value();
    final layout = jsonEncode({
      'goals': goals.name,
      'pulse': pulse.name,
      'reminders': reminders.name,
      'order': order.map((e) => e.name).toList(),
      'hidden': hidden.map((e) => e.name).toList(),
      'featuredGoal': featuredGoal,
    });
    final mode = appearance.name;
    themeMode.value = appearance;
    error = null;
    notifyListeners();
    _writes = _writes.then((_) async {
      try {
        final saved = await storage.setString(_key, layout);
        final themeSaved = await storage.setString(
          'savetrack.appearance',
          mode,
        );
        if (!saved || !themeSaved) throw StateError('Preferences unavailable');
      } catch (_) {
        error =
            'Your selection is active, but could not be saved on this device.';
        if (!_disposed) notifyListeners();
      }
    });
    return _writes;
  }

  Future<void> restore() {
    goals = GoalPresentation.gallery;
    pulse = PulsePresentation.chart;
    reminders = ReminderPresentation.timeline;
    order = HomeSection.values.toList();
    hidden = {HomeSection.agent};
    featuredGoal = null;
    return save();
  }
}

class AtelierScope extends InheritedNotifier<AtelierPreferences> {
  const AtelierScope({
    super.key,
    required AtelierPreferences preferences,
    required super.child,
  }) : super(notifier: preferences);
  static AtelierPreferences? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AtelierScope>()?.notifier;
}

class AtelierHost extends StatefulWidget {
  const AtelierHost({super.key, required this.child, this.account = 'guest'});
  final Widget child;
  final String account;
  @override
  State<AtelierHost> createState() => _AtelierHostState();
}

class _AtelierHostState extends State<AtelierHost> {
  AtelierPreferences? preferences;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final storage = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(
        () =>
            preferences = AtelierPreferences(storage, account: widget.account),
      );
    } catch (_) {
      // The application remains usable if device preferences are unavailable.
    }
  }

  @override
  void dispose() {
    preferences?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => preferences == null
      ? widget.child
      : AtelierScope(preferences: preferences!, child: widget.child);
}

class CustomizeHomeScreen extends StatelessWidget {
  const CustomizeHomeScreen({super.key, required this.preferences});
  final AtelierPreferences preferences;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: preferences,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Customize Home')),
      body: PageSurface(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const ScreenIntro(
              eyebrow: 'Home Atelier',
              title: 'A space that feels like you.',
              detail: 'Choose your views, then arrange what matters. Saved on this device for your account.',
            ),
            _choice(
              context,
              'Goal presentation',
              GoalPresentation.values,
              preferences.goals,
              (value) {
                preferences.goals = value;
              },
            ),
            _choice(
              context,
              'Savings Pulse',
              PulsePresentation.values,
              preferences.pulse,
              (value) {
                preferences.pulse = value;
              },
            ),
            _choice(
              context,
              'Upcoming reminders',
              ReminderPresentation.values,
              preferences.reminders,
              (value) {
                preferences.reminders = value;
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Your Home sections',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Savings Overview always stays at the top. Use the arrows to change section order.',
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < preferences.order.length; i++)
              _section(context, i),
            if (preferences.featuredGoal != null)
              TextButton.icon(
                onPressed: () {
                  preferences.featuredGoal = null;
                  unawaited(preferences.save());
                },
                icon: const Icon(Icons.push_pin_outlined),
                label: const Text('Clear featured goal'),
              ),
            if (preferences.error != null)
              AuroraNotice(preferences.error!, error: true),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: preferences.restore,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Restore Default Layout'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _choice<T extends Enum>(
    BuildContext context,
    String title,
    List<T> values,
    T value,
    void Function(T) change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      key: ValueKey('$title-${value.name}'),
      isExpanded: true,
      decoration: InputDecoration(labelText: title),
      items: values
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(switch (e.name) {
                'nextUp' => 'Next Up',
                'chart' => 'Mini chart',
                'metrics' => 'Metric cards',
                'compact' => 'Compact summary',
                final name => '${name[0].toUpperCase()}${name.substring(1)}',
              }),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) {
          change(v);
          unawaited(preferences.save());
        }
      },
    ),
  );

  Widget _section(BuildContext context, int i) {
    final section = preferences.order[i];
    void move(int delta) {
      final item = preferences.order.removeAt(i);
      preferences.order.insert(i + delta, item);
      unawaited(preferences.save());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            SwitchListTile.adaptive(
              title: Text(section.label),
              value: !preferences.hidden.contains(section),
              onChanged: (value) {
                value
                    ? preferences.hidden.remove(section)
                    : preferences.hidden.add(section);
                unawaited(preferences.save());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Move ${section.label} up',
                  onPressed: i == 0 ? null : () => move(-1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Move ${section.label} down',
                  onPressed: i == preferences.order.length - 1
                      ? null
                      : () => move(1),
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAppearancePicker(
  BuildContext context,
  AtelierPreferences preferences,
) => showModalBottomSheet<void>(
  context: context,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final mode in ThemeMode.values)
            ListTile(
              leading: Icon(switch (mode) {
                ThemeMode.light => Icons.light_mode_outlined,
                ThemeMode.dark => Icons.dark_mode_outlined,
                ThemeMode.system => Icons.brightness_auto_outlined,
              }),
              title: Text(switch (mode) {
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
                ThemeMode.system => 'Follow System',
              }),
              trailing: preferences.appearance == mode
                  ? const Icon(Icons.check_circle_outline)
                  : null,
              onTap: () {
                preferences.appearance = mode;
                unawaited(preferences.save());
                Navigator.pop(context);
              },
            ),
        ],
      ),
    ),
  ),
);
