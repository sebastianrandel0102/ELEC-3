import 'package:firebase_auth/firebase_auth.dart';

class PasswordFailure implements Exception {
  const PasswordFailure(this.message);
  final String message;
}

/// Captures the authenticated account at dialog creation. No caller-supplied
/// email, Firestore record, UID, or verification flag can select another user.
class PasswordChangeSession {
  PasswordChangeSession({
    required FirebaseAuth auth,
    required this.reauthenticateGoogle,
    required this.supportsGoogle,
  }) : _auth = auth,
       _user = auth.currentUser;

  final FirebaseAuth _auth;
  final User? _user;
  final Future<bool> Function(User) reauthenticateGoogle;
  final bool supportsGoogle;
  bool _busy = false;
  bool _googleVerified = false;

  bool get hasPassword => _hasProvider('password');
  bool get hasGoogle => _hasProvider('google.com');
  bool get canVerifyGoogle => hasPassword && hasGoogle && supportsGoogle;
  bool get googleVerified => _googleVerified;
  bool _hasProvider(String id) =>
      _user?.providerData.any((provider) => provider.providerId == id) ?? false;

  User _requireUser() {
    final user = _user;
    if (user == null || _auth.currentUser?.uid != user.uid) {
      throw const PasswordFailure(
        'Your authentication session changed. Close this window and sign in again.',
      );
    }
    return user;
  }

  Future<bool> verifyGoogle() async {
    if (_busy) return false;
    _busy = true;
    _googleVerified = false;
    try {
      final user = _requireUser();
      // Inspect the current user's Firebase providers before reauth.
      // Reauthentication cannot create or merge an unrelated Firebase account.
      final providers = _auth.currentUser!.providerData;
      if (!canVerifyGoogle ||
          !providers.any((p) => p.providerId == 'google.com') ||
          !providers.any((p) => p.providerId == 'password')) {
        throw const PasswordFailure(
          'A linked Google verification method is not available for this account.',
        );
      }
      if (!await reauthenticateGoogle(user)) return false;
      await _requireRecentSession(user);
      _googleVerified = true;
      return true;
    } finally {
      _busy = false;
    }
  }

  static String? validateNewPassword(String password) {
    if (password.isEmpty) return 'Please enter a new password.';
    if (password.length < 6) {
      return 'Your password must contain at least 6 characters.';
    }
    return null;
  }

  static String? validateConfirmation(String password, String confirmation) {
    if (confirmation.isEmpty) return 'Please confirm your new password.';
    if (password != confirmation) return 'Your passwords do not match.';
    return null;
  }

  Future<void> save({
    required String password,
    required String confirmation,
    String? currentPassword,
  }) async {
    if (_busy) throw const PasswordFailure('A request is already in progress.');
    _busy = true;
    try {
      final user = _requireUser();
      if (!hasPassword) {
        throw const PasswordFailure(
          'This account does not have a SaveTrack password. Use its existing sign-in provider.',
        );
      }
      final validation =
          validateNewPassword(password) ??
          validateConfirmation(password, confirmation);
      if (validation != null) throw PasswordFailure(validation);
      if (!_googleVerified &&
          (currentPassword == null || currentPassword.isEmpty)) {
        throw const PasswordFailure('Please enter your current password.');
      }

      // Read the actual Firebase policy, including length and character rules.
      // If policy retrieval fails, fail closed; never fall back to weaker rules.
      final PasswordValidationStatus status;
      try {
        status = await _auth
            .validatePassword(_auth, password)
            .timeout(const Duration(seconds: 20));
      } on FirebaseAuthException {
        rethrow;
      } catch (_) {
        throw const PasswordFailure(
          'Could not check the password security rules. Check your connection and try again. If this continues, contact support.',
        );
      }
      if (!status.isValid) {
        final missing = <String>[
          if (!status.meetsMinPasswordLength)
            'at least ${status.passwordPolicy.minPasswordLength} characters',
          if (!status.meetsMaxPasswordLength)
            'no more than ${status.passwordPolicy.maxPasswordLength} characters',
          if (!status.meetsLowercaseRequirement) 'a lowercase letter',
          if (!status.meetsUppercaseRequirement) 'an uppercase letter',
          if (!status.meetsDigitsRequirement) 'a number',
          if (!status.meetsSymbolsRequirement) 'a permitted special character',
        ];
        throw PasswordFailure(
          'Your password does not meet the required security rules.'
          '${missing.isEmpty ? '' : ' Include ${missing.join(', ')}.'}',
        );
      }

      _requireUser();
      if (!_googleVerified) {
        final email = user.email;
        if (email == null) {
          throw const PasswordFailure(
            'This account has no password sign-in email.',
          );
        }
        final result = await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: email,
            password: currentPassword!,
          ),
        );
        if (result.user?.uid != user.uid) {
          throw const PasswordFailure(
            'Identity verification did not match your account.',
          );
        }
      }
      await _requireRecentSession(user);
      _requireUser();
      await user.updatePassword(password);
      _googleVerified = false;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login' ||
          error.code == 'user-token-expired' ||
          error.code == 'invalid-user-token') {
        _googleVerified = false;
      }
      throw PasswordFailure(passwordErrorMessage(error));
    } finally {
      _busy = false;
    }
  }

  Future<void> _requireRecentSession(User user) async {
    _requireUser();
    final token = await user.getIdTokenResult(true);
    _requireUser();
    final time = token.authTime;
    if (time == null ||
        DateTime.now().difference(time) > const Duration(minutes: 5)) {
      _googleVerified = false;
      throw const PasswordFailure(
        'Please verify your identity again before saving.',
      );
    }
  }
}

String passwordErrorMessage(Object error) {
  if (error is PasswordFailure) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' =>
        'Your current password is incorrect. Please try again.',
      'user-mismatch' => 'Identity verification did not match your account.',
      'requires-recent-login' || 'user-token-expired' || 'invalid-user-token' =>
        'Please verify your identity again before saving.',
      'weak-password' ||
      'password-does-not-meet-requirements' ||
      'invalid-password' =>
        'Your password does not meet the required security rules.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'user-disabled' => 'This account has been disabled. Contact support.',
      'user-not-found' => 'Your session is no longer available. Sign in again.',
      'operation-not-allowed' ||
      'invalid-api-key' ||
      'app-not-authorized' ||
      'unauthorized-domain' ||
      'invalid-oauth-client-id' =>
        'Account verification is not configured for this app. Contact support.',
      'popup-blocked' => 'Allow sign-in popups in your browser and try again.',
      'account-exists-with-different-credential' ||
      'credential-already-in-use' ||
      'provider-already-linked' ||
      'email-already-in-use' => 'This verification method belongs to a different account. Accounts were not linked.',
      _ => 'Could not update your password. Please try again.',
    };
  }
  return 'Could not update your password. Please try again.';
}
