// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's behaviour lives in part files, each an extension on its
// state, and an extension method's tear-off is a new closure on every read.
// Handed to anything that compares it later — a `removeListener` undoing an
// `addListener`, the numbers row's value-compared `KeyboardAccessorySpec` —
// it never matches, and nothing says so: the listener leaks and fires after
// dispose, the spec notifies on every build. So every callback in those
// positions has to name a member of the state class itself.
//
// A guard because the failure is silent: analyze is happy, and a test only
// sees it if it happens to dispose the panel and then poke the notifier.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _dir = '../packages/halo_widgets/lib/src';
const _library = '$_dir/logging_controls.dart';

/// A bare `_name` tear-off where the receiver compares it later.
final _compared = RegExp(r'(?:addListener|removeListener)\((_\w+)\)|onKey: (_\w+)\b');

/// A method declared at member indentation, which in a part file means a
/// member of that part's extension.
final _declared = RegExp(r'^  (?:static )?\w[\w<>?, ]*? (_\w+)\(', multiLine: true);

void main() {
  test('every compared callback in the logging panel is a member of its state class', () {
    final library = File(_library).readAsStringSync();
    final parts = [for (final m in RegExp(r"^part '([\w.]+)';", multiLine: true).allMatches(library)) File('$_dir/${m.group(1)}').readAsStringSync()];
    // Loudly, not vacuously: a library that lost its parts, or its listeners,
    // would otherwise leave nothing to check.
    expect(parts, isNotEmpty, reason: 'no part directives in $_library');

    final inParts = {
      for (final source in parts) ...[for (final m in _declared.allMatches(source)) m.group(1)!],
    };
    final compared = {
      for (final source in [library, ...parts]) ...[for (final m in _compared.allMatches(source)) (m.group(1) ?? m.group(2))!],
    };
    expect(compared, isNotEmpty, reason: 'no listener registrations found in the logging panel');

    final offenders = compared.intersection(inParts);
    expect(
      offenders,
      isEmpty,
      reason:
          '${offenders.join(', ')}: declared in a logging_controls part file (an extension), but handed to a '
          'listener or a value-compared spec. Move the method onto _LoggingControlsState in logging_controls.dart.',
    );
  });
}
