// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/drivers/flex_pan_spectrum.dart';
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

/// An FFT datagram shaped like RadioRoom's (FLEX-6600, 4.3.16): extension
/// data with a stream id (the pan's), class 0x8003, UTC and sample-count
/// timestamps, then start bin, bin count, bin size, total bins and frame
/// index ahead of big-endian u16 rows, and four bytes the radio pads with.
Uint8List fftPacket(int pan, {required int frame, required int start, required int total, required List<int> rows}) {
  final words = 7 + 3 + (rows.length * 2 + 3) ~/ 4 + 1;
  final bytes = ByteData(words * 4);
  bytes.setUint32(0, 0x38500000 | words);
  bytes.setUint32(4, pan);
  bytes.setUint32(8, 0x00001c2d);
  bytes.setUint32(12, 0x534c8003);
  bytes.setUint16(28, start);
  bytes.setUint16(30, rows.length);
  bytes.setUint16(32, 2);
  bytes.setUint16(34, total);
  bytes.setUint32(36, frame);
  for (var i = 0; i < rows.length; i++) {
    bytes.setUint16(40 + i * 2, rows[i]);
  }
  return bytes.buffer.asUint8List();
}

/// One whole 2048-bin sweep of [pan] in a single packet, at the pan's
/// bottom row but for [peaks] (bin → row).
Uint8List sweep(int pan, {required int frame, Map<int, int> peaks = const {}, int bins = 2048}) =>
    fftPacket(pan, frame: frame, start: 0, total: bins, rows: [for (var i = 0; i < bins; i++) peaks[i] ?? 399]);

void main() {
  late List<String> sent;
  late Map<String, void Function(int, String)> replies;
  late _Sink sink;
  late FlexPanSpectrum spectrum;
  late Map<String, Map<String, String>> pans;

  setUp(() {
    sent = [];
    replies = {};
    sink = _Sink();
    pans = {};
    spectrum = FlexPanSpectrum(
      send: (command, {onReply}) {
        sent.add(command);
        if (onReply != null) replies[command] = onReply;
      },
      sink: sink,
      pans: pans,
    );
    spectrum.subscribe();
  });

  /// A status as the connection hands it on: merged into the record first,
  /// which the scope only reads.
  void status(String id, Map<String, String> fields) {
    if (fields.containsKey('removed')) {
      pans.remove(id);
    } else {
      (pans[id] ??= {}).addAll(fields);
    }
    spectrum.panStatus(id, fields);
  }

  /// HaLo's pan as the radio describes it: 200 kHz wide on 14.074, its rows
  /// spanning -150 to -10 dBm.
  void ready() {
    spectrum.start();
    spectrum.socketReady();
    spectrum.slicePan('0x40000003');
    status('0x40000003', {
      'center': '14.074000',
      'bandwidth': '0.200000',
      'min_dbm': '-150.00',
      'max_dbm': '-10.00',
      'y_pixels': '400',
      'x_pixels': '2048',
      'fps': '25',
    });
  }

  test("the pan is shaped for HaLo's displays, and nothing is asked of DAX", () {
    ready();
    expect(sent, [
      'sub pan all',
      'display pan set 0x40000003 xpixels=2048',
      'display pan set 0x40000003 ypixels=400',
      'display pan set 0x40000003 min_dbm=-150',
      'display pan set 0x40000003 max_dbm=-10',
    ]);
    sent.clear();
    status('0x40000003', {'center': '14.075000'});
    expect(sent, isEmpty, reason: 'a status arrives several times a second, and each would shape the pan again');
  });

  test('a sweep the radio splits across packets is drawn once, whole, in dBm across the pan', () {
    ready();
    // Row 0 is the pan's top. Rows read as dB would put the strongest
    // signal at the bottom of the display.
    final first = [for (var i = 0; i < 600; i++) i == 300 ? 0 : 399];
    final second = [for (var i = 0; i < 1448; i++) 399];
    expect(spectrum.packet(fftPacket(0x40000003, frame: 7, start: 0, total: 2048, rows: first)), isTrue);
    expect(sink.frames, isEmpty, reason: 'half a sweep drawn is a sweep with half its band at zero');
    expect(spectrum.packet(fftPacket(0x40000003, frame: 7, start: 600, total: 2048, rows: second)), isTrue);
    final frame = sink.frames.single;
    expect((frame.lowHz, frame.highHz), (14074000 - 100000, 14074000 + 100000));
    expect(frame.levels, hasLength(2048));
    expect(frame.levels[300], closeTo(-10, 0.01));
    expect(frame.levels[1000], closeTo(-150, 0.01));
  });

  test('a sweep missing its first packet is not drawn with the next one', () {
    ready();
    spectrum.packet(fftPacket(0x40000003, frame: 8, start: 600, total: 2048, rows: List.filled(1448, 200)));
    spectrum.packet(fftPacket(0x40000003, frame: 9, start: 600, total: 2048, rows: List.filled(1448, 200)));
    expect(sink.frames, isEmpty, reason: "frame 9's tail and frame 8's would make one sweep of nothing");
  });

  // The radio sends no status to the client that made a change, and a status
  // already on its way says what the pan was. Taken, the first pan a
  // station gets (50 by 20) keeps reading as 20 rows tall while the radio
  // sends 400, and every level lands twenty times too far down.
  test("a status sent before the radio took HaLo's change does not undo it", () {
    ready();
    status('0x40000003', {'y_pixels': '20', 'x_pixels': '50'});
    replies['display pan set 0x40000003 xpixels=2048']!(0, '');
    replies['display pan set 0x40000003 ypixels=400']!(0, '');
    spectrum.packet(sweep(0x40000003, frame: 1, peaks: {0: 0}));
    expect(sink.frames.single.levels[1], closeTo(-150, 0.01));
    status('0x40000003', {'y_pixels': '20'});
    spectrum.packet(sweep(0x40000003, frame: 2, peaks: {0: 0}));
    expect(sink.frames, hasLength(1), reason: 'once answered, a status is news: a sweep below the last row it names is dropped, not drawn');
  });

  // Read by HaLo's window the moment it is asked for, the sweeps the radio
  // made on its own window meanwhile land up to 30 dB off, and drag the
  // noise floor with them.
  test('a sweep made before the radio takes a change is read by what the radio had', () {
    ready();
    for (final reply in replies.values.toList()) {
      reply(0, '');
    }
    status('0x40000003', {'min_dbm': '-135.00', 'max_dbm': '-40.00'});
    expect(sent.last, 'display pan set 0x40000003 max_dbm=-10');
    spectrum.packet(sweep(0x40000003, frame: 1, peaks: {0: 0}));
    expect(sink.frames.single.levels[0], closeTo(-40, 0.01));
    replies['display pan set 0x40000003 min_dbm=-150']!(0, '');
    replies['display pan set 0x40000003 max_dbm=-10']!(0, '');
    spectrum.packet(sweep(0x40000003, frame: 2, peaks: {0: 0}));
    expect(sink.frames.last.levels[0], closeTo(-10, 0.01));
  });

  // CatSpectrum asks a span once per change of what the displays need: lost
  // here, the pan keeps the radio's width for good.
  test('a span asked before the slice names its pan reaches the pan once it is shaped', () {
    spectrum.start();
    spectrum.socketReady();
    expect(spectrum.set(const SpectrumRequest(spanHz: 48000, speed: SpectrumSpeed.slow)), isTrue);
    ready();
    expect(sent, containsAll(['display pan set 0x40000003 bandwidth=0.096000', 'display pan set 0x40000003 fps=8']));
  });

  test("the slice moving to another pan takes the displays' span with it", () {
    ready();
    spectrum.set(const SpectrumRequest(spanHz: 48000));
    sent.clear();
    spectrum.slicePan('0x40000004');
    status('0x40000004', {'center': '7.074000', 'bandwidth': '0.200000'});
    expect(sent, contains('display pan set 0x40000004 bandwidth=0.096000'));
  });

  test('a pan the radio removes says so, and a late answer does not bring it back', () {
    ready();
    status('0x40000003', {'removed': '1'});
    expect(sink.problems.last, t.settings.station.spectrumNoPanadapter);
    replies['display pan set 0x40000003 xpixels=2048']!(0, '');
    sent.clear();
    spectrum.slicePan('0x40000004');
    spectrum.slicePan('0x40000003');
    expect(sent, isEmpty, reason: 'a pan id the radio reuses is shaped from its own description, not from a leftover');
  });

  // The radio's own sweeps before it takes HaLo's shape are 50 bins of 20
  // rows: drawn on HaLo's scale they read as -10 dBm across the band, and
  // seed the noise floor there.
  test('a sweep as wide as the pan was before its shaping is not drawn', () {
    ready();
    spectrum.packet(sweep(0x40000003, frame: 1, bins: 50, peaks: {for (var i = 0; i < 50; i++) i: 19}));
    expect(sink.frames, isEmpty);
  });

  // HaLo's own copy, put back, is a guess about a value the radio may never
  // have had: two refused centres in a row would place every sweep at the
  // first refused one, with nothing on the radio's side to correct it.
  test('two refused changes in a row leave the pan where the radio said it is', () {
    ready();
    spectrum.set(const SpectrumRequest(centerHz: 14100000));
    spectrum.set(const SpectrumRequest(centerHz: 14200000));
    replies['display pan set 0x40000003 center=14.100000']!(0x50000016, '');
    replies['display pan set 0x40000003 center=14.200000']!(0x50000016, '');
    spectrum.packet(sweep(0x40000003, frame: 1));
    expect(sink.frames.single.lowHz, 14074000 - 100000);
  });

  // Another client moving the pan while HaLo's own move waits: put back to
  // what HaLo had before, every sweep is placed where the pan no longer is.
  test('a change refused after the radio said something else takes what the radio said', () {
    ready();
    spectrum.set(const SpectrumRequest(centerHz: 14100000));
    status('0x40000003', {'center': '14.050000'});
    replies['display pan set 0x40000003 center=14.100000']!(0x50000016, '');
    spectrum.packet(sweep(0x40000003, frame: 1));
    expect(sink.frames.single.lowHz, 14050000 - 100000);
  });

  // Counted twice, a repeated packet completes a sweep whose lost half is
  // still row 0: a wall at the top of the scale.
  test('a packet that comes twice does not stand in for one that never came', () {
    ready();
    final half = [for (var i = 0; i < 1024; i++) 399];
    spectrum.packet(fftPacket(0x40000003, frame: 3, start: 0, total: 2048, rows: half));
    spectrum.packet(fftPacket(0x40000003, frame: 3, start: 0, total: 2048, rows: half));
    expect(sink.frames, isEmpty);
    spectrum.packet(fftPacket(0x40000003, frame: 3, start: 1024, total: 2048, rows: half));
    expect(sink.frames, hasLength(1));
  });

  // Left at the radio's own window, everything over -40 dBm is cut off flat.
  test('the radio putting its own window back is asked for the wide one again', () {
    ready();
    for (final reply in replies.values) {
      reply(0, '');
    }
    sent.clear();
    status('0x40000003', {'min_dbm': '-135.00', 'max_dbm': '-40.00', 'rfgain': '8', 'pre': '+8dB'});
    expect(sent, ['display pan set 0x40000003 min_dbm=-150', 'display pan set 0x40000003 max_dbm=-10']);
    sent.clear();
    status('0x40000003', {'min_dbm': '-150.00', 'max_dbm': '-10.00'});
    expect(sent, isEmpty);
  });

  test("another pan's FFT is left for its own slice", () {
    ready();
    // Claimed here, a second slice on HaLo's station never draws.
    expect(spectrum.packet(sweep(0x40000004, frame: 1)), isFalse);
  });

  test('a span asked for widens the pan, and a refusal puts the old width back', () {
    ready();
    sent.clear();
    expect(spectrum.set(const SpectrumRequest(spanHz: 380000)), isTrue);
    expect(sent, ['display pan set 0x40000003 bandwidth=0.768000']);
    expect(sink.settings.last.spanHz, 384000);
    replies['display pan set 0x40000003 bandwidth=0.768000']!(0x50000016, '');
    expect(sink.settings.last.spanHz, 100000, reason: 'sweeps would be placed across a width the pan does not have');
  });

  test('the speed is the pan\'s frame rate', () {
    ready();
    expect(sink.settings.last.speed, SpectrumSpeed.fast);
    sent.clear();
    spectrum.set(const SpectrumRequest(speed: SpectrumSpeed.slow));
    expect(sent, ['display pan set 0x40000003 fps=8']);
    expect(sink.settings.last.speed, SpectrumSpeed.slow);
  });

  test('an FFT that never arrives says so, and a sweep that does clears it', () {
    fakeAsync((async) {
      ready();
      async.elapse(const Duration(seconds: 6));
      expect(sink.problems.last, t.settings.station.spectrumNoUdp);
      spectrum.packet(sweep(0x40000003, frame: 1, peaks: {3: 10}));
      expect(sink.problems.last, isNull);
    });
  });

  // Cleared by a sweep that can't be placed, the problem goes and never
  // comes back, over a scope that stays blank.
  test('sweeps that cannot be drawn do not clear the problem', () {
    fakeAsync((async) {
      ready();
      spectrum.packet(sweep(0x40000003, frame: 1, bins: 50));
      async.elapse(const Duration(seconds: 6));
      expect(sink.problems.last, t.settings.station.spectrumNoUdp);
    });
  });

  test('a slice with no pan says so', () {
    spectrum.start();
    spectrum.socketReady();
    spectrum.slicePan(null);
    expect(sink.problems.last, t.settings.station.spectrumNoPanadapter);
  });

  // The operator reads this as a crop's reason over the band scope: a code there is the radio's,
  // not theirs.
  test('a pan the radio turns down is said in words, its code left to the log', () {
    final sink = _Sink();
    final own = FlexPanSpectrum(
      send: (command, {onReply}) {
        if (onReply != null) replies[command] = onReply;
      },
      sink: sink,
      pans: pans,
      ownPanAt: () => 14074,
    )..subscribe();
    own
      ..start()
      ..socketReady();
    replies['display pan create x=2048 y=400']!(0x50000016, '');
    expect(sink.problems.last, t.settings.station.spectrumNoSweepToSpare, reason: 'the slice has its pan: this one is for a narrower display');
    expect(own.turnedDown, isTrue);
    own.close();
  });

  // The socket coming back shapes the pan again; at the first centre a display asked, it would
  // jump away from where the display has since moved it.
  test("a pan of the scope's own is shaped again where a display last put it", () {
    final own = FlexPanSpectrum(
      send: (command, {onReply}) {
        sent.add(command);
        if (onReply != null) replies[command] = onReply;
      },
      sink: _Sink(),
      pans: pans,
      ownPanAt: () => 14074,
    )..subscribe();
    own
      ..start()
      ..socketReady();
    replies['display pan create x=2048 y=400']!(0, '0x40000005,0x42000005');
    expect(sent, contains('display pan set 0x40000005 center=14.074000'));
    own.setSpectrum(const SpectrumRequest(centerHz: 14080000));
    own.setSpectrum(const SpectrumRequest(centerHz: 14090000));
    sent.clear();
    own
      ..socketLost()
      ..socketReady();
    expect(sent, contains('display pan set 0x40000005 center=14.090000'));
    own.close();
  });
}
