part of 'design_system.dart';

class AuroraGreeting extends StatelessWidget {
  const AuroraGreeting({super.key, required this.date, required this.greeting});
  final String date, greeting;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(date, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(greeting, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

/// A separate coordinator per tab keeps its header and content scroll state.
/// Existing lists inherit the inner controller; no second data layer is added.
class AuroraPage extends StatelessWidget {
  const AuroraPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.leading,
    this.storageKey,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? leading;
  final String? storageKey;

  @override
  Widget build(BuildContext context) => NestedScrollView(
    key: PageStorageKey(storageKey ?? 'aurora-page-$title'),
    headerSliverBuilder: (context, innerBoxIsScrolled) => [
      AuroraLargeTitle(
        title: title,
        actions: actions,
        leading: leading,
        scrolled: innerBoxIsScrolled,
      ),
    ],
    body: child,
  );
}

/// One title morphs between its expanded and toolbar positions. FlexibleSpaceBar
/// derives the interpolation from scroll geometry, including reduced motion.
class AuroraLargeTitle extends StatelessWidget {
  const AuroraLargeTitle({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.scrolled = false,
  });
  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final bool scrolled;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    final largeText = scale.scale(20) > 28;
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      leading: leading,
      actions: actions,
      toolbarHeight: largeText ? 72 : 56,
      expandedHeight: largeText ? 144 : 104,
      backgroundColor: context.atelierCanvas,
      surfaceTintColor: Colors.transparent,
      forceElevated: scrolled,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final range =
              (settings?.maxExtent ?? 104) - (settings?.minExtent ?? 56);
          final expanded = range <= 0
              ? 0.0
              : (((settings?.currentExtent ?? constraints.maxHeight) -
                            (settings?.minExtent ?? 56)) /
                        range)
                    .clamp(0.0, 1.0);
          final inset = SaveTrackDesign.pageInset(
            MediaQuery.sizeOf(context).width,
          );
          final leadingSpace = leading == null ? inset : 64.0;
          final trailingSpace = actions.length * 48.0 + 12;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: inset + (leadingSpace - inset) * (1 - expanded),
                right: expanded > .5 ? inset : trailingSpace,
                bottom: 12,
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: largeText && expanded > .5 ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20 + 14 * expanded,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.6 * expanded,
                      color: context.atelierInk,
                    ),
                  ),
                ),
              ),
              if (scrolled)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Divider(height: 1, color: context.atelierBorder),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Related rows share one surface, with inset separators and natural heights.
class AuroraGroupedSection extends StatelessWidget {
  const AuroraGroupedSection({
    super.key,
    this.title,
    this.footer,
    required this.children,
  });
  final String? title, footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Semantics(
            header: true,
            child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: 76, color: context.atelierBorder),
              children[i],
            ],
          ],
        ),
      ),
      if (footer != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(footer!, style: Theme.of(context).textTheme.bodySmall),
        ),
    ],
  );
}

class AuroraIdentity extends StatelessWidget {
  const AuroraIdentity({
    super.key,
    required this.name,
    required this.email,
    required this.avatar,
  });
  final String name, email;
  final Widget avatar;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(email, style: Theme.of(context).textTheme.bodySmall),
            ],
          );
          if (constraints.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(14) > 22) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [avatar, const SizedBox(height: 16), text],
            );
          }
          return Row(
            children: [
              avatar,
              const SizedBox(width: 16),
              Expanded(child: text),
            ],
          );
        },
      ),
    ),
  );
}

class AuroraQuickAction extends StatelessWidget {
  const AuroraQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabledReason,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    hint: onTap == null ? disabledReason : null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: onTap == null
                      ? context.atelierTonal
                      : context.atelierSelected,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 23,
                  color: onTap == null
                      ? context.atelierMuted
                      : context.atelierAccent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onTap == null
                      ? context.atelierMuted
                      : context.atelierInk,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One selection with wrapping labels, keyboard focus and a 48-pixel target.
class AuroraModeSelector<T extends Object> extends StatelessWidget {
  const AuroraModeSelector({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelected,
  });
  final T selected;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: context.atelierTonal,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final entry in options.entries)
          Expanded(
            child: Semantics(
              selected: entry.key == selected,
              child: TextButton(
                onPressed: () => onSelected(entry.key),
                style: TextButton.styleFrom(
                  backgroundColor: entry.key == selected
                      ? context.atelierSurface
                      : Colors.transparent,
                  foregroundColor: entry.key == selected
                      ? context.atelierInk
                      : context.atelierMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: entry.key == selected
                          ? context.atelierBorder
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(entry.value, textAlign: TextAlign.center),
              ),
            ),
          ),
      ],
    ),
  );
}

class AuroraAssistChooser extends StatelessWidget {
  const AuroraAssistChooser({
    super.key,
    required this.onAi,
    required this.onAgent,
  });
  final VoidCallback onAi, onAgent;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Assist',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close Assist',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A little clarity. A thoughtful next step.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          AuroraGroupedSection(
            children: [
              ListTile(
                leading: const MintIcon(Icons.auto_awesome_outlined),
                title: const Text('SaveTrack AI'),
                subtitle: const Text(
                  'Ask questions and understand your progress. Read-only coaching.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onAi,
              ),
              ListTile(
                leading: const MintIcon(Icons.hub_outlined),
                title: const Text('Agent Studio Pro'),
                subtitle: const Text(
                  'Prepare goals, tasks and missions. Review actions before execution.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onAgent,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Static placeholders avoid perpetual shimmer and expose a single status.
class AuroraSkeleton extends StatelessWidget {
  const AuroraSkeleton({super.key, this.featured = false});
  final bool featured;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(context, .38, 14),
              SizedBox(height: featured ? 20 : 12),
              _line(context, .7, featured ? 36 : 20),
              const SizedBox(height: 16),
              _line(context, 1, 8),
              if (featured) ...[
                const SizedBox(height: 20),
                _line(context, .6, 14),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _line(BuildContext context, double width, double height) =>
      FractionallySizedBox(
        widthFactor: width,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: context.atelierTonal,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
}

/// Cache and pending writes are separate states, never a success indicator.
class AuroraSyncStatus extends StatelessWidget {
  const AuroraSyncStatus({
    super.key,
    required this.cached,
    required this.pending,
  });
  final bool cached, pending;

  @override
  Widget build(BuildContext context) {
    if (!cached && !pending) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        liveRegion: true,
        child: AuroraNotice(
          pending
              ? 'Changes are pending cloud confirmation.'
              : 'Showing cached information. Reconnect for the latest updates.',
          icon: pending
              ? Icons.cloud_upload_outlined
              : Icons.cloud_off_outlined,
        ),
      ),
    );
  }
}
