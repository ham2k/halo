// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The agent link's listener: loopback TCP, one JSON frame per line
// (docs/design/agent-link.md). A browser cannot listen, so the web build
// gets a stub that says so.

export 'agent_link_socket_web.dart' if (dart.library.io) 'agent_link_socket_io.dart';
