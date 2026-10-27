part of 'main.dart';

/// Presentation ordering reuses the existing strict time parser. Free-text
/// schedules stay visible after timed entries; no missing time is invented.
List<QueryDocumentSnapshot<Map<String, dynamic>>> flowOrderedTasks(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
  String dateKey,
) {
  final day = SmartTaskRecommendationService.parseDateKey(dateKey);
  if (day == null) return records;
  DateTime? start(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      SmartTaskRecommendationService.parseSchedule(
        d.data()['time']?.toString() ?? '',
        day,
      ).start;
  return records.toList()..sort((a, b) {
    final x = start(a), y = start(b);
    if (x == null && y != null) return 1;
    if (x != null && y == null) return -1;
    final order = x == null ? 0 : x.compareTo(y!);
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
}

bool flowHasSchedule(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  String dateKey,
) {
  final day = SmartTaskRecommendationService.parseDateKey(dateKey);
  return day != null &&
      SmartTaskRecommendationService.parseSchedule(
            doc.data()['time']?.toString() ?? '',
            day,
          ).start !=
          null;
}

class FlowTaskGroupEntry extends StatelessWidget {
  const FlowTaskGroupEntry({
    super.key,
    required this.uid,
    required this.doc,
    required this.dateKey,
    this.groupHeading = false,
    this.featured = false,
  });
  final String uid, dateKey;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool groupHeading, featured;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (groupHeading)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Text(
            'Flexible & unscheduled',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      TaskTile(
        uid: uid,
        doc: doc,
        timeline: flowHasSchedule(doc, dateKey),
        featured: featured,
      ),
    ],
  );
}

String? flowFeaturedTask(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
  String dateKey, {
  DateTime? now,
}) {
  final day = SmartTaskRecommendationService.parseDateKey(dateKey);
  if (day == null) return null;
  final clock = now ?? DateTime.now();
  for (final doc in records) {
    if (doc.data()['completed'] == true) continue;
    final schedule = SmartTaskRecommendationService.parseSchedule(
      doc.data()['time']?.toString() ?? '',
      day,
    );
    if (schedule.start != null &&
        (schedule.end ?? schedule.start!).isAfter(clock)) {
      return doc.id;
    }
  }
  return null;
}

/// One scrolling canvas: the mint header meets a rounded white sheet. Sections
/// stay lazy and retain the user's existing order and visibility preferences.
class FlowHomeLayout extends StatefulWidget {
  const FlowHomeLayout({
    super.key,
    required this.header,
    required this.quickActions,
    required this.sectionCount,
    required this.sectionBuilder,
  });
  final Widget header, quickActions;
  final int sectionCount;
  final IndexedWidgetBuilder sectionBuilder;

  @override
  State<FlowHomeLayout> createState() => _FlowHomeLayoutState();
}

class _FlowHomeLayoutState extends State<FlowHomeLayout> {
  final _heroKey = GlobalKey();
  bool _surfaceCheckScheduled = false;

  void _scheduleSurfaceCheck() {
    if (_surfaceCheckScheduled) return;
    _surfaceCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _surfaceCheckScheduled = false;
      if (!mounted) return;
      final heroContext = _heroKey.currentContext;
      final hero = heroContext?.findRenderObject();
      if (heroContext == null || hero is! RenderBox || !hero.hasSize) return;
      // Report the actual sheet boundary, including nested-scroll overlap and
      // changes to the hero's height from text size, data, or screen width.
      final contentTop = hero.localToGlobal(Offset(0, hero.size.height)).dy;
      AuroraHeaderSurfaceNotification(contentTop: contentTop).dispatch(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSurfaceCheck();
    final inset = SaveTrackDesign.pageInset(MediaQuery.sizeOf(context).width);
    return NotificationListener<Notification>(
      onNotification: (notification) {
        if ((notification is ScrollNotification && notification.depth == 0) ||
            (notification is ScrollMetricsNotification &&
                notification.depth == 0) ||
            notification is SizeChangedLayoutNotification) {
          _scheduleSurfaceCheck();
        }
        return false;
      },
      child: CustomScrollView(
        key: const PageStorageKey('home-atelier'),
        slivers: [
          SliverToBoxAdapter(
            child: ColoredBox(
              color: context.flowHero,
              child: Column(
                children: [
                  SizeChangedLayoutNotifier(
                    child: Padding(
                      key: _heroKey,
                      padding: EdgeInsets.fromLTRB(inset, 8, inset, 28),
                      child: widget.header,
                    ),
                  ),
                  FlowContentSheet(
                    padding: EdgeInsets.fromLTRB(inset, 12, inset, 24),
                    child: widget.quickActions,
                  ),
                ],
              ),
            ),
          ),
          DecoratedSliver(
            decoration: BoxDecoration(color: context.atelierSurface),
            sliver: SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, 32),
              sliver: SliverList.builder(
                itemCount: widget.sectionCount,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: widget.sectionBuilder(context, i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AtelierSectionHeader extends StatelessWidget {
  const AtelierSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
    this.onTap,
  });
  final String title, subtitle;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => FlowSectionHeader(
    title: title,
    subtitle: subtitle,
    trailing: onTap == null
        ? null
        : TextButton(onPressed: onTap, child: Text(action ?? 'View all')),
  );
}

/// The same personal-goal snapshot supplies the overview, count and gallery.
class HomeAtelier extends StatefulWidget {
  const HomeAtelier({super.key, required this.uid});
  final String uid;
  @override
  State<HomeAtelier> createState() => _HomeAtelierState();
}

class _HomeAtelierState extends State<HomeAtelier> {
  late final goals = _goals(widget.uid)
      .orderBy('createdAt', descending: true)
      .snapshots(includeMetadataChanges: true);
  @override
  Widget build(BuildContext context) {
    final preferences = AtelierScope.maybeOf(context);
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning.'
        : now.hour < 18
        ? 'Good afternoon.'
        : 'Good evening.';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: goals,
      builder: (context, snapshot) {
        final records =
            snapshot.data?.docs
                .where((d) => d.data()['archived'] != true)
                .toList() ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final currency = CurrencyScope.maybeOf(context);
        final balances = records
            .map(
              (d) => (_number(d.data()['savedAmount']), goalCurrency(d.data())),
            )
            .toList();
        final targets = records
            .map(
              (d) =>
                  (_number(d.data()['targetAmount']), goalCurrency(d.data())),
            )
            .toList();
        final summary = currencySummary(currency, balances, targets);
        Widget gallery() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AtelierSectionHeader(
              title: 'Goal Gallery',
              subtitle: 'Make room for what matters.',
              action: 'All goals',
              onTap: () => _openTab(context, 1),
            ),
            if (snapshot.hasError)
              const AuroraNotice(
                'Your goals could not be loaded. Check your connection and reopen Home.',
                error: true,
              )
            else if (!snapshot.hasData)
              const LoadingPanel()
            else
              GoalGallery(
                uid: widget.uid,
                records: records,
                presentation: preferences?.goals ?? GoalPresentation.gallery,
                featuredId: preferences?.featuredGoal,
              ),
            const SizedBox(height: 12),
            const SharedGoalsPanel(compact: true),
          ],
        );
        final sections = <HomeSection, Widget Function()>{
          HomeSection.goals: gallery,
          HomeSection.pulse: () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AtelierSectionHeader(
                title: 'Savings Pulse',
                subtitle: 'Your recent savings, in focus.',
                action: 'View Reports',
                onTap: () => _openTab(context, 3),
              ),
              if (snapshot.hasData)
                SavingsPulse(
                  key: ValueKey('pulse-${widget.uid}'),
                  uid: widget.uid,
                  goals: snapshot.data!.docs,
                  presentation: preferences?.pulse ?? PulsePresentation.chart,
                )
              else if (snapshot.hasError)
                const AuroraNotice(
                  'Savings activity is unavailable until your goals load.',
                  error: true,
                )
              else
                const LoadingPanel(),
            ],
          ),
          HomeSection.reminders: () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AtelierSectionHeader(
                title: 'Up Next',
                subtitle: "What's coming up.",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SmartRemindersScreen(),
                  ),
                ),
              ),
              UpcomingTimeline(
                presentation:
                    preferences?.reminders ?? ReminderPresentation.timeline,
              ),
            ],
          ),
          HomeSection.planner: () => Column(
            children: [
              AtelierSectionHeader(
                title: 'Daily Planner',
                subtitle: 'A little focus for today.',
                action: 'Open Planner',
                onTap: () => _openTab(context, 2),
              ),
              TasksList(
                uid: widget.uid,
                dateKey: _dateKey(now),
                compact: true,
                maxPreview: 3,
              ),
            ],
          ),
          HomeSection.agent: () => Card(
            child: Column(
              children: [
                ListTile(
                  leading: const MintIcon(Icons.hub_outlined),
                  title: const Text('Agent Studio Pro'),
                  subtitle: const Text(
                    'Turn an idea into a plan you can review.',
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AgentStudioScreen(
                        onOpen: _openAgentDestination,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const MintIcon(Icons.auto_awesome_outlined),
                  title: const Text('AI Coach Lite'),
                  subtitle: const Text(
                    'Understand your progress. Ask anything.',
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AiCoachScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        };
        final visible = (preferences?.order ?? HomeSection.values)
            .where(
              (s) =>
                  !(preferences?.hidden.contains(s) ??
                      (s == HomeSection.agent)),
            )
            .toList();
        return FlowHomeLayout(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AuroraGreeting(
                      date: DateFormat('EEEE, MMMM d').format(now),
                      greeting: greeting,
                    ),
                  ),
                  if (preferences != null)
                    IconButton(
                      tooltip: 'Customize Home',
                      icon: const Icon(Icons.tune_rounded),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CustomizeHomeScreen(preferences: preferences),
                        ),
                      ),
                    ),
                ],
              ),
              if (snapshot.hasError)
                const AuroraNotice(
                  'Your savings are unavailable. Reopen Home after reconnecting.',
                  error: true,
                )
              else if (!snapshot.hasData)
                const LoadingPanel(featured: true)
              else
                SavingsOverview(
                  embedded: true,
                  total: summary.$1,
                  target: summary.$2,
                  count: records.length,
                  totalLabel:
                      currency?.totalDisplay(balances) ??
                      (summary.$3 ? null : 'Conversion unavailable'),
                  targetLabel:
                      currency?.totalDisplay(targets) ??
                      (summary.$3 ? null : 'See individual goals'),
                  showProgress: summary.$3,
                ),
              if (snapshot.hasData)
                AuroraSyncStatus(
                  cached: snapshot.data!.metadata.isFromCache,
                  pending: snapshot.data!.metadata.hasPendingWrites,
                ),
            ],
          ),
          quickActions: LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(13) > 18
                  ? 2
                  : 4;
              final actions = [
                AuroraQuickAction(
                  icon: Icons.add_rounded,
                  label: 'Add savings',
                  disabledReason: 'Create a goal before adding savings.',
                  onTap: records.isEmpty
                      ? null
                      : () => _chooseSavingsGoal(context, widget.uid, records),
                ),
                AuroraQuickAction(
                  icon: Icons.flag_outlined,
                  label: 'New goal',
                  onTap: () => showGoalTypeChoice(context),
                ),
                AuroraQuickAction(
                  icon: Icons.checklist_rounded,
                  label: 'Add task',
                  onTap: () => showTaskForm(context),
                ),
                AuroraQuickAction(
                  icon: Icons.notifications_outlined,
                  label: 'Reminders',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SmartRemindersScreen(),
                    ),
                  ),
                ),
              ];
              return Wrap(
                children: [
                  for (final action in actions)
                    SizedBox(
                      width: constraints.maxWidth / columns,
                      child: action,
                    ),
                ],
              );
            },
          ),
          sectionCount: visible.length,
          sectionBuilder: (context, index) => _KeepHomeSection(
            key: ValueKey(visible[index]),
            child: sections[visible[index]]!(),
          ),
        );
      },
    );
  }
}

Future<void> _chooseSavingsGoal(
  BuildContext context,
  String uid,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
) async {
  final chosen =
      await showModalBottomSheet<QueryDocumentSnapshot<Map<String, dynamic>>>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Add savings to a goal',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: const MintIcon(Icons.flag_outlined),
                      title: Text('${records[i].data()['title']}'),
                      subtitle: Text(goalCurrency(records[i].data())),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, records[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  if (chosen != null &&
      context.mounted &&
      FirebaseAuth.instance.currentUser?.uid == uid) {
    await showDepositForm(context, uid, chosen);
  }
}

class _KeepHomeSection extends StatefulWidget {
  const _KeepHomeSection({super.key, required this.child});
  final Widget child;
  @override
  State<_KeepHomeSection> createState() => _KeepHomeSectionState();
}

class _KeepHomeSectionState extends State<_KeepHomeSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class TransactionDateGroup extends StatelessWidget {
  const TransactionDateGroup({
    super.key,
    required this.at,
    required this.previous,
    required this.first,
    required this.child,
  });
  final Object? at, previous;
  final bool first;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final date = at is Timestamp ? (at as Timestamp).toDate() : null;
    final last = previous is Timestamp
        ? (previous as Timestamp).toDate()
        : null;
    final show =
        first ||
        (date == null
            ? last != null
            : last == null || _dateKey(date) != _dateKey(last));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (show)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              date == null
                  ? 'Date unavailable'
                  : DateFormat.yMMMMd().format(date),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        child,
      ],
    );
  }
}

class TransactionFilters extends StatefulWidget {
  const TransactionFilters({
    super.key,
    required this.records,
    required this.builder,
  });
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> records;
  final Widget Function(
    BuildContext,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>,
  )
  builder;
  @override
  State<TransactionFilters> createState() => _TransactionFiltersState();
}

class _TransactionFiltersState extends State<TransactionFilters> {
  String selected = 'All';
  @override
  Widget build(BuildContext context) {
    final records = widget.records
        .where(
          (d) =>
              selected == 'All' ||
              (d.data()['type'] == 'withdrawal') == (selected == 'Withdrawn'),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: ['All', 'Added', 'Withdrawn']
                .map(
                  (label) => ChoiceChip(
                    label: Text(label),
                    selected: selected == label,
                    onSelected: (_) => setState(() => selected = label),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No transactions match this filter.'),
                  ),
                )
              : widget.builder(context, records),
        ),
      ],
    );
  }
}

class GoalGallery extends StatelessWidget {
  const GoalGallery({
    super.key,
    required this.uid,
    required this.records,
    this.presentation = GoalPresentation.gallery,
    this.featuredId,
  });
  final String uid;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> records;
  final GoalPresentation presentation;
  final String? featuredId;
  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return EmptyPanel(
        icon: Icons.flag_outlined,
        title: 'Every goal begins somewhere.',
        detail: 'Give your next milestone a name and a target.',
        action: 'Create Goal',
        onTap: () => showGoalForm(context),
      );
    }
    final sorted = records.toList();
    final featured = sorted.indexWhere((d) => d.id == featuredId);
    if (featured > 0) sorted.insert(0, sorted.removeAt(featured));
    final visible = sorted.take(6).toList();
    if (presentation == GoalPresentation.list) {
      return Column(
        children: visible
            .map((d) => AtelierGoalTile(uid: uid, doc: d, compact: true))
            .toList(),
      );
    }
    if (presentation == GoalPresentation.grid) {
      return AdaptiveCards(
        breakpoint: 560,
        children: visible
            .map((d) => AtelierGoalTile(uid: uid, doc: d))
            .toList(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideText = MediaQuery.textScalerOf(context).scale(14) > 21;
        final cardWidth = wideText
            ? constraints.maxWidth
            : (constraints.maxWidth * .62).clamp(200.0, 224.0).toDouble();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                SizedBox(
                  width: cardWidth,
                  child: AtelierGoalTile(
                    uid: uid,
                    doc: visible[i],
                    featured: visible[i].id == featuredId,
                    preview: true,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class AtelierGoalTile extends StatelessWidget {
  const AtelierGoalTile({
    super.key,
    required this.uid,
    required this.doc,
    this.compact = false,
    this.featured = false,
    this.preview = false,
    this.onOpen,
  });
  final String uid;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool compact, featured, preview;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final data = doc.data(), code = goalCurrency(data);
    final saved = _number(data['savedAmount']),
        target = _number(data['targetAmount']);
    if (data['savedAmount'] is! num ||
        data['targetAmount'] is! num ||
        !saved.isFinite ||
        !target.isFinite ||
        saved < 0 ||
        target < 0) {
      return const AuroraNotice(
        'This goal has an unavailable balance or target. Open your goals to review it.',
        error: true,
      );
    }
    final progress = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final title = data['title']?.toString() ?? 'Savings goal';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = data['deadline'] is Timestamp
        ? (data['deadline'] as Timestamp).toDate()
        : null;
    final coverTarget = GoalCoverTarget.personal(uid, doc.id);
    final cover = GoalCoverRecord.fromMap(data, coverTarget);
    final preferences = AtelierScope.maybeOf(context);
    final tone = saved >= target && target > 0
        ? FlowAccent.mint
        : date != null && date.isBefore(today)
        ? FlowAccent.coral
        : featured
        ? FlowAccent.lavender
        : date != null && date.difference(today).inDays <= 14
        ? FlowAccent.peach
        : FlowAccent.mint;
    return Card(
      color: context.flowCategory(tone),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            onOpen ??
            () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    PersonalGoalDetailsScreen(uid: uid, goalId: doc.id),
              ),
            ),
        child: FlowCategoryDecoration(
          accent: tone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact && cover.path != null)
                Stack(
                  children: [
                    GoalCoverImage(
                      target: coverTarget,
                      name: title,
                      path: cover.path,
                      radius: 0,
                      decodeWidth: featured ? 960 : 640,
                    ),
                    if (featured)
                      const Positioned(
                        left: 16,
                        top: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: SaveTrackDesign.obsidian,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Text(
                              'Featured',
                              style: TextStyle(
                                color: mint,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (compact || cover.path == null) ...[
                          MintIcon(
                            saved >= target && target > 0
                                ? Icons.check_rounded
                                : Icons.flag_outlined,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (preferences != null)
                          IconButton(
                            tooltip: preferences.featuredGoal == doc.id
                                ? 'Unpin featured goal'
                                : 'Feature this goal',
                            onPressed: () {
                              preferences.featuredGoal =
                                  preferences.featuredGoal == doc.id
                                  ? null
                                  : doc.id;
                              unawaited(preferences.save());
                            },
                            icon: Icon(
                              preferences.featuredGoal == doc.id
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AmountText(
                      displayMoney(context, saved, code),
                      compactCurrency: true,
                      style: SaveTrackDesign.amount.copyWith(
                        fontSize: preview
                            ? 25
                            : featured
                            ? 32
                            : 24,
                        color: context.atelierInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of ${displayMoney(context, target, code)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    MintProgress(value: progress),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          target > 0 && saved >= target
                              ? 'Target reached'
                              : '${(progress * 100).round()}% saved',
                          style: TextStyle(
                            color: context.isDark ? context.atelierInk : teal,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (date != null)
                          Text(
                            '${date.isBefore(today) && saved < target ? 'Past deadline · ' : 'Due '}${DateFormat.yMMMd().format(date)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum GoalSort {
  newest,
  deadline,
  highestProgress,
  lowestProgress,
  alphabetical,
}

enum GoalFilter { all, active, completed, overdue }

class GoalBrowser extends StatefulWidget {
  const GoalBrowser({super.key, required this.uid, required this.records});
  final String uid;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> records;
  @override
  State<GoalBrowser> createState() => _GoalBrowserState();
}

class _GoalBrowserState extends State<GoalBrowser> {
  final _search = TextEditingController();
  String search = '';
  GoalFilter filter = GoalFilter.all;
  GoalSort sort = GoalSort.newest;
  String sortLabel(GoalSort value) => switch (value) {
    GoalSort.newest => 'Newest first',
    GoalSort.deadline => 'Nearest deadline',
    GoalSort.highestProgress => 'Highest progress',
    GoalSort.lowestProgress => 'Lowest progress',
    GoalSort.alphabetical => 'Alphabetical',
  };

  void reset() => setState(() {
    _search.clear();
    search = '';
    filter = GoalFilter.all;
  });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  double progress(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final target = _number(d.data()['targetAmount']);
    return target <= 0 ? 0 : _number(d.data()['savedAmount']) / target;
  }

  DateTime? deadline(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      d.data()['deadline'] is Timestamp
      ? (d.data()['deadline'] as Timestamp).toDate()
      : null;
  @override
  Widget build(BuildContext context) {
    final preferences = AtelierScope.maybeOf(context);
    final inset = SaveTrackDesign.pageInset(MediaQuery.sizeOf(context).width);
    final mode = preferences?.goals ?? GoalPresentation.gallery;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final docs = widget.records
        .where(
          (d) =>
              (d.data()['title']?.toString() ?? '').toLowerCase().contains(
                search.toLowerCase(),
              ) &&
              switch (filter) {
                GoalFilter.all => true,
                GoalFilter.active => progress(d) < 1,
                GoalFilter.completed => progress(d) >= 1,
                GoalFilter.overdue =>
                  progress(d) < 1 &&
                      deadline(d) != null &&
                      deadline(d)!.isBefore(today),
              },
        )
        .toList();
    switch (sort) {
      case GoalSort.newest:
        break;
      case GoalSort.deadline:
        docs.sort(
          (a, b) => (deadline(a) ?? DateTime(9999)).compareTo(
            deadline(b) ?? DateTime(9999),
          ),
        );
      case GoalSort.highestProgress:
        docs.sort((a, b) => progress(b).compareTo(progress(a)));
      case GoalSort.lowestProgress:
        docs.sort((a, b) => progress(a).compareTo(progress(b)));
      case GoalSort.alphabetical:
        docs.sort(
          (a, b) => '${a.data()['title']}'.toLowerCase().compareTo(
            '${b.data()['title']}'.toLowerCase(),
          ),
        );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(inset, 8, inset, 0),
          sliver: SliverList.list(
            children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  labelText: 'Search goals',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () => setState(() {
                            _search.clear();
                            search = '';
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: GoalFilter.values
                      .map(
                        (f) => ChoiceChip(
                          label: Text(switch (f) {
                            GoalFilter.all => 'All',
                            GoalFilter.active => 'Active',
                            GoalFilter.completed => 'Completed',
                            GoalFilter.overdue => 'Overdue',
                          }),
                          selected: f == filter,
                          showCheckmark: false,
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          onSelected: (_) => setState(() => filter = f),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${docs.length} ${docs.length == 1 ? 'goal' : 'goals'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Flexible(
                    flex: 3,
                    child: PopupMenuButton<GoalSort>(
                      tooltip: 'Sort goals',
                      initialValue: sort,
                      onSelected: (value) => setState(() => sort = value),
                      itemBuilder: (_) => [
                        for (final value in GoalSort.values)
                          CheckedPopupMenuItem(
                            value: value,
                            checked: sort == value,
                            child: Text(sortLabel(value)),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sort_rounded,
                              size: 18,
                              color: context.atelierAccent,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                sortLabel(sort),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.atelierAccent,
                                ),
                              ),
                            ),
                            const Icon(Icons.expand_more_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (preferences != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Wrap(
                    spacing: 8,
                    children: GoalPresentation.values
                        .map(
                          (v) => ChoiceChip(
                            label: Text(v.name),
                            selected: mode == v,
                            onSelected: (_) {
                              preferences.goals = v;
                              unawaited(preferences.save());
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (docs.isEmpty)
                TonalPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.records.isEmpty
                            ? 'Make room for your first goal.'
                            : 'No goals match your search and filters.',
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: widget.records.isEmpty
                            ? () => showGoalTypeChoice(context)
                            : reset,
                        icon: Icon(
                          widget.records.isEmpty
                              ? Icons.add_rounded
                              : Icons.restart_alt_rounded,
                        ),
                        label: Text(
                          widget.records.isEmpty
                              ? 'New goal'
                              : 'Reset search and filters',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(inset, 12, inset, 100),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  mode == GoalPresentation.grid &&
                      constraints.crossAxisExtent >= 350 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 16
                  ? 2
                  : 1;
              return SliverList.builder(
                itemCount: (docs.length / columns).ceil(),
                itemBuilder: (context, row) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: 12),
                      Expanded(
                        child: row * columns + column < docs.length
                            ? AtelierGoalTile(
                                uid: widget.uid,
                                doc: docs[row * columns + column],
                                compact: mode == GoalPresentation.list,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class UpcomingReminder {
  const UpcomingReminder(this.configuration, this.target, this.at);
  final ReminderConfiguration configuration;
  final ReminderTarget target;
  final DateTime at;
}

class WeeklyPlanner extends StatefulWidget {
  const WeeklyPlanner({
    super.key,
    required this.uid,
    required this.selected,
    required this.onSelect,
    required this.header,
    this.taskStream,
    this.today,
  });
  final String uid;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final Widget header;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? taskStream;
  final DateTime? today;
  @override
  State<WeeklyPlanner> createState() => _WeeklyPlannerState();
}

class _WeeklyPlannerState extends State<WeeklyPlanner> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  late DateTime start;
  void _subscribe() {
    final d = widget.selected;
    start = DateTime(d.year, d.month, d.day - d.weekday + 1);
    stream =
        widget.taskStream ??
        _tasks(widget.uid)
            .where('dateKey', isGreaterThanOrEqualTo: _dateKey(start))
            .where(
              'dateKey',
              isLessThanOrEqualTo: _dateKey(
                DateTime(start.year, start.month, start.day + 6),
              ),
            )
            .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(WeeklyPlanner old) {
    super.didUpdateWidget(old);
    final d = widget.selected;
    if (old.uid != widget.uid ||
        old.taskStream != widget.taskStream ||
        _dateKey(DateTime(d.year, d.month, d.day - d.weekday + 1)) !=
            _dateKey(start)) {
      _subscribe();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    key: ValueKey('${widget.uid}/week-${_dateKey(start)}'),
    stream: stream,
    builder: (context, snapshot) {
      final records =
          snapshot.data?.docs ??
          <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final selected = flowOrderedTasks(
        records
            .where((d) => d.data()['dateKey'] == _dateKey(widget.selected))
            .toList(),
        _dateKey(widget.selected),
      );
      final featuredId = flowFeaturedTask(
        selected,
        _dateKey(widget.selected),
        now: widget.today,
      );
      final firstFlexible = selected.indexWhere(
        (d) => !flowHasSchedule(d, _dateKey(widget.selected)),
      );
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            sliver: SliverList.list(
              children: [
                widget.header,
                FlowDateHeading(
                  date: widget.selected,
                  onToday: () =>
                      widget.onSelect(widget.today ?? DateTime.now()),
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Previous week',
                      onPressed: () => widget.onSelect(
                        DateTime(
                          widget.selected.year,
                          widget.selected.month,
                          widget.selected.day - 7,
                        ),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${DateFormat.MMMd().format(start)} – ${DateFormat.yMMMd().format(DateTime(start.year, start.month, start.day + 6))}',
                    ),
                    IconButton(
                      tooltip: 'Next week',
                      onPressed: () => widget.onSelect(
                        DateTime(
                          widget.selected.year,
                          widget.selected.month,
                          widget.selected.day + 7,
                        ),
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FlowWeekSelector(
                  selected: widget.selected,
                  today: widget.today,
                  onSelected: widget.onSelect,
                  counts: {
                    for (var i = 0; i < 7; i++)
                      i + 1: records
                          .where(
                            (d) =>
                                d.data()['dateKey'] ==
                                _dateKey(
                                  DateTime(
                                    start.year,
                                    start.month,
                                    start.day + i,
                                  ),
                                ),
                          )
                          .length,
                  },
                ),
                const SizedBox(height: 20),
                if (snapshot.hasData && !snapshot.hasError)
                  FlowPlannerSummary(
                    label: 'Weekly progress',
                    done: records
                        .where((d) => d.data()['completed'] == true)
                        .length,
                    total: records.length,
                  ),
                const SizedBox(height: 24),
                Text(
                  DateFormat.yMMMMEEEEd().format(widget.selected),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (snapshot.hasError)
                  ErrorPanel(
                    message: 'This week could not be loaded. Check your connection and try again.',
                    onRetry: () => setState(_subscribe),
                  )
                else if (!snapshot.hasData)
                  const FlowTimelineSkeleton()
                else if (selected.isEmpty)
                  EmptyPanel(
                    icon: Icons.event_available_outlined,
                    title: 'Your day is ready for a fresh start.',
                    detail: 'Plan something that matters to you.',
                    action: 'Add Task',
                    onTap: () => showTaskForm(
                      context,
                      dateKey: _dateKey(widget.selected),
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList.builder(
              itemCount: snapshot.hasError ? 0 : selected.length,
              itemBuilder: (context, i) => FlowTaskGroupEntry(
                uid: widget.uid,
                doc: selected[i],
                dateKey: _dateKey(widget.selected),
                groupHeading: i == firstFlexible,
                featured: selected[i].id == featuredId,
              ),
            ),
          ),
        ],
      );
    },
  );
}

List<UpcomingReminder> upcomingReminders(
  ReminderCoordinator coordinator,
  DateTime now,
) {
  if (coordinator.zone == null) return [];
  final result = <UpcomingReminder>[];
  for (final config in coordinator.configurations.values) {
    final target = coordinator.targets[config.key];
    if (target == null) continue;
    try {
      final next = coordinator.calculator.next(
        config,
        target,
        coordinator.zone!,
        now,
      );
      if (next != null) result.add(UpcomingReminder(config, target, next));
    } on ReminderFailure {
      /* The management screen exposes invalid schedules. */
    }
  }
  result.sort((a, b) {
    final time = a.at.compareTo(b.at);
    return time == 0 ? a.target.key.compareTo(b.target.key) : time;
  });
  return result;
}

class UpcomingTimeline extends StatelessWidget {
  const UpcomingTimeline({
    super.key,
    this.presentation = ReminderPresentation.timeline,
  });
  final ReminderPresentation presentation;
  @override
  Widget build(BuildContext context) {
    final coordinator = ReminderScope.maybeOf(context);
    if (coordinator == null) {
      return const LoadingPanel();
    }
    if (coordinator.error != null) {
      return AuroraNotice(coordinator.error!, error: true);
    }
    if (coordinator.loading) return const LoadingPanel();
    if (coordinator.zone == null) {
      return const AuroraNotice(
        'Reminder times are unavailable. Open View all to review your reminders and phone settings.',
      );
    }
    final items = upcomingReminders(
      coordinator,
      coordinator.clock(),
    ).take(presentation == ReminderPresentation.nextUp ? 1 : 4).toList();
    final blocked = coordinator.statuses.values.any(
      (s) =>
          s.delivery == ReminderDelivery.blocked ||
          s.delivery == ReminderDelivery.failed ||
          s.delivery == ReminderDelivery.unsupported ||
          s.delivery == ReminderDelivery.limit,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AuroraNotice(
              coordinator.scheduler.supported
                  ? 'Some reminders cannot notify on this phone. Open View all to review notification access and scheduling status.'
                  : 'Phone notifications are unavailable on this platform. Your saved schedule is shown below.',
            ),
          ),
        ReminderTimeline(
          items: items,
          presentation: presentation,
          onOpen: (item) => showReminderEditor(context, item.target),
        ),
      ],
    );
  }
}

class ReminderTimeline extends StatelessWidget {
  const ReminderTimeline({
    super.key,
    required this.items,
    required this.onOpen,
    this.presentation = ReminderPresentation.timeline,
  });
  final List<UpcomingReminder> items;
  final ValueChanged<UpcomingReminder> onOpen;
  final ReminderPresentation presentation;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const TonalPanel(
        child: DetailLine(
          icon: Icons.event_available_outlined,
          label: 'No upcoming reminders. Manage reminders from your goals or Planner.',
        ),
      );
    }
    return Column(
      children: items.indexed.map((entry) {
        final item = entry.$2;
        final featured = entry.$1 == 0;
        final time = TimeOfDay.fromDateTime(item.at).format(context);
        final timeline = presentation == ReminderPresentation.timeline;
        final (icon, category) = switch (item.target.type) {
          ReminderTargetType.task => (
            Icons.check_circle_outline,
            'Task reminder',
          ),
          ReminderTargetType.sharedGoal => (
            Icons.groups_outlined,
            'Shared goal reminder',
          ),
          ReminderTargetType.personalGoal => (
            Icons.savings_outlined,
            'Savings reminder',
          ),
        };
        final card = Material(
          color: featured
              ? context.flowCategory(FlowAccent.mint)
              : context.atelierTonal,
          borderRadius: BorderRadius.circular(SaveTrackDesign.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpen(item),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.target.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: context.atelierAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reminderSummary(context, item.configuration),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!timeline) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${DateFormat.yMMMd().format(item.at)} · $time',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(icon, size: 16, color: context.atelierAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          category,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        return timeline
            ? FlowTimelineEntry(
                time: time,
                caption: DateFormat.MMMd().format(item.at),
                featured: featured,
                child: card,
              )
            : Padding(padding: const EdgeInsets.only(bottom: 12), child: card);
      }).toList(),
    );
  }
}

enum PulsePeriod { week, month, calendarMonth }

class PulseEntry {
  const PulseEntry({
    required this.at,
    required this.amount,
    required this.currency,
    this.withdrawal = false,
  });
  final DateTime at;
  final ExactDecimal amount;
  final String currency;
  final bool withdrawal;
}

class PulseTotals {
  PulseTotals(this.currency, this.start, this.end, List<PulseEntry> entries) {
    for (final entry in entries) {
      if (entry.currency != currency ||
          entry.at.isBefore(start) ||
          !entry.at.isBefore(end)) {
        continue;
      }
      count++;
      if (entry.withdrawal) {
        withdrawals = withdrawals + entry.amount;
      } else {
        contributions = contributions + entry.amount;
        final key = _dateKey(entry.at);
        days[key] = (days[key] ?? ExactDecimal.fromNum(0)) + entry.amount;
      }
    }
  }
  final String currency;
  final DateTime start, end;
  ExactDecimal contributions = ExactDecimal.fromNum(0),
      withdrawals = ExactDecimal.fromNum(0);
  ExactDecimal get net => contributions - withdrawals;
  int count = 0;
  final Map<String, ExactDecimal> days = {};
}

/// One set of bounded ledger reads per selected period/revision, no new listeners.
class SavingsPulse extends StatefulWidget {
  const SavingsPulse({
    super.key,
    required this.uid,
    required this.goals,
    this.presentation = PulsePresentation.chart,
    this.load,
    this.clock,
  });
  final String uid;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> goals;
  final PulsePresentation presentation;
  final Future<(List<PulseEntry>, bool)> Function(DateTime, DateTime)? load;
  final DateTime Function()? clock;
  @override
  State<SavingsPulse> createState() => _SavingsPulseState();
}

class _SavingsPulseState extends State<SavingsPulse> {
  PulsePeriod period = PulsePeriod.week;
  String? selectedCurrency;
  late Future<(List<PulseEntry>, bool)> activity;
  late DateTime start, end;
  String revision(SavingsPulse value) => value.goals
      .map((d) => '${d.id}:${d.data()['savedAmount']}:${d.data()['updatedAt']}')
      .join('|');
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(SavingsPulse old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid || revision(old) != revision(widget)) _reload();
  }

  void _reload() {
    final now = widget.clock?.call() ?? DateTime.now();
    end = DateTime(now.year, now.month, now.day + 1);
    start = period == PulsePeriod.calendarMonth
        ? DateTime(now.year, now.month)
        : DateTime(
            now.year,
            now.month,
            now.day - (period == PulsePeriod.week ? 6 : 29),
          );
    activity = widget.load?.call(start, end) ?? _read(start, end);
    // A fast failure can arrive before FutureBuilder attaches on the next frame.
    // Keep the error available to its retry UI without an unhandled async error.
    activity.ignore();
  }

  Future<(List<PulseEntry>, bool)> _read(DateTime from, DateTime to) async {
    final entries = <PulseEntry>[];
    var cached = false;
    for (final goal in widget.goals) {
      if (FirebaseAuth.instance.currentUser?.uid != widget.uid) {
        throw StateError('Account changed');
      }
      final result = await goal.reference
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('date', isLessThan: Timestamp.fromDate(to))
          .get();
      if (FirebaseAuth.instance.currentUser?.uid != widget.uid) {
        throw StateError('Account changed');
      }
      cached =
          cached ||
          result.metadata.isFromCache ||
          result.metadata.hasPendingWrites;
      for (final doc in result.docs) {
        final data = doc.data(), amount = data['amount'], date = data['date'];
        if (amount is! num ||
            !amount.isFinite ||
            amount < 0 ||
            date is! Timestamp) {
          throw const FormatException('Invalid recorded savings activity');
        }
        final type = data['type'];
        if (type != null && type != 'deposit' && type != 'withdrawal') {
          throw const FormatException('Unsupported recorded savings activity');
        }
        entries.add(
          PulseEntry(
            at: date.toDate(),
            amount: ExactDecimal.fromNum(amount),
            currency:
                data['currencyCode']?.toString() ?? goalCurrency(goal.data()),
            withdrawal: type == 'withdrawal',
          ),
        );
      }
    }
    return (entries, cached);
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in PulsePeriod.values)
                ChoiceChip(
                  label: Text(switch (p) {
                    PulsePeriod.week => '7 days',
                    PulsePeriod.month => '30 days',
                    PulsePeriod.calendarMonth => 'This month',
                  }),
                  selected: period == p,
                  onSelected: (_) => setState(() {
                    period = p;
                    _reload();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<(List<PulseEntry>, bool)>(
            future: activity,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingPanel();
              }
              if (snapshot.hasError) {
                return Column(
                  children: [
                    const AuroraNotice(
                      'Savings activity could not be loaded. No partial totals are shown.',
                      error: true,
                    ),
                    TextButton.icon(
                      onPressed: () => setState(_reload),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                );
              }
              final entries = snapshot.data!.$1;
              if (entries.isEmpty) {
                return TonalPanel(
                  child: DetailLine(
                    icon: Icons.insights_outlined,
                    label: snapshot.data!.$2
                        ? 'No activity is cached for this period. Reconnect to load your recorded savings activity.'
                        : 'No recorded savings activity in this period. Your next contribution starts the story.',
                  ),
                );
              }
              final codes = entries.map((e) => e.currency).toSet().toList()
                ..sort();
              final code = codes.contains(selectedCurrency)
                  ? selectedCurrency!
                  : codes.first;
              final totals = PulseTotals(code, start, end, entries);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (codes.length > 1)
                    Wrap(
                      spacing: 6,
                      children: codes
                          .map(
                            (c) => ChoiceChip(
                              label: Text(c),
                              selected: c == code,
                              onSelected: (_) =>
                                  setState(() => selectedCurrency = c),
                            ),
                          )
                          .toList(),
                    ),
                  Text(
                    '$code · ${DateFormat.MMMd().format(start)} – ${DateFormat.MMMd().format(end.subtract(const Duration(days: 1)))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  PulseContent(
                    totals: totals,
                    presentation: widget.presentation,
                  ),
                  if (snapshot.data!.$2)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Includes cached or pending activity. Reconnect to confirm.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    '${totals.count} recorded ${totals.count == 1 ? 'transaction' : 'transactions'} · Personal goals · Original currency',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class PulseContent extends StatelessWidget {
  const PulseContent({
    super.key,
    required this.totals,
    this.presentation = PulsePresentation.chart,
  });
  final PulseTotals totals;
  final PulsePresentation presentation;
  @override
  Widget build(BuildContext context) {
    String money(ExactDecimal value) => formatCurrency(value, totals.currency);
    final points = <(DateTime, double)>[];
    for (
      var date = totals.start;
      date.isBefore(totals.end);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      points.add((date, totals.days[_dateKey(date)]?.toDouble() ?? 0));
    }
    final maximum = points.fold<double>(0, (m, p) => p.$2 > m ? p.$2 : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (presentation == PulsePresentation.compact) ...[
          Text(
            'Net savings change',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          AmountText(
            money(totals.net),
            key: const ValueKey('pulse-net-savings'),
            style: SaveTrackDesign.amount.copyWith(
              fontSize: 30,
              color: context.atelierInk,
            ),
          ),
          Text(
            'Added ${money(totals.contributions)} · Withdrawn ${money(totals.withdrawals)}',
          ),
        ] else ...[
          AdaptiveCards(
            breakpoint: 300,
            children: [
              FlowFinancialMetric(
                icon: Icons.south_west,
                value: money(totals.contributions),
                label: 'Contributions',
              ),
              FlowFinancialMetric(
                accent: FlowAccent.peach,
                icon: Icons.north_east,
                value: money(totals.withdrawals),
                label: 'Withdrawals',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Net savings change',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          AmountText(
            money(totals.net),
            key: const ValueKey('pulse-net-savings'),
            compactCurrency: true,
            style: SaveTrackDesign.amount.copyWith(
              fontSize: 30,
              color: context.atelierInk,
            ),
          ),
        ],
        if (presentation == PulsePresentation.chart) ...[
          const SizedBox(height: 20),
          Text(
            'Daily contributions · ${totals.currency}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (maximum == 0)
            const Text(
              'No contributions recorded. Withdrawals are included in the totals above.',
            )
          else
            SizedBox(
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 4; i++)
                          Divider(height: 1, color: context.atelierBorder),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: points.map((point) {
                      final label =
                          '${DateFormat.yMMMd().format(point.$1)}: ${formatCurrency(totals.days[_dateKey(point.$1)] ?? ExactDecimal.zero, totals.currency)} contributed';
                      return Expanded(
                        child: Tooltip(
                          message: label,
                          triggerMode: TooltipTriggerMode.tap,
                          child: Semantics(
                            label: label,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: (point.$2 / maximum * 150).clamp(
                                    2,
                                    150,
                                  ),
                                  decoration: BoxDecoration(
                                    color: point.$2 > 0
                                        ? context.atelierAccent
                                        : context.atelierBorder,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat.MMMd().format(totals.start),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                DateFormat.MMMd().format(points.last.$1),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            // Keep disclosure state separate from the ancestor scroll offset.
            key: PageStorageKey(
              'pulse-details-${totals.currency}-'
              '${_dateKey(totals.start)}-${_dateKey(totals.end)}',
            ),
            tilePadding: EdgeInsets.zero,
            title: const Text('Daily contribution details'),
            subtitle: Text('${totals.currency} · Recorded activity'),
            children: [
              for (final point in points)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat.yMMMd().format(point.$1)),
                  subtitle: Text(
                    money(totals.days[_dateKey(point.$1)] ?? ExactDecimal.zero),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
