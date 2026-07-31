// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A serial port — how the FT-891 and most other rigs expose CAT, via a
// built-in or external USB-to-serial bridge. Same conditional-export shape
// as tcp_transport.dart; the web build has no ports of any kind.

export 'serial_transport_stub.dart' if (dart.library.io) 'serial_transport_io.dart';
