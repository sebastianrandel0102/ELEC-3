import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'password_service.dart';
import 'password_recovery_service.dart';

class GoogleSignInFailure implements Exception {
  const GoogleSignInFailure(this.message);
  final String message;
}

/// Adds Google authentication to the existing Firebase session and user schema.
/// Firebase is initialized only by main(); dependencies are resolved on demand.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    this.isWeb = kIsWeb,
    TargetPlatform? platform,
  }) : _authOverride = auth,
       _firestoreOverride = firestore,
       _googleOverride = googleSignIn,
       _platformOverride = platform;

  static final instance = AuthService();
  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final GoogleSignIn? _googleOverride;
  final TargetPlatform? _platformOverride;
  final bool isWeb;
  final _googleSignInInProgress = ValueNotifier(false);
  Future<void>? _initialization;
  bool _googleInitialized = false;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  GoogleSignIn get _google => _googleOverride ?? GoogleSignIn.instance;
  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  ValueListenable<bool> get googleSignInInProgress => _googleSignInInProgress;
  bool get supportsGoogleSignIn =>
      isWeb ||
      switch (_platform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  PasswordChangeSession passwordChangeSession() => PasswordChangeSession(
    auth: _auth,
    reauthenticateGoogle: _reauthenticateGoogle,
    supportsGoogle: supportsGoogleSignIn,
  );

  /// Uses this app's existing Auth instance and Firebase's hosted email handler.
  /// Request completion is not evidence of delivery or a changed password.
  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim();
    final validation = validateRecoveryEmail(normalizedEmail);
    if (validation != null) {
      throw PasswordRecoveryFailure(validation, invalidEmail: true);
    }
    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      final code = error.code.replaceFirst(RegExp(r'^auth/'), '');
      // Older SDK/project configurations can reveal a nonexistent account.
      // Keep the same neutral confirmation as enumeration-protected projects.
      if (code == 'user-not-found') return;
      if (kDebugMode) debugPrint('Password recovery failed: $code');
      throw PasswordRecoveryFailure(
        passwordRecoveryErrorMessage(error),
        invalidEmail: code == 'invalid-email' || code == 'missing-email',
        rateLimited: code == 'too-many-requests' || code == 'quota-exceeded',
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Password recovery failed: ${error.runtimeType}');
      }
      throw const PasswordRecoveryFailure(
        'Password recovery is temporarily unavailable. Please try again later.',
      );
    }
  }

  Future<bool> _reauthenticateGoogle(User user) async {
    if (_auth.currentUser?.uid != user.uid ||
        !user.providerData.any((p) => p.providerId == 'google.com')) {
      throw const PasswordFailure(
        'Identity verification did not match your account.',
      );
    }
    try {
      final UserCredential result;
      if (isWeb) {
        result = await user.reauthenticateWithPopup(
          GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'}),
        );
      } else {
        await _initializeGoogle();
        if (!_google.supportsAuthenticate()) {
          throw const PasswordFailure(
            'Google verification is unavailable on this device.',
          );
        }
        final account = await _google.authenticate();
        final token = account.authentication.idToken;
        if (token == null || token.isEmpty) {
          throw const PasswordFailure(
            'Google could not verify your identity. Try again.',
          );
        }
        result = await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(idToken: token),
        );
      }
      if (result.user?.uid != user.uid || _auth.currentUser?.uid != user.uid) {
        throw const PasswordFailure(
          'Identity verification did not match your account.',
        );
      }
      return true;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return false;
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const PasswordFailure(
          'Google verification is not configured. Use your current password or contact support.',
        );
      }
      throw PasswordFailure(_messageFor(error));
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request' ||
          error.code == 'web-context-cancelled') {
        return false;
      }
      if (error.code == 'invalid-credential' ||
          error.code == 'invalid-id-token') {
        throw const PasswordFailure(
          'Google could not verify your identity. Please try again.',
        );
      }
      throw PasswordFailure(passwordErrorMessage(error));
    }
  }

  Future<void> _initializeGoogle() async {
    // Cache even a failed initialization: the package requires exactly one
    // initialize() call per instance. Configuration changes require a restart.
    _initialization ??= _google.initialize();
    await _initialization;
    _googleInitialized = true;
  }

  /// Returns null for cancellation or a duplicate request. No account linking
  /// or email-based profile lookup is performed by this application.
  Future<User?> signInWithGoogle() async {
    if (_googleSignInInProgress.value) return null;
    _googleSignInInProgress.value = true;
    User? signedInUser;
    try {
      if (!supportsGoogleSignIn) {
        throw const GoogleSignInFailure(
          'Google sign-in is unavailable on this platform. Use email and password.',
        );
      }

      final UserCredential result;
      if (isWeb) {
        // Invoke directly from the button gesture, before any asynchronous work,
        // so browsers permit the popup. Firebase handles the OAuth exchange.
        result = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        await _initializeGoogle();
        if (!_google.supportsAuthenticate()) {
          throw const GoogleSignInFailure(
            'Google sign-in is unavailable. Use email and password.',
          );
        }
        final account = await _google.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const GoogleSignInFailure(
            'Google could not verify your account. Please try again.',
          );
        }
        result = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      signedInUser = result.user;
      if (signedInUser == null) {
        throw const GoogleSignInFailure(
          'Google could not verify your account. Please try again.',
        );
      }
      await _ensureGoogleProfile(signedInUser);
      return signedInUser;
    } catch (error) {
      // Keep AuthGate on the login screen until profile setup or rollback ends.
      // Never delete the Firebase account or modify existing app records.
      if (signedInUser != null && _auth.currentUser?.uid == signedInUser.uid) {
        await _auth.signOut();
      }
      await _clearGoogleSession();
      if (error is GoogleSignInException &&
          error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      if (error is FirebaseAuthException &&
          (error.code == 'popup-closed-by-user' ||
              error.code == 'cancelled-popup-request' ||
              error.code == 'web-context-cancelled')) {
        return null;
      }
      throw GoogleSignInFailure(_messageFor(error));
    } finally {
      _googleSignInInProgress.value = false;
    }
  }

  Future<void> _ensureGoogleProfile(User user) async {
    final reference = _firestore.collection('users').doc(user.uid);
    // A transaction protects a concurrently created/edited profile as well as
    // repeated logins. The fields match existing email registration exactly.
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        transaction.set(reference, {
          'displayName': user.displayName ?? user.email ?? 'SaveTrack user',
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'currency': 'PHP',
        });
      }
    });
  }

  Future<void> signOut() async {
    // Firebase logout remains authoritative. Google cleanup cannot prevent it.
    final wasGoogleUser =
        _auth.currentUser?.providerData.any(
          (provider) => provider.providerId == GoogleAuthProvider.PROVIDER_ID,
        ) ??
        false;
    await _auth.signOut();
    // A restored Firebase session may have been signed in on an earlier launch.
    if (wasGoogleUser &&
        !isWeb &&
        supportsGoogleSignIn &&
        !_googleInitialized) {
      try {
        await _initializeGoogle();
      } catch (_) {
        debugPrint(
          'Google sign-out initialization failed. Firebase signed out.',
        );
      }
    }
    await _clearGoogleSession();
  }

  Future<void> _clearGoogleSession() async {
    if (isWeb || !_googleInitialized) return;
    try {
      await _google.signOut();
    } catch (_) {
      debugPrint(
        'Google sign-out cleanup failed. Firebase session is separate.',
      );
    }
  }

  String _messageFor(Object error) {
    if (error is GoogleSignInFailure) return error.message;
    if (error is GoogleSignInException) {
      debugPrint('Google authentication failed: ${error.code.name}');
      return switch (error.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError => 'Google sign-in is not configured yet. Please use email and password.',
        GoogleSignInExceptionCode.interrupted ||
        GoogleSignInExceptionCode.uiUnavailable =>
          'Google sign-in was interrupted. Please try again.',
        _ =>
          'Could not sign in with Google. Check your connection and try again.',
      };
    }
    if (error is FirebaseAuthException) {
      debugPrint('Firebase Google authentication failed: ${error.code}');
      return switch (error.code) {
        'account-exists-with-different-credential' ||
        'credential-already-in-use' ||
        'email-already-in-use' => 'This account uses another sign-in method. Sign in with that method first. Account linking is not available in SaveTrack yet.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        'operation-not-allowed' ||
        'invalid-oauth-client-id' ||
        'unauthorized-domain' ||
        'invalid-api-key' ||
        'app-not-authorized' => 'Google sign-in is not configured yet. Please use email and password.',
        'popup-blocked' =>
          'Allow sign-in popups in your browser and try again.',
        'user-disabled' => 'This account has been disabled. Contact support.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'invalid-credential' || 'invalid-id-token' =>
          'Google could not verify your account. Please try again.',
        _ => 'Could not sign in with Google. Please try again.',
      };
    }
    if (error is FirebaseException) {
      debugPrint('Google profile setup failed: ${error.code}');
      return error.code == 'unavailable' || error.code == 'deadline-exceeded'
          ? 'Check your internet connection and try again.'
          : 'Could not load your SaveTrack profile. Please try again.';
    }
    // Never print exception payloads, which can include provider credentials.
    debugPrint('Unexpected Google sign-in failure: ${error.runtimeType}');
    return 'Could not sign in with Google. Please try again.';
  }
}
