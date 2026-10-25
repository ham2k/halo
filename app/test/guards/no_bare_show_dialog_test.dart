// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// docs/design/user-interface.md (Dialogs): app code opens a dialog with
// showHaloDialog, never a bare showDialog, and a framework picker passes
// `builder: haloPickerFrame`. A bare showDialog still opens, and still keeps
// clear of the header through the theme's Dialog inset — but its bottom is
// measured from its route, above the status footer, rather than from the
// window, it skips the shared size cap, and on a phone it gets Material's
// margins instead of the plain one. A picker without the frame is worse: the
// range picker's calendar fills the window, over the window controls. None of
// that looks broken in a test window, so review cannot be relied on to catch
// it; this reads the SOURCE instead.
//
// showGeneralDialog is not covered: the surfaces that use it (the release
// overlay, the command bar) place themselves with HaloDialogFrame's insets.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The framework's ways of opening a plain dialog route.
final _bareDialog = RegExp(r'\b(showDialog|showAdaptiveDialog|showCupertinoDialog)\b(?=\s*[<(])');

/// The framework pickers, each of which opens its own dialog.
final _picker = RegExp(r'\b(showDatePicker|showDateRangePicker|showTimePicker)\b(?=\s*[<(])');

/// The one place a bare call belongs: showHaloDialog itself.
const _home = 'src/modal_pane.dart';

/// Line comments, which name these calls in prose. Dropped to the end of
/// the line, which also swallows the tail of a line holding a URL string —
/// never a dialog call in this code.
final _comment = RegExp(r'//[^\n]*');

/// Every `.dart` file under the app's and the widget package's `lib/`, with
/// its line comments dropped and its line numbers intact.
Map<String, String> _sources() {
  final roots = [Directory('lib'), Directory('../packages/halo_widgets/lib')];
  // Loudly, not vacuously: a suite run from an unexpected cwd would
  // otherwise scan nothing and pass while enforcing nothing.
  for (final root in roots) {
    if (!root.existsSync()) {
      fail('expected ${root.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
    }
  }
  return {
    for (final root in roots)
      for (final file in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
        file.path: file.readAsStringSync().replaceAll(_comment, ''),
  };
}

int _lineOf(String source, int offset) => '\n'.allMatches(source.substring(0, offset)).length + 1;

void main() {
  test('app code opens dialogs with showHaloDialog, never a bare showDialog', () {
    final bare = <String>[];
    var atHome = 0;
    for (final MapEntry(key: path, value: source) in _sources().entries) {
      for (final match in _bareDialog.allMatches(source)) {
        if (path.endsWith(_home)) {
          atHome++;
        } else {
          bare.add('$path:${_lineOf(source, match.start)}');
        }
      }
    }
    // The pattern still recognises the call it exists to catch: showHaloDialog
    // is built on exactly one.
    expect(atHome, 1, reason: 'expected exactly one showDialog, inside showHaloDialog in $_home');
    expect(bare, isEmpty, reason: 'open these with showHaloDialog — see the Dialogs section of docs/design/user-interface.md');
  });

  test('every framework picker is framed with haloPickerFrame', () {
    final unframed = <String>[];
    var checked = 0;
    for (final MapEntry(key: path, value: source) in _sources().entries) {
      for (final match in _picker.allMatches(source)) {
        final open = source.indexOf('(', match.end);
        var depth = 0;
        var close = open;
        for (; close < source.length; close++) {
          if (source[close] == '(') depth++;
          if (source[close] == ')' && --depth == 0) break;
        }
        checked++;
        if (!source.substring(open, close).contains(RegExp(r'\bbuilder:\s*haloPickerFrame\b'))) {
          unframed.add('$path:${_lineOf(source, match.start)}');
        }
      }
    }
    // Loudly, not vacuously: the Logs view's custom period opens one, so a
    // scan that finds none has stopped recognising the call.
    expect(checked, greaterThanOrEqualTo(1), reason: 'the scan found no picker calls at all');
    expect(unframed, isEmpty, reason: 'pass `builder: haloPickerFrame` — see the Dialogs section of docs/design/user-interface.md');
  });
}
