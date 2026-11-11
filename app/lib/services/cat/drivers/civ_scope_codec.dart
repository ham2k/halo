// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The CI-V scope (command 0x27) of the IC-705/7300/7610 line: builders for
// its settings and an assembler for the sweeps it streams. Pure: no timers.
//
// Every layout here was checked against an IC-705 over WiFi — the captured
// frames are pinned in cat_icom_scope_test.dart. A serial radio splits a
// sweep across several divisions; the network sends it whole.

import 'dart:typed_data';

import 'civ_codec.dart';

const civScopeCommand = 0x27;

/// The streamed sweep, never asked for.
const civScopeWaveform = 0x00;

/// Whether the scope runs at all — the radio's own screen shows it too.
const civScopeOnOff = 0x10;

/// Whether sweeps are sent over CI-V. Off unless asked: a sweep is most of
/// what a serial line carries while it is on.
const civScopeOutput = 0x11;
const civScopeMode = 0x14;
const civScopeSpan = 0x15;

/// Which of a band range's four fixed-edge presets the Fixed and Scroll-F
/// modes show.
const civScopeEdgeNumber = 0x16;
const civScopeRef = 0x19;
const civScopeSpeed = 0x1A;
const civScopeEdges = 0x1E;

/// The scope's modes. Scroll-C holds a centre mode's span still and
/// Scroll-F a fixed mode's edges, each scrolling only once the operating
/// frequency leaves the screen. Every mode but center sends its sweeps
/// between edges.
const civScopeModeCenter = 0x00, civScopeModeFixed = 0x01, civScopeModeScrollC = 0x02, civScopeModeScrollF = 0x03;

/// The main receiver's scope. Every settings sub-command takes it first.
const _main = 0x00;

/// The top of an amplitude byte: 0xA0 is the top of the radio's screen on
/// the IC-705 and most of the line; an entry pins its own where it differs.
const civScopeAmplitudeMax = 160;

/// The half-widths center mode offers on the IC-705 and IC-7300, ascending.
const civScopeSpans = [2500, 5000, 10000, 25000, 50000, 100000, 250000, 500000];

/// The REF range most of the line offers; an entry pins its own where it differs.
const civScopeRefMinDb = -20.0;
const civScopeRefMaxDb = 20.0;
const civScopeRefStepDb = 0.5;

/// The band ranges a model keeps fixed-edge presets for, `[lowHz, highHz]`,
/// in the order its CI-V reference guide numbers them from 1. These are the
/// IC-7300's and IC-7300MK2's; the IC-7610, IC-7760 and IC-7850/7851 number
/// the same ranges and stop at 60 MHz. An entry pins its own table where
/// the model's differs.
const civScopeEdgeRanges = [
  [30000, 1600000],
  [1600000, 2000000],
  [2000000, 6000000],
  [6000000, 8000000],
  [8000000, 11000000],
  [11000000, 15000000],
  [15000000, 20000000],
  [20000000, 22000000],
  [22000000, 26000000],
  [26000000, 30000000],
  [30000000, 45000000],
  [45000000, 60000000],
  [60000000, 74800000],
];

/// The IC-705's: the line's, then its VHF and UHF ranges.
const civScopeEdgeRangesIc705 = [
  ...civScopeEdgeRanges,
  [74800000, 108000000],
  [108000000, 137000000],
  [137000000, 200000000],
  [400000000, 470000000],
];

const civScopeEdgeRangesIc9700 = [
  [144000000, 148000000],
  [430000000, 450000000],
  [1240000000, 1300000000],
];

/// Without its sixth, 10 GHz range: its sweeps there are not drawn, so its
/// edges are never placed.
const civScopeEdgeRangesIc905 = [
  [144000000, 148000000],
  [430000000, 450000000],
  [1240000000, 1300000000],
  [2300000000, 2450000000],
  [5650000000, 5925000000],
];

/// The furthest apart a preset's edges may be.
const civScopeMaxEdgeWidthHz = 1000000;

List<int> _frame(int to, int from, List<int> data) => buildCivFrame(to: to, from: from, command: civScopeCommand, data: data);

List<int> buildScopeOnOffFrame({required int to, required int from, bool? on}) => _frame(to, from, [civScopeOnOff, if (on != null) on ? 0x01 : 0x00]);

List<int> buildScopeOutputFrame({required int to, required int from, bool? on}) => _frame(to, from, [civScopeOutput, if (on != null) on ? 0x01 : 0x00]);

/// [mode] null reads the mode.
List<int> buildScopeModeFrame({required int to, required int from, int? mode}) => _frame(to, from, [civScopeMode, _main, ?mode]);

List<int> buildScopeSpanFrame({required int to, required int from, int? spanHz}) =>
    _frame(to, from, [civScopeSpan, _main, if (spanHz != null) ...encodeBcdFrequency(spanHz)]);

/// Two BCD bytes of hundredths, most significant first, then a sign byte
/// (0x01 is minus): `04 50 01` is −4.5 dB.
List<int> buildScopeRefFrame({required int to, required int from, double? refDb}) {
  if (refDb == null) return _frame(to, from, [civScopeRef, _main]);
  final digits = (refDb.abs() * 100).round().clamp(0, 9999).toString().padLeft(4, '0');
  int pair(int i) => (int.parse(digits[i]) << 4) | int.parse(digits[i + 1]);
  return _frame(to, from, [civScopeRef, _main, pair(0), pair(2), refDb < 0 ? 0x01 : 0x00]);
}

/// Reads the selected preset, or with [edge] selects one — HaLo only ever the
/// one already selected, after writing its edges.
List<int> buildScopeEdgeNumberFrame({required int to, required int from, int? edge}) => _frame(to, from, [civScopeEdgeNumber, _main, ?edge]);

/// Sets preset [edge] (1–4) of band range [range] — its number in the
/// model's table ([civScopeEdgeRanges]), counted from 1 — to [lowHz]..[highHz].
/// The radio ignores digits under 1 kHz, refuses edges outside the range or
/// more than 1 MHz apart, and takes no receiver byte here.
List<int> buildScopeEdgesFrame({required int to, required int from, required int range, required int edge, required int lowHz, required int highHz}) =>
    _frame(to, from, [civScopeEdges, (range ~/ 10) << 4 | range % 10, edge, ...encodeBcdFrequency(lowHz), ...encodeBcdFrequency(highHz)]);

/// 0x00 is fast and 0x02 slow — the reverse of the order the names suggest.
List<int> buildScopeSpeedFrame({required int to, required int from, int? speed}) => _frame(to, from, [civScopeSpeed, _main, ?speed]);

int? _bcdByte(int byte) {
  final tens = byte >> 4, ones = byte & 0x0F;
  return tens > 9 || ones > 9 ? null : tens * 10 + ones;
}

/// The value of a settings answer — `frame.data` from its sub-command on.
/// Null for a sub-command these do not read, or a malformed answer.
bool? parseScopeFlag(List<int> data) => data.length == 2 ? data[1] == 0x01 : null;

int? parseScopeMode(List<int> data) => data.length == 3 && data[2] <= civScopeModeScrollF ? data[2] : null;

int? parseScopeEdgeNumber(List<int> data) => data.length == 3 && data[2] >= 1 && data[2] <= 4 ? data[2] : null;

int? parseScopeSpan(List<int> data) => data.length == 7 ? decodeBcdFrequency(data.sublist(2)) : null;

double? parseScopeRef(List<int> data) {
  if (data.length != 5) return null;
  final hi = _bcdByte(data[2]), lo = _bcdByte(data[3]);
  if (hi == null || lo == null) return null;
  final db = (hi * 100 + lo) / 100;
  return data[4] == 0x01 ? -db : db;
}

int? parseScopeSpeed(List<int> data) => data.length == 3 && data[2] <= 0x02 ? data[2] : null;

/// One complete sweep. In center mode [firstHz] is the center and [secondHz]
/// the half-width; in every other mode they are the low and high edges.
class CivScopeSweep {
  /// [civScopeModeCenter] .. [civScopeModeScrollF].
  final int mode;
  final int firstHz;
  final int secondHz;

  /// The radio could not sweep where it was asked to — outside its range.
  final bool outOfRange;
  final Uint8List amplitudes;

  const CivScopeSweep({required this.mode, required this.firstHz, required this.secondHz, required this.outOfRange, required this.amplitudes});

  bool get fixed => mode != civScopeModeCenter;

  int get lowHz => fixed ? firstHz : firstHz - secondHz;
  int get highHz => fixed ? secondHz : firstHz + secondHz;
}

/// Puts the divisions of one sweep back together.
///
/// Division 1 carries the header — `mode, 5 BCD bytes, 5 BCD bytes, out of
/// range` — and, on the network, the whole sweep after it. On a serial line
/// the amplitudes follow in divisions 2..N. A division out of sequence
/// drops the sweep: the next division 1 starts a fresh one, which costs one
/// sweep rather than drawing two halves of different ones side by side.
class CivScopeAssembler {
  CivScopeSweep? _header;
  final _amplitudes = BytesBuilder(copy: false);
  int _expect = 0;

  /// `frame.data` of a `27 00` frame — `00, receiver, division, divisions`
  /// and then the division itself. Returns the sweep it completes.
  CivScopeSweep? add(List<int> data) {
    // The sub-receiver's scope on a dual-scope radio is another stream.
    if (data.length < 4 || data[0] != civScopeWaveform || data[1] != _main) return null;
    final division = _bcdByte(data[2]), divisions = _bcdByte(data[3]);
    if (division == null || divisions == null || division < 1 || division > divisions) return _reset();
    if (division == 1) {
      if (data.length < 16) return _reset();
      final first = decodeBcdFrequency(data.sublist(5, 10)), second = decodeBcdFrequency(data.sublist(10, 15));
      if (first == null || second == null) return _reset();
      _header = CivScopeSweep(mode: data[4], firstHz: first, secondHz: second, outOfRange: data[15] == 0x01, amplitudes: Uint8List(0));
      _amplitudes.clear();
      _amplitudes.add(data.sublist(16));
    } else {
      if (_header == null || division != _expect) return _reset();
      _amplitudes.add(data.sublist(4));
    }
    _expect = division + 1;
    if (division < divisions) return null;
    final header = _header!;
    _header = null;
    // A header with no amplitudes after it is nothing to draw.
    if (_amplitudes.isEmpty) return null;
    return CivScopeSweep(
      mode: header.mode,
      firstHz: header.firstHz,
      secondHz: header.secondHz,
      outOfRange: header.outOfRange,
      amplitudes: _amplitudes.takeBytes(),
    );
  }

  CivScopeSweep? _reset() {
    _header = null;
    _amplitudes.clear();
    return null;
  }
}
