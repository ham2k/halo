// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every route built by hand puts its content in a HoldSizeWhileCovered
// (halo_widgets' covered_route_hold.dart), enforced against the SOURCE the
// way dialog_footer_convention_test enforces its convention.
//
// Page routes get the hold from the theme and Modal Panes and showHaloDialog
// from halo_widgets, but a direct showDialog, showGeneralDialog or route
// builder has nothing to give it one. Such a route still works — it is just
// laid out again under any later route's keyboard, and a lazy list in it
// drops rows whose disposal can close that keyboard on iOS. Nothing on screen
// says so, so review cannot be relied on to catch it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Calls and classes that build a route whose content nothing else wraps —
/// and the route classes a new route would extend.
final _routeBuilders = RegExp(
  r'\b(showDialog|showAdaptiveDialog|showGeneralDialog|showCupertinoDialog|showCupertinoModalPopup|showModalBottomSheet|PageRouteBuilder|DialogRoute|RawDialogRoute|CupertinoPageRoute|CupertinoDialogRoute|CupertinoModalPopupRoute|ModalBottomSheetRoute|PopupRoute|ModalRoute|PageRoute|TransitionRoute)\b',
);

/// How many hand-built routes the app has. Raise it with a new one; a count
/// that falls below it means the scan went blind, not that routes went away.
const _knownSites = 6;

List<File> _sources() {
  final roots = [Directory('lib'), Directory('../packages/halo_widgets/lib')];
  // Loudly, not vacuously: a suite run from an unexpected cwd would otherwise
  // scan nothing and pass while enforcing nothing.
  for (final root in roots) {
    if (!root.existsSync()) {
      fail('expected ${root.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
    }
  }
  return [for (final root in roots) ...root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))];
}

/// The source with comments and the CONTENTS of string literals blanked,
/// keeping every offset so line numbers still point at the real line. A
/// bracket or an apostrophe inside either would otherwise unbalance the scan
/// of the call around it.
String _blankCommentsAndStrings(String source) {
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
    } else if (source.startsWith("'''", i) || source.startsWith('"""', i)) {
      final quote = source.substring(i, i + 3);
      final end = source.indexOf(quote, i + 3);
      final stop = end == -1 ? out.length : end;
      for (var j = i + 3; j < stop; j++) {
        if (out[j] != '\n') out[j] = ' ';
      }
      i = stop + 3;
    } else if (out[i] == "'" || out[i] == '"') {
      final quote = out[i];
      i++;
      while (i < out.length && out[i] != quote && out[i] != '\n') {
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

/// Where the argument list opens when the name ending at [from] is called
/// or constructed — past a balanced `<…>` of type arguments — or null when
/// it is not: a type argument (`Observer<PageRoute<T>>`) or a return type
/// (`PageRoute<T> build()`) builds no route.
int? _callParen(String source, int from) {
  var i = from;
  while (i < source.length && source[i].trim().isEmpty) {
    i++;
  }
  if (i < source.length && source[i] == '<') {
    var depth = 0;
    for (; i < source.length; i++) {
      if (source[i] == '<') depth++;
      if (source[i] == '>' && --depth == 0) break;
    }
    i++;
    while (i < source.length && source[i].trim().isEmpty) {
      i++;
    }
  }
  return i < source.length && source[i] == '(' ? i : null;
}

/// The end of the bracketed span that opens at [open] (`(` or `{`).
int _closing(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '(' || c == '{' || c == '[') depth++;
    if (c == ')' || c == '}' || c == ']') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return source.length;
}

void main() {
  test('every hand-built route puts its content in a HoldSizeWhileCovered', () {
    final unwrapped = <String>[];
    var checked = 0;
    for (final file in _sources()) {
      final source = _blankCommentsAndStrings(file.readAsStringSync());
      for (final match in _routeBuilders.allMatches(source)) {
        // A subclass wraps in its own body; a call or a construction wraps in
        // its arguments. Anything else — a type in a signature, an import —
        // builds no route here.
        final before = source.substring(0, match.start).trimRight();
        final int open;
        if (before.endsWith('extends')) {
          open = source.indexOf('{', match.end);
        } else {
          final paren = _callParen(source, match.end);
          if (paren == null) continue;
          open = paren;
        }
        if (open < 0) continue;
        checked++;
        final span = source.substring(open, _closing(source, open) + 1);
        if (!span.contains('HoldSizeWhileCovered(')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          unwrapped.add('${file.path}:$line — ${match.group(0)} without HoldSizeWhileCovered');
        }
      }
    }
    // Loudly, not vacuously: a scan that stopped recognising some calls would
    // pass with them unchecked.
    expect(checked, greaterThanOrEqualTo(_knownSites), reason: 'the scan found only $checked hand-built routes');
    expect(unwrapped, isEmpty, reason: 'wrap the route\'s content in HoldSizeWhileCovered — see covered_route_hold.dart for why');
  });
}
