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

/// The tile colour for an extension whose manifest names no accent — the same
/// neutral the catalog site falls back to (`web/components/ui.tsx`).
const kExtensionAccentFallback = Color(0xFF52525B);

/// How wide an extension's icon tile is where nothing says otherwise: a
/// ListTile leading box, which is what almost every one of them sits in.
const kExtensionIconTileSize = 40.0;

/// How solid an extension's icon is where the operator does not have it — 30%
/// transparent, on the unfilled treatment [ExtensionIconTile.filled] describes.
///
/// Lighter than the filled tile needs to be: a glyph on the row's own ground
/// is already the quieter of the two, and fading it as far as a solid tile
/// would need takes it out of the row altogether.
const kUninstalledIconOpacity = 0.7;

/// An extension's icon on its own accent colour — the tile the catalog site
/// draws for the same extension, so a programme is the same square of colour
/// wherever an operator meets it.
///
/// The glyph is white against every accent, with no contrast branch: the
/// manifest key is a brand colour, and the ones in use run from 0.12 to 0.56
/// relative luminance, so a second foreground would only ever be reached by a
/// colour nobody has picked.
class ExtensionIconTile extends StatelessWidget {
  /// The manifest's `icon`, resolved by [resolveIconName].
  final String? icon;

  /// The manifest's `accentColor` as `'#RRGGBB'`; anything else, including
  /// nothing, draws [kExtensionAccentFallback] rather than no tile — an
  /// extension without an accent is still an extension, and a bare glyph in a
  /// column of tiles reads as a row that failed to load.
  final String? accentColor;

  /// What to draw when [icon] names nothing either table knows — the caller's
  /// category glyph, where it has one.
  final IconData fallbackIcon;

  final double size;

  /// How solid the icon is. Below 1 for an extension the operator does not
  /// have: the row offers it rather than reporting it, and a full-strength
  /// icon beside the installed ones claims a place in the log that nothing
  /// has taken yet.
  final double opacity;

  /// Whether the accent is the TILE or the GLYPH.
  ///
  /// Filled is what the operator owns: a solid square of the programme's own
  /// colour with a white glyph on it, the same tile the catalog site draws.
  /// Unfilled is what is merely on offer — the glyph itself in the accent, on
  /// the row's own ground.
  ///
  /// One accent, two weights, and the difference is legible down a column
  /// without reading a word of it: a shape that is filled in is one you have.
  final bool filled;

  const ExtensionIconTile({
    super.key,
    this.icon,
    this.accentColor,
    this.fallbackIcon = MdiIcons.puzzle,
    this.size = kExtensionIconTileSize,
    this.opacity = 1,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = resolveExtensionColor(accentColor) ?? kExtensionAccentFallback;
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      // Same box either way, filled or not, so a column of rows keeps one
      // left edge whichever of the two any given row is.
      decoration: filled ? BoxDecoration(color: accent, borderRadius: BorderRadius.circular(size / 5)) : null,
      child: Icon(
        resolveIconName(icon, fallback: fallbackIcon),
        size: size * 0.6,
        // White reads on every accent the vocabulary allows; the glyph on its
        // own has nothing behind it, so it wears the accent itself.
        color: filled ? const Color(0xFFFFFFFF) : accent,
      ),
    );
    // The whole tile, not the glyph: fading a white glyph against a solid
    // accent leaves the tile as loud as an installed one.
    return opacity >= 1 ? tile : Opacity(opacity: opacity, child: tile);
  }
}
