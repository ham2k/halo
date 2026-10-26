// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a CAT server's client sees of the station: the Main VFO radio, read
// and tuned through the same `vfoA` funnel the logging panel uses
// (docs/design/cat.md § CAT server).

import 'package:flutter/foundation.dart';

import '../cat/cat_service.dart';
import '../cat/equipment.dart';
import '../peer/peer_remote_radios.dart';
import '../radio_service.dart';
import '../settings_service.dart';
import 'cat_server_service.dart';

/// The longest a client holds the transmitter keyed before the app drops it.
/// Longer than the operator's own key: a JS8 or fldigi text transmission runs
/// well past a minute. Still bounded, since a client that hangs mid-over
/// sends no unkey.
const catServerPttTimeout = Duration(minutes: 3);

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

  /// Whether the operator allows clients to transmit at all — what a
  /// protocol that announces PTT once, at connect, announces. Whether a key
  /// can go out right now is [canTransmit].
  bool get transmitAllowed;

  /// Whether a client may key the transmitter right now: [transmitAllowed],
  /// and the Main VFO radio is a local one whose CAT can key it.
  bool get canTransmit;

  /// Keys the Main VFO radio for [owner], as the station's one PTT key. False
  /// when it did not key: not [canTransmit], someone else holds the key, or
  /// the key failed.
  bool keyPtt(Object owner);

  /// Drops [owner]'s key, on whichever radio it went to. A key the operator
  /// or another client holds stays.
  void releasePtt(Object owner);

  /// Drops a key any client holds — the operator's stays. For the operator
  /// withdrawing the permission: that is how a transmission they did not
  /// start is stopped.
  void releaseClientPtt();

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
  final SettingsService settings;

  StationCatServerRig({required this.cat, required this.radio, required this.peerRadios, required this.settings});

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

  @override
  bool get transmitAllowed => CatServerSettings.allowTransmit(settings);

  @override
  bool get canTransmit => transmitAllowed && cat.canPttRadio1;

  @override
  bool keyPtt(Object owner) => transmitAllowed && cat.keyRadio1Ptt(owner, timeout: catServerPttTimeout);

  @override
  void releasePtt(Object owner) => cat.releasePtt(owner);

  @override
  void releaseClientPtt() {
    final owner = cat.pttOwner;
    if (owner is CatServerPtt) cat.releasePtt(owner);
  }
}

/// One client's PTT, as every protocol takes it, and the owner of any key
/// that client holds. A client that keyed and then went away — closed,
/// crashed, cable pulled — sends no unkey, and no protocol here has a
/// dead-man's switch: [drop] at the connection's close is what takes the
/// transmitter off the air.
class CatServerPtt {
  final CatServerRig rig;

  CatServerPtt(this.rig);

  /// Keys or unkeys at the client's request. False when the client asked to
  /// key and no key went out, which each protocol refuses in its own words.
  /// An unkey always succeeds, and drops only this client's own key.
  bool set(bool on) {
    if (on) return rig.keyPtt(this);
    rig.releasePtt(this);
    return true;
  }

  void drop() => rig.releasePtt(this);
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
