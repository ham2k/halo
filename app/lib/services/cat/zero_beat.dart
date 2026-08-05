// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Avoid Zero-Beating on Spots: where tuning to a CW spot should actually land
// (docs/design/cat.md § Avoiding zero beat).
//
// Pure and randomless — [zeroBeatOffsetHz] is handed its draw rather than
// taking one, the same way vfo_snap.dart is told the time. That lets a test
// pin an exact resulting frequency instead of asserting a range, which is the
// only way to catch an off-by-one in the dead zone.

import 'dart:math';

import 'package:halo_core/halo_core.dart';

import 'vfo_snap.dart' show staysInBand;

/// Below this, an offset cannot survive the frequency field's own round-trip.
///
/// The offsetted value is written into the field with [fmtFreqInput] and read
/// back with [parseFreq], and `parseFreq` reads a sub-1000 value carrying a
/// decimal point as MHz — so a 630 m spot at a whole `474` kHz, which works
/// today, would come back as `474.021` → `474021` kHz and be both logged and
/// sent to the rig. An offset always introduces that decimal point, so 630 m
/// and 2190 m are left exactly on the spot rather than mangled.
const _lowestOffsettableKHz = 1000.0;

/// The inner edge of the draw, as a fraction of the range: an offset lands
/// between 40% and 100% of [rangeHz], either side.
///
/// Zero is excluded on purpose. A uniform draw across the whole range puts
/// some operators within a few Hz of the spot — which is zero beat, so for
/// them the feature did nothing. The dead zone costs an even spread and buys
/// the guarantee that every caller is audibly off the pile.
const _deadZoneFraction = 0.4;

/// The dead zone never shrinks below this, whatever the range. At the 10 Hz
/// setting the fraction alone would allow a 4 Hz offset, which against a
/// ~600 Hz sidetone is not audibly off the pile — the one thing the dead zone
/// is there to guarantee, and what the setting's own description promises.
const _minimumOffsetHz = 8.0;

/// The offset in Hz to add to a spotted CW frequency, given a [draw] in
/// `[0, 1)` — `Random().nextDouble()`, in production.
///
/// [draw] is stretched across BOTH sides — `[0, 0.5)` lands above the spot,
/// `[0.5, 1)` below — and the position within each half sets the distance, so
/// the two sides get the same spread of distances. Deriving the side from the
/// draw's low bit instead would tie side to distance: every offset above the
/// spot would be a near one and every offset below a far one.
///
/// Within a side the magnitude is uniform before rounding, which leaves the
/// two end values landing about half as often as the ones between them —
/// they take half-width buckets. Irrelevant on the air, stated so the tests
/// below aren't read as claiming a flat integer distribution.
int zeroBeatOffsetHz(double rangeHz, double draw) {
  final t = (draw.clamp(0.0, 1.0)) * 2;
  // Clamped to the range itself, so a range narrower than the floor collapses
  // to a fixed offset at its edge rather than inverting into an empty span.
  final nearest = min(max(rangeHz * _deadZoneFraction, _minimumOffsetHz), rangeHz);
  final magnitude = nearest + (t - t.floor()) * (rangeHz - nearest);
  return (t < 1 ? magnitude : -magnitude).round();
}

/// [freqKHz] moved off an exact zero beat by [offsetHz].
///
/// Computed in whole Hz, like `snapToGrid`, so the result is always a whole
/// number of Hz. Adding `offsetHz / 1000` to the kHz value instead would carry
/// any sub-Hz precision in [freqKHz] straight through to the radio — asking a
/// rig for a fraction of a Hz it cannot tune to, off a spot that was never
/// that precise to begin with.
double applyZeroBeatOffset(double freqKHz, int offsetHz) => ((freqKHz * 1000).round() + offsetHz) / 1000;

/// Whether a suggestion tuning to [freqKHz] in [mode] should be nudged.
///
/// CW only — the whole point is that CW signals a few Hz apart are separable
/// by ear, which is not true of phone, nor of data modes whose decoders expect
/// the tone where the spot says it is. Matched through [superModeForMode], the
/// same way Smart VFO Snap tests for Phone; note that only literal `CW` maps
/// to `'CW'` there, so a `CWR` spot is classed Digital and is left alone.
///
/// [radioConnected] gates the whole thing, because the offset is only ever
/// worth anything when something acts on it. With no rig under CAT the app
/// changes no frequency at all: the operator reads the number off the screen
/// and dials it in, so an offset would hand them digits to hand-tune for no
/// benefit and leave the log claiming a frequency they never transmitted on.
bool shouldAvoidZeroBeat({
  required bool enabled,
  required bool radioConnected,
  required String? mode,
  required double? freqKHz,
}) =>
    enabled &&
    radioConnected &&
    freqKHz != null &&
    freqKHz >= _lowestOffsettableKHz &&
    mode != null &&
    superModeForMode(mode) == 'CW';

/// [qso] — a suggestion map — with its CW frequency moved off the spot, or
/// [qso] itself when nothing should move. [draw] is `Random().nextDouble()`.
///
/// Returns a copy when it offsets, never mutating the caller's map: the one
/// it is handed belongs to the spot list.
///
/// An offset that would leave the band is flipped to the other side. Nudging
/// a spot out of its band would retune the rig somewhere illegal, log it
/// there, and clear the VFO band that the Spots panel's `auto` filter reads.
///
/// Dropping the offset entirely when BOTH sides fail is a backstop, not a
/// case that occurs: the narrowest band this can reach is 30 m at 50 kHz —
/// the LF cutoff puts 2190 m and 630 m out of reach — against a widest
/// offered range of 75 Hz. It costs a line, and without it a future narrow
/// band would silently be transmitted outside.
Map<String, dynamic> zeroBeatSuggestion(
  Map<String, dynamic> qso, {
  required bool enabled,
  required bool radioConnected,
  required double rangeHz,
  required double draw,
}) {
  final freqKHz = (qso['freq'] as num?)?.toDouble();
  if (!shouldAvoidZeroBeat(
    enabled: enabled,
    radioConnected: radioConnected,
    mode: qso['mode'] as String?,
    freqKHz: freqKHz,
  )) {
    return qso;
  }
  final offsetHz = zeroBeatOffsetHz(rangeHz, draw);
  for (final candidate in [offsetHz, -offsetHz]) {
    final moved = applyZeroBeatOffset(freqKHz!, candidate);
    // The cutoff is re-checked on the MOVED value, not just the spot's: the
    // guard is about what the frequency field will be asked to round-trip.
    if (moved >= _lowestOffsettableKHz && staysInBand(moved, freqKHz)) return {...qso, 'freq': moved};
  }
  return qso;
}

/// Applies [zeroBeatSuggestion] while keeping one spot's offset stable across
/// repeated taps.
///
/// Two things have to hold at once, and they pull against each other:
///
/// - **The same spot must land on the same frequency.** Each tap builds a
///   fresh suggestion, which `LoggingControls` pushes to the VFO, so a new
///   draw per tap would physically retune the rig tens of Hz — an operator
///   tapping a spot again to re-read its reference info would hear the radio
///   move mid-exchange.
/// - **Every call must return a NEW map.** `LoggingControls.didUpdateWidget`
///   re-applies a suggestion only when the map is a different instance, so
///   handing back a previously-returned one silently stops the panel
///   refilling, the callsign restoring, the spot sources reloading and the
///   VFO push firing — for every spot, not only the ones this offsets.
///
/// So the DRAW is what's remembered, never the result. Everything else is
/// re-evaluated per call, which is also what makes switching the setting off
/// take effect on the very next tap of the same spot.
class ZeroBeatOffsetter {
  /// Beyond this many remembered spots the oldest is forgotten. A session can
  /// tap through a whole spot list, and none of it is worth holding once the
  /// operator has moved on.
  static const _maxRemembered = 32;

  final double Function() _nextDraw;
  final _draws = <String, double>{};

  ZeroBeatOffsetter({double Function()? nextDraw}) : _nextDraw = nextDraw ?? Random().nextDouble;

  /// The spot [qso] came from, as far as "the same spot" goes: a different
  /// frequency or mode for the same call is a different thing to tune to.
  static String _keyFor(Map<String, dynamic> qso) =>
      '${(qso['their'] as Map?)?['call']}|${qso['freq']}|${qso['mode']}';

  Map<String, dynamic> apply(
    Map<String, dynamic> qso, {
    required bool enabled,
    required bool radioConnected,
    required double rangeHz,
  }) {
    // Gate BEFORE drawing, so a spot that will never be offset — phone, no
    // radio, feature off — spends no slot. Otherwise browsing a spot list
    // evicts the very draw this exists to keep.
    if (!shouldAvoidZeroBeat(
      enabled: enabled,
      radioConnected: radioConnected,
      mode: qso['mode'] as String?,
      freqKHz: (qso['freq'] as num?)?.toDouble(),
    )) {
      return qso;
    }
    final key = _keyFor(qso);
    // Remove-then-insert, so touching a key moves it to the end: with a plain
    // `putIfAbsent` the map evicts in INSERTION order, and a spot tapped
    // steadily through a long session would be dropped while a spot glanced
    // at once outlived it.
    final draw = _draws.remove(key) ?? _nextDraw();
    _draws[key] = draw;
    if (_draws.length > _maxRemembered) _draws.remove(_draws.keys.first);
    return zeroBeatSuggestion(
      qso,
      enabled: enabled,
      radioConnected: radioConnected,
      rangeHz: rangeHz,
      draw: draw,
    );
  }
}
