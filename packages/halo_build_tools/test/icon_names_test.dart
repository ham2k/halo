// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The traps these tests exist to catch:
//
// 1. An extension names its icons as plain strings (`icon: 'pine-tree'`,
//    or 'fa-tree' for FontAwesome6 solid), and the app resolves them at
//    runtime with a silent puzzle-piece fallback — correct for third-party
//    extensions updated dynamically, but for the extensions in this repo a
//    typo would sail through typecheck, tests, and review, and ship as a
//    puzzle glyph. This is the only place in-repo icon names get checked.
//
// 2. The app's icon language is MDI; the built-in MaterialIcons font ships
//    only as a safety net for framework-internal glyphs. `Icons.*` in our
//    own Dart renders a Material glyph in an MDI UI — core code must use
//    MdiIcons consts, and literal names in resolveIconName belong to
//    extension data only (a literal in core Dart is invisible to the
//    analyzer, so a typo degrades to a puzzle glyph at runtime).

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const _glyphmapDir = '../halo_widgets/tool/data';

Set<String> _names(String file) {
  final data = jsonDecode(File('$_glyphmapDir/$file').readAsStringSync());
  return (data['icons'] as Map<String, dynamic>).keys.toSet();
}

/// Walks [root] without descending into directories that can't hold
/// reviewable source (node_modules, dist, build) and skipping generated
/// Dart, which is data, not code.
Iterable<File> _sources(String root, String extension) sync* {
  const skipDirs = {'node_modules', 'dist', 'build'};
  final pending = [Directory(root)];
  while (pending.isNotEmpty) {
    for (final entity in pending.removeLast().listSync()) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (entity is Directory) {
        if (!skipDirs.contains(name)) pending.add(entity);
      } else if (entity is File && name.endsWith(extension) && !name.endsWith('.g$extension')) {
        yield entity;
      }
    }
  }
}

void main() {
  final mdi = _names('mdi_glyphmap.json');
  final fa = _names('fa6_solid_glyphmap.json');

  bool resolves(String name) => name.startsWith('fa-') ? fa.contains(name.substring(3)) : mdi.contains(name);

  test('every icon name in the bundled extensions resolves to a glyph', () {
    final iconField = RegExp('''icon\\??:\\s*['"]([^'"]+)['"]''');
    final bad = <String>[];
    var found = 0;
    for (final file in _sources('../../extensions', '.ts')) {
      for (final match in iconField.allMatches(file.readAsStringSync())) {
        found++;
        final name = match.group(1)!;
        if (!resolves(name)) bad.add('${file.path}: $name');
      }
    }
    expect(bad, isEmpty, reason: 'icon names with no glyph in the vendored fonts');
    // The regex going blind (a syntax change in how extensions declare
    // icons) must fail loudly, not pass on an empty scan.
    expect(found, greaterThan(20), reason: 'suspiciously few icon: literals found — extraction regex broken?');
  });

  test('core Dart uses MdiIcons consts, never Icons.* or literal icon names', () {
    // `//` starts a comment only when not preceded by `:` — a plain split
    // would truncate at the `://` of any URL in a string literal and hide a
    // violation later on the same line.
    final lineComment = RegExp(r'(?<!:)//');
    final materialIcons = RegExp(r'(?<![A-Za-z_])Icons\.[a-z]');
    // Whole-file match (literals can be wrapped onto the next line by
    // formatting) and both quote styles.
    final literalResolve = RegExp('''resolveIconName\\(\\s*['"]''');
    final roots = [
      '../../app/lib',
      '../halo_widgets/lib',
      '../halo_core/lib',
      '../halo_extension_host/lib',
      // Present only in the private checkout; the public mirror filters
      // app_dist out and must still pass this suite.
      if (Directory('../../app_dist/lib').existsSync()) '../../app_dist/lib',
    ];
    final bad = <String>[];
    for (final root in roots) {
      for (final file in _sources(root, '.dart')) {
        final content = file.readAsStringSync();
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final code = lines[i].split(lineComment).first;
          if (materialIcons.hasMatch(code)) {
            bad.add('${file.path}:${i + 1}: Icons.* — core code uses MdiIcons consts');
          }
        }
        if (literalResolve.hasMatch(content)) {
          bad.add('${file.path}: literal resolveIconName — use the MdiIcons const');
        }
      }
    }
    expect(bad, isEmpty);
  });
}
