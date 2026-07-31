// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web fallback: the browser has no raw sockets, so there is no CAT control
// on web at all and the Station Configuration section is hidden there. This
// throws rather than no-opping — reaching it means a platform gate is
// missing, and a silent no-op would present a radio as merely "not
// connected" forever.

import '../transport.dart';

class TcpTransport implements EquipmentTransport {
  const TcpTransport();

  static const transportKey = 'tcp';

  @override
  String get key => transportKey;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    throw UnsupportedError('CAT control needs raw sockets, which the web build does not have.');
  }
}
