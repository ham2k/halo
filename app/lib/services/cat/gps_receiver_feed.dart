// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The station's GPS receiver, handed to the location service
// (docs/design/cat.md § GPS receivers).

import '../location_service.dart';
import 'cat_service.dart';
import 'equipment.dart';

/// Keeps [location] told which receiver locates the station and what it last
/// said — or that none does, and the operating system answers again. Started by the boot: nothing else touches it.
class GpsReceiverFeed {
  GpsReceiverFeed({required this.cat, required this.location});

  final CatService cat;
  final LocationService location;

  void start() {
    cat.addListener(_update);
    _update();
  }

  void dispose() => cat.removeListener(_update);

  void _update() {
    final uuid = cat.gpsReceiver;
    final node = uuid == null ? null : cat.nodeFor(uuid);
    final state = node == null ? null : cat.stateFor(node.uuid);
    // Only a receiver connected and talking answers: one that is not, or that
    // has gone quiet behind a port still open, hands back to the operating
    // system rather than leave the station unlocated or serve its last fix.
    if (node == null || state == null || state.status != EquipmentStatus.connected || state.stale) {
      location.setReceiver();
      return;
    }
    location.setReceiver(name: cat.displayNameFor(node), reading: state.gps);
  }
}
