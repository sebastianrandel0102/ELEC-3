import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'design_system.dart';
import 'password_recovery_service.dart';

class PasswordRecoveryDialog extends StatefulWidget {
  const PasswordRecoveryDialog({
    super.key,
    this.authService,
    this.initialEmail = '',
  });
  final AuthService? authService;
  final String initialEmail;

  @override
  State<PasswordRecoveryDialog> createState() => _PasswordRecoveryDialogState();
}

class _PasswordRecoveryDialogState extends State<PasswordRecoveryDialog> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail.trim());
  bool _busy = false, _sent = false;
  String? _error, _emailError, _submittedEmail;
  int _cooldown = 0;
  Timer? _timer;

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown == 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    if (_busy || _cooldown > 0) return;
    if (!_sent) {
      setState(() => _emailError = null);
      if (!_form.currentState!.validate()) return;
    }
    final email = _submittedEmail ?? _email.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.authService ?? AuthService.instance).sendPasswordResetEmail(
        email,
      );
      if (!mounted) return;
      setState(() {
        _submittedEmail = email;
        _sent = true;
        _startCooldown();
      });
    } on PasswordRecoveryFailure catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.rateLimited) _startCooldown();
        if (error.invalidEmail && !_sent) {
          _emailError = error.message;
          _form.currentState!.validate();
        } else {
          _error = error.message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: SaveTrackDesign.premium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _sent ? Icons.mark_email_read_outlined : Icons.lock_reset,
                      color: mint,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _sent ? 'Check Your Email' : 'Forgot Password?',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sent
                          ? 'If this email address is associated with an eligible SaveTrack account, password-reset instructions will be sent. Please check your inbox or spam folder.'
                          : "Enter your email address and we'll send you a secure link to reset your password.",
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
                    if (!_sent) ...[
                      Form(
                        key: _form,
                        child: TextFormField(
                          key: const ValueKey('recovery-email'),
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (value) =>
                              validateRecoveryEmail(value) ?? _emailError,
                          onChanged: (_) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                          onFieldSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'Enter your registered email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Check your inbox and spam folder after requesting a reset.',
                        style: TextStyle(color: muted),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'This resets your SaveTrack email/password credential. If you use Google Sign-In, continue signing in with Google; this does not change your Google password.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: const TextStyle(color: SaveTrackDesign.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GradientButton(
                      onPressed: _busy || _cooldown > 0 ? null : _send,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                                semanticsLabel:
                                    'Requesting password-reset email',
                              ),
                            )
                          : Text(_sent ? 'Resend Link' : 'Send Reset Link'),
                    ),
                    if (_cooldown > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        'To avoid repeated requests, SaveTrack enables another request in $_cooldown seconds.',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Back to Login'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }
}
