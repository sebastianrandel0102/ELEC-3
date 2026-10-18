import 'package:flutter/material.dart';

import '../../design_system.dart';

class AgentEmblem extends StatelessWidget {
  const AgentEmblem({super.key, this.size = 40, this.onDark = false});
  final double size;
  final bool onDark;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDark
            ? SaveTrackDesign.heroHighlight
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size * .53,
        color: onDark ? mint : Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class AgentSurface extends StatelessWidget {
  const AgentSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.selected = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected ? c.secondaryContainer : c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(SaveTrackDesign.radius),
        border: Border.all(color: selected ? c.primary : c.outlineVariant),
      ),
      child: child,
    );
  }
}

class AgentHero extends StatelessWidget {
  const AgentHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.footer,
  });
  final String eyebrow, title, subtitle;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: DecoratedBox(
      decoration: const BoxDecoration(gradient: SaveTrackDesign.premium),
      child: Stack(
        children: [
          Positioned(
            right: -55,
            top: -90,
            child: ExcludeSemantics(
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [SaveTrackDesign.heroHighlight, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AgentEmblem(onDark: true, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        eyebrow,
                        style: const TextStyle(
                          color: mint,
                          fontSize: 11,
                          height: 1.5,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.18,
                    letterSpacing: -.9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: SaveTrackDesign.onHeroMuted,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
                if (footer != null) ...[const SizedBox(height: 20), footer!],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class AgentSectionHeader extends StatelessWidget {
  const AgentSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 14),
    child: MediaQuery.textScalerOf(context).scale(1) > 1.4
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              ?action,
            ],
          )
        : Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?action,
            ],
          ),
  );
}

class AgentQuickActionCard extends StatelessWidget {
  const AgentQuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.featured = false,
  });
  final IconData icon;
  final String title, description;
  final VoidCallback onTap;
  final bool featured;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: Material(
        animationDuration: SaveTrackDesign.duration(
          context,
          SaveTrackDesign.selectionMotion,
        ),
        color: featured ? c.secondaryContainer : c.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: c.primary, size: 23),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      size: 16,
                      color: c.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: TextStyle(
                    color: c.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    color: c.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AgentStatusChip extends StatelessWidget {
  const AgentStatusChip({
    super.key,
    required this.label,
    this.icon = Icons.circle_outlined,
    this.error = false,
  });
  final String label;
  final IconData icon;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = error ? c.error : c.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AgentEmptyState extends StatelessWidget {
  const AgentEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.route_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => AgentSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 26, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 8), action!],
      ],
    ),
  );
}

class AgentProcessingIndicator extends StatelessWidget {
  const AgentProcessingIndicator({
    super.key,
    required this.label,
    this.onCancel,
  });
  final String label;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: AgentSurface(
      child: Row(
        children: [
          if (MediaQuery.disableAnimationsOf(context))
            const AgentEmblem(size: 28)
          else
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (onCancel != null)
            IconButton(
              tooltip: 'Stop waiting',
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 20),
            ),
        ],
      ),
    ),
  );
}

class AgentModeCard extends StatelessWidget {
  const AgentModeCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title, description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        animationDuration: SaveTrackDesign.duration(
          context,
          SaveTrackDesign.selectionMotion,
        ),
        color: selected ? c.secondaryContainer : c.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? c.primary : c.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: c.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          color: c.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: c.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
