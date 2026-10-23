// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The knob's own moves, rounded to a sensible number once the operator
// stops turning (docs/design/cat.md § Smart VFO Snap). The rules live in
// vfo_snap.dart; what is here is when to ask them.

part of 'cat_service.dart';

mixin _VfoSnap {
  SettingsService get _settings;
  RadioService? get _radio;
  Map<String, _NodeRuntime> get _runtimes;
  String? get _localRadio1;
  bool get _disposed;
  DateTime Function() get now;
  bool get radio1IsTransmitting;

  /// The movement tracker and its quiet-period timer. ONE of each, not one
  /// per node: the setting applies to the VFO the app is driving —
  /// `radio1`'s — not separately to every radio in the shack.
  final _snapper = VfoSnapper();
  Timer? _snapTimer;

  /// Feeds `radio1`'s reading to the snapper and re-arms the quiet period.
  ///
  /// Phone only, and checked on every reading rather than once: a radio
  /// switched from SSB to CW mid-burst must abandon the burst, not settle it
  /// under the old mode. CW and data operators tune to exact frequencies and
  /// snapping under them would be the app moving the rig off a signal.
  void _noteSnapReading(VfoReading reading) {
    final freqKHz = reading.freqKHz;
    if (!_settings.smartVfoSnap || freqKHz == null || superModeForMode(reading.mode) != 'Phone') {
      _cancelSnap(freqKHz);
      return;
    }
    // Hands off a transmitting radio. Retuning a rig mid-over is the one
    // thing this feature must never do — some rigs simply refuse it, the
    // ones that don't sweep the carrier across the band on their way — and
    // a burst measured across a transmission is not a knob turn anyway.
    if (radio1IsTransmitting) {
      _cancelSnap(freqKHz);
      return;
    }
    if (!_snapper.report(freqKHz, now())) return;
    _snapTimer?.cancel();
    // Read per reading, not cached: the operator tuning this setting is
    // turning the knob to feel the difference, and a cached period would make
    // the change take effect only after a reconnect.
    _snapTimer = Timer(_snapQuietPeriod, _settleSnap);
  }

  /// How long the VFO must hold still before [_settleSnap] believes it.
  ///
  /// The operator's setting is how long a SETTLED VFO should sit before the
  /// app acts. On a polling session that is not the same as how long the app
  /// must wait: between polls no readings arrive whether the dial is still or
  /// spinning, so the first poll period carries no information at all. Adding
  /// it means the delay always measures silence we could have heard something
  /// in — and a pushing session (`expectedUpdateInterval` null) adds nothing,
  /// because there every quiet millisecond is evidence.
  ///
  /// Read at arming time, from the cadence in force DURING the movement —
  /// AdaptivePoller is at its fast interval then, having just seen a change.
  /// Re-reading it later would chase the back-off the moment the dial stops.
  Duration get _snapQuietPeriod {
    final configured = _settings.smartVfoSnapDebounce;
    final expected = _runtimes[_localRadio1]?.session?.expectedUpdateInterval;
    return expected == null ? configured : configured + expected;
  }

  /// Abandons any pending snap and takes [freqKHz] as the new resting point.
  /// For everything that is not the knob turning: a typed frequency, a spot,
  /// a session ending, the setting going off.
  void _cancelSnap(double? freqKHz) {
    _snapTimer?.cancel();
    _snapTimer = null;
    _snapper.rebase(freqKHz);
  }

  /// The VFO held still long enough. Retunes the radio if the movement
  /// earned a snap.
  void _settleSnap() {
    _snapTimer = null;
    final target = _snapper.settle(
      VfoSnapTuning(
        longMoveKHz: _settings.smartVfoSnapLongMoveKHz,
        minMoveKHz: _settings.smartVfoSnapMinMoveKHz,
        minSpeedKHzPerSec: _settings.smartVfoSnapMinSpeed,
      ),
    );
    // Settled first, so the movement is consumed either way: switching the
    // setting off during a turn must not leave a burst behind to be settled
    // by whatever reading follows it being switched back on.
    // Checked again here, not only when the burst was fed: the operator can
    // key the rig during the settle delay, and this is the line that
    // actually moves it.
    if (target == null || _disposed || !_settings.smartVfoSnap || radio1IsTransmitting) return;
    // Written as the OPERATOR, deliberately: the snap is a decision about
    // where they meant to be, so it takes the same path a typed frequency
    // does — RadioService notifies, [_onVfoChanged] tunes the radio. Tagging
    // it `radio` would leave the app showing a frequency the rig is not on.
    _radio?.setVfo('vfoA', freq: target);
  }
}
