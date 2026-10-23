part of 'main.dart';

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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (onTap != null)
          TextButton(onPressed: onTap, child: Text(action ?? 'View all')),
      ],
    ),
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
        return CustomScrollView(
          key: const PageStorageKey('home-atelier'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverList.list(
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
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          MediaQuery.textScalerOf(context).scale(12) > 20
                          ? 2
                          : 4;
                      final actions = [
                        AuroraQuickAction(
                          icon: Icons.add_rounded,
                          label: 'Add savings',
                          onTap: records.isEmpty
                              ? null
                              : () => _chooseSavingsGoal(
                                  context,
                                  widget.uid,
                                  records,
                                ),
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
                  const SizedBox(height: 28),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: (preferences?.order ?? HomeSection.values)
                    .where(
                      (s) =>
                          !(preferences?.hidden.contains(s) ??
                              (s == HomeSection.agent)),
                    )
                    .length,
                itemBuilder: (context, index) {
                  final visible = (preferences?.order ?? HomeSection.values)
                      .where(
                        (s) =>
                            !(preferences?.hidden.contains(s) ??
                                (s == HomeSection.agent)),
                      )
                      .toList();
                  return _KeepHomeSection(
                    child: Padding(
                      key: ValueKey(visible[index]),
                      padding: const EdgeInsets.only(bottom: 28),
                      child: sections[visible[index]]!(),
                    ),
                  );
                },
              ),
            ),
          ],
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
  const _KeepHomeSection({required this.child});
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
    // A wrapping gallery respects text scaling without fixed carousel heights.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840 &&
            visible.length > 1 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AtelierGoalTile(
                  uid: uid,
                  doc: visible.first,
                  featured: true,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  children: visible
                      .skip(1)
                      .map(
                        (d) => AtelierGoalTile(uid: uid, doc: d, compact: true),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            AtelierGoalTile(uid: uid, doc: visible.first, featured: true),
            if (visible.length > 1) ...[
              const SizedBox(height: 12),
              AdaptiveCards(
                breakpoint: 600,
                children: visible
                    .skip(1)
                    .map(
                      (d) => AtelierGoalTile(uid: uid, doc: d, compact: true),
                    )
                    .toList(),
              ),
            ],
          ],
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
    this.onOpen,
  });
  final String uid;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool compact, featured;
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
    return Card(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact)
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
                            'IN FOCUS',
                            style: TextStyle(
                              color: mint,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (compact) ...[
                        const MintIcon(Icons.flag_outlined, size: 40),
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
                    style: SaveTrackDesign.amount.copyWith(
                      fontSize: featured ? 32 : 24,
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
                          color: context.atelierAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
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
  String search = '';
  GoalFilter filter = GoalFilter.all;
  GoalSort sort = GoalSort.newest;
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList.list(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search goals',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
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
                        onSelected: (_) => setState(() => filter = f),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GoalSort>(
                initialValue: sort,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sort goals'),
                items: GoalSort.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(switch (s) {
                          GoalSort.newest => 'Newest first',
                          GoalSort.deadline => 'Nearest deadline',
                          GoalSort.highestProgress => 'Highest progress',
                          GoalSort.lowestProgress => 'Lowest progress',
                          GoalSort.alphabetical => 'Alphabetical',
                        }),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => sort = v);
                },
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
                const TonalPanel(
                  child: Text('No goals match your search and filters.'),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  mode == GoalPresentation.grid &&
                      constraints.crossAxisExtent >= 600 &&
                      MediaQuery.textScalerOf(context).scale(14) < 22
                  ? 2
                  : 1;
              return SliverList.builder(
                itemCount: (docs.length / columns).ceil(),
                itemBuilder: (context, row) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: 16),
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
  });
  final String uid;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final Widget header;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? taskStream;
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
        _dateKey(DateTime(d.year, d.month, d.day - d.weekday + 1)) !=
            _dateKey(start)) {
      _subscribe();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snapshot) {
      final records =
          snapshot.data?.docs ??
          <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final selected = records
          .where((d) => d.data()['dateKey'] == _dateKey(widget.selected))
          .toList();
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            sliver: SliverList.list(
              children: [
                widget.header,
                const ScreenIntro(
                  eyebrow: 'Weekly planner',
                  title: 'Find your rhythm.',
                  detail: 'A little perspective for the days ahead.',
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
                Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Builder(
                        builder: (context) {
                          final day = DateTime(
                                start.year,
                                start.month,
                                start.day + i,
                              ),
                              key = _dateKey(
                                DateTime(
                                  start.year,
                                  start.month,
                                  start.day + i,
                                ),
                              );
                          final count = records
                              .where((d) => d.data()['dateKey'] == key)
                              .length;
                          return ChoiceChip(
                            label: Text(
                              '${DateFormat('EEE d').format(day)}\n$count ${count == 1 ? 'task' : 'tasks'}',
                            ),
                            selected: key == _dateKey(widget.selected),
                            onSelected: (_) => widget.onSelect(day),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (snapshot.hasData)
                  DailyCompletion(
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
                  const AuroraNotice(
                    'This week could not be loaded. Reopen Planner after reconnecting.',
                    error: true,
                  )
                else if (!snapshot.hasData)
                  const LoadingPanel()
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
              itemCount: selected.length,
              itemBuilder: (context, i) =>
                  TaskTile(uid: widget.uid, doc: selected[i]),
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
      children: items.map((item) {
        final time = TimeOfDay.fromDateTime(item.at).format(context);
        final task = item.target.type == ReminderTargetType.task;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (presentation == ReminderPresentation.timeline &&
                  MediaQuery.textScalerOf(context).scale(14) <= 21) ...[
                SizedBox(
                  width: 76,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.atelierAccent,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: 90,
                  margin: const EdgeInsets.only(right: 14),
                  color: context.atelierBorder,
                ),
              ],
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: MintIcon(
                      task
                          ? Icons.check_circle_outline
                          : Icons.savings_outlined,
                      size: 36,
                    ),
                    title: Text(
                      item.target.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${DateFormat.yMMMd().format(item.at)} · $time\n${reminderSummary(context, item.configuration)}',
                    ),
                    onTap: () => onOpen(item),
                  ),
                ),
              ),
            ],
          ),
        );
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
            breakpoint: 540,
            children: [
              AuroraMetricCard(
                icon: Icons.south_west,
                value: money(totals.contributions),
                label: 'Contributions',
              ),
              AuroraMetricCard(
                icon: Icons.north_east,
                value: money(totals.withdrawals),
                label: 'Withdrawals',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Net savings change: ${money(totals.net)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
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
              height: 110,
              child: Row(
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
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: (point.$2 / maximum * 100).clamp(2, 100),
                              decoration: BoxDecoration(
                                color: point.$2 > 0
                                    ? context.atelierAccent
                                    : context.atelierBorder,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
        ],
      ],
    );
  }
}
