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
import 'package:ham2k_logger/services/scoring_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a saved change to the operation schedules a rescore, and the checkpoint follows it', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices(
      stubs: {
        'scoring:*:scope': [
          {'key': 'core', 'ok': true, 'value': 'always'},
        ],
        'scoring:core:scoreQsos': {
          'qsoScores': const <String, dynamic>{},
          'daySections': const <dynamic>[],
          'operationSummary': const <String, dynamic>{},
          'scoresheet': const {'worked': <String, dynamic>{}},
        },
      },
    );
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    final operation = await services.operations.create(stationCall: 'KI2D');
    await services.qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
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
    expect(
      logAfter.map((q) => q.updatedAtMillis),
      logBefore.map((q) => q.updatedAtMillis),
      reason: 'the save must not have restamped the log, or the log alone would explain the rescore',
    );
    expect(await stampedOperation(), after.updatedAtMillis, reason: 'a checkpoint folded under the old operation must not survive the save');

    // Tear the tree down and drain the services' debounce timers so the
    // binding's pending-timer invariant passes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // The view is what says "this is the first pass after an open" — the rule
  // that keeps a changed extension from leaving stale scores behind — and what
  // decides a log moved at all. A view that resumed on open, or that missed
  // the append, would be invisible from the service's own tests.
  testWidgets('the first pass after an open folds the whole log; the pass after a logged contact replays it as a tail', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final passes = <Map<String, dynamic>>[];
    final HaLoHarness(:services, :settings) = await makeHaLoServices(
      stubs: {
        'scoring:*:scope': [
          {'key': 'core', 'ok': true, 'value': 'always'},
        ],
        'scoring:core:scoreQsos': (Object? args) {
          final sent = ((args as Map)['qsos'] as List).cast<Map<String, dynamic>>();
          passes.add(args.cast<String, dynamic>());
          return {
            'qsoScores': {
              for (final q in sent) q['uuid'] as String: {'value': 1},
            },
            'daySections': const <dynamic>[],
            'operationSummary': const <String, dynamic>{},
            'scoresheet': {'folded': sent.length},
            'scoresheetDay': 0,
          };
        },
      },
    );
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    final operation = await services.operations.create(stationCall: 'KI2D');
    final first = await services.qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    // Real time, not the test's fake clock: the stamps come from the real clock.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await services.qsos.add(operation.uuid, {
      'their': {'call': 'K1ABC'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 2000,
    });
    // A checkpoint from an earlier session that folded the FIRST contact: to
    // the rule, the second is a valid one-contact tail — which is exactly what
    // the open pass must not take.
    await services.operations.updateLocalData(operation.uuid, {
      'scoring': {
        'core': {
          'scoresheet': const {'folded': 1},
          'scoresheetDay': 0,
          'checkpoint': {
            'digest': checkpointDigestOf([first]),
            'updatedAtMillis': first.updatedAtMillis,
            'startAtMillis': 1000,
            'operationUpdatedAtMillis': (await services.operations.get(operation.uuid))!.updatedAtMillis,
          },
        },
      },
    });

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(passes, hasLength(1));
    expect((passes.single['qsos'] as List).length, 2, reason: 'the open pass folds the whole log');
    expect(passes.single.containsKey('resumeFrom'), isFalse);

    final added = await services.qsos.add(operation.uuid, {
      'their': {'call': 'N0DEV'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 3000,
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(passes, hasLength(2));
    final tail = (passes.last['qsos'] as List).cast<Map<String, dynamic>>();
    expect(tail.map((q) => q['uuid']), [added.uuid], reason: 'the pass after a logged contact replays only that contact');
    expect(passes.last['resumeFrom'], {'folded': 2});

    // An edit moves no count. Only a fingerprint that carries every stamp
    // schedules the pass — and an edited contact is one the checkpoint has
    // already folded, so that pass is the whole log.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await services.qsos.update(
      Qso(
        uuid: first.uuid,
        operationUuid: first.operationUuid,
        data: {
          ...first.data,
          'their': {'call': 'W1AW/P'},
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(passes, hasLength(3), reason: 'an edit is a rescore');
    expect((passes.last['qsos'] as List).length, 3);
    expect(passes.last.containsKey('resumeFrom'), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // A runtime change moves neither the log nor the operation, so a rescore
  // driven by those alone never comes: every checkpoint is void from the
  // tick on, the call-info pills and the spots board fold the whole log on
  // every keystroke and refresh, and the summaries stay the old scorers'.
  testWidgets('a runtime generation tick rescores the whole log with nothing else changed', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final passes = <Map<String, dynamic>>[];
    final HaLoHarness(:services, :settings) = await makeHaLoServices(
      stubs: {
        'scoring:*:scope': [
          {'key': 'core', 'ok': true, 'value': 'always'},
        ],
        'scoring:core:scoreQsos': (Object? args) {
          final sent = ((args as Map)['qsos'] as List).cast<Map<String, dynamic>>();
          passes.add(args.cast<String, dynamic>());
          return {
            'qsoScores': {
              for (final q in sent) q['uuid'] as String: {'value': 1},
            },
            'daySections': const <dynamic>[],
            'operationSummary': const <String, dynamic>{},
            'scoresheet': {'folded': sent.length},
            'scoresheetDay': 0,
          };
        },
      },
    );
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    final operation = await services.operations.create(stationCall: 'KI2D');
    await services.qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(passes, hasLength(1), reason: 'the open pass');

    services.extensions.runtimeGeneration.value++;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(passes, hasLength(2), reason: 'the tick alone schedules a pass');
    expect(passes.last.containsKey('resumeFrom'), isFalse, reason: 'under a new runtime the pass folds the whole log');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
