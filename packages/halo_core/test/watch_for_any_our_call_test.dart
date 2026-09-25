// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Logs view's All filter is every station callsign's QSOs, watched
// without a list of the callsigns: a list would have to be kept current as
// callsigns come and go. These pin that it answers the same as the per-call
// query would given every callsign — the same exclusions, the same order —
// and that a callsign logged for the first time turns up on its own.

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  });

  tearDown(() async => db.close());

  Future<Qso> log(Operation operation, String their, int at, {String? our}) => qsos.add(operation.uuid, {
    'our': {'call': our ?? operation.stationCall},
    'their': {'call': their},
    'band': '20m',
    'mode': 'CW',
    'startAtMillis': at,
  });

  test('every station callsign, oldest first, with what the per-call query leaves out left out', () async {
    final k1abc = await operations.create(stationCall: 'K1ABC');
    final w2xyz = await operations.create(stationCall: 'W2XYZ');
    final gone = await operations.create(stationCall: 'N3GON');
    await log(w2xyz, 'VE3CC', 3000);
    await log(k1abc, 'W1AW', 1000);
    final deleted = await log(k1abc, 'K2AA', 2000);
    await qsos.softDelete(deleted);
    await log(gone, 'N3BB', 1500);
    await operations.softDelete(gone.uuid);
    // No station callsign: not anyone's log, as it is in the picker.
    await log(k1abc, 'NOCALL', 2500, our: '');

    final all = await qsos.watchForAnyOurCall().first;
    expect([for (final qso in all) qso.theirCall], ['W1AW', 'VE3CC']);
    final perCall = await qsos.watchForOurCalls(['K1ABC', 'W2XYZ', 'N3GON']).first;
    expect([for (final qso in all) qso.uuid], [for (final qso in perCall) qso.uuid]);
  });

  test('a callsign logged for the first time is in the next emission', () async {
    final k1abc = await operations.create(stationCall: 'K1ABC');
    await log(k1abc, 'W1AW', 1000);
    final emissions = qsos.watchForAnyOurCall().map((list) => [for (final qso in list) qso.ourCall]);
    final seen = expectLater(emissions, emitsThrough(['K1ABC', 'W9NEW']));
    final newcomer = await operations.create(stationCall: 'W9NEW');
    await log(newcomer, 'VE3CC', 2000);
    await seen;
  });
}
