// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'image_clipboard_error.dart';

export 'image_clipboard_error.dart';

/// Copies the PNG [png] will be to the clipboard through the async
/// Clipboard API.
///
/// The clipboard item is made NOW, around a promise of the PNG, rather than
/// once the image is ready: Safari refuses a write that is not begun during
/// the user gesture that asked for it, and rendering the image takes longer
/// than the gesture lasts. Every current browser accepts a promise here.
///
/// Throws [ImageClipboardException] when the browser refuses the write — no
/// permission, a page without focus — which is an answer for the operator,
/// not a fault.
Future<void> copyImageToClipboard(Future<Uint8List> png) async {
  final blob = png.then((bytes) => web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png')));
  final items = JSObject()..setProperty('image/png'.toJS, blob.toJS);
  final write = web.window.navigator.clipboard.write(<web.ClipboardItem>[web.ClipboardItem(items)].toJS).toDart;
  try {
    await write;
  } catch (e) {
    // The PNG's own failure is this app's, and goes on as it came; anything
    // else is the browser saying no.
    await png;
    throw ImageClipboardException('$e');
  }
}
