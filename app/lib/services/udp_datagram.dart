// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

/// One datagram, and the address it came from as the network gave it: a
/// device on the local network, or this one.
typedef UdpDatagram = ({Uint8List data, String sender});
