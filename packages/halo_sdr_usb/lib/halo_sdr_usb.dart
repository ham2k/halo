// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// USB SDR receivers on the desktop — docs/design/cat.md § SDR receivers.

export 'src/sdr_usb.dart';
export 'src/sdr_usb_stub.dart' if (dart.library.io) 'src/sdr_usb_ffi.dart';
