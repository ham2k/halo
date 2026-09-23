// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The listening socket behind each emulated CAT server. Same
// conditional-export shape as the CAT transports: the web build cannot
// listen, and its stub throws rather than pretending to.

export 'cat_server_socket_web.dart' if (dart.library.io) 'cat_server_socket_io.dart';
