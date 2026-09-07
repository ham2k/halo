// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `CommandEngine.dispatchActions` turns the closed set of `CommandAction`
// fields into `runAction` calls, and it does so through a hand-written chain
// of `else if`s. A field added to the SDK types without a branch here still
// interprets, still previews, still prints the hook's confirmation — and does
// nothing at all. `logging_controls.dart` has its own copy of that chain and
// its own regression test; this is the OTHER path, the one taken from ⌘K and
// the Home bar when no operation is open, and it had none.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/command_engine.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The services the most recent [engine] was built on, for the one test
  /// that needs to open an operation context on them.
  late HaLoServices lastServices;

  /// An engine with nothing registered to take over dispatch, which is the
  /// no-operation-open case these local branches exist for. With a logging
  /// panel mounted `services.currentCommandDispatch` swallows the batch first
  /// and none of this code runs.
  Future<(CommandEngine, List<MapEntry<String, Map<String, dynamic>?>>)> engine() async {
    final HaLoHarness(:services, :db) = await makeHaLoServices();

    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    lastServices = services;
    final commandEngine = CommandEngine(
      services: services,
      operationContext: () => null,
      runAction: (action, [params]) async {
        dispatched.add(MapEntry(action, params));
      },
    );
    addTearDown(commandEngine.dispose);
    return (commandEngine, dispatched);
  }

  test('devHammer reaches runAction with its params', () async {
    // Without this branch DEVHAMMER interprets, prints the extension's
    // "Hammering the status bar…" confirmation, and does nothing — from ⌘K
    // only, since the call field's chain has a branch of its own. A tester who
    // sees no churn reads that as the churn no longer provoking the bug.
    final (commandEngine, dispatched) = await engine();

    await commandEngine.dispatchActions([
      {
        'devHammer': {'seconds': 20},
      },
    ]);

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'devHammer');
    expect(dispatched.single.value, {'seconds': 20});
  });

  test('devBench reaches runAction with its params', () async {
    // Without this branch DEVBENCH interprets, the palette accepts it, and
    // nothing runs — the only trace a "no dispatch branch" line in a console
    // nobody is watching.
    final (commandEngine, dispatched) = await engine();

    await commandEngine.dispatchActions([
      {
        'devBench': {'qsoCount': 2000},
      },
    ]);

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'devBench');
    expect(dispatched.single.value, {'qsoCount': 2000});
  });

  test('updateOperation reaches runAction, carrying the open operation\'s uuid', () async {
    // OPER/POSITION are app-scoped: the logging panel contributes only the
    // uuid, which the open operation's context has too. Without a branch here
    // a POSITION run from ⌘K while no logging panel is mounted prints
    // "Position: 2" and writes nothing — a confirmation for a write that
    // never happened is worse than no command at all.
    final (commandEngine, dispatched) = await engine();
    final entry = lastServices.openOperationContext('op-uuid');
    entry.operation = {'uuid': 'op-uuid', 'stationCall': 'KI2D'};
    addTearDown(() => lastServices.closeOperationContext(entry));

    await commandEngine.dispatchActions([
      {
        'updateOperation': {'multiIdentifier': '2'},
      },
    ]);

    expect(dispatched.single.key, 'updateOperation');
    expect(dispatched.single.value, {'multiIdentifier': '2', 'uuid': 'op-uuid'});
  });

  test('with no operation open updateOperation still reaches runAction, which reports the failure', () async {
    // Dropping it here would be the silent path all over again: the action
    // itself is what tells the operator there is nothing to write to.
    final (commandEngine, dispatched) = await engine();

    await commandEngine.dispatchActions([
      {
        'updateOperation': {'operatorCall': 'KI2D'},
      },
    ]);

    expect(dispatched.single.key, 'updateOperation');
    expect(dispatched.single.value, {'operatorCall': 'KI2D'});
  });

  test('a batch is dispatched whole, in order', () async {
    // Commands can return several actions at once, and the order is the hook's
    // to decide — splitting or reordering the batch is how a pair like
    // setVfo + updateQso stops meaning what it said.
    final (commandEngine, dispatched) = await engine();

    await commandEngine.dispatchActions([
      {
        'devStatus': {'text': 'first'},
      },
      {
        'devHammer': {'seconds': 5},
      },
      {
        'reloadDataFiles': {'target': 'ALL'},
      },
    ]);

    expect(dispatched.map((e) => e.key).toList(), ['devStatus', 'devHammer', 'reloadDataFiles']);
  });

  test('the branches that bypass runAction still take effect', () async {
    // updateSettings never reaches runAction — it writes the setting directly —
    // so the dispatched list cannot see it, and deleting its branch drops the
    // action into the `else` where it is merely printed. syncAll rides along
    // here because it is the other branch keyed on containsKey rather than a
    // Map value, and neither was covered.
    final HaLoHarness(:services, :db, :settings) = await makeHaLoServices();

    final dispatched = <String>[];
    final commandEngine = CommandEngine(
      services: services,
      operationContext: () => null,
      runAction: (action, [params]) async => dispatched.add(action),
    );
    addTearDown(commandEngine.dispose);

    expect(settings.developerMode, isFalse, reason: 'the assertion below means nothing if it starts true');

    await commandEngine.dispatchActions([
      {
        'updateSettings': {'developerMode': true},
      },
      {'syncAll': <String, dynamic>{}},
    ]);

    expect(settings.developerMode, isTrue);
    expect(dispatched, ['syncAll']);
  });

  test('a registered logging panel takes the batch, and takes it once', () async {
    // With an operation open the whole batch goes to that panel's dispatcher,
    // which handles the app-scoped actions too. The early return after it is
    // what stops the local chain running as well — without it every app-scoped
    // action in the batch fires twice, once per chain, and a SYNCALL from ⌘K
    // starts two syncs.
    final HaLoHarness(:services, :db) = await makeHaLoServices();

    final toPanel = <List<dynamic>>[];
    final entry = services.openOperationContext('op-1');
    entry.dispatch = (actions, {bool skipOnlineLookup = false}) async => toPanel.add(actions);
    addTearDown(() => services.closeOperationContext(entry));

    final locally = <String>[];
    final commandEngine = CommandEngine(
      services: services,
      operationContext: () => null,
      runAction: (action, [params]) async => locally.add(action),
    );
    addTearDown(commandEngine.dispose);

    await commandEngine.dispatchActions([
      {'syncAll': <String, dynamic>{}},
    ]);

    expect(toPanel, hasLength(1), reason: 'the panel owns the batch');
    expect(locally, isEmpty, reason: 'and the local chain must not run it a second time');
  });

  test('an action with no branch here is reported, not swallowed', () async {
    // The safety net for the NEXT field added to CommandAction. It cannot stop
    // the silent no-op, but it leaves a trace of one — and that trace is the
    // only thing separating "this command does nothing" from "this command is
    // not wired up", which are indistinguishable from the operator's seat.
    final (commandEngine, dispatched) = await engine();

    final log = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => log.add(message ?? '');
    addTearDown(() => debugPrint = previous);

    await commandEngine.dispatchActions([
      {
        'somethingNobodyWiredUp': {'x': 1},
      },
    ]);

    expect(dispatched, isEmpty);
    expect(log.join('\n'), contains('no dispatch branch'));
    expect(log.join('\n'), contains('somethingNobodyWiredUp'));
  });
}
