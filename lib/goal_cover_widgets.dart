import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'design_system.dart';
import 'goal_cover_cache.dart';
import 'goal_cover_picker.dart';
import 'goal_cover_processing.dart';
import 'goal_cover_service.dart';
import 'profile_photo_processing.dart';

typedef GoalCoverSave = Future<void> Function(
  Uint8List bytes,
  void Function(double) progress,
);

class GoalCoverImage extends StatefulWidget {
  const GoalCoverImage({
    super.key,
    required this.target,
    required this.name,
    this.path,
    this.icon = Icons.flag_outlined,
    this.bytes,
    this.onEdit,
    this.radius = 22,
    this.decodeWidth = 640,
    this.load,
    this.viewerUid,
  });
  final GoalCoverTarget target;
  final String name;
  final String? path, viewerUid;
  final IconData icon;
  final Uint8List? bytes;
  final VoidCallback? onEdit;
  final double radius;
  final int decodeWidth;
  final Future<Uint8List?> Function(String)? load;
  @override
  State<GoalCoverImage> createState() => _GoalCoverImageState();
}

class _GoalCoverImageState extends State<GoalCoverImage> {
  Future<Uint8List?>? _future;
  GoalCoverCache? _cache;
  String? _uid;
  int _loadGeneration = 0;
  int _cacheRevision = 0;
  final _localProviders = <ImageProvider>{};
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(GoalCoverImage old) {
    super.didUpdateWidget(old);
    if (old.bytes != widget.bytes) {
      for (final provider in _localProviders) {
        unawaited(provider.evict());
      }
      _localProviders.clear();
    }
    if (old.path != widget.path ||
        old.target.documentPath != widget.target.documentPath ||
        old.viewerUid != widget.viewerUid) {
      _resolve();
    }
  }

  void _invalidated() {
    if (!mounted) return;
    // Auth changes must remove already-built images immediately. A permission
    // revocation forgets its cache and the existing guarded goal stream hides it.
    final path = widget.path;
    if (_cache?.currentUid() != _uid ||
        (path != null && _cache?.revision(path) != _cacheRevision)) {
      setState(() {
        _future = null;
        _loadGeneration++;
        if (path != null) _cacheRevision = _cache?.revision(path) ?? 0;
      });
    } else if (_future == null &&
        _uid != null &&
        _cache?.canLoad(_uid!, widget.target) == true) {
      setState(_resolve);
    }
  }

  void _resolve() {
    _loadGeneration++;
    final path = widget.path;
    if (path == null || !widget.target.ownsPath(path)) {
      _future = null;
      return;
    }
    if (widget.load != null) {
      _future = widget.load!(path);
      return;
    }
    _cache ??= GoalCoverCache.instance..addListener(_invalidated);
    _uid = widget.viewerUid ?? _cache!.currentUid();
    _cacheRevision = _cache!.revision(path);
    _future = _uid == null ? null : _cache!.load(_uid!, widget.target, path);
  }

  @override
  void dispose() {
    _cache?.removeListener(_invalidated);
    for (final provider in _localProviders) {
      unawaited(provider.evict());
    }
    super.dispose();
  }

  Widget _fallback() => DecoratedBox(
    decoration: const BoxDecoration(gradient: SaveTrackDesign.premium),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          right: -48,
          top: -100,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  SaveTrackDesign.luminous.withValues(alpha: .28),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: -38,
          bottom: -100,
          child: Container(
            width: 280,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: mint.withValues(alpha: .12),
                width: 1.5,
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: mint.withValues(alpha: .2)),
            ),
            child: Icon(widget.icon, color: mint, size: 38),
          ),
        ),
        const Positioned(
          left: 20,
          bottom: 16,
          child: Text(
            'A little closer, every day.',
            style: TextStyle(
              color: SaveTrackDesign.onHeroMuted,
              fontSize: 11,
              letterSpacing: .4,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _photo(Uint8List bytes) {
    final provider = ResizeImage.resizeIfNeeded(
      widget.decodeWidth,
      null,
      MemoryImage(bytes),
    );
    if (widget.bytes != null) _localProviders.add(provider);
    if (_cache != null && _uid != null && widget.path != null) {
      _cache!.track(_uid!, widget.path!, provider);
    }
    return Image(
      image: provider,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, error, stack) => _fallback(),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '${widget.name} goal cover',
    child: AspectRatio(
      aspectRatio: GoalCoverLimits.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.bytes != null)
              _photo(widget.bytes!)
            else
              FutureBuilder<Uint8List?>(
                key: ValueKey('${widget.path}:$_loadGeneration'),
                future: _future,
                builder: (context, snapshot) => AnimatedSwitcher(
                  duration: SaveTrackDesign.duration(
                    context,
                    const Duration(milliseconds: 240),
                  ),
                  child:
                      snapshot.hasData &&
                          (_cache == null || _cache!.currentUid() == _uid)
                      ? KeyedSubtree(
                          key: ValueKey(widget.path),
                          child: _photo(snapshot.data!),
                        )
                      : Stack(
                          key: const ValueKey('fallback'),
                          fit: StackFit.expand,
                          children: [
                            _fallback(),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              const Positioned(
                                left: 20,
                                top: 20,
                                child: SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: mint,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            if (widget.onEdit != null)
              Positioned(
                right: 10,
                top: 10,
                child: Material(
                  color: SaveTrackDesign.obsidian.withValues(alpha: .8),
                  borderRadius: BorderRadius.circular(16),
                  child: IconButton(
                    tooltip: widget.path == null
                        ? 'Add Goal Photo'
                        : 'Change Goal Photo',
                    onPressed: widget.onEdit,
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.white,
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

Future<PreparedProfilePhoto> _prepareFile(XFile file) async {
  if (await file.length() > ProfilePhotoLimits.originalBytes) {
    throw const GoalCoverFailure('Choose a photo smaller than 20 MB.');
  }
  return prepareGoalCover(await file.readAsBytes());
}

Future<Uint8List?> selectGoalCover(
  BuildContext context,
  GoalCoverTarget target, {
  GoalCoverSave? onSave,
  XFile? recovered,
  GalleryGoalCoverPicker? picker,
}) async {
  try {
    final gallery = picker ?? GalleryGoalCoverPicker();
    final file = recovered ?? await gallery.pick(target);
    if (file == null) return null;
    final photo = await _prepareFile(file);
    if (!context.mounted) return null;
    if (FirebaseAuth.instance.currentUser?.uid != target.ownerUid) return null;
    final provider = MemoryImage(photo.bytes);
    await precacheImage(provider, context);
    if (!context.mounted ||
        FirebaseAuth.instance.currentUser?.uid != target.ownerUid) {
      unawaited(provider.evict());
      return null;
    }
    return await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GoalCoverRouteGuard(
        active: FirebaseAuth.instance.authStateChanges().map(
          (user) => user?.uid == target.ownerUid,
        ),
        child: GoalCoverPreview(
          photo: photo,
          onSave: onSave,
          chooseAnother: () async {
            final file = await gallery.pick(target);
            return file == null ? null : _prepareFile(file);
          },
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(goalCoverError(error))));
    }
    return null;
  }
}

Future<void> changeGoalCover(
  BuildContext context,
  GoalCoverTarget target, {
  XFile? recovered,
}) async {
  final service = GoalCoverService(FirestoreGoalCoverBackend());
  final result = await selectGoalCover(
    context,
    target,
    recovered: recovered,
    onSave: (bytes, progress) =>
        service.replace(target, bytes, onProgress: progress),
  );
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Goal cover updated.')));
  }
}

Future<void> removeGoalCover(
  BuildContext context,
  GoalCoverTarget target,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove Goal Photo?'),
      content: const Text('Your goal will use its Mint Aurora cover again.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remove Photo'),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RemoveCoverProgress(target: target),
  );
}

class _RemoveCoverProgress extends StatefulWidget {
  const _RemoveCoverProgress({required this.target});
  final GoalCoverTarget target;
  @override
  State<_RemoveCoverProgress> createState() => _RemoveCoverProgressState();
}

class _RemoveCoverProgressState extends State<_RemoveCoverProgress> {
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(_remove());
  }

  Future<void> _remove() async {
    setState(() => error = null);
    try {
      await GoalCoverService(FirestoreGoalCoverBackend()).remove(widget.target);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goal cover removed.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = goalCoverError(e));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: error != null,
    child: AlertDialog(
      title: Text(
        error == null ? 'Removing Goal Cover' : 'Could not remove cover',
      ),
      content: error == null ? const LinearProgressIndicator() : Text(error!),
      actions: error == null
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              FilledButton(onPressed: _remove, child: const Text('Retry')),
            ],
    ),
  );
}

Future<void> showGoalCoverActions(
  BuildContext context,
  GoalCoverTarget target,
  String? path,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(path == null ? 'Add Goal Photo' : 'Change Goal Photo'),
            onTap: () => Navigator.pop(ctx, 'change'),
          ),
          if (path != null)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove Goal Photo'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'change') {
    await changeGoalCover(context, target);
  } else if (action == 'remove') {
    await removeGoalCover(context, target);
  }
}

/// Existing forms manage covers independently; new forms keep a pending crop.
class GoalCoverFormSection extends StatefulWidget {
  const GoalCoverFormSection({
    super.key,
    required this.target,
    this.path,
    this.pending,
    this.onPendingChanged,
    this.onBusyChanged,
    this.enabled = true,
    this.exists = false,
  });
  final GoalCoverTarget target;
  final String? path;
  final Uint8List? pending;
  final ValueChanged<Uint8List?>? onPendingChanged;
  final ValueChanged<bool>? onBusyChanged;
  final bool enabled, exists;
  @override
  State<GoalCoverFormSection> createState() => _GoalCoverFormSectionState();
}

class _GoalCoverFormSectionState extends State<GoalCoverFormSection> {
  bool busy = false;
  Future<void> _change() async {
    if (busy) return;
    setState(() => busy = true);
    widget.onBusyChanged?.call(true);
    try {
      if (widget.exists) {
        await changeGoalCover(context, widget.target);
      } else {
        final bytes = await selectGoalCover(context, widget.target);
        if (bytes != null && mounted) widget.onPendingChanged?.call(bytes);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Goal Cover Photo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Add a picture that inspires your savings goal.',
          style: TextStyle(color: muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        GoalCoverImage(
          target: widget.target,
          name: 'Your',
          path: widget.path,
          bytes: widget.pending,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: widget.enabled && !busy ? _change : null,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(
                widget.path != null || widget.pending != null
                    ? 'Change Photo'
                    : 'Add Cover Photo',
              ),
            ),
            if (widget.path != null || widget.pending != null)
              TextButton.icon(
                onPressed: !widget.enabled || busy
                    ? null
                    : () async {
                        if (!widget.exists) {
                          widget.onPendingChanged?.call(null);
                          return;
                        }
                        setState(() => busy = true);
                        try {
                          await removeGoalCover(context, widget.target);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove Photo'),
              ),
          ],
        ),
      ],
    ),
  );
}

class GoalCoverPreview extends StatefulWidget {
  const GoalCoverPreview({
    super.key,
    required this.photo,
    required this.chooseAnother,
    this.onSave,
  });
  final PreparedProfilePhoto photo;
  final Future<PreparedProfilePhoto?> Function() chooseAnother;
  final GoalCoverSave? onSave;
  @override
  State<GoalCoverPreview> createState() => _GoalCoverPreviewState();
}

class _GoalCoverPreviewState extends State<GoalCoverPreview> {
  late PreparedProfilePhoto photo = widget.photo;
  double x = .5, y = .5, zoom = 1;
  double? progress;
  bool busy = false, uploading = false, adjusting = true;
  String? error;
  MemoryImage? _previewProvider;
  @override
  void dispose() {
    final provider = _previewProvider;
    if (provider != null) unawaited(provider.evict());
    super.dispose();
  }

  Future<void> _save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      progress = null;
    });
    try {
      final bytes = await cropGoalCover(
        photo,
        GoalCoverCrop(x: x, y: y, zoom: zoom),
      );
      if (widget.onSave != null) {
        if (mounted) setState(() => uploading = true);
        await widget.onSave!(bytes, (value) {
          if (mounted) setState(() => progress = value.clamp(0, 1));
        });
      }
      if (mounted) Navigator.pop(context, bytes);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = goalCoverError(e);
          busy = false;
          uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      insetPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 560),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(
            160,
            MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).vertical -
                MediaQuery.paddingOf(context).vertical -
                32,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Preview Goal Cover',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Make sure your goal looks just right.',
                        style: TextStyle(color: muted),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        label: 'Landscape crop preview. Drag to reposition or use the crop sliders.',
                        image: true,
                        child: AspectRatio(
                          aspectRatio: GoalCoverLimits.aspectRatio,
                          child: LayoutBuilder(
                            builder: (context, bounds) {
                              final scale =
                                  math.max(
                                    bounds.maxWidth / photo.width,
                                    bounds.maxHeight / photo.height,
                                  ) *
                                  zoom;
                              return GestureDetector(
                                onPanUpdate: busy
                                    ? null
                                    : (details) => setState(() {
                                        final dx =
                                                photo.width * scale -
                                                bounds.maxWidth,
                                            dy =
                                                photo.height * scale -
                                                bounds.maxHeight;
                                        if (dx > .1) {
                                          x = (x - details.delta.dx / dx).clamp(
                                            0,
                                            1,
                                          );
                                        }
                                        if (dy > .1) {
                                          y = (y - details.delta.dy / dy).clamp(
                                            0,
                                            1,
                                          );
                                        }
                                      }),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: OverflowBox(
                                    alignment: Alignment(x * 2 - 1, y * 2 - 1),
                                    minWidth: bounds.maxWidth * zoom,
                                    maxWidth: bounds.maxWidth * zoom,
                                    minHeight: bounds.maxHeight * zoom,
                                    maxHeight: bounds.maxHeight * zoom,
                                    child: Image(
                                      image: _previewProvider ??= MemoryImage(
                                        photo.bytes,
                                      ),
                                      width: bounds.maxWidth * zoom,
                                      height: bounds.maxHeight * zoom,
                                      fit: BoxFit.cover,
                                      alignment: Alignment(
                                        x * 2 - 1,
                                        y * 2 - 1,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => setState(() => adjusting = !adjusting),
                        icon: const Icon(Icons.crop),
                        label: const Text('Adjust Crop'),
                      ),
                      if (adjusting) ...[
                        _slider('Zoom', zoom, 1, 3, (v) => zoom = v),
                        _slider('Horizontal position', x, 0, 1, (v) => x = v),
                        _slider('Vertical position', y, 0, 1, (v) => y = v),
                      ],
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                setState(() {
                                  busy = true;
                                  error = null;
                                });
                                try {
                                  final chosen = await widget.chooseAnother();
                                  if (chosen != null &&
                                      mounted &&
                                      context.mounted) {
                                    final chosenProvider = MemoryImage(
                                      chosen.bytes,
                                    );
                                    await precacheImage(
                                      chosenProvider,
                                      context,
                                    );
                                    if (!mounted) {
                                      unawaited(chosenProvider.evict());
                                      return;
                                    }
                                    final previous = _previewProvider;
                                    _previewProvider = null;
                                    if (previous != null) {
                                      unawaited(previous.evict());
                                    }
                                    setState(() {
                                      photo = chosen;
                                      x = .5;
                                      y = .5;
                                      zoom = 1;
                                    });
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() => error = goalCoverError(e));
                                  }
                                } finally {
                                  if (mounted) setState(() => busy = false);
                                }
                              },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose Another Photo'),
                      ),
                      if (busy)
                        Semantics(
                          liveRegion: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                uploading
                                    ? 'Uploading Goal Cover'
                                    : 'Processing Goal Cover',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: progress),
                              const SizedBox(height: 8),
                              Text(
                                uploading
                                    ? 'Saving your goal picture...'
                                    : 'Preparing your landscape crop...',
                              ),
                            ],
                          ),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: SaveTrackDesign.error,
                            ),
                            semanticsLabel: 'Cover update failed. $error',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Cover Photo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> update,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: muted, fontSize: 12)),
      Slider(
        value: value,
        min: min,
        max: max,
        semanticFormatterCallback: (v) => label == 'Zoom'
            ? '${v.toStringAsFixed(1)} times'
            : '${(v * 100).round()} percent',
        onChanged: busy ? null : (v) => setState(() => update(v)),
      ),
    ],
  );
}

/// Private modal content disappears immediately when its selecting session ends.
class GoalCoverRouteGuard extends StatefulWidget {
  const GoalCoverRouteGuard({
    super.key,
    required this.active,
    required this.child,
  });
  final Stream<bool> active;
  final Widget child;
  @override
  State<GoalCoverRouteGuard> createState() => _GoalCoverRouteGuardState();
}

class _GoalCoverRouteGuardState extends State<GoalCoverRouteGuard> {
  bool active = true;
  late final StreamSubscription<bool> subscription;
  @override
  void initState() {
    super.initState();
    subscription = widget.active.listen(
      _changed,
      onError: (Object _) => _changed(false),
    );
  }

  void _changed(bool value) {
    if (value || !mounted || !active) return;
    setState(() => active = false);
    scheduleMicrotask(() {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null) Navigator.of(context).removeRoute(route);
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      active ? widget.child : const SizedBox.shrink();
}

/// Recovery and maintenance belong to the authenticated session, not each card.
class GoalCoverSession extends StatefulWidget {
  const GoalCoverSession({super.key, required this.uid, required this.child});
  final String uid;
  final Widget child;
  @override
  State<GoalCoverSession> createState() => _GoalCoverSessionState();
}

class _GoalCoverSessionState extends State<GoalCoverSession> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  Future<void> _recover() async {
    final backend = FirestoreGoalCoverBackend();
    unawaited(backend.maintain().catchError((Object _) {}));
    try {
      final selection = await GalleryGoalCoverPicker().recover(widget.uid);
      if (selection == null || !mounted || backend.currentUid != widget.uid) {
        return;
      }
      try {
        await backend.read(selection.target);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gallery selection was interrupted. Reopen the goal form and choose your cover again.',
              ),
            ),
          );
        }
        return;
      }
      if (mounted) {
        await changeGoalCover(
          context,
          selection.target,
          recovered: selection.file,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(goalCoverError(e))));
      }
    }
  }

  @override
  void dispose() {
    final cache = GoalCoverCache.active;
    if (cache != null) scheduleMicrotask(cache.clear);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
