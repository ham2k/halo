// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reopens the app in a standalone, chrome-less popup window (web only) — see
// DEVPOPUP. Same conditional-export shape as web_download.dart.

export 'web_popup_io.dart' if (dart.library.js_interop) 'web_popup_web.dart';
