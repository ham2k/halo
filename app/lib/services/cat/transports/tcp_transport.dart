// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A plain TCP byte stream — FlexRadio's SmartSDR API, a Hamlib `rigctld`
// bridge, anything else that listens on a socket. Same conditional-export
// shape as web_download.dart: the web build has no sockets at all, so it
// gets a stub that throws.

export 'tcp_transport_web.dart' if (dart.library.io) 'tcp_transport_io.dart';
