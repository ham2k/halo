// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The WinSparkle settings the `auto_updater` plugin never exposes, called
// directly through the DLL it already bundles. Everything here is Windows-only
// and a no-op everywhere else; AutoUpdateService is the sole caller.
//
// Same two-way conditional-export shape as `tcp_transport.dart` and friends:
// `dart:ffi` does not exist on web, so the import itself has to be compiled
// out rather than merely guarded at runtime.

export 'winsparkle_config_stub.dart' if (dart.library.io) 'winsparkle_config_io.dart';
