// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_shared_session.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

class _Sink implements EquipmentSink, TunerSink, TuneCarrierSink {
  final commands = <String>[];
  final tuner = <TunerStatus?>[];
  final tuneCarrier = <bool>[];

  @override
  void send(List<int> bytes) {
    commands.addAll(ascii.decode(bytes).split(';').where((command) => command.isNotEmpty));
  }

  @override
  void reportTuner(TunerStatus? status) => tuner.add(status);
  @override
  void reportTuneCarrier(bool on) => tuneCarrier.add(on);
  @override
  void report(VfoReading reading) {}
  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool transmitting) {}
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportAlive() {}
}

Uint8List _wire(String text) => Uint8List.fromList(ascii.encode(text));

// K31 IF layout, with the transmit flag immediately before the mode.
String _info({bool tx = false, String frequency = '00014074000'}) => 'IF$frequency     +000000 00${tx ? 1 : 0}2000001 ;';

KenwoodSession _local(String variant, _Sink sink) {
  final type = EquipmentRegistry().typeFor(variant)!;
  return type.driver.createSession(sink, type.driverConfig({...type.defaultConfig, 'host': '192.0.2.4'})) as KenwoodSession;
}

void main() {
  for (final variant in ['k4-serial', 'k4-tcp']) {
    test('$variant verifies the KAT4 and receive state before transmitting', () {
      fakeAsync((_) {
        final sink = _Sink();
        final session = _local(variant, sink)..startUpdates();
        expect(sink.commands, containsAllInOrder(['AT', 'TU']));
        sink.commands.clear();
        session.handleData(_wire('AT0;TU0;'));
        session.setTuner(inline: true);
        session.startTune();
        expect(session.canStartTune, isFalse);
        expect(sink.commands, isEmpty);

        session.handleData(_wire('AT1;'));
        expect(sink.tuner, [TunerStatus.bypassed]);
        session.setTuner(inline: true);
        expect(sink.commands, ['AT2', 'AT'], reason: 'switching in the tuner does not key the radio');
        sink.commands.clear();
        expect(session.canStartTune, isFalse, reason: 'wait for the radio to confirm AUTO');
        session.handleData(_wire('AT2;'));
        session.startTune();
        expect(sink.commands, isEmpty, reason: 'receive has not been confirmed');

        session.handleData(_wire(_info(tx: true)));
        sink.commands.clear();
        session.startTune();
        expect(sink.commands, isEmpty, reason: 'do not start over another transmission');

        session.handleData(_wire(_info()));
        sink.commands.clear();
        session.startTune();
        session.startTune();
        expect(sink.commands, ['TU3'], reason: 'a second press must not trigger an extended search');
        session.handleData(_wire('TU3;'));
        expect(sink.tuner.last, TunerStatus.tuning);
        expect(sink.tuneCarrier, isEmpty);
        session.stopTune();
        expect(sink.commands, ['TU3', 'TU0']);
        session.handleData(_wire('TU0;'));
        expect(sink.tuner.last, TunerStatus.inline);
        session.teardown();
        expect(sink.commands.where((c) => c == 'TU0'), hasLength(1));
      });
    });
  }

  test('band and antenna changes preserve the last reported ATU mode', () {
    fakeAsync((_) {
      final sink = _Sink();
      final session = _local('k4-serial', sink)..startUpdates();
      session.handleData(_wire('${_info()}AT2;TU0;AN1;'));
      sink.commands.clear();
      session.handleData(_wire('AN2;AN2;'));
      expect(session.canStartTune, isTrue);
      session.handleData(_wire(_info(frequency: '00007045000')));
      session.setFrequency(14045);
      expect(sink.commands, isNot(contains('AT')));
      expect(session.canStartTune, isTrue);
      expect(sink.tuner, [TunerStatus.inline]);
      session.handleData(_wire('AT1;'));
      expect(sink.tuner.last, TunerStatus.bypassed);
      expect(session.canStartTune, isFalse);
      session.teardown();
    });
  });

  test('a missing tune report does not release the app’s stop on disconnect', () {
    fakeAsync((async) {
      final sink = _Sink();
      final session = _local('k4-serial', sink)..startUpdates();
      session.handleData(_wire('${_info()}AT2;TU0;'));
      sink.commands.clear();
      session.startTune();
      async.elapse(const Duration(seconds: 3));
      expect(sink.commands.where((c) => c.startsWith('TU')), ['TU3', 'TU']);
      session.teardown();
      expect(sink.commands.where((c) => c.startsWith('TU')), ['TU3', 'TU', 'TU0']);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('the secure link queries a missed tune-end notification once', () {
    fakeAsync((async) {
      final link = _Sink(), sink = _Sink();
      final owner = K4SharedSession(send: link.send, pan: const Stream<K4RemotePanPacket>.empty(), config: {});
      final session = owner.attach(sink, receiver: 'main') as AntennaTunerSession;
      session.startUpdates();
      owner.handleData(_wire('RX;AT2;TU0;'));
      link.commands.clear();
      session.startTune();
      owner.handleData(_wire('TU3;'));
      async.elapse(const Duration(seconds: 3));
      expect(link.commands, ['TU3', 'TU']);
      owner.handleData(_wire('TU0;'));
      expect(sink.tuner.last, TunerStatus.inline);
      async.elapse(const Duration(minutes: 1));
      expect(link.commands, ['TU3', 'TU'], reason: 'the secure connection does not poll tuner status at idle');
      owner.teardown();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('secure receivers share tuner state while only the initiator can stop an app tune', () {
    fakeAsync((async) {
      final link = _Sink(), mainSink = _Sink(), subSink = _Sink();
      final owner = K4SharedSession(send: link.send, pan: const Stream<K4RemotePanPacket>.empty(), config: {});
      final main = owner.attach(mainSink, receiver: 'main') as AntennaTunerSession;
      final sub = owner.attach(subSink, receiver: 'sub') as AntennaTunerSession;
      main.startUpdates();
      owner.handleData(_wire('RX;AT2;TU0;'));
      sub.startUpdates();
      expect(link.commands.where((c) => c == 'AT'), hasLength(1));
      expect(mainSink.tuner, [TunerStatus.inline]);
      expect(subSink.tuner, [TunerStatus.inline], reason: 'the second facade gets the current tuner state');
      owner.handleData(_wire('FA00014045000;FA00007045000;AN2;'));
      expect(link.commands.where((c) => c == 'AT'), hasLength(1));
      expect(main.canStartTune, isTrue);
      expect(sub.canStartTune, isTrue);
      owner.handleData(_wire('AT1;'));
      expect(mainSink.tuner.last, TunerStatus.bypassed);
      expect(subSink.tuner.last, TunerStatus.bypassed);
      owner.handleData(_wire('AT2;'));
      owner.handleData(_wire('TU2;TU0;'));
      expect(mainSink.tuneCarrier, [true, false]);
      expect(subSink.tuneCarrier, [true, false]);
      link.commands.clear();
      sub.startTune();
      main.startTune();
      owner.handleData(_wire('TU3;'));
      expect(mainSink.tuner.last, TunerStatus.tuning);
      expect(subSink.tuner.last, TunerStatus.tuning);
      main.stopTune();
      main.teardown();
      expect(link.commands, ['TU3'], reason: 'disconnecting the sibling leaves the initiator’s tune alone');
      sub.teardown();
      owner.teardown();
      expect(link.commands, ['TU3', 'TU0']);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('ordinary tune and a front-panel ATU tune never become app-owned', () {
    fakeAsync((_) {
      final sink = _Sink();
      final session = _local('k4-serial', sink)..startUpdates();
      session.handleData(_wire('${_info()}AT2;TU1;TU2;'));
      expect(sink.tuneCarrier, [true]);
      expect(sink.tuner.last, TunerStatus.inline, reason: 'a TUNE carrier is not an ATU search');
      sink.commands.clear();
      session.startTune();
      session.stopTune();
      session.handleData(_wire('TU0;TU4;'));
      expect(sink.tuneCarrier, [true, false]);
      expect(sink.tuner.last, TunerStatus.tuning);
      session.startTune();
      session.stopTune();
      session.teardown();
      expect(sink.commands.where((c) => c == 'TU0' || c == 'TU3'), isEmpty, reason: 'Stop and teardown leave the front panel alone');
    });
  });
}
