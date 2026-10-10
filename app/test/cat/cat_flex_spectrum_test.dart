// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/drivers/flex_spectrum.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';

class _Sink implements SpectrumSink {
  final frames = <SpectrumFrame>[];
  final settings = <SpectrumSettings>[];
  final problems = <String?>[];
  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings s) => settings.add(s);
  @override
  void reportSpectrumProblem(String? message) => problems.add(message);
}

/// A DAX IQ datagram shaped like the FLEX-6600's: IF data with a stream id,
/// class 0x02E4, UTC and sample-count timestamps, a trailer, and
/// little-endian float32 I/Q pairs.
Uint8List _packet(int stream, List<double> iq) {
  final words = 7 + iq.length + 1;
  final bytes = ByteData(words * 4);
  bytes.setUint32(0, 0x1c510000 | words);
  bytes.setUint32(4, stream);
  bytes.setUint32(8, 0x00001c2d);
  bytes.setUint16(12, 0x534c);
  bytes.setUint16(14, 0x02e4);
  for (var i = 0; i < iq.length; i++) {
    bytes.setFloat32(28 + i * 4, iq[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// [count] samples of a carrier [offsetHz] from the center, at 48 kHz.
List<double> _tone(int start, int count, double offsetHz) => [
  for (var n = start; n < start + count; n++) ...[1000 * math.cos(2 * math.pi * offsetHz * n / 48000), 1000 * math.sin(2 * math.pi * offsetHz * n / 48000)],
];

void main() {
  late List<String> sent;
  late List<void Function(int, String)> replies;
  late _Sink sink;
  late FlexDaxSpectrum spectrum;

  setUp(() {
    sent = [];
    replies = [];
    sink = _Sink();
    spectrum = FlexDaxSpectrum(
      send: (command, {onReply}) {
        sent.add(command);
        if (onReply != null) replies.add(onReply);
      },
      sink: sink,
    );
    // The session's handshake: the radio refuses a `sub` before it.
    spectrum.subscribe();
  });

  /// The slice's pan, as the radio describes it, with [others] holding the
  /// channels other pans already have.
  void ready({String channel = '0', Map<String, String> others = const {}}) {
    spectrum.start();
    spectrum.socketReady();
    spectrum.slicePan('0x40000000');
    for (final MapEntry(:key, :value) in others.entries) {
      spectrum.panStatus(key, {'daxiq_channel': value});
    }
    spectrum.panStatus('0x40000000', {'center': '14.200000', 'bandwidth': '0.064120', 'daxiq_channel': channel});
  }

  test('a pan without a channel gets the first free one, and gets it back as it was', () {
    ready(others: {'0x40000001': '1'});
    expect(sent, containsAllInOrder(['sub pan all', 'display pan set 0x40000000 daxiq_channel=2', 'stream create type=dax_iq daxiq_channel=2']));
    replies.last(0, '20000000');
    sent.clear();
    spectrum.stop();
    expect(sent, ['stream remove 0x20000000', 'display pan set 0x40000000 daxiq_channel=0', 'unsub pan all']);
  });

  test("a pan that already has a channel is someone else's, and keeps it", () {
    ready(channel: '3');
    expect(sent, isNot(anyElement(startsWith('display pan set'))));
    expect(sent.last, 'stream create type=dax_iq daxiq_channel=3');
    replies.single(0, '20000000');
    sent.clear();
    spectrum.stop();
    expect(sent, ['stream remove 0x20000000', 'unsub pan all']);
  });

  test('every channel taken says so, and opens nothing', () {
    ready(others: {'0x40000001': '1', '0x40000002': '2', '0x40000003': '3', '0x40000004': '4'});
    expect(sent, ['sub pan all']);
    expect(sink.problems.last, t.settings.station.spectrumNoDaxChannel);
  });

  test('nothing is created before the UDP socket the IQ will arrive on', () {
    spectrum.start();
    spectrum.slicePan('0x40000000');
    spectrum.panStatus('0x40000000', {'center': '14.200000', 'daxiq_channel': '1'});
    expect(sent, ['sub pan all']);
    spectrum.socketReady();
    expect(sent.last, 'stream create type=dax_iq daxiq_channel=1');
  });

  test('a stream the radio grants after the display has gone is handed straight back', () {
    ready(channel: '1');
    spectrum.stop();
    sent.clear();
    replies.single(0, '20000000');
    expect(sent, ['stream remove 0x20000000']);
  });

  test('a carrier above the center lands above it, inside the trimmed edges', () {
    ready(channel: '1');
    replies.single(0, '20000000');
    spectrum.streamStatus('0x20000000', {'daxiq_rate': '48000', 'payload_endian': 'little'});
    for (var p = 0; p < 10; p++) {
      expect(spectrum.packet(_packet(0x20000000, _tone(p * 512, 512, 6000))), isTrue);
    }
    final frame = sink.frames.last;
    // The outer sixteenth of each side is the radio's filter, not the band.
    expect((frame.lowHz, frame.highHz), (14200000 - 21000, 14200000 + 21000));
    final levels = frame.levels;
    var peak = 0;
    for (var i = 1; i < levels.length; i++) {
      if (levels[i] > levels[peak]) peak = i;
    }
    final peakHz = frame.lowHz + peak / (levels.length - 1) * (frame.highHz - frame.lowHz);
    // Mirrored, a click on the carrier would tune 12 kHz away from it.
    expect(peakHz, closeTo(14206000, 100));
  });

  test("another stream's packets are taken off the meter path but drawn nowhere", () {
    ready(channel: '1');
    replies.single(0, '20000000');
    expect(spectrum.packet(_packet(0x20000001, _tone(0, 512, 0))), isTrue);
    expect(sink.frames, isEmpty);
  });

  test('a stream granted after a stop and a restart is handed back, and a fresh one asked for', () {
    ready(channel: '0');
    final stale = replies.last;
    spectrum.stop();
    spectrum.start();
    expect(sent.last, 'stream create type=dax_iq daxiq_channel=1', reason: 'the restart asks again at once');
    sent.clear();
    stale(0, '20000000');
    // Adopted, it would be a stream on a channel the stop already gave back.
    expect(sent, ['stream remove 0x20000000']);
    replies.last(0, '20000001');
    expect(spectrum.packet(_packet(0x20000001, _tone(0, 512, 0))), isTrue);
  });

  test("the stream's status, pushed ahead of the reply, still sets its rate", () {
    ready(channel: '2');
    // Captured order on a FLEX-6600: the status line, then the R reply.
    spectrum.streamStatus('0x20000000', {'type': 'dax_iq', 'daxiq_rate': '96000', 'payload_endian': 'little'});
    replies.single(0, '20000000');
    for (var p = 0; p < 20; p++) {
      spectrum.packet(_packet(0x20000000, _tone(p * 512, 512, 0)));
    }
    // At the 48 kHz default the sweep would be drawn half as wide as it is.
    expect(sink.frames.last.highHz - sink.frames.last.lowHz, 84000);
  });

  test('a refused stream gives the channel back, says why, and is not asked for again on every pan push', () {
    ready(channel: '0');
    sent.clear();
    replies.last(0x50000016, '');
    expect(sent, ['display pan set 0x40000000 daxiq_channel=0']);
    expect(sink.problems.last, contains('50000016'));
    spectrum.panStatus('0x40000000', {'center': '14.201000'});
    expect(sent, hasLength(1));
  });

  test('a NaN sample is drawn as silence, not carried in the noise average', () {
    ready(channel: '1');
    replies.single(0, '20000000');
    spectrum.streamStatus('0x20000000', {'daxiq_rate': '48000'});
    for (var p = 0; p < 10; p++) {
      spectrum.packet(_packet(0x20000000, p == 2 ? List.filled(1024, double.nan) : _tone(p * 512, 512, 6000)));
    }
    expect(sink.frames.last.floorDb.isFinite, isTrue);
  });

  test('a recentre places the sweeps at once, and back where they were if the radio refuses it', () {
    // The radio may never echo the move to the client that made it, so the centre is taken as
    // asked — but kept after a refusal, every sweep would be labelled where the IQ is not.
    ready(channel: '1');
    replies.single(0, '20000000');
    spectrum.streamStatus('0x20000000', {'daxiq_rate': '48000', 'payload_endian': 'little'});
    void sweep() {
      for (var p = 0; p < 10; p++) {
        spectrum.packet(_packet(0x20000000, _tone(p * 512, 512, 6000)));
      }
    }

    spectrum.set(const SpectrumRequest(centerHz: 14250000));
    expect(sent.last, 'display pan set 0x40000000 center=14.250000');
    sweep();
    expect(sink.frames.last.lowHz, 14250000 - 21000);
    replies.last(0x50000016, '');
    sink.frames.clear();
    sweep();
    expect(sink.frames.last.lowHz, 14200000 - 21000);

    spectrum.set(const SpectrumRequest(centerHz: 14300000));
    replies.last(0, '');
    sink.frames.clear();
    sweep();
    expect(sink.frames.last.lowHz, 14300000 - 21000);
  });

  test('a span asks for the stream rate that shows it', () {
    ready(channel: '1');
    replies.single(0, '20000000');
    spectrum.set(const SpectrumRequest(spanHz: 42000));
    expect(sent.last, 'stream set 0x20000000 daxiq_rate=96000');
  });

  test('a display opened before the handshake subscribes to pans once the session does', () {
    final early = FlexDaxSpectrum(send: (c, {onReply}) => sent.add(c), sink: sink);
    early.start();
    expect(sent, isEmpty, reason: 'the radio refuses a sub before its handshake');
    early.subscribe();
    expect(sent, ['sub pan all']);
  });

  test('a socket that failed before any display opened is said when one does', () {
    spectrum.socketUnavailable();
    spectrum.start();
    expect(sink.problems.last, t.settings.station.spectrumNoUdp);
  });

  test('a display that reopens hears the settings again', () {
    ready(channel: '1');
    replies.single(0, '20000000');
    final before = sink.settings.length;
    spectrum.stop();
    spectrum.start();
    // The host forgets a stopped scope's settings; a restart that said
    // nothing would leave the extension's span and Ref controls empty.
    expect(sink.settings.length, greaterThan(before));
    expect(sink.settings.last.spanHz, 21000);
  });

  test('a refused channel assignment gives up the stream beside it, and says why', () {
    ready(channel: '0');
    final (assign, create) = (replies[0], replies[1]);
    sent.clear();
    assign(0x50000023, '');
    expect(sink.problems.last, contains('50000023'));
    // Not ours to give back: the radio never gave it.
    expect(sent, isNot(contains('display pan set 0x40000000 daxiq_channel=0')));
    create(0, '20000000');
    expect(sent, contains('stream remove 0x20000000'), reason: 'a stream on a channel no pan feeds');
  });

  test('a granted stream whose IQ never arrives says so, and late IQ clears it', () {
    fakeAsync((async) {
      ready(channel: '1');
      replies.single(0, '20000000');
      async.elapse(const Duration(seconds: 6));
      expect(sink.problems.last, t.settings.station.spectrumNoUdp);
      spectrum.packet(_packet(0x20000000, _tone(0, 512, 0)));
      expect(sink.problems.last, isNull);
    });
  });

  test('a stream id with a leading zero still matches its packets', () {
    ready(channel: '1');
    replies.single(0, '0a000000');
    spectrum.streamStatus('0x0a000000', {'daxiq_rate': '48000'});
    for (var p = 0; p < 10; p++) {
      spectrum.packet(_packet(0x0a000000, _tone(p * 512, 512, 0)));
    }
    expect(sink.frames, isNotEmpty);
  });

  test('a slice not yet heard from is not called a slice without a panadapter', () {
    final quiet = FlexDaxSpectrum(send: (c, {onReply}) => sent.add(c), sink: sink)..subscribe();
    quiet.start();
    quiet.socketReady();
    expect(sink.problems, isNot(contains(t.settings.station.spectrumNoPanadapter)));
    quiet.slicePan(null);
    expect(sink.problems.last, t.settings.station.spectrumNoPanadapter);
  });
}
