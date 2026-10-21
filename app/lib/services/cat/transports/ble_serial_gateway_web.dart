// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'ble_serial_gateway.dart';

/// No BLE on the web build, the peer transport's reason: keeping the plugin
/// off it is what enforces that. `BleSerialTransport` reports itself
/// unsupported, so no BLE variant is offered there.
BleSerialGateway? createBleSerialGateway() => null;
