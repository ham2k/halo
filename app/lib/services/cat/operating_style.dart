// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';

/// How an operating position is working its radio: running a frequency of
/// its own, or [normal] — anything else, searching and pouncing on other
/// stations' included, and the default; the app labels it S&P. [value] is
/// what a contact stores as `opStyle` and what an extension reads —
/// docs/design/logging-fields.md § Operating style.
enum OperatingStyle {
  run('run'),
  normal('normal');

  const OperatingStyle(this.value);

  final String value;
}

/// Moves each set's operating style with what the operator does, the way a
/// contester's own hands would: message 1 keyed is a CQ, so Run; leaving the
/// run frequency, or picking a spot, is S&P; coming back to the run
/// frequency within [returnWindow] is Run again. The style itself is kept by
/// the caller — [isRunning] and [setRunning] — and every change to it, the
/// tracker's own and the operator's, reaches [styleChanged].
///
/// "Leaving" is [Vfo.movedOffOf], the same QSY the logging panel's wipe
/// reads, measured from the run frequency rather than the last reading, so
/// a run frequency nudged in steps adds up to the QSY one turn of the knob
/// would.
class OperatingStyleTracker {
  OperatingStyleTracker({required this.isRunning, required this.setRunning, required this.vfoOf, required this.transmitting});

  final bool Function(String radio) isRunning;
  final void Function(String radio, bool running) setRunning;

  /// What [radio]'s VFO reads now.
  final Vfo Function(String radio) vfoOf;

  /// Whether [radio]'s VFO reading now is one the rig took while on the
  /// air, which is not read: working split, a rig reports the frequency it
  /// is sending on.
  final bool Function(String radio) transmitting;

  /// How long after leaving the run frequency coming back to it is Run
  /// again. Past it, the operator has moved on and the frequency is not
  /// theirs to come back to.
  static const returnWindow = Duration(minutes: 3);

  /// Where each set is, or was last, running.
  final _runOn = <String, Vfo>{};

  /// Takes [vfo] as [radio]'s run frequency. A VFO with neither frequency
  /// nor band is not yet read, not a place: the next reading takes it, or
  /// that reading would look like a mode change and leave the run.
  void _runHere(String radio, Vfo vfo) {
    if (vfo.freq == null && vfo.band == null) {
      _runOn.remove(radio);
    } else {
      _runOn[radio] = vfo;
    }
  }

  /// When each set last stopped running, by the app clock.
  final _leftAt = <String, int>{};

  /// Whether each set's VFO has been off its run frequency since it stopped
  /// running. Coming back is Run only after going: without it, a spot picked
  /// on the run frequency itself would flip straight back to Run.
  final _away = <String, bool>{};

  /// Each set's VFO as last read off the air: where it receives. A reading
  /// taken on the air may be where it sends, working split, and taken as
  /// the run frequency it would read the next receive reading as a QSY.
  final _heard = <String, Vfo>{};

  Vfo _receiving(String radio) => transmitting(radio) ? (_heard[radio] ?? vfoOf(radio)) : vfoOf(radio);

  /// [radio]'s VFO moved.
  void vfoMoved(String radio) {
    if (transmitting(radio)) return;
    final vfo = vfoOf(radio);
    _heard[radio] = vfo;
    final runOn = _runOn[radio];
    if (isRunning(radio)) {
      if (runOn == null) {
        _runHere(radio, vfo);
      } else if (vfo.movedOffOf(runOn)) {
        setRunning(radio, false);
      }
      return;
    }
    final leftAt = _leftAt[radio];
    if (runOn == null || leftAt == null || nowMillis() - leftAt > returnWindow.inMilliseconds) return;
    if (vfo.movedOffOf(runOn)) {
      _away[radio] = true;
    } else if (_away[radio] == true) {
      setRunning(radio, true);
    }
  }

  /// [radio]'s style changed, by whatever changed it.
  void styleChanged(String radio) {
    final vfo = _receiving(radio);
    if (isRunning(radio)) {
      _runHere(radio, vfo);
      _leftAt.remove(radio);
      _away.remove(radio);
      return;
    }
    _leftAt[radio] = nowMillis();
    final runOn = _runOn[radio];
    _away[radio] = runOn != null && vfo.movedOffOf(runOn);
  }

  /// [radio] keyed message 1: Run, on the frequency it was keyed on.
  void messageOne(String radio) {
    if (isRunning(radio)) {
      _runHere(radio, _receiving(radio));
    } else {
      setRunning(radio, true);
    }
  }

  /// The operator picked a spot to work on [radio]. The tune to it is no
  /// return to the run frequency, even onto it: only a move away after it
  /// makes the way back one.
  void pickedSpot(String radio) {
    if (isRunning(radio)) setRunning(radio, false);
    _away[radio] = false;
  }

  /// [radio] stopped or started being a set of its own (SO2R's Radio B):
  /// what it ran before is no run of the set it is now.
  void forget(String radio) {
    for (final map in [_runOn, _leftAt, _away, _heard]) {
      map.remove(radio);
    }
  }

  /// SO2R's SWAP traded the two radios' frequencies and styles: each set
  /// takes the other's run frequency with them.
  void swap() {
    void trade<T>(Map<String, T> map) {
      final (a, b) = (map.remove('A'), map.remove('B'));
      if (b != null) map['A'] = b;
      if (a != null) map['B'] = a;
    }

    trade(_runOn);
    trade(_leftAt);
    trade(_away);
    trade(_heard);
  }
}
