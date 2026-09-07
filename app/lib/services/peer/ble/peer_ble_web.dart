// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'peer_ble_gateway.dart';

/// No BLE on this platform. `PeerService` treats a null gateway as "the
/// transport does not exist here" — the sub-switch does nothing, quietly.
PeerBleGateway? createPeerBleGateway() => null;
