import 'package:flutter/material.dart';

import '../branding/savetrack_logo.dart';
import 'widget_models.dart';
import 'widget_visuals.dart';
import 'widget_native_preview.dart';

/// Approximate native compositions. Preview controls never perform transactions.
class WidgetPreviewCard extends StatelessWidget {
  const WidgetPreviewCard({
    super.key,
    required this.type,
    this.theme,
    this.privacy,
    this.goal,
    this.planner,
    this.presets = const [],
    this.showTaskTitles = false,
    this.size = WidgetPreviewSize.medium,
  });
  final HomeWidgetType type;
  final WidgetTheme? theme;
  final WidgetPrivacy? privacy;
  final WidgetGoalFacts? goal;
  final WidgetPlannerFacts? planner;
  final List<String> presets;
  final bool showTaskTitles;
  final WidgetPreviewSize size;

  @override
  Widget build(BuildContext context) {
    final palette = WidgetAtelierPalette.resolve(
      theme,
      type,
      MediaQuery.platformBrightnessOf(context),
    );
    final selectedPrivacy = privacy ?? WidgetPrivacy.progress;
    // Use the production snapshot formatter and privacy filter, never preview money math.
    final data = HomeWidgetSnapshot.build(
      config: HomeWidgetConfig(
        id: 1,
        uid: 'preview',
        type: type,
        goal: goal?.ref,
        currency: goal?.currency,
        theme: theme ?? WidgetTheme.emerald,
        privacy: selectedPrivacy,
        showTaskTitles: showTaskTitles,
        presets: presets,
      ),
      now: DateTime.now(),
      goal: goal,
      planner: planner,
    ).data;
    final savings = (data['goal'] as Map?)?.cast<String, dynamic>();
    final tasks = (data['planner'] as Map?)?.cast<String, dynamic>();
    final readyTasks = tasks?['state'] == 'ready' ? tasks : null;
    final compact = size == WidgetPreviewSize.compact;
    final expanded = size == WidgetPreviewSize.expanded;
    final hidden = selectedPrivacy == WidgetPrivacy.hidden;
    Text text(
      String value, {
      double sp = 13,
      bool strong = false,
      bool quiet = false,
      int? lines,
    }) => Text(
      value,
      maxLines: lines,
      overflow: lines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(
        color: quiet ? palette.secondary : palette.text,
        fontSize: sp,
        height: 1.25,
        fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    Widget progress(Map<String, dynamic>? facts) => facts == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: ((facts['progress'] as num?) ?? 0) / 1000,
                minHeight: compact ? 4 : 7,
                color: palette.accent,
                backgroundColor: palette.track,
              ),
            ),
          );
    Widget action(String label, {bool primary = true}) => Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? palette.action : palette.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: primary ? palette.onAction : palette.text,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    Widget panel(List<Widget> children, {bool secondary = false}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: secondary ? palette.secondarySurface : palette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
    final percent = savings == null ? '—' : '${savings['percent']}%';
    final goalTitle = savings?['title'] as String? ?? 'Choose a savings goal';
    final total = readyTasks?['total'] as int?;
    final remaining = readyTasks?['remaining'] as int?;
    final completion = readyTasks == null
        ? '—'
        : '${readyTasks['done']} / $total';
    final left = remaining == null
        ? 'Open Planner to refresh'
        : total == 0
        ? 'No tasks scheduled'
        : remaining == 0
        ? 'All tasks done'
        : '$remaining ${remaining == 1 ? 'task' : 'tasks'} left';
    final taskRows = (readyTasks?['tasks'] as List? ?? const []).cast<Map>();
    Widget taskRow(Map task) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: panel([
        Row(
          children: [
            Icon(
              Icons.radio_button_unchecked_rounded,
              size: 18,
              color: palette.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text(task['title'] as String? ?? '', lines: 1),
                  text(
                    [task['priority'], task['time']]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    sp: 11,
                    quiet: true,
                    lines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ]),
    );

    Widget content;
    if (hidden) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text('Open SaveTrack', sp: 22, strong: true),
          const SizedBox(height: 8),
          text('Private details are hidden.', quiet: true),
        ],
      );
    } else if (compact) {
      final label = switch (type) {
        HomeWidgetType.goal => goalTitle,
        HomeWidgetType.planner => 'Today',
        HomeWidgetType.quickSave => 'Quick Save',
        HomeWidgetType.today => 'Savings',
      };
      final metric = switch (type) {
        HomeWidgetType.goal || HomeWidgetType.today => percent,
        HomeWidgetType.planner => remaining == null ? '—' : '$remaining left',
        HomeWidgetType.quickSave => '+ Add Savings',
      };
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text(label, sp: 11, quiet: true, lines: 1),
                    const SizedBox(height: 4),
                    text(metric, sp: 18, strong: true),
                  ],
                ),
              ),
              if (type == HomeWidgetType.today)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text('Tasks left', sp: 11, quiet: true),
                      const SizedBox(height: 4),
                      text(remaining?.toString() ?? '—', sp: 18, strong: true),
                    ],
                  ),
                ),
            ],
          ),
          if (type == HomeWidgetType.goal || type == HomeWidgetType.planner)
            progress(type == HomeWidgetType.goal ? savings : readyTasks),
        ],
      );
    } else {
      content = switch (type) {
        HomeWidgetType.goal => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text(goalTitle, sp: 15, strong: true, lines: 2),
            const SizedBox(height: 8),
            text(savings?['saved'] as String? ?? percent, sp: 28, strong: true),
            if (savings?['target'] != null)
              text('Saved of ${savings!['target']}', sp: 12, quiet: true),
            progress(savings),
            text(
              '$percent complete${savings?['status'] == null ? '' : ' · ${savings!['status']}'}',
              sp: 12,
              quiet: true,
            ),
            if (expanded && savings?['remaining'] != null) ...[
              const SizedBox(height: 12),
              panel([
                text('REMAINING', sp: 11, quiet: true),
                const SizedBox(height: 4),
                text(savings!['remaining'] as String, sp: 16, strong: true),
                const SizedBox(height: 12),
                text('DEADLINE', sp: 11, quiet: true),
                const SizedBox(height: 4),
                text(savings['deadline'] as String? ?? 'No deadline'),
              ], secondary: true),
            ],
            const SizedBox(height: 16),
            action(savings?['canSave'] == true ? '+ Add Savings' : 'Open Goal'),
          ],
        ),
        HomeWidgetType.planner => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text(
              MaterialLocalizations.of(context)
                  .formatMediumDate(DateTime.now()),
              sp: 12,
              quiet: true,
            ),
            const SizedBox(height: 8),
            text(
              total == 0 ? 'All clear today' : '$completion complete',
              sp: 24,
              strong: true,
            ),
            text(left, sp: 12, quiet: true),
            progress(readyTasks),
            for (final task in taskRows.take(expanded ? 3 : 1)) taskRow(task),
            const SizedBox(height: 16),
            action('Open Planner'),
          ],
        ),
        HomeWidgetType.quickSave => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text('Quick Save', sp: 24, strong: true),
            const SizedBox(height: 6),
            text(
              '${savings?['currency'] == null ? '' : '${savings!['currency']} · '}$goalTitle',
              quiet: true,
              lines: 2,
            ),
            if ((savings?['presets'] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amount
                      in (savings!['presets'] as List).cast<String>())
                    SizedBox(
                      width: 88,
                      child: action(
                        '+${amount.replaceFirst('${savings['currency']} ', '')}',
                        primary: false,
                      ),
                    ),
                ],
              ),
            ],
            if (expanded) ...[
              const SizedBox(height: 16),
              text(
                'Enter amount, then Review. Confirm on the widget.',
                sp: 12,
                quiet: true,
              ),
              progress(savings),
            ],
            const SizedBox(height: 16),
            action(
              savings?['canSave'] == true ? '+ Add Savings' : 'Choose a goal',
            ),
          ],
        ),
        HomeWidgetType.today => LayoutBuilder(
          builder: (context, constraints) {
            final goalPanel = panel([
              text('Savings', sp: 11, quiet: true),
              const SizedBox(height: 6),
              text(percent, sp: 26, strong: true),
              text(goalTitle, sp: 12, quiet: true, lines: 1),
              progress(savings),
              if (expanded && savings?['saved'] != null)
                text(savings!['saved'] as String, sp: 13, quiet: true),
              if (expanded && savings?['remaining'] != null)
                text('${savings!['remaining']} remaining', sp: 12, quiet: true),
            ]);
            final taskPanel = panel([
              text('Today’s focus', sp: 11, quiet: true),
              const SizedBox(height: 6),
              text(completion, sp: 26, strong: true),
              text(left, sp: 12, quiet: true),
              progress(readyTasks),
              if (taskRows.isNotEmpty)
                text('Next · ${taskRows.first['title']}', sp: 12, lines: 2),
            ], secondary: true);
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            return Column(
              children: [
                if (expanded || constraints.maxWidth / scale < 240)
                  Column(
                    children: [goalPanel, const SizedBox(height: 8), taskPanel],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: goalPanel),
                      const SizedBox(width: 8),
                      Expanded(child: taskPanel),
                    ],
                  ),
                if (expanded) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: action('Dashboard')),
                      const SizedBox(width: 8),
                      Expanded(child: action('Planner', primary: false)),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      };
    }
    return NativeWidgetPreview(
      type: type.name,
      config: HomeWidgetConfig(
        id: 1,
        uid: 'preview',
        type: type,
        goal: goal?.ref,
        currency: goal?.currency,
        theme: theme ?? WidgetTheme.emerald,
        privacy: selectedPrivacy,
        showTaskTitles: showTaskTitles,
        presets: presets,
      ).toMap(),
      snapshot: data,
      width: compact ? 180 : 300,
      height: type == HomeWidgetType.quickSave
          ? (expanded ? 420 : 220)
          : (compact
                ? 100
                : expanded
                ? 360
                : 220),
      child: Semantics(
        label: '${widgetTypeName(type)} preview, ${size.name} size',
        child: Container(
          constraints: BoxConstraints(
            minHeight: compact
                ? 88
                : expanded
                ? 320
                : 190,
          ),
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: palette.background,
            gradient: palette.gradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact) ...[
                Row(
                  children: [
                    SaveTrackLogo(size: 20, onDark: palette.dark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: text(
                        'SAVETRACK · ${switch (type) {
                          HomeWidgetType.goal => 'SAVINGS',
                          HomeWidgetType.planner => 'TODAY’S FOCUS',
                          HomeWidgetType.quickSave => 'QUICK SAVE',
                          HomeWidgetType.today => 'TODAY',
                        }}',
                        sp: 11,
                        strong: true,
                        quiet: true,
                        lines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              content,
            ],
          ),
        ),
      ),
    );
  }
}
