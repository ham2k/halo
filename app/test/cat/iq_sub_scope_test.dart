// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A narrower display's own sweep, transformed from IQ a session already
// receives (IqSubScope): what a crop of the widest sweep cannot give it.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/iq_sub_scope.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/spectrum_fft.dart';

class _Sink implements SpectrumSink {
  final frames = <SpectrumFrame>[];
  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings settings) {}
  @override
  void reportSpectrumProblem(String? message) {}
}

const _rate = 192000, _iqCenter = 14200000, _visible = 84000;

/// [count] samples of carriers at [offsetsHz] from the IQ's centre, from sample [start].
Float32List _carriers(int start, int count, List<double> offsetsHz) {
  final out = Float32List(count * 2);
  for (var n = 0; n < count; n++) {
    for (final hz in offsetsHz) {
      final phase = 2 * math.pi * hz * (start + n) / _rate;
      out[2 * n] += 1000 * math.cos(phase);
      out[2 * n + 1] += 1000 * math.sin(phase);
    }
  }
  return out;
}

/// Whether [frame] draws carriers at [aHz] and [bHz] as two, with a dip of 6 dB between them.
bool _apart(SpectrumFrame frame, double aHz, double bHz) {
  final levels = frame.levels;
  int at(double hz) => ((hz - frame.lowHz) / (frame.highHz - frame.lowHz) * (levels.length - 1)).round();
  final (a, b) = (at(aHz), at(bHz));
  if (b - a < 2) return false;
  final between = [for (var i = a + 1; i < b; i++) levels[i]].reduce(math.min);
  return between < math.min(levels[a], levels[b]) - 6;
}

void main() {
  // The widest sweep's points are 82 Hz apart at 192 kHz: two signals 150 Hz apart are one bump.
  test('two carriers 150 Hz apart, one in the widest sweep, are drawn apart in a 24 kHz one', () {
    final sink = _Sink();
    final scope = IqSubScope(sink: sink, receiverHz: () => _iqCenter + 5000, closed: (_) {}, moveIq: (_) => true)
      ..setSpectrum(const SpectrumRequest(spanHz: 12000));
    final widest = IqSpectrum(size: 8192, hop: 8192);
    final wideSweeps = <Float32List>[];
    for (var start = 0; start < 3 * 16384; start += 4096) {
      final iq = _carriers(start, 4096, [5000, 5150]);
      scope.feed(iq, rate: _rate, iqCenterHz: _iqCenter, visibleHalfWidth: _visible);
      widest.add(iq, wideSweeps.add);
    }
    final frame = sink.frames.last;
    expect(frame.highHz - frame.lowHz, closeTo(24000, 50));
    expect(_apart(frame, _iqCenter + 5000, _iqCenter + 5150), isTrue);
    final wide = SpectrumFrame(
      lowHz: _iqCenter - _visible,
      highHz: _iqCenter + _visible,
      levels: poolPeaks(Float32List.sublistView(wideSweeps.last, 512, 8192 - 512), 2048),
      floorDb: 0,
      ceilingDb: 0,
      atMillis: 0,
    );
    expect(_apart(wide, _iqCenter + 5000, _iqCenter + 5150), isFalse, reason: 'cropped from the widest, the panel would show one signal');
  });

  // Twice the points pooled back down are twice the work, and twice the IQ in each sweep, which
  // smears keying across the waterfall's rows.
  test('the transform gives the span about as many points as a sweep draws, and no more', () {
    expect(IqSubScope.sizeFor(192000, 21000), 8192, reason: '1792 points across ±21 kHz, drawn unpooled');
    expect(IqSubScope.sizeFor(384000, 5000), 16384, reason: 'no larger, however narrow the span');
  });

  test("sits on the receiver, stops at the IQ's clear edge, and goes where a display puts it", () {
    final sink = _Sink();
    var receiver = _iqCenter + 3000;
    final scope = IqSubScope(sink: sink, receiverHz: () => receiver, closed: (_) {}, moveIq: (_) => true)..setSpectrum(const SpectrumRequest(spanHz: 12000));
    void sweep() {
      for (var start = 0; start < 2 * 16384; start += 4096) {
        scope.feed(_carriers(start, 4096, [0]), rate: _rate, iqCenterHz: _iqCenter, visibleHalfWidth: _visible);
      }
    }

    double middle() => (sink.frames.last.lowHz + sink.frames.last.highHz) / 2;
    sweep();
    expect(middle(), closeTo(_iqCenter + 3000, 50));
    receiver = _iqCenter + 90000;
    sweep();
    expect(middle(), closeTo(_iqCenter + _visible - 12000, 50), reason: 'drawn past the clear edge, the filter roll-off reads as a quiet band');
    scope.setSpectrum(const SpectrumRequest(centerHz: _iqCenter - 20000));
    sweep();
    expect(middle(), closeTo(_iqCenter - 20000, 50));
  });

  // A crop reaches nothing past what the IQ holds: a display moved there would draw the IQ's edge,
  // with the dial in a blank window, where moving its own scope moved the IQ for it.
  test("a display moved past the IQ moves the session's IQ; one within it moves only the sweep", () {
    final moves = <int>[];
    final scope = IqSubScope(
      sink: _Sink(),
      receiverHz: () => null,
      closed: (_) {},
      moveIq: (hz) {
        moves.add(hz);
        return true;
      },
    )..setSpectrum(const SpectrumRequest(spanHz: 12000));
    scope.feed(_carriers(0, 4096, [0]), rate: _rate, iqCenterHz: _iqCenter, visibleHalfWidth: _visible);
    scope.setSpectrum(const SpectrumRequest(centerHz: _iqCenter + 40000));
    expect(moves, isEmpty);
    expect(scope.setSpectrum(const SpectrumRequest(centerHz: _iqCenter + 200000)), isTrue);
    expect(moves, [_iqCenter + 200000]);
  });

  // Held after a band change, a middle a display put on the old band draws an edge of the new one.
  test("a display's middle is let go once the IQ has moved away from it, for the receiver's", () {
    final sink = _Sink();
    final scope = IqSubScope(sink: sink, receiverHz: () => 7074000, closed: (_) {}, moveIq: (_) => true)..setSpectrum(const SpectrumRequest(spanHz: 12000));
    scope.feed(_carriers(0, 4096, [0]), rate: _rate, iqCenterHz: _iqCenter, visibleHalfWidth: _visible);
    scope.setSpectrum(const SpectrumRequest(centerHz: _iqCenter + 20000));
    for (var start = 0; start < 2 * 16384; start += 4096) {
      scope.feed(_carriers(start, 4096, [0]), rate: _rate, iqCenterHz: 7070000, visibleHalfWidth: _visible);
    }
    expect((sink.frames.last.lowHz + sink.frames.last.highHz) / 2, closeTo(7074000, 50));
  });

  test('a closed sweep is fed nothing and told the session once', () {
    final sink = _Sink();
    var closings = 0;
    final scope = IqSubScope(sink: sink, receiverHz: () => null, closed: (_) => closings++, moveIq: (_) => true);
    scope
      ..close()
      ..close();
    scope.feed(_carriers(0, 32768, [0]), rate: _rate, iqCenterHz: _iqCenter, visibleHalfWidth: _visible);
    expect((closings, sink.frames.length), (1, 0));
    expect(scope.setSpectrum(const SpectrumRequest(spanHz: 12000)), isFalse);
  });
}
