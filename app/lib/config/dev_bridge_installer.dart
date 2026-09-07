// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Installs the `window.__halo` dev bridge on web (dev/preview only); a no-op
// stub on every other platform. Same conditional-export shape as
// web_preview_label.dart / mapbox_web_map_view.dart.

export 'dev_bridge_io.dart' if (dart.library.js_interop) 'dev_bridge_web.dart';
