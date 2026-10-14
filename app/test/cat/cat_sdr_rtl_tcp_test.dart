// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An SDR behind rtl_tcp: what it is told, and where a signal lands. The
// sweeps are labelled in the LINKED RADIO's frequencies — a carrier drawn a
// few kHz from where it is would send a click-to-tune to the wrong place.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/rtl_tcp_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/sdr_spectrum.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';

class _Sink implements EquipmentSink, SpectrumSink, SdrSink {
  final sent = <Uint8List>[];
  final frames = <SpectrumFrame>[];
  final problems = <String?>[];
  final spectrumProblems = <String?>[];
  final settings = <SpectrumSettings>[];
  @override
  double? linkedVfoHz;

  @override
  void send(List<int> bytes) => sent.add(Uint8List.fromList(bytes));
  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings settings) => this.settings.add(settings);
  @override
  void reportSpectrumProblem(String? message) => spectrumProblems.add(message);
  @override
  void reportProblem(String? message) => problems.add(message);
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportAlive() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  /// The frequencies the device was told, in order.
  List<int> get tuned => [
    for (final command in sent)
      if (command[0] == RtlTcpCommand.frequency) ByteData.sublistView(command).getUint32(1),
  ];
}

const _rate = 2048000;

/// The server's opening: `RTL0`, an R820T, 29 gains.
final _header = Uint8List.fromList([...'RTL0'.codeUnits, 0, 0, 0, 5, 0, 0, 0, 29]);

/// [count] unsigned 8-bit I/Q pairs of a carrier [offsetHz] from the
/// device's centre.
Uint8List _tone(int count, double offsetHz) {
  final out = Uint8List(count * 2);
  for (var n = 0; n < count; n++) {
    final phase = 2 * math.pi * offsetHz * n / _rate;
    out[n * 2] = (127.5 + 100 * math.cos(phase)).round();
    out[n * 2 + 1] = (127.5 + 100 * math.sin(phase)).round();
  }
  return out;
}

/// Where the loudest point of [frame] is, in Hz.
double _peakHz(SpectrumFrame frame) {
  var best = 0;
  for (var i = 1; i < frame.levels.length; i++) {
    if (frame.levels[i] > frame.levels[best]) best = i;
  }
  final step = (frame.highHz - frame.lowHz) / frame.levels.length;
  return frame.lowHz + (best + 0.5) * step;
}

double _stepHz(SpectrumFrame frame) => (frame.highHz - frame.lowHz) / frame.levels.length;

RtlTcpSession _session(_Sink sink, Map<String, dynamic> config) {
  final session = const RtlTcpDriver().createSession(sink, config) as RtlTcpSession;
  session.handleData(_header);
  session.startUpdates();
  return session;
}

void _send(RtlTcpSession session, Uint8List bytes) {
  for (var i = 0; i < bytes.length; i += 65537) {
    session.handleData(Uint8List.sublistView(bytes, i, math.min(i + 65537, bytes.length)));
  }
}

/// Enough IQ for the settle after a retune and one whole sweep, sent in
/// chunks of an odd length so I/Q pairs are split across them.
void _stream(RtlTcpSession session, double offsetHz) {
  final bytes = _tone(_rate ~/ 5, offsetHz);
  for (var i = 0; i < bytes.length; i += 65537) {
    session.handleData(Uint8List.sublistView(bytes, i, math.min(i + 65537, bytes.length)));
  }
}

void main() {
  test('a receiver on its own antenna tunes to the dial and draws a carrier where it is', () {
    final sink = _Sink()..linkedVfoHz = 14100000;
    final session = _session(sink, {sdrTuningConfigKey: 'independent'});
    session.startSpectrum();
    expect(sink.tuned, [14100000]);

    _stream(session, 100000);
    final frame = sink.frames.last;
    expect(frame.lowHz, lessThan(14100000));
    expect(frame.highHz, greaterThan(14200000));
    // Within a point: the waterfall's carrier and the click that tunes to it
    // must agree with the radio's dial.
    expect(_peakHz(frame), closeTo(14200000, _stepHz(frame)));
  });

  test("an upconverter's offset reaches the device and never the labels", () {
    final sink = _Sink()..linkedVfoHz = 14100000;
    final session = _session(sink, {sdrOffsetHzConfigKey: 125000000});
    session.startSpectrum();
    expect(sink.tuned, [139100000], reason: 'the device hears 125 MHz above the band');

    _stream(session, -50000);
    expect(_peakHz(sink.frames.last), closeTo(14050000, _stepHz(sink.frames.last)), reason: 'drawn on the band, not at 139 MHz');
  });

  test("an IF tap stays on the IF and draws the dial's neighbourhood, mirrored when inverted", () {
    final sink = _Sink()..linkedVfoHz = 7074000;
    final session = _session(sink, {sdrTuningConfigKey: 'ifTap', sdrIfHzConfigKey: 10700000, sdrIfInvertedConfigKey: true});
    session.startSpectrum();
    expect(sink.tuned, [10700000]);

    // 5 kHz above the IF is 5 kHz BELOW the dial on a mirrored IF.
    _stream(session, 5000);
    final frame = sink.frames.last;
    expect((frame.lowHz + frame.highHz) / 2, closeTo(7074000, 1));
    expect(_peakHz(frame), closeTo(7069000, _stepHz(frame)));

    // The dial moving moves the labels, not the device.
    sink.linkedVfoHz = 7080000;
    _stream(session, 5000);
    expect(_peakHz(sink.frames.last), closeTo(7075000, _stepHz(sink.frames.last)));
    expect(sink.tuned, [10700000]);
  });

  test('in fixed mode the window stays while the dial moves inside it, and follows it out', () {
    final sink = _Sink()..linkedVfoHz = 14100000;
    final session = _session(sink, const {});
    session.startSpectrum();
    _stream(session, 0);

    sink.linkedVfoHz = 14150000;
    _stream(session, 0);
    expect(sink.tuned, [14100000], reason: "a panel's follow places this window; moving it here would fight it");

    sink.linkedVfoHz = 21074000;
    _stream(session, 0);
    expect(sink.tuned, [14100000, 21074000], reason: 'a dial off the window is never left unseen');
  });

  test('the sweep that moves the window is not drawn at the new one', () {
    final sink = _Sink()..linkedVfoHz = 14100000;
    final session = _session(sink, const {});
    session.startSpectrum();
    _stream(session, 0);

    sink.linkedVfoHz = 21074000;
    final before = sink.frames.length;
    // What the device sends until the retune lands — still the old band, a
    // carrier at +100 kHz — then the new band's, a carrier at -200 kHz.
    _send(session, _tone(150000, 100000));
    _send(session, _tone(400000, -200000));
    final moved = sink.frames.skip(before).where((f) => f.lowHz > 20000000).toList();
    expect(moved, isNotEmpty);
    for (final frame in moved) {
      expect(_peakHz(frame), closeTo(20874000, _stepHz(frame)), reason: 'a sweep of the old band drawn on the new one puts its carrier at 21.174 MHz');
    }
  });

  test('only a window the app holds still reports its edges', () {
    final fixed = _Sink()..linkedVfoHz = 14100000;
    final session = _session(fixed, const {});
    session.startSpectrum();
    expect(fixed.settings.last.lowHz, 14100000 - sdrVisibleHalfWidth(2048000));
    session.setSpectrum(SpectrumRequest(spanHz: sdrVisibleHalfWidth(250000)));
    expect(fixed.settings.last.lowHz, 14100000 - sdrVisibleHalfWidth(250000), reason: 'a narrower span narrows the window it reports');

    final tap = _Sink()..linkedVfoHz = 14074000;
    _session(tap, {sdrTuningConfigKey: 'ifTap', sdrIfHzConfigKey: 68330000}).startSpectrum();
    expect(tap.settings.last.lowHz, isNull, reason: 'edges around the IF would be 54 MHz from every sweep drawn');
  });

  test('a recenter moves a fixed window, and a span change sets the sample rate', () {
    final sink = _Sink()..linkedVfoHz = 14100000;
    final session = _session(sink, const {});
    session.startSpectrum();
    expect(session.spectrumCapabilities.canRecenter, isTrue);

    expect(session.setSpectrum(const SpectrumRequest(centerHz: 14300000)), isTrue);
    expect(sink.tuned.last, 14300000);

    sink.sent.clear();
    session.setSpectrum(SpectrumRequest(spanHz: sdrVisibleHalfWidth(250000)));
    expect(
      [
        for (final c in sink.sent)
          if (c[0] == RtlTcpCommand.sampleRate) ByteData.sublistView(c).getUint32(1),
      ],
      [250000],
    );
  });

  test('an IF tap cannot be recentered: its window is the radio mixer\'s', () {
    final sink = _Sink()..linkedVfoHz = 7074000;
    final session = _session(sink, {sdrTuningConfigKey: 'ifTap', sdrIfHzConfigKey: 10700000});
    session.startSpectrum();
    expect(session.spectrumCapabilities.canRecenter, isFalse);
    session.setSpectrum(const SpectrumRequest(centerHz: 7100000));
    expect(sink.tuned, [10700000]);
  });

  test('an IF tap with no IF set says so, rather than drawing what 0 Hz hears', () {
    final sink = _Sink()..linkedVfoHz = 7074000;
    final session = _session(sink, {sdrTuningConfigKey: 'ifTap'});
    session.startSpectrum();
    expect(sink.tuned, isEmpty);
    _stream(session, 5000);
    expect(sink.frames, isEmpty);
    expect(sink.spectrumProblems.last, t.settings.station.spectrumSdrNoIf);
  });

  test('with no dial to follow it waits and says so, rather than guessing a band', () {
    final sink = _Sink();
    final session = _session(sink, const {});
    session.startSpectrum();
    expect(sink.tuned, isEmpty);
    expect(sink.spectrumProblems.last, t.settings.station.spectrumSdrNoRadio);

    _stream(session, 0);
    expect(sink.frames, isEmpty);

    sink.linkedVfoHz = 3573000;
    _stream(session, 0);
    expect(sink.tuned, [3573000]);
    expect(sink.spectrumProblems.last, isNull);
  });

  test('the setup goes out on connect: automatic gain unless a gain is set, in tenths of a dB', () {
    final auto = _Sink();
    _session(auto, const {});
    expect(auto.sent.map((c) => c[0]), containsAllInOrder([RtlTcpCommand.ppm, RtlTcpCommand.directSampling, RtlTcpCommand.gainMode, RtlTcpCommand.sampleRate]));
    expect(auto.sent.firstWhere((c) => c[0] == RtlTcpCommand.gainMode)[4], 0);

    final manual = _Sink();
    _session(manual, {sdrGainDbConfigKey: 28.0, sdrPpmConfigKey: -2});
    expect(ByteData.sublistView(manual.sent.firstWhere((c) => c[0] == RtlTcpCommand.gain)).getUint32(1), 280);
    // Negative as rtl_tcp reads it back: a 32-bit two's complement.
    expect(ByteData.sublistView(manual.sent.firstWhere((c) => c[0] == RtlTcpCommand.ppm)).getInt32(1), -2);
  });

  test('something that is not an rtl_tcp server is said not to be one, not drawn as noise', () {
    final sink = _Sink();
    final session = const RtlTcpDriver().createSession(sink, const {}) as RtlTcpSession;
    session.handleData(Uint8List.fromList('HTTP/1.1 200 OK\r\n'.codeUnits));
    expect(sink.problems.single, t.settings.station.rtlTcpNotAServer);
  });
}
