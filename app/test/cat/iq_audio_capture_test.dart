// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/transports/iq_audio.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

final _unavailable = isA<IqAudioException>().having((error) => error.reason, 'reason', IqAudioFailure.deviceUnavailable);

class _AudioPlatform extends RecordPlatform {
  final samples = StreamController<Uint8List>();
  final states = StreamController<RecordState>.broadcast();
  List<InputDevice> inputs = const [InputDevice(id: 'usb-iq', label: 'Stereo USB')];
  Completer<bool>? permission;
  bool allowed = true;
  RecordConfig? config;
  Object? startError;
  Object? inputsError;
  RecordConfig? adjusted;
  void Function(RecordConfig)? onConfig;
  final calls = <String>[];

  @override
  Future<void> create(String recorderId) async => calls.add('create');
  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async {
    calls.add('inputs');
    if (inputsError case final error?) throw error;
    return inputs;
  }

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    calls.add('permission');
    return permission?.future ?? allowed;
  }

  @override
  Stream<RecordState> onStateChanged(String recorderId) => states.stream;
  @override
  void setOnConfigChanged(String recorderId, void Function(RecordConfig)? handler) => onConfig = handler;
  @override
  Future<Stream<Uint8List>> startStream(String recorderId, RecordConfig config) async {
    calls.add('start');
    this.config = config;
    if (startError case final error?) throw error;
    if (adjusted case final actual?) onConfig?.call(actual);
    return samples.stream;
  }

  @override
  Future<void> dispose(String recorderId) async => calls.add('dispose');
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Unexpected recorder call: ${invocation.memberName}');
}

void main() {
  late RecordPlatform previous;
  late _AudioPlatform platform;
  late IqAudioCapture capture;
  setUp(() {
    previous = RecordPlatform.instance;
    RecordPlatform.instance = platform = _AudioPlatform();
    capture = createIqAudioCapture();
  });
  tearDown(() async {
    await capture.dispose();
    RecordPlatform.instance = previous;
    unawaited(platform.samples.close());
    await platform.states.close();
  });

  test('passive enumeration never requests permission or starts capture', () async {
    expect((await listIqAudioInputs()).single.id, 'usb-iq');
    expect(platform.calls, ['create', 'inputs', 'dispose']);
  });

  test('an explicit stereo source delivers unchanged PCM without voice processing', () async {
    final stream = await capture.start(deviceId: 'usb-iq', sampleRate: 96000);
    final received = expectLater(
      stream,
      emitsInOrder([
        orderedEquals([1, 2, 3, 4]),
        emitsDone,
      ]),
    );
    final config = platform.config!;
    expect(config.device?.id, 'usb-iq');
    expect(config.numChannels, 2);
    expect(config.sampleRate, 96000);
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect([config.autoGain, config.echoCancel, config.noiseSuppress, config.androidConfig.manageBluetooth], everyElement(isFalse));
    platform.samples.add(Uint8List.fromList([1, 2, 3, 4]));
    await platform.samples.close();
    await received;
    await capture.dispose();
    await capture.dispose();
    expect(platform.calls.where((call) => call == 'dispose'), hasLength(1));
  });

  test('a missing selection cannot fall back to the system microphone', () async {
    await expectLater(capture.start(deviceId: 'missing-usb', sampleRate: 48000), throwsA(_unavailable));
    expect(platform.calls, ['create', 'inputs']);
  });

  test('permission refusal never starts a stream', () async {
    platform.allowed = false;
    await expectLater(
      capture.start(deviceId: 'usb-iq', sampleRate: 48000),
      throwsA(isA<IqAudioException>().having((error) => error.reason, 'reason', IqAudioFailure.permissionDenied)),
    );
    expect(platform.calls, isNot(contains('start')));
  });

  test('source-rate rejection remains distinct from a generic audio failure', () async {
    platform.startError = PlatformException(code: 'record', message: 'iq_audio_sample_rate_mismatch');
    await expectLater(
      capture.start(deviceId: 'usb-iq', sampleRate: 192000),
      throwsA(isA<IqAudioException>().having((error) => error.reason, 'reason', IqAudioFailure.sampleRateMismatch)),
    );
  });

  test('an unavailable capture runtime is explained before asking for microphone access', () async {
    platform.inputsError = PlatformException(code: 'record', message: 'iq_audio_unsupported');
    final unsupported = isA<IqAudioException>().having((error) => error.reason, 'reason', IqAudioFailure.unsupported);
    await expectLater(listIqAudioInputs(), throwsA(unsupported));
    await expectLater(capture.start(deviceId: 'usb-iq', sampleRate: 48000), throwsA(unsupported));
    expect(platform.calls, isNot(contains('permission')));
  });

  test('a backend downgrade cannot turn a mono microphone into an I/Q source', () async {
    platform.adjusted = const RecordConfig(encoder: AudioEncoder.pcm16bits, numChannels: 1, sampleRate: 48000);
    await expectLater(
      capture.start(deviceId: 'usb-iq', sampleRate: 48000),
      throwsA(isA<IqAudioException>().having((error) => error.reason, 'reason', IqAudioFailure.invalidFormat)),
    );
  });

  test('device-loss errors retain the reconnect reason and do not affect CAT', () async {
    final stream = await capture.start(deviceId: 'usb-iq', sampleRate: 48000);
    final received = expectLater(stream, emitsInOrder([emitsError(_unavailable), emitsDone]));
    platform.states.addError(PlatformException(code: 'record', message: 'iq_audio_device_unavailable'));
    await Future<void>.delayed(Duration.zero);
    await capture.dispose();
    await received;
  });

  test('closing while permission is pending prevents a late microphone start', () async {
    platform.permission = Completer<bool>();
    final starting = capture.start(deviceId: 'usb-iq', sampleRate: 48000);
    final rejected = expectLater(starting, throwsA(_unavailable));
    while (!platform.calls.contains('permission')) {
      await Future<void>.delayed(Duration.zero);
    }
    final closing = capture.dispose();
    platform.permission!.complete(true);
    await rejected;
    await closing;
    expect(platform.calls, ['create', 'inputs', 'permission', 'dispose']);
  });
}
