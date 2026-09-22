// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scorer folds the operation as well as the log. A change to a segment key
// (station call, refs, grid — `segmentOverrideKeys`) restamps the contacts
// and so moves the log's own fingerprint; one to anything else does not, and
// without a rescore on the save the cached checkpoint keeps the old operation
// until the next contact is logged, with the live call-info path folding cold
// on every keystroke until then. The trap is a rescore triggered by the log
// alone, so the save here is one the log cannot see: a title.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a saved change to the operation schedules a rescore, and the checkpoint follows it', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices(stubs: {
      'scoring:*:scope': [
        {'key': 'core', 'ok': true, 'value': 'always'},
      ],
      'scoring:core:scoreQsos': {
        'qsoScores': const <String, dynamic>{},
        'daySections': const <dynamic>[],
        'operationSummary': const <String, dynamic>{},
        'scoresheet': const {'worked': <String, dynamic>{}},
      },
    });
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    final operation = await services.operations.create(stationCall: 'KI2D');
    await services.qsos.add(operation.uuid, {'their': {'call': 'W1AW'}, 'band': '20m', 'mode': 'SSB', 'startAtMillis': 1000});

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: OperationView(services: services, operationUuid: operation.uuid)),
    ));
    await tester.pumpAndSettle();
    // The open-triggered pass, after its debounce.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    Future<Object?> stampedOperation() async {
      final scoring = (await services.operations.get(operation.uuid))!.localData['scoring'] as Map?;
      return ((scoring?['core'] as Map?)?['checkpoint'] as Map?)?['operationUpdatedAtMillis'];
    }

    final before = (await services.operations.get(operation.uuid))!;
    expect(await stampedOperation(), before.updatedAtMillis, reason: 'the open pass stamps the operation as it stood');

    // The save moves the operation's stamp; nothing about the log changes.
    final logBefore = await services.qsos.forOperation(operation.uuid);
    await services.operations.saveData(Operation(uuid: operation.uuid, data: {...before.data, 'userTitle': 'Renamed'}));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final after = (await services.operations.get(operation.uuid))!;
    expect(after.updatedAtMillis, isNot(before.updatedAtMillis));
    final logAfter = await services.qsos.forOperation(operation.uuid);
    expect(logAfter.map((q) => q.updatedAtMillis), logBefore.map((q) => q.updatedAtMillis),
        reason: 'the save must not have restamped the log, or the log alone would explain the rescore');
    expect(await stampedOperation(), after.updatedAtMillis,
        reason: 'a checkpoint folded under the old operation must not survive the save');

    // Tear the tree down and drain the services' debounce timers so the
    // binding's pending-timer invariant passes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
