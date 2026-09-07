// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Dev-only: resets the app to a known fixture for agent verification, behind
// `window.__halo.resetFixture()`. Wired up in main.dart, and only there.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';

import '../views/operation_view.dart';
import '../config/dev_fixture.dart';

import 'settings_service.dart';

import '../config/navigation.dart';
import 'halo_services.dart';

/// Resets the app to a known fixture for agent/dev verification: back up
/// then clear all operations + QSOs, restore font scale and distance units to
/// their defaults, seed a fresh operation with canned QSOs, and navigate into
/// it. Returns a summary including the `backupId` of the pre-reset snapshot.
/// Backs `window.__halo.resetFixture()`; only reachable in dev/web (see
/// `main()`), so it never runs in release.
Future<Map<String, dynamic>> resetDevFixture(HaLoServices services) async {
  // Clean slate — but back the live data up first rather than hard-deleting, so
  // a stray reset over real data is recoverable. Copies operations + QSOs into
  // the OperationsBackup/QsosBackup tables under a shared backupId, then clears
  // the live tables: the same copy-then-delete the sync engine uses when
  // replacing local data. One transaction so a crash mid-clear can't leave
  // orphaned QSOs. The drift streams (watchAll) re-emit, so the UI follows.
  final backupId = nowUtc().toIso8601String();
  await services.db.transaction(() async {
    await services.operations.backupAndClearAll(backupId);
    await services.qsos.backupAndClearAll(backupId);
  });

  // Known UI state — the settings that most often skew visual verification.
  await services.settings.setFontScale(FontScale.normal);
  await services.settings.setDistanceUnits(DistanceUnits.kilometers);

  final operatorCall = services.settings.activeProfile.operatorCall;
  final stationCall = operatorCall.isNotEmpty ? operatorCall : 'N0DEV';
  final operation = await services.operations.create(stationCall: stationCall, userTitle: 'HALO Fixture');
  await services.operations
      .saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'grid': fixtureOperationGrid}));

  final seeds = fixtureQsos(nowMillis());
  for (final qso in seeds) {
    await services.qsos.add(operation.uuid, qso);
  }

  // Land in the seeded operation, clearing whatever was on the stack (keep the
  // home route beneath so Back still works).
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => OperationView(services: services, operationUuid: operation.uuid)),
    (route) => route.isFirst,
  );

  // `backupId` lets a caller find the pre-reset data in the backup tables.
  return {'uuid': operation.uuid, 'stationCall': stationCall, 'qsoCount': seeds.length, 'backupId': backupId};
}
