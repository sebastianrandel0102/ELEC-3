import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';
import 'shared_savings.dart';

const sharedIcons = <String, IconData>{
  'group': Icons.groups_outlined,
  'travel': Icons.flight_takeoff,
  'home': Icons.home_outlined,
  'school': Icons.school_outlined,
  'gift': Icons.card_giftcard,
  'emergency': Icons.health_and_safety_outlined,
};

bool _canCorrect(Object error) =>
    error is FirebaseException &&
    [
      'invalid-argument',
      'failed-precondition',
      'permission-denied',
    ].contains(error.code);

/// Keeps an open contribution form from exposing stale data after revocation.
class SharedGoalGuard extends StatefulWidget {
  const SharedGoalGuard({
    super.key,
    required this.goalId,
    required this.builder,
  });
  final String goalId;
  final Widget Function(BuildContext, SharedSavingsGoal) builder;
  @override
  State<SharedGoalGuard> createState() => _SharedGoalGuardState();
}

class _SharedGoalGuardState extends State<SharedGoalGuard> {
  late final stream = SharedSavingsService().watchGoal(widget.goalId);
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: SharedNotice(sharedError(snapshot.error!), error: true),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data();
          if (data == null ||
              !(data['memberIds'] as List).contains(
                FirebaseAuth.instance.currentUser?.uid,
              )) {
            return const Center(
              child: SharedNotice('Your access to this shared goal has ended.'),
            );
          }
          return widget.builder(
            context,
            SharedSavingsGoal(widget.goalId, data),
          );
        },
      );
}

void openSharedGoal(BuildContext context, String id) => Navigator.of(context)
    .push(
      MaterialPageRoute<void>(
        builder: (_) => SharedGoalDetailsScreen(goalId: id),
      ),
    );
void createSharedGoal(BuildContext context, {Map<String, dynamic>? personal}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedGoalFormScreen(personal: personal),
      ),
    );
void redeemSharedInvitation(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const SharedInvitationScreen()));

class SharedNotice extends StatelessWidget {
  const SharedNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      message,
      style: TextStyle(color: error ? SaveTrackDesign.error : muted),
    ),
  );
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2);
    return Semantics(
      label: name,
      child: CircleAvatar(
        backgroundColor: mint,
        foregroundColor: teal,
        child: Text(
          words.isEmpty
              ? '?'
              : words.map((w) => w.characters.first).join().toUpperCase(),
        ),
      ),
    );
  }
}

class SharedPage extends StatefulWidget {
  const SharedPage({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  State<SharedPage> createState() => _SharedPageState();
}

class _SharedPageState extends State<SharedPage> {
  late final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _session = FirebaseAuth.instance.authStateChanges();
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _session,
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, session) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: session.data?.uid != _uid || _uid == null
          ? const Center(child: Text('Sign in to access Save Together.'))
          : PageSurface(child: SafeArea(top: false, child: widget.child)),
    ),
  );
}

class SharedGoalsPanel extends StatefulWidget {
  const SharedGoalsPanel({
    super.key,
    this.compact = false,
    this.report = false,
  });
  final bool compact, report;
  @override
  State<SharedGoalsPanel> createState() => _SharedGoalsPanelState();
}

class _SharedGoalsPanelState extends State<SharedGoalsPanel> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final controller = SharedSavingsScope.of(context);
    if (controller.error != null) {
      return SharedNotice(controller.error!, error: true);
    }
    if (controller.loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final all = controller.goals;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final goals =
        all
            .where(
              (g) => filter == 'All' || g.statusAt(DateTime.now()) == filter,
            )
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.compact || widget.report)
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 12),
            child: Text(
              'Save Together',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
          ),
        if (widget.report)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${all.length} goals joined · ${all.where((g) => g.ownerId == uid).length} owned',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Combined group balances: ${sharedMoney(all.fold<double>(0, (total, g) => total + g.balance))}',
                  ),
                  Text(
                    'Your recorded deposits: ${sharedMoney(all.fold<double>(0, (total, g) => total + ((g.data['personalDeposits'] as Map?)?[uid] as num? ?? 0).toDouble()))}',
                  ),
                  const SharedNotice(
                    'Group balances are shared tracking totals. They are separate from personal savings. Deposits remain attributed to members after a group decrease.',
                  ),
                ],
              ),
            ),
          ),
        if (!widget.compact && !widget.report) ...[
          const ScreenIntro(
            eyebrow: 'Save Together',
            title: 'A shared goal. Real progress.',
            detail: 'Record savings with people you trust.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => createSharedGoal(context),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Create shared goal'),
              ),
              OutlinedButton.icon(
                onPressed: () => redeemSharedInvitation(context),
                icon: const Icon(Icons.key_outlined),
                label: const Text('Enter invitation'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['All', 'Active', 'Completed', 'Overdue', 'Archived']
                .map(
                  (v) => ChoiceChip(
                    label: Text(v),
                    selected: filter == v,
                    onSelected: (_) => setState(() => filter = v),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (goals.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.groups_outlined, size: 40, color: teal),
                  const SizedBox(height: 12),
                  Text(
                    all.isEmpty
                        ? 'Start saving together.'
                        : 'No goals in this filter.',
                  ),
                  if (all.isEmpty) ...[
                    const SharedNotice(
                      'Create a shared goal and invite someone to join.',
                    ),
                    TextButton(
                      onPressed: () => createSharedGoal(context),
                      child: const Text('Create shared goal'),
                    ),
                    TextButton(
                      onPressed: () => redeemSharedInvitation(context),
                      child: const Text('Enter invitation'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ...goals
            .take(widget.compact ? 2 : goals.length)
            .map((g) => SharedGoalCard(goal: g, uid: uid)),
      ],
    );
    return widget.compact || widget.report
        ? body
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            child: body,
          );
  }
}

class SharedGoalCard extends StatelessWidget {
  const SharedGoalCard({super.key, required this.goal, required this.uid});
  final SharedSavingsGoal goal;
  final String uid;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => openSharedGoal(context, goal.id),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(sharedIcons[goal.iconKey], color: teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      goal.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const StatusPill('Shared'),
                  StatusPill(goal.statusAt(DateTime.now())),
                  Text(
                    '${goal.memberCount} members · ${goal.ownerId == uid ? 'Owner' : 'Contributor'}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                sharedMoney(goal.balance),
                style: SaveTrackDesign.amount.copyWith(
                  fontSize: 27,
                  color: teal,
                ),
              ),
              Text('Combined savings · ${sharedMoney(goal.target)} target'),
              const SizedBox(height: 12),
              MintProgress(value: goal.progress),
              const SizedBox(height: 12),
              Text(
                '${(goal.progress * 100).round()}% · Due ${sharedDateText(goal.deadline)}',
              ),
              if ((goal.data['memberNames'] as Map?)?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...(goal.data['memberNames'] as Map).values
                          .take(3)
                          .map((n) => MemberAvatar(n as String)),
                      if (goal.memberCount > 3)
                        Text('+${goal.memberCount - 3}'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SharedGoalFormScreen extends StatefulWidget {
  const SharedGoalFormScreen({super.key, this.personal, this.goal});
  final Map<String, dynamic>? personal;
  final SharedSavingsGoal? goal;
  @override
  State<SharedGoalFormScreen> createState() => _SharedGoalFormScreenState();
}

class _SharedGoalFormScreenState extends State<SharedGoalFormScreen> {
  final form = GlobalKey<FormState>();
  late final service = SharedSavingsService();
  late final requestId = service.newRequestId();
  late final name = TextEditingController(
    text: widget.goal?.name ?? widget.personal?['title'] as String?,
  );
  late final description = TextEditingController(
    text: widget.goal?.description ?? widget.personal?['note'] as String?,
  );
  late final target = TextEditingController(
    text:
        widget.goal?.target.toStringAsFixed(2) ??
        (widget.personal?['targetAmount'] as num?)?.toStringAsFixed(2),
  );
  final initial = TextEditingController(text: '0');
  late DateTime start = widget.goal?.startDate ?? DateTime.now();
  late DateTime deadline =
      widget.goal?.deadline ??
      (widget.personal?['deadline'] is Timestamp
          ? sharedDate(widget.personal!['deadline'])
          : DateTime.now().add(const Duration(days: 90)));
  late String icon = widget.goal?.iconKey ?? 'group';
  bool busy = false;
  String? error;
  Map<String, dynamic>? pending;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    target.dispose();
    initial.dispose();
    super.dispose();
  }

  Future<void> pick(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDate: isStart ? start : deadline,
    );
    if (d != null && mounted) {
      setState(() {
        if (isStart) {
          start = d;
        } else {
          deadline = d;
        }
      });
    }
  }

  Future<void> submit() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    if (sharedDateText(start).compareTo(sharedDateText(deadline)) > 0) {
      setState(() => error = 'Start date must be on or before the deadline.');
      return;
    }
    pending ??= {
      'name': name.text.trim(),
      'description': description.text.trim(),
      'targetAmount': target.text.trim(),
      'initialAmount': initial.text.trim(),
      'startDate': sharedDateText(start),
      'deadline': sharedDateText(deadline),
      'iconKey': icon,
      if (widget.goal != null) 'goalId': widget.goal!.id,
    };
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await service.call(
        widget.goal == null ? 'create' : 'edit',
        pending!,
        requestId: requestId,
      );
      if (!mounted) return;
      if (widget.goal != null) {
        Navigator.pop(context);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                SharedGoalDetailsScreen(goalId: result['goalId'] as String),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = sharedError(e);
          if (_canCorrect(e)) pending = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SharedPage(
    title: widget.goal == null ? 'Create shared goal' : 'Goal settings',
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.personal != null)
              SharedNotice(
                'This creates a new shared goal with copied details and a zero starting balance. Your personal balance of ${sharedMoney(widget.personal!['savedAmount'] as num? ?? 0)} and transaction history stay private and unchanged. No existing funds or transactions are copied.',
              ),
            const SharedNotice(
              'SaveTrack records self-reported savings. No money is transferred. Shared members can see contributions and notes.',
            ),
            AbsorbPointer(
              absorbing: busy || pending != null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: name,
                    enabled: !busy && pending == null,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Goal name'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter a goal name.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: target,
                    enabled: !busy && pending == null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Target amount (PHP)',
                    ),
                    validator: (v) => (parseSharedAmount(v) ?? 0) <= 0
                        ? 'Enter a positive amount with up to two decimals (maximum PHP 1 billion).'
                        : null,
                  ),
                  if (widget.goal == null && widget.personal == null) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: initial,
                      enabled: !busy && pending == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Initial recorded savings (PHP)',
                      ),
                      validator: (v) => parseSharedAmount(v) == null
                          ? 'Enter zero or a positive amount with up to two decimals.'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    enabled: !busy && pending == null,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                  ),
                  if (widget.goal == null)
                    OutlinedButton.icon(
                      onPressed: () => pick(true),
                      icon: const Icon(Icons.today),
                      label: Text('Start: ${sharedDateText(start)}'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => pick(false),
                    icon: const Icon(Icons.calendar_month),
                    label: Text('Deadline: ${sharedDateText(deadline)}'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: icon,
                    decoration: const InputDecoration(labelText: 'Goal icon'),
                    items: sharedIcons.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Row(
                              children: [
                                Icon(e.value),
                                const SizedBox(width: 12),
                                Text(e.key),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => icon = v!),
                  ),
                ],
              ),
            ),
            if (error != null) SharedNotice(error!, error: true),
            if (pending != null && error != null)
              const SharedNotice(
                'Retry uses the same submitted values to prevent duplicates. Reopen the form to enter different values.',
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : submit,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                busy
                    ? 'Saving…'
                    : pending != null && error != null
                    ? 'Retry same request'
                    : widget.goal == null
                    ? 'Create shared goal'
                    : 'Save changes',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SharedGoalDetailsScreen extends StatefulWidget {
  const SharedGoalDetailsScreen({super.key, required this.goalId});
  final String goalId;
  @override
  State<SharedGoalDetailsScreen> createState() =>
      _SharedGoalDetailsScreenState();
}

class _SharedGoalDetailsScreenState extends State<SharedGoalDetailsScreen> {
  late final service = SharedSavingsService();
  late final stream = service
      .goal(widget.goalId)
      .snapshots(includeMetadataChanges: true);
  @override
  Widget build(BuildContext context) => SharedPage(
    title: 'Save Together',
    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SharedNotice(sharedError(s.error!), error: true),
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (!s.data!.exists ||
            uid == null ||
            !(s.data!.data()!['memberIds'] as List).contains(uid)) {
          return const Center(
            child: SharedNotice(
              'This shared goal is no longer available to you.',
            ),
          );
        }
        final goal = SharedSavingsGoal(widget.goalId, s.data!.data()!);
        final owner = goal.ownerId == uid;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (s.data!.metadata.isFromCache)
              const SharedNotice(
                'Showing cached information. Reconnect to verify access and record changes.',
              ),
            MintHero(
              deep: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Icon(sharedIcons[goal.iconKey], color: mint),
                      const Text('Shared goal', style: TextStyle(color: mint)),
                      Text(
                        goal.statusAt(DateTime.now()),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    goal.name,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    sharedMoney(goal.balance),
                    style: SaveTrackDesign.amount.copyWith(
                      color: Colors.white,
                      fontSize: 34,
                    ),
                  ),
                  const Text(
                    'Combined recorded savings',
                    style: TextStyle(color: SaveTrackDesign.onHeroMuted),
                  ),
                  const SizedBox(height: 20),
                  MintProgress(value: goal.progress, onDark: true),
                  const SizedBox(height: 16),
                  Text(
                    '${(goal.progress * 100).round()}% · ${sharedMoney(goal.target)} target',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    '${sharedMoney(goal.remaining)} remaining · Due ${sharedDateText(goal.deadline)}',
                    style: const TextStyle(color: SaveTrackDesign.onHeroMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (goal.description.isNotEmpty) Text(goal.description),
            const SharedNotice(
              'Contributions are self-reported savings records. No money is transferred or held by SaveTrack.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!goal.archived)
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SharedContributionScreen(goal: goal),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add contribution'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SharedMembersScreen(goal: goal),
                    ),
                  ),
                  icon: const Icon(Icons.people_outline),
                  label: Text('Members (${goal.memberCount})'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SharedHistoryScreen(goalId: goal.id),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('All activity'),
                ),
                if (owner && !goal.archived) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SharedInvitesScreen(goal: goal),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Invite members'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SharedGoalFormScreen(goal: goal),
                      ),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Settings'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SharedContributionScreen(
                          goal: goal,
                          decrease: true,
                        ),
                      ),
                    ),
                    child: const Text('Decrease savings'),
                  ),
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => SharedActionDialog(
                        title: 'Archive shared goal?',
                        message: 'Members retain access to the history. New contributions and invitations will stop.',
                        action: 'archive',
                        payload: {'goalId': goal.id},
                      ),
                    ),
                    child: const Text('Archive goal'),
                  ),
                ],
                if (!owner)
                  TextButton(
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (_) => SharedActionDialog(
                          title: 'Leave shared goal?',
                          message: 'Your access ends. Your recorded contributions and the shared balance remain in the history.',
                          action: 'leave',
                          payload: {'goalId': goal.id},
                        ),
                      );
                      if (result == true && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Leave goal'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your contribution',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    OwnContribution(goalId: goal.id),
                    const SharedNotice(
                      'Your recorded deposits are separate from the current group balance. Group decreases do not reduce a specific member’s deposit total.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shared savings report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Total deposits: ${sharedMoney(goal.deposits)}'),
                    Text('Total decreases: ${sharedMoney(goal.decreases)}'),
                    Text('Current balance: ${sharedMoney(goal.balance)}'),
                    Text(
                      '${goal.daysRemaining(DateTime.now()) < 0 ? 'Days overdue' : 'Days remaining'}: ${goal.daysRemaining(DateTime.now()).abs()}',
                    ),
                    if (goal.remaining > 0)
                      Text(
                        'Suggested pace: ${sharedMoney(goal.daily(DateTime.now()))} daily · ${sharedMoney(goal.daily(DateTime.now()) * 7)} weekly',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent savings activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            RecentSharedActivity(goalId: goal.id),
          ],
        );
      },
    ),
  );
}

class OwnContribution extends StatefulWidget {
  const OwnContribution({super.key, required this.goalId});
  final String goalId;
  @override
  State<OwnContribution> createState() => _OwnContributionState();
}

class _OwnContributionState extends State<OwnContribution> {
  late final stream = SharedSavingsService()
      .goal(widget.goalId)
      .collection('members')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, s) => s.hasError
            ? SharedNotice(sharedError(s.error!), error: true)
            : !s.hasData
            ? const LinearProgressIndicator()
            : Text(
                sharedMoney((s.data!.data()?['totalDeposits'] as num?) ?? 0),
                style: SaveTrackDesign.amount.copyWith(
                  fontSize: 27,
                  color: teal,
                ),
              ),
      );
}

class SharedContributionScreen extends StatefulWidget {
  const SharedContributionScreen({
    super.key,
    required this.goal,
    this.decrease = false,
  });
  final SharedSavingsGoal goal;
  final bool decrease;
  @override
  State<SharedContributionScreen> createState() =>
      _SharedContributionScreenState();
}

class _SharedContributionScreenState extends State<SharedContributionScreen> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(), note = TextEditingController();
  late final service = SharedSavingsService();
  late final requestId = service.newRequestId();
  DateTime date = DateTime.now();
  bool busy = false;
  String? error;
  Map<String, dynamic>? pending;
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    pending ??= {
      'goalId': widget.goal.id,
      'amount': amount.text.trim(),
      'note': note.text.trim(),
      'date': sharedDateText(date),
    };
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await service.call(
        widget.decrease ? 'decrease' : 'contribute',
        pending!,
        requestId: requestId,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Savings record saved.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = sharedError(e);
          if (_canCorrect(e)) pending = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SharedPage(
    title: widget.decrease ? 'Decrease shared savings' : 'Add contribution',
    child: SharedGoalGuard(
      goalId: widget.goal.id,
      builder: (context, liveGoal) {
        if (liveGoal.archived) {
          return const Center(
            child: SharedNotice(
              'This goal is archived. New savings records are disabled.',
            ),
          );
        }
        if (sharedDateText(liveGoal.startDate)
                .compareTo(sharedDateText(DateTime.now())) >
            0) {
          return Center(
            child: SharedNotice(
              'This goal starts on ${sharedDateText(liveGoal.startDate)}.',
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(liveGoal.name, style: SaveTrackDesign.heading),
                Text('Current balance: ${sharedMoney(liveGoal.balance)}'),
                Text('Remaining: ${sharedMoney(liveGoal.remaining)}'),
                SharedNotice(
                  'Recorded by ${FirebaseAuth.instance.currentUser?.displayName ?? 'you'}. Members can see this amount and note. ${widget.decrease ? 'This decreases the group balance and preserves individual deposit totals.' : 'This records money you have personally set aside.'}',
                ),
                AbsorbPointer(
                  absorbing: busy || pending != null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: amount,
                        enabled: !busy && pending == null,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount (PHP)',
                        ),
                        validator: (v) => (parseSharedAmount(v) ?? 0) <= 0
                            ? 'Enter a positive amount with at most two decimals.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: note,
                        enabled: !busy && pending == null,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: widget.decrease
                              ? 'Reason (optional)'
                              : 'Note (optional)',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (sharedDateText(widget.goal.startDate)
                                  .compareTo(sharedDateText(DateTime.now())) >
                              0) {
                            setState(
                              () => error = 'This goal starts in the future. Record contributions after its start date.',
                            );
                            return;
                          }
                          final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(
                              widget.goal.startDate.year,
                              widget.goal.startDate.month,
                              widget.goal.startDate.day,
                            ),
                            lastDate: DateTime.now(),
                            initialDate: date,
                          );
                          if (d != null && mounted) setState(() => date = d);
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(sharedDateText(date)),
                      ),
                    ],
                  ),
                ),
                if (error != null) SharedNotice(error!, error: true),
                if (pending != null && error != null)
                  const SharedNotice(
                    'Retry confirms the same amount and note to prevent duplicate records. Reopen this form to change values.',
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Recording…'
                        : error != null && pending != null
                        ? 'Retry same request'
                        : widget.decrease
                        ? 'Record decrease'
                        : 'Add contribution',
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class SharedActionDialog extends StatefulWidget {
  const SharedActionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.action,
    required this.payload,
  });
  final String title, message, action;
  final Map<String, dynamic> payload;
  @override
  State<SharedActionDialog> createState() => _SharedActionDialogState();
}

class _SharedActionDialogState extends State<SharedActionDialog> {
  late final service = SharedSavingsService();
  late final requestId = service.newRequestId();
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.message),
        if (error != null) SharedNotice(error!, error: true),
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  await service.call(
                    widget.action,
                    widget.payload,
                    requestId: requestId,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (mounted) setState(() => error = sharedError(e));
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        child: Text(busy ? 'Saving…' : 'Confirm'),
      ),
    ],
  );
}

class SharedMembersScreen extends StatefulWidget {
  const SharedMembersScreen({super.key, required this.goal});
  final SharedSavingsGoal goal;
  @override
  State<SharedMembersScreen> createState() => _SharedMembersScreenState();
}

class _SharedMembersScreenState extends State<SharedMembersScreen> {
  late final stream = SharedSavingsService().members(widget.goal.id);
  late final goalUpdates = SharedSavingsService().watchGoal(widget.goal.id);
  @override
  Widget build(BuildContext context) => SharedPage(
    title: 'Goal members',
    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: goalUpdates,
      builder: (context, goalSnapshot) {
        if (goalSnapshot.hasError) {
          return SharedNotice(sharedError(goalSnapshot.error!), error: true);
        }
        if (!goalSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!goalSnapshot.data!.exists) {
          return const SharedNotice(
            'This shared goal no longer exists.',
            error: true,
          );
        }
        final current = SharedSavingsGoal(
          widget.goal.id,
          goalSnapshot.data!.data()!,
        );
        return StreamBuilder<List<SharedGoalMember>>(
          stream: stream,
          builder: (context, s) {
            if (s.hasError) {
              return Center(
                child: SharedNotice(sharedError(s.error!), error: true),
              );
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final members = [...s.data!]
              ..sort(
                (a, b) => a.role == b.role
                    ? a.name.compareTo(b.name)
                    : a.role == 'owner'
                    ? -1
                    : 1,
              );
            final totalDeposits = current.deposits;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SharedNotice(
                  'Showing active participants. Deposit shares use all recorded group deposits, including former members. Leaving or removal preserves history and the group balance.',
                ),
                ...members.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                MemberAvatar(m.name),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    m.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                StatusPill(
                                  m.role == 'owner' ? 'Owner' : 'Contributor',
                                ),
                                StatusPill(m.status),
                                Text('Joined ${sharedDateText(m.joinedAt)}'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${sharedMoney(m.deposits)} recorded deposits',
                            ),
                            Text(
                              '${(totalDeposits == 0 ? 0 : m.deposits / totalDeposits * 100).toStringAsFixed(1)}% of all recorded deposits',
                            ),
                            const SizedBox(height: 8),
                            MintProgress(
                              value: totalDeposits == 0
                                  ? 0
                                  : m.deposits / totalDeposits,
                            ),
                            if (current.ownerId ==
                                    FirebaseAuth.instance.currentUser?.uid &&
                                m.role != 'owner' &&
                                m.status == 'active')
                              TextButton(
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => SharedActionDialog(
                                    title: 'Remove ${m.name}?',
                                    message: 'This revokes access. Their contributions remain recorded and the group balance stays unchanged.',
                                    action: 'remove',
                                    payload: {
                                      'goalId': widget.goal.id,
                                      'memberId': m.id,
                                    },
                                  ),
                                ),
                                child: const Text('Remove member'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class SharedInvitesScreen extends StatefulWidget {
  const SharedInvitesScreen({super.key, required this.goal});
  final SharedSavingsGoal goal;
  @override
  State<SharedInvitesScreen> createState() => _SharedInvitesScreenState();
}

class _SharedInvitesScreenState extends State<SharedInvitesScreen> {
  late final service = SharedSavingsService();
  late final stream = service.invitations(widget.goal.id);
  String? requestId, token, error;
  bool busy = false;
  Future<void> issue() async {
    if (busy) return;
    requestId ??= service.newRequestId();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await service.call('invite', {
        'goalId': widget.goal.id,
      }, requestId: requestId!);
      if (mounted) {
        setState(() {
          token = result['token'] as String?;
          requestId = null;
          if (token == null) error = 'The invitation was created, but its code could not be recovered. Revoke it below and generate a new invitation.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = sharedError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SharedPage(
    title: 'Invite members',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.goal.name, style: SaveTrackDesign.heading),
        Text('${widget.goal.memberCount} participants'),
        const SharedNotice(
          'Create a single-use code, valid for seven days. Share it privately with a registered SaveTrack user. Anyone with this code can view the invitation and accept or decline it.',
        ),
        FilledButton.icon(
          onPressed: busy ? null : issue,
          icon: const Icon(Icons.key),
          label: Text(
            busy
                ? 'Creating…'
                : error != null && requestId != null
                ? 'Retry same request'
                : 'Generate invitation code',
          ),
        ),
        if (error != null) SharedNotice(error!, error: true),
        if (token != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Invitation code',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(token!),
                  const SharedNotice(
                    'Ask the recipient to sign in, open Savings → Shared → Enter invitation, then paste this code.',
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: token!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invitation code copied.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy invitation code'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'Recent invitations',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        StreamBuilder<List<SharedGoalInvitation>>(
          stream: stream,
          builder: (context, s) {
            if (s.hasError) {
              return SharedNotice(sharedError(s.error!), error: true);
            }
            if (!s.hasData) return const LinearProgressIndicator();
            if (s.data!.isEmpty) {
              return const SharedNotice('No invitations waiting.');
            }
            return Column(
              children: s.data!.map((i) {
                final status = i.statusAt(DateTime.now());
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Invitation · $status'),
                        Text('Expires ${sharedDateText(i.expiresAt)}'),
                        if (status == 'pending')
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => SharedActionDialog(
                                title: 'Revoke invitation?',
                                message:
                                    'This code will no longer grant access.',
                                action: 'revoke',
                                payload: {
                                  'goalId': widget.goal.id,
                                  'invitationId': i.id,
                                },
                              ),
                            ),
                            child: const Text('Revoke'),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ),
  );
}

class SharedInvitationScreen extends StatefulWidget {
  const SharedInvitationScreen({super.key});
  @override
  State<SharedInvitationScreen> createState() => _SharedInvitationScreenState();
}

class _SharedInvitationScreenState extends State<SharedInvitationScreen> {
  final code = TextEditingController();
  late final service = SharedSavingsService();
  Map<String, dynamic>? invitation;
  bool busy = false;
  String? error, requestId, decision;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> run(String action) async {
    if (busy) return;
    if (decision != null && decision != action) return;
    if (action != 'preview') {
      decision ??= action;
      requestId ??= service.newRequestId();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await service.call(action, {
        'token': code.text.trim(),
      }, requestId: requestId ?? service.newRequestId());
      if (!mounted) return;
      if (action == 'preview') {
        setState(() => invitation = result);
      } else if (action == 'accept') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                SharedGoalDetailsScreen(goalId: result['goalId'] as String),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = sharedError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SharedPage(
    title: 'Join Save Together',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.groups_outlined, size: 56, color: teal),
        const SizedBox(height: 20),
        if (invitation == null) ...[
          const SharedNotice(
            'Paste the code from the goal owner. Sign in to your own SaveTrack account first; keep the code until you join.',
          ),
          TextField(
            controller: code,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Invitation code'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : () => run('preview'),
            child: Text(busy ? 'Checking…' : 'Check invitation'),
          ),
        ] else ...[
          Text(
            'You’re invited to save together!',
            style: SaveTrackDesign.heading,
          ),
          const SizedBox(height: 16),
          Text(
            invitation!['name'] as String,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          Text('Invited by ${invitation!['ownerName']}'),
          Text('Target: ${sharedMoney(invitation!['targetAmount'] as num)}'),
          Text(
            'Expires: ${sharedDateText(DateTime.fromMillisecondsSinceEpoch(invitation!['expiresAt'] as int))}',
          ),
          const SharedNotice(
            'Joining makes your future contributions and shared notes visible to goal members.',
          ),
          FilledButton(
            onPressed: busy || decision == 'decline'
                ? null
                : () => run('accept'),
            child: Text(busy ? 'Saving…' : 'Join goal'),
          ),
          TextButton(
            onPressed: busy || decision == 'accept'
                ? null
                : () => run('decline'),
            child: const Text('Decline'),
          ),
        ],
        if (error != null) SharedNotice(error!, error: true),
      ],
    ),
  );
}

class SharedActivityTile extends StatelessWidget {
  const SharedActivityTile({super.key, required this.record});
  final SharedSavingsTransaction record;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MemberAvatar(record.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${record.name} ${record.withdrawal ? 'recorded a decrease' : 'contributed'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${record.withdrawal ? '−' : '+'}${sharedMoney(record.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: record.withdrawal ? SaveTrackDesign.error : teal,
                fontSize: 20,
              ),
            ),
            Text(sharedDateText(record.date)),
            if (record.note.isNotEmpty) Text(record.note),
          ],
        ),
      ),
    ),
  );
}

class RecentSharedActivity extends StatefulWidget {
  const RecentSharedActivity({super.key, required this.goalId});
  final String goalId;
  @override
  State<RecentSharedActivity> createState() => _RecentSharedActivityState();
}

class _RecentSharedActivityState extends State<RecentSharedActivity> {
  late final stream = SharedSavingsService()
      .activity(widget.goalId)
      .limit(5)
      .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, s) {
          if (s.hasError) {
            return SharedNotice(sharedError(s.error!), error: true);
          }
          if (!s.hasData) return const LinearProgressIndicator();
          if (s.data!.docs.isEmpty) {
            return const SharedNotice(
              'Your group hasn’t recorded any savings yet.',
            );
          }
          return Column(
            children: s.data!.docs
                .map(
                  (d) => SharedActivityTile(
                    record: SharedSavingsTransaction(d.id, d.data()),
                  ),
                )
                .toList(),
          );
        },
      );
}

class SharedHistoryScreen extends StatefulWidget {
  const SharedHistoryScreen({super.key, required this.goalId});
  final String goalId;
  @override
  State<SharedHistoryScreen> createState() => _SharedHistoryScreenState();
}

class _SharedHistoryScreenState extends State<SharedHistoryScreen> {
  late final service = SharedSavingsService();
  late final accessUpdates = service.watchGoal(widget.goalId);
  final records = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  bool busy = false, more = true, denied = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      if (refresh) {
        records.clear();
        more = true;
      }
    });
    try {
      var query = service.activity(widget.goalId).limit(30);
      if (records.isNotEmpty) query = query.startAfterDocument(records.last);
      final page = await query.get(const GetOptions(source: Source.server));
      if (mounted) {
        setState(() {
          records.addAll(page.docs);
          more = page.docs.length == 30;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = sharedError(e);
          if (e is FirebaseException && e.code == 'permission-denied') {
            records.clear();
            denied = true;
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SharedPage(
    title: 'Shared activity',
    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: accessUpdates,
      builder: (context, access) {
        if (access.hasError ||
            (access.hasData &&
                (!access.data!.exists ||
                    !(access.data!.data()?['memberIds'] as List? ?? [])
                        .contains(FirebaseAuth.instance.currentUser?.uid)))) {
          return const Center(
            child: SharedNotice('Access to this shared history has ended.'),
          );
        }
        if (!access.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () => load(refresh: true),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: records.length + 1,
            itemBuilder: (context, index) {
              if (index < records.length) {
                final record = SharedSavingsTransaction(
                  records[index].id,
                  records[index].data(),
                );
                final day = sharedDateText(
                  sharedDate(records[index].data()['createdAt']),
                );
                final previousDay = index == 0
                    ? null
                    : sharedDateText(
                        sharedDate(records[index - 1].data()['createdAt']),
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (day != previousDay)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          day,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    SharedActivityTile(record: record),
                  ],
                );
              }
              return Column(
                children: [
                  if (records.isEmpty && !busy && error == null)
                    const SharedNotice('No savings activity yet.'),
                  if (error != null) SharedNotice(error!, error: true),
                  if (busy) const CircularProgressIndicator(),
                  if (!busy && !denied && (more || error != null))
                    TextButton(
                      onPressed: () => load(),
                      child: Text(error == null ? 'Load more' : 'Retry'),
                    ),
                ],
              );
            },
          ),
        );
      },
    ),
  );
}
