// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeps VFO state — freq/band/mode for up to 4 VFOs (`vfoA`..`vfoD`,
// though only `vfoA` is wired up today). This tracks the radio(s) in use,
// not any one operation: a physical radio is tuned to one frequency
// regardless of which operation you're logging into, so this is device-
// global state (shared across every operation), persisted to
// SharedPreferences like `StatusBarService`'s notice history — not synced
// between devices. This is the state CAT control reads from and writes to
// in both directions: GATO writes what the radio reports, and forwards
// everyone else's writes to the radio (docs/design/gato.md).

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
/// GATO needs this to tell the radio's own echo from a real operator
/// action: it writes what the radio reports, hears its own write back
/// through [RadioService]'s notification, and must not then re-tune the
/// radio to the value the radio just gave it. See docs/design/gato.md.
///
/// Deliberately two values, not three: a command action and a keystroke
/// both mean "the operator wants the radio here", and nothing treats them
/// differently.
enum VfoOrigin { user, radio }

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
  /// clears the frequency (a manually picked band); `mode` is independent
  /// of the two. Omitted parameters leave that part of the VFO unchanged —
  /// `clearFreq` is the explicit way to clear it without also implying a
  /// `band`.
  /// [origin] says who moved it — see [VfoOrigin]. It's an extra optional
  /// parameter beyond [VfoStore.setVfo]'s signature (which Dart allows an
  /// override to add), so every existing caller keeps meaning `user` and
  /// only GATO has to say otherwise.
  @override
  void setVfo(String key,
      {double? freq,
      String? band,
      String? mode,
      bool clearFreq = false,
      VfoOrigin origin = VfoOrigin.user}) {
    final current = _vfos[key] ?? const Vfo();
    final Vfo updated;
    if (freq != null) {
      updated = Vfo(freq: freq, band: bandForFrequency(freq), mode: mode ?? current.mode);
    } else if (band != null || clearFreq) {
      updated = Vfo(freq: null, band: band ?? current.band, mode: mode ?? current.mode);
    } else {
      updated = Vfo(freq: current.freq, band: current.band, mode: mode ?? current.mode);
    }
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
    // `writeDelay` of VFO state, which every `setVfo` used to persist
    // immediately. `flushPendingWrites` cancels the timer itself.
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
    await _prefs.setString(
        _prefsKey, jsonEncode({for (final entry in _vfos.entries) entry.key: entry.value.toJson()}));
  }
}
