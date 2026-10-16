import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth_service.dart';

import 'widget_bridge.dart';
import 'widget_controller.dart';
import 'widget_data_source.dart';
import 'widget_models.dart';

class HomeWidgetScope extends InheritedNotifier<HomeWidgetController> {
  const HomeWidgetScope({
    super.key,
    required HomeWidgetController controller,
    required super.child,
  }) : super(notifier: controller);
  static HomeWidgetController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeWidgetScope>()?.notifier;
  static HomeWidgetController of(BuildContext context) => maybeOf(context)!;
}

class HomeWidgetHost extends StatefulWidget {
  const HomeWidgetHost({
    super.key,
    required this.child,
    required this.openTarget,
  });
  final Widget child;
  final Future<void> Function(HomeWidgetController, WidgetLaunch) openTarget;
  @override
  State<HomeWidgetHost> createState() => _HomeWidgetHostState();
}

class _HomeWidgetHostState extends State<HomeWidgetHost>
    with WidgetsBindingObserver {
  late final bridge = HomeWidgetBridge();
  late final controller = HomeWidgetController(
    bridge: bridge,
    source: FirestoreWidgetDataSource(),
  );
  StreamSubscription<User?>? _auth;
  Timer? _dateCheck;
  WidgetLaunch? _pending;
  bool _routing = false, _ready = false, _foreground = true;
  String? _lastKey;
  String? _activeKey;
  DateTime? _lastTap;
  @override
  void initState() {
    super.initState();
    if (!bridge.supported) return;
    WidgetsBinding.instance.addObserver(this);
    AuthService.instance.googleSignInInProgress.addListener(_drain);
    bridge.onLaunch = (launch) {
      final key =
          '${launch.id}/${launch.action}/${launch.preset}/${launch.taskId}';
      final now = DateTime.now();
      if (_routing && key == _activeKey) return;
      if (key == _lastKey &&
          _lastTap != null &&
          now.difference(_lastTap!) < const Duration(milliseconds: 800)) {
        return;
      }
      _lastKey = key;
      _lastTap = now;
      _pending = launch;
      _drain();
    };
    unawaited(bridge.initialize().catchError((Object _) {}));
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) async {
      _ready = false;
      try {
        await controller.switchAccount(user?.uid);
        if (mounted && controller.uid == user?.uid) {
          _ready = user != null;
          _drain();
        }
      } catch (_) {
        /* Retry on resume; native snapshots remain invalidated. */
      }
    });
    _dateCheck = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_foreground) controller.checkDate();
    });
  }

  void _drain() {
    if (!mounted ||
        !_ready ||
        _routing ||
        _pending == null ||
        AuthService.instance.googleSignInInProgress.value) {
      return;
    }
    // AuthGate and the root navigator must have completed their frame first.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !_ready ||
          _routing ||
          _pending == null ||
          AuthService.instance.googleSignInInProgress.value) {
        return;
      }
      final launch = _pending!;
      _pending = null;
      _routing = true;
      _activeKey =
          '${launch.id}/${launch.action}/${launch.preset}/${launch.taskId}';
      try {
        await widget.openTarget(controller, launch);
      } finally {
        _routing = false;
        _activeKey = null;
        _drain();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && bridge.supported) {
      controller.checkDate();
      if (!_ready && FirebaseAuth.instance.currentUser != null) {
        unawaited(
          controller
              .switchAccount(FirebaseAuth.instance.currentUser!.uid)
              .then((_) {
                if (!mounted) return;
                _ready =
                    controller.uid == FirebaseAuth.instance.currentUser?.uid;
                _drain();
              })
              .catchError((Object _) {}),
        );
      } else {
        unawaited(controller.reload().catchError((Object _) {}));
      }
      _drain();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (bridge.supported) {
      AuthService.instance.googleSignInInProgress.removeListener(_drain);
    }
    _dateCheck?.cancel();
    unawaited(_auth?.cancel());
    bridge.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HomeWidgetScope(controller: controller, child: widget.child);
}

/// Pushed routes and confirmation dialogs cannot retain another account's UI.
class WidgetAccountGuard extends StatelessWidget {
  const WidgetAccountGuard({super.key, required this.uid, required this.child});
  final String? uid;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (uid == null) return child;
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, session) => session.data?.uid == uid
          ? child
          : Scaffold(
              appBar: AppBar(title: const Text('SaveTrack')),
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Return to sign in'),
                ),
              ),
            ),
    );
  }
}
