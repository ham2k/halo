// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A serial port — how the FT-891 and most other rigs expose CAT, via a
// built-in or external USB-to-serial bridge, a Chromium browser's Web
// Serial API, or (Safari/Firefox, no equivalent there) nothing at all.
// Same three-way conditional-export shape `web_download.dart` and friends
// use for io/web/stub.

export 'serial_transport_config.dart';
export 'serial_transport_unsupported.dart'
    if (dart.library.io) 'serial_transport_io.dart'
    if (dart.library.js_interop) 'serial_transport_web.dart';
