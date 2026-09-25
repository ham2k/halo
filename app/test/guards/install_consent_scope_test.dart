// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The consent screen is the whole of what stands between a bundle from anyone
// and code the app will run, and `askConsent: false` is the one way past it.
// It exists for Update all — one press, confirmed on a screen naming every
// extension it will take and what each becomes, whether it came from the
// Extensions panel or the update notice — and for nothing else.
//
// A guard rather than a widget test because what matters is not that one
// caller behaves, but that no OTHER caller appears: a second opt-out added in
// good faith six months from now is exactly the change nobody would think to
// question, and it would not fail a single test about dialogs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where the exception is allowed to be, and the method that may hold it.
const _allowedFile = 'lib/views/extension_install_flow.dart';
const _allowedMethod = 'updateAllFromCatalog';

/// The screen that stands in for the skipped consents, which the allowed
/// method must show before it skips them.
const _confirmation = '_confirmUpdateAll';

/// The half-open range of [method]'s body, by brace matching from its
/// declaration — null when the file does not declare it.
(int, int)? _bodyOf(String source, String method) {
  final declared = RegExp('Future<[^>]*>\\s+$method\\s*\\(').firstMatch(source);
  if (declared == null) return null;
  // Past the parameter list first: its named parameters open a brace of
  // their own, which is not the body.
  var parens = 1;
  var close = declared.end;
  for (; close < source.length && parens > 0; close++) {
    if (source[close] == '(') parens++;
    if (source[close] == ')') parens--;
  }
  final open = source.indexOf('{', close);
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return (open, i);
    }
  }
  return null;
}

int _lineOf(String source, int offset) => '\n'.allMatches(source.substring(0, offset)).length + 1;

void main() {
  test('only the bulk update may skip the install consent screen', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      if (!source.contains('askConsent: false')) continue;
      if (!file.path.endsWith(_allowedFile.substring('lib/'.length))) {
        offenders.add('${file.path} — skips consent outside $_allowedFile');
        continue;
      }
      // Inside the allowed METHOD, established by matching its braces rather
      // than by where its name last appears. A position heuristic is satisfied
      // by a call site above it, so anything below that looked like it was
      // inside.
      final body = _bodyOf(source, _allowedMethod);
      // And confirmed inside it, ahead of the skip. With the confirmation left
      // to its callers, the method itself installs unseen code for whoever
      // calls it next — and a literal-position check stays green over that.
      final confirmedAt = body == null ? -1 : source.indexOf('$_confirmation(', body.$1);
      for (var at = source.indexOf('askConsent: false'); at >= 0; at = source.indexOf('askConsent: false', at + 1)) {
        if (body == null || at < body.$1 || at > body.$2) {
          offenders.add('${file.path}:${_lineOf(source, at)} — skips consent outside $_allowedMethod');
        } else if (confirmedAt < 0 || confirmedAt > at) {
          offenders.add('${file.path}:${_lineOf(source, at)} — skips consent before $_allowedMethod asks $_confirmation');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Consent is asked for every install and for every update taken one at a time.\n'
          'Only Update all may skip it, because the press that started it named every\n'
          'extension it would take. If you need another exception, that is a decision\n'
          'about what the operator is shown before code runs — not a parameter.',
    );
  });
}
