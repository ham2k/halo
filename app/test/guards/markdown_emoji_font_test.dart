// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every markdown render must reach `emojiFontFamily`, because a flag or
// pictograph inside markdown renders ONLY when the text style names it as a
// fallback. There is no second mechanism and no platform branch: the font is
// the only thing standing between an emoji and a blank.
//
// The failure is silent in the way that matters. Body text is Roboto, which
// resolves no emoji; on web CanvasKit shapes text itself and never reaches for
// an OS font, so the glyph is simply absent — no tofu, no error, no log — and
// on Windows the platform substitutes Segoe UI Emoji, which has no flag glyphs
// and draws the bare letters "US". Both look fine to whoever wrote the site.
//
// Nothing else catches it: `flutter analyze` sees a well-typed TextStyle,
// widget tests run on one platform with placeholder fonts and cannot observe
// an unresolved glyph, and scripts/test.sh builds no web or desktop target.
// Reading the diff does not catch it either — an absent named argument is what
// there is to notice.
//
// Per RENDER, not per file. Two shapes make a per-file check a rubber stamp,
// and both are live: a file with two renders where only one is styled (the
// other free-rides on its neighbour), and `withEmojiFallback(sheet).copyWith(
// p: …)` — wrapped, then overridden — which drops the paragraph's fallback and
// reads as compliant. The scan is paren-balanced from each render so that
// "reaches the font" means this call does, and the emoji token has to sit
// OUTSIDE any later copyWith rather than merely somewhere in the argument.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rendering markdown, as opposed to defining how it renders. `Markdown(` is
/// flutter_markdown's scrolling widget — unused today and the likeliest thing
/// a long notes pane reaches for.
final _renders = RegExp(r'\b(?:Markdown|MarkdownBody|InlineMarkdownText|inlineMarkdownSpans)\(');

/// Reaching the bundled emoji font, directly or through the shared helper.
final _emojiAware = RegExp(r'\b(?:emojiFontFamily|withEmojiFallback)\b');

/// A style argument naming an identifier defined elsewhere in the file, e.g.
/// `styleSheet: notesStyleSheet` or `style: _subtitleStyle(theme)` — the
/// render is then only as covered as that definition is.
final _styleArg = RegExp(r'\b(?:styleSheet|style|codeStyle|linkStyle)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)');

/// Files that render markdown and legitimately do NOT name the font, each with
/// the reason. Empty of call sites on purpose: every renderer of user-,
/// extension- or notes-authored markdown needs the font.
const _exempt = <String, String>{
  // Defines InlineMarkdownText and inlineMarkdownSpans rather than calling
  // them; the style it renders with is the caller's.
  '../packages/halo_widgets/lib/src/inline_markdown.dart': 'the implementation, not a call site',
};

List<File> _sources() {
  // Every package, not just the one that renders markdown today: a renderer
  // added under another package's lib/ would be scanned by nothing, and that
  // gap is silent where a missing root is loud.
  final roots = [
    Directory('lib'),
    ...Directory('../packages').listSync().whereType<Directory>().map((d) => Directory('${d.path}/lib')).where((d) => d.existsSync()),
  ];
  if (!roots.first.existsSync()) {
    fail('expected lib/ to exist — run this suite from the app package (cwd: ${Directory.current.path})');
  }
  return [for (final root in roots) ...root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))];
}

/// [source] with every `//` comment body blanked, so prose that discusses the
/// font satisfies nothing. Length is preserved: the offsets below index back
/// into the original to report a line number.
String _withoutComments(String source) {
  final out = source.split('');
  for (var i = 0; i < out.length - 1; i++) {
    if (out[i] == '/' && out[i + 1] == '/') {
      while (i < out.length && out[i] != '\n') {
        out[i++] = ' ';
      }
    }
  }
  return out.join();
}

/// The block enclosing [index] — the innermost `{ … }` around it — so a style
/// passed by name is resolved against the function that built it. Names are
/// not unique across a file: several widgets keep a local `textStyle`, and
/// resolving one against another's definition is how this check would quietly
/// judge the wrong code.
String _enclosingBlock(String source, int index) {
  var depth = 0;
  var open = -1;
  for (var i = index; i >= 0; i--) {
    if (source[i] == '}') depth++;
    if (source[i] == '{') {
      if (depth == 0) {
        open = i;
        break;
      }
      depth--;
    }
  }
  if (open < 0) return source;
  depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return source.substring(open);
}

/// The parameter list of the function whose body is [block] — the text between
/// the parentheses immediately before it.
String _signatureOf(String source, String block) {
  final start = source.indexOf(block);
  if (start <= 0) return '';
  final close = source.lastIndexOf(')', start);
  if (close < 0) return '';
  var depth = 0;
  for (var i = close; i >= 0; i--) {
    if (source[i] == ')') depth++;
    if (source[i] == '(') {
      depth--;
      if (depth == 0) return source.substring(i, close + 1);
    }
  }
  return '';
}

/// The expression a name is bound to — `final x = <expr>;`, `T f(…) => <expr>;`
/// or a block body — so a style passed by name is judged by its definition.
/// Empty when the name is not bound in [scope], which reads as uncovered
/// rather than as covered by something unseen.
String _definitionOf(String scope, String name) {
  final binding = RegExp('\\b$name\\b\\s*(?:\\([^)]*\\))?\\s*(?:=>|=|\\{)').firstMatch(scope);
  if (binding == null) return '';
  // A block body runs to its own closing brace; an expression body ends at the
  // first `;` outside brackets. Terminating a block on `;` would stop at its
  // first statement and miss everything the function actually returns.
  final isBlock = scope[binding.end - 1] == '{';
  var depth = isBlock ? 1 : 0;
  for (var i = binding.end; i < scope.length; i++) {
    final c = scope[i];
    if (c == '(' || c == '{' || c == '[') depth++;
    if (c == ')' || c == '}' || c == ']') {
      depth--;
      if (depth == 0 && isBlock) return scope.substring(binding.end, i);
      if (depth < 0) return scope.substring(binding.end, i);
    }
    if (c == ';' && depth == 0 && !isBlock) return scope.substring(binding.end, i);
  }
  return scope.substring(binding.end);
}

/// The argument list of the call starting at [open], paren-balanced.
String _argsAt(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  return source.substring(open);
}

void main() {
  test('every markdown render reaches the bundled emoji font', () {
    final offenders = <String>[];
    final exemptSeen = <String>{};

    for (final file in _sources()) {
      final path = file.path.replaceAll(r'\', '/');
      final source = _withoutComments(file.readAsStringSync());
      final renders = _renders.allMatches(source).toList();
      if (renders.isEmpty) continue;
      if (_exempt.containsKey(path)) {
        exemptSeen.add(path);
        continue;
      }

      for (final render in renders) {
        final args = _argsAt(source, render.end - 1);
        if (_emojiAware.hasMatch(args)) continue;
        // A style passed by name is covered when its definition is — the usual
        // shape when one stylesheet serves two renders in a file.
        final named = _styleArg.allMatches(args).map((m) => m.group(1)!);
        // The enclosing function first, then file scope for a top-level helper
        // like a shared stylesheet builder. Two hops, because the usual shape
        // is `final s = _buildStyle(theme)` — the name binds to a call whose
        // own definition is what names the font.
        final block = _enclosingBlock(source, render.start);
        String bound(String name) {
          final local = _definitionOf(block, name);
          return local.isEmpty ? _definitionOf(source, name) : local;
        }

        bool covered(String name, {int hops = 2}) {
          final definition = bound(name);
          if (_emojiAware.hasMatch(definition)) return true;
          if (hops == 0 || definition.isEmpty) return false;
          return RegExp(r'\b([A-Za-z_][A-Za-z0-9_]*)\s*\(').allMatches(definition).any((m) => covered(m.group(1)!, hops: hops - 1));
        }

        // `inlineMarkdownSpans` builds spans; it resolves no glyph itself. The
        // style that does is the one the Text or TextPainter consuming them is
        // given — so a builder handed a TextStyle is covered by whoever calls
        // it, which for a measurement helper is the paint site it must match.
        if (render.group(0)!.startsWith('inlineMarkdownSpans')) {
          final block = _enclosingBlock(source, render.start);
          if (_emojiAware.hasMatch(block) || _signatureOf(source, block).contains('TextStyle')) continue;
        }

        // A style the function is HANDED cannot name a font it was not given:
        // its coverage belongs to the caller, and to the paint site that a
        // measurement helper is paired with.
        final signature = _signatureOf(source, block);
        if (named.any((n) => RegExp('\\b$n\\b').hasMatch(signature))) continue;

        // EVERY style that names a font family has to carry the fallback, not
        // just one of them. A span style naming a family replaces the
        // paragraph's whole family list (ParagraphBuilder.pushStyle builds it
        // from that style alone), so a covered `style:` does nothing for an
        // uncovered `codeStyle:` beside it — the shape that hid an unresolved
        // emoji inside backticks.
        final namesFamily = named.where((n) => bound(n).contains('fontFamily') || covered(n, hops: 2));
        if (namesFamily.isNotEmpty && !namesFamily.every((n) => covered(n))) {
          final line = '\n'.allMatches(source.substring(0, render.start)).length + 1;
          offenders.add('$path:$line');
          continue;
        }
        if (named.any((n) => covered(n))) continue;
        final line = '\n'.allMatches(source.substring(0, render.start)).length + 1;
        offenders.add('$path:$line');
      }
    }
    offenders.sort();

    expect(
      offenders,
      isEmpty,
      reason:
          'These markdown renders do not reach the emoji font, so a flag or pictograph in\n'
          'that markdown is invisible on web and shows as letters on Windows:\n'
          '${offenders.map((p) => '  $p').join('\n')}\n'
          '\n'
          'Wrap the stylesheet in withEmojiFallback() (halo_widgets/theme.dart), OUTERMOST —\n'
          'a copyWith applied after the wrap drops the fallback again. It covers every style\n'
          'that can hold running text; copyWith(p:) alone reaches list items and code blocks\n'
          'but never a heading, blockquote or table cell. For a bespoke TextStyle, name\n'
          'emojiFontFamily in its fontFamilyFallback.\n'
          '\n'
          'If the file genuinely renders only static UI copy with no emoji path, add it to\n'
          '_exempt with the reason.',
    );

    // The wrapper has to be OUTERMOST. `withEmojiFallback(sheet).copyWith(p: …)`
    // rebuilds the paragraph style from one that never had the fallback, so the
    // flag goes back to invisible while every check above still reads the call
    // as covered — the one regression this whole test would otherwise greenlight.
    final overridden = <String>[];
    for (final file in _sources()) {
      final path = file.path.replaceAll(r'\', '/');
      final source = _withoutComments(file.readAsStringSync());
      for (final wrap in RegExp(r'\bwithEmojiFallback\s*\(').allMatches(source)) {
        final open = wrap.end - 1;
        var depth = 0;
        for (var i = open; i < source.length; i++) {
          if (source[i] == '(') depth++;
          if (source[i] == ')') {
            depth--;
            if (depth == 0) {
              if (source.substring(i + 1).trimLeft().startsWith('.copyWith')) {
                overridden.add('$path:${'\n'.allMatches(source.substring(0, wrap.start)).length + 1}');
              }
              break;
            }
          }
        }
      }
    }
    expect(
      overridden,
      isEmpty,
      reason:
          'withEmojiFallback() is overridden by a later copyWith here, which drops the\n'
          'fallback it just added:\n'
          '${overridden.map((p) => '  $p').join('\n')}\n'
          '\n'
          'Move the copyWith inside: withEmojiFallback(sheet.copyWith(…)).',
    );

    // An exemption for a file that no longer renders markdown is stale, and a
    // stale exemption is how one silently starts covering something else.
    expect(_exempt.keys.toSet().difference(exemptSeen), isEmpty, reason: 'These files are exempted but no longer render markdown — drop them from _exempt.');
  });
}
