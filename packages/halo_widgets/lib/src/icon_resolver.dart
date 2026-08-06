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
// This string lookup is for extension-supplied data ONLY. Core Dart code
// uses the MdiIcons consts (mdi_icons.g.dart) so a bad name is an analyzer
// error instead of a runtime placeholder.
//
// The codepoint tables (icon_codepoints.g.dart), the MdiIcons consts, and
// the bundled TTFs are all vendored/generated as a pair from the icon
// projects' own pinned npm packages by tool/update_icons.py, which proves
// the pairing by checking every table codepoint against the font's cmap.
// The name sets match app-polo's (@react-native-vector-icons repackages the
// same upstreams), keeping extension icon names portable between PoLo and
// HaLo.

import 'package:flutter/widgets.dart';

import 'icon_codepoints.g.dart';
import 'mdi_icons.g.dart';

/// Resolves an extension-provided icon name string to an [IconData].
/// A bare name (e.g. `'pine-tree'`) looks up Material Design Icons; a
/// `'fa-'`-prefixed name (e.g. `'fa-tree'`) looks up FontAwesome6's solid
/// style with the prefix stripped. Falls back to [fallback] — default
/// [MdiIcons.puzzle] — for a null/empty name or one that isn't in either
/// table, so an extension typo degrades to a placeholder glyph instead of
/// crashing. Call sites with a meaningful default pass it as [fallback]
/// rather than hand-writing a null-check ternary around this function.
///
/// The default stays a puzzle piece deliberately: extension chrome draws the
/// toy-brick family instead (the Extensions panel, the activities "Manage"
/// button, the placeholder while controls load). Keeping the two apart is
/// what lets a puzzle piece mean one specific thing — *this name did not
/// resolve* — rather than just "something to do with extensions".
IconData resolveIconName(String? name, {IconData fallback = MdiIcons.puzzle}) {
  if (name == null || name.isEmpty) return fallback;

  if (name.startsWith('fa-')) {
    final codepoint = faSolidCodepoints[name.substring(3)];
    if (codepoint == null) return fallback;
    // Runtime codepoint by design — extensions name icons as data
    // (docs/extensions/hooks.md), so the set can't be const/tree-shaken;
    // the app already builds with --no-tree-shake-icons.
    // ignore: non_const_argument_for_const_parameter
    return IconData(codepoint, fontFamily: 'FontAwesome6Solid');
  }

  final codepoint = mdiCodepoints[name];
  if (codepoint == null) return fallback;
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
