// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Resolves an icon name coming from extension JSON (a plain string the
// extension author chose, not a compile-time Dart constant) into an actual
// IconData, so any extension can pick any icon from either set by name
// without a core-repo PR — matching app-polo's own convention exactly
// (react-native's H2kIcon.jsx: bare name -> Material Design Icons via
// react-native-paper's Icon; 'fa-' prefix -> FontAwesome6, solid style).
//
// The codepoint tables (icon_codepoints.g.dart) are generated from the same
// glyphmap JSON files app-polo's own icon rendering uses — see
// tool/generate_icon_codepoints.py.

import 'package:flutter/widgets.dart';

import 'icon_codepoints.g.dart';
import 'mdi_icons.dart';

/// Resolves an extension-provided icon name string to an [IconData].
/// A bare name (e.g. `'pine-tree'`) looks up Material Design Icons; a
/// `'fa-'`-prefixed name (e.g. `'fa-tree'`) looks up FontAwesome6's solid
/// style with the prefix stripped. Falls back to [MdiIcons.puzzle]
/// for a null/empty name or one that isn't in either table, so an extension
/// typo degrades to a placeholder glyph instead of crashing.
IconData resolveIconName(String? name) {
  if (name == null || name.isEmpty) return MdiIcons.puzzle;

  if (name.startsWith('fa-')) {
    final codepoint = faSolidCodepoints[name.substring(3)];
    if (codepoint == null) return MdiIcons.puzzle;
    // Runtime codepoint by design — extensions name icons as data
    // (docs/extensions/hooks.md), so the set can't be const/tree-shaken;
    // the app already builds with --no-tree-shake-icons.
    // ignore: non_const_argument_for_const_parameter
    return IconData(codepoint, fontFamily: 'FontAwesome6Solid');
  }

  final codepoint = mdiCodepoints[name];
  if (codepoint == null) return MdiIcons.puzzle;
  // ignore: non_const_argument_for_const_parameter
  return IconData(codepoint, fontFamily: 'MaterialDesignIcons');
}

/// Resolves an extension-provided accent color string (a `'#RRGGBB'` hex
/// value, e.g. `'#068541'`) to a [Color]. Returns null for a missing or
/// malformed value, so an extension typo just means no accent rather than
/// a crash.
final _hexColorPattern = RegExp(r'^#([0-9A-Fa-f]{6})$');

Color? resolveExtensionColor(String? hex) {
  if (hex == null) return null;
  final match = _hexColorPattern.firstMatch(hex);
  if (match == null) return null;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}
