// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../../../services/cat/cat_service.dart';
import '../../../services/cat/equipment.dart';
import '../../../services/cat/spectrum.dart';
import '../../../services/panel_radio_service.dart';
import '../../../services/settings_service.dart';
import 'scene_spectrum.dart';

/// A scene's spectrum controls, fed by the station's CAT connections.
@immutable
class CatSpectrumSource implements SceneSpectrumSource {
  final CatService cat;

  /// Holds the SDR receivers experiment (`fall` in experiments.yaml): whether
  /// a radio's linked SDR draws in place of its own scope. Read at each
  /// [resolve], with [changes] carrying its toggle, as [PanelRadioService]
  /// reads it at each call — a value captured when the dock builds would have
  /// a panel set one device's scope while its control draws another's. Holds
  /// the `keyer` experiment too, which `radio.ptt` waits on as `readRadio`'s
  /// `keying` does. Null reads as off.
  final SettingsService? settings;

  /// Whether the panel may command the radio — `requiresRadioWrite` — and so
  /// move its scope.
  final bool canCommand;

  const CatSpectrumSource(this.cat, {this.settings, this.canCommand = false});

  /// The node whose sweeps a control draws: the radio's linked SDR when it
  /// has one, otherwise the radio. Everything about the radio itself — its
  /// dial, its meters — is read back through [_radioOf], so a scene's
  /// `radio` values stay the radio's whichever node draws.
  @override
  String? resolve(String? radio) {
    final uuid = radio == null
        ? switch (cat.radio1) {
            LocalRadio(:final uuid) => uuid,
            _ => null,
          }
        // A node that is not a radio — a keyer, a switch — has no scope to name.
        : switch (cat.nodeFor(radio)) {
            final node? when cat.typeFor(node)?.category == kCategoryTransceiver => radio,
            _ => null,
          };
    if (uuid == null || !(settings?.experimentEnabled('fall') /* stored key, see experiments.yaml */ ?? false)) return uuid;
    return cat.spectrumNodeFor(uuid);
  }

  String? _radioOf(String uuid) => cat.isSdr(uuid) ? cat.linkedRadioFor(uuid) : uuid;

  @override
  Stream<SpectrumFrame> frames(String uuid) => cat.spectrumFrames(uuid);

  @override
  String? problem(String uuid) {
    final state = cat.stateFor(uuid);
    if (cat.isSdr(uuid)) {
      if (cat.sdrConnectionProblem(uuid) case final problem?) return problem;
    }
    if (state.status != EquipmentStatus.connected) return t.settings.station.spectrumNoRadio;
    if (cat.spectrumCapabilitiesFor(uuid) == null) return t.settings.station.spectrumUnsupported;
    return cat.spectrumProblemFor(uuid);
  }

  @override
  double? vfoHz(String uuid) => switch (_radioOf(uuid)) {
    final radio? => switch (cat.stateFor(radio).vfo.freqKHz) {
      final khz? => khz * 1000,
      null => null,
    },
    null => null,
  };

  @override
  Listenable get changes => switch (settings) {
    final settings? => Listenable.merge([cat, settings]),
    null => cat,
  };

  /// Kept to `readRadio`'s rules ([PanelRadioService.read]), so a scene and a
  /// render never disagree about what the radio is doing: the frequency and
  /// mode are the last the radio reported, connected or not; everything else
  /// only while it is live.
  @override
  Map<String, num> readings(String node) {
    final uuid = _radioOf(node);
    if (uuid == null) return const {};
    final state = cat.stateFor(uuid);
    final live = isLiveRadio(state);
    final transmitting = live && state.telemetry.transmitting == true, last = cat.lastTransmissionFor(uuid);
    final passband = live ? state.passband : null;
    return {
      ...liveMeters(state, live: live),
      if (live && state.telemetry.transmitting != null) 'transmitting': state.telemetry.isTransmitting ? 1 : 0,
      if (live) 'swrAverage': ?cat.swrAverageFor(uuid),
      // Always given, a long time when there has been none: a hold bound to it is over, not pending.
      'secondsSinceTransmit': transmitting ? 0 : (last == null ? 1e9 : (realNowMillis() - last.endedAtMillis) / 1000),
      if (state.vfo.freqKHz case final khz?) 'frequencyHz': (khz * 1000).round(),
      if (passband != null) ...{'passbandLowHz': passband.lowHz, 'passbandHighHz': passband.highHz, 'passbandWidthHz': passband.widthHz},
      if (live) 'powerWatts': ?state.power,
      if (_keyed(uuid, live)) 'ptt': cat.pttHeldOn(uuid) ? 1 : 0,
      'connected': live ? 1 : 0,
    };
  }

  @override
  Map<String, String> readingStrings(String node) {
    final uuid = _radioOf(node);
    if (uuid == null) return const {};
    final state = cat.stateFor(uuid);
    return {'mode': ?state.vfo.mode, if (isLiveRadio(state)) 'tuner': ?state.tuner?.name, 'status': state.status.name};
  }

  @override
  List<Object?> dialState() => [
    for (final node in cat.nodes)
      if (cat.typeFor(node)?.category == kCategoryTransceiver) ..._dial(node.uuid),
  ];

  /// What a `radio` trigger answers to, read straight from the state: it runs on every meter
  /// reading, several a second, and the meters themselves are no part of it — a scene binds them
  /// live, and a render has nothing to redraw for them. The same values [readings] gives.
  List<Object?> _dial(String uuid) {
    final state = cat.stateFor(uuid), live = isLiveRadio(state);
    return [
      uuid,
      state.status,
      live,
      state.vfo.freqKHz,
      state.vfo.mode,
      if (live) ...[state.passband?.lowHz, state.passband?.highHz, state.telemetry.transmitting],
      if (_keyed(uuid, live)) cat.pttHeldOn(uuid),
    ];
  }

  /// Whether the app keys [uuid] where a panel may see it: `readRadio` gives `keying` only for a
  /// live radio 1 or 2 while the `keyer` experiment is on, and `radio.ptt` keeps to the same.
  bool _keyed(String uuid, bool live) =>
      live && (cat.isRadio1(uuid) || cat.isRadio2(uuid)) && (settings?.experimentEnabled('keyer') /* stored key, see experiments.yaml */ ?? false);

  @override
  Listenable get readingChanges => cat.meterReadings;

  @override
  bool recenter(String uuid, int centerHz) {
    if (!canCommand || !(cat.spectrumCapabilitiesFor(uuid)?.canRecenter ?? false)) return false;
    return cat.setSpectrum(uuid, SpectrumRequest(centerHz: centerHz));
  }

  /// Any panel that draws the scope, commanding the radio or not: the span
  /// it sizes is only ever one that changes nothing on the radio.
  @override
  void showWidth(String uuid, Object owner, int? widthHz) => cat.wantSpectrumWidth(uuid, owner, widthHz);

  @override
  String get noRadio => t.settings.station.spectrumNoRadio;

  @override
  String get waiting => t.settings.station.spectrumWaiting;

  @override
  bool operator ==(Object other) =>
      other is CatSpectrumSource && identical(other.cat, cat) && identical(other.settings, settings) && other.canCommand == canCommand;

  @override
  int get hashCode => Object.hash(identityHashCode(cat), identityHashCode(settings), canCommand);
}
