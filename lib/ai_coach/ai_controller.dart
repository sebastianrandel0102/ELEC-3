import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ai_domain.dart';
import 'ai_gateway.dart';
import 'firebase_ai_gateway.dart' show mapAiError;

class AiSession {
  AiSession(this.mode, this.id);
  final AiMode mode;
  final String id;
  final List<AiMessage> _messages = [];
  List<AiMessage> get messages => List.unmodifiable(_messages);
  AiStatus status = AiStatus.idle;
  AiFailure? failure;
  AiLocalFacts? facts;
  AiApprovedContext? approval;
}

/// In-memory, user-scoped state. No Firestore writer or model chat-session memory.
class AiCoachController extends ChangeNotifier {
  AiCoachController({
    required this.gateway,
    required this.currentUid,
    this.contextSource,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    _ownerUid = currentUid();
    for (final mode in AiMode.values) {
      _sessions[mode] = AiSession(mode, _id());
    }
  }
  final AiGateway gateway;
  final AiContextSource? contextSource;
  final String? Function() currentUid;
  final DateTime Function() now;
  final _sessions = <AiMode, AiSession>{};
  final streamingChanges = ValueNotifier<int>(0);
  late String? _ownerUid;
  AiMode mode = AiMode.askAnything;
  AiSession get active => _sessions[mode]!;
  AiSession session(AiMode mode) => _sessions[mode]!;
  bool get busy =>
      active.status == AiStatus.preparing ||
      active.status == AiStatus.streaming;
  bool providerAcknowledged = false;
  int _serial = 0, _epoch = 0;
  bool _disposed = false;
  DateTime? _lastSent;
  StreamSubscription<String>? _stream;
  StreamSubscription<void>? _contextWatch;
  Timer? _consentExpiry;
  Timer? _deadline, _batch;
  Completer<void>? _completion;
  String _id() => '${now().microsecondsSinceEpoch}-${_serial++}';

  void acknowledgeProvider() {
    providerAcknowledged = true;
    notifyListeners();
  }

  Future<void> checkConnection() async {
    final provider = gateway;
    if (provider is AiGatewayPreflight) {
      await (provider as AiGatewayPreflight).prepare(forceRefresh: true);
    }
  }

  void clearFailure() {
    active.failure = null;
    if (!busy) active.status = AiStatus.idle;
    notifyListeners();
  }

  void switchMode(AiMode next) {
    if (mode == next || _disposed) return;
    cancel();
    mode = next;
    notifyListeners();
  }

  void newChat() {
    cancel();
    if (mode == AiMode.coach) _releaseContext();
    _sessions[mode] = AiSession(mode, _id());
    notifyListeners();
  }

  void selectFacts(AiLocalFacts facts, {required bool approve}) {
    if (mode != AiMode.coach ||
        facts.ownerUid != currentUid() ||
        (approve && facts.shared)) {
      throw const AiFailure(
        AiErrorKind.privacy,
        'This context cannot be shared.',
      );
    }
    newChat(); // Changing subjects cannot reuse replies about an old subject.
    active.facts = facts;
    if (approve) {
      active.approval = AiApprovedContext(
        facts: facts,
        sessionId: active.id,
        approvedAt: now(),
      );
      _consentExpiry = Timer(AiConfig.consentLifetime, revokeContext);
    }
    final source = contextSource;
    if (source is AiContextWatcher) {
      _contextWatch = (source as AiContextWatcher).invalidations(facts).listen((
        _,
      ) {
        revokeContext();
      }, onError: (Object _) => revokeContext());
    }
    notifyListeners();
  }

  void revokeContext() {
    // Purge Coach history too: previous model replies may paraphrase context.
    if (mode == AiMode.coach) cancel();
    _releaseContext();
    _sessions[AiMode.coach] = AiSession(AiMode.coach, _id());
    notifyListeners();
  }

  void invalidateIdentity() {
    cancel();
    _releaseContext();
    _ownerUid = currentUid();
    providerAcknowledged = false;
    for (final mode in AiMode.values) {
      _sessions[mode] = AiSession(mode, _id());
    }
    notifyListeners();
  }

  Future<void> send(String question, {bool retry = false}) async {
    if (_disposed || busy) return;
    final uid = currentUid();
    if (uid == null || uid.isEmpty || uid != _ownerUid) {
      invalidateIdentity();
      active.failure = const AiFailure(
        AiErrorKind.authentication,
        'Sign in again to use SaveTrack AI.',
      );
      active.status = AiStatus.failed;
      notifyListeners();
      return;
    }
    final session = active;
    try {
      if (!providerAcknowledged) {
        throw const AiFailure(
          AiErrorKind.privacy,
          'Read the AI privacy notice before sending a question.',
        );
      }
      if (_lastSent != null &&
          now().difference(_lastSent!) < AiConfig.cooldown) {
        throw const AiFailure(
          AiErrorKind.quota,
          'Please wait a few seconds before sending again.',
        );
      }
      // Validate before any context reads; Ask Anything never invokes the source.
      buildAiRequest(
        mode: mode,
        sessionId: session.id,
        uid: uid,
        question: question,
        history: session.messages,
        context: session.approval,
        now: now(),
      );
    } catch (error) {
      if (error is AiFailure &&
          error.kind == AiErrorKind.privacy &&
          session.approval != null) {
        revokeContext();
      }
      active.failure = mapAiError(error);
      active.status = AiStatus.failed;
      notifyListeners();
      return;
    }
    final epoch = ++_epoch;
    session.status = AiStatus.preparing;
    session.failure = null;
    final completion = _completion = Completer<void>();
    notifyListeners();
    _deadline = Timer(AiConfig.requestTimeout, () {
      if (_valid(epoch, session)) {
        _finish(
          session,
          const AiFailure(
            AiErrorKind.offline,
            'AI took too long to respond. Check your connection and retry.',
          ),
        );
      }
    });
    try {
      final provider = gateway;
      if (provider is AiGatewayPreflight) {
        await (provider as AiGatewayPreflight).prepare();
        if (!_valid(epoch, session)) return;
      }
      if (session.approval != null) {
        final valid = await contextSource
            ?.isCurrent(session.approval!.facts)
            .timeout(AiConfig.contextReadTimeout);
        if (!_valid(epoch, session)) return;
        if (valid != true) {
          revokeContext();
          active.failure = const AiFailure(
            AiErrorKind.privacy,
            'Selected data changed or access was revoked. Select and review it again.',
          );
          active.status = AiStatus.failed;
          notifyListeners();
          return;
        }
      }
      if (!_valid(epoch, session)) return;
      session.approval?.validate(
        uid: currentUid()!,
        session: session.id,
        now: now(),
      );
      if (retry &&
          session._messages.length >= 2 &&
          session._messages.last.role == AiRole.assistant &&
          session._messages.last.status != AiMessageStatus.complete) {
        session._messages.removeRange(
          session._messages.length - 2,
          session._messages.length,
        );
      }
      final request = buildAiRequest(
        mode: session.mode,
        sessionId: session.id,
        uid: currentUid()!,
        question: question,
        history: session.messages,
        context: session.approval,
        now: now(),
      );
      _lastSent = now();
      session._messages.addAll([
        AiMessage(
          id: _id(),
          sessionId: session.id,
          mode: session.mode,
          role: AiRole.user,
          text: question.trim(),
        ),
        AiMessage(
          id: _id(),
          sessionId: session.id,
          mode: session.mode,
          role: AiRole.assistant,
          text: '',
          status: AiMessageStatus.streaming,
        ),
      ]);
      if (session._messages.length > AiConfig.maxTranscriptMessages) {
        session._messages.removeRange(0, 2);
      }
      session.status = AiStatus.streaming;
      notifyListeners();
      _stream = gateway
          .generate(request)
          .listen(
            (chunk) {
              if (!_valid(epoch, session) || chunk.isEmpty) return;
              final last = session._messages.last;
              final text = last.text + chunk;
              if (text.length > AiConfig.maxResponseCharacters) {
                _finish(
                  session,
                  const AiFailure(
                    AiErrorKind.unavailable,
                    'This response exceeded the reading limit. Ask for a shorter answer.',
                  ),
                );
                return;
              }
              session._messages[session._messages.length - 1] = last.copyWith(
                text: text,
              );
              _batch ??= Timer(const Duration(milliseconds: 40), () {
                _batch = null;
                if (_valid(epoch, session)) streamingChanges.value++;
              });
            },
            onError: (Object error) {
              if (_valid(epoch, session)) _finish(session, mapAiError(error));
            },
            onDone: () {
              if (!_valid(epoch, session)) return;
              _finish(
                session,
                session._messages.last.text.trim().isEmpty
                    ? const AiFailure(
                        AiErrorKind.empty,
                        'The model returned no text. Try rephrasing or retry.',
                      )
                    : null,
              );
            },
          );
      await completion.future;
    } catch (error) {
      if (_valid(epoch, session)) _finish(session, mapAiError(error));
    }
  }

  Future<void> retry() async {
    if (busy || active._messages.length < 2) return;
    final last = active._messages.last;
    if (last.role != AiRole.assistant ||
        last.status == AiMessageStatus.complete) {
      return;
    }
    await send(active._messages[active._messages.length - 2].text, retry: true);
  }

  bool _valid(int epoch, AiSession session) {
    if (_disposed || epoch != _epoch || !identical(active, session)) {
      return false;
    }
    if (currentUid() != _ownerUid || _ownerUid == null) {
      invalidateIdentity();
      return false;
    }
    return true;
  }

  void _releaseContext() {
    _consentExpiry?.cancel();
    _consentExpiry = null;
    unawaited(_contextWatch?.cancel());
    _contextWatch = null;
  }

  void _finish(AiSession session, AiFailure? failure) {
    ++_epoch;
    _deadline?.cancel();
    _batch?.cancel();
    _batch = null;
    unawaited(_stream?.cancel());
    _stream = null;
    if (session._messages.isNotEmpty &&
        session._messages.last.status == AiMessageStatus.streaming) {
      session._messages[session._messages.length - 1] = session._messages.last
          .copyWith(
            status: failure == null
                ? AiMessageStatus.complete
                : AiMessageStatus.failed,
          );
    }
    session.failure = failure;
    session.status = failure == null ? AiStatus.idle : AiStatus.failed;
    _complete();
    if (!_disposed) {
      streamingChanges.value++;
      notifyListeners();
    }
  }

  void _complete() {
    if (_completion != null && !_completion!.isCompleted) {
      _completion!.complete();
    }
    _completion = null;
  }

  void cancel() {
    if (_disposed) return;
    ++_epoch;
    _deadline?.cancel();
    _batch?.cancel();
    _batch = null;
    unawaited(_stream?.cancel());
    _stream = null;
    if (active._messages.isNotEmpty &&
        active._messages.last.status == AiMessageStatus.streaming) {
      active._messages[active._messages.length - 1] = active._messages.last
          .copyWith(status: AiMessageStatus.canceled);
    }
    active.status = AiStatus.idle;
    _complete();
    notifyListeners();
  }

  @override
  void dispose() {
    cancel();
    _releaseContext();
    _disposed = true;
    for (final session in _sessions.values) {
      session._messages.clear();
      session.approval = null;
      session.facts = null;
    }
    streamingChanges.dispose();
    super.dispose();
  }
}
