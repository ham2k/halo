// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When a panel hears `qsoLogged`. The SDK promises it for a contact logged,
// edited or deleted; the traps are an edit that never fires it (a panel
// keeping what it read stays wrong), and a rescore's cached verdicts that
// fire it once more per contact for nothing a panel reads. And when it hears
// `operation`: the row is read again around every contact, so an operation
// compared by identity fires it with each one.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';

void main() {
  late HaLoDatabase db;
  late QsosRepository qsos;
  late OperationsRepository operations;
  late Operation operation;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    qsos = QsosRepository(db);
    operations = OperationsRepository(db);
    operation = await operations.create(stationCall: 'KI2D');
  });

  tearDown(() => db.close());

  /// The context a view builds from its log stream's latest list.
  Future<PanelRenderContext> context() async {
    final log = await qsos.watchForOperation(operation.uuid).first;
    return PanelRenderContext(operation: operation, qsoCount: log.length, log: log);
  }

  Future<Qso> add(String call, int startAt) => qsos.add(operation.uuid, {
    'their': {'call': call},
    'startAtMillis': startAt,
  });

  test('an edit fires qsoLogged though the count stands still', () async {
    final first = await add('W1AW', 1000);
    final before = await context();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await qsos.update(Qso(uuid: first.uuid, operationUuid: operation.uuid, data: {...first.data, 'startAtMillis': 5000}));
    expect((await context()).changesFrom(before), contains('qsoLogged'));
  });

  test("a rescore's cached verdicts do not", () async {
    final first = await add('W1AW', 1000);
    final before = await context();
    await qsos.updateScoreCache(operation.uuid, {first.uuid: '{"core":{}}'});
    final after = await context();
    expect(identical(after.log, before.log), isFalse, reason: 'the stream did emit a new list');
    expect(after.changesFrom(before), isNot(contains('qsoLogged')));
  });

  test('a contact logged or deleted does', () async {
    await add('W1AW', 1000);
    final before = await context();
    final second = await add('K1ABC', 2000);
    final logged = await context();
    expect(logged.changesFrom(before), contains('qsoLogged'));
    await qsos.softDelete(second);
    expect((await context()).changesFrom(logged), contains('qsoLogged'));
  });

  group('operation', () {
    /// The context a view builds after reading the operation row again.
    Future<PanelRenderContext> reread() async => PanelRenderContext(operation: await operations.get(operation.uuid));

    Future<void> log(String call, int startAt) async {
      await add(call, startAt);
      await operations.followContact(operation.uuid, isNewContact: true);
    }

    // Each contact reaches the view as several rows: the counters refreshed
    // with the contact, then the status, then device-local writes such as
    // the scoring summary. A context is built from each.
    test('fires only once while contacts are logged, for the first one making the operation active', () async {
      var previous = await reread();
      final fired = <String>[];
      Future<void> step(String name) async {
        final next = await reread();
        if (next.changesFrom(previous).contains('operation')) fired.add(name);
        previous = next;
      }

      for (final (i, call) in ['W1AW', 'K1ABC', 'N0DEV'].indexed) {
        await add(call, 1000 + i);
        await step('$call counters');
        await operations.followContact(operation.uuid, isNewContact: true);
        await step('$call status');
        await operations.updateLocalData(operation.uuid, {
          'scoring': {'qsos': i + 1},
        });
        await step('$call local data');
      }
      expect(previous.operation!.qsoCount, 3, reason: 'the row moved under every contact');
      expect(fired, ['W1AW status']);
    });

    test('fires when what the operator set changes', () async {
      await log('W1AW', 1000);
      final before = await reread();
      await operations.saveData(Operation(uuid: operation.uuid, data: {...before.operation!.data, 'grid': 'FN20'}));
      expect((await reread()).changesFrom(before), contains('operation'));
    });

    // The seat is device-local, so moving to another one writes nothing to
    // the data; the operator a panel shows as `operatorCall` changes all the
    // same.
    test('fires when this device takes another seat', () async {
      final seated = await operations.get(operation.uuid);
      await operations.saveData(Operation(uuid: operation.uuid, data: {...seated!.data, 'operator1': 'K1ABC', 'operator2': 'N0DEV'}));
      await operations.updateLocalData(operation.uuid, {multiIdentifierKey: '1'});
      final before = await reread();
      await operations.updateLocalData(operation.uuid, {multiIdentifierKey: '2'});
      final after = await reread();
      expect(operatorCallFor(after.operation!), 'N0DEV');
      expect(after.changesFrom(before), contains('operation'));
    });
  });

  // The row and the log come on separate streams: a log that arrives first
  // fires `qsoLogged` while the context still holds the old times, and the
  // row arriving after must fire it again.
  test("the operation's contact times moving fire qsoLogged, not operation", () async {
    await add('W1AW', 1000);
    final log = await qsos.watchForOperation(operation.uuid).first;
    final before = PanelRenderContext(operation: await operations.get(operation.uuid), qsoCount: log.length, log: log);
    await add('K1ABC', 2000);
    final after = PanelRenderContext(operation: await operations.get(operation.uuid), qsoCount: log.length, log: log);
    expect(after.operation!.startAtMillisMax, 2000);
    expect(after.changesFrom(before), {'qsoLogged'});
  });
}
