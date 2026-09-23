// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a CAT server's client sees of the station: the Main VFO radio, read
// and tuned through the same `vfoA` funnel the logging panel uses
// (docs/design/cat.md § CAT server).

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../cat/cat_service.dart';
import '../cat/equipment.dart';
import '../peer/peer_remote_radios.dart';
import '../radio_service.dart';

/// The one radio every protocol emulator answers for. Frequencies are kHz
/// and modes are app mode names, as everywhere else in CAT; each codec
/// converts at its own edge.
abstract interface class CatServerRig {
  /// Whether a Main VFO radio is connected right now. Every protocol refuses
  /// to report or tune while this is false: a client that sees a
  /// frequency with no radio behind it would believe it had control.
  bool get available;

  double? get freqKHz;

  String? get mode;

  /// False when nothing knows, the same reading `radio1IsTransmitting` gives.
  bool get transmitting;

  void tune({double? freqKHz, String? mode});

  /// Notifies when any of the above may have changed — for a protocol whose
  /// server speaks first when the radio moves.
  Listenable get changes;
}

/// The app's rig, as [CatServerRig] describes it.
///
/// Writes go to `vfoA` with the default `user` origin, never to a driver
/// session: that is what moves the logging panel along with the radio, and
/// what reaches a peer's radio when that is the Main VFO.
class StationCatServerRig implements CatServerRig {
  final CatService cat;
  final RadioService radio;
  final PeerRemoteRadios peerRadios;

  StationCatServerRig({required this.cat, required this.radio, required this.peerRadios});

  @override
  bool get available => switch (cat.radio1) {
    LocalRadio(:final uuid) => cat.stateFor(uuid).status == EquipmentStatus.connected && !cat.stateFor(uuid).stale,
    PeerRadio(:final selection) => peerRadios.find(selection.deviceId, selection.radioId) != null,
    null => false,
  };

  @override
  double? get freqKHz => radio.vfoA.freq;

  @override
  String? get mode => radio.vfoA.mode;

  @override
  bool get transmitting => cat.radio1IsTransmitting;

  /// The peers' offers too: a peer's radio being the Main VFO is available
  /// only while its device offers it, and nothing in [cat] or [radio] moves
  /// when that device comes or goes.
  @override
  late final Listenable changes = Listenable.merge([radio, cat, peerRadios]);

  @override
  void tune({double? freqKHz, String? mode}) {
    if (!available) return;
    if (freqKHz != null && !isTunableFrequencyKHz(freqKHz)) return;
    if (freqKHz == null && mode == null) return;
    radio.setVfo('vfoA', freq: freqKHz, mode: mode);
  }
}

/// Whether [freqKHz] is a frequency a radio could be tuned to. A client's
/// number is parsed text, and `NaN`, `Infinity` and `1e400` all parse: any of
/// them in `vfoA` reaches the logging panel, a logged contact and the radio,
/// and every later read of it throws.
bool isTunableFrequencyKHz(double freqKHz) => freqKHz.isFinite && freqKHz > 0 && freqKHz < _maxFrequencyKHz;

/// 300 GHz, the top of the radio spectrum.
const _maxFrequencyKHz = 300e6;

/// The modes a client may tune to, by the app's names: every mode a CAT
/// driver reports, plus the app's own digital modes, which a logging client
/// names rather than a sideband.
const _tunableModes = {
  'USB', 'LSB', 'SSB', 'CW', 'AM', 'AM-N', 'FM', 'FM-N', //
  'DATA-USB', 'DATA-LSB', 'DATA-FM', 'RTTY', 'RTTY-LSB', 'RTTY-USB', //
  'FT8', 'FT4', 'DATA',
};

/// What a client's requested [mode] becomes in `vfoA`, or null for one
/// nothing here knows — which a server refuses rather than writing into the
/// logging panel, and so into the log.
///
/// `CW-R` becomes `CW`, as it does for a radio's own report in
/// `CatService`: reverse-sideband CW is a setting of the radio, and the log
/// has no such mode.
String? tunableAppMode(String mode) {
  final upper = mode.toUpperCase();
  if (upper == 'CW-R') return 'CW';
  return _tunableModes.contains(upper) ? upper : null;
}

/// The app modes that name a digital mode rather than a way of setting the
/// radio. A rig running any of them sits in its data sideband, which is what
/// a client asking "what mode is the radio in?" needs to hear.
const _dataModes = {'FT8', 'FT4', 'FT2', 'JS8', 'DATA', 'PSK', 'PSK31', 'OLIVIA', 'MFSK', 'JT65', 'JT9', 'WSPR', 'Q65', 'MSK144', 'FST4', 'VARA'};

/// [mode] as a radio would state it: a digital mode becomes `DATA-USB`, a
/// generic `SSB` the sideband its frequency implies, anything else itself.
String? radioModeForAppMode(String? mode, double? freqKHz) {
  if (mode == null) return null;
  final upper = mode.toUpperCase();
  if (_dataModes.contains(upper)) return 'DATA-USB';
  return resolveSideband(upper, freqKHz);
}
