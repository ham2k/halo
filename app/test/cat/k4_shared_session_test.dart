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
import 'package:ham2k_logger/services/cat/drivers/k4_remote_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_shared_session.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';

class _Sink implements EquipmentSink, SpectrumSink, PassbandSink {
  final readings = <VfoReading>[];
  final frames = <SpectrumFrame>[];
  final settings = <SpectrumSettings>[];
  final passbands = <Passband?>[];
  final meters = <RadioMeter, num>{};
  final powers = <num>[];
  final transmitting = <bool>[];
  final problems = <String?>[];
  final spectrumProblems = <String?>[];
  int alive = 0;
  void Function()? onReading;
  @override
  void send(List<int> bytes) => fail('receiver facade must send through its physical owner');
  @override
  void report(VfoReading reading) {
    readings.add(reading);
    onReading?.call();
  }

  @override
  void reportPower(num watts) => powers.add(watts);
  @override
  void reportTransmitting(bool value) => transmitting.add(value);
  @override
  void reportMeter(RadioMeter meter, num value) => meters[meter] = value;
  @override
  void reportPassband(Passband? value) => passbands.add(value);
  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings value) => settings.add(value);
  @override
  void reportSpectrumProblem(String? problem) => spectrumProblems.add(problem);
  @override
  void reportProblem(String? problem) => problems.add(problem);
  @override
  void reportAlive() => alive++;
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
}

class _Fixture {
  final Map<String, dynamic> config;
  _Fixture({this.config = const {}});
  final sent = <String>[];
  final mainSink = _Sink(), subSink = _Sink();
  int panListens = 0, panCancels = 0;
  late final pan = StreamController<K4RemotePanPacket>.broadcast(sync: true, onListen: () => panListens++, onCancel: () => panCancels++);
  late final owner = K4SharedSession(send: (bytes) => sent.add(ascii.decode(bytes)), pan: pan.stream, config: config);
  late final main = owner.attach(mainSink, receiver: 'main');
  late final sub = owner.attach(subSink, receiver: 'sub');
  void start() {
    main.startUpdates();
    sub.startUpdates();
  }

  void receive(String text) => owner.handleData(Uint8List.fromList(ascii.encode(text)));
  void ready() => receive(r'FA00014074000;FB00007045000;MD2;MD$3;DV0;SB1;BW0270;IS 1500;BW$0050;IS$ 0600;CW60;');
  void close() {
    owner.teardown();
    main.teardown();
    sub.teardown();
    unawaited(pan.close());
  }
}

// A synthetic remote PAN envelope exercises dispatch, not wire compatibility.
K4RemotePanPacket _packet(int receiver, int centerHz) {
  final payload = Uint8List(27 + 1024);
  payload.setRange(0, 5, [2, 1, 0, 0, receiver]);
  final metadata = ByteData.sublistView(payload);
  metadata.setUint16(5, 1024, Endian.little);
  metadata.setInt64(11, centerHz, Endian.little);
  metadata.setInt32(19, 48, Endian.little);
  metadata.setInt32(23, -1300, Endian.little);
  payload.fillRange(27, payload.length, 45);
  final wire = Uint8List(payload.length + 12);
  wire.setRange(0, 4, [0xfe, 0xfd, 0xfc, 0xfb]);
  ByteData.sublistView(wire).setUint32(4, payload.length, Endian.big);
  wire.setRange(8, 8 + payload.length, payload);
  wire.setRange(wire.length - 4, wire.length, [0xfb, 0xfc, 0xfd, 0xfe]);
  return K4RemoteDecoder().add(wire).single as K4RemotePanPacket;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppClock.followZoneClock = true);
  tearDown(() => AppClock.followZoneClock = false);

  test('receiver config uses existing channel identity only for secure K4', () {
    const remote = KenwoodDriver.k4(remote: true);
    expect(remote.channelKey, 'receiver');
    expect(remote.channelValues, ['main', 'sub']);
    expect(remote.describeChannel({}), remote.describeChannel({'receiver': 'main'}));
    expect(remote.validateField('receiver', 'wrong', {}), isNotNull);
    expect(remote.validateField('receiver', null, {}), isNull);
    expect(const KenwoodDriver.k4(lanSpectrum: true).channelKey, isNull);
    expect(const KenwoodDriver.k4().channelValues, isEmpty);
  });

  test('one startup and physical parser serve both receivers without idle polling', () {
    fakeAsync((async) {
      final f = _Fixture()..start();
      expect(f.sent.where((text) => text == 'RDY;'), hasLength(1));
      expect(f.sent.where((text) => text == 'K40;K31;'), hasLength(1));
      f.receive('FA00014');
      f.receive(r'074000;FB00007045000;MD2;MD$3;DV0;SB1;PONG;');
      expect(f.mainSink.readings.last, const VfoReading(freqKHz: 14074, mode: 'USB'));
      expect(f.subSink.readings.last, const VfoReading(freqKHz: 7045, mode: 'CW'));
      expect((f.mainSink.alive, f.subSink.alive), (1, 1));
      f.main.handleData(Uint8List.fromList(ascii.encode('FA00099999999;')));
      expect(f.mainSink.readings.last.freqKHz, 14074, reason: 'lease proof bytes must not parse CAT a second time');
      final before = f.sent.length;
      async.elapse(const Duration(minutes: 1));
      expect(f.sent, hasLength(before));
      f.close();
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('Sub uses its own DATA mode, filter, meter and CAT targets', () {
    final f = _Fixture()
      ..start()
      ..ready();
    addTearDown(f.close);
    expect(f.mainSink.passbands.last, const Passband(150, 2850));
    expect(f.subSink.passbands.last, const Passband(-250, 250));
    f.receive(r'SMH-073;SMH$-085;');
    expect(f.mainSink.meters[RadioMeter.signalDbm], -73);
    expect(f.subSink.meters[RadioMeter.signalDbm], -85);
    f.sent.clear();
    (f.sub as TransceiverSession).setFrequency(10136);
    expect(f.sent.join(), contains(r'BN$04;FB00010136000;'));
    expect(f.sent.join(), isNot(contains('FA')));
    f.sent.clear();
    (f.sub as TransceiverSession).setMode('FT8');
    expect(f.sent.first, r'MD$6;DT$0;');
    expect(f.sent.join(), isNot(contains('MD6;')));
    f.receive(r'MD$6;');
    expect(f.subSink.readings.last.mode, isNull, reason: 'a previous DT must not name a newly selected DATA mode');
    f.receive(r'DT$0;');
    expect(f.subSink.readings.last.mode, 'DATA-USB');
    f.receive(r'MD$9;DT$2;');
    expect(f.subSink.readings.last.mode, 'RTTY-R');
    expect(f.mainSink.readings.last.mode, 'USB');
    f.receive(r'MD$1;BW$0270;IS$ 1500;');
    expect(f.subSink.passbands.last, const Passband(-2850, -150));
    f.sent.clear();
    (f.sub as PassbandSession).setPassband(const Passband(-2400, -100));
    expect(f.sent.single, r'BW$0230;BW$;IS$;');
  });

  test('diversity binds Sub RX to A without touching B split register', () {
    final f = _Fixture()
      ..start()
      ..ready();
    addTearDown(f.close);
    f.receive('DV1;');
    expect(f.subSink.readings.last, const VfoReading(freqKHz: 14074, mode: 'USB'));
    // Legacy IF is an operating/TX snapshot: it cannot replace either RX.
    f.receive('IF00007045000     +000000 0011001001 ;');
    expect(f.mainSink.readings.last.freqKHz, 14074);
    expect(f.subSink.readings.last.freqKHz, 14074);
    f.sent.clear();
    (f.sub as TransceiverSession).setFrequency(14250);
    (f.sub as TransceiverSession).setMode('CW');
    expect(f.sent.join(), contains('FA00014250000;'));
    expect(f.sent.join(), contains('MD3;'));
    expect(f.sent.join(), isNot(matches(r'FB\d')));
    expect(f.sent.join(), isNot(matches(r'MD\$\d')));
    expect(f.sent.join(), contains(r'MD$;'), reason: 'coupled B settings still need readback under AI4');
    expect(f.sent.join(), isNot(contains('FT')));
    f.receive('DV0;');
    expect(f.subSink.readings.last.freqKHz, 7045, reason: 'B remains the independent VFO when diversity ends');
    expect(f.subSink.readings.last.mode, isNull, reason: 'the pre-diversity B mode is no longer evidence');
    f.receive(r'MD$2;');
    expect(f.subSink.readings.last.mode, 'USB');
    f.receive('SB0;');
    expect(f.subSink.problems.last, isNotNull);
    expect(f.mainSink.problems.last, isNull);
    expect(f.sent.join(), isNot(contains('SB1;')), reason: 'adding Sub never turns it on behind the operator');
    f.sent.clear();
    (f.sub as TransceiverSession).setFrequency(7100);
    (f.sub as TransceiverSession).setMode('LSB');
    expect(f.sent, isEmpty, reason: 'a direct caller cannot tune an inactive receiver behind the disabled panel');
  });

  test('unknown diversity cannot authorize a write to the split holding register', () {
    final f = _Fixture()..start();
    addTearDown(f.close);
    f.sent.clear();
    (f.sub as TransceiverSession).setFrequency(7100);
    expect(f.sent, ['DV;']);
  });

  test('one PAN subscription retains independent displays and survives sibling teardown', () {
    fakeAsync((async) {
      final f = _Fixture()
        ..start()
        ..ready();
      final main = f.main as SpectrumSession, sub = f.sub as SpectrumSession;
      main.startSpectrum();
      sub.startSpectrum();
      expect(f.panListens, 1);
      main.setSpectrum(const SpectrumRequest(spanHz: 2500, refLevelDb: 5));
      sub.setSpectrum(const SpectrumRequest(spanHz: 10000, refLevelDb: -4));
      f.pan.add(_packet(0, 14045000));
      f.pan.add(_packet(1, 7045000));
      expect(f.mainSink.frames, hasLength(1));
      expect(f.subSink.frames, hasLength(1));
      expect(f.mainSink.frames.single.highHz, lessThan(14074000), reason: 'PAN center is independent of the RX dial');
      expect(f.subSink.settings.last.refLevelDb, -4);
      f.main.teardown();
      expect(f.panCancels, 0);
      f.pan.add(_packet(1, 7046000));
      expect(f.subSink.frames, hasLength(2));
      sub.stopSpectrum();
      async.flushMicrotasks();
      expect(f.panCancels, 1);
      sub.startSpectrum();
      expect(f.subSink.settings.last.refLevelDb, -4, reason: 'display settings belong to the logical receiver');
      expect(f.panListens, 2);
      f.close();
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('a terminated PAN source stays unavailable without retrying or stopping CAT', () {
    fakeAsync((async) {
      final f = _Fixture()
        ..start()
        ..ready();
      final main = f.main as SpectrumSession, sub = f.sub as SpectrumSession;
      main.startSpectrum();
      sub.startSpectrum();
      unawaited(f.pan.close());
      async.flushMicrotasks();
      expect(f.mainSink.spectrumProblems.last, t.settings.station.spectrumK4RemoteUnavailable);
      expect(f.subSink.spectrumProblems.last, t.settings.station.spectrumK4RemoteUnavailable);
      main.stopSpectrum();
      main.startSpectrum();
      expect(f.mainSink.spectrumProblems.last, t.settings.station.spectrumK4RemoteUnavailable);
      expect(f.panListens, 1, reason: 'a terminal source requires a replacement connection, not another subscription');
      f.sent.clear();
      async.elapse(const Duration(seconds: 20));
      expect(f.sent, isEmpty, reason: 'spectrum does not create a CAT or reconnection loop');
      f.receive('FA00014075000;');
      expect(f.mainSink.readings.last.freqKHz, 14075);
      f.close();
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('global TX state is shared but a sibling cannot release another facade PTT', () {
    final f = _Fixture()
      ..start()
      ..ready();
    addTearDown(f.close);
    f.receive('PC050H;TQ1;');
    expect(f.mainSink.powers.last, 50);
    expect(f.subSink.powers.last, 50);
    expect(f.subSink.transmitting.last, isTrue);
    (f.sub as PttSession).setPtt(true);
    f.sent.clear();
    (f.main as PttSession).setPtt(false);
    expect(f.sent, isEmpty, reason: 'only the facade that asserted PTT may release it');
    f.main.teardown();
    expect(f.sent, isEmpty);
    f.sub.teardown();
    expect(f.sent, ['RX;', 'TQ;'], reason: 'disconnecting the PTT owner still unkeys before its lease closes');
    f.owner.teardown();
    expect(f.sent.where((command) => command == 'RX;'), hasLength(1));
  });

  test('late receiver attaches replay physical state and reentrant detach stops callbacks', () {
    final f = _Fixture()
      ..start()
      ..ready();
    addTearDown(f.close);
    f.receive('PC050H;');
    final lateSink = _Sink();
    final lateSession = f.owner.attach(lateSink, receiver: 'sub');
    lateSession.startUpdates();
    expect(lateSink.powers, [50]);
    expect(lateSink.readings.last.freqKHz, 7045);
    lateSink.onReading = lateSession.teardown;
    final filters = lateSink.passbands.length;
    f.receive('FB00007046000;');
    expect(lateSink.passbands, hasLength(filters));
    f.receive('FB00007047000;');
    expect(lateSink.readings.last.freqKHz, 7046);
    expect(f.subSink.readings.last.freqKHz, 7047);
  });

  test('CW and voice stop with their initiating receiver, not an unrelated sibling', () {
    fakeAsync((async) {
      final cw = _Fixture(config: const {'cwDialect': 'elecraft'})
        ..start()
        ..ready();
      (cw.sub as CwKeyerSession).sendCw('CQ CQ CQ DE N0DEV N0DEV K');
      cw.sent.clear();
      cw.main.teardown();
      expect(cw.sent, isEmpty);
      expect((cw.sub as CwKeyerSession).cwSending, isTrue);
      cw.sub.teardown();
      expect(cw.sent, ['KY @;']);
      expect((cw.sub as CwKeyerSession).cwSending, isFalse);
      async.elapse(const Duration(minutes: 1));
      expect(cw.sent, ['KY @;'], reason: 'no later chunk may outlive the node that supplied the message');
      cw.close();

      final voice = _Fixture(config: const {'voiceDialect': 'k4', 'voiceMemories': 8})
        ..start()
        ..ready();
      (voice.sub as VoiceKeyerSession).playVoiceMemory(1);
      voice.sent.clear();
      voice.main.teardown();
      expect(voice.sent, isEmpty);
      voice.sub.teardown();
      expect(voice.sent, ['DA0;']);
      voice.close();
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
    });
  });
}
