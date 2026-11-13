// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:path/path.dart' as p;

/// The name an export lands under, from whatever a hook offered. Only the
/// last path segment survives (the Windows style splits on either
/// separator; a hook runs on every platform and may name a path in
/// another's); a bare root is no name at all; control and format
/// characters go (a right-to-left override would show one extension and
/// save another), as do the characters Windows refuses in a name and the
/// trailing dots and spaces it drops; leading dots go too, so an export is
/// never a hidden file (`.bashrc`, `.zshrc` in the home directory); a Windows device name (`NUL.adi`
/// writes to the device and nothing lands) or a name with nothing left is
/// `export.txt`; and a name longer than a filesystem holds is cut to fit,
/// extension kept. Every writer joins this onto the directory the operator
/// chose or the share cache, so an extension's filename can name a file
/// there and nowhere else.
String safeExportFilename(String? offered) {
  var name = p.windows.basename(offered ?? '');
  // `basename` hands a root back as itself: `/`, `C:\`, `\\server\share`.
  if (name.contains('/') || name.contains('\\')) return 'export.txt';
  name = name.replaceAll(_invisibleOrRefused, '').replaceAll(_leadingDotsAndSpaces, '').trim().replaceAll(_trailingDotsAndSpaces, '');
  if (name.isEmpty || _windowsDeviceName.hasMatch(name)) return 'export.txt';
  return _fitting(name);
}

/// Control characters (C0, C1 and DEL), format characters, the line and
/// paragraph separators, and the characters Windows refuses in a name.
final _invisibleOrRefused = RegExp(r'[\p{Cc}\p{Cf}\u2028\u2029<>:"|?*]', unicode: true);
final _leadingDotsAndSpaces = RegExp(r'^[. ]+');
final _trailingDotsAndSpaces = RegExp(r'[. ]+$');

/// The names Windows keeps for devices, with or without an extension:
/// COM and LPT 0-9 and their superscript forms, CON, PRN, AUX, NUL.
final _windowsDeviceName = RegExp(r'^(con|prn|aux|nul|com[0-9¹²³]|lpt[0-9¹²³])(\..*)?$', caseSensitive: false);

/// [name] within the 255 bytes a filename may hold on every platform,
/// keeping its extension and whole characters.
String _fitting(String name) {
  const maxBytes = 255;
  if (utf8.encode(name).length <= maxBytes) return name;
  final ext = p.extension(name);
  final extBytes = utf8.encode(ext).length;
  final runes = name.substring(0, name.length - ext.length).runes.toList();
  while (runes.isNotEmpty && utf8.encode(String.fromCharCodes(runes)).length + extBytes > maxBytes) {
    runes.removeLast();
  }
  return String.fromCharCodes(runes) + ext;
}
