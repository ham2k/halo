// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeps VFO state — freq/band/mode/power for up to 4 VFOs (`vfoA`..`vfoD`,
// though only `vfoA` is wired up today). This tracks the radio(s) in use,
// not any one operation: a physical radio is tuned to one frequency
// regardless of which operation you're logging into, so this is device-
// global state (shared across every operation), persisted to
// SharedPreferences like `StatusBarService`'s notice history — not synced
// between devices. This is the state CAT control reads from and writes to
// in both directions: CAT writes what the radio reports, and forwards
// everyone else's writes to the radio (docs/design/cat.md).

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

  /// Trailing debounce before a change is written to disk. Tests pass
  /// [Duration.zero] and then await [flushPendingWrites].
  final Duration writeDelay;

  Timer? _writeTimer;
  Future<void>? _inFlightWrite;

  RadioService(this._prefs, {this.writeDelay = _persistDebounce}) {
    _vfos.addAll(_load());
  }

  @override
  Vfo get vfoA => _vfos['vfoA'] ?? const Vfo();

  VfoOrigin _lastOrigin = VfoOrigin.user;

  /// Who made the change listeners are currently being told about. Only
  /// meaningful inside a notification.
  VfoOrigin get lastVfoOrigin => _lastOrigin;

  /// Updates one VFO (`'vfoA'`..`'vfoD'`) and persists the change. Matches
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
    final current = _vfos[key] ?? const Vfo();
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
    final updated = Vfo(freq: newFreq, band: newBand, mode: newMode, power: newPower);
    // A radio restating what it already reported is not a change. Without
    // this, every status push and every periodic resync would notify every
    // listener and schedule another write.
    if (updated == current) return;

    _vfos[key] = updated;
    _lastOrigin = origin;
    notifyListeners();
    _scheduleWrite();
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
    await _prefs.setString(_prefsKey, jsonEncode({for (final entry in _vfos.entries) entry.key: entry.value.toJson()}));
  }
}
