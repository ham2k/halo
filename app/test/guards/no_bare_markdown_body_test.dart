// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Block markdown renders through HaloMarkdown (halo_widgets), never a bare
// MarkdownBody, and no style sheet is built outside it. HaloMarkdown is what
// carries the house table style and adds the emoji font after a call site's
// own style. A bare MarkdownBody renders every table as flutter_markdown's
// bordered 16x8 grid, and a call site's hand-built text style blanks every
// flag in it on web. Neither looks broken in a test window or in any screen
// the app ships — they show only when an extension's or a notice's markdown
// happens to carry a table or a flag — so this reads the SOURCE instead.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// flutter_markdown's block widgets: MarkdownBody and the scrolling Markdown.
final _render = RegExp(r'\b(?:Markdown|MarkdownBody)\s*\(');

/// Building a sheet: the constructor or any of its named factories. One built
/// outside HaloMarkdown has nowhere to go but a bare MarkdownBody, or a
/// `style:` that discards the house sheet it is handed.
final _sheet = RegExp(r'\bMarkdownStyleSheet(?:\.\w+)?\s*\(');

/// The one place either belongs.
const _home = 'halo_widgets/lib/src/halo_markdown.dart';

/// Line comments, which name these calls in prose.
final _comment = RegExp(r'//[^\n]*');

/// Every `.dart` file under the app's and every package's `lib/`, with its
/// line comments dropped and its line numbers intact.
Map<String, String> _sources() {
  final roots = [
    Directory('lib'),
    ...Directory('../packages').listSync().whereType<Directory>().map((d) => Directory('${d.path}/lib')).where((d) => d.existsSync()),
  ];
  // Loudly, not vacuously: a suite run from an unexpected cwd would
  // otherwise scan nothing and pass while enforcing nothing.
  if (!roots.first.existsSync()) {
    fail('expected lib/ to exist — run this suite from the app package (cwd: ${Directory.current.path})');
  }
  return {
    for (final root in roots)
      for (final file in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
        file.path.replaceAll(r'\', '/'): file.readAsStringSync().replaceAll(_comment, ''),
  };
}

int _lineOf(String source, int offset) => '\n'.allMatches(source.substring(0, offset)).length + 1;

void main() {
  test('block markdown renders through HaloMarkdown, never a bare MarkdownBody', () {
    final bare = <String>[];
    var atHome = 0;
    for (final MapEntry(key: path, value: source) in _sources().entries) {
      for (final match in [..._render.allMatches(source), ..._sheet.allMatches(source)]) {
        if (path.endsWith(_home)) {
          atHome++;
        } else {
          bare.add('$path:${_lineOf(source, match.start)}');
        }
      }
    }
    bare.sort();
    // The patterns still recognise what they exist to catch: HaloMarkdown is
    // built on exactly one MarkdownBody and one fromTheme.
    expect(atHome, 2, reason: 'expected one MarkdownBody and one MarkdownStyleSheet construction, inside HaloMarkdown in $_home');
    expect(
      bare,
      isEmpty,
      reason:
          'Render these with HaloMarkdown, customising through its `style:` callback\n'
          '(`style: (base) => base.copyWith(…)`) rather than building a sheet:\n'
          '${bare.map((p) => '  $p').join('\n')}',
    );
  });
}
