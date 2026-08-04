// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every padding, margin and gap comes from `Space` (halo_widgets'
// spacing.dart). The vocabulary only holds if new code joins it, and a bare
// `EdgeInsets.all(10)` is the obvious thing to reach for — so this reads the
// UI SOURCE the way no_hover_tooltips_test reads it for `tooltip:`: a
// reintroduced literal gets caught the day it lands, not at the next design
// pass.
//
// Scope matches the vocabulary's: arguments of an `EdgeInsets` constructor,
// and the `height`/`width` of a childless single-axis `SizedBox` — a gap.
// A `SizedBox` with a child, or with both axes, is sizing something rather
// than spacing it, and is none of this test's business.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Values that are geometry rather than spacing, and so deliberately stay
/// literal. Keyed by the file that may use them: a map camera's fit-bounds
/// inset has no business tracking a UI spacing rung, and a density pass that
/// "finished the migration" here would silently reframe the map.
// Not `const`: a const Set<double> is rejected — doubles have no primitive
// equality — and the values must stay doubles to compare against parsed ones.
final _allowed = <String, Set<double>>{
  // Fit-bounds padding handed to the map camera, in map viewport terms.
  'views/map/osm_map_view.dart': {48.0},
  // Reserves the QR code's footprint while the code is still resolving.
  'views/switch_accounts_dialog.dart': {48.0},
  // Sizes a progress spinner inside a fixed 48x48 box: 48 - 14*2 = 20pt.
  'views/station_panel.dart': {14.0},
  // Mirrors the HTML loading page's box model so the handoff from
  // web/index.html to the Flutter splash is a visual no-op.
  'views/splash_view.dart': {64.0, 32.0},
};

/// Every `.dart` file under the app's and the widget package's `lib/`.
List<File> _uiSources() {
  final roots = [Directory('lib'), Directory('../packages/halo_widgets/lib')];
  // Loudly, not vacuously: a suite run from an unexpected cwd would otherwise
  // scan nothing, find nothing, and pass while enforcing nothing at all.
  for (final root in roots) {
    if (!root.existsSync()) {
      fail('expected ${root.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
    }
  }
  return [
    for (final root in roots)
      ...root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart')),
  ];
}

/// The source with comments and string literals blanked out, so a number
/// inside either can't read as code. Keeps every offset, so line numbers in
/// the report still point at the real line.
String _blankNonCode(String source) {
  final out = source.split('');
  var i = 0;
  while (i < out.length) {
    final rest = source.substring(i);
    if (rest.startsWith('//')) {
      while (i < out.length && out[i] != '\n') {
        out[i] = ' ';
        i++;
      }
    } else if (rest.startsWith('/*')) {
      final end = source.indexOf('*/', i + 2);
      final stop = end == -1 ? out.length : end + 2;
      for (var j = i; j < stop; j++) {
        if (out[j] != '\n') out[j] = ' ';
      }
      i = stop;
    } else if (out[i] == "'" || out[i] == '"') {
      final quote = out[i];
      i++;
      while (i < out.length && out[i] != quote) {
        if (out[i] == r'\') {
          out[i] = ' ';
          i++;
        }
        if (i < out.length && out[i] != '\n') out[i] = ' ';
        i++;
      }
      i++;
    } else {
      i++;
    }
  }
  return out.join();
}

/// The top-level comma-separated arguments of the call whose `(` is at
/// [open], each with its absolute offset. Null when the call is unbalanced.
List<({String text, int offset})>? _args(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) {
        final inner = source.substring(open + 1, i);
        final out = <({String text, int offset})>[];
        var d = 0, start = 0;
        for (var j = 0; j < inner.length; j++) {
          final ch = inner[j];
          if (ch == '(' || ch == '[' || ch == '{') {
            d++;
          } else if (ch == ')' || ch == ']' || ch == '}') {
            d--;
          } else if (ch == ',' && d == 0) {
            out.add((text: inner.substring(start, j), offset: open + 1 + start));
            start = j + 1;
          }
        }
        if (inner.substring(start).trim().isNotEmpty) {
          out.add((text: inner.substring(start), offset: open + 1 + start));
        }
        return out;
      }
    }
  }
  return null;
}

/// The value half of `name: value`, or the whole argument when positional.
String _value(String arg) {
  final colon = arg.indexOf(':');
  return (colon == -1 ? arg : arg.substring(colon + 1)).trim();
}

String? _name(String arg) {
  final colon = arg.indexOf(':');
  return colon == -1 ? null : arg.substring(0, colon).trim();
}

// `MbxEdgeInsets` is the Mapbox SDK's own type in map viewport terms, not
// Flutter's — the lookbehind keeps it out.
final _edgeInsets = RegExp(r'(?<![A-Za-z0-9_])EdgeInsets(\.\w+)?\s*\(');
final _sizedBox = RegExp(r'(?<![A-Za-z0-9_])SizedBox\s*\(');
final _number = RegExp(r'^-?\d+(\.\d+)?$');

void main() {
  test('every padding, margin and gap comes from the Space vocabulary', () {
    final offenders = <String>[];

    for (final file in _uiSources()) {
      final raw = file.readAsStringSync();
      final source = _blankNonCode(raw);
      final allowed = _allowed.entries
              .firstWhere(
                (e) => file.path.replaceAll(r'\', '/').endsWith(e.key),
                orElse: () => const MapEntry('', <double>{}),
              )
              .value;

      int lineOf(int offset) => '\n'.allMatches(raw.substring(0, offset)).length + 1;

      void report(int offset, String what) {
        offenders.add('${file.path}:${lineOf(offset)}: $what');
      }

      for (final m in _edgeInsets.allMatches(source)) {
        for (final arg in _args(source, m.end - 1) ?? const []) {
          final value = _value(arg.text);
          if (!_number.hasMatch(value)) continue;
          final n = double.parse(value);
          if (n == 0 || allowed.contains(n)) continue;
          report(arg.offset, '${m.group(0)}…) takes a literal $value');
        }
      }

      for (final m in _sizedBox.allMatches(source)) {
        final args = _args(source, m.end - 1);
        if (args == null) continue;
        final names = args.map((a) => _name(a.text)).toList();
        // A box AROUND something, or one with both axes pinned, is sizing
        // rather than spacing — the vocabulary has nothing to say about it.
        if (names.contains('child')) continue;
        if (names.where((n) => n == 'height' || n == 'width').length != 1) continue;
        for (final arg in args) {
          final name = _name(arg.text);
          if (name != 'height' && name != 'width') continue;
          final value = _value(arg.text);
          if (!_number.hasMatch(value)) continue;
          final n = double.parse(value);
          if (n == 0 || allowed.contains(n)) continue;
          report(arg.offset, 'SizedBox($name: $value) is a gap');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Spacing comes from `Space` (packages/halo_widgets/lib/src/spacing.dart):\n'
          'xxs 2 / xs 4 / sm 6 / md 8 / lg 12 / xl 16 / xxl 24.\n'
          'Pick the rung whose ROLE fits; a value that fits no rung is usually a\n'
          'size (a row height, a control diameter, a camera inset), which belongs\n'
          'in a named constant of its own — and, if it lives in an EdgeInsets or a\n'
          'gap SizedBox, in this test\'s `_allowed` map with a reason.\n'
          'Found:\n${offenders.join('\n')}',
    );
  });

  // The scan above can only see numbers written where it looks. A measurement
  // that mirrors one of these gaps — TextPainter width math against a padded
  // widget — is the other half of the rule and the half that fails silently:
  // the layout still builds, it just reserves the wrong width. Nothing can
  // enforce that automatically, so it is stated in spacing.dart's doc and
  // pinned here by the one case that already went wrong.
  test('a measurement that mirrors a gap names the rung, not the number', () {
    final source = File('../packages/halo_widgets/lib/src/logging_controls.dart').readAsStringSync();
    expect(
      source,
      contains('+ Space.sm * 2; // _noticePill\'s padding'),
      reason: 'the notice-pill width measurement must track _noticePill\'s own padding constant',
    );
    expect(
      source,
      contains('+ Space.xs; // the SizedBox beside the glyph'),
      reason: 'the call-note glyph measurement must track the rendered gap\'s constant',
    );
  });
}
