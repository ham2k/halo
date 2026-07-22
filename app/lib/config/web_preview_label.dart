// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Auto DEV_LABEL for web preview deployments (ham2k/app-halo-dist#234): web
// builds read the preview name from window.location; every other platform gets
// the '' stub. Same conditional-export shape as mapbox_web_map_view.dart.

export 'web_preview_label_stub.dart' if (dart.library.js_interop) 'web_preview_label_web.dart';
