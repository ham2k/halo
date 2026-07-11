// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:drift/native.dart';
import 'package:ham2k_logger/services/radio_service.dart';

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late RadioService radio;
  late Operation operation;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    radio = RadioService(operations: operations);
    operation = await operations.create(stationCall: 'W1AW');
  });

  tearDown(() async {
    // setVfo's persistence is fire-and-forget (matches ScoringService) — let
    // any in-flight write settle before closing the database out from
    // under it.
    await Future<void>.delayed(Duration.zero);
    await db.close();
  });

  test('vfoA is empty before any operation is loaded', () {
    expect(radio.vfoA.freq, isNull);
    expect(radio.vfoA.band, isNull);
    expect(radio.vfoA.mode, isNull);
  });

  test('setVfo with freq derives the band and persists both', () async {
    radio.loadForOperation(operation);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');

    expect(radio.vfoA.freq, 14285);
    expect(radio.vfoA.band, '20m');
    expect(radio.vfoA.mode, 'SSB');

    // Persistence is fire-and-forget in setVfo — wait a beat, then reload
    // from a fresh service to confirm it actually landed in localData.
    await Future<void>.delayed(Duration.zero);
    final reloaded = await operations.get(operation.uuid);
    final freshRadio = RadioService(operations: operations);
    freshRadio.loadForOperation(reloaded!);
    expect(freshRadio.vfoA.freq, 14285);
    expect(freshRadio.vfoA.band, '20m');
    expect(freshRadio.vfoA.mode, 'SSB');
  });

  test('setVfo with band clears freq (manually picked band, no exact frequency)', () {
    radio.loadForOperation(operation);
    radio.setVfo('vfoA', freq: 14285);
    radio.setVfo('vfoA', band: '40m');

    expect(radio.vfoA.freq, isNull);
    expect(radio.vfoA.band, '40m');
  });

  test('setVfo with only mode leaves freq/band untouched', () {
    radio.loadForOperation(operation);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    radio.setVfo('vfoA', mode: 'CW');

    expect(radio.vfoA.freq, 14285);
    expect(radio.vfoA.band, '20m');
    expect(radio.vfoA.mode, 'CW');
  });

  test('loadForOperation is a no-op for the operation already loaded', () {
    radio.loadForOperation(operation);
    radio.setVfo('vfoA', freq: 14285);
    radio.loadForOperation(operation);

    expect(radio.vfoA.freq, 14285);
  });

  test('notifies listeners on setVfo and on loading a different operation', () async {
    var notifications = 0;
    radio.addListener(() => notifications++);

    radio.loadForOperation(operation);
    expect(notifications, 1);

    radio.setVfo('vfoA', freq: 14285);
    expect(notifications, 2);

    final other = await operations.create(stationCall: 'W1AW/2');
    radio.loadForOperation(other);
    expect(notifications, 3);
    expect(radio.vfoA.freq, isNull);
  });
}
