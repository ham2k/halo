// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the peers are offering to have driven (HALO-416) — the consumer half
// of `catOffer`, and what the Station panel's main-VFO picker lists beside
// this device's own radios.
//
// Latest-value-wins per device, like every other ephemeral state: an offer
// replaces that peer's previous one outright, an EMPTY one is a real answer
// meaning the peer's last radio went away, and a peer that leaves is
// forgotten entirely.

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

/// One pickable radio: which device offers it, under what name, and the
/// radio itself.
@immutable
class PeerRemoteRadio {
  final String deviceId;
  final String deviceName;
  final PeerRadioOffer radio;

  const PeerRemoteRadio({required this.deviceId, required this.deviceName, required this.radio});
}

class PeerRemoteRadios extends ChangeNotifier {
  final Map<String, ({String name, List<PeerRadioOffer> radios})> _byDevice = {};

  /// Every radio on offer right now, ordered by device and then by radio so
  /// the picker does not reshuffle itself when an unrelated peer's offer
  /// arrives.
  List<PeerRemoteRadio> get all {
    final devices = _byDevice.entries.toList()..sort((a, b) => a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()));
    return [
      for (final device in devices)
        for (final radio in [...device.value.radios]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
          PeerRemoteRadio(deviceId: device.key, deviceName: device.value.name, radio: radio),
    ];
  }

  /// The offer behind a stored selection, or null when that device is not
  /// here or no longer offers that radio — which is what the picker shows as
  /// unavailable rather than dropping.
  PeerRemoteRadio? find(String deviceId, String radioId) {
    final device = _byDevice[deviceId];
    if (device == null) return null;
    for (final radio in device.radios) {
      if (radio.id == radioId) {
        return PeerRemoteRadio(deviceId: deviceId, deviceName: device.name, radio: radio);
      }
    }
    return null;
  }

  void setOffers(String deviceId, String deviceName, List<PeerRadioOffer> radios) {
    // Deduped by id, because this is where a peer's data becomes widget
    // identity: two menu entries sharing a value break the picker's
    // "exactly one matching item" assertion the moment one of them is the
    // selected one. A well-behaved sender iterates a uuid-keyed map and
    // cannot produce it — which is exactly why nothing else would catch a
    // sender that is not.
    final seen = <String>{};
    final unique = [
      for (final radio in radios)
        if (seen.add(radio.id)) radio,
    ];
    final before = _byDevice[deviceId];
    if (before != null && before.name == deviceName && listEquals(before.radios, unique)) return;
    _byDevice[deviceId] = (name: deviceName, radios: List.unmodifiable(unique));
    notifyListeners();
  }

  void forgetPeer(String deviceId) {
    if (_byDevice.remove(deviceId) == null) return;
    notifyListeners();
  }
}
