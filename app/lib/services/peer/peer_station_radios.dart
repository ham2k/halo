// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the peer CAT bridge needs from this device's own station (HALO-416),
// and nothing else. `CatService` implements it; the router
// (`PeerChannels`) holds only this.
//
// A seam rather than a direct reference, for the reason the bridge exists at
// all: everything above the `EquipmentSession` boundary is transport-blind
// (docs/design/cat.md), and a router that could reach into the equipment
// registry would not stay that way. It also keeps the channel tests running
// two REAL `RadioService`s against a stub station, which is what makes them
// prove the origin/echo discipline rather than restate `CatService`.

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../cat/equipment.dart';

/// The peer radio this device's `vfoA` follows — a device and one of the
/// radios it offers. Both halves are needed to name one: node uuids are
/// unique within a station, not across the pair.
@immutable
class PeerRadioSelection {
  final String deviceId;
  final String radioId;

  /// What the two were called when they were picked, kept only so a
  /// remembered selection can be NAMED while the peer is away — after a
  /// relaunch there is nowhere else to read them from, and a picker showing
  /// two uuids tells the operator nothing about what they chose.
  ///
  /// Deliberately outside [operator ==] and [hashCode]: a device or radio
  /// that is renamed is still the same radio, and comparing names would make
  /// the rename read as a different pick.
  final String deviceName;
  final String radioName;

  const PeerRadioSelection({
    required this.deviceId,
    required this.radioId,
    this.deviceName = '',
    this.radioName = '',
  });

  bool matches(String deviceId, String radioId) =>
      this.deviceId == deviceId && this.radioId == radioId;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'radioId': radioId,
        if (deviceName.isNotEmpty) 'deviceName': deviceName,
        if (radioName.isNotEmpty) 'radioName': radioName,
      };

  /// Null for anything malformed, which reads as "nothing selected" —
  /// the same fallback a stored `radio1` naming an unloadable node takes.
  static PeerRadioSelection? from(Object? raw) {
    if (raw is! Map) return null;
    final deviceId = raw['deviceId'];
    final radioId = raw['radioId'];
    if (deviceId is! String || deviceId.isEmpty) return null;
    if (radioId is! String || radioId.isEmpty) return null;
    final deviceName = raw['deviceName'];
    final radioName = raw['radioName'];
    return PeerRadioSelection(
      deviceId: deviceId,
      radioId: radioId,
      deviceName: deviceName is String ? deviceName : '',
      radioName: radioName is String ? radioName : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PeerRadioSelection && other.deviceId == deviceId && other.radioId == radioId;

  @override
  int get hashCode => Object.hash(deviceId, radioId);
}

/// The prefix that tells a peer radio's picker value from a local node's.
/// Both are uuids; only one of them means "a node in THIS station".
const _peerRadioValuePrefix = 'peer:';

/// [selection] as one string, for a picker whose values are shared with the
/// local nodes'.
///
/// Pure and top-level so the round trip can be tested without a service or a
/// widget — the same reason `uniqueEquipmentName` is. The pair matters
/// because a menu's items are captured when it opens: the value has to carry
/// enough to rebuild the pick, since the offer it was built from may be gone
/// by the time the operator taps it.
String peerRadioValue(PeerRadioSelection selection) =>
    '$_peerRadioValuePrefix${selection.deviceId}:${selection.radioId}';

/// The pick [value] names, or null when it does not name one at all — a local
/// node's uuid, or a malformed value with a half missing.
PeerRadioSelection? peerRadioSelectionFromValue(String? value) {
  if (value == null || !value.startsWith(_peerRadioValuePrefix)) return null;
  final rest = value.substring(_peerRadioValuePrefix.length);
  // The FIRST separator only: a device id cannot contain one, and splitting
  // on every colon would truncate anything a future id scheme puts in the
  // radio half.
  final split = rest.indexOf(':');
  if (split <= 0 || split == rest.length - 1) return null;
  return PeerRadioSelection(
    deviceId: rest.substring(0, split),
    radioId: rest.substring(split + 1),
  );
}

/// The station, as the peer bridge sees it.
abstract class PeerStationRadios implements Listenable {
  /// Every radio this device is willing to have driven from elsewhere.
  ///
  /// Offering is independent of which radio drives this device's own panel:
  /// a shack with two rigs offers both, and a device controlling somebody
  /// else's radio still offers its own. What it is NOT independent of is the
  /// link — only a connected rig is offered, which is what keeps a tune
  /// request from moving app state on a radio that is not there and reaching
  /// the asker as if the rig had confirmed it.
  List<PeerRadioOffer> get offeredRadios;

  /// Where one of [offeredRadios] is sitting, or null if it is not offered.
  VfoReading? vfoForOfferedRadio(String radioId);

  /// Tunes one of this device's own radios on a peer's behalf, through the
  /// same path and echo guards a local operator's tune takes.
  void tuneOfferedRadio(String radioId, {double? freqKHz, String? mode});

  /// The peer radio this device's `vfoA` follows, or null when `vfoA` is a
  /// local rig's or nothing's. Read fresh on every message: the operator can
  /// change the pick while sessions are up.
  ///
  /// This bridge's own narrowing of the station's one main-VFO pick, in the
  /// only terms it can act on — a device and a radio to address a message
  /// to. What the station calls that pick, and what else it can hold, is the
  /// station's business.
  PeerRadioSelection? get followedPeerRadio;

  /// What a peer is offering, and under what names. Only the names matter
  /// here, and only for the one radio this device picked: they are what
  /// [PeerRadioSelection.deviceName] shows once that peer is gone, and this
  /// is the only place a renamed device or radio is heard about without the
  /// operator picking again.
  void noteOffer(String deviceId, String deviceName, List<PeerRadioOffer> radios);
}
