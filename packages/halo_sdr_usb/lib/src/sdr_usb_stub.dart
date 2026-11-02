// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The web build: no USB receivers, and nothing to load.

import 'sdr_usb.dart';

/// Opens [kind]'s receiver with [serial], or the first found when blank.
Future<SdrUsbDevice> openSdrUsb(SdrUsbKind kind, {String serial = ''}) async =>
    throw const SdrUsbOpenException('USB receivers need the desktop app', unavailable: true);
