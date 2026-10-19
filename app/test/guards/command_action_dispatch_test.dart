// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every `CommandAction` an extension can return must have a branch in the
// dispatchers that run it: the logging panel's (`logging_controls.dart`) and
// the app's own for when no panel is open (`command_engine.dart`). Both are
// hand-kept lists, and an action missing from one interprets fine — the
// command describes itself, the operator confirms — and then does nothing
// but log a line to the console, which a test of the action alone cannot
// see.
//
// A guard rather than a test per action because what matters is the next
// action: it is added to the SDK's types and to whichever dispatcher its
// author had open.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _types = '../extensions/sdk/src/types.ts';
const _panel = '../packages/halo_widgets/lib/src/logging_controls.dart';
const _engine = 'lib/views/command_engine.dart';

/// Actions only a live logging panel can run — they act on the QSO being
/// entered — so the no-panel dispatcher reports them instead.
const _panelOnly = {'setVfo', 'updateQso', 'addQso', 'sendSpots', 'autoRespot', 'setCallField', 'setTime'};

/// The top-level fields of `interface CommandAction`. Two-space indent only:
/// a field's own object type (`setVfo: { freq?: … }`) nests deeper.
List<String> _actions() {
  final source = File(_types).readAsStringSync();
  final block = RegExp(r'^export interface CommandAction \{\n(.*?)^\}', multiLine: true, dotAll: true).firstMatch(source)?.group(1);
  // Loudly, not vacuously: a renamed interface would otherwise leave nothing
  // to check and every dispatcher passing.
  if (block == null) fail('no `interface CommandAction` in $_types');
  return [for (final m in RegExp(r'^  (\w+)\??:', multiLine: true).allMatches(block)) m.group(1)!];
}

bool _handles(String source, String action) => RegExp("map\\['$action'\\]|containsKey\\('$action'\\)").hasMatch(source);

void main() {
  final actions = _actions();

  test('the SDK declares the actions this guard reads', () {
    expect(actions, containsAll(['setVfo', 'devLogCat', 'toggleExperiment']));
  });

  test('the logging panel has a branch for every action', () {
    final panel = File(_panel).readAsStringSync();
    expect(
      [
        for (final a in actions)
          if (!_handles(panel, a)) a,
      ],
      isEmpty,
      reason: 'add a branch to _dispatchActions in $_panel',
    );
  });

  test('the no-panel dispatcher has a branch for every action a panel is not needed for', () {
    final engine = File(_engine).readAsStringSync();
    expect(
      [
        for (final a in actions)
          if (!_panelOnly.contains(a) && !_handles(engine, a)) a,
      ],
      isEmpty,
      reason: 'add a branch to dispatchActions in $_engine',
    );
    // A stale entry here would exempt an action that has since gained a
    // branch, or one that no longer exists.
    expect(_panelOnly.difference(actions.toSet()), isEmpty, reason: 'drop actions the SDK no longer declares from _panelOnly');
    expect(
      [
        for (final a in _panelOnly)
          if (_handles(engine, a)) a,
      ],
      isEmpty,
      reason: 'drop actions $_engine now handles from _panelOnly',
    );
  });
}
