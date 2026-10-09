// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../../../services/cat/cat_service.dart';
import '../../../services/cat/equipment.dart';
import '../../../services/cat/spectrum.dart';
import 'scene_spectrum.dart';

/// A scene's spectrum controls, fed by the station's CAT connections.
@immutable
class CatSpectrumSource implements SceneSpectrumSource {
  final CatService cat;

  const CatSpectrumSource(this.cat);

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
  String get noRadio => t.settings.station.spectrumNoRadio;

  @override
  String get waiting => t.settings.station.spectrumWaiting;

  @override
  bool operator ==(Object other) => other is CatSpectrumSource && identical(other.cat, cat);

  @override
  int get hashCode => identityHashCode(cat);
}
