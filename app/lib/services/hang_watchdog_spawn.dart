// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spawning the watchdog, which needs an isolate and a process to end — the
// web build has neither, so it gets a stub that declines. Same
// conditional-export shape as tcp_transport.dart.

export 'hang_watchdog_spawn_stub.dart' if (dart.library.io) 'hang_watchdog_spawn_io.dart';
