// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reloads the current page (web only) — see BuildFreshnessService. Same
// conditional-export shape as web_preview_label.dart.

export 'build_reload_stub.dart' if (dart.library.js_interop) 'build_reload_web.dart';
