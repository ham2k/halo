// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// The clipboard refused an image: another app holding it, a browser that
/// would not allow the write. An answer for the operator, not a fault.
class ImageClipboardException implements Exception {
  final String message;
  const ImageClipboardException(this.message);

  @override
  String toString() => message;
}
