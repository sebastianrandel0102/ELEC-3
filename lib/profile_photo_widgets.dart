import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'design_system.dart';
import 'profile_photo_picker.dart';
import 'profile_photo_processing.dart';
import 'profile_photo_service.dart';

String profileInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  return (words.length == 1
          ? words.first.characters.first
          : '${words.first.characters.first}${words.last.characters.first}')
      .toUpperCase();
}

/// Authenticated custom bytes have precedence over the provider's public photo.
/// A failed custom download falls back to initials, without a broken image icon.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.size = 104,
    this.storagePath,
    this.googlePhotoUrl,
    this.load,
    this.bytes,
  });
  final String name;
  final double size;
  final String? storagePath, googlePhotoUrl;
  final Future<Uint8List?> Function(String)? load;
  final Uint8List? bytes;
  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Future<Uint8List?>? _image;
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath) _resolve();
  }

  void _resolve() {
    _image = widget.storagePath != null && widget.load != null
        ? widget.load!(widget.storagePath!)
        : null;
  }

  Widget _fallback() {
    final initials = profileInitials(widget.name);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SaveTrackDesign.glow),
      child: Center(
        child: initials.isEmpty
            ? Icon(Icons.person_outline, color: teal, size: widget.size * .42)
            : Text(
                initials,
                style: TextStyle(
                  color: teal,
                  fontSize: widget.size * .29,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _photo(ImageProvider provider) => Image(
    image: provider,
    width: widget.size,
    height: widget.size,
    fit: BoxFit.cover,
    errorBuilder: (_, error, stack) => _fallback(),
    loadingBuilder: (_, child, progress) => progress == null
        ? child
        : Stack(
            fit: StackFit.expand,
            children: [
              _fallback(),
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ),
  );

  @override
  Widget build(BuildContext context) {
    final providerUrl = Uri.tryParse(widget.googlePhotoUrl ?? '');
    final providerValid =
        providerUrl != null &&
        providerUrl.host.isNotEmpty &&
        providerUrl.scheme == 'https';
    final content = widget.bytes != null
        ? _photo(MemoryImage(widget.bytes!))
        : widget.storagePath != null
        ? FutureBuilder<Uint8List?>(
            future: _image,
            builder: (_, snapshot) => snapshot.hasData
                ? _photo(MemoryImage(snapshot.data!))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      _fallback(),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
          )
        : providerValid
        ? _photo(NetworkImage(providerUrl.toString()))
        : _fallback();
    return Semantics(
      label:
          '${widget.name.trim().isEmpty ? 'Your' : widget.name} profile picture',
      image: true,
      child: Container(
        width: widget.size,
        height: widget.size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: mint.withValues(alpha: .8), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x29145C4B),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(child: content),
      ),
    );
  }
}

enum ProfilePhotoAction { gallery, view, remove }

Future<ProfilePhotoAction?> showProfilePhotoActions(
  BuildContext context, {
  required bool canView,
  required bool canRemove,
}) => showModalBottomSheet<ProfilePhotoAction>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheetContext) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Profile Picture', style: SaveTrackDesign.heading),
          const SizedBox(height: 8),
          const Text(
            'Choose a photo to personalize your SaveTrack account.',
            style: TextStyle(color: muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          ListTile(
            key: const ValueKey('choose-profile-gallery'),
            leading: const MintIcon(Icons.photo_library_outlined),
            title: const Text('Choose from Gallery'),
            onTap: () =>
                Navigator.pop(sheetContext, ProfilePhotoAction.gallery),
          ),
          if (canView)
            ListTile(
              leading: const MintIcon(Icons.fullscreen),
              title: const Text('View Profile Picture'),
              onTap: () => Navigator.pop(sheetContext, ProfilePhotoAction.view),
            ),
          if (canRemove)
            ListTile(
              leading: const MintIcon(Icons.delete_outline),
              title: const Text('Remove Profile Picture'),
              onTap: () =>
                  Navigator.pop(sheetContext, ProfilePhotoAction.remove),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  ),
);

class ProfilePhotoEditor extends StatefulWidget {
  const ProfilePhotoEditor({
    super.key,
    required this.uid,
    required this.name,
    required this.service,
    required this.picker,
    this.path,
    this.googlePhotoUrl,
    this.enabled = true,
  });
  final String uid, name;
  final String? path, googlePhotoUrl;
  final ProfilePhotoService service;
  final ProfilePhotoPicker picker;
  final bool enabled;
  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  bool _busy = false;
  bool _preparing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  bool get _active =>
      mounted && widget.service.backend.currentUid == widget.uid;
  Future<void> _recover() async {
    unawaited(widget.service.maintain(widget.uid));
    try {
      final file = await widget.picker.recover(widget.uid);
      if (file != null && _active && !_busy) {
        setState(() => _busy = true);
        try {
          await _preview(file);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      }
    } catch (error) {
      if (_active) _message(profilePhotoErrorMessage(error));
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _actions() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    try {
      final custom = ownsAvatarPath(widget.uid, widget.path);
      final action = await showProfilePhotoActions(
        context,
        canView: custom || (widget.googlePhotoUrl?.isNotEmpty ?? false),
        canRemove: custom,
      );
      if (!mounted || !_active) return;
      switch (action) {
        case ProfilePhotoAction.gallery:
          final file = await widget.picker.pick(widget.uid);
          if (file != null && _active) await _preview(file);
        case ProfilePhotoAction.view:
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Profile Picture',
                      style: SaveTrackDesign.heading,
                    ),
                    const SizedBox(height: 24),
                    ProfileAvatar(
                      name: widget.name,
                      size: 240,
                      storagePath: widget.path,
                      googlePhotoUrl: widget.googlePhotoUrl,
                      load: (p) => widget.service.load(widget.uid, p),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          );
        case ProfilePhotoAction.remove:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Remove profile picture?'),
              content: const Text(
                'Your account will use your Google photo or default avatar.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('confirm-remove-profile-photo'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (confirmed == true && _active) await _persist(null);
        case null:
          break;
      }
    } catch (error) {
      if (_active) _message(profilePhotoErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(XFile file) async {
    if (await file.length() > ProfilePhotoLimits.originalBytes) {
      throw const ProfilePhotoFailure('Choose a photo smaller than 20 MB.');
    }
    if (!_active) return;
    setState(() => _preparing = true);
    late final PreparedProfilePhoto photo;
    try {
      photo = await prepareProfilePhoto(await file.readAsBytes());
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
    if (!mounted || !_active) return;
    final bytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ProfilePhotoPreview(photo: photo),
    );
    if (bytes != null && _active) await _persist(bytes);
  }

  Future<void> _persist(Uint8List? bytes) async {
    final uid = widget.uid;
    final service = widget.service;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProfilePhotoUploadDialog(
        removing: bytes == null,
        operation: (progress) => bytes == null
            ? service.remove(uid)
            : service.save(uid, bytes, onProgress: progress),
      ),
    );
    if (_active) {
      _message(
        result == 'success'
            ? bytes == null
                  ? 'Profile picture removed.'
                  : 'Profile picture updated.'
            : result ?? 'Your profile picture could not be updated.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          children: [
            Positioned(
              left: 4,
              top: 4,
              child: Semantics(
                button: true,
                label: 'Change profile picture',
                child: InkWell(
                  key: const ValueKey('change-profile-picture'),
                  customBorder: const CircleBorder(),
                  onTap: _busy || !widget.enabled ? null : _actions,
                  child: ProfileAvatar(
                    name: widget.name,
                    storagePath: widget.path,
                    googlePhotoUrl: widget.googlePhotoUrl,
                    load: (p) => widget.service.load(widget.uid, p),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: mint,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  tooltip: 'Change profile picture',
                  onPressed: _busy || !widget.enabled ? null : _actions,
                  icon: const Icon(
                    Icons.add_a_photo_outlined,
                    color: teal,
                    size: 21,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (_preparing)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: mint),
          ),
        ),
    ],
  );
}

class ProfilePhotoPreview extends StatefulWidget {
  const ProfilePhotoPreview({super.key, required this.photo});
  final PreparedProfilePhoto photo;
  @override
  State<ProfilePhotoPreview> createState() => _ProfilePhotoPreviewState();
}

class _ProfilePhotoPreviewState extends State<ProfilePhotoPreview> {
  double _x = .5, _y = .5, _zoom = 1;
  bool _processing = false;
  String? _error;
  Future<void> _confirm() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final bytes = await cropProfilePhoto(
        widget.photo,
        ProfilePhotoCrop(x: _x, y: _y, zoom: _zoom),
      );
      if (mounted) Navigator.pop(context, bytes);
    } catch (error) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = profilePhotoErrorMessage(error);
        });
      }
    }
  }

  Widget _slider(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    double min = 0,
    double max = 1,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
      ),
      Slider(
        label: label,
        value: value,
        min: min,
        max: max,
        onChanged: _processing ? null : onChanged,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_processing,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormHeading(
                icon: Icons.crop_rounded,
                title: 'Preview Profile Picture',
                detail: 'Adjust the crop, then save your photo.',
              ),
              const SizedBox(height: 24),
              Center(
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final size = math.min(260.0, constraints.maxWidth);
                    final scale =
                        size /
                        math.min(widget.photo.width, widget.photo.height) *
                        _zoom;
                    final width = widget.photo.width * scale,
                        height = widget.photo.height * scale;
                    return Container(
                      width: size,
                      height: size,
                      foregroundDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: mint, width: 3),
                      ),
                      child: ClipOval(
                        child: Stack(
                          children: [
                            Positioned(
                              left: -(width - size) * _x,
                              top: -(height - size) * _y,
                              width: width,
                              height: height,
                              child: Image.memory(
                                widget.photo.bytes,
                                fit: BoxFit.fill,
                                key: const ValueKey(
                                  'selected-profile-photo-preview',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              _slider(
                'Zoom',
                _zoom,
                (v) => setState(() => _zoom = v),
                min: 1,
                max: 3,
              ),
              _slider('Horizontal position', _x, (v) => setState(() => _x = v)),
              _slider('Vertical position', _y, (v) => setState(() => _y = v)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: SaveTrackDesign.error),
                  ),
                ),
              GradientButton(
                key: const ValueKey('save-profile-picture'),
                onPressed: _processing ? null : _confirm,
                child: _processing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Profile Picture'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _processing ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProfilePhotoUploadDialog extends StatefulWidget {
  const _ProfilePhotoUploadDialog({
    required this.operation,
    required this.removing,
  });
  final Future<void> Function(void Function(double)) operation;
  final bool removing;
  @override
  State<_ProfilePhotoUploadDialog> createState() =>
      _ProfilePhotoUploadDialogState();
}

class _ProfilePhotoUploadDialogState extends State<_ProfilePhotoUploadDialog> {
  double? _progress;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_run());
    });
  }

  Future<void> _run() async {
    var result = 'success';
    try {
      await widget.operation((v) {
        if (mounted) setState(() => _progress = v.clamp(0, 1));
      });
    } catch (error) {
      result = profilePhotoErrorMessage(error);
    }
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: FormHeading(
        icon: Icons.cloud_upload_outlined,
        detail: 'Updating your account securely.',
        title: widget.removing
            ? 'Removing Profile Picture'
            : 'Uploading Profile Picture',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.removing
                ? 'Please wait while we update your profile.'
                : 'Please wait while we save your new photo.',
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: _progress != null && _progress! < 1 ? _progress : null,
          ),
          if (_progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _progress! >= 1
                    ? 'Saving your profile…'
                    : '${(_progress! * 100).round()}% uploaded',
                style: const TextStyle(color: muted),
              ),
            ),
        ],
      ),
    ),
  );
}
