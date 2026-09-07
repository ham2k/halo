// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Hands a generated export to the browser as a download (web only) — see
// ExportService.downloadFiles. Same conditional-export shape as
// build_reload.dart.

export 'web_download_io.dart' if (dart.library.js_interop) 'web_download_web.dart';
