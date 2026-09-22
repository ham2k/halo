// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// main.dart is the composition root: it wires the service graph and hands it
// to the widget tree, and that is all it does. A lib file that imports it
// takes the whole app for one symbol, and the graph turns into a cycle the
// moment a service wants the navigator — it would be importing the file that
// constructs the service. Everything lib code reaches for lives in its own
// file (config/navigation.dart, services/halo_services.dart,
// views/app_shell/…), and this pins that it is imported from there.
//
// Only lib/ is held to it. The tests reach the app through its entry point
// on purpose — main.dart re-exports what it wires — so a test importing
// main.dart is the intended shape, not a violation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `.dart` file under the app's `lib/` except the entry point itself.
List<File> _sources() {
  final root = Directory('lib');
  // Loudly, not vacuously: a suite run from an unexpected cwd would otherwise
  // scan nothing and pass while enforcing nothing at all.
  if (!root.existsSync()) {
    fail('expected ${root.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
  }
  return root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && f.path != 'lib/main.dart').toList();
}

void main() {
  test('no lib file imports the entry point', () {
    final entryPoint = RegExp(r"""^import\s+'((\.\./)*main\.dart|package:ham2k_logger/main\.dart)'""");
    final offenders = <String>[];
    for (final file in _sources()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (entryPoint.hasMatch(lines[i].trimLeft())) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'main.dart is the composition root, not a library. Import what you need from where it lives:\n'
          '  HaLoServices, OperationCommandContext → services/halo_services.dart\n'
          '  runCommandAction → services/command_actions.dart\n'
          '  navigatorKey → config/navigation.dart\n'
          '  homeRail, HomeDestination, route observers → views/app_shell/home_rail_state.dart\n'
          'Found:\n${offenders.join('\n')}',
    );
  });
}
