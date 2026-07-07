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
/// style with the prefix stripped. Falls back to [MdiIcons.puzzleOutline]
/// for a null/empty name or one that isn't in either table, so an extension
/// typo degrades to a placeholder glyph instead of crashing.
IconData resolveIconName(String? name) {
  if (name == null || name.isEmpty) return MdiIcons.puzzleOutline;

  if (name.startsWith('fa-')) {
    final codepoint = faSolidCodepoints[name.substring(3)];
    if (codepoint == null) return MdiIcons.puzzleOutline;
    return IconData(codepoint, fontFamily: 'FontAwesome6Solid');
  }

  final codepoint = mdiCodepoints[name];
  if (codepoint == null) return MdiIcons.puzzleOutline;
  return IconData(codepoint, fontFamily: 'MaterialDesignIcons');
}
