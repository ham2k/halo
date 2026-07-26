// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeps VFO state — freq/band/mode for up to 4 VFOs (`vfoA`..`vfoD`,
// though only `vfoA` is wired up today). This tracks the radio(s) in use,
// not any one operation: a physical radio is tuned to one frequency
// regardless of which operation you're logging into, so this is device-
// global state (shared across every operation), persisted to
// SharedPreferences like `StatusBarService`'s notice history — not synced
// between devices. This is the state future CAT control will read from
// and write to in both directions.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'error_reporting_service.dart';

const _prefsKey = 'radioVfoState';

class RadioService extends ChangeNotifier implements VfoStore {
  final SharedPreferences _prefs;

  final Map<String, Vfo> _vfos = {};

  RadioService(this._prefs) {
    _vfos.addAll(_load());
  }

  @override
  Vfo get vfoA => _vfos['vfoA'] ?? const Vfo();

  /// Updates one VFO (`'vfoA'`..`'vfoD'`) and persists the change. Matches
  /// the `setVfo` command action's convention: passing `freq` replaces the
  /// band with the one derived from it; passing `band` without `freq`
  /// clears the frequency (a manually picked band); `mode` is independent
  /// of the two. Omitted parameters leave that part of the VFO unchanged —
  /// `clearFreq` is the explicit way to clear it without also implying a
  /// `band`.
  @override
  void setVfo(String key, {double? freq, String? band, String? mode, bool clearFreq = false}) {
    final current = _vfos[key] ?? const Vfo();
    final Vfo updated;
    if (freq != null) {
      updated = Vfo(freq: freq, band: bandForFrequency(freq), mode: mode ?? current.mode);
    } else if (band != null || clearFreq) {
      updated = Vfo(freq: null, band: band ?? current.band, mode: mode ?? current.mode);
    } else {
      updated = Vfo(freq: current.freq, band: current.band, mode: mode ?? current.mode);
    }
    _vfos[key] = updated;
    notifyListeners();
    unawaited(_persist());
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
