// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The transport for equipment that is plugged in, not connected to — an
// antenna or a CW key has no bytes to move. A real (model × transport) pair
// still exists for these categories, rather than a special-cased "typeless"
// node, so a category that later gains one (an antenna switch, an automatic
// keyer) is a registry addition, not a rearchitecture — and every
// [EquipmentType]-shaped assumption elsewhere in CatService keeps holding.

import '../transport.dart';

class NoneTransport extends EquipmentTransport {
  static const transportKey = 'none';

  const NoneTransport();

  @override
  String get key => transportKey;

  /// The equipment list never offers a Connect action for this category
  /// (see `_EquipmentTile`'s category branch), so nothing calls this.
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    throw UnsupportedError('$transportKey has nothing to connect to');
  }
}
