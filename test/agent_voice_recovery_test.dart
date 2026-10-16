import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myproject/agent_studio/agent_domain.dart';
import 'package:myproject/agent_studio/agent_voice.dart';

import 'agent_studio_fixtures.dart';

void main() {
  test(
    'on-device unavailable is an error and never selects a remote recognizer',
    () async {
      final adapter = FakeAgentVoice(),
          voice = AgentVoiceController(FakeAgentVoice());
      voice.dispose();
      final controller = AgentVoiceController(adapter);
      await controller.initialize();
      await controller.start(AgentSettings(onDevice: true));
      expect(controller.state, AgentVoiceState.error);
      expect(adapter.starts, isEmpty);
      expect(adapter.systemStarts, isEmpty);
      controller.dispose();
    },
  );
  test('native error code and reason survive stopping audio without a misleading ready state', () async {
    final adapter = FakeAgentVoice(),
        controller = AgentVoiceController(FakeAgentVoice());
    controller.dispose();
    final voice = AgentVoiceController(adapter);
    await voice.initialize();
    await voice.start(AgentSettings());
    adapter.controller.add({
      'type': 'error',
      'session': adapter.session,
      'nativeCode': 13,
      'code': 'language_unavailable',
      'message': 'The on-device language model is not installed or ready.',
    });
    expect(voice.nativeErrorCode, 13);
    expect(voice.state, AgentVoiceState.error);
    await voice.silence();
    expect(voice.state, AgentVoiceState.error);
    expect(voice.error, contains('model'));
    voice.dismissError();
    expect(voice.state, AgentVoiceState.ready);
    expect(voice.nativeErrorCode, isNull);
    voice.dispose();
  });
  test(
    'native permission and service startup messages are preserved',
    () async {
      final adapter = FakeAgentVoice()
        ..startError = PlatformException(
          code: 'permission',
          message: 'Allow microphone access for SaveTrack.',
        );
      final voice = AgentVoiceController(adapter);
      await voice.initialize();
      await voice.start(AgentSettings());
      expect(voice.error, 'Allow microphone access for SaveTrack.');
      expect(voice.state, AgentVoiceState.error);
      voice.dispose();
    },
  );
  test('system speech dialog requires explicit removal of the on-device requirement', () async {
    final adapter = FakeAgentVoice(),
        voice = AgentVoiceController(FakeAgentVoice());
    voice.dispose();
    final controller = AgentVoiceController(adapter);
    await controller.initialize();
    await controller.startSystem(AgentSettings(onDevice: true));
    expect(adapter.systemStarts, isEmpty);
    await controller.startSystem(AgentSettings(onDevice: false));
    expect(adapter.systemStarts, hasLength(1));
    expect(controller.usingSystemDialog, true);
    adapter.emit('final', text: 'Prepare PHP 50');
    expect(controller.transcript, 'Prepare PHP 50');
    expect(controller.state, AgentVoiceState.reviewing);
    expect(controller.usingSystemDialog, false);
    controller.dispose();
  });
  test('rapid system-dialog taps launch only once; cancellation rejects a late result', () async {
    final adapter = FakeAgentVoice(),
        voice = AgentVoiceController(FakeAgentVoice());
    voice.dispose();
    final controller = AgentVoiceController(adapter);
    await controller.initialize();
    await Future.wait([
      controller.startSystem(AgentSettings()),
      controller.startSystem(AgentSettings()),
    ]);
    expect(adapter.systemStarts, hasLength(1));
    final token = adapter.session;
    await controller.stop();
    adapter.emit('final', token: token, text: 'late private transcript');
    expect(controller.transcript, isEmpty);
    expect(controller.usingSystemDialog, false);
    controller.dispose();
  });
  test('support details expose actual installed on-device languages for the picker', () async {
    final adapter = FakeAgentVoice(),
        voice = AgentVoiceController(FakeAgentVoice());
    voice.dispose();
    final controller = AgentVoiceController(adapter);
    await controller.initialize();
    await controller.start(AgentSettings());
    adapter.controller.add({
      'type': 'support',
      'session': adapter.session,
      'onDeviceLanguages': ['en-US'],
    });
    expect(controller.availability['onDeviceLanguages'], ['en-US']);
    adapter.emit('systemCanceled');
    expect(controller.usingSystemDialog, false);
    expect(controller.error, isEmpty);
    controller.dispose();
  });
}
