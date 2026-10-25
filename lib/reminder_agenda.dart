part of 'reminder_widgets.dart';

class ReminderAgendaEntry {
  const ReminderAgendaEntry({
    required this.configuration,
    required this.target,
    required this.next,
    required this.section,
  });
  final ReminderConfiguration configuration;
  final ReminderTarget? target;
  final DateTime? next;
  final String section;
}

/// Resolves recurrence with the scheduler's calculator and timezone. Disabled,
/// unavailable and invalid schedules remain manageable after upcoming entries.
List<ReminderAgendaEntry> reminderAgenda(ReminderCoordinator coordinator) {
  final now = coordinator.clock();
  final zone = coordinator.zone;
  final localNow = zone == null ? now : tz.TZDateTime.from(now, zone);
  final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final result = <ReminderAgendaEntry>[];
  for (final config in coordinator.configurations.values) {
    final target = coordinator.targets[config.key];
    DateTime? next;
    if (target != null && zone != null) {
      try {
        next = coordinator.calculator.next(config, target, zone, now);
      } on ReminderFailure {
        // Status and Manage Reminder expose the invalid configuration.
      }
    }
    final day = next == null
        ? null
        : DateTime.utc(next.year, next.month, next.day);
    final distance = day?.difference(today).inDays;
    result.add(
      ReminderAgendaEntry(
        configuration: config,
        target: target,
        next: next,
        section: switch (distance) {
          null => 'Other reminders',
          0 => 'Today',
          1 => 'Tomorrow',
          final d when d > 1 && d <= DateTime.sunday - localNow.weekday =>
            'This week',
          _ => 'Later',
        },
      ),
    );
  }
  result.sort((a, b) {
    if (a.next == null && b.next != null) return 1;
    if (a.next != null && b.next == null) return -1;
    final order = a.next?.compareTo(b.next!) ?? 0;
    return order == 0
        ? a.configuration.key.compareTo(b.configuration.key)
        : order;
  });
  return result;
}

class ReminderAgendaCard extends StatelessWidget {
  const ReminderAgendaCard({
    super.key,
    required this.entry,
    required this.status,
    required this.onManage,
    required this.onToggle,
    required this.onRemove,
  });
  final ReminderAgendaEntry entry;
  final ReminderStatus status;
  final VoidCallback? onManage;
  final ValueChanged<bool>? onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final next = entry.next;
    final time = next == null
        ? null
        : TimeOfDay.fromDateTime(next).format(context);
    final card = Card(
      color: entry.section == 'Today'
          ? context.flowCategory(FlowAccent.mint)
          : context.atelierSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MintIcon(Icons.notifications_outlined, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entry.target?.title ?? 'Unavailable item',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                Semantics(
                  label:
                      'Enable reminder for ${entry.target?.title ?? 'unavailable item'}',
                  child: Switch.adaptive(
                    value: entry.configuration.enabled,
                    onChanged: onToggle,
                  ),
                ),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 10),
              Text(
                '$time · ${MaterialLocalizations.of(context).formatMediumDate(next)}',
                style: TextStyle(
                  color: context.atelierAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(reminderSummary(context, entry.configuration)),
            const SizedBox(height: 6),
            Text(status.message, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: onManage,
                  child: const Text('Manage Reminder'),
                ),
                TextButton(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    foregroundColor: context.atelierError,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return next == null
        ? Padding(padding: const EdgeInsets.only(bottom: 12), child: card)
        : FlowTimelineEntry(
            time: time!,
            caption: MaterialLocalizations.of(context)
                .formatShortMonthDay(next),
            featured: entry.section == 'Today',
            child: card,
          );
  }
}
