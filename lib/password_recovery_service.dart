import 'package:firebase_auth/firebase_auth.dart';

class PasswordRecoveryFailure implements Exception {
  const PasswordRecoveryFailure(
    this.message, {
    this.invalidEmail = false,
    this.rateLimited = false,
  });
  final String message;
  final bool invalidEmail;
  final bool rateLimited;
}

String? validateRecoveryEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Please enter your email address.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Please enter a valid email address.';
  }
  return null;
}

String passwordRecoveryErrorMessage(
  FirebaseAuthException error,
) => switch (error.code.replaceFirst(RegExp(r'^auth/'), '')) {
  'invalid-email' || 'missing-email' => 'Please enter a valid email address.',
  'network-request-failed' =>
    'Unable to connect. Please check your internet connection.',
  'too-many-requests' ||
  'quota-exceeded' => 'Too many requests. Please wait before trying again.',
  // Includes provider, initialization, API-key and email-action configuration
  // failures. Do not expose Firebase's raw message or account information.
  _ => 'Password recovery is temporarily unavailable. Please try again later.',
};
