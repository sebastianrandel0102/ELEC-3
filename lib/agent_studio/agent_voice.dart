import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'agent_domain.dart';
import 'intelligence/voice_locale_repository.dart';
import 'intelligence/agent_language.dart';

enum AgentVoiceState { ready, starting, listening, reviewing, speaking, error }

abstract interface class AgentVoiceAdapter {
  Stream<Map<String, dynamic>> get events;
  Future<Map<String, dynamic>> capabilities();
  Future<void> start({
    required String session,
    required String locale,
    required bool onDevice,
  });
  Future<void> startSystem({required String session, required String locale});
  Future<void> stop();
  Future<void> cancel();
  Future<void> speak({
    required String session,
    required String text,
    required String locale,
    required String voice,
    required double rate,
  });
  Future<void> stopSpeaking();
  Future<void> dispose();
}

class AndroidAgentVoice implements AgentVoiceAdapter {
  AndroidAgentVoice() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'event' && !_events.isClosed) {
        _events.add(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
  }
  static const _channel = MethodChannel('savetrack/agent_voice');
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
  @override
  Future<Map<String, dynamic>> capabilities() async => supported
      ? Map<String, dynamic>.from(
          await _channel.invokeMethod<Map>('capabilities') ?? {},
        )
      : {
          'recognition': false,
          'tts': false,
          'onDevice': false,
          'systemRecognition': false,
          'languages': <String>[],
          'voices': <String>[],
        };
  @override
  Future<void> start({
    required String session,
    required String locale,
    required bool onDevice,
  }) async {
    await _channel.invokeMethod<void>('start', {
      'session': session,
      'locale': locale,
      'onDevice': onDevice,
    });
  }

  @override
  Future<void> startSystem({
    required String session,
    required String locale,
  }) async {
    await _channel.invokeMethod<void>('startSystem', {
      'session': session,
      'locale': locale,
      'onDevice': false,
    });
  }

  @override
  Future<void> stop() async {
    if (supported) await _channel.invokeMethod<void>('stop');
  }

  @override
  Future<void> cancel() async {
    if (supported) await _channel.invokeMethod<void>('cancel');
  }

  @override
  Future<void> speak({
    required String session,
    required String text,
    required String locale,
    required String voice,
    required double rate,
  }) async {
    await _channel.invokeMethod<void>('speak', {
      'session': session,
      'text': text,
      'locale': locale,
      'voice': voice,
      'rate': rate,
    });
  }

  @override
  Future<void> stopSpeaking() async {
    if (supported) await _channel.invokeMethod<void>('stopSpeaking');
  }

  @override
  Future<void> dispose() async {
    if (supported) await _channel.invokeMethod<void>('release');
    _channel.setMethodCallHandler(null);
    await _events.close();
  }
}

class AgentVoiceController extends ChangeNotifier {
  AgentVoiceController(this.adapter) {
    _events = adapter.events.listen(_event);
  }
  final AgentVoiceAdapter adapter;
  late final StreamSubscription<Map<String, dynamic>> _events;
  AgentVoiceState state = AgentVoiceState.ready;
  String transcript = '', error = '', _session = '';
  String originalTranscript = '', recognitionLocale = '';
  List<String> alternatives = const [];
  List<double?> confidences = const [];
  int? nativeErrorCode;
  bool usingSystemDialog = false;
  bool _startingSystem = false;
  Map<String, dynamic> availability = {};
  double amplitude = 0;
  bool _disposed = false;
  bool get recording =>
      state == AgentVoiceState.starting || state == AgentVoiceState.listening;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final refreshed = await adapter.capabilities();
      availability = {...availability, ...refreshed};
      if (refreshed['onDevice'] != true) {
        availability.remove('onDeviceLanguages');
      }
    } catch (_) {
      error = 'Voice services are unavailable. You can keep typing.';
    }
    _notify();
  }

  void _event(Map<String, dynamic> event) {
    if (_disposed || event['session'] != _session) return;
    switch (event['type']) {
      case 'listening':
        error = '';
        nativeErrorCode = null;
        state = AgentVoiceState.listening;
      case 'partial':
        if (!recording) return;
        transcript = event['text'] as String? ?? '';
      case 'final':
        if (!recording) return;
        transcript = event['text'] as String? ?? '';
        originalTranscript = transcript;
        alternatives = List.unmodifiable(
          (event['alternatives'] as List? ?? []).whereType<String>().take(5),
        );
        confidences = List.unmodifiable(
          (event['confidences'] as List? ?? [])
              .take(5)
              .map((n) => n is num && n >= 0 && n <= 1 ? n.toDouble() : null),
        );
        usingSystemDialog = false;
        error = '';
        nativeErrorCode = null;
        state = AgentVoiceState.reviewing;
      case 'amplitude':
        amplitude = ((event['value'] as num?)?.toDouble() ?? 0).clamp(0, 1);
      case 'speaking':
        state = AgentVoiceState.speaking;
      case 'done':
        state = AgentVoiceState.ready;
      case 'error':
        usingSystemDialog = false;
        nativeErrorCode = event['nativeCode'] as int?;
        error =
            event['message'] as String? ??
            'Voice was interrupted. Try again or type.';
        state = AgentVoiceState.error;
      case 'interrupted':
        usingSystemDialog = false;
        state = error.isNotEmpty
            ? AgentVoiceState.error
            : transcript.isNotEmpty
            ? AgentVoiceState.reviewing
            : AgentVoiceState.ready;
      case 'support':
        availability = {
          ...availability,
          'onDeviceLanguages': (event['onDeviceLanguages'] as List? ?? [])
              .cast<String>(),
        };
      case 'systemCanceled':
        usingSystemDialog = false;
        state = transcript.isEmpty
            ? AgentVoiceState.ready
            : AgentVoiceState.reviewing;
    }
    _notify();
  }

  Future<void> start(AgentSettings settings) async {
    if (_disposed || recording || _startingSystem) return;
    nativeErrorCode = null;
    if (availability['recognition'] != true) {
      error =
          'Speech recognition is unavailable on this device. Use text input.';
      state = AgentVoiceState.error;
      _notify();
      return;
    }
    if (settings.onDevice && availability['onDevice'] != true) {
      error = 'On-device recognition is unavailable. Turn it off to use the device speech service, or type.';
      nativeErrorCode = null;
      state = AgentVoiceState.error;
      _notify();
      return;
    }
    final locale = const VoiceLocaleRepository().recognition(
      settings,
      availability,
    );
    if (locale == null) {
      error = 'The selected recognition language is not reported by this speech service. Choose an available language in Voice settings, or type.';
      state = AgentVoiceState.error;
      _notify();
      return;
    }
    recognitionLocale = locale;
    _session = agentId();
    final session = _session;
    state = AgentVoiceState.starting;
    transcript = '';
    originalTranscript = '';
    alternatives = const [];
    confidences = const [];
    error = '';
    nativeErrorCode = null;
    amplitude = 0;
    _notify();
    try {
      await adapter.stopSpeaking();
      if (_disposed ||
          _session != session ||
          state != AgentVoiceState.starting) {
        return;
      }
      await adapter.start(
        session: session,
        locale: locale,
        onDevice: settings.onDevice,
      );
    } on PlatformException catch (failure) {
      if (!_disposed && _session == session) {
        state = AgentVoiceState.error;
        error = failure.message ?? 'The Android speech service could not start. Open Voice settings or use text input.';
        _notify();
      }
    } catch (_) {
      if (!_disposed && _session == session) {
        state = AgentVoiceState.error;
        error = 'Could not start recognition. Check microphone permission and installed speech services.';
        _notify();
      }
    }
  }

  Future<void> startSystem(AgentSettings settings) async {
    if (_disposed || recording || usingSystemDialog || _startingSystem) return;
    if (settings.onDevice) {
      error = 'The Android speech dialog may use its provider. Turn off Require on-device recognition first if you want to allow it.';
      state = AgentVoiceState.error;
      _notify();
      return;
    }
    if (availability['systemRecognition'] != true) {
      error = 'No Android speech dialog is available. Use text input or check the installed speech provider.';
      state = AgentVoiceState.error;
      _notify();
      return;
    }
    final locale = const VoiceLocaleRepository().recognition(
      settings,
      availability,
    );
    if (locale == null) {
      error = 'The selected recognition language is unavailable. Choose a reported language or use text.';
      state = AgentVoiceState.error;
      _notify();
      return;
    }
    recognitionLocale = locale;
    _startingSystem = true;
    String? session;
    try {
      final stopping = silence();
      final preparation = _session;
      await stopping;
      if (_disposed || preparation != _session) return;
      _session = agentId();
      session = _session;
      error = '';
      nativeErrorCode = null;
      transcript = '';
      originalTranscript = '';
      alternatives = const [];
      state = AgentVoiceState.starting;
      usingSystemDialog = true;
      _notify();
      await adapter.startSystem(session: session, locale: locale);
    } catch (failure) {
      if (!_disposed && _session == session) {
        usingSystemDialog = false;
        state = AgentVoiceState.error;
        error = failure is PlatformException
            ? failure.message ??
                  'Android speech dialog unavailable. Type instead.'
            : 'Could not open the Android speech dialog. Type instead.';
        _notify();
      }
    } finally {
      _startingSystem = false;
    }
  }

  Future<void> stop() async {
    if (usingSystemDialog) {
      await silence();
      return;
    }
    if (!recording) return;
    try {
      await adapter.stop();
    } catch (_) {
      state = AgentVoiceState.reviewing;
      _notify();
    }
  }

  Future<void> silence() async {
    _session = agentId();
    usingSystemDialog = false;
    state = error.isEmpty ? AgentVoiceState.ready : AgentVoiceState.error;
    amplitude = 0;
    _notify();
    try {
      await adapter.cancel();
      await adapter.stopSpeaking();
    } catch (_) {
      /* Text remains available. */
    }
  }

  void dismissError() {
    error = '';
    nativeErrorCode = null;
    if (state == AgentVoiceState.error) {
      state = transcript.isEmpty
          ? AgentVoiceState.ready
          : AgentVoiceState.reviewing;
    }
    _notify();
  }

  Future<void> speak(String text, AgentSettings settings) async {
    if (_disposed || !settings.spoken) return;
    await silence();
    if (_disposed) return;
    if (availability['tts'] != true) await initialize();
    if (_disposed) return;
    if (availability['tts'] != true) {
      error = 'Text-to-speech is unavailable or still starting. Check installed voices and retry.';
      state = AgentVoiceState.error;
      _notify();
      return;
    }
    final ttsLocale = const VoiceLocaleRepository().speech(
      settings,
      availability,
    );
    if (ttsLocale == null) {
      error = 'No compatible installed TTS language was reported. Keep reading the response or choose another spoken-response language.';
      state = AgentVoiceState.error;
      _notify();
      return;
    }
    _session = agentId();
    state = AgentVoiceState.speaking;
    error = '';
    nativeErrorCode = null;
    _notify();
    // With privacy enabled, no dynamic record or conversation text reaches TTS.
    final selectedVoice = (availability['voiceDetails'] as List? ?? [])
        .whereType<Map>()
        .where((v) => v['name'] == settings.voice)
        .firstOrNull;
    var spokenLocale = ttsLocale;
    if (spokenLocale.isEmpty) {
      spokenLocale = settings.voice.isNotEmpty && selectedVoice != null
          ? (selectedVoice['locale'] as String? ?? '')
          : (availability['ttsDefaultLocale'] as String? ?? '');
    }
    final noticeLanguage = VoiceLocaleRepository.filipino(spokenLocale)
        ? AgentLanguage.filipino
        : AgentLanguage.english;
    final spoken = settings.hideSpokenDetails
        ? AgentStrings(noticeLanguage).privateSpokenNotice
        : text.substring(0, text.length.clamp(0, 1200));
    try {
      await adapter.speak(
        session: _session,
        text: spoken,
        locale: ttsLocale,
        voice: settings.voice,
        rate: settings.rate,
      );
    } catch (_) {
      state = AgentVoiceState.error;
      error = 'Could not speak this response. Try an installed voice or read it on screen.';
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _session = '';
    unawaited(_events.cancel());
    unawaited(adapter.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
