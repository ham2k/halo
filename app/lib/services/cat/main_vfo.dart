// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import '../peer/peer_station_radios.dart';

/// What drives `vfoA` — one slot, because there is one VFO.
///
/// A sum rather than two nullable fields: the two cases are mutually
/// exclusive, and a type that cannot hold both is what keeps every writer,
/// and every hand-edited or newer-build blob, from pointing `vfoA` at two
/// things at once.
///
/// [CatService.radio1] holds one of these, or null for None — `radio1` being
/// data-model.md's name for the transceiver whose VFO is `vfoA`, which this
/// makes true of a peer's rig as much as of one plugged in here.
sealed class MainVfo {
  const MainVfo();
}

/// A transceiver in this device's own equipment list.
class LocalRadio extends MainVfo {
  final String uuid;

  const LocalRadio(this.uuid);

  @override
  bool operator ==(Object other) => other is LocalRadio && other.uuid == uuid;

  @override
  int get hashCode => uuid.hashCode;
}

/// A radio on another device, reached over a peer link (HALO-416).
class PeerRadio extends MainVfo {
  final PeerRadioSelection selection;

  const PeerRadio(this.selection);

  @override
  bool operator ==(Object other) => other is PeerRadio && other.selection == selection;

  @override
  int get hashCode => selection.hashCode;
}
