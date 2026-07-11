// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeps the current operation's VFO state — freq/band/mode for up to 4
// VFOs (`vfoA`..`vfoD`, though only `vfoA` is wired up today). Persisted
// under `Operation.localData['radio']`, device-local like `ScoringService`'s
// cached summaries, since a radio's tuned frequency isn't something that
// should sync between devices. This is the state future CAT control will
// read from and write to in both directions.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

class RadioService extends ChangeNotifier implements VfoStore {
  final OperationsRepository operations;

  RadioService({required this.operations});

  String? _operationUuid;
  final Map<String, Vfo> _vfos = {};

  @override
  Vfo get vfoA => _vfos['vfoA'] ?? const Vfo();

  /// Seeds VFO state from [operation]'s persisted `localData`. A no-op if
  /// this is already the loaded operation, so callers can call it
  /// unconditionally whenever the operation they're showing might have
  /// changed.
  @override
  void loadForOperation(Operation operation) {
    if (_operationUuid == operation.uuid) return;
    _operationUuid = operation.uuid;
    _vfos.clear();
    final radio = operation.localData['radio'] as Map?;
    if (radio != null) {
      for (final entry in radio.entries) {
        final value = entry.value;
        if (value is Map) _vfos[entry.key as String] = Vfo.fromJson(value.cast<String, dynamic>());
      }
    }
    notifyListeners();
  }

  /// Updates one VFO (`'vfoA'`..`'vfoD'`) and persists the change. Matches
  /// the `setVfo` command action's convention: passing `freq` replaces the
  /// band with the one derived from it; passing `band` without `freq`
  /// clears the frequency (a manually picked band); `mode` is independent
  /// of the two. Omitted parameters leave that part of the VFO unchanged.
  @override
  void setVfo(String key, {double? freq, String? band, String? mode}) {
    if (_operationUuid == null) return;
    final current = _vfos[key] ?? const Vfo();
    final Vfo updated;
    if (freq != null) {
      updated = Vfo(freq: freq, band: bandForFrequency(freq), mode: mode ?? current.mode);
    } else if (band != null) {
      updated = Vfo(freq: null, band: band, mode: mode ?? current.mode);
    } else {
      updated = Vfo(freq: current.freq, band: current.band, mode: mode ?? current.mode);
    }
    _vfos[key] = updated;
    notifyListeners();
    unawaited(operations.updateLocalData(_operationUuid!, {
      'radio': {for (final entry in _vfos.entries) entry.key: entry.value.toJson()},
    }));
  }
}
