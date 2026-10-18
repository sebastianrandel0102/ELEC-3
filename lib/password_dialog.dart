import 'package:flutter/material.dart';

import 'design_system.dart';
import 'password_service.dart';
import 'auth_service.dart';
import 'password_recovery_dialog.dart';

Future<void> showPasswordRecoveryDialog(
  BuildContext context, {
  AuthService? authService,
  String initialEmail = '',
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => PasswordRecoveryDialog(
    authService: authService,
    initialEmail: initialEmail,
  ),
);

Future<void> showChangePasswordDialog(
  BuildContext context,
  PasswordChangeSession session,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => PasswordDialog(session: session),
);

/// Signed-in password changes require the existing authenticated session.
class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key, required this.session});
  final PasswordChangeSession session;

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _visible = <String, bool>{};
  bool _busy = false, _success = false;
  String? _error;

  Future<void> _verifyGoogle() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final verified = await widget.session.verifyGoogle();
      if (verified) {
        _current.clear();
        _password.clear();
        _confirm.clear();
      }
    } catch (error) {
      if (mounted) setState(() => _error = passwordErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.save(
        password: _password.text,
        confirmation: _confirm.text,
        currentPassword: _current.text,
      );
      _current.clear();
      _password.clear();
      _confirm.clear();
      if (mounted) setState(() => _success = true);
    } catch (error) {
      if (mounted) setState(() => _error = passwordErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _passwordField(
    String label,
    TextEditingController controller,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(label),
      controller: controller,
      enabled: !_busy,
      obscureText: !(_visible[label] ?? false),
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: label == 'Confirm New Password'
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: label == 'Confirm New Password' ? (_) => _save() : null,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: '${(_visible[label] ?? false) ? 'Hide' : 'Show'} $label',
          onPressed: _busy
              ? null
              : () => setState(
                  () => _visible[label] = !(_visible[label] ?? false),
                ),
          icon: Icon(
            (_visible[label] ?? false)
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final verified = session.googleVerified;
    final editable = session.hasPassword;
    final title = _success
        ? 'Password Changed'
        : verified
        ? 'Create New Password'
        : 'Change Password';
    final subtitle = _success
        ? 'Your SaveTrack password has been updated.'
        : verified
        ? 'Choose a secure password for your SaveTrack account.'
        : editable
        ? 'Verify your identity to keep your account secure.'
        : 'Manage your account with its sign-in provider.';

    return PopScope(
      canPop: !_busy,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MintHero(
                  deep: true,
                  edgeToEdge: true,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _success
                            ? Icons.check_circle_outline
                            : Icons.shield_outlined,
                        color: mint,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: SaveTrackDesign.onHeroMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_success) ...[
                        Semantics(
                          liveRegion: true,
                          child: const Text(
                            'Use your new password the next time you sign in.',
                          ),
                        ),
                        const SizedBox(height: 20),
                        GradientButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
                        ),
                      ] else ...[
                        if (!editable) ...[
                          Text(
                            session.hasGoogle
                                ? 'This account uses Google Sign-In and has no SaveTrack password. '
                                      'Manage your Google password in your Google Account and continue signing in with Google.'
                                : 'This account has no SaveTrack password. Continue using its existing sign-in provider.',
                          ),
                        ] else ...[
                          if (session.canVerifyGoogle && !verified) ...[
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _verifyGoogle,
                              icon: const Icon(Icons.verified_user_outlined),
                              label: const Text('Verify with linked Google'),
                            ),
                            const SizedBox(height: 16),
                            const Text('Or verify with your current password.'),
                            const SizedBox(height: 16),
                          ],
                          Form(
                            key: _form,
                            child: Column(
                              children: [
                                if (!verified)
                                  _passwordField(
                                    'Current Password',
                                    _current,
                                    (value) => value == null || value.isEmpty
                                        ? 'Please enter your current password.'
                                        : null,
                                  ),
                                _passwordField(
                                  'New Password',
                                  _password,
                                  (value) =>
                                      PasswordChangeSession.validateNewPassword(
                                        value ?? '',
                                      ),
                                ),
                                _passwordField(
                                  'Confirm New Password',
                                  _confirm,
                                  (value) =>
                                      PasswordChangeSession.validateConfirmation(
                                        _password.text,
                                        value ?? '',
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Your new password must meet your account’s security rules. '
                            'These are checked before saving.',
                            style: TextStyle(
                              color: context.atelierMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(color: context.atelierError),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_busy) ...[
                          Semantics(
                            liveRegion: true,
                            label: 'Processing account verification or password update',
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (editable) ...[
                          GradientButton(
                            onPressed: _busy ? null : _save,
                            child: const Text('Save New Password'),
                          ),
                          const SizedBox(height: 8),
                        ],
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
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

  @override
  void dispose() {
    _current.clear();
    _password.clear();
    _confirm.clear();
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }
}
