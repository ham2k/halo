// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_linux/src/alsa_backend.dart';
import 'package:record_linux/src/alsa_iq_recorder.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

const _id = 'hw:CARD=USB,DEV=0,SUBDEV=0';
const _device = InputDevice(id: _id, label: 'Stereo I/Q');

Matcher _failure(String reason) => isA<PlatformException>().having((e) => e.message, 'reason', reason);

class _Pcm implements AlsaPcm {
  AlsaSourceFormat format;
  Object? configureError;
  Object? readError;
  int closes = 0;
  _Pcm({int channels = 2, int rate = 48000, bool hardware = true}) : format = AlsaSourceFormat(hardware: hardware, channels: channels, sampleRate: rate);
  @override
  AlsaSourceFormat configure(int sampleRate) {
    if (configureError case final error?) throw error;
    return format;
  }

  @override
  Uint8List? read() {
    if (readError case final error?) throw error;
    return Uint8List.fromList([0x34, 0x12, 0xcd, 0xab]);
  }

  @override
  void close() => closes++;
}

class _Backend implements AlsaBackend {
  final AlsaPcm pcm;
  List<InputDevice> devices = [_device];
  int opens = 0;
  _Backend(this.pcm);
  @override
  List<InputDevice> inputs() => devices;
  @override
  AlsaPcm open(String deviceId) {
    opens++;
    return pcm;
  }
}

class _WorkerPcm extends _Pcm {
  final SendPort events;
  _WorkerPcm(this.events);
  @override
  AlsaSourceFormat configure(int sampleRate) {
    events.send('configured');
    return super.configure(sampleRate);
  }

  @override
  void close() {
    events.send('closed');
    super.close();
  }
}

// Capture only a SendPort; an open native handle must never cross isolates.
AlsaBackend Function() _workerFactory(SendPort events) =>
    () => _Backend(_WorkerPcm(events));

void main() {
  group('Linux I/Q hardware validation', () {
    test('never opens a default, software, numeric or missing device', () {
      for (final id in ['', 'default', 'pulse', 'plughw:CARD=USB,DEV=0', 'hw:0,0', 'hw:CARD=0,DEV=0', 'hw:CARD=Missing,DEV=0']) {
        final backend = _Backend(_Pcm());
        expect(() => openAlsaIq(backend, id, 48000), throwsA(_failure('iq_audio_device_unavailable')));
        expect(backend.opens, 0);
      }
    });

    test('closes mono, multichannel and software sources instead of upmixing', () {
      for (final pcm in [_Pcm(channels: 1), _Pcm(channels: 4), _Pcm(hardware: false)]) {
        expect(() => openAlsaIq(_Backend(pcm), _id, 48000), throwsA(_failure('iq_audio_invalid_format')));
        expect(pcm.closes, 1);
      }
    });

    test('rate mismatch closes capture rather than advertising false bandwidth', () {
      final pcm = _Pcm(rate: 48000);
      expect(() => openAlsaIq(_Backend(pcm), _id, 192000), throwsA(_failure('iq_audio_sample_rate_mismatch')));
      expect(pcm.closes, 1);
    });

    test('configuration failure releases the native device before rethrowing', () {
      final error = alsaFailure('iq_audio_permission_denied');
      final pcm = _Pcm()..configureError = error;
      expect(() => openAlsaIq(_Backend(pcm), _id, 48000), throwsA(same(error)));
      expect(pcm.closes, 1);
    });

    test('native rates preserve interleaved I/Q and close exactly once', () {
      for (final rate in [48000, 96000, 192000]) {
        final pcm = _Pcm(rate: rate);
        final session = AlsaIqSession(_Backend(pcm))..start(_id, rate);
        expect(session.read(), [0x34, 0x12, 0xcd, 0xab]);
        session.stop();
        session.stop();
        expect(pcm.closes, 1);
      }
    });

    test('unplug or overrun terminates capture without joining discontinuous samples', () {
      final error = alsaFailure('iq_audio_device_unavailable', 'overrun');
      final pcm = _Pcm()..readError = error;
      final session = AlsaIqSession(_Backend(pcm))..start(_id, 48000);
      expect(session.read, throwsA(same(error)));
      expect(session.read(), isNull);
      session.stop();
      expect(pcm.closes, 1);
    });
  });

  test('PCM conversion preserves signed I/Q order at every supported width', () {
    const expected = [0x34, 0x12, 0xcd, 0xab];
    expect(alsaPcm16(Uint8List.fromList(expected), 2), expected);
    expect(alsaPcm16(Uint8List.fromList([0xff, 0x34, 0x12, 0, 0, 0xcd, 0xab, 0xff]), 6), expected);
    expect(alsaPcm16(Uint8List.fromList([0xff, 0xff, 0x34, 0x12, 0, 0, 0xcd, 0xab]), 10), expected);
    expect(alsaPcm16(Uint8List.fromList([0xff, 0x34, 0x12, 0, 0xcd, 0xab]), 32), expected);
    for (final format in [2, 6, 10, 32, 14]) {
      expect(() => alsaPcm16(Uint8List(1), format), throwsA(_failure('iq_audio_invalid_format')));
    }
  });

  test('worker stop waits for native close before a reconnect can open', () async {
    final messages = ReceivePort();
    final events = <String>[];
    final subscription = messages.listen((event) => events.add(event as String));
    final recorder = AlsaIqRecorder(backendFactory: _workerFactory(messages.sendPort));
    const config = RecordConfig(encoder: AudioEncoder.pcm16bits, numChannels: 2, sampleRate: 48000, device: _device);
    try {
      for (var cycle = 0; cycle < 2; cycle++) {
        final samples = await recorder.startStream(config);
        expect(await samples.first, [0x34, 0x12, 0xcd, 0xab]);
        await recorder.stop();
        // The exit message is emitted after close; no timing delay is needed.
        expect(events, List.generate(cycle + 1, (_) => ['configured', 'closed']).expand((pair) => pair));
        expect(recorder.isRecording(), isFalse);
      }
    } finally {
      await recorder.dispose();
      await subscription.cancel();
      messages.close();
    }
  });

  test('failed worker spawn completes rather than waiting forever for readiness', () async {
    final unsendable = ReceivePort();
    final recorder = AlsaIqRecorder(
      backendFactory: () {
        // ReceivePort cannot cross an isolate boundary.
        unsendable.close();
        return _Backend(_Pcm());
      },
    );
    const config = RecordConfig(encoder: AudioEncoder.pcm16bits, numChannels: 2, sampleRate: 48000, device: _device);
    try {
      await expectLater(recorder.startStream(config), throwsArgumentError);
      expect(recorder.isRecording(), isFalse);
    } finally {
      await recorder.dispose();
      unsendable.close();
    }
  });

  test('worker startup refusal releases handles and leaves restart possible', () async {
    final recorder = AlsaIqRecorder(backendFactory: () => _Backend(_Pcm(channels: 1)));
    const config = RecordConfig(encoder: AudioEncoder.pcm16bits, numChannels: 2, sampleRate: 48000, device: _device);
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(recorder.startStream(config), throwsA(_failure('iq_audio_invalid_format')));
        expect(recorder.isRecording(), isFalse);
      }
    } finally {
      await recorder.dispose();
    }
  });
}
