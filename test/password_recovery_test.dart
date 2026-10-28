import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/auth_service.dart';
import 'package:myproject/main.dart';
import 'package:myproject/password_dialog.dart';
import 'package:myproject/password_recovery_dialog.dart';
import 'package:myproject/password_recovery_service.dart';

// No account/session/provider/Firestore APIs are stubbed: using any of them
// during recovery fails the test. Only the official email operation is allowed.
class ResetAuth extends Fake implements FirebaseAuth {
  final emails = <String>[];
  Object? failure;
  Completer<void>? pending;

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    emails.add(email);
    expect(actionCodeSettings, isNull);
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
  }
}

void main() {
  late ResetAuth auth;
  late AuthService service;

  setUp(() {
    auth = ResetAuth();
    service = AuthService(auth: auth);
  });

  test(
    'required and reasonable email validation rejects malformed input',
    () async {
      for (final email in [
        '',
        '  ',
        'person',
        'a@@example.com',
        'a b@example.com',
        'a@example',
      ]) {
        await expectLater(
          service.sendPasswordResetEmail(email),
          throwsA(isA<PasswordRecoveryFailure>()),
        );
      }
      expect(auth.emails, isEmpty);
      expect(validateRecoveryEmail('name+tag@sub.example.travel'), isNull);
    },
  );

  test(
    'official Firebase reset method uses trimmed email and is awaited',
    () async {
      auth.pending = Completer<void>();
      var completed = false;
      final request = service
          .sendPasswordResetEmail('  Person+tag@example.com  ')
          .then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(auth.emails, ['Person+tag@example.com']);
      expect(completed, isFalse);
      auth.pending!.complete();
      await request;
      expect(completed, isTrue);
    },
  );

  for (final code in ['user-not-found', 'auth/user-not-found']) {
    test(
      '$code uses neutral confirmation without exposing account existence',
      () async {
        auth.failure = FirebaseAuthException(code: code);
        await service.sendPasswordResetEmail('unknown@example.com');
        expect(auth.emails, hasLength(1));
      },
    );
  }

  for (final entry in {
    'invalid-email': 'Please enter a valid email address.',
    'auth/invalid-email': 'Please enter a valid email address.',
    'network-request-failed':
        'Unable to connect. Please check your internet connection.',
    'too-many-requests': 'Too many requests. Please wait before trying again.',
    'operation-not-allowed':
        'Password recovery is temporarily unavailable. Please try again later.',
    'invalid-continue-uri':
        'Password recovery is temporarily unavailable. Please try again later.',
    'unauthorized-continue-uri':
        'Password recovery is temporarily unavailable. Please try again later.',
    'invalid-api-key':
        'Password recovery is temporarily unavailable. Please try again later.',
    'internal-error':
        'Password recovery is temporarily unavailable. Please try again later.',
  }.entries) {
    test('${entry.key} gives a safe error message', () async {
      auth.failure = FirebaseAuthException(
        code: entry.key,
        message: 'private payload',
      );
      await expectLater(
        service.sendPasswordResetEmail('person@example.com'),
        throwsA(
          isA<PasswordRecoveryFailure>().having(
            (e) => e.message,
            'message',
            entry.value,
          ),
        ),
      );
    });
  }

  test(
    'initialization and unexpected failures do not expose payloads',
    () async {
      for (final error in [
        FirebaseException(
          plugin: 'core',
          code: 'no-app',
          message: 'private payload',
        ),
        StateError('private payload'),
      ]) {
        auth.failure = error;
        await expectLater(
          service.sendPasswordResetEmail('person@example.com'),
          throwsA(
            isA<PasswordRecoveryFailure>().having(
              (e) => e.message,
              'message',
              'Password recovery is temporarily unavailable. Please try again later.',
            ),
          ),
        );
      }
    },
  );

  final emailField = find.byKey(const ValueKey('recovery-email'));
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double keyboard = 0,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SaveTrackDesign.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showPasswordRecoveryDialog(context, authService: service),
              child: const Text('Open recovery'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open recovery'));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Send Reset Link'));
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
  }

  testWidgets(
    'login opens recovery and pre-fills email without login validation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SaveTrackDesign.theme,
          home: AuthScreen(authService: service),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        ' person@example.com ',
      );
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(emailField).controller!.text,
        'person@example.com',
      );
      await tester.ensureVisible(find.text('Back to Login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordRecoveryDialog), findsNothing);
      expect(find.text('Welcome back, my love'), findsOneWidget);
      expect(auth.emails, isEmpty);
    },
  );

  testWidgets(
    'empty and invalid emails show field validation without Firebase requests',
    (tester) async {
      await mount(tester);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: emailField, matching: find.byType(TextField)),
            )
            .keyboardType,
        TextInputType.emailAddress,
      );
      await send(tester);
      expect(find.text('Please enter your email address.'), findsOneWidget);
      await tester.enterText(emailField, 'invalid');
      await send(tester);
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(auth.emails, isEmpty);
    },
  );

  testWidgets(
    'awaits Firebase, blocks duplicate taps and keyboard submissions, then confirms',
    (tester) async {
      auth.pending = Completer<void>();
      await mount(tester);
      await tester.enterText(emailField, '  person@example.com  ');
      await send(tester);
      expect(auth.emails, ['person@example.com']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Check Your Email'), findsNothing);
      expect(
        tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
        isNull,
      );
      expect(tester.widget<TextFormField>(emailField).enabled, isFalse);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Back to Login'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isFalse,
      );
      await tester.tap(find.byType(GradientButton));
      tester
          .widget<TextField>(
            find.descendant(of: emailField, matching: find.byType(TextField)),
          )
          .onSubmitted!('person@example.com');
      await tester.pump();
      expect(auth.emails, hasLength(1));
      auth.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Check Your Email'), findsOneWidget);
      expect(
        find.textContaining('If this email address is associated'),
        findsOneWidget,
      );
      expect(find.text('Password Changed'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordRecoveryDialog), findsNothing);
    },
  );

  testWidgets('resend waits for UI cooldown and reuses the validated email', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(emailField, 'person@example.com');
    await send(tester);
    await tester.pumpAndSettle();
    expect(
      tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
      isNotNull,
    );
    auth.failure = FirebaseAuthException(code: 'too-many-requests');
    await tester.tap(find.text('Resend Link'));
    await tester.pumpAndSettle();
    expect(auth.emails, ['person@example.com', 'person@example.com']);
    expect(
      find.text('Too many requests. Please wait before trying again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
  });

  testWidgets('network error preserves input and retry succeeds', (
    tester,
  ) async {
    auth.failure = FirebaseAuthException(code: 'network-request-failed');
    await mount(tester);
    await tester.enterText(emailField, 'person@example.com');
    await send(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to connect. Please check your internet connection.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(emailField).controller!.text,
      'person@example.com',
    );
    expect(find.text('Check Your Email'), findsNothing);
    auth.failure = null;
    await send(tester);
    await tester.pumpAndSettle();
    expect(find.text('Check Your Email'), findsOneWidget);
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Firebase invalid-email error is field-specific and can be corrected',
    (tester) async {
      auth.failure = FirebaseAuthException(code: 'invalid-email');
      await mount(tester);
      await tester.enterText(emailField, 'person@example.com');
      await send(tester);
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      auth.failure = null;
      await tester.enterText(emailField, 'correct@example.com');
      await send(tester);
      await tester.pumpAndSettle();
      expect(auth.emails.last, 'correct@example.com');
      expect(find.text('Check Your Email'), findsOneWidget);
      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();
    },
  );

  for (final size in [const Size(320, 568), const Size(1280, 800)]) {
    testWidgets('recovery at $size handles keyboard and large text', (
      tester,
    ) async {
      await mount(tester, size: size, keyboard: 260, textScale: 2);
      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'person@example.com');
      await send(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Back to Login'));
      expect(find.text('Back to Login').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();
    });
  }
}
