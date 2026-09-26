// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Puts an image on the system clipboard — Flutter's own `Clipboard` carries
// only text. The browser's async clipboard on the web; everywhere else the
// `ham2k/image_clipboard` channel, answered by each runner's own code
// (MainFlutterWindow.swift, AppDelegate.swift, ImageClipboardChannel.kt,
// flutter_window.cpp, my_application.cc). Same conditional-export shape as
// web_download.dart.

export 'image_clipboard_io.dart' if (dart.library.js_interop) 'image_clipboard_web.dart';
