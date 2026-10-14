// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When a panel hears `qsoLogged`. The SDK promises it for a contact logged,
// edited or deleted; the traps are an edit that never fires it (a panel
// keeping what it read stays wrong), and a rescore's cached verdicts that
// fire it once more per contact for nothing a panel reads.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';

void main() {
  late HaLoDatabase db;
  late QsosRepository qsos;
  late Operation operation;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    qsos = QsosRepository(db);
    operation = await OperationsRepository(db).create(stationCall: 'KI2D');
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
}
