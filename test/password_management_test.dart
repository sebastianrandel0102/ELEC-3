import 'dart:async';

import 'ui_preview_fonts.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myproject/auth_service.dart';
import 'package:myproject/design_system.dart';
import 'package:myproject/password_dialog.dart';
import 'package:myproject/password_service.dart';
import 'package:myproject/password_recovery_dialog.dart';

class ProviderInfo extends Fake implements UserInfo {
  ProviderInfo(this.providerId);
  @override
  final String providerId;
}

class CredentialResult extends Fake implements UserCredential {
  CredentialResult(this.user);
  @override
  final User? user;
}

class TokenResult extends Fake implements IdTokenResult {
  TokenResult(this.authTime);
  @override
  final DateTime? authTime;
}

class RecoveryGoogleAccount extends Fake implements GoogleSignInAccount {
  @override
  GoogleSignInAuthentication get authentication =>
      const GoogleSignInAuthentication(idToken: 'verified-google-token');
}

class RecoveryGoogle extends Fake implements GoogleSignIn {
  Object? failure;
  int initializations = 0;
  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializations++;
  }

  @override
  bool supportsAuthenticate() => true;
  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const [],
  }) async {
    if (failure != null) throw failure!;
    return RecoveryGoogleAccount();
  }
}

class PasswordUser extends Fake implements User {
  PasswordUser({this.uid = 'original', this.providers = const ['password']});
  @override
  final String uid;
  List<String> providers;
  @override
  String? get email => 'owner@example.com';
  @override
  List<UserInfo> get providerData => providers.map(ProviderInfo.new).toList();
  AuthCredential? credential;
  AuthProvider? popupProvider;
  Object? reauthFailure, updateFailure;
  User? reauthResult;
  DateTime? authTime = DateTime.now();
  String? updatedPassword;
  int updates = 0, reauths = 0;
  Completer<void>? pendingUpdate;
  VoidCallback? onReauth, onToken;
  @override
  Future<void> reload() async {}
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential value,
  ) async {
    credential = value;
    return _reauth();
  }

  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider value) async {
    popupProvider = value;
    return _reauth();
  }

  Future<UserCredential> _reauth() async {
    reauths++;
    if (reauthFailure != null) throw reauthFailure!;
    onReauth?.call();
    return CredentialResult(reauthResult ?? this);
  }

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    onToken?.call();
    return TokenResult(authTime);
  }

  @override
  Future<void> updatePassword(String value) async {
    updates++;
    if (pendingUpdate != null) await pendingUpdate!.future;
    if (updateFailure != null) throw updateFailure!;
    updatedPassword = value;
  }
}

class PolicyStatus extends Fake implements PasswordValidationStatus {
  @override
  bool isValid = true;
  @override
  bool meetsMinPasswordLength = true;
  @override
  bool meetsMaxPasswordLength = true;
  @override
  bool meetsLowercaseRequirement = true;
  @override
  bool meetsUppercaseRequirement = true;
  @override
  bool meetsDigitsRequirement = true;
  @override
  bool meetsSymbolsRequirement = true;
}

class PasswordAuth extends Fake implements FirebaseAuth {
  PasswordAuth(this.currentUser);
  @override
  User? currentUser;
  Object? policyFailure;
  PasswordValidationStatus status = PolicyStatus();
  int policyChecks = 0;
  @override
  Future<PasswordValidationStatus> validatePassword(
    FirebaseAuth auth,
    String? password,
  ) async {
    policyChecks++;
    if (policyFailure != null) throw policyFailure!;
    return status;
  }
}

void main() {
  late PasswordUser user;
  late PasswordAuth auth;
  late PasswordChangeSession session;
  int googleVerifications = 0;

  setUpAll(() async {
    await loadManropeForPreviews();
    if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
    final config = jsonDecode(
      await File('.dart_tool/package_config.json').readAsString(),
    ) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((package) => package['name'] == 'flutter');
    final sdk = Uri.parse('${flutter['rootUri']}/').resolve('../../');
    for (final entry in {
      'Roboto': 'bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      'MaterialIcons':
          'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    }.entries) {
      final file = File.fromUri(sdk.resolve(entry.value));
      final loader = FontLoader(entry.key)
        ..addFont(
          file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });

  setUp(() {
    user = PasswordUser();
    auth = PasswordAuth(user);
    googleVerifications = 0;
    session = PasswordChangeSession(
      auth: auth,
      supportsGoogle: true,
      reauthenticateGoogle: (selected) async {
        googleVerifications++;
        return true;
      },
    );
  });

  Future<void> save({
    String password = 'NewSecret123!',
    String confirmation = 'NewSecret123!',
    String? current = 'current secret',
  }) => session.save(
    password: password,
    confirmation: confirmation,
    currentPassword: current,
  );
  Matcher failure(String text) => isA<PasswordFailure>().having(
    (e) => e.message,
    'message',
    contains(text),
  );

  test('unauthenticated callers cannot update an account', () async {
    auth.currentUser = null;
    await expectLater(save(), throwsA(failure('session changed')));
    expect(user.updates, 0);
    expect(auth.policyChecks, 0);
  });

  test(
    'validation rejects missing, weak, mismatched and unverified requests',
    () async {
      for (final attempt in [
        () => save(password: ''),
        () => save(password: 'short'),
        () => save(confirmation: ''),
        () => save(confirmation: 'different'),
        () => save(current: ''),
        () => save(current: null),
      ]) {
        await expectLater(attempt(), throwsA(isA<PasswordFailure>()));
      }
      expect(auth.policyChecks, 0);
      expect(user.reauths, 0);
      expect(user.updates, 0);
    },
  );

  test('configured policy prevents reauthentication and writes on invalid password', () async {
    auth.status = PolicyStatus()
      ..isValid = false
      ..meetsUppercaseRequirement = false;
    await expectLater(save(), throwsA(failure('an uppercase letter')));
    expect(user.reauths, 0);
    expect(user.updates, 0);
  });

  test('policy retrieval failure fails closed', () async {
    auth.policyFailure = Exception('unavailable');
    await expectLater(save(), throwsA(failure('Could not check')));
    expect(user.updates, 0);
  });

  test(
    'current password reauthenticates exact strings before Firebase update',
    () async {
      await save(
        password: ' new Secret 123! ',
        confirmation: ' new Secret 123! ',
        current: ' current secret ',
      );
      final credential = user.credential as EmailAuthCredential;
      expect(credential.email, user.email);
      expect(credential.password, ' current secret ');
      expect(user.updatedPassword, ' new Secret 123! ');
      expect(user.reauths, 1);
      expect(user.updates, 1);
    },
  );

  test('incorrect current password never updates Firebase', () async {
    user.reauthFailure = FirebaseAuthException(code: 'invalid-credential');
    await expectLater(
      save(),
      throwsA(failure('current password is incorrect')),
    );
    expect(user.updates, 0);
  });

  test('UID returned by reauthentication must match', () async {
    user.reauthResult = PasswordUser(uid: 'other');
    await expectLater(save(), throwsA(failure('did not match')));
    expect(user.updates, 0);
  });

  test('session changes during reauth or token refresh cannot update either account', () async {
    user.onReauth = () => auth.currentUser = PasswordUser(uid: 'other');
    await expectLater(save(), throwsA(failure('session changed')));
    expect(user.updates, 0);
    auth.currentUser = user;
    user.onReauth = null;
    user.onToken = () => auth.currentUser = null;
    await expectLater(save(), throwsA(failure('session changed')));
    expect(user.updates, 0);
  });

  test('stale or missing authenticated token time fails closed', () async {
    user.authTime = DateTime.now().subtract(const Duration(minutes: 6));
    await expectLater(save(), throwsA(failure('verify your identity again')));
    user.authTime = null;
    await expectLater(save(), throwsA(failure('verify your identity again')));
    expect(user.updates, 0);
  });

  test('Google verification is offered only for an existing linked password account', () async {
    expect(session.canVerifyGoogle, isFalse);
    await expectLater(
      session.verifyGoogle(),
      throwsA(failure('not available')),
    );
    expect(googleVerifications, 0);
    user.providers = ['google.com'];
    expect(session.canVerifyGoogle, isFalse);
    await expectLater(save(), throwsA(failure('does not have')));
    user.providers = ['password', 'google.com'];
    expect(session.canVerifyGoogle, isTrue);
    expect(await session.verifyGoogle(), isTrue);
    await save(current: null);
    expect(googleVerifications, 1);
    expect(user.reauths, 0);
    expect(user.updates, 1);
  });

  test('web linked Google uses user reauthentication, never Firebase sign-in or linking', () async {
    user.providers = ['password', 'google.com'];
    final service = AuthService(auth: auth, isWeb: true);
    session = service.passwordChangeSession();
    expect(await session.verifyGoogle(), isTrue);
    expect(user.popupProvider, isA<GoogleAuthProvider>());
    expect(user.reauths, 1);
    await save(current: null);
    expect(user.updates, 1);
  });

  test(
    'Google cancellation stays unverified and mismatched Google is rejected',
    () async {
      user.providers = ['password', 'google.com'];
      session = AuthService(auth: auth, isWeb: true).passwordChangeSession();
      user.reauthFailure = FirebaseAuthException(code: 'popup-closed-by-user');
      expect(await session.verifyGoogle(), isFalse);
      expect(session.googleVerified, isFalse);
      user.reauthFailure = FirebaseAuthException(code: 'user-mismatch');
      await expectLater(
        session.verifyGoogle(),
        throwsA(failure('did not match')),
      );
      expect(session.googleVerified, isFalse);
      expect(user.updates, 0);
    },
  );

  test(
    'native linked Google exchanges its token through reauthentication',
    () async {
      user.providers = ['password', 'google.com'];
      final google = RecoveryGoogle();
      session = AuthService(
        auth: auth,
        googleSignIn: google,
        isWeb: false,
        platform: TargetPlatform.android,
      ).passwordChangeSession();
      expect(await session.verifyGoogle(), isTrue);
      final credential = user.credential as OAuthCredential;
      expect(credential.providerId, 'google.com');
      expect(credential.idToken, 'verified-google-token');
      expect(google.initializations, 1);
      await save(current: null);
      expect(user.updates, 1);
    },
  );

  test(
    'native cancellation and missing configuration cannot unlock saving',
    () async {
      user.providers = ['password', 'google.com'];
      final google = RecoveryGoogle();
      session = AuthService(
        auth: auth,
        googleSignIn: google,
        isWeb: false,
        platform: TargetPlatform.android,
      ).passwordChangeSession();
      google.failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      expect(await session.verifyGoogle(), isFalse);
      google.failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      );
      await expectLater(
        session.verifyGoogle(),
        throwsA(failure('not configured')),
      );
      expect(session.googleVerified, isFalse);
      expect(user.reauths, 0);
      expect(user.updates, 0);
    },
  );

  test(
    'expired verified Google sessions return to identity verification',
    () async {
      user.providers = ['password', 'google.com'];
      expect(await session.verifyGoogle(), isTrue);
      user.updateFailure = FirebaseAuthException(code: 'user-token-expired');
      await expectLater(
        save(current: null),
        throwsA(failure('verify your identity again')),
      );
      expect(session.googleVerified, isFalse);
      expect(user.updatedPassword, isNull);
    },
  );

  test('duplicate saves cannot issue a second Firebase update', () async {
    user.pendingUpdate = Completer<void>();
    final pending = save();
    await Future<void>.delayed(Duration.zero);
    await expectLater(save(), throwsA(failure('already in progress')));
    expect(user.updates, 1);
    user.pendingUpdate!.complete();
    await pending;
  });

  test(
    'backend weak password, network and recent-login errors are specific',
    () async {
      for (final entry in {
        'weak-password': 'security rules',
        'network-request-failed': 'internet connection',
        'requires-recent-login': 'verify your identity again',
      }.entries) {
        user.updateFailure = FirebaseAuthException(code: entry.key);
        await expectLater(save(), throwsA(failure(entry.value)));
        expect(user.updatedPassword, isNull);
      }
    },
  );

  final previewKey = GlobalKey();
  Future<void> mount(
    WidgetTester tester, {
    bool recovery = false,
    Size size = const Size(390, 844),
    double keyboard = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: const bool.fromEnvironment('SAVE_UI_PREVIEWS')
            ? SaveTrackDesign.theme.copyWith(
                textTheme: SaveTrackDesign.theme.textTheme.apply(
                  fontFamily: 'Manrope',
                ),
              )
            : SaveTrackDesign.theme,
        builder: (context, child) =>
            RepaintBoundary(key: previewKey, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => recovery
                  ? showPasswordRecoveryDialog(context)
                  : showChangePasswordDialog(context, session),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    for (final entry in {
      'Current Password': 'current secret',
      'New Password': 'NewSecret123!',
      'Confirm New Password': 'NewSecret123!',
    }.entries) {
      await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
    }
    await tester.ensureVisible(find.text('Save New Password'));
  }

  testWidgets('login recovery requests email without asking for passwords', (
    tester,
  ) async {
    await mount(tester, recovery: true);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Send Reset Link'), findsOneWidget);
    expect(find.text('Save New Password'), findsNothing);
    expect(auth.policyChecks, 0);
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
    expect(find.byType(PasswordRecoveryDialog), findsNothing);
  });

  testWidgets(
    'change form hides all passwords and validates mismatch before Firebase',
    (tester) async {
      await mount(tester);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.obscureText, isTrue);
      }
      await fill(tester);
      await tester.enterText(
        find.byKey(const ValueKey('Confirm New Password')),
        'different',
      );
      await tester.tap(find.text('Save New Password'));
      await tester.pumpAndSettle();
      expect(find.text('Your passwords do not match.'), findsOneWidget);
      expect(user.updates, 0);
    },
  );

  testWidgets(
    'success waits for Firebase; loading blocks save, cancel and back',
    (tester) async {
      user.pendingUpdate = Completer<void>();
      await mount(tester);
      await fill(tester);
      await tester.tap(find.text('Save New Password'));
      await tester.pump();
      expect(find.text('Password Changed'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isFalse,
      );
      user.pendingUpdate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Password Changed'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordDialog), findsNothing);
    },
  );

  testWidgets('network failures preserve the form and allow retry', (
    tester,
  ) async {
    user.updateFailure = FirebaseAuthException(code: 'network-request-failed');
    await mount(tester);
    await fill(tester);
    await tester.tap(find.text('Save New Password'));
    await tester.pumpAndSettle();
    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('Password Changed'), findsNothing);
    user.updateFailure = null;
    await tester.tap(find.text('Save New Password'));
    await tester.pumpAndSettle();
    expect(find.text('Password Changed'), findsOneWidget);
  });

  testWidgets('Google-only management has no current-password demand', (
    tester,
  ) async {
    user.providers = ['google.com'];
    await mount(tester);
    expect(find.textContaining('Manage your Google password'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Save New Password'), findsNothing);
  });

  testWidgets(
    'verified linked Google transitions to new password without current password',
    (tester) async {
      user.providers = ['password', 'google.com'];
      await mount(tester);
      await tester.tap(find.text('Verify with linked Google'));
      await tester.pumpAndSettle();
      expect(find.text('Create New Password'), findsOneWidget);
      expect(find.byKey(const ValueKey('Current Password')), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(user.updates, 0);
    },
  );

  testWidgets('small-screen keyboard keeps actions scrollable', (tester) async {
    await mount(tester, size: const Size(320, 568), keyboard: 260);
    await tester.ensureVisible(find.text('Save New Password'));
    await tester.pumpAndSettle();
    expect(find.text('Save New Password').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password dialog preview', (tester) async {
    await mount(tester);
    if (const bool.fromEnvironment('SAVE_UI_PREVIEWS')) {
      await tester.runAsync(() async {
        final boundary =
            previewKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/ui-preview/change-password.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
  });
}
