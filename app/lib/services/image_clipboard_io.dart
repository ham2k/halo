// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'image_clipboard_error.dart';

export 'image_clipboard_error.dart';

const _channel = MethodChannel('ham2k/image_clipboard');

/// Copies the PNG [png] will be to the clipboard.
///
/// Takes a future so that a caller can start the copy inside the tap that
/// asked for it and finish rendering afterwards: on the web the clipboard
/// only accepts a write begun during a user gesture (see
/// image_clipboard_web.dart). Here the future is simply awaited.
///
/// Windows and Linux get the raw pixels as well, from which their runners
/// build the bitmap formats their clipboards expect — decoded here, and let
/// go of as soon as they are sent; the Apple and Android clipboards take the
/// PNG as it is.
///
/// Throws [ImageClipboardException] when the clipboard refuses — another app
/// holding it, say — which is an answer for the operator, not a fault.
Future<void> copyImageToClipboard(Future<Uint8List> png) async {
  final bytes = await png;
  final args = <String, Object>{'png': bytes};
  if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final image = frame.image;
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (rgba == null) throw StateError('the image has no pixels to copy');
      args['rgba'] = rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
      args['width'] = image.width;
      args['height'] = image.height;
    } finally {
      image.dispose();
    }
  }
  try {
    await _channel.invokeMethod<void>('copyImage', args);
  } on PlatformException catch (e) {
    // The runners' own word for a clipboard that said no; any other code
    // is this side asking wrongly, and a fault.
    if (e.code == 'copy_failed') throw ImageClipboardException(e.message ?? e.code);
    rethrow;
  }
}
