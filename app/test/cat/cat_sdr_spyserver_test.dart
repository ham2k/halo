// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An SDR behind SpyServer: what it is told, and where a signal in the
// server's own sweeps lands. The server never answers a setting, so the only
// truth about where a sweep was taken is what this client asked for — a label
// computed from anything else draws a carrier where it is not.

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/sdr_spectrum.dart';
import 'package:ham2k_logger/services/cat/drivers/spyserver_driver.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';

class _Sink implements EquipmentSink, SpectrumSink, SdrSink {
  final sent = <Uint8List>[];
  final frames = <SpectrumFrame>[];
  final problems = <String?>[];
  final spectrumProblems = <String?>[];
  final drops = <String>[];
  int alive = 0;

  /// Set, the next sweep reported throws: a fault in whatever draws it.
  bool throwOnSpectrum = false;
  @override
  double? linkedVfoHz;

  @override
  void send(List<int> bytes) => sent.add(Uint8List.fromList(bytes));
  @override
  void reportSpectrum(SpectrumFrame frame) {
    if (throwOnSpectrum) {
      throwOnSpectrum = false;
      throw StateError('drawing failed');
    }
    frames.add(frame);
  }

  @override
  void reportSpectrumSettings(SpectrumSettings settings) {}
  @override
  void reportSpectrumProblem(String? message) => spectrumProblems.add(message);
  @override
  void dropConnection(String why) => drops.add(why);
  @override
  void reportProblem(String? message) => problems.add(message);
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportAlive() => alive++;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  /// Every SET_SETTING sent, in order, as (setting, value).
  List<(int, int)> get settings => [
    for (final command in sent)
      if (ByteData.sublistView(command).getUint32(0, Endian.little) == SpyServerCommand.setSetting)
        (ByteData.sublistView(command).getUint32(8, Endian.little), ByteData.sublistView(command).getUint32(12, Endian.little)),
  ];

  List<int> valuesOf(int setting) => [
    for (final (s, v) in settings)
      if (s == setting) v,
  ];
}

Uint8List _message(int kind, List<int> body, {int version = spyServerProtocolVersion, int stream = 0}) {
  final header = ByteData(20)
    ..setUint32(0, version, Endian.little)
    ..setUint32(4, kind, Endian.little)
    ..setUint32(8, stream, Endian.little)
    ..setUint32(16, body.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...body]);
}

Uint8List _words(List<int> words) {
  final data = ByteData(words.length * 4);
  for (var i = 0; i < words.length; i++) {
    data.setUint32(i * 4, words[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

/// An RTL-SDR's server, as captured: 2.4 MS/s with 2 MHz usable, nine
/// halvings, gain steps 0–29, 24 MHz to 1.8 GHz.
final _deviceInfo = _deviceInfoWith();

/// A server's build, in a header's version word.
int _build(int build) => 2 << 24 | build;

Uint8List _deviceInfoWith({int stages = 9, int maxGain = 29, int minHz = 24000000, int maxHz = 1800000000, int version = spyServerProtocolVersion}) =>
    _message(SpyServerMessage.deviceInfo, _words([3, 1, 2400000, 2000000, stages, 0, maxGain, minHz, maxHz, 8, 0, 0]), version: version);

Uint8List _clientSync({bool control = true, int deviceHz = 100000000}) =>
    _message(SpyServerMessage.clientSync, _words([control ? 1 : 0, 10, deviceHz, deviceHz, deviceHz, 0, 0, 0, 0]));

/// A sweep of noise with one carrier at [bin].
Uint8List _sweep(int bin) => _message(SpyServerMessage.uint8Fft, [for (var i = 0; i < spyServerFftPixels; i++) i == bin ? 220 : 90], stream: 4);

double _peakHz(SpectrumFrame frame) {
  var best = 0;
  for (var i = 1; i < frame.levels.length; i++) {
    if (frame.levels[i] > frame.levels[best]) best = i;
  }
  final step = (frame.highHz - frame.lowHz) / frame.levels.length;
  return frame.lowHz + (best + 0.5) * step;
}

/// The default span: the middle of the halvings offered, 2 MHz / 2^4.
const _span = 125000;
const _bin = _span / spyServerFftPixels;

/// Past the sweeps a first tune throws away: they were taken wherever the
/// server's window was before.
void _settle(SpyServerSession session) {
  session.handleData(_sweep(0));
  session.handleData(_sweep(0));
}

SpyServerSession _session(_Sink sink, [Map<String, dynamic> config = const {}]) {
  final session = const SpyServerDriver().createSession(sink, config) as SpyServerSession;
  session.startUpdates();
  return session;
}

void main() {
  test('the hello names the protocol version and the client, with no terminator', () {
    final sink = _Sink();
    _session(sink);
    final hello = sink.sent.single;
    final data = ByteData.sublistView(hello);
    expect(data.getUint32(0, Endian.little), SpyServerCommand.hello);
    expect(data.getUint32(4, Endian.little), hello.length - 8);
    expect(data.getUint32(8, Endian.little), 0x020006A4);
    expect(String.fromCharCodes(hello.sublist(12)), 'Ham2K Logger');
  });

  test('a display waiting before the handshake ends starts the stream once it has', () {
    final sink = _Sink()..linkedVfoHz = 144200000;
    final session = _session(sink);
    session.startSpectrum();
    expect(sink.settings, isEmpty, reason: 'nothing is known yet of what the receiver can do');

    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    expect(sink.valuesOf(SpyServerSetting.streamingMode), [5], reason: 'the spectrum alone arrives empty');
    expect(sink.valuesOf(SpyServerSetting.fftDisplayPixels), [spyServerFftPixels]);
    expect(sink.valuesOf(SpyServerSetting.fftDecimation), [4]);
    final order = [for (final (s, _) in sink.settings) s];
    expect(order.indexOf(SpyServerSetting.fftFrequency), lessThan(order.indexOf(SpyServerSetting.iqFrequency)), reason: 'the receiver follows the window');
    expect(order.last, SpyServerSetting.streamingEnabled);
    expect(sink.valuesOf(SpyServerSetting.fftFrequency), [144200000]);
  });

  test("a carrier in the server's sweep is drawn where it is", () {
    final sink = _Sink()..linkedVfoHz = 144200000;
    final session = _session(sink);
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    session.startSpectrum();
    _settle(session);

    // Bins rise from the window's low edge: the span is the usable bandwidth's
    // halving, not the sample rate's, which would put this 2.3 kHz off.
    session.handleData(_sweep(1424));
    final frame = sink.frames.last;
    expect(frame.lowHz, 144200000 - _span / 2);
    expect(frame.highHz, 144200000 + _span / 2);
    expect(_peakHz(frame), closeTo(144200000 - _span / 2 + 1424.5 * _bin, _bin));
  });

  test('messages split anywhere, or run together, read the same; unknown kinds and IQ are passed over', () {
    final sink = _Sink()..linkedVfoHz = 144200000;
    final session = _session(sink);
    session.startSpectrum();
    final stream = Uint8List.fromList([
      ..._deviceInfo,
      ..._message(9999, [1, 2, 3]),
      ..._clientSync(),
      ..._message(100, List.filled(64, 128), stream: 1),
      ..._message(2, const []),
      ..._sweep(1000),
      ..._sweep(1000),
      ..._sweep(1000),
    ]);
    for (var i = 0; i < stream.length; i += 7) {
      session.handleData(Uint8List.sublistView(stream, i, i + 7 > stream.length ? stream.length : i + 7));
    }
    expect(sink.problems, isEmpty);
    expect(sink.frames, hasLength(1));
  });

  test('a client that may not retune keeps its window inside what the receiver hears', () {
    final sink = _Sink()..linkedVfoHz = 145450000;
    final session = _session(sink);
    session.startSpectrum();
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync(control: false, deviceHz: 144500000)]));

    // 2 MHz around 144.5 MHz, less half the 125 kHz window.
    expect(sink.valuesOf(SpyServerSetting.fftFrequency), [145437500]);
    _settle(session);
    session.handleData(_sweep(1024));
    expect(sink.frames.last.lowHz, 145437500 - _span / 2, reason: 'labelled where the server put it, not where the dial is');

    // A dial past the edge would sit off the picture: said, not drawn.
    sink.linkedVfoHz = 146000000;
    final drawn = sink.frames.length;
    for (var i = 0; i < 3; i++) {
      session.handleData(_sweep(1024));
    }
    expect(sink.frames, hasLength(drawn));
    expect(sink.spectrumProblems.last, t.settings.station.spectrumSdrUnreachable);
    expect(sink.valuesOf(SpyServerSetting.fftFrequency), hasLength(1), reason: 'a dial it cannot reach is not chased on every sweep');

    // Back within reach: retuned, and drawn once the sweeps in flight pass.
    sink.linkedVfoHz = 145000000;
    for (var i = 0; i < 4; i++) {
      session.handleData(_sweep(1024));
    }
    expect(sink.spectrumProblems.last, isNull);
    expect(sink.frames.last.lowHz, 145000000 - _span / 2);
  });

  test("a spectator's window also stays inside the range the server's operator allows", () {
    // A receiver centred above the band its operator opened, as one public
    // server is: what it hears reaches past what the server allows.
    final sink = _Sink()..linkedVfoHz = 27400000;
    final session = _session(sink);
    session.startSpectrum();
    session.handleData(Uint8List.fromList([..._deviceInfoWith(minHz: 26565000, maxHz: 27405000), ..._clientSync(control: false, deviceHz: 27565000)]));
    expect(sink.valuesOf(SpyServerSetting.fftFrequency), [
      27405000 - _span ~/ 2,
    ], reason: 'the server clamps it there, and a sweep labelled at the dial would be off');
  });

  test('a range narrower than the window, or none reported, still says when the dial is out of reach', () {
    // 100 kHz allowed, a 125 kHz window: the server clamps it to the top.
    final narrow = _Sink()..linkedVfoHz = 144200000;
    final session = _session(narrow);
    session.startSpectrum();
    session.handleData(Uint8List.fromList([..._deviceInfoWith(minHz: 432000000, maxHz: 432100000), ..._clientSync()]));
    _settle(session);
    session.handleData(_sweep(1024));
    expect(narrow.frames, isEmpty, reason: 'returned unclamped, 432 MHz would be drawn as the band around 144.2');
    expect(narrow.spectrumProblems.last, t.settings.station.spectrumSdrUnreachable);

    // Some servers leave both ends at zero: a spectator is still held to what
    // the receiver hears.
    final unbounded = _Sink()..linkedVfoHz = 146000000;
    final watching = _session(unbounded);
    watching.startSpectrum();
    watching.handleData(Uint8List.fromList([..._deviceInfoWith(minHz: 0, maxHz: 0), ..._clientSync(control: false, deviceHz: 144500000)]));
    expect(unbounded.valuesOf(SpyServerSetting.fftFrequency), [145437500]);
  });

  test('an independent window the receiver cannot reach is said so, not drawn as the band', () {
    // An RTL-SDR starts at 24 MHz; a radio on 20 m is below it.
    final sink = _Sink()..linkedVfoHz = 14074000;
    final session = _session(sink);
    session.startSpectrum();
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    _settle(session);
    session.handleData(_sweep(1024));
    expect(sink.frames, isEmpty, reason: 'the sweep is of 24 MHz, with the dial nowhere on it');
    expect(sink.spectrumProblems.last, t.settings.station.spectrumSdrUnreachable);
  });

  test('when another client moves the receiver, the window follows it inside', () {
    final sink = _Sink()..linkedVfoHz = 144200000;
    final session = _session(sink);
    session.startSpectrum();
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync(control: false, deviceHz: 144500000)]));
    expect(sink.valuesOf(SpyServerSetting.fftFrequency), [144200000]);

    session.handleData(_clientSync(control: false, deviceHz: 146000000));
    expect(sink.valuesOf(SpyServerSetting.fftFrequency).last, 146000000 - 1000000 + _span ~/ 2);
  });

  test('gain is set only by a client in control, and kept to the steps the receiver has', () {
    final controlling = _Sink();
    _session(controlling, {spyServerGainConfigKey: 40}).handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    expect(controlling.valuesOf(SpyServerSetting.gain), [29]);

    final watching = _Sink();
    _session(watching, {spyServerGainConfigKey: 10}).handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync(control: false)]));
    expect(watching.valuesOf(SpyServerSetting.gain), isEmpty, reason: "the receiver's gain belongs to the client in control");

    final unset = _Sink();
    _session(unset).handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    expect(unset.valuesOf(SpyServerSetting.gain), isEmpty, reason: 'blank leaves the server as its operator set it');

    final stepless = _Sink();
    _session(stepless, {spyServerGainConfigKey: 10}).handleData(Uint8List.fromList([..._deviceInfoWith(maxGain: 0), ..._clientSync()]));
    expect(stepless.valuesOf(SpyServerSetting.gain), isEmpty, reason: 'some HF+ servers have no steps: 0 would be a gain asked for, not none');
  });

  test('the IQ thrown away is as narrow as the server still sends a spectrum with', () {
    final current = _Sink();
    _session(current).handleData(Uint8List.fromList([..._deviceInfoWith(version: _build(1920)), ..._clientSync()]));
    expect(current.valuesOf(SpyServerSetting.iqDecimation), [8], reason: 'the narrowest the receiver offers: 9.4 kS/s');

    // Measured on 2.0.1700 and 2.0.1822 servers: no spectrum at 12 kS/s of IQ
    // or less, a spectrum at 19.5 kS/s or more.
    final older = _Sink();
    _session(older).handleData(Uint8List.fromList([..._deviceInfoWith(version: _build(1822)), ..._clientSync()]));
    expect(older.valuesOf(SpyServerSetting.iqDecimation), [6], reason: '37.5 kS/s: the halving below, 18.75 kS/s, is under the floor');
  });

  test('the sweeps sent before a retune landed are not drawn at the new window', () {
    final sink = _Sink()..linkedVfoHz = 144200000;
    final session = _session(sink);
    session.startSpectrum();
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    _settle(session);
    session.handleData(_sweep(1024));

    sink.linkedVfoHz = 432100000;
    final before = sink.frames.length;
    session.handleData(_sweep(1024)); // moves the window, is itself the old one
    session.handleData(_sweep(1024));
    session.handleData(_sweep(1024));
    expect(sink.frames.length, before, reason: 'still in flight from the old window');
    session.handleData(_sweep(1024));
    expect(sink.frames.last.lowHz, 432100000 - _span / 2);
  });

  test('stopping the display stops the stream', () {
    final sink = _Sink()..linkedVfoHz = 144200000;
    final session = _session(sink);
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    session.startSpectrum();
    session.stopSpectrum();
    expect(sink.valuesOf(SpyServerSetting.streamingEnabled), [1, 0]);
  });

  test('a server with no receiver, another version, or no SpyServer at all says so, and is dropped to be tried again', () {
    final empty = _Sink();
    _session(empty).handleData(_message(SpyServerMessage.deviceInfo, _words(List.filled(12, 0))));
    expect(empty.drops, [t.settings.station.spyServerNoDevice], reason: 'a receiver plugged in later is found on the next try');

    final newer = _Sink();
    _session(newer).handleData(_message(SpyServerMessage.deviceInfo, _words(List.filled(12, 0)), version: 3 << 24));
    expect(newer.drops, [t.settings.station.spyServerNotAServer]);

    // An rtl_tcp server's greeting, read as a header: held open, it would
    // stay locked to this client.
    final rtlTcp = _Sink();
    _session(rtlTcp).handleData(Uint8List.fromList([...'RTL0'.codeUnits, ...List.filled(20, 0)]));
    expect(rtlTcp.drops, [t.settings.station.spyServerNotAServer]);
    for (final sink in [empty, newer, rtlTcp]) {
      expect(sink.problems, isEmpty, reason: 'a problem would be held, and the connection with it');
    }
  });

  test('a stream out of step is dropped to be made again, not held open and ignored', () {
    final garbled = _Sink()..linkedVfoHz = 144200000;
    final session = _session(garbled);
    session.startSpectrum();
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    final huge = ByteData(20)
      ..setUint32(0, spyServerProtocolVersion, Endian.little)
      ..setUint32(16, 2 << 20, Endian.little);
    session.handleData(huge.buffer.asUint8List());
    session.handleData(_sweep(1024));
    expect(garbled.drops, [t.settings.station.spyServerGarbled], reason: 'reconnecting from the hello is the only way back in step');
    expect(garbled.problems, isEmpty);
    expect(garbled.frames, isEmpty, reason: 'every header after one out of step is garbage');

    // Out of step, a header nearly always fails the version check first:
    // after the handshake that is garbage, not a server of another version.
    final versioned = _Sink();
    final other = _session(versioned);
    other.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    other.handleData(Uint8List.fromList(List.filled(20, 0xA5)));
    expect(versioned.drops, [t.settings.station.spyServerGarbled]);

    final short = _Sink();
    _session(short).handleData(_message(SpyServerMessage.deviceInfo, _words([3, 1, 2400000])));
    expect(short.drops, hasLength(1), reason: 'a handshake that cannot finish would otherwise wait forever');
  });

  test('a message whose drawing fails does not put the stream out of step', () {
    final sink = _Sink()..linkedVfoHz = 144200000;
    final session = _session(sink);
    session.startSpectrum();
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    _settle(session);

    // The chunk that throws also carries the start of the next sweep.
    final next = _sweep(1024);
    sink.throwOnSpectrum = true;
    expect(() => session.handleData(Uint8List.fromList([..._sweep(1024), ...next.sublist(0, 100)])), throwsStateError);
    session.handleData(next.sublist(100));
    expect(sink.frames, hasLength(1));
    expect(sink.problems, isEmpty);
    expect(sink.drops, isEmpty);
  });

  test('a ping goes out while nothing streams, and its answer counts as the server being there', () {
    fakeAsync((async) {
      final sink = _Sink();
      final session = _session(sink);
      session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
      int pings() => sink.sent.where((c) => ByteData.sublistView(c).getUint32(0, Endian.little) == SpyServerCommand.ping).length;

      async.elapse(spyServerPingInterval * 2);
      expect(pings(), 2, reason: 'connected with no display, the server sends nothing to say it is alive');
      session.handleData(_message(SpyServerMessage.pong, const []));
      expect(sink.alive, 1);

      session.teardown();
      async.elapse(spyServerPingInterval * 2);
      expect(pings(), 2);
      expect(sink.drops, isEmpty, reason: 'with no display, no sweep is owed');
    });
  });

  test('something on the port that never answers the hello is dropped as not a SpyServer', () {
    fakeAsync((async) {
      // Another service waiting for its own protocol, with no display yet:
      // an operator's Connect would otherwise hold it as a server being
      // waited for.
      final silent = _Sink();
      final session = _session(silent);
      async.elapse(spyServerPingInterval);
      expect(silent.drops, isEmpty, reason: 'one interval of grace: a small server opens its radio first');
      async.elapse(spyServerPingInterval);
      expect(silent.drops, [t.settings.station.spyServerNotAServer]);
      session.teardown();

      final halfway = _Sink();
      final other = _session(halfway);
      other.handleData(_deviceInfo);
      async.elapse(spyServerPingInterval * 2);
      expect(halfway.drops, [t.settings.station.spyServerNotAServer], reason: 'device info alone is not a handshake');
      other.teardown();
    });
  });

  test('a stream that brings no spectrum is dropped, and one that does is kept', () {
    fakeAsync((async) {
      final silent = _Sink()..linkedVfoHz = 144200000;
      final session = _session(silent);
      session.startSpectrum();
      session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
      async.elapse(spyServerPingInterval);
      expect(silent.drops, isEmpty, reason: 'one interval of grace to start');
      async.elapse(spyServerPingInterval);
      expect(silent.drops, [t.settings.station.spyServerNoSpectrum], reason: 'or the display waits forever on a server that streams none');

      final streaming = _Sink()..linkedVfoHz = 144200000;
      final other = _session(streaming);
      other.startSpectrum();
      other.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
      for (var i = 0; i < 4; i++) {
        async.elapse(spyServerPingInterval ~/ 2);
        other.handleData(_sweep(0));
      }
      expect(streaming.drops, isEmpty);
      other.teardown();
      session.teardown();
    });
  });

  test('a client that gains control later sets its gain then', () {
    final sink = _Sink();
    final session = _session(sink, {spyServerGainConfigKey: 12});
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync(control: false)]));
    expect(sink.valuesOf(SpyServerSetting.gain), isEmpty);
    session.handleData(_clientSync());
    expect(sink.valuesOf(SpyServerSetting.gain), [12], reason: "or the receiver keeps the last client's gain");
  });

  test('an IF the receiver cannot be tuned to is said so, and never drawn from somewhere else', () {
    // An RTL-SDR starts at 24 MHz; a 9 MHz IF is not on it.
    final low = _Sink()..linkedVfoHz = 14074000;
    final session = _session(low, {sdrTuningConfigKey: 'ifTap', sdrIfHzConfigKey: 9000000});
    session.startSpectrum();
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    expect(low.valuesOf(SpyServerSetting.fftFrequency), isEmpty);
    _settle(session);
    session.handleData(_sweep(1024));
    expect(low.frames, isEmpty, reason: 'clamped to 24 MHz, the sweep would be drawn as the band around 14.074');
    expect(low.spectrumProblems.last, t.settings.station.spectrumSdrUnreachable);

    // Another client has the receiver elsewhere, then brings it within reach.
    final watching = _Sink()..linkedVfoHz = 14074000;
    final tap = _session(watching, {sdrTuningConfigKey: 'ifTap', sdrIfHzConfigKey: 68330000});
    tap.startSpectrum();
    tap.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync(control: false, deviceHz: 145000000)]));
    expect(watching.valuesOf(SpyServerSetting.fftFrequency), isEmpty);
    tap.handleData(_clientSync(control: false, deviceHz: 68500000));
    expect(watching.valuesOf(SpyServerSetting.fftFrequency), [68330000]);
    expect(watching.spectrumProblems.last, isNull);

    // Moved away and back: the server clamped the window meanwhile, so the
    // IF is sent again.
    tap.handleData(_clientSync(control: false, deviceHz: 145000000));
    expect(watching.spectrumProblems.last, t.settings.station.spectrumSdrUnreachable);
    tap.handleData(_clientSync(control: false, deviceHz: 68500000));
    expect(watching.valuesOf(SpyServerSetting.fftFrequency), [68330000, 68330000]);
  });

  test("a carrier in the middle of a server's sweep is drawn, not taken for the receiver's DC", () {
    final sink = _Sink()..linkedVfoHz = 144200000;
    final session = _session(sink);
    session.startSpectrum();
    session.handleData(Uint8List.fromList([..._deviceInfo, ..._clientSync()]));
    _settle(session);
    session.handleData(_sweep(spyServerFftPixels ~/ 2));
    expect(
      _peakHz(sink.frames.last),
      closeTo(144200000, 2 * _bin),
      reason: 'the window centre is the dial in center mode, and anywhere on a receiver tuned elsewhere',
    );
  });

  test('a stage count from the wire is bounded: none still offers the full width, and nonsense is not looped over', () {
    final none = _Sink();
    final session = _session(none);
    session.handleData(Uint8List.fromList([..._deviceInfoWith(stages: 0), ..._clientSync()]));
    expect(session.spectrumCapabilities.spansHz, [1000000]);

    final huge = _Sink();
    final other = _session(huge);
    other.handleData(Uint8List.fromList([..._deviceInfoWith(stages: 0xFFFFFFFF), ..._clientSync()]));
    expect(other.spectrumCapabilities.spansHz.length, lessThanOrEqualTo(16));
  });
}
