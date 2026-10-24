import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'auth_service.dart';
import 'app_record_repository.dart';
import 'agent_studio/agent_screen.dart';
import 'ai_coach/ai_coach_screen.dart';
import 'ai_coach/ai_widgets.dart';
import 'ai_coach/firebase_ai_gateway.dart';
import 'currency_money.dart';
import 'currency_service.dart';
import 'currency_widgets.dart';
import 'currency_settings_screen.dart';
import 'currency_savings_dialog.dart';
import 'currency_transactions.dart';
import 'decrease_savings_dialog.dart';
import 'firebase_options.dart';
import 'goal_cover_service.dart';
import 'goal_cover_processing.dart';
import 'goal_cover_widgets.dart';
import 'password_dialog.dart';
import 'profile_photo_picker.dart';
import 'profile_photo_service.dart';
import 'profile_photo_widgets.dart';
import 'savings_decrease.dart';
import 'reminder_coordinator.dart';
import 'reminder_widgets.dart';
import 'shared_savings_screens.dart';
import 'shared_savings_repository.dart';
import 'smart_suggestions.dart';
import 'smart_task_recommendation_service.dart';
import 'home_widgets/widget_controller.dart';
import 'home_widgets/widget_host.dart';
import 'home_widgets/widget_models.dart';
import 'home_widgets/widget_settings_screen.dart';
import 'shared_savings_models.dart';

import 'design_system.dart';
import 'atelier_preferences.dart';
export 'design_system.dart';
part 'home_atelier.dart';
part 'precision_flows.dart';

final _appNavigator = GlobalKey<NavigatorState>();
final _homeShellKey = GlobalKey<_HomeShellState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AiAppCheck.initialize();
  } catch (error) {
    startupError = error;
  }

  runApp(SaveTrackApp(startupError: startupError));
}

class SaveTrackApp extends StatefulWidget {
  const SaveTrackApp({super.key, this.startupError});
  final Object? startupError;

  @override
  State<SaveTrackApp> createState() => _SaveTrackAppState();
}

class _SaveTrackAppState extends State<SaveTrackApp> {
  late Object? _startupError = widget.startupError;
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) {
      return;
    }
    setState(() => _retrying = true);
    Object? failure;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await AiAppCheck.initialize();
    } catch (error) {
      failure = error;
    }
    if (mounted) {
      setState(() {
        _startupError = failure;
        _retrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AtelierHost(
    child: ValueListenableBuilder<ThemeMode>(
      valueListenable: AtelierPreferences.themeMode,
      builder: (context, mode, _) => MaterialApp(
        navigatorKey: _appNavigator,
        title: 'SaveTrack',
        debugShowCheckedModeBanner: false,
        theme: SaveTrackDesign.theme,
        darkTheme: SaveTrackDesign.darkTheme,
        themeMode: mode,
        builder: _startupError == null
            ? (context, child) => HomeWidgetHost(
                openTarget: _openHomeWidgetTarget,
                child: ReminderHost(
                  openTarget: _openReminderTarget,
                  child: CurrencyHost(child: SharedSavingsHost(child: child!)),
                ),
              )
            : null,
        home: _startupError != null
            ? SetupScreen(
                error: _startupError!,
                onRetry: _retry,
                busy: _retrying,
              )
            : const AuthGate(),
      ),
    ),
  );
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({
    super.key,
    required this.error,
    this.onRetry,
    this.busy = false,
  });
  final Object error;
  final VoidCallback? onRetry;
  final bool busy;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageSurface(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(),
                const SizedBox(height: 28),
                Text(
                  'We could not connect to SaveTrack.',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.atelierInk,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your space is not available yet. Check your connection and try again.',
                  style: TextStyle(color: context.atelierMuted, height: 1.5),
                ),
                const SizedBox(height: 20),
                if (onRetry != null)
                  GradientButton(
                    onPressed: busy ? null : onRetry,
                    child: SaveActionLabel(
                      busy: busy,
                      label: 'Try again',
                      busyLabel: 'Connecting',
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'If this continues, the app connection may need to be configured. Reopen SaveTrack after setup is complete.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: SessionLoading());
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: PageSurface(
            child: ErrorPanel(
              message: 'Could not check your session: ${snapshot.error}',
            ),
          ),
        );
      }
      return ValueListenableBuilder<bool>(
        valueListenable: AuthService.instance.googleSignInInProgress,
        builder: (context, googleBusy, child) =>
            snapshot.data == null || googleBusy
            ? const AuthScreen()
            : GoalCoverSession(
                key: ValueKey(snapshot.data!.uid),
                uid: snapshot.data!.uid,
                child: AtelierHost(
                  key: ValueKey('atelier-${snapshot.data!.uid}'),
                  account: snapshot.data!.uid,
                  child: HomeShell(key: _homeShellKey),
                ),
              ),
      );
    },
  );
}

class SessionLoading extends StatelessWidget {
  const SessionLoading({super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: SaveTrackDesign.premium),
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: EnterOnce(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AuroraEmblem(size: 80, onDark: true, animate: true),
                const SizedBox(height: 24),
                Text(
                  'SaveTrack',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your goals, your progress.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SaveTrackDesign.onHeroMuted),
                ),
                const SizedBox(height: 32),
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: mint,
                    semanticsLabel: 'Checking your session',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.authService});
  final AuthService? authService;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false, _busy = false, _showPassword = false;
  bool _googleBusy = false;
  bool _recoveryOpen = false;
  String? _error;
  AuthService get _authService => widget.authService ?? AuthService.instance;

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _googleBusy = true;
      _error = null;
    });
    try {
      await _authService.signInWithGoogle();
      // AuthGate follows Firebase's session, after the profile is ready.
    } on GoogleSignInFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      debugPrint('Unexpected Google login error: ${error.runtimeType}');
      if (mounted) {
        setState(
          () => _error = 'Could not sign in with Google. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _googleBusy = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await credential.user!.updateDisplayName(_name.text.trim());
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
              'displayName': _name.text.trim(),
              'email': _email.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
              'currency': 'PHP',
            });
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = switch (e.code) {
          'email-already-in-use' => 'An account already exists for this email.',
          'invalid-credential' ||
          'wrong-password' ||
          'user-not-found' => 'Email or password is incorrect.',
          'weak-password' =>
            'Choose a stronger password (at least 6 characters).',
          'network-request-failed' =>
            'Check your internet connection and try again.',
          _ => e.message ?? 'Authentication failed. Please try again.',
        },
      );
    } catch (e) {
      setState(() => _error = 'Could not save your account: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy || _recoveryOpen) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _recoveryOpen = true;
      _error = null;
    });
    try {
      await showPasswordRecoveryDialog(
        context,
        authService: _authService,
        initialEmail: _email.text,
      );
    } finally {
      if (mounted) setState(() => _recoveryOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageSurface(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: SaveTrackDesign.pageInset(
                MediaQuery.sizeOf(context).width,
              ),
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: AuthComposition(
                brand: const BrandMark(),
                register: _register,
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _register ? 'Create your account' : 'Welcome back',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.6,
                          color: context.atelierInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _register
                            ? 'Start building a future you look forward to.'
                            : 'Continue building your goals, one day at a time.',
                        style: TextStyle(color: context.atelierMuted),
                      ),
                      const SizedBox(height: 26),
                      if (_register) ...[
                        TextFormField(
                          controller: _name,
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _email,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) =>
                            (v == null ||
                                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(v.trim()))
                            ? 'Enter a valid email.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        autofillHints: _register
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Use at least 6 characters.'
                            : null,
                      ),
                      if (!_register)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy || _recoveryOpen
                                ? null
                                : _resetPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ErrorPanel(message: _error!),
                        ),
                      const SizedBox(height: 8),
                      GradientButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy && !_googleBusy
                            ? SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.atelierAccent,
                                  semanticsLabel: _register
                                      ? 'Creating account'
                                      : 'Signing in',
                                ),
                              )
                            : Text(_register ? 'Create account' : 'Sign in'),
                      ),
                      if (!_register && _authService.supportsGoogleSignIn) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'OR',
                                  style: TextStyle(color: context.atelierMuted),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          key: const ValueKey('google-sign-in'),
                          onPressed: _busy ? null : _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1F1F1F),
                            disabledBackgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF747775)),
                            minimumSize: const Size.fromHeight(52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'GoogleSans',
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_googleBusy)
                                const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: teal,
                                    semanticsLabel: 'Signing in with Google',
                                  ),
                                )
                              else
                                Image.asset(
                                  'assets/branding/google_g.png',
                                  width: 20,
                                  height: 20,
                                  excludeFromSemantics: true,
                                ),
                              const SizedBox(width: 12),
                              const Flexible(
                                child: Text('Continue with Google'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _register = !_register;
                                _error = null;
                              }),
                        child: Text(
                          _register
                              ? 'Already have an account? Sign in'
                              : 'New to SaveTrack? Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _visited = <int>{0};
  String? _account;
  static const _titles = ['Today', 'Goals', 'Planner', 'Reports', 'Profile'];

  void selectTab(int index) {
    if (mounted) setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final account = FirebaseAuth.instance.currentUser!.uid;
    if (_account != account) {
      _account = account;
      _visited.clear();
      _index = 0;
    }
    _visited.add(_index);
    final pages = [
      HomeAtelier(
        key: ValueKey(FirebaseAuth.instance.currentUser!.uid),
        uid: FirebaseAuth.instance.currentUser!.uid,
      ),
      GoalsScreen(key: ValueKey('goals-$account')),
      PlannerScreen(key: ValueKey('planner-$account'), active: _index == 2),
      ReportsScreen(key: ValueKey('reports-$account')),
      ProfileScreen(key: ValueKey('profile-$account')),
    ];
    return Scaffold(
      body: PageSurface(
        child: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < pages.length; i++)
              if (_visited.contains(i))
                TickerMode(
                  enabled: _index == i,
                  child: AuroraPage(
                    title: _titles[i],
                    storageKey: 'tab-$account-$i',
                    actions: [
                      if (i == 0)
                        IconButton(
                          tooltip: 'Smart Reminders',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const SmartRemindersScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.notifications_outlined),
                        ),
                      IconButton(
                        tooltip: 'Assist',
                        onPressed: () => showAssistChooser(context),
                        icon: const Icon(Icons.auto_awesome_outlined),
                      ),
                      if (i != 4)
                        IconButton(
                          tooltip: 'Profile',
                          onPressed: () => selectTab(4),
                          icon: ProfileAvatar(
                            name:
                                FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.displayName ??
                                '',
                            googlePhotoUrl:
                                FirebaseAuth.instance.currentUser?.photoURL,
                            size: 32,
                          ),
                        ),
                    ],
                    child: pages[i],
                  ),
                )
              else
                const SizedBox.shrink(),
          ],
        ),
      ),
      floatingActionButton: _index == 1 || _index == 2
          ? FloatingActionButton.extended(
              backgroundColor: context.flowAction,
              foregroundColor: context.flowOnAction,
              onPressed: () => _index == 1
                  ? showGoalTypeChoice(context)
                  : showTaskForm(context),
              icon: const Icon(Icons.add),
              label: Text(_index == 1 ? 'New goal' : 'Add task'),
            )
          : null,
      bottomNavigationBar: SaveTrackNavigation(
        selectedIndex: _index,
        onSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

class SaveTrackNavigation extends StatelessWidget {
  const SaveTrackNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.atelierSurface,
              border: Border(top: BorderSide(color: context.atelierBorder)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                var widestLabel = 0.0;
                for (final label in [
                  'Today',
                  'Goals',
                  'Planner',
                  'Reports',
                  'Profile',
                ]) {
                  final measure = TextPainter(
                    text: TextSpan(
                      text: label,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  if (measure.width > widestLabel) widestLabel = measure.width;
                  measure.dispose();
                }
                final needed = (widestLabel + 4) * 5;
                final navigation = NavigationBar(
                  indicatorColor: context.atelierSelected,
                  height: MediaQuery.textScalerOf(context).scale(12) > 18
                      ? 60 + MediaQuery.textScalerOf(context).scale(12)
                      : 72,
                  animationDuration: SaveTrackDesign.duration(
                    context,
                    SaveTrackDesign.selectionMotion,
                  ),
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onSelected,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Today',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.savings_outlined),
                      selectedIcon: Icon(Icons.savings),
                      label: 'Goals',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.checklist_outlined),
                      selectedIcon: Icon(Icons.checklist),
                      label: 'Planner',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights),
                      label: 'Reports',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                );
                if (needed <= constraints.maxWidth) return navigation;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(width: needed, child: navigation),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text(
                        'Swipe for all tabs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.atelierMuted,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final today = _dateKey(DateTime.now());
    return LayoutBuilder(
      builder: (context, constraints) {
        final lazyTasks =
            constraints.maxWidth < 840 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        return DashboardLayout(
          tasksAreSlivers: lazyTasks,
          header: ScreenIntro(
            eyebrow: _dateTitle(DateTime.now()),
            title: 'Hello, ${user.displayName?.split(' ').first ?? 'there'}',
            detail: 'A little progress adds up.',
          ),
          savings: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _goals(user.uid)
                .where('archived', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return ErrorPanel(
                  message: 'Could not load your goals. Check your connection and try again.',
                );
              }
              if (!snap.hasData) return const LoadingPanel(featured: true);
              final docs = snap.data!.docs;
              final currency = CurrencyScope.maybeOf(context);
              final balances = docs
                  .map(
                    (d) => (
                      _number(d.data()['savedAmount']),
                      goalCurrency(d.data()),
                    ),
                  )
                  .toList();
              final targets = docs
                  .map(
                    (d) => (
                      _number(d.data()['targetAmount']),
                      goalCurrency(d.data()),
                    ),
                  )
                  .toList();
              final summary = currencySummary(currency, balances, targets);
              return SavingsOverview(
                total: summary.$1,
                target: summary.$2,
                count: docs.length,
                totalLabel: currency?.totalDisplay(balances),
                targetLabel: currency?.totalDisplay(targets),
                showProgress: summary.$3,
              );
            },
          ),
          metrics: AdaptiveCards(
            breakpoint: 0,
            children: [
              SummaryTile(
                icon: Icons.flag_outlined,
                label: 'Active goals',
                stream: _goals(user.uid)
                    .where('archived', isEqualTo: false)
                    .snapshots(),
                count: true,
              ),
              SummaryTile(
                icon: Icons.check_circle_outline,
                label: 'Done today',
                stream: _tasks(user.uid)
                    .where('dateKey', isEqualTo: today)
                    .snapshots(),
                count: false,
              ),
            ],
          ),
          goals: Column(
            children: [
              GoalsPreview(uid: user.uid),
              const SharedGoalsPanel(compact: true),
            ],
          ),
          tasks: TasksList(
            uid: user.uid,
            dateKey: today,
            compact: true,
            asSliver: lazyTasks,
          ),
          onGoals: () => _openTab(context, 1),
          onPlanner: () => _openTab(context, 2),
          ai: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AiDashboardCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AiCoachScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const MintIcon(Icons.hub_outlined),
                  title: const Text(
                    'Agent Studio',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Text or voice. Editable plans. Actions you approve.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AgentStudioScreen(
                        onOpen: _openAgentDestination,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SavingsOverview extends StatelessWidget {
  const SavingsOverview({
    super.key,
    required this.total,
    required this.target,
    required this.count,
    this.totalLabel,
    this.targetLabel,
    this.showProgress = true,
    this.embedded = false,
  });
  final String? totalLabel, targetLabel;
  final bool showProgress;
  final bool embedded;
  final double total, target;
  final int count;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your savings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.atelierInk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AmountText(
                      totalLabel ?? _money(total),
                      compactCurrency: true,
                      style: SaveTrackDesign.amount.copyWith(
                        color: context.atelierInk,
                        fontSize: constraints.maxWidth < 330 ? 32 : 38,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$count personal ${count == 1 ? 'goal' : 'goals'}',
                      style: TextStyle(fontSize: 13, color: context.atelierInk),
                    ),
                  ],
                ),
              ),
              if (constraints.maxWidth >= 300 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 21) ...[
                const SizedBox(width: 8),
                FlowSavingsArt(size: constraints.maxWidth < 380 ? 100 : 128),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (showProgress)
            MintProgress(value: target == 0 ? 0 : (total / target).clamp(0, 1)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  '${targetLabel ?? _money(target)} target',
                  style: TextStyle(color: context.atelierInk, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
      return embedded
          ? content
          : MintHero(
              soft: true,
              padding: const EdgeInsets.all(24),
              child: content,
            );
    },
  );
}

class DashboardLayout extends StatelessWidget {
  const DashboardLayout({
    super.key,
    required this.header,
    required this.savings,
    required this.metrics,
    required this.goals,
    required this.tasks,
    required this.onGoals,
    required this.onPlanner,
    this.tasksAreSlivers = false,
    this.ai,
  });
  final Widget header, savings, metrics, goals, tasks;
  final Widget? ai;
  final VoidCallback onGoals, onPlanner;
  final bool tasksAreSlivers;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final overview = Column(
        children: [
          savings,
          const SizedBox(height: 16),
          metrics,
          if (ai != null) ...[const SizedBox(height: 16), ai!],
        ],
      );
      final planHeader = SectionHeader(
        title: "Today\u2019s plan",
        action: 'Open planner',
        onTap: onPlanner,
      );
      final plan = Column(children: [planHeader, tasks]);
      final milestones = Column(
        children: [
          SectionHeader(title: 'Your goals', action: 'See all', onTap: onGoals),
          goals,
        ],
      );
      final wide =
          constraints.maxWidth >= 840 &&
          MediaQuery.textScalerOf(context).scale(14) <= 21;
      if (!wide) {
        final inset = SaveTrackDesign.pageInset(constraints.maxWidth);
        return CustomScrollView(
          key: const PageStorageKey('dashboard-scroll'),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, 12, inset, 0),
              sliver: SliverList.list(
                children: [
                  header,
                  overview,
                  const SizedBox(height: 24),
                  milestones,
                  const SizedBox(height: 28),
                  planHeader,
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              sliver: tasksAreSlivers
                  ? tasks
                  : SliverToBoxAdapter(child: tasks),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        );
      }
      return ListView(
        key: const PageStorageKey('dashboard-scroll'),
        padding: SaveTrackDesign.pagePadding(constraints.maxWidth),
        children: [
          header,
          if (wide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: overview),
                const SizedBox(width: 24),
                Expanded(child: plan),
              ],
            ),
            const SizedBox(height: 32),
            milestones,
          ] else ...[
            overview,
            const SizedBox(height: 24),
            milestones,
            const SizedBox(height: 28),
            plan,
          ],
        ],
      );
    },
  );
}

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});
  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 2,
    child: Column(
      children: [
        AuroraTabs(
          tabs: [
            Tab(text: 'Personal'),
            Tab(text: 'Shared'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [PersonalGoalsScreen(), SharedGoalsPanel()],
          ),
        ),
      ],
    ),
  );
}

class PersonalGoalsScreen extends StatefulWidget {
  const PersonalGoalsScreen({super.key});
  @override
  State<PersonalGoalsScreen> createState() => _PersonalGoalsScreenState();
}

class _PersonalGoalsScreenState extends State<PersonalGoalsScreen> {
  late final uid = FirebaseAuth.instance.currentUser!.uid;
  late final records = _goals(uid)
      .orderBy('createdAt', descending: true)
      .snapshots();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: records,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorPanel(
            message:
                'Could not load goals. Check your connection and try again.',
          );
        }
        if (!snap.hasData) return const LoadingPanel();
        final docs = snap.data!.docs
            .where((d) => d.data()['archived'] != true)
            .toList();
        if (docs.isEmpty) {
          return EmptyPanel(
            icon: Icons.savings_outlined,
            title: 'Start with a savings goal',
            detail: 'Give your next milestone a name and target.',
            action: 'Create goal',
            onTap: () => showGoalForm(context),
          );
        }
        return GoalBrowser(uid: uid, records: docs);
      },
    );
  }
}

class GoalsPreview extends StatelessWidget {
  const GoalsPreview({super.key, required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _goals(uid)
            .where('archived', isEqualTo: false)
            .limit(3)
            .snapshots(),
        builder: (context, s) {
          if (s.hasError) {
            return ErrorPanel(
              message:
                  'Could not load goals. Check your connection and try again.',
            );
          }
          if (!s.hasData) return const LoadingPanel();
          if (s.data!.docs.isEmpty) {
            return EmptyPanel(
              icon: Icons.savings_outlined,
              title: 'No goals yet',
              detail: 'Create a goal to start tracking progress.',
              action: 'Create goal',
              onTap: () => showGoalForm(context),
            );
          }
          return AdaptiveCards(
            children: s.data!.docs
                .map((d) => GoalCard(key: ValueKey(d.id), uid: uid, doc: d))
                .toList(),
          );
        },
      );
}

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.uid,
    required this.doc,
    this.details = false,
    this.coverLoad,
  });
  final String uid;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool details;
  final Future<Uint8List?> Function(String)? coverLoad;
  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final coverTarget = GoalCoverTarget.personal(uid, doc.id);
    final cover = GoalCoverRecord.fromMap(data, coverTarget);
    final code = goalCurrency(data);
    String money(num value) => displayMoney(context, value, code);
    final saved = _number(data['savedAmount']),
        target = _number(data['targetAmount']);
    final double pct = target == 0 ? 0 : (saved / target).clamp(0.0, 1.0);
    final enlarged = MediaQuery.textScalerOf(context).scale(14) > 21;
    final reminderTarget = ReminderTarget.fromData(
      ReminderTargetType.personalGoal,
      doc.id,
      data,
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: !details,
              label: details ? 'Goal cover' : 'Open goal details',
              child: InkWell(
                onTap: details
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => PersonalGoalDetailsScreen(
                            uid: uid,
                            goalId: doc.id,
                          ),
                        ),
                      ),
                child: GoalCoverImage(
                  target: coverTarget,
                  name: '${data['title']}',
                  path: cover.path,
                  decodeWidth: details ? 1280 : 640,
                  load: coverLoad,
                  onEdit: details
                      ? () => showGoalCoverActions(
                          context,
                          coverTarget,
                          cover.path,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MintIcon(Icons.flag_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: enlarged
                      ? const SizedBox.shrink()
                      : Text(
                          '${data['title']}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.atelierInk,
                          ),
                        ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Goal actions',
                  onSelected: (v) {
                    if (v == 'deposit') showDepositForm(context, uid, doc);
                    if (v == 'withdrawal') {
                      showDecreaseSavingsForm(context, uid, doc);
                    }
                    if (v == 'edit') showGoalForm(context, doc: doc);
                    if (v == 'cover') changeGoalCover(context, coverTarget);
                    if (v == 'remove-cover') {
                      removeGoalCover(context, coverTarget);
                    }
                    if (v == 'reminder') {
                      showReminderEditor(context, reminderTarget);
                    }
                    if (v == 'shared') {
                      createSharedGoal(context, personal: data);
                    }
                    if (v == 'delete') {
                      confirmDelete(
                        context,
                        'Delete this goal and its savings history?',
                        () => _deleteGoal(doc),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'deposit',
                      child: Text('Add savings'),
                    ),
                    PopupMenuItem(
                      value: 'withdrawal',
                      enabled: saved > 0,
                      child: const Text('Decrease Savings'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit goal'),
                    ),
                    PopupMenuItem(
                      value: 'cover',
                      child: Text(
                        cover.path == null
                            ? 'Add Goal Photo'
                            : 'Change Goal Photo',
                      ),
                    ),
                    if (cover.path != null)
                      const PopupMenuItem(
                        value: 'remove-cover',
                        child: Text('Remove Goal Photo'),
                      ),
                    const PopupMenuItem(
                      value: 'shared',
                      child: Text('Save Together'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete goal'),
                    ),
                    PopupMenuItem(
                      value: 'reminder',
                      child: Text(
                        ReminderScope.maybeOf(context)?.configurations
                                    .containsKey(reminderTarget.key) ==
                                true
                            ? 'Manage Reminder'
                            : 'Set Reminder',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (enlarged)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '${data['title']}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.atelierInk,
                  ),
                ),
              ),
            ReminderButton(target: reminderTarget),
            if ((data['note'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  data['note'] as String,
                  style: TextStyle(color: context.atelierMuted, fontSize: 13),
                ),
              ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AmountText(
                  '${money(saved)} saved',
                  compactCurrency: true,
                  supportingSuffix: ' saved',
                  style: SaveTrackDesign.amount.copyWith(
                    fontSize: 28,
                    color: context.atelierAccent,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${money(target)} target',
                  style: TextStyle(color: context.atelierMuted, fontSize: 13),
                ),
                CurrencyContextLabel(source: code),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(
                      saved >= target && target > 0
                          ? 'Goal reached'
                          : '${(pct * 100).round()}% saved',
                    ),
                    Text(
                      '${money((target - saved).clamp(0, double.infinity))} to go',
                      style: TextStyle(
                        color: context.atelierMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                MintProgress(value: pct),
              ],
            ),
            const SizedBox(height: 16),
            if (data['deadline'] is Timestamp)
              DetailLine(
                icon: Icons.calendar_today_outlined,
                label:
                    'Target date  ${_shortDate((data['deadline'] as Timestamp).toDate())}',
              ),
            if (data['deadline'] is Timestamp && saved < target)
              Builder(
                builder: (context) {
                  final deadline = (data['deadline'] as Timestamp).toDate();
                  final needed = target - saved;
                  final now = DateTime.now();
                  final isOverdue = deadline.isBefore(
                    DateTime(now.year, now.month, now.day),
                  );
                  final days = deadline
                      .difference(DateTime(now.year, now.month, now.day))
                      .inDays
                      .clamp(1, 365000);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: DetailLine(
                      icon: isOverdue ? Icons.schedule : Icons.trending_up,
                      label: isOverdue
                          ? 'Overdue  ${money(needed)} remaining'
                          : 'Suggested pace: ${money(needed / days)} daily, ${money(needed * 7 / days)} weekly',
                      color: isOverdue
                          ? context.atelierError
                          : context.atelierMuted,
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (!details)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PersonalGoalDetailsScreen(uid: uid, goalId: doc.id),
                      ),
                    ),
                    child: const Text('Details'),
                  ),
                TextButton(
                  onPressed: () => showTransactionHistory(context, doc),
                  child: const Text('History'),
                ),
                GradientButton(
                  expand: false,
                  onPressed: () => showDepositForm(context, uid, doc),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 8),
                      Flexible(child: Text('Add savings')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PersonalGoalDetailsScreen extends StatefulWidget {
  const PersonalGoalDetailsScreen({
    super.key,
    required this.uid,
    required this.goalId,
  });
  final String uid, goalId;
  @override
  State<PersonalGoalDetailsScreen> createState() =>
      _PersonalGoalDetailsScreenState();
}

class _PersonalGoalDetailsScreenState extends State<PersonalGoalDetailsScreen> {
  late final stream = _goals(widget.uid)
      .where(FieldPath.documentId, isEqualTo: widget.goalId)
      .snapshots(includeMetadataChanges: true);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Goal Details')),
    body: PageSurface(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (FirebaseAuth.instance.currentUser?.uid != widget.uid ||
              snapshot.hasError) {
            return const ErrorPanel(
              message: 'This goal is no longer available to you.',
            );
          }
          if (!snapshot.hasData) return const LoadingPanel();
          if (snapshot.data!.docs.isEmpty) {
            return const ErrorPanel(message: 'This goal has been deleted.');
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuroraSyncStatus(
                      cached: snapshot.data!.metadata.isFromCache,
                      pending: snapshot.data!.metadata.hasPendingWrites,
                    ),
                    PersonalGoalOverview(
                      uid: widget.uid,
                      doc: snapshot.data!.docs.single,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, this.active = true, this.initialDate});
  final bool active;
  final DateTime? initialDate;
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with WidgetsBindingObserver {
  DateTime _day = DateTime.now();
  bool _followToday = true;
  Timer? _midnightTimer;
  bool _foreground = true;
  bool _weekly = false;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDate ?? _day;
    _followToday = widget.initialDate == null;
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    if (!widget.active || !_foreground || !_followToday) return;
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final untilMidnight = midnight.difference(now);
    final checkAfter = untilMidnight < const Duration(minutes: 1)
        ? untilMidnight
        : const Duration(minutes: 1);
    // Check the calendar each minute too, in case the device timezone changes
    // while this screen remains foregrounded. Rebuild only when the day changes.
    _midnightTimer = Timer(checkAfter, () {
      if (!mounted) return;
      if (_dateKey(_day) != _dateKey(DateTime.now())) {
        setState(() => _day = DateTime.now());
      }
      _scheduleMidnight();
    });
  }

  void _refreshToday() {
    if (_followToday && _dateKey(_day) != _dateKey(DateTime.now())) {
      setState(() => _day = DateTime.now());
    }
    _scheduleMidnight();
  }

  void _selectDay(DateTime day) {
    setState(() {
      _day = day;
      _followToday = _dateKey(day) == _dateKey(DateTime.now());
    });
    _scheduleMidnight();
  }

  @override
  void didUpdateWidget(covariant PlannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _refreshToday();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && widget.active) {
      _refreshToday();
    } else {
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final key = _dateKey(_day);
    final modeSwitch = Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AuroraModeSelector<bool>(
        selected: _weekly,
        options: const {false: 'Daily', true: 'Weekly'},
        onSelected: (value) => setState(() => _weekly = value),
      ),
    );
    if (_weekly) {
      return WeeklyPlanner(
        uid: uid,
        selected: _day,
        onSelect: _selectDay,
        header: modeSwitch,
      );
    }
    return TasksList(
      uid: uid,
      dateKey: key,
      suggestionsActive: widget.active,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          modeSwitch,
          PlannerDateHeader(
            date: _day,
            onSelect: _selectDay,
            title: _dateTitle(_day),
            onPrevious: () =>
                _selectDay(DateTime(_day.year, _day.month, _day.day - 1)),
            onNext: () =>
                _selectDay(DateTime(_day.year, _day.month, _day.day + 1)),
            onToday: () => _selectDay(DateTime.now()),
            onPick: () async {
              final selected = await showSaveTrackDatePicker(
                context: context,
                initialDate: _day,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (selected != null && mounted) _selectDay(selected);
            },
          ),
        ],
      ),
    );
  }
}

class PlannerDateHeader extends StatelessWidget {
  const PlannerDateHeader({
    super.key,
    required this.title,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    this.onPick,
    this.date,
    this.onSelect,
  });
  final String title;
  final VoidCallback onPrevious, onNext, onToday;
  final VoidCallback? onPick;
  final DateTime? date;
  final ValueChanged<DateTime>? onSelect;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (date != null)
        FlowDateHeading(date: date!, onToday: onToday, onPick: onPick)
      else
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onPick,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            TextButton(onPressed: onToday, child: const Text('Today')),
          ],
        ),
      const SizedBox(height: 8),
      Row(
        children: [
          if (date != null && onSelect != null)
            IconButton(
              tooltip: 'Previous week',
              onPressed: () =>
                  onSelect!(DateTime(date!.year, date!.month, date!.day - 7)),
              icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
            ),
          IconButton(
            tooltip: 'Previous day',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              date == null ? title : DateFormat('MMM yyyy').format(date!),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          if (date != null && onSelect != null)
            IconButton(
              tooltip: 'Next week',
              onPressed: () =>
                  onSelect!(DateTime(date!.year, date!.month, date!.day + 7)),
              icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
            ),
        ],
      ),
      if (date != null && onSelect != null) ...[
        const SizedBox(height: 8),
        FlowWeekSelector(selected: date!, onSelected: onSelect!),
      ],
      const SizedBox(height: 16),
    ],
  );
}

class DailyCompletion extends StatelessWidget {
  const DailyCompletion({super.key, required this.done, required this.total});
  final int done, total;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ring = ProgressRing(
            value: total == 0 ? 0 : done / total,
            size: 64,
          );
          final label = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily progress',
                style: TextStyle(
                  color: context.atelierInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$done of $total tasks completed',
                style: TextStyle(
                  color: context.atelierMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          );
          return constraints.maxWidth >= 240 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 21
              ? Row(
                  children: [
                    ring,
                    const SizedBox(width: 20),
                    Expanded(child: label),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [ring, const SizedBox(height: 16), label],
                );
        },
      ),
    ),
  );
}

class TasksList extends StatefulWidget {
  const TasksList({
    super.key,
    required this.uid,
    required this.dateKey,
    this.compact = false,
    this.header,
    this.suggestionsActive = true,
    this.taskStream,
    this.recommendationService,
    this.asSliver = false,
    this.maxPreview,
  });
  final String uid, dateKey;
  final bool compact;
  final bool asSliver;
  final int? maxPreview;
  final Widget? header;
  final bool suggestionsActive;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? taskStream;
  final SmartTaskRecommendationService? recommendationService;
  @override
  State<TasksList> createState() => _TasksListState();
}

class _TasksListState extends State<TasksList> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _setStream();
  }

  void _setStream() {
    _stream =
        widget.taskStream ??
        _tasks(widget.uid)
            .where('dateKey', isEqualTo: widget.dateKey)
            .snapshots();
  }

  @override
  void didUpdateWidget(covariant TasksList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.dateKey != widget.dateKey ||
        oldWidget.taskStream != widget.taskStream) {
      _setStream();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    key: ValueKey('${widget.uid}/${widget.dateKey}'),
    stream: _stream,
    builder: (context, s) {
      Widget state(Widget child) => widget.asSliver
          ? SliverToBoxAdapter(child: child)
          : widget.compact
          ? child
          : ListView(
              padding: SaveTrackDesign.pagePadding(
                MediaQuery.sizeOf(context).width,
                bottom: 100,
              ).copyWith(top: 8),
              children: [?widget.header, child],
            );
      if (s.hasError) {
        return state(
          ErrorPanel(
            message:
                'Could not load tasks. Check your connection and try again.',
          ),
        );
      }
      if (!s.hasData) return state(const LoadingPanel());
      final docs = flowOrderedTasks(s.data!.docs, widget.dateKey);
      if (widget.compact && docs.isEmpty) {
        return state(
          EmptyPanel(
            icon: Icons.event_available_outlined,
            title: 'A clear day',
            detail: "Add tasks when you\u2019re ready.",
            action: 'Add a task',
            onTap: () => showTaskForm(context, dateKey: widget.dateKey),
          ),
        );
      }
      if (widget.compact) {
        if (widget.asSliver) {
          return SliverList.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) => TaskTile(
              key: ValueKey('dashboard-task-${docs[index].id}'),
              uid: widget.uid,
              doc: docs[index],
            ),
          );
        }
        return Column(
          children: docs
              .take(widget.maxPreview ?? docs.length)
              .map(
                (d) => TaskTile(
                  key: ValueKey('dashboard-task-${d.id}'),
                  uid: widget.uid,
                  doc: d,
                ),
              )
              .toList(),
        );
      }
      final done = docs.where((d) => d.data()['completed'] == true).length;
      final selectedDate = SmartTaskRecommendationService.parseDateKey(
        widget.dateKey,
      );
      final byId = {for (final doc in docs) doc.id: doc};
      final insights = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (docs.isNotEmpty) ...[
            DailyCompletion(done: done, total: docs.length),
            const SizedBox(height: 24),
          ],
          if (selectedDate != null)
            SmartSuggestions(
              tasks: docs.map((doc) {
                final data = doc.data();
                return PlannerTask.fromData(
                  doc.id,
                  data,
                  createdAt: data['createdAt'] is Timestamp
                      ? (data['createdAt'] as Timestamp).toDate()
                      : null,
                );
              }).toList(),
              selectedDate: selectedDate,
              active: widget.suggestionsActive,
              service: widget.recommendationService,
              onAddTask: () => showTaskForm(context, dateKey: widget.dateKey),
              onOpenTask: (id) {
                final doc = byId[id];
                if (doc != null) showTaskForm(context, doc: doc);
              },
              onCompleteTask: (id) async {
                final doc = byId[id];
                if (doc != null) await setPlannerTaskCompleted(doc, true);
              },
            ),
          const SizedBox(height: 24),
        ],
      );
      final overview = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?widget.header,
          if (docs.isNotEmpty) ...[
            Row(
              children: [
                const SizedBox(width: 4),
                SizedBox(
                  width: 76,
                  child: Text(
                    'Time',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Your Tasks',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
      final featuredId = flowFeaturedTask(docs, widget.dateKey);
      final firstFlexible = docs.indexWhere(
        (d) => !flowHasSchedule(d, widget.dateKey),
      );
      return ListView.builder(
        padding: SaveTrackDesign.pagePadding(
          MediaQuery.sizeOf(context).width,
          bottom: 100,
        ).copyWith(top: 8),
        itemCount: docs.length + 2,
        itemBuilder: (context, index) => index == 0
            ? overview
            : index == docs.length + 1
            ? insights
            : FlowTaskGroupEntry(
                dateKey: widget.dateKey,
                groupHeading: index - 1 == firstFlexible,
                featured: docs[index - 1].id == featuredId,
                key: ValueKey('planner-task-${docs[index - 1].id}'),
                uid: widget.uid,
                doc: docs[index - 1],
              ),
      );
    },
  );
}

/// The original task update, shared by the list and recommendation controls.
Future<void> setPlannerTaskCompleted(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  bool completed,
) => doc.reference.update({
  'completed': completed,
  'updatedAt': FieldValue.serverTimestamp(),
});

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.uid,
    required this.doc,
    this.timeline = false,
    this.featured = false,
  });
  final bool timeline, featured;
  final String uid;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final done = d['completed'] == true;
    final time = d['time']?.toString() ?? '';
    final day = SmartTaskRecommendationService.parseDateKey(
      d['dateKey']?.toString() ?? '',
    );
    final schedule = day == null
        ? const TaskSchedule()
        : SmartTaskRecommendationService.parseSchedule(time, day);
    final railTime = schedule.start == null
        ? (time.isEmpty ? 'Anytime' : 'Flexible')
        : DateFormat('HH:mm').format(schedule.start!);
    final endTime = schedule.end == null
        ? null
        : DateFormat('HH:mm').format(schedule.end!);
    final reminderTarget = ReminderTarget.fromData(
      ReminderTargetType.task,
      doc.id,
      d,
    );
    final card = AnimatedContainer(
      duration: SaveTrackDesign.duration(context, SaveTrackDesign.motion),
      curve: SaveTrackDesign.motionCurve,
      decoration: BoxDecoration(
        color: done
            ? context.atelierTonal
            : featured
            ? context.flowCategory(FlowAccent.mint)
            : context.atelierTonal,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: done ? context.atelierBorder : context.atelierBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!timeline)
              Checkbox(
                semanticLabel: 'Complete ${d['title']}',
                value: done,
                activeColor: context.atelierAccent,
                onChanged: (v) async {
                  try {
                    await setPlannerTaskCompleted(doc, v == true);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not update this task. Please try again.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: SaveTrackDesign.duration(
                        context,
                        SaveTrackDesign.motion,
                      ),
                      curve: SaveTrackDesign.motionCurve,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? context.atelierMuted : context.atelierInk,
                      ),
                      child: Text('${d['title']}'),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (time.isNotEmpty && !timeline)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_outlined,
                                  size: 14,
                                  color: context.atelierMuted,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    time,
                                    style: TextStyle(
                                      color: context.atelierMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          StatusPill(
                            '${d['priority'] ?? 'Normal'} priority',
                            color: d['priority'] == 'High'
                                ? context.atelierWarning
                                : context.atelierAccent,
                          ),
                          if (done) const StatusPill('Completed'),
                          if (timeline)
                            Checkbox(
                              semanticLabel: 'Complete ${d['title']}',
                              value: done,
                              activeColor: context.atelierAccent,
                              onChanged: (v) async {
                                try {
                                  await setPlannerTaskCompleted(doc, v == true);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not update this task. Please try again.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    if (!timeline) ReminderButton(target: reminderTarget),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Task actions',
              onSelected: (v) {
                if (v == 'edit') showTaskForm(context, doc: doc);
                if (v == 'reminder') {
                  showReminderEditor(context, reminderTarget);
                }
                if (v == 'delete') {
                  confirmDelete(
                    context,
                    'Delete this task?',
                    () => doc.reference.delete(),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                PopupMenuItem(
                  value: 'reminder',
                  child: Text(
                    ReminderScope.maybeOf(context)?.configurations
                                .containsKey(reminderTarget.key) ==
                            true
                        ? 'Manage Reminder'
                        : 'Set Reminder',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return timeline
        ? FlowTimelineEntry(
            time: railTime,
            caption: endTime,
            featured: featured,
            child: card,
          )
        : Padding(padding: const EdgeInsets.only(bottom: 12), child: card);
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final uid = FirebaseAuth.instance.currentUser!.uid;
  late final records = _goals(uid).snapshots();
  @override
  Widget build(BuildContext context) {
    final today = _dateKey(DateTime.now());
    final start = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );
    final weekStart = _dateKey(start);
    return ReportsLayout(
      savings: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: records,
        builder: (context, s) {
          if (s.hasError) {
            return ErrorPanel(
              message: 'Could not load savings. Check your connection and try again.',
            );
          }
          if (!s.hasData) return const LoadingPanel(featured: true);
          final ds = s.data!.docs;
          final currency = CurrencyScope.maybeOf(context);
          final balances = ds
              .map(
                (d) =>
                    (_number(d.data()['savedAmount']), goalCurrency(d.data())),
              )
              .toList();
          final targets = ds
              .map(
                (d) =>
                    (_number(d.data()['targetAmount']), goalCurrency(d.data())),
              )
              .toList();
          final summary = currencySummary(currency, balances, targets);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReportMetric(
                title: 'Savings balance',
                featured: true,
                progress: summary.$3
                    ? (summary.$2 == 0
                          ? 0
                          : (summary.$1 / summary.$2).clamp(0, 1))
                    : null,
                value:
                    currency?.totalDisplay(balances) ??
                    (summary.$3
                        ? _money(summary.$1)
                        : 'Conversion unavailable'),
                caption:
                    'Across ${ds.length} personal goals \u00b7 Target: ${currency?.totalDisplay(targets) ?? (summary.$3 ? _money(summary.$2) : 'See each goal in its original currency')}. Current-rate estimates; stored amounts remain authoritative.',
                icon: Icons.savings_outlined,
              ),
              const SizedBox(height: 24),
              const AtelierSectionHeader(
                title: 'Savings activity',
                subtitle: 'Contributions, withdrawals and net change.',
              ),
              SavingsPulse(uid: uid, goals: ds),
            ],
          );
        },
      ),
      shared: const SharedGoalsPanel(report: true),
      daily: ReportTaskMetric(
        uid: uid,
        dateKey: today,
        title: "Today\u2019s tasks",
      ),
      weekly: ReportTaskMetric(
        uid: uid,
        dateKey: weekStart,
        title: "This week\u2019s tasks",
        week: true,
      ),
      goals: GoalsPreview(uid: uid),
    );
  }
}

/// Composition only: streams, report windows and calculations stay in the screen.
class ReportsLayout extends StatelessWidget {
  const ReportsLayout({
    super.key,
    required this.savings,
    required this.shared,
    required this.daily,
    required this.weekly,
    required this.goals,
  });
  final Widget savings, shared, daily, weekly, goals;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final expanded =
          constraints.maxWidth >= 840 &&
          MediaQuery.textScalerOf(context).scale(14) <= 21;
      final finances = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [savings, const SizedBox(height: 24), shared],
      );
      final planning = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Planning rhythm',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (expanded) ...[
            daily,
            const SizedBox(height: 16),
            weekly,
          ] else
            AdaptiveCards(breakpoint: 600, children: [daily, weekly]),
        ],
      );
      return ListView(
        key: const PageStorageKey('reports-scroll'),
        padding: SaveTrackDesign.pagePadding(constraints.maxWidth),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text('Your savings and planning, at a glance.'),
          ),
          if (expanded)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: finances),
                const SizedBox(width: 24),
                Expanded(child: planning),
              ],
            )
          else ...[
            finances,
            const SizedBox(height: 32),
            planning,
          ],
          const SizedBox(height: 32),
          Text(
            'Savings progress',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          goals,
        ],
      );
    },
  );
}

class ReportTaskMetric extends StatelessWidget {
  const ReportTaskMetric({
    super.key,
    required this.uid,
    required this.dateKey,
    required this.title,
    this.week = false,
  });
  final String uid, dateKey, title;
  final bool week;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: week
        ? _tasks(uid)
              .where('dateKey', isGreaterThanOrEqualTo: dateKey)
              .where(
                'dateKey',
                isLessThanOrEqualTo: _dateKey(
                  DateTime.parse(dateKey).add(const Duration(days: 6)),
                ),
              )
              .snapshots()
        : _tasks(uid).where('dateKey', isEqualTo: dateKey).snapshots(),
    builder: (context, s) {
      if (s.hasError) {
        return ErrorPanel(
          message: 'Could not load task report. Check your connection and try again.',
        );
      }
      if (!s.hasData) return const LoadingPanel(minHeight: 236);
      final all = s.data!.docs;
      final done = all.where((d) => d.data()['completed'] == true).length;
      return ReportMetric(
        title: title,
        value: '$done / ${all.length} completed',
        progress: all.isEmpty ? 0 : done / all.length,
        caption:
            '${_shortDate(DateTime.parse(dateKey))}'
            '${week ? ' – ${_shortDate(DateTime.parse(dateKey).add(const Duration(days: 6)))}' : ''}'
            ' · ${all.isEmpty ? 'No tasks scheduled' : '${all.length - done} remaining'}',
        icon: Icons.check_circle_outline,
      );
    },
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final user = FirebaseAuth.instance.currentUser!;
  late final profile = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => !snapshot.metadata.hasPendingWrites);
  late final photoService = ProfilePhotoService(FirestoreProfilePhotoBackend());
  late final picker = GalleryProfilePhotoPicker();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profile,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final name = data['displayName'] is String
              ? data['displayName'] as String
              : user.displayName ?? 'SaveTrack user';
          return ProfileContent(
            name: name,
            email: user.email ?? '',
            avatar: ProfilePhotoEditor(
              key: ValueKey(user.uid),
              uid: user.uid,
              name: name,
              path: data['avatarStoragePath'] is String
                  ? data['avatarStoragePath'] as String
                  : null,
              googlePhotoUrl: user.photoURL,
              service: photoService,
              picker: picker,
              enabled: snapshot.hasData && !snapshot.hasError,
            ),
            profileError: snapshot.hasError
                ? 'Your profile could not be loaded. Check your connection and reopen Profile.'
                : null,
            onPassword: () => showChangePasswordDialog(
              context,
              AuthService.instance.passwordChangeSession(),
            ),
            onSignOut: () => AuthService.instance.signOut(),
          );
        },
      );
}

/// Pure account presentation; Firebase remains owned by ProfileScreen.
class ProfileContent extends StatelessWidget {
  const ProfileContent({
    super.key,
    required this.name,
    required this.email,
    required this.onPassword,
    required this.onSignOut,
    this.avatar,
    this.profileError,
  });
  final String name, email;
  final VoidCallback onPassword, onSignOut;
  final Widget? avatar;
  final String? profileError;
  @override
  Widget build(BuildContext context) {
    final preferences = AtelierScope.maybeOf(context);
    return ListView(
      key: const PageStorageKey('profile-scroll'),
      padding: SaveTrackDesign.pagePadding(
        MediaQuery.sizeOf(context).width,
        bottom: 32,
      ),
      children: [
        AuroraIdentity(
          name: name,
          email: email,
          avatar: avatar ?? ProfileAvatar(name: name, size: 56),
        ),
        if (profileError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AuroraNotice(profileError!, error: true),
          ),
        const SizedBox(height: 24),
        if (preferences != null) ...[
          AuroraGroupedSection(
            title: 'Make it yours',
            children: [
              ListTile(
                leading: const MintIcon(Icons.palette_outlined, size: 36),
                title: const Text('Appearance'),
                subtitle: Text(switch (AtelierPreferences.themeMode.value) {
                  ThemeMode.system => 'System',
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                }),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAppearancePicker(context, preferences),
              ),
              ListTile(
                leading: const MintIcon(
                  Icons.dashboard_customize_outlined,
                  size: 36,
                ),
                title: const Text('Customize Home'),
                subtitle: const Text('Views, sections and your featured goal'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CustomizeHomeScreen(preferences: preferences),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        AuroraGroupedSection(
          title: 'Everyday preferences',
          children: [
            ListTile(
              key: const ValueKey('open-currency-settings'),
              leading: const MintIcon(Icons.currency_exchange, size: 36),
              title: const Text('Currency Settings'),
              subtitle: Text(
                'Display currency · ${CurrencyScope.maybeOf(context)?.preferred ?? 'PHP'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CurrencySettingsScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const MintIcon(Icons.notifications_outlined, size: 36),
              title: const Text('Smart Reminders'),
              subtitle: const Text(
                'Your agenda and phone notification settings',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const SmartRemindersScreen(),
                ),
              ),
            ),
            if (HomeWidgetScope.maybeOf(context)?.bridge.supported == true)
              ListTile(
                leading: const MintIcon(Icons.widgets_outlined, size: 36),
                title: const Text('Home Screen Widgets'),
                subtitle: const Text('Savings and daily plans, at a glance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final owner = FirebaseAuth.instance.currentUser?.uid;
                  if (owner == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => WidgetAccountGuard(
                        uid: owner,
                        child: const HomeWidgetsSettingsScreen(),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        AuroraGroupedSection(
          title: 'AI & Assist',
          children: [
            ListTile(
              leading: const MintIcon(Icons.auto_awesome_outlined, size: 36),
              title: const Text('SaveTrack AI'),
              subtitle: const Text(
                'Questions, guidance and read-only coaching',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const AiCoachScreen()),
              ),
            ),
            ListTile(
              leading: const MintIcon(Icons.hub_outlined, size: 36),
              title: const Text('Agent Studio Pro'),
              subtitle: const Text('Plans, missions and execution settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const AgentStudioScreen(onOpen: _openAgentDestination),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AuroraGroupedSection(
          title: 'Account security',
          children: [
            ListTile(
              leading: const MintIcon(Icons.lock_outline, size: 36),
              title: const Text('Change Password'),
              subtitle: const Text('Keep your account secure'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onPassword,
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.atelierError,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'SaveTrack · Beautiful progress. Effortless control.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.icon,
    required this.label,
    required this.stream,
    required this.count,
  });
  final IconData icon;
  final String label;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool count;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, s) {
      if (s.hasError) {
        return ErrorPanel(
          message:
              'Could not load $label. Check your connection and try again.',
        );
      }
      if (!s.hasData) return const LoadingPanel();
      return AuroraMetricCard(
        icon: icon,
        value: s.hasData
            ? (count
                  ? '${s.data!.docs.length}'
                  : '${s.data!.docs.where((d) => d.data()['completed'] == true).length}/${s.data!.docs.length}')
            : '',
        label: label,
      );
    },
  );
}

class ReportMetric extends StatelessWidget {
  const ReportMetric({
    super.key,
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    this.progress,
    this.featured = false,
  });
  final String title, value, caption;
  final IconData icon;
  final double? progress;
  final bool featured;
  @override
  Widget build(BuildContext context) {
    if (!featured) {
      return AuroraChartSurface(
        title: title,
        icon: icon,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final numbers = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: SaveTrackDesign.amount.copyWith(
                    fontSize: 22,
                    color: context.atelierInk,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  caption,
                  style: TextStyle(color: context.atelierMuted, fontSize: 13),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 16),
                  const DetailLine(
                    icon: Icons.check_circle_outline,
                    label: 'Task completion',
                  ),
                ],
              ],
            );
            if (progress == null) return numbers;
            final ring = ProgressRing(value: progress!, size: 88);
            return constraints.maxWidth >= 300 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 21
                ? Row(
                    children: [
                      ring,
                      const SizedBox(width: 24),
                      Expanded(child: numbers),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [ring, const SizedBox(height: 20), numbers],
                  );
          },
        ),
      );
    }
    return TonalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.atelierMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 24, color: context.atelierAccent),
            ],
          ),
          const SizedBox(height: 16),
          AmountText(
            value,
            compactCurrency: true,
            style: SaveTrackDesign.amount.copyWith(
              fontSize: 38,
              color: context.atelierInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: TextStyle(color: context.atelierMuted, fontSize: 13),
          ),
          if (progress != null) ...[
            const SizedBox(height: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(progress! * 100).round()}% of total target',
                  style: TextStyle(
                    color: context.atelierInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                MintProgress(value: progress!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 21,
              color: context.atelierInk,
            ),
          ),
        ),
        Flexible(
          child: TextButton(onPressed: onTap, child: Text(action)),
        ),
      ],
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandDot(),
      SizedBox(width: 10),
      Flexible(
        child: Text(
          'SaveTrack',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
            color: context.atelierAccent,
          ),
        ),
      ),
    ],
  );
}

class BrandDot extends StatelessWidget {
  const BrandDot({super.key});
  @override
  Widget build(BuildContext context) => const AuroraEmblem(size: 36);
}

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({super.key, this.featured = false, this.minHeight = 0});
  final bool featured;
  final double minHeight;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: AuroraSkeleton(featured: featured),
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => StateSurface(
    padding: const EdgeInsets.all(16),
    child: Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          border: Border.all(color: context.atelierError.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final icon = Icon(
              Icons.error_outline,
              color: context.atelierError,
              size: 22,
            );
            final text = Text(
              message,
              style: TextStyle(color: context.atelierError, height: 1.5),
            );
            return constraints.maxWidth < 220
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [icon, const SizedBox(height: 8), text],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: text),
                    ],
                  );
          },
        ),
      ),
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
    required this.onTap,
  });
  final IconData icon;
  final String title, detail, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => StateSurface(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: context.atelierSurfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.atelierBorder),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MintIcon(icon, size: 64),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.atelierMuted, height: 1.5),
          ),
          const SizedBox(height: 16),
          GradientButton(expand: false, onPressed: onTap, child: Text(action)),
        ],
      ),
    ),
  );
}

CollectionReference<Map<String, dynamic>> _goals(String uid) =>
    FirebaseFirestore.instance.collection('users').doc(uid).collection('goals');
CollectionReference<Map<String, dynamic>> _tasks(String uid) =>
    FirebaseFirestore.instance.collection('users').doc(uid).collection('tasks');

Future<void> _openAgentDestination(
  BuildContext context,
  String destination,
  String? id,
  String? amount,
) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  if (destination == 'contribution' && id != null) {
    final snapshot = await _goals(uid)
        .where(FieldPath.documentId, isEqualTo: id)
        .get(const GetOptions(source: Source.server));
    if (!context.mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    if (snapshot.docs.isEmpty) throw StateError('Goal unavailable');
    await showCurrencySavingsForm(
      context,
      uid,
      snapshot.docs.first,
      initialAmount: amount,
      guardWidgetAccount: true,
    );
    return;
  }
  final Widget page = switch (destination) {
    'general' => const AiCoachScreen(),
    'reminders' => const SmartRemindersScreen(),
    'goal' when id != null => PersonalGoalDetailsScreen(uid: uid, goalId: id),
    _ => Scaffold(
      appBar: AppBar(
        title: Text(
          destination == 'planner'
              ? 'Planner'
              : destination == 'reports'
              ? 'Reports'
              : 'Savings goals',
        ),
      ),
      body: PageSurface(
        child: destination == 'planner'
            ? const PlannerScreen()
            : destination == 'reports'
            ? const ReportsScreen()
            : const GoalsScreen(),
      ),
    ),
  };
  if (context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WidgetAccountGuard(uid: uid, child: page),
      ),
    );
  }
}

double _number(dynamic v) => v is num ? v.toDouble() : 0;
String _money(num v) => originalMoney(v);

(double, double, bool) currencySummary(
  CurrencyController? service,
  List<(num, String)> balances,
  List<(num, String)> targets,
) {
  try {
    final converter =
        service?.conversion ?? const CurrencyConversionService(null);
    final code = service?.preferred ?? 'PHP';
    return (
      converter.total(balances, code).toDouble(),
      converter.total(targets, code).toDouble(),
      true,
    );
  } on CurrencyFailure {
    return (0, 0, false);
  }
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _shortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
String _dateTitle(DateTime d) => _dateKey(d) == _dateKey(DateTime.now())
    ? 'Today  ${_shortDate(d)}'
    : '${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]}  ${_shortDate(d)}';
void _openTab(BuildContext context, int index) {
  final state = context.findAncestorStateOfType<_HomeShellState>();
  state?.selectTab(index);
}

Future<void> _deleteGoal(
  QueryDocumentSnapshot<Map<String, dynamic>> goal,
) async {
  final transactions = await goal.reference.collection('transactions').get();
  for (var offset = 0; offset < transactions.docs.length; offset += 450) {
    final batch = FirebaseFirestore.instance.batch();
    for (final transaction in transactions.docs.skip(offset).take(450)) {
      batch.delete(transaction.reference);
    }
    await batch.commit();
  }
  await goal.reference.delete();
  // Goal/history deletion succeeds independently of optional photo cleanup.
  // The durable journal retries cleanup when the server is available again.
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    final target = GoalCoverTarget.personal(uid, goal.id);
    final cover = GoalCoverRecord.fromMap(goal.data(), target);
    if (cover.path != null) {
      try {
        await FirestoreGoalCoverBackend().cleanup(target, cover.path!);
      } catch (_) {
        /* journal retries */
      }
    }
  }
}

Future<void> showTransactionHistory(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> goal,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const MintIcon(Icons.history_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${goal.data()['title']} history',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close history',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: goal.reference
                    .collection('transactions')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorPanel(
                      message: 'Could not load savings history. Check your connection and try again.',
                    );
                  }
                  if (!snapshot.hasData) return const LoadingPanel();
                  final records = snapshot.data!.docs;
                  if (records.isEmpty) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MintIcon(Icons.savings_outlined, size: 56),
                          const SizedBox(height: 16),
                          const Text(
                            'No savings transactions yet.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your savings activity will appear here.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }
                  return TransactionFilters(
                    records: records,
                    builder: (context, records) => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: records.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 56),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final data = record.data();
                        final timestamp = data['date'];
                        return TransactionDateGroup(
                          at: timestamp,
                          previous: index == 0
                              ? null
                              : records[index - 1].data()['date'],
                          first: index == 0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Card(
                              child: PersonalTransactionTile(
                                data: data,
                                currency: goalCurrency(goal.data()),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> confirmDelete(
  BuildContext context,
  String message,
  Future<void> Function() action,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      icon: Icon(Icons.delete_outline, color: context.atelierError),
      title: const Text('Please confirm'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: context.atelierError),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok == true) {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete item: $e')));
      }
    }
  }
}

Future<void> showGoalTypeChoice(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FormHeading(
                icon: Icons.flag_outlined,
                title: 'Your next milestone',
                detail: 'Choose how you want to save.',
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const MintIcon(Icons.savings_outlined),
                title: const Text('Personal goal'),
                subtitle: const Text('Keep your savings private.'),
                onTap: () {
                  Navigator.pop(sheet);
                  showGoalForm(context);
                },
              ),
              ListTile(
                leading: const MintIcon(Icons.groups_outlined),
                title: const Text('Save Together'),
                subtitle: const Text(
                  'Create a shared goal and invite members.',
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  createSharedGoal(context);
                },
              ),
            ],
          ),
        ),
      ),
    );

Future<void> showGoalForm(
  BuildContext context, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
}) async {
  final form = GlobalKey<FormState>();
  final goalAuth = auth ?? FirebaseAuth.instance;
  final goalDb = firestore ?? FirebaseFirestore.instance;
  final uid = goalAuth.currentUser!.uid;
  final goalRef =
      doc?.reference ??
      goalDb.collection('users').doc(uid).collection('goals').doc();
  final coverTarget = GoalCoverTarget.personal(uid, goalRef.id);
  Uint8List? pendingCover;
  bool goalSaved = false, photoBusy = false;
  String? coverError;
  double? coverProgress;
  String code = doc == null ? 'PHP' : goalCurrency(doc.data());
  final title = TextEditingController(text: doc?.data()['title'] as String?);
  final note = TextEditingController(text: doc?.data()['note'] as String?);
  final target = TextEditingController(
    text: doc == null
        ? ''
        : _number(doc.data()['targetAmount'])
              .toStringAsFixed(CurrencyCatalog.byCode[code]?.digits ?? 2),
  );
  DateTime? deadline = (doc?.data()['deadline'] as Timestamp?)?.toDate();
  final originalDeadline = deadline, originalCode = code;
  final discardGuard = GlobalKey<UnsavedChangesGuardState>();
  bool busy = false;
  final coverSession = goalAuth.authStateChanges().map(
    (user) => user?.uid == uid,
  );
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => GoalCoverRouteGuard(
      active: coverSession,
      child: FormControllerScope(
        controllers: [title, note, target],
        child: StatefulBuilder(
          builder: (ctx, setState) => UnsavedChangesGuard(
            key: discardGuard,
            controllers: [title, note, target],
            enabled: !goalSaved,
            busy: busy || photoBusy,
            hasChanges: () =>
                deadline != originalDeadline ||
                code != originalCode ||
                pendingCover != null,
            child: AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              title: FormHeading(
                icon: Icons.flag_outlined,
                title: doc == null ? 'Create a goal' : 'Edit goal',
                detail: 'Give your next milestone a name and a destination.',
              ),
              content: AbsorbPointer(
                absorbing: busy || photoBusy,
                child: Form(
                  key: form,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (doc == null)
                          GoalCoverFormSection(
                            target: coverTarget,
                            pending: pendingCover,
                            enabled: !goalSaved,
                            onBusyChanged: (value) {
                              if (ctx.mounted) {
                                setState(() => photoBusy = value);
                              }
                            },
                            onPendingChanged: (bytes) =>
                                setState(() => pendingCover = bytes),
                          )
                        else
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: goalRef.snapshots(),
                            builder: (context, snapshot) =>
                                GoalCoverFormSection(
                                  target: coverTarget,
                                  exists: true,
                                  enabled: !busy,
                                  onBusyChanged: (value) {
                                    if (ctx.mounted) {
                                      setState(() => photoBusy = value);
                                    }
                                  },
                                  path: GoalCoverRecord.fromMap(
                                    snapshot.data?.data() ?? doc.data(),
                                    coverTarget,
                                  ).path,
                                ),
                          ),
                        if (goalSaved && coverError != null)
                          Text(
                            'Goal saved. Its cover could not be confirmed. $coverError',
                            style: TextStyle(color: context.atelierError),
                          ),
                        if (busy && goalSaved && pendingCover != null) ...[
                          const Text('Uploading Goal Cover'),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: coverProgress),
                        ],
                        AbsorbPointer(
                          absorbing: goalSaved,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GoalCurrencyField(
                                code: code,
                                enabled: doc == null && !busy,
                                onChanged: (value) =>
                                    setState(() => code = value),
                              ),
                              if (doc != null)
                                Text(
                                  'Stored denomination: $code ? fixed after creation',
                                  style: TextStyle(
                                    color: context.atelierMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              const FieldCaption('Your milestone'),
                              TextFormField(
                                controller: title,
                                decoration: const InputDecoration(
                                  labelText: 'Goal name',
                                  prefixIcon: Icon(Icons.flag_outlined),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Enter a goal name.'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: target,
                                style: SaveTrackDesign.amount.copyWith(
                                  fontSize: 24,
                                  color: context.atelierAccent,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'Target amount ($code)',
                                  prefixText: '$code ',
                                ),
                                validator: (v) {
                                  final n = parseCurrencyAmount(v ?? '', code);
                                  return n == null || !n.positive
                                      ? 'Enter an amount greater than zero.'
                                      : null;
                                },
                              ),
                              const SizedBox(height: 24),
                              const FieldCaption('A little personal detail'),
                              TextFormField(
                                controller: note,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Note (optional)',
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final d = await showSaveTrackDatePicker(
                                    context: ctx,
                                    firstDate: DateTime.now().subtract(
                                      const Duration(days: 1),
                                    ),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 3650),
                                    ),
                                    initialDate:
                                        deadline ??
                                        DateTime.now().add(
                                          const Duration(days: 90),
                                        ),
                                  );
                                  if (d != null) setState(() => deadline = d);
                                },
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  deadline == null
                                      ? 'Set target date'
                                      : _shortDate(deadline!),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy || photoBusy
                      ? null
                      : () => discardGuard.currentState?.requestClose(),
                  child: Text(goalSaved ? 'Done without photo' : 'Cancel'),
                ),
                GradientButton(
                  expand: false,
                  onPressed: busy || photoBusy
                      ? null
                      : () async {
                          if (!goalSaved && !form.currentState!.validate()) {
                            return;
                          }
                          setState(() => busy = true);
                          try {
                            if (goalAuth.currentUser?.uid != uid) {
                              throw const GoalCoverFailure(
                                'Your session changed. Please sign in again.',
                              );
                            }
                            final data = {
                              'title': title.text.trim(),
                              'note': note.text.trim(),
                              'targetAmount': parseCurrencyAmount(
                                target.text,
                                code,
                              )!.toDouble(),
                              'deadline': deadline == null
                                  ? null
                                  : Timestamp.fromDate(deadline!),
                              'updatedAt': FieldValue.serverTimestamp(),
                            };
                            if (doc == null && !goalSaved) {
                              data.addAll({
                                'currencyCode': code,
                                'savedAmount': 0.0,
                                'archived': false,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              await AppRecordRepository(
                                db: goalDb,
                                auth: goalAuth,
                              ).create(
                                uid: uid,
                                collection: 'goals',
                                id: goalRef.id,
                                data: data,
                              );
                              if (ctx.mounted) setState(() => goalSaved = true);
                            } else if (doc != null) {
                              await doc.reference.update(data);
                            }
                            if (pendingCover != null) {
                              await GoalCoverService(
                                FirestoreGoalCoverBackend(),
                              ).replace(
                                coverTarget,
                                pendingCover!,
                                onProgress: (value) {
                                  if (ctx.mounted) {
                                    setState(() => coverProgress = value);
                                  }
                                },
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              setState(() {
                                busy = false;
                                coverError = goalSaved
                                    ? goalCoverError(e)
                                    : null;
                              });
                              if (!goalSaved) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not save the goal. Check your connection and try again.',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: SaveActionLabel(
                    busy: busy,
                    label: goalSaved ? 'Retry Cover Upload' : 'Save',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> showDecreaseSavingsForm(
  BuildContext context,
  String uid,
  QueryDocumentSnapshot<Map<String, dynamic>> goal,
) async {
  if (CurrencyScope.maybeOf(context) != null ||
      goalCurrency(goal.data()) != 'PHP') {
    await showCurrencySavingsForm(context, uid, goal, withdrawal: true);
    return;
  }
  final requestId = goal.reference.collection('transactions').doc().id;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DecreaseSavingsDialog(
      initialGoal: goal.data(),
      goalUpdates: goal.reference.snapshots(),
      formatMoney: _money,
      onConfirm: (amount, note) => decreaseSavings(
        goal: goal.reference,
        uid: uid,
        amount: amount,
        note: note,
        requestId: requestId,
      ),
    ),
  );
  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Savings decreased successfully.')),
    );
  }
}

Future<void> showDepositForm(
  BuildContext context,
  String uid,
  QueryDocumentSnapshot<Map<String, dynamic>> goal,
) => showCurrencySavingsForm(context, uid, goal);

Future<void> showCurrencySavingsForm(
  BuildContext context,
  String uid,
  QueryDocumentSnapshot<Map<String, dynamic>> goal, {
  bool withdrawal = false,
  String? initialAmount,
  bool guardWidgetAccount = false,
}) async {
  final requestId = goal.reference.collection('transactions').doc().id;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      final dialog = CurrencySavingsDialog(
        initialGoal: goal.data(),
        goalUpdates: goal.reference.snapshots(),
        withdrawal: withdrawal,
        initialAmount: initialAmount,
        onConfirm: (entry, note) => recordCurrencySavings(
          goal: goal.reference,
          uid: uid,
          entry: entry,
          note: note,
          requestId: requestId,
          withdrawal: withdrawal,
        ),
      );
      return guardWidgetAccount
          ? WidgetAccountGuard(uid: uid, child: dialog)
          : dialog;
    },
  );
  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          withdrawal
              ? 'Savings decreased successfully.'
              : 'Savings added successfully.',
        ),
      ),
    );
  }
}

Future<void> showTaskForm(
  BuildContext context, {
  String? dateKey,
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  String? widgetAccount,
}) async {
  final form = GlobalKey<FormState>();
  final reminderCoordinator = ReminderScope.maybeOf(context);
  final account = reminderCoordinator?.uid;
  var taskReference =
      doc?.reference ?? (account == null ? null : _tasks(account).doc());
  ReminderConfiguration? reminderDraft = taskReference == null
      ? null
      : reminderCoordinator?.configurations['task_${taskReference.id}'];
  bool reminderChanged = false;
  bool taskSaved = doc != null;
  bool savedThisSession = false;
  final title = TextEditingController(text: doc?.data()['title']?.toString());
  final time = TextEditingController(text: doc?.data()['time']?.toString());
  String priority = doc?.data()['priority']?.toString() ?? 'Normal';
  final priorities = ['Low', 'Normal', 'High'];
  if (!priorities.contains(priority)) priorities.add(priority);
  String day =
      doc?.data()['dateKey'] as String? ?? dateKey ?? _dateKey(DateTime.now());
  final originalDay = day, originalPriority = priority;
  final discardGuard = GlobalKey<UnsavedChangesGuardState>();
  bool busy = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => WidgetAccountGuard(
      uid: widgetAccount,
      child: FormControllerScope(
        controllers: [title, time],
        child: StatefulBuilder(
          builder: (ctx, setState) => UnsavedChangesGuard(
            key: discardGuard,
            controllers: [title, time],
            busy: busy,
            enabled: !savedThisSession,
            hasChanges: () =>
                day != originalDay ||
                priority != originalPriority ||
                reminderChanged,
            child: AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              title: FormHeading(
                icon: Icons.edit_calendar_outlined,
                title: doc == null ? 'Add a task' : 'Edit task',
                detail: 'Make space for what matters in your day.',
              ),
              content: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldCaption('The plan'),
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Task',
                        prefixIcon: Icon(Icons.checklist_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a task.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: time,
                      decoration: const InputDecoration(
                        labelText: 'Time (optional)',
                        prefixIcon: Icon(Icons.schedule_outlined),
                        hintText: 'e.g. 9:30 AM',
                      ),
                    ),
                    const SizedBox(height: 24),
                    const FieldCaption('When & how important'),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(Icons.low_priority),
                      ),
                      items: priorities
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => priority = v ?? 'Normal'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final d = DateTime.tryParse(day) ?? DateTime.now();
                        final chosen = await showSaveTrackDatePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: d,
                        );
                        if (chosen != null) {
                          setState(() => day = _dateKey(chosen));
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_shortDate(DateTime.parse(day))),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.notifications_outlined),
                      label: Text(
                        reminderDraft == null
                            ? 'Set Task Reminder'
                            : reminderSummary(ctx, reminderDraft!),
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                              if (account == null || taskReference == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sign in to configure a task reminder.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final target = ReminderTarget.fromData(
                                ReminderTargetType.task,
                                taskReference!.id,
                                {
                                  'title': title.text.trim().isEmpty
                                      ? 'Your task'
                                      : title.text.trim(),
                                  'time': time.text.trim(),
                                  'dateKey': day,
                                  'completed': doc?.data()['completed'] == true,
                                },
                              );
                              final draft = await configureReminderDraft(
                                ctx,
                                uid: account,
                                target: target,
                                initial: reminderDraft,
                              );
                              if (draft != null && ctx.mounted) {
                                setState(() {
                                  reminderDraft = draft;
                                  reminderChanged = true;
                                });
                              }
                            },
                    ),
                    if (reminderDraft != null)
                      Text(
                        'Reminder time is separate from the task schedule. Save the task to apply reminder changes.',
                        style: TextStyle(
                          color: context.atelierMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => discardGuard.currentState?.requestClose(),
                  child: const Text('Cancel'),
                ),
                GradientButton(
                  expand: false,
                  onPressed: busy
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          setState(() => busy = true);
                          try {
                            final activeAccount = reminderCoordinator != null
                                ? reminderCoordinator.uid
                                : doc == null
                                ? FirebaseAuth.instance.currentUser!.uid
                                : null;
                            if (account != null && activeAccount != account) {
                              throw const ReminderFailure(
                                'Your account changed. Open the task again.',
                              );
                            }
                            taskReference ??= _tasks(activeAccount!).doc();
                            final data = {
                              'title': title.text.trim(),
                              'time': time.text.trim(),
                              'priority': priority,
                              'dateKey': day,
                              'updatedAt': FieldValue.serverTimestamp(),
                            };
                            final target = ReminderTarget.fromData(
                              ReminderTargetType.task,
                              doc?.id ?? taskReference!.id,
                              {
                                ...data,
                                'completed': doc?.data()['completed'] == true,
                              },
                            );
                            if (reminderChanged &&
                                reminderDraft?.enabled == true) {
                              final zone = reminderCoordinator?.zone;
                              if (zone == null ||
                                  const ReminderTimeCalculator().next(
                                        reminderDraft!,
                                        target,
                                        zone,
                                        DateTime.now(),
                                      ) ==
                                      null) {
                                throw const ReminderFailure(
                                  'Choose a valid future reminder before saving.',
                                );
                              }
                            }
                            if (!taskSaved) {
                              data.addAll({
                                'completed': false,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              await AppRecordRepository().create(
                                uid: activeAccount!,
                                collection: 'tasks',
                                id: taskReference!.id,
                                data: data,
                              );
                            } else {
                              await taskReference!.update(data);
                            }
                            taskSaved = true;
                            savedThisSession = true;
                            if (reminderChanged && reminderDraft != null) {
                              if (reminderCoordinator == null) {
                                throw const ReminderFailure(
                                  'Task saved. Reminder service unavailable.',
                                );
                              }
                              await reminderCoordinator.save(
                                reminderDraft!,
                                target,
                              );
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      reminderCoordinator
                                          .status(reminderDraft!.key)
                                          .message,
                                    ),
                                  ),
                                );
                              }
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setState(() => busy = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${savedThisSession && reminderChanged ? 'Task saved; reminder change could not be confirmed' : 'Could not save task'}: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: SaveActionLabel(busy: busy, label: 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openReminderTarget(
  ReminderCoordinator coordinator,
  ReminderPayload payload,
) async {
  final navigator = _appNavigator.currentState;
  if (navigator == null) return;
  void unavailable() {
    final context = _appNavigator.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This reminder item is no longer available to your account.',
          ),
        ),
      );
    }
  }

  if (coordinator.uid != payload.uid ||
      FirebaseAuth.instance.currentUser?.uid != payload.uid) {
    unavailable();
    return;
  }
  try {
    final target = await coordinator.repository.target(
      payload.uid,
      payload.type,
      payload.targetId,
    );
    if (target == null || !target.available || coordinator.uid != payload.uid) {
      unavailable();
      return;
    }
    if (payload.type == ReminderTargetType.sharedGoal) {
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => SharedGoalDetailsScreen(goalId: payload.targetId),
          ),
        ),
      );
    } else {
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                _ReminderItemScreen(payload: payload, target: target),
          ),
        ),
      );
    }
  } catch (_) {
    unavailable();
  }
}

/// Reuses the existing goal card and planner, guarded across account changes.
class _ReminderItemScreen extends StatelessWidget {
  const _ReminderItemScreen({required this.payload, required this.target});
  final ReminderPayload payload;
  final ReminderTarget target;
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, session) => Scaffold(
      appBar: AppBar(
        title: Text(
          payload.type == ReminderTargetType.task ? 'Planner' : 'Goal details',
        ),
      ),
      body: session.data?.uid != payload.uid
          ? const Center(child: Text('Sign in to access this item.'))
          : payload.type == ReminderTargetType.task
          ? PlannerScreen(initialDate: target.taskDay)
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _goals(payload.uid)
                  .where(FieldPath.documentId, isEqualTo: payload.targetId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('This goal is unavailable.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('This goal is no longer available.'),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GoalCard(uid: payload.uid, doc: snapshot.data!.docs.first),
                  ],
                );
              },
            ),
    ),
  );
}

/// All widget arguments are identifiers. Server authorization precedes the
/// existing screens and confirmation workflows; this router performs no writes.
Future<void> _openHomeWidgetTarget(
  HomeWidgetController controller,
  WidgetLaunch launch,
) async {
  final navigator = _appNavigator.currentState;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (navigator == null || uid == null || uid != controller.uid) return;
  void unavailable() {
    final context = _appNavigator.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This widget item is unavailable. Check your connection or reconfigure the widget.',
          ),
        ),
      );
    }
  }

  try {
    await controller.reload();
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;
    final instance = controller.instance(launch.id);
    if (instance == null) {
      unavailable();
      return;
    }
    if (launch.action == WidgetLaunchAction.configure) {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => WidgetAccountGuard(
            uid: uid,
            child: WidgetConfigurationScreen(
              instance: instance,
              launcher: launch.launcher,
            ),
          ),
        ),
      );
      return;
    }
    final config = instance.config;
    if (config == null || config.uid != uid) {
      unavailable();
      return;
    }
    if (launch.action == WidgetLaunchAction.dashboard) {
      navigator.popUntil((route) => route.isFirst);
      _homeShellKey.currentState?.selectTab(0);
      return;
    }
    if (launch.action == WidgetLaunchAction.planner ||
        launch.action == WidgetLaunchAction.task) {
      if (!config.needsPlanner) {
        unavailable();
        return;
      }
      if (launch.action == WidgetLaunchAction.task) {
        final tasks = await _tasks(uid)
            .where(FieldPath.documentId, isEqualTo: launch.taskId)
            .get(const GetOptions(source: Source.server));
        if (FirebaseAuth.instance.currentUser?.uid != uid ||
            tasks.docs.isEmpty) {
          unavailable();
          return;
        }
        // Existing task form, opened for review; nothing is marked complete.
        final context = navigator.context;
        if (!context.mounted) return;
        await showTaskForm(context, doc: tasks.docs.single, widgetAccount: uid);
      } else {
        navigator.popUntil((route) => route.isFirst);
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  WidgetAccountGuard(uid: uid, child: const PlannerScreen()),
            ),
          ),
        );
      }
      return;
    }
    if (launch.action == WidgetLaunchAction.coach) {
      navigator.popUntil((route) => route.isFirst);
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                WidgetAccountGuard(uid: uid, child: const AiCoachScreen()),
          ),
        ),
      );
      return;
    }
    final ref = config.goal;
    if (ref == null) {
      unavailable();
      return;
    }
    Map<String, dynamic> data;
    QueryDocumentSnapshot<Map<String, dynamic>>? personal;
    if (ref.shared) {
      final repository = SharedSavingsRepository();
      final goal = await repository
          .goal(ref.id)
          .get(const GetOptions(source: Source.server));
      final member = await repository
          .goal(ref.id)
          .collection('members')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      data = goal.data() ?? {};
      if (member.data()?['status'] != 'active' ||
          data['memberIds'] is! List ||
          !(data['memberIds'] as List).contains(uid)) {
        unavailable();
        return;
      }
    } else {
      final result = await _goals(uid)
          .where(FieldPath.documentId, isEqualTo: ref.id)
          .get(const GetOptions(source: Source.server));
      if (result.docs.isEmpty) {
        unavailable();
        return;
      }
      personal = result.docs.single;
      data = personal.data();
    }
    if (FirebaseAuth.instance.currentUser?.uid != uid ||
        controller.uid != uid) {
      return;
    }
    if (launch.action == WidgetLaunchAction.save) {
      final currency = ref.shared ? 'PHP' : goalCurrency(data);
      if (currency != config.currency ||
          data['archived'] == true ||
          data['status'] == 'archived') {
        unavailable();
        return;
      }
      String? initialAmount;
      if (launch.preset != null) {
        if (launch.preset! >= config.presets.length) {
          unavailable();
          return;
        }
        initialAmount = config.presets[launch.preset!];
        if (parseCurrencyAmount(initialAmount, currency)?.positive != true) {
          unavailable();
          return;
        }
      }
      if (ref.shared) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => WidgetAccountGuard(
              uid: uid,
              child: SharedContributionScreen(
                goal: SharedSavingsGoal(ref.id, data),
                initialAmount: initialAmount,
              ),
            ),
          ),
        );
      } else {
        final context = navigator.context;
        if (!context.mounted) return;
        await showCurrencySavingsForm(
          context,
          uid,
          personal!,
          initialAmount: initialAmount,
          guardWidgetAccount: true,
        );
      }
      await controller.reload();
    } else {
      navigator.popUntil((route) => route.isFirst);
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => WidgetAccountGuard(
              uid: uid,
              child: ref.shared
                  ? SharedGoalDetailsScreen(goalId: ref.id)
                  : PersonalGoalDetailsScreen(uid: uid, goalId: ref.id),
            ),
          ),
        ),
      );
    }
  } catch (_) {
    unavailable();
  }
}
