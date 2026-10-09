// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/civ_scope_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:halo_i18n/halo_i18n.dart';

/// One sweep as an IC-705 sent it over WiFi: `frame.data` of a `27 00` frame
/// at 144.025 MHz, ±100 kHz, REF +10 — receiver noise and nothing else.
final _capturedSweep = _hex(
  '000001010000500244010000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
  '0000000000000000000000',
);

List<int> _hex(String s) => [for (var i = 0; i + 1 < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)];

class _Sink implements EquipmentSink, SpectrumSink {
  final sent = <List<int>>[];
  final frames = <SpectrumFrame>[];
  final settings = <SpectrumSettings>[];

  /// The radio's side: a scope read answers with [answers]' entry for its
  /// sub-command, anything else with an ACK. Null answers nothing.
  void Function(Uint8List frame)? radio;
  Map<int, List<int>> answers = {};

  @override
  void send(List<int> bytes) {
    sent.add(bytes);
    // A read is the sub-command alone, or with the receiver byte for the
    // settings that take one; anything longer sets something, and is ACKed.
    final isRead = bytes[4] == civScopeCommand && bytes.length == (const {civScopeOnOff, civScopeOutput}.contains(bytes[5]) ? 7 : 8);
    final reply = isRead && answers[bytes[5]] != null ? [civScopeCommand, ...answers[bytes[5]]!] : [0xFB];
    radio?.call(Uint8List.fromList([0xFE, 0xFE, bytes[3], bytes[2], ...reply, 0xFD]));
  }

  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings s) => settings.add(s);
  final problems = <String?>[];
  @override
  void reportSpectrumProblem(String? message) => problems.add(message);
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
  void reportDiagnostic(String? note) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

void main() {
  const ic705 = 0xA4, us = 0xE1;

  group('the scope codec, against a captured IC-705', () {
    test('a network sweep arrives whole, and its header places it', () {
      final sweep = CivScopeAssembler().add(_capturedSweep)!;
      expect((sweep.fixed, sweep.lowHz, sweep.highHz, sweep.outOfRange), (false, 143925000, 144125000, false));
      // 475 points plus the one the radio appends; all of them, or the
      // trace is stretched across a span it does not cover.
      expect(sweep.amplitudes, hasLength(_capturedSweep.length - 16));
      expect(sweep.amplitudes.every((a) => a <= civScopeAmplitudeMax), isTrue);
    });

    test('a serial sweep is put back together from its divisions, and a gap drops it', () {
      final header = [0x00, 0x00, 0x01, 0x03, 0x00, ..._capturedSweep.sublist(5, 16)];
      final a = CivScopeAssembler();
      expect(a.add(header), isNull);
      expect(a.add([0x00, 0x00, 0x02, 0x03, 10, 20]), isNull);
      expect(a.add([0x00, 0x00, 0x03, 0x03, 30])!.amplitudes, [10, 20, 30]);
      // Division 3 without 2: the halves of two sweeps side by side would
      // draw a signal that is not there.
      expect(a.add(header), isNull);
      expect(a.add([0x00, 0x00, 0x03, 0x03, 30]), isNull);
    });

    test('settings answers decode as the radio sent them', () {
      expect(parseScopeSpan([0x15, 0x00, 0x00, 0x25, 0x00, 0x00, 0x00]), 2500);
      expect(parseScopeRef([0x19, 0x00, 0x04, 0x50, 0x01]), -4.5);
      expect(parseScopeFixed([0x14, 0x00, 0x00]), isFalse);
      expect(parseScopeSpeed([0x1A, 0x00, 0x02]), 2);
      // The radio ACKed exactly these bytes for REF −4.5.
      expect(buildScopeRefFrame(to: ic705, from: us, refDb: -4.5).sublist(5, 10), [0x19, 0x00, 0x04, 0x50, 0x01]);
    });
  });

  group('the scope on a session', () {
    late _Sink sink;
    late IcomCivSession session;
    IcomCivSession make(Map<String, dynamic> config) {
      sink = _Sink();
      session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, config: config);
      return session;
    }

    test('a radio without a scope, or a line too slow for one, says why', () {
      expect(make({}).spectrumUnavailable, t.settings.station.spectrumUnsupported);
      // The operator asked for these words: what to change, not what failed.
      expect(make({civScopeConfigKey: true, 'baudRate': 19200}).spectrumUnavailable, 'Requires CAT at 115200 bps');
      expect(make({civScopeConfigKey: true, 'baudRate': 115200}).spectrumUnavailable, isNull);
      expect(make({civScopeConfigKey: true}).spectrumUnavailable, isNull, reason: 'the network has no baud rate to fall short of');
    });

    test('starting turns the output on and reads the settings; sweeps become frames', () {
      make({civScopeConfigKey: true});
      sink.answers = {
        civScopeOnOff: [civScopeOnOff, 0x01],
        civScopeSpan: [civScopeSpan, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00],
        civScopeRef: [civScopeRef, 0x00, 0x10, 0x00, 0x00],
        civScopeSpeed: [civScopeSpeed, 0x00, 0x00],
        civScopeMode: [civScopeMode, 0x00, 0x00],
      };
      sink.radio = session.handleData;
      session.startSpectrum();
      expect(
        sink.sent.map((f) => f.sublist(4, f.length - 1)),
        containsAllInOrder([
          [0x27, 0x10],
          [0x27, 0x11, 0x01],
          [0x27, 0x14, 0x00],
        ]),
      );
      expect(sink.settings.last, const SpectrumSettings(spanHz: 100000, refLevelDb: 10, speed: SpectrumSpeed.fast));
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ..._capturedSweep, 0xFD]));
      expect(sink.frames.single.lowHz, 143925000);
      expect(sink.frames.single.levels, hasLength(_capturedSweep.length - 16));
    });

    test('a sweep never answers a scope read, so it cannot free the wire for a burst', () {
      make({civScopeConfigKey: true});
      session.startSpectrum();
      // The radio has answered nothing; only the first read is on the wire.
      expect(sink.sent, hasLength(1));
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ..._capturedSweep, 0xFD]));
      expect(sink.sent, hasLength(1), reason: 'a sweep repeats the command byte of the read in flight');
    });

    test('a scope the display turned on goes off with it; one already on stays on', () {
      make({civScopeConfigKey: true});
      sink.answers = {
        civScopeOnOff: [civScopeOnOff, 0x00],
      };
      sink.radio = session.handleData;
      session.startSpectrum();
      expect(sink.sent.map((f) => f.sublist(4, f.length - 1)), anyElement(equals([0x27, 0x10, 0x01])));
      sink.sent.clear();
      session.stopSpectrum();
      expect(sink.sent.map((f) => f.sublist(4, f.length - 1)), [
        [0x27, 0x11, 0x00],
        [0x27, 0x10, 0x00],
      ]);

      make({civScopeConfigKey: true});
      sink.answers = {
        civScopeOnOff: [civScopeOnOff, 0x01],
      };
      sink.radio = session.handleData;
      session.startSpectrum();
      sink.sent.clear();
      session.stopSpectrum();
      expect(sink.sent.map((f) => f.sublist(4, f.length - 1)), [
        [0x27, 0x11, 0x00],
      ]);
    });

    test('a stopped scope refuses a change; a switch to center mode drops the fixed edges', () {
      make({civScopeConfigKey: true});
      sink.radio = session.handleData;
      expect(session.setSpectrum(const SpectrumRequest(spanHz: 5000)), isFalse, reason: 'nothing is running to set');
      session.startSpectrum();
      expect(session.setSpectrum(const SpectrumRequest(spanHz: 5000)), isTrue);
      // A fixed sweep, then the radio's answer that it is centered again.
      final fixedSweep = [..._capturedSweep]..[4] = 0x01;
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ...fixedSweep, 0xFD]));
      expect(sink.settings.last.mode, SpectrumMode.fixed);
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, 0x14, 0x00, 0x00, 0xFD]));
      expect((sink.settings.last.mode, sink.settings.last.lowHz, sink.settings.last.highHz), (SpectrumMode.center, null, null));
    });

    test('a scope command the radio refuses is said, not only printed', () {
      make({civScopeConfigKey: true});
      session.startSpectrum();
      // The first command on the wire is the scope read; the radio NAKs it.
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0xFA, 0xFD]));
      expect(sink.problems.last, t.settings.station.spectrumScopeRefused);
    });

    test('a sweep the radio marks out of range is said, and an in-range one clears it', () {
      make({civScopeConfigKey: true});
      session.startSpectrum();
      final outside = [..._capturedSweep]..[15] = 0x01;
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ...outside, 0xFD]));
      expect(sink.problems.last, t.settings.station.spectrumOutOfRange);
      expect(sink.frames, isEmpty);
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ..._capturedSweep, 0xFD]));
      expect((sink.problems.last, sink.frames.length), (null, 1));
    });

    test('a header with no amplitudes is no sweep', () {
      expect(CivScopeAssembler().add(_capturedSweep.sublist(0, 16)), isNull, reason: 'it would be drawn as an image no pixels wide');
    });

    test('a session torn down mid-display stops the stream on its way out', () {
      make({civScopeConfigKey: true});
      sink.radio = session.handleData;
      session.startSpectrum();
      sink.sent.clear();
      session.teardown();
      expect(sink.sent.map((f) => f.sublist(4, f.length - 1)), anyElement(equals([0x27, 0x11, 0x00])));
    });
  });
}
