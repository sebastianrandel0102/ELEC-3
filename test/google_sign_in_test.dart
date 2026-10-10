// Firestore's sealed interfaces are implemented only for isolated SDK doubles.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myproject/auth_service.dart';
import 'package:myproject/main.dart';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'firebase-uid';
  @override
  String? get displayName => 'Google user';
  @override
  String? get email => 'person@example.com';
  @override
  List<UserInfo> get providerData => [FakeGoogleProviderInfo()];
}

class FakeGoogleProviderInfo extends Fake implements UserInfo {
  @override
  String get providerId => 'google.com';
}

class FakeCredential extends Fake implements UserCredential {
  FakeCredential(this.user);
  @override
  final User? user;
}

class FakeAuth extends Fake implements FirebaseAuth {
  User? session;
  AuthCredential? receivedCredential;
  AuthProvider? receivedProvider;
  Object? failure;
  int signInCalls = 0;
  int signOutCalls = 0;
  @override
  User? get currentUser => session;

  Future<UserCredential> complete() async {
    signInCalls++;
    if (failure != null) throw failure!;
    session = FakeUser();
    return FakeCredential(session);
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) {
    receivedCredential = credential;
    return complete();
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) {
    receivedProvider = provider;
    return complete();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    session = null;
  }
}

class FakeGoogleAccount extends Fake implements GoogleSignInAccount {
  FakeGoogleAccount(this.token);
  final String? token;
  @override
  GoogleSignInAuthentication get authentication =>
      GoogleSignInAuthentication(idToken: token);
}

class FakeGoogle extends Fake implements GoogleSignIn {
  int initializeCalls = 0;
  int authenticateCalls = 0;
  int signOutCalls = 0;
  String? token = 'test-id-token';
  Object? failure;
  Object? initializationFailure;
  Object? cleanupFailure;
  Completer<GoogleSignInAccount>? pending;
  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializeCalls++;
    if (initializationFailure != null) throw initializationFailure!;
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const [],
  }) async {
    authenticateCalls++;
    if (failure != null) throw failure!;
    return pending == null ? FakeGoogleAccount(token) : pending!.future;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (cleanupFailure != null) throw cleanupFailure!;
  }
}

class FakeProfileReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  FakeProfileReference(this.owner);
  final FakeFirestore owner;
}

class FakeProfiles extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  FakeProfiles(this.owner);
  final FakeFirestore owner;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    owner.requestedUid = path;
    return FakeProfileReference(owner);
  }
}

class FakeProfileSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  FakeProfileSnapshot(this.exists);
  @override
  final bool exists;
}

class FakeProfileTransaction extends Fake implements Transaction {
  FakeProfileTransaction(this.owner);
  final FakeFirestore owner;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    return FakeProfileSnapshot(owner.profile != null) as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    owner.writes++;
    owner.profile = Map<String, dynamic>.from(data as Map);
    return this;
  }
}

class FakeFirestore extends Fake implements FirebaseFirestore {
  Map<String, dynamic>? profile;
  String? requestedCollection;
  String? requestedUid;
  int writes = 0;
  Object? failure;
  Completer<void>? pending;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    requestedCollection = path;
    return FakeProfiles(this);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    return transactionHandler(FakeProfileTransaction(this));
  }
}

void main() {
  late FakeAuth auth;
  late FakeGoogle google;
  late FakeFirestore firestore;
  late AuthService service;

  setUp(() {
    auth = FakeAuth();
    google = FakeGoogle();
    firestore = FakeFirestore();
    service = AuthService(
      auth: auth,
      firestore: firestore,
      googleSignIn: google,
      platform: TargetPlatform.android,
    );
  });

  test(
    'native flow exchanges ID token and creates only the existing UID profile',
    () async {
      final user = await service.signInWithGoogle();
      expect(user, same(auth.currentUser));
      expect(google.initializeCalls, 1);
      expect(google.authenticateCalls, 1);
      final credential = auth.receivedCredential! as OAuthCredential;
      expect(credential.providerId, 'google.com');
      expect(credential.idToken, 'test-id-token');
      expect(firestore.requestedCollection, 'users');
      expect(firestore.requestedUid, 'firebase-uid');
      expect(firestore.profile!.keys.toSet(), {
        'displayName',
        'email',
        'createdAt',
        'currency',
      });
      expect(firestore.profile!['displayName'], 'Google user');
      expect(firestore.profile!['email'], 'person@example.com');
      expect(firestore.profile!['currency'], 'PHP');
      expect(firestore.profile!['createdAt'], isA<FieldValue>());
      expect(service.googleSignInInProgress.value, isFalse);
    },
  );

  test(
    'repeated logins preserve existing profile and initialize once',
    () async {
      final existing = {
        'displayName': 'Existing name',
        'currency': 'USD',
        'custom': true,
      };
      firestore.profile = existing;
      await service.signInWithGoogle();
      await service.signOut();
      await service.signInWithGoogle();
      expect(firestore.profile, same(existing));
      expect(firestore.writes, 0);
      expect(google.initializeCalls, 1);
    },
  );

  test(
    'a first-time profile is written only once across subsequent logins',
    () async {
      await service.signInWithGoogle();
      final original = firestore.profile;
      await service.signOut();
      await service.signInWithGoogle();
      expect(firestore.writes, 1);
      expect(firestore.profile, same(original));
    },
  );

  test(
    'native cancellation is silent, resets busy, and allows retry',
    () async {
      google.failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      expect(await service.signInWithGoogle(), isNull);
      expect(auth.signInCalls, 0);
      expect(firestore.writes, 0);
      expect(google.signOutCalls, 1);
      expect(service.googleSignInInProgress.value, isFalse);
      google.failure = null;
      expect(await service.signInWithGoogle(), isNotNull);
    },
  );

  test('duplicate requests never start a second account picker', () async {
    google.pending = Completer<GoogleSignInAccount>();
    final first = service.signInWithGoogle();
    await Future<void>.delayed(Duration.zero);
    expect(service.googleSignInInProgress.value, isTrue);
    expect(await service.signInWithGoogle(), isNull);
    expect(google.authenticateCalls, 1);
    google.pending!.complete(FakeGoogleAccount(google.token));
    await first;
    expect(auth.signInCalls, 1);
  });

  test(
    'busy remains true while the authenticated UID profile is prepared',
    () async {
      firestore.pending = Completer<void>();
      final request = service.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);
      expect(auth.currentUser, isNotNull);
      expect(service.googleSignInInProgress.value, isTrue);
      expect(firestore.writes, 0);
      firestore.pending!.complete();
      await request;
      expect(service.googleSignInInProgress.value, isFalse);
    },
  );

  test(
    'profile failure rolls back session without writing or deleting records',
    () async {
      firestore.failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await expectLater(
        service.signInWithGoogle(),
        throwsA(
          isA<GoogleSignInFailure>().having(
            (e) => e.message,
            'message',
            contains('profile'),
          ),
        ),
      );
      expect(auth.currentUser, isNull);
      expect(auth.signOutCalls, 1);
      expect(google.signOutCalls, 1);
      expect(firestore.writes, 0);
      expect(service.googleSignInInProgress.value, isFalse);
    },
  );

  for (final token in <String?>[null, '']) {
    test(
      'missing or empty ID token never signs in to Firebase ($token)',
      () async {
        google.token = token;
        await expectLater(
          service.signInWithGoogle(),
          throwsA(isA<GoogleSignInFailure>()),
        );
        expect(auth.signInCalls, 0);
        expect(firestore.writes, 0);
        expect(google.signOutCalls, 1);
      },
    );
  }

  for (final entry in {
    'network-request-failed': 'internet connection',
    'operation-not-allowed': 'not configured',
    'account-exists-with-different-credential': 'another sign-in method',
    'credential-already-in-use': 'another sign-in method',
    'invalid-credential': 'verify your account',
  }.entries) {
    test(
      'Firebase ${entry.key} has safe feedback without profile writes',
      () async {
        auth.failure = FirebaseAuthException(
          code: entry.key,
          message: 'sensitive provider detail',
        );
        await expectLater(
          service.signInWithGoogle(),
          throwsA(
            isA<GoogleSignInFailure>()
                .having((e) => e.message, 'message', contains(entry.value))
                .having(
                  (e) => e.message,
                  'safe message',
                  isNot(contains('sensitive')),
                ),
          ),
        );
        expect(firestore.writes, 0);
        expect(google.signOutCalls, 1);
        expect(service.googleSignInInProgress.value, isFalse);
      },
    );
  }

  test(
    'configuration failure is safe and initialization is never repeated',
    () async {
      google.initializationFailure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'private diagnostic',
      );
      for (var i = 0; i < 2; i++) {
        await expectLater(
          service.signInWithGoogle(),
          throwsA(
            isA<GoogleSignInFailure>().having(
              (e) => e.message,
              'message',
              contains('not configured'),
            ),
          ),
        );
      }
      expect(google.initializeCalls, 1);
      expect(auth.signInCalls, 0);
    },
  );

  test('unexpected errors are reported with safe feedback', () async {
    google.failure = StateError('sensitive detail');
    await expectLater(
      service.signInWithGoogle(),
      throwsA(
        isA<GoogleSignInFailure>().having(
          (e) => e.message,
          'message',
          'Could not sign in with Google. Please try again.',
        ),
      ),
    );
    expect(service.googleSignInInProgress.value, isFalse);
  });

  test(
    'web uses Firebase popup directly without the native Google API',
    () async {
      final web = AuthService(
        auth: auth,
        firestore: firestore,
        googleSignIn: google,
        isWeb: true,
      );
      final request = web.signInWithGoogle();
      expect(auth.receivedProvider, isA<GoogleAuthProvider>());
      await request;
      expect(google.initializeCalls, 0);
      expect(google.authenticateCalls, 0);
      expect(auth.currentUser, isNotNull);
      expect(firestore.writes, 1);
      await web.signOut();
      expect(auth.currentUser, isNull);
      expect(google.signOutCalls, 0);
    },
  );

  test('web popup cancellation is silent and restores state', () async {
    auth.failure = FirebaseAuthException(code: 'popup-closed-by-user');
    final web = AuthService(auth: auth, firestore: firestore, isWeb: true);
    expect(await web.signInWithGoogle(), isNull);
    expect(web.googleSignInInProgress.value, isFalse);
    expect(firestore.writes, 0);
  });

  test(
    'logout clears a restored Google session on a fresh app launch',
    () async {
      auth.session = FakeUser();
      await service.signOut();
      expect(auth.currentUser, isNull);
      expect(auth.signOutCalls, 1);
      expect(google.initializeCalls, 1);
      expect(google.signOutCalls, 1);
    },
  );

  test('Google cleanup failure cannot prevent Firebase logout', () async {
    await service.signInWithGoogle();
    google.cleanupFailure = StateError('cleanup failure');
    await service.signOut();
    expect(auth.currentUser, isNull);
    expect(auth.signOutCalls, 1);
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double keyboard = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SaveTrackDesign.theme,
        home: AuthScreen(authService: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  final googleButton = find.byKey(const ValueKey('google-sign-in'));

  testWidgets(
    'login retains email, password, recovery, registration and branded Google button',
    (tester) async {
      await mount(tester);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('New to SaveTrack? Create an account'), findsOneWidget);
      expect(find.text('OR'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      final logo = tester.widget<Image>(
        find.descendant(of: googleButton, matching: find.byType(Image)),
      );
      expect(
        (logo.image as AssetImage).assetName,
        'assets/branding/google_g.png',
      );
      final button = tester.widget<OutlinedButton>(googleButton);
      expect(button.style!.backgroundColor!.resolve({}), Colors.white);
      expect(button.style!.shape!.resolve({}), isA<RoundedRectangleBorder>());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small screen with keyboard can scroll to Google and registration',
    (tester) async {
      await mount(tester, size: const Size(320, 568), keyboard: 260);
      await tester.ensureVisible(googleButton);
      await tester.pumpAndSettle();
      expect(googleButton.hitTestable(), findsOneWidget);
      await tester.ensureVisible(
        find.text('New to SaveTrack? Create an account'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('New to SaveTrack? Create an account').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Google loading blocks duplicate taps and cancellation restores controls',
    (tester) async {
      google.pending = Completer<GoogleSignInAccount>();
      await mount(tester);
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pump();
      expect(google.authenticateCalls, 1);
      expect(tester.widget<OutlinedButton>(googleButton).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final emailLogin = tester.widget<GradientButton>(
        find.byType(GradientButton),
      );
      expect(emailLogin.onPressed, isNull);
      google.pending!.completeError(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(googleButton).onPressed, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ErrorPanel), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );

  testWidgets('Google errors render safely through the existing ErrorPanel', (
    tester,
  ) async {
    auth.failure = FirebaseAuthException(code: 'network-request-failed');
    await mount(tester);
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.byType(ErrorPanel), findsOneWidget);
    expect(tester.widget<OutlinedButton>(googleButton).onPressed, isNotNull);
  });

  testWidgets(
    'existing login validation, recovery validation and registration remain available',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(find.text('Use at least 6 characters.'), findsOneWidget);
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email address first.'), findsOneWidget);
      await tester.ensureVisible(
        find.text('New to SaveTrack? Create an account'),
      );
      await tester.tap(find.text('New to SaveTrack? Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Your name'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
      expect(googleButton, findsNothing);
    },
  );
}
