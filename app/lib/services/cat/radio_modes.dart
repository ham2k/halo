// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the Station dialog's Radio Mode picker offers. Beside CatService
// rather than in it: it needs nothing but the service's public face.

import 'cat_service.dart';
import 'equipment.dart';

extension RadioModes on CatService {
  /// The modes radio1's driver can set — while it is this station's own and
  /// connected, and empty otherwise (a peer's radio is set on its device).
  /// Paired with [CatService.setRadio1Mode].
  List<String> get radio1SettableModes {
    final uuid = localRadio1;
    final node = uuid == null ? null : nodeFor(uuid);
    final type = node == null ? null : typeFor(node);
    if (type == null || stateFor(node!.uuid).status != EquipmentStatus.connected) return const [];
    // Less CW-R: the app reads a radio's CW-R report as CW (_applyReading), so
    // a CW-R pick would show as CW and read as refused.
    return [
      for (final mode in type.driver.settableModes(type.driverConfig(node.config)))
        if (mode != 'CW-R') mode,
    ];
  }
}
