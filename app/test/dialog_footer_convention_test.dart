// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The dialog footer convention of docs/design/user-interface.md §Dialogs,
// enforced against the SOURCE the way spacing_vocabulary_test and
// no_hover_tooltips_test enforce theirs.
//
// It needs enforcing because the previous convention was violated silently:
// two dialogs passed Cancel through `actions:` instead of the `cancel:` slot,
// which renders identically enough to pass review and puts the button flush
// against the primary with none of `haloDialogCancelGap` between them. The
// design doc said so and nothing checked.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Labels that name a way OUT of a dialog. Any of these inside `actions:`
/// means a dismissal is being packed in with the confirm action.
const _dismissalTokens = [
  'common.cancel',
  'common.done',
  'common.close',
  'common.dismiss',
  'labels.cancel',
  // FormRenderer's own dialogs name their verbs through FormRendererLabels,
  // not the app's i18n — two of them shipped a Done inside `actions:` while
  // this list only knew `labels.cancel`.
  'labels.done',
  'labels.close',
  'labels.dismiss',
  "'Cancel'",
  "'Done'",
  "'Close'",
  "'Dismiss'",
];

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

/// The source with `//` and `/* */` comments blanked, keeping every offset so
/// reported line numbers still point at the real line. String literals are
/// deliberately LEFT INTACT — a hardcoded `'Cancel'` is exactly what this
/// looks for — but they must still be RECOGNISED, because a `'https://…'`
/// otherwise reads as a line comment and blanks the rest of the line,
/// brackets included. That silently unbalances the enclosing call and drops
/// it from the scan: before this walked strings, the expired-build dialog —
/// one of the two the convention was introduced to fix — was the one file in
/// the app never checked.
String _blankComments(String source) {
  final out = source.split('');
  var i = 0;
  while (i < out.length) {
    if (source.startsWith('//', i)) {
      while (i < out.length && out[i] != '\n') {
        out[i] = ' ';
        i++;
      }
    } else if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      final stop = end == -1 ? out.length : end + 2;
      for (var j = i; j < stop; j++) {
        if (out[j] != '\n') out[j] = ' ';
      }
      i = stop;
    } else if (out[i] == "'" || out[i] == '"') {
      // Step OVER the literal, leaving it readable, so its contents can never
      // be mistaken for a comment or a bracket.
      final quote = out[i];
      i++;
      while (i < out.length && out[i] != quote) {
        if (out[i] == r'\') i++;
        if (out[i] == '\n') break;
        i++;
      }
      i++;
    } else {
      i++;
    }
  }
  return out.join();
}

/// The index just past the bracket matching the one at [open], or -1.
int _matchingBracket(String s, int open) {
  final close = s[open] == '(' ? ')' : ']';
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    final c = s[i];
    if (c == '(' || c == '[') depth++;
    if (c == ')' || c == ']') {
      depth--;
      if (depth == 0 && c == close) return i;
    }
  }
  return -1;
}

int _lineOf(String source, int offset) => '\n'.allMatches(source.substring(0, offset)).length + 1;

void main() {
  test('no dismissal button is passed through `actions:` instead of the `cancel:` slot', () {
    // Scoped to the two footer APIs rather than every `actions:` in the
    // codebase: an AppBar takes an `actions:` list too, and a close button
    // genuinely belongs in one of those.
    final footerCalls = RegExp(r'\b(HaloDialog|haloDialogFooterRow)\s*\(');
    final offenders = <String>[];

    for (final file in _uiSources()) {
      final source = _blankComments(file.readAsStringSync());
      for (final call in footerCalls.allMatches(source)) {
        final open = call.end - 1;
        final close = _matchingBracket(source, open);
        // Loudly, never `continue`: an unbalanced call is a call this scan
        // did not check, and a scanner that skips in silence reports success
        // for exactly the files it failed to read.
        if (close == -1) {
          fail('${file.path}:${_lineOf(source, open)} — could not balance this footer call, so it went '
              'unchecked. Fix the parser rather than leaving a dialog unscanned.');
        }
        final body = source.substring(open, close);

        // The `actions:` belonging to THIS call, not one nested in a child
        // widget inside it: depth 1 relative to the call's own parens.
        var depth = 0;
        for (var i = 0; i < body.length; i++) {
          final c = body[i];
          if (c == '(' || c == '[') depth++;
          if (c == ')' || c == ']') depth--;
          if (depth == 1 && body.startsWith('actions:', i)) {
            // The `[` must be THIS argument's, not the next list anywhere
            // later in the call: `actions: someVar` has no literal to scan.
            final afterKey = body.substring(i + 'actions:'.length);
            final lead = afterKey.length - afterKey.trimLeft().length;
            if (!afterKey.trimLeft().startsWith('[')) {
              i += 'actions:'.length;
              continue;
            }
            final listOpen = i + 'actions:'.length + lead;
            final listClose = _matchingBracket(body, listOpen);
            if (listClose == -1) break;
            final list = body.substring(listOpen, listClose);
            for (final token in _dismissalTokens) {
              if (list.contains(token)) {
                offenders.add('${file.path}:${_lineOf(source, open + listOpen)} — $token in actions:');
              }
            }
            i = listClose;
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A dialog\'s way out belongs in the `cancel:` slot, not in `actions:`. Only that slot gets\n'
          'haloDialogCancelGap between it and the primary action — passed through `actions:` it lands\n'
          'flush against Save. See docs/design/user-interface.md §Dialogs.\n\n${offenders.join('\n')}',
    );
  });

  test('no dialog footer says Close or Apply', () {
    // The other half of the rule, and the half a placement check misses: a
    // `Close` sitting correctly in the `cancel:` slot is well-placed and still
    // wrong. Both words are retired from footers — Done covers the dialog that
    // has nothing to commit, and Apply promises work the dialog already did.
    //
    // `common.close` itself stays: five call sites pass it as `closeLabel`,
    // the accessible name of a Modal Pane header's icon button, which is not a
    // footer button. So this looks for the word inside a footer call rather
    // than for the key anywhere.
    final footerCalls = RegExp(r'\b(HaloDialog|haloDialogFooterRow)\s*\(');
    const banned = ['common.close', 'common.apply', "'Close'", "'Apply'"];
    final offenders = <String>[];

    for (final file in _uiSources()) {
      final source = _blankComments(file.readAsStringSync());
      for (final call in footerCalls.allMatches(source)) {
        final open = call.end - 1;
        final close = _matchingBracket(source, open);
        if (close == -1) {
          fail('${file.path}:${_lineOf(source, open)} — could not balance this footer call, so it went '
              'unchecked. Fix the parser rather than leaving a dialog unscanned.');
        }
        final body = source.substring(open, close);
        for (final token in banned) {
          if (body.contains(token)) {
            offenders.add('${file.path}:${_lineOf(source, open)} — $token in a dialog footer');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A dialog with nothing to commit says Done; one that commits says Save, or the specific\n'
          'verb for what happens. See docs/design/user-interface.md §Dialogs.\n\n${offenders.join('\n')}',
    );
  });

  test('no dialog bypasses HaloDialog for a raw AlertDialog', () {
    // HaloDialog is the app's one dialog shell — banded header and footer,
    // shared size box, the footer convention above. A raw AlertDialog gets
    // Material's chrome instead and silently opts out of all three.
    final offenders = <String>[];
    for (final file in _uiSources()) {
      final source = _blankComments(file.readAsStringSync());
      for (final match in RegExp(r'\bAlertDialog\s*\(').allMatches(source)) {
        offenders.add('${file.path}:${_lineOf(source, match.start)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use HaloDialog (with showHaloDialog) instead of AlertDialog.\n\n${offenders.join('\n')}',
    );
  });
}
