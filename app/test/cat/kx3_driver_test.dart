// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/kx3_iq_spectrum.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transports/iq_audio.dart';

class _Sink implements EquipmentSink, SpectrumSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final frames = <SpectrumFrame>[];
  final settings = <SpectrumSettings>[];
  final problems = <String?>[];
  final spectrumProblems = <String?>[];
  final keyerSpeeds = <int>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void report(VfoReading reading) => readings.add(reading);
  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings value) => settings.add(value);
  @override
  void reportSpectrumProblem(String? message) => spectrumProblems.add(message);
  @override
  void reportProblem(String? message) => problems.add(message);
  @override
  void reportKeyerSpeed(int wpm) => keyerSpeeds.add(wpm);
  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool value) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportAlive() {}
}

class _Capture implements IqAudioCapture {
  // An explicit cleanup future stays in the fake clock's zone; the SDK's
  // broadcast cancellation otherwise continues through its root-zone future.
  final incoming = StreamController<Uint8List>(sync: true, onCancel: () async {});
  int starts = 0;
  int closes = 0;

  @override
  Future<Stream<Uint8List>> start({required String deviceId, required int sampleRate}) async {
    starts++;
    return incoming.stream;
  }

  @override
  Future<void> dispose() async {
    closes++;
  }
}

void _receive(KenwoodSession session, String text) => session.handleData(Uint8List.fromList(ascii.encode(text)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppClock.followZoneClock = true;
    AppClock.instance.reset();
  });
  tearDown(() {
    AppClock.instance.reset();
    AppClock.followZoneClock = false;
  });

  test('only an explicitly enabled KX3 offers I/Q, even when a KX2 retains those saved settings', () {
    final registry = EquipmentRegistry();
    const saved = {kx3IqEnabledKey: true, kx3IqDeviceKey: 'usb-stereo-input', kx3IqRateKey: 96000, kx3IqOffsetKey: 8000, kx3IqSwapKey: true};
    for (final key in ['kx3-serial', 'kx2-serial', 'kenwood-serial']) {
      final type = registry.typeFor(key)!;
      final session = type.driver.createSession(_Sink(), type.driverConfig({...type.defaultConfig, ...saved}));
      addTearDown(session.teardown);
      if (key == 'kx3-serial') {
        expect(session, isA<SpectrumSession>());
        final scope = session as SpectrumSession;
        expect(scope.spectrumCapabilities.spansHz.last, 48000);
        expect(scope.spectrumCapabilities.modes, {SpectrumMode.center});
        expect(scope.spectrumCapabilities.canRecenter, isFalse);
        expect(scope.setSpectrum(const SpectrumRequest(spanHz: 5000)), isFalse);
        final cat = session as KenwoodSession;
        expect(cat.declaredModeOffset, 27);
        expect(cat.cwDialect, KenwoodCwDialect.elecraft);
        expect(cat.voiceMemoryCount, 2);
        expect(cat.voiceMemoryCeiling, const Duration(seconds: 15));
        expect(cat.passbandDialect, KenwoodPassbandDialect.elecraft);
      } else {
        expect(session, isNot(isA<SpectrumSession>()), reason: '$key has no supported physical RX I/Q output');
      }
    }
    final kx3 = registry.typeFor('kx3-serial')!;
    for (final enabled in [null, false]) {
      final session = kx3.driver.createSession(_Sink(), kx3.driverConfig({...saved, kx3IqEnabledKey: enabled}));
      addTearDown(session.teardown);
      expect(session, isNot(isA<SpectrumSession>()), reason: 'ordinary KX3 CAT must not require an audio input');
    }
  });

  test('I/Q configuration validates only enabled capture and preserves its saved keys', () {
    const driver = Kx3Driver();
    const enabled = {kx3IqEnabledKey: true};
    expect(driver.recognizedConfigKeys, containsAll([kx3IqEnabledKey, kx3IqDeviceKey, kx3IqRateKey, kx3IqSwapKey, kx3IqOffsetKey]));
    for (final missing in [null, '', '  ']) {
      expect(driver.validateField(kx3IqDeviceKey, missing, enabled), t.settings.station.kx3IqSelectDevice);
    }
    expect(driver.validateField(kx3IqDeviceKey, 'usb-stereo-input', enabled), isNull);
    for (final rate in [48000, '96000', 192000]) {
      expect(driver.validateField(kx3IqRateKey, rate, enabled), isNull);
    }
    for (final rate in [44100, 'bad', 96000.5]) {
      expect(driver.validateField(kx3IqRateKey, rate, enabled), t.settings.station.kx3IqInvalidRate);
    }
    for (final offset in [-24000, '8000', 24000]) {
      expect(driver.validateField(kx3IqOffsetKey, offset, enabled), isNull);
    }
    for (final offset in [-24001, 24001, 'bad', 1.5]) {
      expect(driver.validateField(kx3IqOffsetKey, offset, enabled), t.settings.station.kx3IqInvalidOffset);
    }
    expect(driver.validateField(kx3IqDeviceKey, '', const {}), isNull);
    expect(driver.validateField(kx3IqRateKey, 44100, const {}), isNull);
    expect(driver.validateField(kx3IqOffsetKey, 'bad', const {}), isNull);
  });

  test('audio controls are offered only on a supported platform with the supported sample rates', () {
    final fields = const Kx3Driver().configElements();
    final iqFields = fields.where((field) => '${field['key']}'.startsWith('kx3Iq')).toList();
    if (!iqAudioSupported) {
      expect(iqFields, isEmpty);
      return;
    }
    expect(iqFields.map((field) => field['key']), containsAll([kx3IqEnabledKey, kx3IqDeviceKey, kx3IqRateKey, kx3IqSwapKey, kx3IqOffsetKey]));
    final rates = iqFields.singleWhere((field) => field['key'] == kx3IqRateKey)['options'] as List;
    expect(rates.map((dynamic option) => option['value']), [48000, 96000, 192000]);
  });

  test('I/Q follows CAT frequency while local scope controls leave CAT tuning and keying intact', () {
    fakeAsync((async) {
      final sink = _Sink();
      final capture = _Capture();
      final session = Kx3SpectrumSession(
        sink,
        spectrum: Kx3IqSpectrum(deviceId: 'usb-stereo-input', sampleRate: 48000, sink: sink, captureFactory: () => capture),
        declaredModeOffset: 27,
        cwDialect: KenwoodCwDialect.elecraft,
      );
      expect(capture.starts, 0);
      session.startSpectrum();
      session.startSpectrum();
      async.flushMicrotasks();
      expect(capture.starts, 1);
      capture.incoming.add(Uint8List(3200 * 4));
      expect(sink.frames, isEmpty);
      expect(session.setSpectrum(const SpectrumRequest(spanHz: 5000, refLevelDb: 3)), isTrue);
      expect(sink.settings.last.spanHz, 5000);
      expect(sink.settings.last.refLevelDb, 3);
      expect(session.setSpectrum(const SpectrumRequest(centerHz: 14250000)), isFalse);
      expect(sink.sent, isEmpty, reason: 'audio demand and local zoom must not write radio settings');

      session.startUpdates();
      _receive(session, 'FA00014074000;MD2;KS023;');
      expect(sink.readings.where((reading) => reading.freqKHz != null).last.freqKHz, 14074);
      expect(sink.readings.last.mode, 'USB');
      expect(sink.keyerSpeeds.last, 23);
      capture.incoming.add(Uint8List(3200 * 4));
      expect(sink.frames, hasLength(1));
      expect((sink.frames.single.lowHz + sink.frames.single.highHz) / 2, 14074000);
      session.setFrequency(14250);
      expect(sink.sent, contains('FA00014250000;'));
      _receive(session, 'FA00014250000;');
      capture.incoming.add(Uint8List(3200 * 4));
      expect((sink.frames.last.lowHz + sink.frames.last.highHz) / 2, 14250000);
      session.sendCw('cq test');
      expect(sink.sent, contains('KY CQ TEST;'));
      session.stopCw();
      expect(sink.sent.last, 'KY @;');

      session.stopUpdates();
      async.flushMicrotasks();
      expect(capture.closes, 0, reason: 'CatService owns display demand independently of polling');
      session.teardown();
      async.flushMicrotasks();
      expect(capture.closes, 1);
    });
  });

  test('losing the audio device reports only a spectrum problem and CAT remains usable', () {
    fakeAsync((async) {
      final sink = _Sink();
      final capture = _Capture();
      final session = Kx3SpectrumSession(
        sink,
        spectrum: Kx3IqSpectrum(deviceId: 'usb-stereo-input', sampleRate: 48000, sink: sink, captureFactory: () => capture),
        cwDialect: KenwoodCwDialect.elecraft,
      );
      session.startSpectrum();
      async.flushMicrotasks();
      capture.incoming.addError(const IqAudioException(IqAudioFailure.deviceUnavailable), StackTrace.current);
      async.flushMicrotasks();
      expect(capture.closes, 1);
      expect(sink.spectrumProblems.last, t.settings.station.kx3IqDeviceUnavailable);
      expect(sink.problems.whereType<String>(), isEmpty);
      _receive(session, 'FA00007030000;MD3;');
      expect(sink.readings.where((reading) => reading.freqKHz != null).last.freqKHz, 7030);
      expect(sink.readings.last.mode, 'CW');
      session.setFrequency(7040);
      session.sendCw('cq');
      expect(sink.sent, containsAll(['FA00007040000;', 'KY CQ;']));
      session.teardown();
      async.flushMicrotasks();
      expect(capture.closes, 1);
    });
  });
}
