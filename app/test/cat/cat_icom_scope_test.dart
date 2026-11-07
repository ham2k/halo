// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/civ_codec.dart' show encodeBcdFrequency;
import 'package:ham2k_logger/services/cat/drivers/civ_scope_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/spectrum_fft.dart' show NoiseFloor;
import 'package:halo_core/halo_core.dart' show AppClock;
import 'package:halo_i18n/halo_i18n.dart';

import '../support/fake_clock.dart';

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

  /// Sees every frame before the radio answers it.
  void Function(List<int> bytes)? heard;
  final frames = <SpectrumFrame>[];
  final settings = <SpectrumSettings>[];

  /// The radio's side: a scope read answers with [answers]' entry for its
  /// sub-command, anything else with an ACK. Null answers nothing.
  void Function(Uint8List frame)? radio;
  Map<int, List<int>> answers = {};

  @override
  void send(List<int> bytes) {
    sent.add(bytes);
    heard?.call(bytes);
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

    test('a sweep in any mode but center is placed by its edges', () {
      // Scroll-C keeps centre mode's span, but its header carries edges like
      // fixed mode's: read as a centre and a span, it would be drawn at 14 MHz ± 14.35.
      final scrollC = [..._capturedSweep]
        ..[4] = civScopeModeScrollC
        ..setRange(5, 15, [0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x35, 0x14, 0x00]);
      final sweep = CivScopeAssembler().add(scrollC)!;
      expect((sweep.mode, sweep.lowHz, sweep.highHz), (civScopeModeScrollC, 14000000, 14350000));
    });

    test('settings answers decode as the radio sent them', () {
      expect(parseScopeSpan([0x15, 0x00, 0x00, 0x25, 0x00, 0x00, 0x00]), 2500);
      expect(parseScopeRef([0x19, 0x00, 0x04, 0x50, 0x01]), -4.5);
      expect(parseScopeMode([0x14, 0x00, 0x03]), civScopeModeScrollF);
      expect(parseScopeEdgeNumber([0x16, 0x00, 0x02]), 2);
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
      // The screen's floor is the radio's, but a scene placing things above the noise needs the noise.
      expect(sink.frames.single.noiseDb, isNotNull);
    });

    test('a sweep never answers a scope read, so it cannot free the wire for a burst', () {
      make({civScopeConfigKey: true});
      session.startSpectrum();
      // The radio has answered nothing; only the first read is on the wire.
      expect(sink.sent, hasLength(1));
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ..._capturedSweep, 0xFD]));
      expect(sink.sent, hasLength(1), reason: 'a sweep repeats the command byte of the read in flight');
    });

    test('from 10 GHz up a sweep is not drawn, and the display says why', () {
      // An IC-905 on its 10 GHz band sends six-byte frequencies in the sweep
      // header, and the assembler reads five: drawn, the sweep is noise
      // placed across an unrelated range.
      make({civScopeConfigKey: true});
      session.startSpectrum();
      // 10.368 GHz, six bytes.
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x00, 0x00, 0x00, 0x10, 0x68, 0x03, 0x01, 0xFD]));
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ..._capturedSweep, 0xFD]));
      expect(sink.frames, isEmpty);
      expect(sink.problems.last, t.settings.station.spectrumBandUnsupported);
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
      // A REF goes out at once; a span only once the app places the edges, which it is not yet.
      expect(session.setSpectrum(const SpectrumRequest(refLevelDb: 0)), isTrue);
      expect(session.setSpectrum(const SpectrumRequest(spanHz: 5000)), isFalse);
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

  group('the automatic scope reference', () {
    late _Sink sink;
    late IcomCivSession session;

    /// The radio's REF: read back as it stands, and moved by a set, the way
    /// an IC-705 does.
    var ref = 0.0;
    void make(String reference) {
      ref = 0;
      sink = _Sink()
        ..heard = (bytes) {
          if (bytes[4] == civScopeCommand && bytes[5] == civScopeRef && bytes.length == 11) ref = parseScopeRef(bytes.sublist(5, 10))!;
          sink.answers[civScopeRef] = buildScopeRefFrame(to: us, from: ic705, refDb: ref).sublist(5, 10);
        };
      session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, config: {civScopeConfigKey: true, civScopeAdjustConfigKey: reference});
      sink.radio = session.handleData;
    }

    List<double> refSets() => [
      for (final f in sink.sent)
        if (f[4] == civScopeCommand && f[5] == civScopeRef && f.length == 11) parseScopeRef(f.sublist(5, 10))!,
    ];

    /// One sweep on 2 m whose every point is the radio's noise: [baseByte]
    /// screen steps at REF 0, moving 2 steps for each dB of REF and clipped
    /// at the bottom of the screen as the radio clips it.
    void sweep(double baseByte) {
      final level = (baseByte + ref * 2).round().clamp(0, civScopeAmplitudeMax);
      final s = [..._capturedSweep.sublist(0, 16), for (var i = 0; i < 475; i++) level];
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ...s, 0xFD]));
    }

    /// Ten sweeps a second for [d].
    void sweepFor(FakeAsync async, Duration d, double Function() baseByte) {
      for (var at = Duration.zero; at < d; at += const Duration(milliseconds: 100)) {
        sweep(baseByte());
        async.elapse(const Duration(milliseconds: 100));
      }
    }

    test('left to the radio, a dark scope is left dark', () {
      followFakeClock();
      fakeAsync((async) {
        make(civScopeAdjustRadio);
        session.startSpectrum();
        sweepFor(async, const Duration(seconds: 5), () => -8);
        expect(refSets(), isEmpty, reason: "REF is the operator's, on the radio, unless they chose Automatic");
      });
    });

    test('automatic lifts clipped noise to where every other radio shows it, then holds', () {
      followFakeClock();
      fakeAsync((async) {
        make(civScopeAdjustApp);
        session.startSpectrum();
        // At REF 0 the noise is 4 dB under the bottom of the screen and reads
        // 0: REF goes up by the whole target, then by what is still missing.
        sweepFor(async, const Duration(seconds: 5), () => -8);
        expect(refSets(), [NoiseFloor.belowNoiseDb, 14]);
        sweepFor(async, const Duration(seconds: 10), () => -8);
        expect(refSets(), [NoiseFloor.belowNoiseDb, 14], reason: 'at the target nothing more is sent, however long it runs');
      });
    });

    test('a burst of static does not move REF', () {
      followFakeClock();
      fakeAsync((async) {
        make(civScopeAdjustApp);
        session.startSpectrum();
        var n = 0;
        sweepFor(async, const Duration(seconds: 5), () => n++ == 15 ? 120 : 20);
        expect(refSets(), isEmpty, reason: 'a reading is a second of sweeps, not the loudest of them');
      });
    });

    test('turning REF while automatic moves the target with it, rather than being turned back', () {
      followFakeClock();
      fakeAsync((async) {
        make(civScopeAdjustApp);
        session.startSpectrum();
        sweepFor(async, const Duration(seconds: 3), () => 20);
        expect(refSets(), isEmpty);
        session.setSpectrum(const SpectrumRequest(refLevelDb: 6));
        sweepFor(async, const Duration(seconds: 10), () => 20);
        expect(refSets(), [6], reason: "only the operator's own set; automatic would take it back to 0");
      });
    });

    test("turned all the way down, automatic still lifts the noise out of the radio's clipping", () {
      followFakeClock();
      fakeAsync((async) {
        make(civScopeAdjustApp);
        session.startSpectrum();
        sweepFor(async, const Duration(seconds: 3), () => 20);
        // Darker by 20 dB: at the bottom of the screen, the noise reads 0.
        session.setSpectrum(const SpectrumRequest(refLevelDb: -20));
        sweepFor(async, const Duration(seconds: 5), () => 20);
        expect(refSets().length, greaterThan(1), reason: 'a clipped reading on target would leave the waterfall black');
        expect(refSets().last, greaterThan(-20));
      });
    });

    test("automatic places the display by the noise, as every other radio's; the radio's own screen is fixed", () {
      followFakeClock();
      fakeAsync((async) {
        make(civScopeAdjustApp);
        session.startSpectrum();
        // The waterfall's window sits a fixed distance above the floor: a
        // floor at the bottom of the radio's screen, under a noise REF could
        // only lift 6 dB, leaves the noise and weak signals black.
        sweepFor(async, const Duration(seconds: 1), () => 12);
        final auto = sink.frames.last;
        expect(auto.floorDb, closeTo(auto.noiseDb! - NoiseFloor.belowNoiseDb, 0.01));
        expect(auto.ceilingDb - auto.floorDb, NoiseFloor.rangeDb);

        make(civScopeAdjustRadio);
        session.startSpectrum();
        sweepFor(async, const Duration(seconds: 1), () => 12);
        expect((sink.frames.last.floorDb, sink.frames.last.ceilingDb), (0, civScopeAmplitudeMax / 2));
      });
    });

    test('an IC-7610 is steered and drawn on its own scale', () {
      followFakeClock();
      fakeAsync((async) {
        // REF stops at +10 there, and the radio refuses a REF past it: a
        // quiet band that wants more is left at +10, never sent +20.
        ref = 0;
        sink = _Sink()
          ..heard = (bytes) {
            if (bytes[4] == civScopeCommand && bytes[5] == civScopeRef && bytes.length == 11) ref = parseScopeRef(bytes.sublist(5, 10))!;
            sink.answers[civScopeRef] = buildScopeRefFrame(to: us, from: ic705, refDb: ref).sublist(5, 10);
          };
        final config = {
          civScopeConfigKey: true,
          civScopeTopConfigKey: 200,
          civScopeRefRangeConfigKey: [-30, 10],
        };
        session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, config: {...config, civScopeAdjustConfigKey: civScopeAdjustApp});
        sink.radio = session.handleData;
        expect((session.spectrumCapabilities.refMinDb, session.spectrumCapabilities.refMaxDb), (-30, 10));
        session.startSpectrum();
        sweepFor(async, const Duration(seconds: 10), () => -30);
        expect(refSets(), isNotEmpty);
        expect(refSets().every((r) => r <= 10), isTrue, reason: 'a REF past +10 is refused by the radio');

        // Its screen is 200 steps tall: a fixed display topped at 160 would cut off its strongest signals.
        session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, config: {...config, civScopeAdjustConfigKey: civScopeAdjustRadio});
        sink.radio = session.handleData;
        session.startSpectrum();
        sweep(20);
        expect(sink.frames.last.ceilingDb, 100);
      });
    });

    test('a new band waits out its own settling before it is read', () {
      followFakeClock();
      fakeAsync((async) {
        make(civScopeAdjustApp);
        session.startSpectrum();
        sweepFor(async, const Duration(seconds: 3), () => 20);
        // 14.1 MHz, its noise clipped: sweeps from while the radio was still
        // bringing back its REF for 20 m. Read, they would move REF.
        final hf = [..._capturedSweep]..setRange(5, 10, [0x00, 0x00, 0x10, 0x14, 0x00]);
        for (var i = 0; i < 15; i++) {
          session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ...hf, 0xFD]));
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(refSets(), isEmpty, reason: 'sweeps straight after a band change are not the new band\'s settled noise');
      });
    });

    test("a new band's REF is read again, not steered from the last band's", () {
      followFakeClock();
      fakeAsync((async) {
        make(civScopeAdjustApp);
        session.startSpectrum();
        // A deaf 2 m: REF goes to its top, +20, the noise still under the screen.
        sweepFor(async, const Duration(seconds: 6), () => -60);
        expect(refSets().last, 20);
        // On 20 m the radio brings back the REF it keeps there, 0, and the noise there reads 0 at it.
        // Steered from 2 m's +20, REF would look held at the top and never move.
        ref = 0;
        session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x00, ...encodeBcdFrequency(14100000), 0xFD]));
        final sent = refSets().length;
        for (var i = 0; i < 50; i++) {
          final level = (-8 + ref * 2).round().clamp(0, civScopeAmplitudeMax);
          final s = [..._capturedSweep.sublist(0, 16), for (var j = 0; j < 475; j++) level]..setRange(5, 10, [0x00, 0x00, 0x10, 0x14, 0x00]);
          session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ...s, 0xFD]));
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(refSets().skip(sent), contains(NoiseFloor.belowNoiseDb));
      });
    });

    test("a sweep panned back and forth across a band's edge is steered by the dial's band", () {
      followFakeClock();
      fakeAsync((async) {
        make(civScopeAdjustApp);
        session.startSpectrum();
        session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x00, ...encodeBcdFrequency(144010000), 0xFD]));
        // Scroll-F sweeps whose middles fall either side of 144 MHz, the noise clipped. Taken by the
        // sweep's middle, each would start the band's reading over, and REF would never move.
        for (var i = 0; i < 50; i++) {
          final low = i.isEven ? 143850000 : 143950000;
          final s = [..._capturedSweep.sublist(0, 16), for (var j = 0; j < 475; j++) 0]
            ..[4] = civScopeModeScrollF
            ..setRange(5, 15, [...encodeBcdFrequency(low), ...encodeBcdFrequency(low + 200000)]);
          session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ...s, 0xFD]));
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(refSets(), isNotEmpty);
      });
    });

    test('the settling spell runs on real time, not the travelled clock', () {
      followFakeClock();
      fakeAsync((async) {
        make(civScopeAdjustApp);
        session.startSpectrum();
        sweep(-8);
        AppClock.instance.travel(delta: const Duration(days: 3));
        sweep(-8);
        sweep(-8);
        expect(refSets(), isEmpty, reason: 'three days of developer time travel is not a second of sweeps');
      });
    });
  });

  group('the app adjusting the scope', () {
    late _Sink sink;
    late IcomCivSession session;

    /// An IC-705 whose scope shows fixed-edge preset 2.
    void make(Map<String, dynamic> config) {
      sink = _Sink()
        ..answers = {
          civScopeEdgeNumber: [civScopeEdgeNumber, 0x00, 0x02],
        };
      session = IcomCivSession(
        sink,
        radioAddress: ic705,
        controllerAddress: us,
        config: {civScopeConfigKey: true, civScopeEdgeRangesConfigKey: civScopeEdgeRangesIc705, ...config},
      );
      sink.radio = session.handleData;
    }

    void tuneTo(int hz) => session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x00, ...encodeBcdFrequency(hz), 0xFD]));

    /// A sweep in [mode] whose header carries [first] and [second], as the radio sends it.
    void sweep(int mode, int first, int second) {
      final s = [..._capturedSweep]
        ..[4] = mode
        ..setRange(5, 15, [...encodeBcdFrequency(first), ...encodeBcdFrequency(second)]);
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x27, ...s, 0xFD]));
    }

    /// What was set — every scope frame longer than a read — by sub-command and data.
    List<List<int>> sets([int? sub]) => [
      for (final f in sink.sent)
        if (f[4] == civScopeCommand && f.length > 8 && (sub == null || f[5] == sub)) f.sublist(5, f.length - 1),
    ];

    test('by default a centred scope goes to Scroll-F over the very window it shows, so the picture does not jump', () {
      followFakeClock();
      fakeAsync((async) {
        make({});
        session.startSpectrum();
        tuneTo(144025000);
        sweep(civScopeModeCenter, 144025000, 100000);
        // Range 16 (137–200 MHz) of the IC-705's table, preset 2, 143.925–144.125 MHz.
        const edges = [civScopeEdges, 0x16, 0x02, 0x00, 0x50, 0x92, 0x43, 0x01, 0x00, 0x50, 0x12, 0x44, 0x01];
        expect(sets(), [
          edges,
          [civScopeMode, 0x00, civScopeModeScrollF],
        ], reason: 'switched before its preset holds the window shown, Scroll-F would show wherever the preset was left');

        sweep(civScopeModeScrollF, 143925000, 144125000);
        sweep(civScopeModeScrollF, 143925000, 144125000);
        expect(sets(), hasLength(2), reason: 'in Scroll-F there is nothing more to set');

        // Later the operator presses CENT on the radio: put back, but not on every sweep while the
        // switch is on its way to them.
        async.elapse(const Duration(seconds: 5));
        sweep(civScopeModeCenter, 144025000, 100000);
        expect(sets(civScopeMode), hasLength(2));
        expect(sets(civScopeEdges), hasLength(2), reason: 'the window it shows now goes into the preset first, as the first time');
        sweep(civScopeModeCenter, 144025000, 100000);
        expect(sets(civScopeMode), hasLength(2));
        async.elapse(const Duration(seconds: 2));
        sweep(civScopeModeCenter, 144025000, 100000);
        expect(sets(civScopeMode), hasLength(3));
      });
    });

    test('closing the display gives the radio its own mode back; a radio already in Scroll-F keeps it', () {
      make({});
      session.startSpectrum();
      tuneTo(144025000);
      sweep(civScopeModeFixed, 143900000, 144100000);
      sink.sent.clear();
      session.stopSpectrum();
      expect(sink.sent.map((f) => f.sublist(4, f.length - 1)).take(2), [
        [0x27, civScopeMode, 0x00, civScopeModeFixed],
        [0x27, civScopeOutput, 0x00],
      ]);

      make({});
      session.startSpectrum();
      tuneTo(144025000);
      sweep(civScopeModeScrollF, 143900000, 144100000);
      sink.sent.clear();
      session.stopSpectrum();
      expect(sets(civScopeMode), isEmpty);
    });

    test("a pan or a zoom moves the preset's edges, kept inside the band range the radio takes them in", () {
      make({});
      session.startSpectrum();
      tuneTo(144025000);
      sweep(civScopeModeScrollF, 143925000, 144125000);
      expect(session.spectrumCapabilities.canRecenter, isTrue);
      expect(session.setSpectrum(const SpectrumRequest(centerHz: 144100000)), isTrue);
      expect(sets(civScopeEdges).last, [civScopeEdges, 0x16, 0x02, ...encodeBcdFrequency(144000000), ...encodeBcdFrequency(144200000)]);
      // Past the dial: as near the window as edges a kHz either side of the dial go. Scroll-F scrolls
      // edges that leave the dial out back over it, nowhere near the window they were placed for.
      session.setSpectrum(const SpectrumRequest(centerHz: 144300000));
      expect(sets(civScopeEdges).last, [civScopeEdges, 0x16, 0x02, ...encodeBcdFrequency(144024000), ...encodeBcdFrequency(144224000)]);
      // Those the radio shows already are not written again, as a pan held past the dial asks for them.
      sweep(civScopeModeScrollF, 144024000, 144224000);
      final written = sets(civScopeEdges).length;
      session.setSpectrum(const SpectrumRequest(centerHz: 144350000));
      expect(sets(civScopeEdges), hasLength(written));
      // A zoom: twice the span wide, about the middle of what is shown. Its noise moves with the width,
      // so REF is read again.
      sink.sent.clear();
      session.setSpectrum(const SpectrumRequest(spanHz: 250000));
      expect(sink.sent.map((f) => f.sublist(4, f.length - 1)), contains(equals([0x27, civScopeRef, 0x00])));
      expect(sets(civScopeEdges).last, [civScopeEdges, 0x16, 0x02, ...encodeBcdFrequency(143874000), ...encodeBcdFrequency(144374000)]);

      // At the top of 160 m, range 2 ends at 2 MHz: edges past it are refused.
      tuneTo(1990000);
      sweep(civScopeModeScrollF, 1890000, 1990000);
      session.setSpectrum(const SpectrumRequest(centerHz: 1995000));
      expect(sets(civScopeEdges).last, [civScopeEdges, 0x02, 0x02, ...encodeBcdFrequency(1900000), ...encodeBcdFrequency(2000000)]);
    });

    test("edges the radio refuses are not said as a refused scope: the radio still scrolls it", () {
      make({});
      session.startSpectrum();
      tuneTo(144025000);
      sweep(civScopeModeScrollF, 143925000, 144125000);
      sink.radio = null;
      session.setSpectrum(const SpectrumRequest(centerHz: 147900000));
      session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0xFA, 0xFD]));
      expect(sink.problems, isNot(contains(t.settings.station.spectrumScopeRefused)));
      // Not asked again, nor said done: a dial held by a range's end would send it four times a second.
      final written = sets(civScopeEdges).length;
      expect(session.setSpectrum(const SpectrumRequest(centerHz: 147900000)), isFalse);
      expect(sets(civScopeEdges), hasLength(written));
    });

    test('a radio that refuses Scroll-F is left in its own mode, not asked every 2 s under a flickering notice', () {
      followFakeClock();
      fakeAsync((async) {
        make({});
        session.startSpectrum();
        tuneTo(144025000);
        // Answered by hand from here: the edges taken, the switch to Scroll-F refused.
        sink.radio = null;
        sweep(civScopeModeCenter, 144025000, 100000);
        session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0xFB, 0xFD]));
        expect(sink.sent.last.sublist(4, sink.sent.last.length - 1), [civScopeCommand, civScopeMode, 0x00, civScopeModeScrollF]);
        session.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0xFA, 0xFD]));
        expect(sink.problems, isNot(contains(t.settings.station.spectrumScopeRefused)));
        sink.radio = session.handleData;
        final modeSets = sets(civScopeMode).length;
        async.elapse(const Duration(seconds: 5));
        sweep(civScopeModeCenter, 144025000, 100000);
        expect(sets(civScopeMode), hasLength(modeSets));
      });
    });

    test('a dial on the end two band ranges share is in the upper one, as the radio shows it', () {
      make({civScopeEdgeRangesConfigKey: civScopeEdgeRanges});
      session.startSpectrum();
      // 2.000 MHz ends range 2 (1.6–2.0) and begins range 3 (2.0–6.0).
      tuneTo(2000000);
      sweep(civScopeModeScrollF, 2050000, 2150000);
      session.setSpectrum(const SpectrumRequest(centerHz: 2060000));
      expect(sets(civScopeEdges).last[1], 0x03);
    });

    test('a pan or a zoom is said done only once edges went to the radio', () {
      followFakeClock();
      fakeAsync((async) {
        make({});
        session.startSpectrum();
        tuneTo(144025000);
        // Centred, the switch to Scroll-F on its way: nothing a pan could move yet. Said done, the
        // window would run off into filler after a scope that never moves, and never ask again.
        sweep(civScopeModeCenter, 144025000, 100000);
        expect(session.setSpectrum(const SpectrumRequest(centerHz: 144100000)), isFalse);
        sweep(civScopeModeScrollF, 143925000, 144125000);
        expect(session.setSpectrum(const SpectrumRequest(centerHz: 144100000)), isTrue);
      });
    });

    test('a lost answer for the preset is asked again, not left to hold Scroll-F off for the whole display', () {
      followFakeClock();
      fakeAsync((async) {
        make({});
        sink.answers = {};
        session.startSpectrum();
        tuneTo(144025000);
        int presetReads() => sink.sent.where((f) => f[4] == civScopeCommand && f.length <= 8 && f[5] == civScopeEdgeNumber).length;
        final asked = presetReads();
        sweep(civScopeModeCenter, 144025000, 100000);
        expect(sets(civScopeMode), isEmpty);
        sink.answers = {
          civScopeEdgeNumber: [civScopeEdgeNumber, 0x00, 0x02],
        };
        async.elapse(const Duration(seconds: 3));
        sweep(civScopeModeCenter, 144025000, 100000);
        expect(presetReads(), greaterThan(asked));
        async.elapse(const Duration(seconds: 3));
        sweep(civScopeModeCenter, 144025000, 100000);
        expect(sets(civScopeMode).last, [civScopeMode, 0x00, civScopeModeScrollF]);
      });
    });

    test("left as the radio has it, nothing about the scope is sent, and nothing past its sweep is offered", () {
      make({civScopeAdjustConfigKey: civScopeAdjustRadio});
      final caps = session.spectrumCapabilities;
      expect(
        (caps.spansHz.isEmpty, caps.canRecenter, caps.refMaxDb > caps.refMinDb, caps.speeds.isEmpty, caps.modes.isEmpty),
        (true, false, false, true, true),
      );
      session.startSpectrum();
      tuneTo(144025000);
      sweep(civScopeModeCenter, 144025000, 100000);
      for (final request in const [
        SpectrumRequest(spanHz: 250000),
        SpectrumRequest(centerHz: 144300000),
        SpectrumRequest(refLevelDb: 10),
        SpectrumRequest(speed: SpectrumSpeed.fast),
      ]) {
        expect(session.setSpectrum(request), isFalse);
      }
      session.stopSpectrum();
      expect(sets(), isEmpty, reason: "the scope's mode, edges, span, REF and speed are the operator's");
    });
  });
}
