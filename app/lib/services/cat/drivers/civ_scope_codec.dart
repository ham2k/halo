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
const civScopeRef = 0x19;
const civScopeSpeed = 0x1A;

/// The main receiver's scope. Every settings sub-command takes it first.
const _main = 0x00;

/// The top of an amplitude byte: 0xA0 is the top of the radio's screen.
const civScopeAmplitudeMax = 160;

/// The half-widths center mode offers on the IC-705 and IC-7300, ascending.
const civScopeSpans = [2500, 5000, 10000, 25000, 50000, 100000, 250000, 500000];

const civScopeRefMinDb = -20.0;
const civScopeRefMaxDb = 20.0;
const civScopeRefStepDb = 0.5;

List<int> _frame(int to, int from, List<int> data) => buildCivFrame(to: to, from: from, command: civScopeCommand, data: data);

List<int> buildScopeOnOffFrame({required int to, required int from, bool? on}) => _frame(to, from, [civScopeOnOff, if (on != null) on ? 0x01 : 0x00]);

List<int> buildScopeOutputFrame({required int to, required int from, bool? on}) => _frame(to, from, [civScopeOutput, if (on != null) on ? 0x01 : 0x00]);

/// [fixed] null reads the mode. Fixed is 0x01; the scroll modes (0x02/0x03)
/// are not offered, and read back as the mode they scroll from.
List<int> buildScopeModeFrame({required int to, required int from, bool? fixed}) =>
    _frame(to, from, [civScopeMode, _main, if (fixed != null) fixed ? 0x01 : 0x00]);

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

/// 0x00 is fast and 0x02 slow — the reverse of the order the names suggest.
List<int> buildScopeSpeedFrame({required int to, required int from, int? speed}) => _frame(to, from, [civScopeSpeed, _main, ?speed]);

int? _bcdByte(int byte) {
  final tens = byte >> 4, ones = byte & 0x0F;
  return tens > 9 || ones > 9 ? null : tens * 10 + ones;
}

/// The value of a settings answer — `frame.data` from its sub-command on.
/// Null for a sub-command these do not read, or a malformed answer.
bool? parseScopeFlag(List<int> data) => data.length == 2 ? data[1] == 0x01 : null;

bool? parseScopeFixed(List<int> data) => data.length == 3 ? data[2] == 0x01 || data[2] == 0x03 : null;

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
/// the half-width; in fixed mode they are the low and high edges.
class CivScopeSweep {
  final bool fixed;
  final int firstHz;
  final int secondHz;

  /// The radio could not sweep where it was asked to — outside its range.
  final bool outOfRange;
  final Uint8List amplitudes;

  const CivScopeSweep({required this.fixed, required this.firstHz, required this.secondHz, required this.outOfRange, required this.amplitudes});

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
      _header = CivScopeSweep(
        fixed: data[4] == 0x01 || data[4] == 0x03,
        firstHz: first,
        secondHz: second,
        outOfRange: data[15] == 0x01,
        amplitudes: Uint8List(0),
      );
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
      fixed: header.fixed,
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
