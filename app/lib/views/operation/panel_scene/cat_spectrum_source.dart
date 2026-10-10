// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../../../services/cat/cat_service.dart';
import '../../../services/cat/equipment.dart';
import '../../../services/cat/spectrum.dart';
import '../../../services/panel_radio_service.dart';
import 'scene_spectrum.dart';

/// A scene's spectrum controls, fed by the station's CAT connections.
@immutable
class CatSpectrumSource implements SceneSpectrumSource {
  final CatService cat;

  @override
  final bool spectrumEnabled;

  /// Whether the panel may command the radio — `requiresRadioWrite` — and so
  /// move its scope.
  final bool canCommand;

  const CatSpectrumSource(this.cat, {this.spectrumEnabled = true, this.canCommand = false});

  @override
  String? resolve(String? radio) {
    if (radio == null) {
      return switch (cat.radio1) {
        LocalRadio(:final uuid) => uuid,
        _ => null,
      };
    }
    // A node that is not a radio — a keyer, a switch — has no scope to name.
    final node = cat.nodeFor(radio);
    return node != null && cat.typeFor(node)?.category == kCategoryTransceiver ? radio : null;
  }

  @override
  Stream<SpectrumFrame> frames(String uuid) => cat.spectrumFrames(uuid);

  @override
  String? problem(String uuid) {
    final state = cat.stateFor(uuid);
    if (state.status != EquipmentStatus.connected) return t.settings.station.spectrumNoRadio;
    final session = cat.spectrumSessionFor(uuid);
    if (session == null) return t.settings.station.spectrumUnsupported;
    return session.spectrumUnavailable ?? state.spectrumProblem;
  }

  @override
  double? vfoHz(String uuid) => switch (cat.stateFor(uuid).vfo.freqKHz) {
    final khz? => khz * 1000,
    null => null,
  };

  @override
  Listenable get changes => cat;

  @override
  Map<String, num> readings(String uuid) {
    final state = cat.stateFor(uuid);
    final live = state.status == EquipmentStatus.connected && !state.stale && state.problem == null;
    final transmitting = live && state.telemetry.transmitting == true, last = cat.lastTransmissionFor(uuid);
    return {
      ...liveMeters(state, live: live),
      if (live && state.telemetry.transmitting != null) 'transmitting': state.telemetry.isTransmitting ? 1 : 0,
      if (live) 'swrAverage': ?cat.swrAverageFor(uuid),
      // Always given, a long time when there has been none: a hold bound to it is over, not pending.
      'secondsSinceTransmit': transmitting ? 0 : (last == null ? 1e9 : (realNowMillis() - last.endedAtMillis) / 1000),
    };
  }

  @override
  Listenable get readingChanges => cat.meterReadings;

  @override
  bool recenter(String uuid, int centerHz) {
    if (!canCommand || !(cat.spectrumSessionFor(uuid)?.spectrumCapabilities.canRecenter ?? false)) return false;
    return cat.setSpectrum(uuid, SpectrumRequest(centerHz: centerHz));
  }

  @override
  String get noRadio => t.settings.station.spectrumNoRadio;

  @override
  String get waiting => t.settings.station.spectrumWaiting;

  @override
  bool operator ==(Object other) =>
      other is CatSpectrumSource && identical(other.cat, cat) && other.spectrumEnabled == spectrumEnabled && other.canCommand == canCommand;

  @override
  int get hashCode => Object.hash(identityHashCode(cat), spectrumEnabled, canCommand);
}
