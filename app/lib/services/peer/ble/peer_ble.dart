// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Same conditional-export shape as peer_beacon.dart. The web build gets the
// stub: BLE is deliberately out of scope there, and keeping the plugin off
// that build is what enforces it.

export 'peer_ble_stub.dart' if (dart.library.io) 'peer_ble_io.dart';
