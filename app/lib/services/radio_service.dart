// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeps VFO state — freq/band/mode/power for up to 4 VFOs (`vfoA`..`vfoD`;
// `vfoA` is the Main VFO's, `vfoB` SO2R's Radio B, the rest unused), and one
// more for every other CAT radio, keyed by its node id. This tracks the radio(s) in use,
// not any one operation: a physical radio is tuned to one frequency
// regardless of which operation you're logging into, so this is device-
// global state (shared across every operation), persisted to
// SharedPreferences like `StatusBarService`'s notice history — not synced
// between devices. This is the state CAT control reads from and writes to
// in both directions: CAT writes what the radio reports, and forwards
// everyone else's writes to the radio (docs/design/cat.md).
//
// Each VFO is two: what the app shows ([RadioService.vfo]), which runs ahead
// of the radio with the operator's tune until the radio reports it, and the
// radio's own last report ([RadioService.realVfo]).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'error_reporting_service.dart';

const _prefsKey = 'radioVfoState';

/// How long a change waits before it's written to disk. Long enough that
/// spinning a radio's VFO knob — which reports every step — costs one write
/// rather than dozens, short enough that a crash loses nothing that matters.
const _persistDebounce = Duration(seconds: 2);

/// The VFOs that persist and that the logging panel reads; any other key is a radio's node id.
const _appVfos = {'vfoA', 'vfoB', 'vfoC', 'vfoD'};

/// How long an operator's tune outranks a radio reporting something else, before the radio has
/// answered a tune often enough to measure, and the bounds its measured answer sets it within.
const _firstHoldMillis = 1500, _minHoldMillis = 1000, _maxHoldMillis = 5000;

/// A radio stepping 10 Hz reports a tune it was given as the step it landed on.
const _sameFreqKHz = 0.0105;

/// An operator's tune the radio has not reported yet: what [RadioService.vfo] shows ahead of
/// [RadioService.realVfo]. A field the tune did not state is null, and the radio's report of it
/// stands.
class _Tune {
  _Tune(this.atMillis);

  /// When the operator last asked: what the hold runs from, and what the radio's answer is timed from.
  int atMillis;
  double? freq;
  String? mode;
}

/// Who moved the VFO.
///
/// CAT needs this to tell the radio's own echo from a real operator
/// action: it writes what the radio reports, hears its own write back
/// through [RadioService]'s notification, and must not then re-tune the
/// radio to the value the radio just gave it. See docs/design/cat.md.
///
/// A command action and a keystroke are both [user]: they mean "the operator
/// wants the radio here", and nothing treats them differently. [dial] is the
/// operator too, turning an on-screen dial — the radio is tuned the same, but
/// it is a knob MOVING, which Smart VFO Snap settles like the radio's own
/// knob, where a typed frequency is an exact target it must not round.
enum VfoOrigin { user, radio, dial }

class RadioService extends ChangeNotifier implements VfoStore {
  final SharedPreferences _prefs;

  final Map<String, Vfo> _vfos = {};
  final Map<String, Vfo> _real = {};
  final Map<String, _Tune> _tunes = {};

  /// Where a held report waits out its tune's hold: only a radio contradicting the tune starts
  /// one, so a VFO with no radio behind it never has a timer.
  final Map<String, Timer> _holds = {};

  /// Each VFO's radio's smoothed time from a tune to its report of it.
  final Map<String, double> _answerMillis = {};

  /// A tune whose hold ran out unconfirmed, still timed until [_maxHoldMillis]: a radio answering
  /// slower than its hold is only measured by the answer that comes after it, and without this the
  /// hold of a slow link never grows past the one it started with.
  final Map<String, _Tune> _late = {};

  /// Trailing debounce before a change is written to disk. Tests pass
  /// [Duration.zero] and then await [flushPendingWrites].
  final Duration writeDelay;

  Timer? _writeTimer;
  Future<void>? _inFlightWrite;

  RadioService(this._prefs, {this.writeDelay = _persistDebounce}) {
    _vfos.addAll(_load());
  }

  @override
  Vfo get vfoA => vfo('vfoA');

  /// Any of the VFOs by key — `vfoB` is SO2R's second radio, a node id any other radio. What the
  /// app shows and logs: the operator's tune from the moment it is asked for, until the radio
  /// reports it or its [holdMillis] runs out with the radio reporting something else.
  Vfo vfo(String key) => _vfos[key] ?? const Vfo();

  /// What the radio behind [key] last reported, whether or not [vfo] shows it yet; empty until it
  /// reports. A report notifies only where it moves [vfo] — CatService notifies every one.
  Vfo realVfo(String key) => _real[key] ?? const Vfo();

  /// Which fields of an operator's tune of [key] the radio has not reported yet: where [vfo] runs
  /// ahead of [realVfo], and where a report that leaves the field out says nothing about it.
  ({bool freq, bool mode}) unconfirmed(String key) => switch (_tunes[key]) {
    final tune? => (freq: tune.freq != null, mode: tune.mode != null),
    null => (freq: false, mode: false),
  };

  /// How long a tune of [key] outranks the radio reporting something else: three of its radio's
  /// usual answers, so a slow link holds longer than a wired rig, within bounds.
  int holdMillis(String key) => switch (_answerMillis[key]) {
    final answer? => (3 * answer).round().clamp(_minHoldMillis, _maxHoldMillis),
    null => _firstHoldMillis,
  };

  /// Where the operator of the operation in front of them is licensed, as
  /// `modeForFrequency` takes it — what a band picked by name is placed
  /// against (`defaultFrequencyForBand`). Set by the operation as it learns
  /// its own callsign's entity; null until then, and the band plan's
  /// unscoped segments answer.
  int? ourItuRegion;
  String? ourCountryCode;

  VfoOrigin _lastOrigin = VfoOrigin.user;
  String _lastKey = 'vfoA';

  /// Who made the change listeners are currently being told about. Only
  /// meaningful inside a notification.
  VfoOrigin get lastVfoOrigin => _lastOrigin;

  /// Which VFO the change listeners are currently being told about moved.
  /// Only meaningful inside a notification, like [lastVfoOrigin].
  String get lastVfoKey => _lastKey;

  /// Updates one VFO (`'vfoA'`..`'vfoD'`, which persist, or a radio's node id). Matches
  /// the `setVfo` command action's convention: passing `freq` replaces the
  /// band with the one derived from it; passing `band` without `freq`
  /// clears the frequency (a manually picked band); `mode` and `power` are
  /// independent of the two. Omitted parameters leave that part of the VFO unchanged —
  /// `clearFreq` is the explicit way to clear it without also implying a
  /// `band`.
  /// [origin] says who moved it — see [VfoOrigin]. It's an extra optional
  /// parameter beyond [VfoStore.setVfo]'s signature (which Dart allows an
  /// override to add), so every existing caller keeps meaning `user` and
  /// only CAT has to say otherwise.
  ///
  /// A `radio` write is a report: it becomes [realVfo], and reaches [vfo]
  /// only where it does not contradict a tune still in its hold.
  @override
  void setVfo(
    String key, {
    double? freq,
    String? band,
    String? mode,
    num? power,
    bool clearFreq = false,
    bool clearPower = false,
    VfoOrigin origin = VfoOrigin.user,
  }) {
    final now = realNowMillis();
    if (origin == VfoOrigin.radio) {
      if (freq != null || mode != null || power != null || clearPower) {
        _real[key] = _applied(_real[key] ?? const Vfo(), freq: freq, mode: mode, power: power, clearPower: clearPower);
      }
      final held = _weigh(key, freq, mode, now);
      if (held.freq) freq = null;
      if (held.mode) mode = null;
    }
    final current = _vfos[key] ?? const Vfo();
    final updated = _applied(current, freq: freq, band: band, mode: mode, power: power, clearFreq: clearFreq, clearPower: clearPower);
    // Only what the write changes is held, a mode the frequency carried across a sideband edge
    // included: restating what is already shown sends the radio nothing, so there is nothing to
    // wait for, and noting it would cancel a release a hold already has waiting.
    if (origin != VfoOrigin.radio) {
      _noteTune(
        key,
        now,
        freq: updated.freq != current.freq ? updated.freq : null,
        mode: updated.mode != current.mode ? updated.mode : null,
        clearsFreq: updated.freq == null && current.freq != null,
      );
    }
    // A radio restating what it already reported is not a change. Without
    // this, every status push and every periodic resync would notify every
    // listener and schedule another write.
    if (updated == current) return;

    _vfos[key] = updated;
    _lastOrigin = origin;
    _lastKey = key;
    notifyListeners();
    if (_appVfos.contains(key)) _scheduleWrite();
  }

  /// A report against the tune of [key] in flight: a field it confirms ends that field's hold, and
  /// one it contradicts within the hold is kept from [vfo] — the radio answering a poll sent ahead
  /// of the tune, or announcing a step the operator has already dragged past. Past the hold the
  /// report stands: a radio that refused or rounded the tune is where it says.
  ({bool freq, bool mode}) _weigh(String key, double? freq, String? mode, int now) {
    const none = (freq: false, mode: false);
    if (freq != null) _timeLate(key, freq, now);
    final tune = _tunes[key];
    if (tune == null || (freq == null && mode == null)) return none;
    final hold = holdMillis(key);
    if (now - tune.atMillis >= hold) {
      _endTune(key, timing: true);
      if (freq != null) _timeLate(key, freq, now);
      return none;
    }
    if (freq != null && tune.freq != null && (freq - tune.freq!).abs() < _sameFreqKHz) {
      _timeAnswer(key, now - tune.atMillis);
      tune.freq = null;
    }
    if (mode != null && mode == tune.mode) tune.mode = null;
    if (tune.freq == null && tune.mode == null) {
      _endTune(key);
      return none;
    }
    final held = (freq: freq != null && tune.freq != null, mode: mode != null && tune.mode != null);
    if (held.freq || held.mode) _holds[key] ??= Timer(Duration(milliseconds: tune.atMillis + hold - now), () => _release(key));
    return held;
  }

  /// The operator asked [key] for [freq] and/or [mode]: held against the radio from [now]. A band
  /// pick names no frequency to hold, and drops the one a tune before it named.
  void _noteTune(String key, int now, {double? freq, String? mode, required bool clearsFreq}) {
    if (freq == null && mode == null && !clearsFreq) return;
    _late.remove(key);
    final tune = _tunes[key] ??= _Tune(now);
    tune.atMillis = now;
    // A report held against the tune before this one is no answer to this one.
    _holds.remove(key)?.cancel();
    if (freq != null) {
      tune.freq = freq;
    } else if (clearsFreq) {
      tune.freq = null;
    }
    if (mode != null) tune.mode = mode;
    if (tune.freq == null && tune.mode == null) _tunes.remove(key);
  }

  /// The hold of [key]'s tune ran out with the radio still reporting something else: its report
  /// stands.
  void _release(String key) {
    _holds.remove(key);
    final tune = _tunes.remove(key), real = _real[key];
    if (tune == null || real == null) return;
    if (tune.freq != null) _late[key] = tune;
    setVfo(key, freq: tune.freq == null ? null : real.freq, mode: tune.mode == null ? null : real.mode, origin: VfoOrigin.radio);
  }

  /// [timing] keeps an unconfirmed frequency timed past the hold ([_late]).
  void _endTune(String key, {bool timing = false}) {
    final tune = _tunes.remove(key);
    _holds.remove(key)?.cancel();
    if (timing && tune?.freq != null) _late[key] = tune!;
  }

  /// A report of [freq] answering a tune whose hold already ran out, if it came within
  /// [_maxHoldMillis] of it.
  void _timeLate(String key, double freq, int now) {
    final late = _late[key];
    if (late == null) return;
    final answer = now - late.atMillis;
    if (answer > _maxHoldMillis) {
      _late.remove(key);
    } else if ((freq - late.freq!).abs() < _sameFreqKHz) {
      _late.remove(key);
      _timeAnswer(key, answer);
    }
  }

  void _timeAnswer(String key, int answerMillis) {
    final was = _answerMillis[key];
    _answerMillis[key] = was == null ? answerMillis.toDouble() : 0.75 * was + 0.25 * answerMillis;
  }

  static Vfo _applied(Vfo current, {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false}) {
    // Independent of the freq/band/mode arithmetic below, like `mode`: a
    // power change says nothing about where the radio is tuned.
    final newPower = clearPower ? null : (power ?? current.power);
    final double? newFreq;
    final String? newBand;
    if (freq != null) {
      newFreq = freq;
      newBand = bandForFrequency(freq);
    } else if (band != null || clearFreq) {
      newFreq = null;
      newBand = band ?? current.band;
    } else {
      newFreq = current.freq;
      newBand = current.band;
    }
    // `SSB` is what a spot, the setVfo command and the mode picker say; it is
    // not a sideband, and which one an operator is actually running is a
    // property of the band, not a second choice to make. Resolving it HERE —
    // where a mode is requested, rather than only at the CAT boundary — is
    // what makes the panel, the logged QSO and the rig name the same mode; a
    // shack with no radio attached resolved nothing at all before.
    //
    // Always against the band this write settles on, not the one being left.
    final String? newMode;
    if (newFreq == null && newBand == null) {
      // Nothing to resolve against. The generic mode stands until there is —
      // picking a sideband here would be a coin flip.
      newMode = mode ?? current.mode;
    } else if (mode != null) {
      // Stated in this write, so it is taken as stated: an operator
      // deliberately on the far sideband keeps it, and a rig reporting its
      // own mode is never second-guessed.
      newMode = resolveSideband(mode, newFreq, band: newBand);
    } else if (newBand != current.band && isSidebandMode(current.mode)) {
      // Crossing a band under a mode nobody restated — a band pick carries no
      // mode at all. The sideband already in the VFO was DERIVED from the
      // band being left, so it is re-derived rather than carried: without
      // this, picking 40m while on 20m SSB leaves the app logging USB, and
      // telling the rig to transmit there.
      newMode = resolveSideband('SSB', newFreq, band: newBand);
    } else {
      // Same band, or a mode with nothing to derive — a power-only write must
      // not rewrite the mode at all.
      newMode = current.mode;
    }
    return Vfo(freq: newFreq, band: newBand, mode: newMode, power: newPower);
  }

  void _scheduleWrite() {
    _writeTimer?.cancel();
    if (writeDelay == Duration.zero) {
      _startWrite();
    } else {
      _writeTimer = Timer(writeDelay, _startWrite);
    }
  }

  void _startWrite() {
    _writeTimer = null;
    // Chained rather than concurrent: `unawaited` writes have no ordering
    // guarantee, so under a burst the stale one could land last.
    _inFlightWrite = (_inFlightWrite ?? Future<void>.value()).then((_) => _persist()).catchError((Object e, StackTrace st) {
      // A failing prefs write must not surface as an unhandled zone error —
      // at CAT rates one transient failure would become a storm.
      debugPrint('[radio] failed to persist VFO state: $e');
      ErrorReportingService.report(e, st, context: 'radio:persist-vfo-state');
    });
  }

  /// Completes once everything written so far has landed. Call before
  /// relying on the persisted state — and in tests, instead of guessing at
  /// a delay.
  Future<void> flushPendingWrites() async {
    if (_writeTimer?.isActive ?? false) {
      _writeTimer!.cancel();
      _startWrite();
    }
    await _inFlightWrite;
  }

  @override
  void dispose() {
    // Flush rather than cancel: dropping the timer would discard up to
    // `writeDelay` of VFO state. `flushPendingWrites` cancels the timer
    // itself.
    unawaited(flushPendingWrites());
    for (final hold in _holds.values) {
      hold.cancel();
    }
    super.dispose();
  }

  Map<String, Vfo> _load() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map) entry.key: Vfo.fromJson((entry.value as Map).cast<String, dynamic>()),
      };
    } catch (e, st) {
      debugPrint('[radio] failed to parse persisted VFO state, discarding it: $e');
      ErrorReportingService.report(e, st, context: 'radio:load-vfo-state');
      return {};
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _prefsKey,
      jsonEncode({
        for (final entry in _vfos.entries)
          if (_appVfos.contains(entry.key)) entry.key: entry.value.toJson(),
      }),
    );
  }
}

/// One of [RadioService]'s VFOs presented as a store's `vfoA` — the VFO a
/// logging panel reads and writes — so SO2R's set B follows `vfoB` without
/// the panel knowing there is more than one.
class RadioVfoView implements VfoStore {
  RadioVfoView(this._radio, this.vfoKey);

  final RadioService _radio;
  final String vfoKey;

  @override
  Vfo get vfoA => _radio.vfo(vfoKey);

  @override
  void setVfo(String key, {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false}) {
    assert(key == 'vfoA', 'a view stands in for vfoA alone');
    _radio.setVfo(vfoKey, freq: freq, band: band, mode: mode, power: power, clearFreq: clearFreq, clearPower: clearPower);
  }
}

/// [RadioService]'s notifications for one VFO alone — what an SO2R set
/// listens to, so each report from the other radio does not rebuild and
/// re-seed it.
class RadioVfoUpdates extends ChangeNotifier {
  RadioVfoUpdates(this._radio, this.vfoKey) {
    _radio.addListener(_relay);
  }

  final RadioService _radio;
  final String vfoKey;

  void _relay() {
    if (_radio.lastVfoKey == vfoKey) notifyListeners();
  }

  @override
  void dispose() {
    _radio.removeListener(_relay);
    super.dispose();
  }
}
