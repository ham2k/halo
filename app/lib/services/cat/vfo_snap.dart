// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Smart VFO Snap: where a knob turn should land once the operator stops
// turning (docs/design/cat.md § Smart VFO Snap).
//
// Pure and clockless — [report] is told the time rather than reading it, and
// the quiet-period timer belongs to the caller. That keeps every rule here
// testable without fakeAsync, and keeps the one piece of real timing in
// CatService where the rest of the timers already live.

import 'package:halo_core/halo_core.dart';

/// Grids the VFO can land on, in kHz. `0.25` is the "250/500/750" grid — a
/// quarter kHz, which is where phone operators conventionally sit between the
/// whole-kHz slots.
const _gridKHz1k = 1.0;
const _gridKHz250 = 0.25;
const _gridKHz100 = 0.1;

/// The three numbers that decide whether a movement snaps and how coarsely,
/// all operator-settable so the feel can be tuned against a real knob
/// (docs/design/cat.md § Smart VFO Snap).
///
/// Distance decides the grid; speed only ever DISQUALIFIES, and only for
/// moves short of [longMoveKHz]. A long haul is a search for a clear slot
/// however it ended — easing in at the last turn of the knob doesn't make it
/// a fine adjustment.
class VfoSnapTuning {
  /// At or beyond this, the movement lands on a whole kHz, speed ignored.
  final double longMoveKHz;

  /// Below this, nothing snaps: the operator is zero-beating a voice against
  /// a filter, and rounding that is the app arguing with an ear.
  final double minMoveKHz;

  /// Below this average speed, a movement short of [longMoveKHz] doesn't
  /// snap — a deliberate creep is someone placing the VFO exactly, not
  /// someone arriving.
  final double minSpeedKHzPerSec;

  const VfoSnapTuning({this.longMoveKHz = 2.0, this.minMoveKHz = 0.2, this.minSpeedKHzPerSec = 0.5});
}

/// Tracks one movement of the VFO and decides where it should settle.
///
/// One instance, not one per node: the setting applies to the VFO the app is
/// driving, not separately to each radio.
class VfoSnapper {
  /// Where the VFO was before the current movement started — what the
  /// distance and the grid are measured against.
  double? _restingKHz;

  double? _burstStartKHz;
  double? _lastKHz;
  DateTime? _burstStartAt;
  DateTime? _lastAt;

  /// Distance covered BETWEEN the burst's readings, following every reversal
  /// rather than taking the net displacement — it is what the knob actually
  /// did, and the only honest numerator for a speed.
  ///
  /// Deliberately excludes the step from the resting frequency to the first
  /// reading of the burst: nothing says WHEN the VFO left the resting point,
  /// only that it had by the time that reading arrived. Counting that
  /// distance against an interval that starts after it divides a longer
  /// journey by a shorter time, and on a polled radio — where the resting
  /// reading can be a whole slow poll earlier — the overestimate is large
  /// enough to carry a deliberate creep over the speed floor.
  double _pathKHz = 0;

  bool get hasBurst => _burstStartKHz != null;

  /// Records what the radio reports now. Returns true when this is movement,
  /// meaning the caller should (re)arm its quiet-period timer.
  bool report(double freqKHz, DateTime at) {
    final resting = _restingKHz;
    if (resting == null) {
      // Nothing to move away from yet — the first reading of a session, or
      // the first after a rebase. It becomes the resting point.
      _restingKHz = freqKHz;
      return false;
    }
    if (freqKHz == (hasBurst ? _lastKHz : resting)) {
      // The radio restating where it already is. It must not end the burst —
      // but it must not extend it either: the caller re-arms its quiet period
      // on a true, and the polled drivers restate the frequency every 200 ms
      // while the poller is still in its fast cadence, which would push the
      // settle out well past the delay the operator set.
      return false;
    }

    if (!hasBurst) {
      _burstStartKHz = resting;
      // The first MOVED reading opens the measured interval, and carries no
      // path with it — see [_pathKHz].
      _burstStartAt = at;
      _pathKHz = 0;
    } else {
      _pathKHz += (freqKHz - _lastKHz!).abs();
    }
    _lastKHz = freqKHz;
    _lastAt = at;
    return true;
  }

  /// The quiet period elapsed. Returns where the VFO should land, or null to
  /// leave it where it is. Ends the burst either way, and takes the answer
  /// (or the untouched frequency) as the new resting point — so the radio
  /// confirming a snap we just asked for reads as no movement at all rather
  /// than as the start of another burst.
  double? settle(VfoSnapTuning tuning) {
    final start = _burstStartKHz;
    final startAt = _burstStartAt;
    final current = _lastKHz;
    _burstStartKHz = null;
    _burstStartAt = null;
    if (start == null || current == null) return null;

    _restingKHz = current;

    final grid = _gridFor(
      distanceKHz: (current - start).abs(),
      // Null, not zero, when the burst holds a single reading — a polled
      // radio, always. There is no interval inside the movement to measure
      // over, and an unmeasurable speed must not read as a slow one, or the
      // floor below would block every snap those radios could ever earn.
      speedKHzPerSec: startAt == null || _lastAt!.difference(startAt) <= Duration.zero ? null : _pathKHz / (_lastAt!.difference(startAt).inMicroseconds / 1e6),
      tuning: tuning,
    );
    if (grid == null) return null;

    final snapped = snapToGrid(current, grid);
    if (snapped == current) return null;
    if (!staysInBand(snapped, current)) return null;

    _restingKHz = snapped;
    return snapped;
  }

  /// Forgets the current movement and takes [freqKHz] as the resting point —
  /// for a move that was not the knob (a typed frequency, a spot) and for a
  /// session ending, where the next reading starts a fresh history.
  void rebase(double? freqKHz) {
    _restingKHz = freqKHz;
    _burstStartKHz = null;
    _burstStartAt = null;
    _lastKHz = freqKHz;
    _lastAt = null;
    _pathKHz = 0;
  }
}

/// The grid a movement of [distanceKHz] earns, or null to leave the VFO
/// alone. [speedKHzPerSec] is null when the burst was a single reading and no
/// speed could be measured.
double? _gridFor({required double distanceKHz, required double? speedKHzPerSec, required VfoSnapTuning tuning}) {
  // A long haul is a search for a clear slot, and it stays one however it
  // ended — checked BEFORE the speed floor, so easing in over the last turn
  // of the knob can't demote it to a fine adjustment.
  if (distanceKHz >= tuning.longMoveKHz) return _gridKHz1k;
  if (distanceKHz < tuning.minMoveKHz) return null;
  // A creep is someone placing the VFO exactly. An UNMEASURED speed is not a
  // slow one — a polled radio reports a whole knob turn as one jump, and
  // holding those to a floor they can never clear would turn the feature off
  // on that hardware.
  if (speedKHzPerSec != null && speedKHzPerSec < tuning.minSpeedKHzPerSec) return null;
  // Half of a long move is still most of the way to one: coarser than a
  // correction, not yet a whole kHz. Derived rather than fixed so the rung
  // stays inside the range the other two settings leave for it.
  return distanceKHz >= tuning.longMoveKHz / 2 ? _gridKHz250 : _gridKHz100;
}

/// Whether [moved] is still somewhere the operator can transmit, given they
/// were at [current]. Shared with zero_beat.dart, which moves the VFO for a
/// different reason and needs the same answer.
///
/// Rounding to nearest moves the VFO at most half a grid step, and half a
/// step is enough to reach a band edge from just inside it — 7299.7 rounds
/// to 7300.0, the top of 40 m. STRICTLY inside, because a carrier sitting
/// exactly on the edge puts its sideband outside: [bandForFrequency] answers
/// with the band at either limit, so comparing bands would let that through.
///
/// A frequency in no band at all is left to snap: the operator is on a
/// transverter IF, or a band this table doesn't carry, and refusing there
/// would be guessing on no evidence.
bool staysInBand(double moved, double current) {
  for (final band in bands) {
    if (current >= band.minKHz && current <= band.maxKHz) {
      return moved > band.minKHz && moved < band.maxKHz;
    }
  }
  return true;
}

/// [freqKHz] rounded to the nearest multiple of [gridKHz].
///
/// Done in whole Hz: `(14285.3 / 0.1).round() * 0.1` is 14285.300000000001,
/// which is not the frequency anyone asked for and would be sent to the
/// radio as-is.
double snapToGrid(double freqKHz, double gridKHz) {
  final gridHz = (gridKHz * 1000).round();
  final freqHz = (freqKHz * 1000).round();
  return ((freqHz / gridHz).round() * gridHz) / 1000;
}
