// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

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

  /// Where a native tune goes: the same paced queue a panel's `setRadio`
  /// joins, so a click and an extension's command never race to the radio.
  final PanelRadioService? radios;

  @override
  final bool nativeGestures;

  const CatSpectrumSource(this.cat, {this.settings, this.canCommand = false, this.radios, this.nativeGestures = true});

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
    final radio? => switch (cat.vfoFreqKHzFor(radio)) {
      final khz? => khz * 1000,
      null => null,
    },
    null => null,
  };

  @override
  Listenable get changes => Listenable.merge([cat, cat.vfoChanges, ?settings]);

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
      if (cat.vfoFreqKHzFor(uuid) case final khz?) 'frequencyHz': (khz * 1000).round(),
      if (state.vfo.freqKHz case final khz?) 'reportedFrequencyHz': (khz * 1000).round(),
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
    // `readRadio`'s `opStyle`, which a set's radio carries.
    cat.styleOf('A'),
    if (cat.radio2 != null) cat.styleOf('B'),
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
      cat.vfoFreqKHzFor(uuid),
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
  Listenable get readingChanges => Listenable.merge([cat.dialChanges, cat.vfoChanges]);

  /// As `listEquipment` describes a device, so a scene and a render never disagree about one.
  @override
  ({Map<String, num> numbers, Map<String, String> words}) equipment(String id, String kind) {
    final node = cat.nodeFor(id);
    final category = node == null ? null : cat.typeFor(node)?.category;
    final wanted = kind == 'rotator' ? kCategoryRotator : kCategoryAntennaSwitch;
    if (category != wanted) return (numbers: const {}, words: const {});
    final state = cat.stateFor(id);
    final connected = state.status == EquipmentStatus.connected ? 1 : 0;
    if (category == kCategoryRotator) {
      final target = state.rotatorTarget;
      return (
        numbers: {
          'connected': connected,
          'azimuth': ?state.rotator?.azimuth,
          'elevation': ?state.rotator?.elevation,
          'targetAzimuth': ?target?.azimuth,
          // Told to turn, until it arrives, is stopped or stalls.
          'moving': target == null ? 0 : 1,
        },
        words: const {},
      );
    }
    // Only the antennas the operator set up are named, as `listEquipment` names them.
    final names = {
      for (final antenna in state.switchAntennas)
        if (antenna.configured) antenna.key: antenna.name,
    };
    return (
      numbers: {'connected': connected, for (final port in state.switchPorts) '${port.key}.auto': port.auto ? 1 : 0},
      words: {
        for (final port in state.switchPorts)
          if (port.selectedAntennaKey case final key?) ...{'${port.key}.antenna': key, '${port.key}.antennaName': ?names[key]},
      },
    );
  }

  @override
  Listenable get equipmentChanges => cat;

  @override
  bool canRecenter(String uuid) => canCommand && (cat.spectrumCapabilitiesFor(uuid)?.canRecenter ?? false);

  @override
  bool recenter(String uuid, int centerHz) {
    if (!canRecenter(uuid)) return false;
    return cat.setSpectrum(uuid, SpectrumRequest(centerHz: centerHz));
  }

  /// Any panel that draws the scope, commanding the radio or not: the span
  /// it sizes is only ever one that changes nothing on the radio.
  @override
  void showWidth(String uuid, Object owner, int? widthHz) => cat.wantSpectrumWidth(uuid, owner, widthHz);

  @override
  int? maxWidthHz(String uuid) {
    final caps = cat.spectrumCapabilitiesFor(uuid);
    if (caps == null || caps.spansHz.isEmpty || !(caps.autoSpan || canCommand)) return null;
    return 2 * caps.spansHz.last;
  }

  @override
  int? minWidthHz(String uuid) {
    final caps = cat.spectrumCapabilitiesFor(uuid);
    if (caps == null || caps.spansHz.isEmpty || !(caps.autoSpan || canCommand)) return null;
    // A fixed scope's width is its edges, which [fitSpan] leaves alone unless the app places them.
    if (!caps.autoSpan && !caps.spanSetsEdges && cat.stateFor(uuid).spectrum?.mode == SpectrumMode.fixed) return null;
    return 2 * caps.spansHz.first;
  }

  @override
  bool canTune(String uuid) => canCommand && radios != null && _radioOf(uuid) != null;

  @override
  bool tune(String uuid, double hz, {bool dial = false, void Function()? refused}) {
    final radio = _radioOf(uuid), radios = this.radios;
    if (!canCommand || radio == null || radios == null) return false;
    // A refusal is an answer, not an error: `set` throws only for what ErrorPolicy should see.
    unawaited(
      radios.set({'selection': radio, 'id': radio, 'frequencyHz': hz.round(), if (dial) 'dial': true}).then((result) {
        if (result['accepted'] == false) refused?.call();
      }),
    );
    return true;
  }

  /// The widest display drawing the scope sets its span: one display's zoom
  /// in must not cut off another's wider window, and one naming no width
  /// draws the whole sweep, so it holds the span at least where it is.
  @override
  bool fitSpan(String uuid, int widthHz, {int? centerHz, int offCenterHz = 0}) {
    final caps = cat.spectrumCapabilitiesFor(uuid);
    if (!canCommand || caps == null || caps.autoSpan || caps.spansHz.isEmpty) return false;
    final settings = cat.stateFor(uuid).spectrum;
    final fixed = settings?.mode == SpectrumMode.fixed;
    // A fixed scope's width is its edges: a span set there changes nothing but the one centre mode
    // keeps — unless the app places the edges itself, where a span is their width.
    if (fixed && !caps.spanSetsEdges) return false;
    final swept = switch (settings) {
      SpectrumSettings(lowHz: final low?, highHz: final high?) when fixed => high - low,
      _ => 2 * (settings?.spanHz ?? caps.spansHz.last),
    };
    // Edges the app places go to the window, so they need only its width; kept centred on the
    // sweep's middle, a narrower scope would leave a window off to one side unswept.
    final placed = fixed && centerHz != null;
    var width = placed ? widthHz : widthHz + 2 * offCenterHz;
    for (final shown in cat.spectrumWidthsFor(uuid)) {
      final needs = shown > 0 ? shown : swept;
      if (needs > width) width = needs;
    }
    final half = caps.spansHz.firstWhere((h) => 2 * h >= width, orElse: () => caps.spansHz.last);
    return cat.setSpectrum(uuid, SpectrumRequest(spanHz: half, centerHz: placed ? centerHz : null));
  }

  @override
  String get noRadio => t.settings.station.spectrumNoRadio;

  @override
  String get waiting => t.settings.station.spectrumWaiting;

  @override
  bool operator ==(Object other) =>
      other is CatSpectrumSource &&
      identical(other.cat, cat) &&
      identical(other.settings, settings) &&
      identical(other.radios, radios) &&
      other.canCommand == canCommand &&
      other.nativeGestures == nativeGestures;

  @override
  int get hashCode => Object.hash(identityHashCode(cat), identityHashCode(settings), identityHashCode(radios), canCommand, nativeGestures);
}
