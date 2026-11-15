// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Recovers HTTPS connections refused on Windows because the PC has not
// downloaded the server's root certificate yet. Windows-only and a no-op
// everywhere else. `dart:ffi` does not exist on web, so the io half is
// compiled out rather than merely guarded at runtime.

export 'src/recovery_stub.dart' if (dart.library.io) 'src/recovery.dart' show installWindowsTlsRootRecovery;
