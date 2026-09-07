// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every flag in the app is a Unicode flag emoji resolved through the bundled
// NotoColorEmoji — there is no image fallback behind it. That makes the font
// FILE load-bearing, and its failure modes are all silent: a missing glyph
// throws nothing, FontLoader accepts bytes it cannot decode, and CanvasKit
// reaches for no OS font, so a wrong font paints nothing at all with no error
// and no log. `flagGlyph`'s own tests assert the style names the family, which
// stays true if this file is deleted, truncated, or swapped for a build with
// no flag glyphs.
//
// So these read the artifact. Static structure only — no rendering — because
// the test harness paints placeholder boxes for a color font regardless of
// what is loaded, and would report a false failure for a font that works.
//
// Lives in app/ because that is where the asset and its pubspec entry are:
// halo_widgets declares neither and structurally cannot check them.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// The sfnt table directory: tag -> (offset, length).
Map<String, (int, int)> _tables(Uint8List font) {
  final data = ByteData.sublistView(font);
  final numTables = data.getUint16(4);
  return {
    for (var i = 0; i < numTables; i++)
      String.fromCharCodes(font.sublist(12 + i * 16, 12 + i * 16 + 4)):
          (data.getUint32(12 + i * 16 + 8), data.getUint32(12 + i * 16 + 12)),
  };
}

/// Every code point the `cmap` format-12 subtable maps.
Set<int> _coverage(Uint8List font, int cmapOffset) {
  final data = ByteData.sublistView(font);
  final subtableCount = data.getUint16(cmapOffset + 2);
  int? format12;
  for (var i = 0; i < subtableCount; i++) {
    final offset = cmapOffset + data.getUint32(cmapOffset + 4 + i * 8 + 4);
    if (data.getUint16(offset) == 12) format12 = offset;
  }
  if (format12 == null) return const {};
  final covered = <int>{};
  final groups = data.getUint32(format12 + 12);
  for (var g = 0; g < groups; g++) {
    final row = format12 + 16 + g * 12;
    for (var c = data.getUint32(row); c <= data.getUint32(row + 4); c++) {
      covered.add(c);
    }
  }
  return covered;
}

void main() {
  final font = File(emojiFontAssetPath).readAsBytesSync();
  final tables = _tables(font);

  test('the asset is a real font, not a truncated or missing file', () {
    // A short read is the LFS/checkout failure mode; it decodes as garbage
    // rather than throwing anywhere in the app.
    expect(font.length, greaterThan(1000000));
    expect(tables.keys, containsAll(['cmap', 'head', 'maxp']));
  });

  test('it carries colour glyph data', () {
    // CBDT/CBLC is the bitmap format that renders on Flutter Windows; the
    // COLRv1 build that replaced it once renders nothing there at all, and
    // nothing else in the suite can tell the two apart.
    expect(tables.keys, containsAll(['CBDT', 'CBLC']));
  });

  test('it covers both flag encodings and can compose them', () {
    final covered = _coverage(font, tables['cmap']!.$1);

    // Regional-indicator pairs (🇺🇸) — all 26, or some entities lose their flag.
    for (var c = 0x1F1E6; c <= 0x1F1FF; c++) {
      expect(covered, contains(c), reason: 'regional indicator U+${c.toRadixString(16)}');
    }
    // The tag-sequence flags: England/Scotland/Wales/N. Ireland.
    expect(covered, contains(0x1F3F4));
    for (final c in [0xE0067, 0xE0062, 0xE0065, 0xE006E, 0xE0073, 0xE0063, 0xE007F]) {
      expect(covered, contains(c), reason: 'tag character U+${c.toRadixString(16)}');
    }
    // Coverage alone paints letter boxes: the pair only becomes one flag glyph
    // through a GSUB substitution, which a subsetting step can strip while
    // leaving every code point above in place.
    expect(tables.keys, contains('GSUB'));
  });

  test('pubspec declares the family the code asks for, at the path it lives on', () {
    // The two halves of this contract sit in different packages, and removing
    // an asset entry is exactly the edit that silently unbundles a font —
    // nothing else would fail.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: $emojiFontFamily'));
    expect(pubspec, contains('asset: $emojiFontAssetPath'));
  });
}
