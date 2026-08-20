// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Asks the browser to exempt this origin's storage from eviction (web only)
// — see `reportWebStorageHealth` in main.dart. Same conditional-export shape
// as web_download.dart.

export 'web_storage_persistence_stub.dart' if (dart.library.js_interop) 'web_storage_persistence_web.dart';
