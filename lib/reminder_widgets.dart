import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system.dart';
import 'reminder_coordinator.dart';
import 'reminder_models.dart';
import 'reminder_repository.dart';
import 'reminder_scheduler.dart';

export 'reminder_models.dart';

class ReminderScope extends InheritedNotifier<ReminderCoordinator> {
  const ReminderScope({
    super.key,
    required ReminderCoordinator coordinator,
    required super.child,
  }) : super(notifier: coordinator);
  static ReminderCoordinator? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReminderScope>()?.notifier;
}

class ReminderHost extends StatefulWidget {
  const ReminderHost({
    super.key,
    required this.child,
    required this.openTarget,
  });
  final Widget child;
  final Future<void> Function(ReminderCoordinator, ReminderPayload) openTarget;
  @override
  State<ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends State<ReminderHost>
    with WidgetsBindingObserver {
  late final coordinator = ReminderCoordinator(
    repository: FirestoreReminderRepository(),
    scheduler: NativeNotificationScheduler(),
    deviceStore: PreferenceReminderDeviceStore(),
  );
  StreamSubscription<User?>? _auth;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    coordinator.onTap = (_) => _deliverTap();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await coordinator.initialize();
    } catch (e) {
      coordinator.error = reminderError(e);
    }
    if (!mounted) return;
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(
        coordinator
            .switchAccount(user?.uid)
            .then((_) => _deliverTap())
            .catchError((Object e) {
              coordinator.error = reminderError(e);
            }),
      );
    });
  }

  void _deliverTap() {
    if (!mounted ||
        _opening ||
        coordinator.pendingTap == null ||
        coordinator.uid == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          _opening ||
          coordinator.pendingTap == null ||
          coordinator.uid == null) {
        return;
      }
      _opening = true;
      final payload = coordinator.pendingTap!;
      coordinator.pendingTap = null;
      try {
        await widget.openTarget(coordinator, payload);
      } finally {
        _opening = false;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        coordinator.resume().catchError((Object e) {
          coordinator.error = reminderError(e);
        }),
      );
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    coordinator.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ReminderScope(coordinator: coordinator, child: widget.child);
}

String reminderSummary(BuildContext context, ReminderConfiguration config) {
  if (!config.enabled) return 'Reminder off';
  final time = TimeOfDay(
    hour: config.hour,
    minute: config.minute,
  ).format(context);
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return switch (config.frequency) {
    ReminderFrequency.daily => 'Every day · $time',
    ReminderFrequency.weekly => '${weekdays[config.weekday - 1]} · $time',
    ReminderFrequency.deadline =>
      '${config.daysBefore == 0 ? 'On deadline' : '${config.daysBefore} days before deadline'} · $time',
    ReminderFrequency.taskStart =>
      config.offsetMinutes == 0
          ? 'At task start'
          : '${config.offsetMinutes} minutes before task start',
    ReminderFrequency.once =>
      config.instant == null
          ? time
          : '${config.instant!.toLocal().day}/${config.instant!.toLocal().month}/${config.instant!.toLocal().year} · ${TimeOfDay.fromDateTime(config.instant!.toLocal()).format(context)}',
  };
}

Future<TimeOfDay?> showReminderTimePicker(
  BuildContext context,
  TimeOfDay time,
) => showTimePicker(
  context: context,
  initialTime: time,
  initialEntryMode: TimePickerEntryMode.dial,
  helpText: 'Choose reminder time',
  confirmText: 'Confirm',
  builder: (context, child) => Theme(
    data: Theme.of(context).copyWith(
      timePickerTheme: TimePickerThemeData(
        backgroundColor: context.atelierSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        dialHandColor: SaveTrackDesign.emerald,
        dialBackgroundColor: context.atelierSelected,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? context.atelierSelected
              : context.atelierTonal,
        ),
        hourMinuteTextColor: context.atelierInk,
        dayPeriodColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? context.atelierSelected
              : context.atelierSurface,
        ),
        dayPeriodTextColor: context.atelierInk,
      ),
    ),
    child: child!,
  ),
);

Future<bool> _ensurePermission(
  BuildContext context,
  ReminderCoordinator coordinator,
  ReminderTargetType type,
) async {
  if (!coordinator.scheduler.supported) return false;
  final capability = await coordinator.scheduler.capability(type);
  if (capability.allowed) return true;
  final preferences = await SharedPreferences.getInstance();
  if (!context.mounted) return false;
  // One system prompt per installation. Later attempts use an explicit settings path.
  if (preferences.getBool('reminder_permission_requested_v1') == true) {
    return false;
  }
  final request = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      scrollable: true,
      icon: const MintIcon(Icons.notifications_outlined),
      title: const Text('Allow phone reminders'),
      content: const Text(
        'SaveTrack needs notification permission to show the reminders you choose, even while the app is closed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (request != true) return false;
  await preferences.setBool('reminder_permission_requested_v1', true);
  return coordinator.scheduler.requestPermission();
}

Future<ReminderConfiguration?> configureReminderDraft(
  BuildContext context, {
  required String uid,
  required ReminderTarget target,
  ReminderConfiguration? initial,
}) => showModalBottomSheet<ReminderConfiguration>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ReminderEditor(
    uid: uid,
    target: target,
    initial: initial,
    onSave: (config) async {
      final coordinator = ReminderScope.maybeOf(context);
      config.validate();
      if (config.enabled) {
        final zone =
            coordinator?.zone ?? await NativeNotificationScheduler().timezone();
        if (const ReminderTimeCalculator().next(
              config,
              target,
              zone,
              DateTime.now(),
            ) ==
            null) {
          throw const ReminderFailure('Please choose a future reminder time.');
        }
        if (coordinator != null && context.mounted) {
          await _ensurePermission(context, coordinator, target.type);
        }
      }
      return const ReminderStatus(
        ReminderDelivery.waiting,
        'Reminder draft ready. Save the task to apply it.',
      );
    },
  ),
);

Future<void> showReminderEditor(
  BuildContext context,
  ReminderTarget target,
) async {
  final coordinator = ReminderScope.maybeOf(context);
  if (coordinator == null || coordinator.uid == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to manage your reminders.')),
    );
    return;
  }
  final uid = coordinator.uid!;
  final result = await showModalBottomSheet<ReminderConfiguration>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ReminderEditor(
      uid: uid,
      target: target,
      initial: coordinator.configurations[target.key],
      onSave: (config) async {
        if (config.enabled) {
          await _ensurePermission(context, coordinator, config.type);
        }
        // Server rules are the final access check. Target snapshots reconcile
        // changes from other devices; never mutate the target record here.
        await coordinator.save(config, target);
        return coordinator.status(config.key);
      },
      openSettings: () => coordinator.scheduler.openSettings(),
    ),
  );
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(coordinator.status(result.key).message)),
    );
  }
}

class ReminderButton extends StatelessWidget {
  const ReminderButton({super.key, required this.target, this.shared = false});
  final ReminderTarget target;
  final bool shared;
  @override
  Widget build(BuildContext context) {
    final coordinator = ReminderScope.maybeOf(context);
    final config = coordinator?.configurations[target.key];
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => showReminderEditor(context, target),
        icon: Icon(
          config?.enabled == true
              ? Icons.notifications_active_outlined
              : Icons.notifications_none,
          size: 18,
        ),
        label: Text(
          config == null
              ? (shared ? 'Set My Reminder' : 'Set Reminder')
              : '${reminderSummary(context, config)}${config.enabled || coordinator?.status(target.key).delivery == ReminderDelivery.failed ? '\n${coordinator!.status(target.key).message}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

class ReminderEditor extends StatefulWidget {
  const ReminderEditor({
    super.key,
    required this.uid,
    required this.target,
    this.initial,
    required this.onSave,
    this.openSettings,
    this.clock,
  });
  final String uid;
  final ReminderTarget target;
  final ReminderConfiguration? initial;
  final Future<ReminderStatus> Function(ReminderConfiguration) onSave;
  final Future<void> Function()? openSettings;
  final DateTime Function()? clock;
  @override
  State<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<ReminderEditor> {
  late bool enabled = widget.initial?.enabled ?? false;
  late bool showTitle = widget.initial?.showTitle ?? false;
  late ReminderFrequency frequency =
      widget.initial?.frequency ??
      (widget.target.type == ReminderTargetType.task
          ? ReminderFrequency.once
          : ReminderFrequency.daily);
  late TimeOfDay time =
      widget.initial?.frequency == ReminderFrequency.once &&
          widget.initial?.instant != null
      ? TimeOfDay.fromDateTime(widget.initial!.instant!.toLocal())
      : TimeOfDay(
          hour: widget.initial?.hour ?? 20,
          minute: widget.initial?.minute ?? 0,
        );
  late DateTime date =
      widget.initial?.instant?.toLocal() ??
      widget.target.taskDay ??
      (widget.clock?.call() ?? DateTime.now());
  late int weekday = widget.initial?.weekday ?? DateTime.monday;
  late int offset = widget.initial?.offsetMinutes ?? 15;
  late int daysBefore = widget.initial?.daysBefore ?? 0;
  bool busy = false;
  String? error;

  Future<ReminderConfiguration> _configuration() async {
    DateTime? instant = widget.initial?.instant;
    if (enabled && frequency == ReminderFrequency.once) {
      final zone =
          ReminderScope.maybeOf(context)?.zone ??
          await NativeNotificationScheduler().timezone();
      instant = const ReminderTimeCalculator()
          .local(zone, date, time.hour, time.minute)
          .toUtc();
    }
    return ReminderConfiguration(
      uid: widget.uid,
      type: widget.target.type,
      targetId: widget.target.id,
      enabled: enabled,
      hour: time.hour,
      minute: time.minute,
      frequency: frequency,
      instant: instant,
      weekday: weekday,
      offsetMinutes: offset,
      daysBefore: daysBefore,
      showTitle: showTitle,
    );
  }

  Future<void> _save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final config = await _configuration();
      final result = await widget.onSave(config);
      if (!mounted) return;
      if (result.delivery == ReminderDelivery.failed ||
          (config.enabled &&
              !result.scheduled &&
              result.delivery != ReminderDelivery.waiting)) {
        setState(() {
          error = result.message;
          busy = false;
        });
        // Keep the saved configuration visible along with its honest unavailable state.
        return;
      }
      Navigator.pop(context, config);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = reminderError(e);
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.target.type == ReminderTargetType.task;
    final choices = task
        ? [
            ReminderFrequency.once,
            if (widget.target.taskStart != null ||
                frequency == ReminderFrequency.taskStart)
              ReminderFrequency.taskStart,
          ]
        : [
            ReminderFrequency.once,
            ReminderFrequency.daily,
            ReminderFrequency.weekly,
            if (widget.target.deadline != null ||
                frequency == ReminderFrequency.deadline)
              ReminderFrequency.deadline,
          ];
    return PopScope(
      canPop: !busy,
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: .92,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                FormHeading(
                  icon: Icons.notifications_outlined,
                  title: task ? 'Task Reminder' : 'Savings Reminder',
                  detail: 'Choose when you’d like to be notified.',
                ),
                const SizedBox(height: 12),
                Text(
                  widget.target.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                if (widget.target.type == ReminderTargetType.sharedGoal)
                  Text(
                    'Only your reminder changes. Other members choose their own.',
                    style: TextStyle(color: context.atelierMuted),
                  ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Reminder'),
                  value: enabled,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => enabled = value),
                ),
                AnimatedOpacity(
                  duration: SaveTrackDesign.selectionMotion,
                  opacity: enabled ? 1 : .75,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        label:
                            'Reminder time, ${time.format(context)}. Opens clock picker.',
                        button: true,
                        child: Card(
                          color: context.atelierTonal,
                          child: InkWell(
                            key: const ValueKey('reminder-time'),
                            borderRadius: BorderRadius.circular(22),
                            onTap: busy
                                ? null
                                : () async {
                                    final selected =
                                        await showReminderTimePicker(
                                          context,
                                          time,
                                        );
                                    if (selected != null && mounted) {
                                      setState(() => time = selected);
                                    }
                                  },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Text(
                                    'Reminder time',
                                    style: TextStyle(
                                      color: context.atelierMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        color: context.atelierAccent,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          time.format(context),
                                          style: const TextStyle(
                                            fontSize: 30,
                                            color: SaveTrackDesign.midnight,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: context.atelierAccent,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const FieldCaption('Frequency'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: choices
                            .map(
                              (choice) => ChoiceChip(
                                label: Text(switch (choice) {
                                  ReminderFrequency.once =>
                                    task ? 'Custom date & time' : 'Once',
                                  ReminderFrequency.daily => 'Daily',
                                  ReminderFrequency.weekly => 'Weekly',
                                  ReminderFrequency.deadline =>
                                    'Before Deadline',
                                  ReminderFrequency.taskStart =>
                                    'At / before task start',
                                }),
                                selected: frequency == choice,
                                onSelected: busy
                                    ? null
                                    : (_) => setState(() => frequency = choice),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      if (frequency == ReminderFrequency.once)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            'Reminder date · ${date.day}/${date.month}/${date.year}',
                          ),
                          onPressed: busy
                              ? null
                              : () async {
                                  final selected = await showDatePicker(
                                    context: context,
                                    initialDate: date,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (selected != null && mounted) {
                                    setState(() => date = selected);
                                  }
                                },
                        ),
                      if (frequency == ReminderFrequency.weekly)
                        DropdownButtonFormField<int>(
                          initialValue: weekday,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Weekday',
                          ),
                          items: List.generate(
                            7,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text(
                                [
                                  'Monday',
                                  'Tuesday',
                                  'Wednesday',
                                  'Thursday',
                                  'Friday',
                                  'Saturday',
                                  'Sunday',
                                ][index],
                              ),
                            ),
                          ),
                          onChanged: busy
                              ? null
                              : (value) => setState(() => weekday = value!),
                        ),
                      if (frequency == ReminderFrequency.deadline)
                        DropdownButtonFormField<int>(
                          initialValue: daysBefore,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Timing relative to goal deadline',
                          ),
                          items: [0, 1, 3, 7]
                              .map(
                                (days) => DropdownMenuItem(
                                  value: days,
                                  child: Text(
                                    days == 0
                                        ? 'On deadline day'
                                        : '$days days before',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (value) => setState(() => daysBefore = value!),
                        ),
                      if (frequency == ReminderFrequency.taskStart) ...[
                        DropdownButtonFormField<int>(
                          initialValue: offset,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Before scheduled task start',
                          ),
                          items: [0, 5, 10, 15, 30, 60]
                              .map(
                                (minutes) => DropdownMenuItem(
                                  value: minutes,
                                  child: Text(
                                    minutes == 0
                                        ? 'At task start'
                                        : '$minutes minutes before',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (value) => setState(() => offset = value!),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Uses the task’s actual start time. The custom time card applies when Custom date & time is selected.',
                          style: TextStyle(
                            color: context.atelierMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show item name in notification'),
                        subtitle: const Text(
                          'Off by default for lock-screen privacy.',
                        ),
                        value: showTitle,
                        onChanged: busy
                            ? null
                            : (value) => setState(() => showTitle = value),
                      ),
                      TonalPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification Preview',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.atelierMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              reminderTitle(widget.target.type),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(reminderBody(widget.target, showTitle)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Android timing may be approximate unless precise alarms are allowed. System settings and battery restrictions can affect delivery.',
                  style: TextStyle(fontSize: 12, color: context.atelierMuted),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: AuroraNotice(error!, error: true),
                  ),
                if (error != null && widget.openSettings != null)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            try {
                              await widget.openSettings!();
                            } catch (e) {
                              if (mounted) {
                                setState(() => error = reminderError(e));
                              }
                            }
                          },
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open notification settings'),
                  ),
                const SizedBox(height: 16),
                GradientButton(
                  onPressed: busy ? null : _save,
                  child: SaveActionLabel(busy: busy, label: 'Save Reminder'),
                ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SmartRemindersScreen extends StatelessWidget {
  const SmartRemindersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final coordinator = ReminderScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Reminders')),
      body: PageSurface(
        child: SafeArea(
          child: coordinator == null || coordinator.uid == null
              ? const Center(child: Text('Sign in to manage reminders.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const FormHeading(
                      icon: Icons.notifications_outlined,
                      title: 'Your reminders',
                      detail: 'Preferences sync with your account. This phone schedules its own notifications.',
                    ),
                    const SizedBox(height: 16),
                    if (!coordinator.scheduler.supported)
                      const AuroraNotice(
                        'Phone scheduling is available on Android and iOS. Web and desktop can manage synced preferences.',
                      ),
                    if (coordinator.pendingWrites)
                      const AuroraNotice(
                        'Changes awaiting cloud confirmation. Local phone status is shown separately.',
                      ),
                    if (coordinator.cached)
                      const AuroraNotice(
                        'Showing cached reminder preferences. Reconnect to confirm synchronization.',
                      ),
                    if (coordinator.error != null)
                      AuroraNotice(coordinator.error!, error: true),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Notification settings'),
                          onPressed: coordinator.scheduler.supported
                              ? () => _action(
                                  context,
                                  coordinator.scheduler.openSettings,
                                )
                              : null,
                        ),
                        if (!Theme.of(context).platform
                                .toString()
                                .contains('iOS') &&
                            coordinator.scheduler.supported)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.alarm),
                            label: const Text('Precise timing'),
                            onPressed: () async {
                              final allow = await showDialog<bool>(
                                context: context,
                                builder: (dialog) => AlertDialog(
                                  scrollable: true,
                                  title: const Text('Allow precise reminders'),
                                  content: const Text(
                                    'Android has separate access for alarms at a precise time. You can allow SaveTrack in Alarms & reminders settings. Otherwise reminders use approximate timing.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, true),
                                      child: const Text('Open settings'),
                                    ),
                                  ],
                                ),
                              );
                              if (allow == true && context.mounted) {
                                await _action(
                                  context,
                                  coordinator.scheduler.requestPreciseTiming,
                                );
                              }
                            },
                          ),
                        TextButton.icon(
                          onPressed: () => _action(context, coordinator.resume),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh phone status'),
                        ),
                      ],
                    ),
                    if (coordinator.loading)
                      const Center(child: CircularProgressIndicator()),
                    if (!coordinator.loading &&
                        coordinator.configurations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Set a reminder from a goal or planner task. Reminders stay off until you choose to enable them.',
                        ),
                      ),
                    ...coordinator.configurations.values.map((config) {
                      final target = coordinator.targets[config.key];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const MintIcon(Icons.notifications_none),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      target?.title ?? 'Unavailable item',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: config.enabled,
                                    onChanged: target == null
                                        ? null
                                        : (enabled) =>
                                              _action(context, () async {
                                                if (enabled) {
                                                  await _ensurePermission(
                                                    context,
                                                    coordinator,
                                                    config.type,
                                                  );
                                                }
                                                await coordinator.save(
                                                  config.withEnabled(enabled),
                                                  target,
                                                );
                                              }),
                                  ),
                                ],
                              ),
                              Text(reminderSummary(context, config)),
                              Text(
                                coordinator.status(config.key).message,
                                style: TextStyle(
                                  color: context.atelierMuted,
                                  fontSize: 12,
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: target == null
                                        ? null
                                        : () => showReminderEditor(
                                            context,
                                            target,
                                          ),
                                    child: const Text('Manage Reminder'),
                                  ),
                                  TextButton(
                                    onPressed: () => _action(
                                      context,
                                      () => coordinator.remove(config.key),
                                    ),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    ...coordinator.statuses.entries
                        .where(
                          (entry) => !coordinator.configurations.containsKey(
                            entry.key,
                          ),
                        )
                        .map(
                          (entry) => Card(
                            child: ListTile(
                              title: Text(entry.value.message),
                              trailing: IconButton(
                                tooltip: 'Remove invalid reminder',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _action(
                                  context,
                                  () => coordinator.remove(entry.key),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(reminderError(e))));
      }
    }
  }
}
