// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Whether the browser page itself still holds focus. Web-only; a `false` stub
// everywhere else, which is what keeps `ViewFocusGuard` inert off web. Same
// conditional-export shape as config/dev_bridge_installer.dart.

export 'document_focus_io.dart' if (dart.library.js_interop) 'document_focus_web.dart';
