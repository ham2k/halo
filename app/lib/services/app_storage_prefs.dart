// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Redirecting the shared_preferences file, split off from app_storage.dart
// because the native implementation reaches for `package:win32` (through
// path_provider_windows), which doesn't compile for web.

export 'app_storage_prefs_stub.dart' if (dart.library.io) 'app_storage_prefs_io.dart';
