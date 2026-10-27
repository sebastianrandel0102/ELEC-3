part of 'main.dart';

Future<void> showAssistChooser(BuildContext context) async {
  final destination = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (sheet) => AuroraAssistChooser(
      onAi: () => Navigator.pop(sheet, 'ai'),
      onAgent: () => Navigator.pop(sheet, 'agent'),
    ),
  );
  if (!context.mounted || destination == null) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => destination == 'ai'
          ? const AiCoachScreen()
          : const AgentStudioScreen(onOpen: _openAgentDestination),
    ),
  );
}

/// Presentation over the original document and guarded financial dialogs.
class PersonalGoalOverview extends StatelessWidget {
  const PersonalGoalOverview({
    super.key,
    required this.uid,
    required this.doc,
    this.recentActivity,
    this.coverLoad,
    this.clock = DateTime.now,
  });
  final String uid;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Widget? recentActivity;
  final Future<Uint8List?> Function(String)? coverLoad;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = data['title']?.toString() ?? 'Savings goal';
    final code = goalCurrency(data);
    final saved = _number(data['savedAmount']);
    final target = _number(data['targetAmount']);
    if (!saved.isFinite || !target.isFinite || saved < 0 || target < 0) {
      return const AuroraNotice(
        'This goal has an unavailable balance or target. Review it before recording savings.',
        error: true,
      );
    }
    final progress = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final coverTarget = GoalCoverTarget.personal(uid, doc.id);
    final cover = GoalCoverRecord.fromMap(data, coverTarget);
    final deadline = data['deadline'] is Timestamp
        ? (data['deadline'] as Timestamp).toDate()
        : null;
    final reminder = ReminderTarget.fromData(
      ReminderTargetType.personalGoal,
      doc.id,
      data,
      deadline: deadline,
    );
    String money(num amount) => displayMoney(context, amount, code);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Goal actions',
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    showGoalForm(context, doc: doc);
                  case 'cover':
                    showGoalCoverActions(context, coverTarget, cover.path);
                  case 'shared':
                    createSharedGoal(context, personal: data);
                  case 'reminder':
                    showReminderEditor(context, reminder);
                  case 'delete':
                    confirmDelete(
                      context,
                      'Delete this goal and its savings history?',
                      () => _deleteGoal(doc),
                    );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit goal')),
                PopupMenuItem(value: 'cover', child: Text('Manage goal photo')),
                PopupMenuItem(
                  value: 'reminder',
                  child: Text('Manage Reminder'),
                ),
                PopupMenuItem(value: 'shared', child: Text('Save Together')),
                PopupMenuItem(value: 'delete', child: Text('Delete goal')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (cover.path != null) ...[
          GoalCoverImage(
            target: coverTarget,
            name: title,
            path: cover.path,
            decodeWidth: 960,
            load: coverLoad,
            onEdit: () =>
                showGoalCoverActions(context, coverTarget, cover.path),
          ),
          const SizedBox(height: 16),
        ],
        MintHero(
          soft: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Current balance',
                style: TextStyle(color: context.atelierInk),
              ),
              const SizedBox(height: 10),
              AmountText(
                money(saved),
                onDark: false,
                compactCurrency: true,
                style: SaveTrackDesign.amount.copyWith(
                  color: context.atelierInk,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Goal currency · $code',
                style: TextStyle(color: context.atelierInk),
              ),
              const SizedBox(height: 20),
              MintProgress(value: progress, onDark: false),
              const SizedBox(height: 10),
              Text(
                target > 0 && saved >= target
                    ? 'Goal reached · ${(progress * 100).round()}%'
                    : '${(progress * 100).round()}% of your target',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GradientButton(
          onPressed: () => showDepositForm(context, uid, doc),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded),
              SizedBox(width: 8),
              Flexible(child: Text('Add savings')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: saved > 0
              ? () => showDecreaseSavingsForm(context, uid, doc)
              : null,
          icon: const Icon(Icons.remove_rounded),
          label: const Text('Decrease Savings'),
        ),
        const SizedBox(height: 24),
        AuroraGroupedSection(
          title: 'Your milestone',
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Target'),
              subtitle: Text(money(target)),
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Remaining'),
              subtitle: Text(money((target - saved).clamp(0, double.infinity))),
            ),
            if (deadline != null)
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('Target date'),
                subtitle: Text(DateFormat.yMMMd().format(deadline)),
              ),
            if (deadline != null && saved < target)
              Builder(
                builder: (context) {
                  final now = clock();
                  final today = DateTime(now.year, now.month, now.day);
                  final needed = target - saved;
                  final days = deadline
                      .difference(today)
                      .inDays
                      .clamp(1, 365000);
                  final overdue = deadline.isBefore(today);
                  return ListTile(
                    leading: Icon(overdue ? Icons.schedule : Icons.trending_up),
                    title: Text(
                      overdue ? 'Past target date' : 'Suggested pace',
                    ),
                    subtitle: Text(
                      overdue
                          ? '${money(needed)} remaining'
                          : '${money(needed / days)} daily, ${money(needed * 7 / days)} weekly',
                    ),
                  );
                },
              ),
            if ((data['note'] as String? ?? '').isNotEmpty)
              ListTile(
                leading: const Icon(Icons.notes_rounded),
                title: const Text('Notes'),
                subtitle: Text(data['note'] as String),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => showTransactionHistory(context, doc),
              child: const Text('View all'),
            ),
          ],
        ),
        recentActivity ?? RecentPersonalTransactions(goal: doc),
        const SizedBox(height: 16),
        ReminderButton(target: reminder),
      ],
    );
  }
}

class RecentPersonalTransactions extends StatefulWidget {
  const RecentPersonalTransactions({super.key, required this.goal});
  final QueryDocumentSnapshot<Map<String, dynamic>> goal;
  @override
  State<RecentPersonalTransactions> createState() =>
      _RecentPersonalTransactionsState();
}

class _RecentPersonalTransactionsState
    extends State<RecentPersonalTransactions> {
  late final records = widget.goal.reference
      .collection('transactions')
      .orderBy('date', descending: true)
      .limit(5)
      .snapshots(includeMetadataChanges: true);

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: records,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const AuroraNotice(
              'Activity is unavailable. Check your connection and reopen this goal.',
              error: true,
            );
          }
          if (!snapshot.hasData) return const AuroraSkeleton();
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const TonalPanel(
              child: Text('Your savings activity will appear here.'),
            );
          }
          return Column(
            children: [
              AuroraSyncStatus(
                cached: snapshot.data!.metadata.isFromCache,
                pending: snapshot.data!.metadata.hasPendingWrites,
              ),
              AuroraGroupedSection(
                children: [
                  for (final record in docs)
                    PersonalTransactionTile(
                      data: record.data(),
                      currency: goalCurrency(widget.goal.data()),
                    ),
                ],
              ),
            ],
          );
        },
      );
}

/// Stored amounts and conversion metadata are displayed without recalculation.
class PersonalTransactionTile extends StatelessWidget {
  const PersonalTransactionTile({
    super.key,
    required this.data,
    required this.currency,
  });
  final Map<String, dynamic> data;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final withdrawal = data['type'] == 'withdrawal';
    final direction = withdrawal ? 'Savings decreased' : 'Savings added';
    final code = data['currencyCode'] as String? ?? currency;
    final amount =
        '${withdrawal ? '−' : '+'}${displayMoney(context, _number(data['amount']), code)}';
    final date = (data['date'] as Timestamp?)?.toDate();
    final note = data['note'] as String? ?? '';
    return ListTile(
      leading: MintIcon(
        withdrawal ? Icons.remove_rounded : Icons.add_rounded,
        color: withdrawal ? SaveTrackDesign.error : teal,
        size: 40,
      ),
      title: Text(direction),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.isNotEmpty) Text(note),
          Text(
            date == null
                ? 'Date unavailable'
                : DateFormat.yMMMd().add_jm().format(date),
          ),
          AmountText(
            amount,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: withdrawal ? context.atelierError : context.atelierAccent,
            ),
          ),
          CurrencyContextLabel(source: code, historical: true),
        ],
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(direction, style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 16),
                AmountText(
                  amount,
                  style: SaveTrackDesign.amount.copyWith(fontSize: 30),
                ),
                CurrencyContextLabel(source: code, historical: true),
                const SizedBox(height: 12),
                Text(
                  'Recorded amount: ${originalMoney(_number(data['amount']), code)}',
                ),
                if (date != null)
                  Text(DateFormat.yMMMd().add_jm().format(date)),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(note),
                  ),
                if (data['conversion'] is Map)
                  TransactionConversionDetails(
                    data: Map<String, dynamic>.from(data['conversion'] as Map),
                  ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
