// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'scene_model.dart';

/// The most an image's `data:` URI holds: [sceneImageMaxBytes] of image, in base64.
const sceneImageMaxChars = sceneImageMaxBytes * 4 ~/ 3 + 64;

/// The most an image may be, however it comes: as markdown's images.
const sceneImageMaxBytes = 4 * 1024 * 1024;

/// A scene image's source, checked by its spelling when the scene arrives:
/// a raster `data:` URI, a path into the extension's own `assets/`, or an
/// `https://` address — whose host the extension must declare, which is the
/// loader's to judge (scene_images.dart), since only it knows the extension.
String sceneImage(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Invalid scene image: $key');
  if (value.length > sceneImageMaxChars) throw _overLength('image', value.length, sceneImageMaxChars);
  if (value.startsWith('data:')) {
    if (!RegExp(r'^data:image/(png|jpeg|gif|webp);base64,', caseSensitive: false).hasMatch(value)) {
      throw FormatException('A scene image is a PNG, JPEG, GIF or WebP, in base64: $key');
    }
    return value;
  }
  final uri = Uri.tryParse(value);
  if (uri == null) throw FormatException('Invalid scene image: $key');
  if (uri.scheme == 'https' && uri.host.isNotEmpty) return value;
  // Only a bare path can name the bundle: `assets/map.png`, never `file:`, `//host/…` or `http:`.
  if (uri.hasScheme || uri.hasAuthority || !uri.path.startsWith('assets/') || uri.path.split('/').contains('..')) {
    throw FormatException('A scene image is a data: URI, one of the extension\'s own assets/ files, or an https address: $key');
  }
  if (!RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(uri.path)) {
    throw FormatException('A scene image is a PNG, JPEG, GIF or WebP: $key');
  }
  return value;
}
