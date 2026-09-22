// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Info panel's history rows say where a past QSO was made from — the
// activation references of ITS operation, read off that operation's refs,
// because the cached title fragments exist only on the device that computed
// them and a synced log has none. A row from an operation that activated
// nothing says nothing, and the current operation's rows never say it.
//
// The refs an operation carries alongside its activations are the contest it
// is running (and, in an imported log, a stray hunting-type ref); a place
// line naming either would be wrong.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/operation/call_info_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> buildServices() async {
    return (await makeHaLoServices()).services;
  }

  setUpAll(initializeDateFormatting);

  testWidgets('a past QSO names the park its operation activated; others say nothing', (tester) async {
    final services = await buildServices();
    final current = await services.operations.create(stationCall: 'N0DEV');
    final park = await services.operations.create(stationCall: 'N0DEV');
    await services.operations.saveData(
      Operation(
        uuid: park.uuid,
        data: {
          ...park.data,
          'refs': [
            {'type': 'potaActivation', 'ref': 'US-1234', 'name': 'North Lake SP'},
            {'type': 'arrlDx', 'ref': 'arrl-dx-2026'},
            {'type': 'pota', 'ref': 'US-9999', 'name': 'A Hunted Park'},
          ],
        },
      ),
    );
    final plain = await services.operations.create(stationCall: 'N0DEV');
    for (final (op, start) in [(current, 3000), (park, 2000), (plain, 1000)]) {
      await services.qsos.add(op.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'startAtMillis': start,
      });
    }

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: CallInfoPanel(operation: current, services: services, call: 'W1AW', guess: const {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('from US-1234 North Lake SP'), findsOneWidget);
    // Exactly one "from" line: not the contest, not the hunted park, not the
    // plain operation, and not the current operation's own row.
    expect(find.textContaining('from '), findsOneWidget);
  });

  testWidgets('a multi-callsign operation does not mark its own contacts as made elsewhere', (tester) async {
    // The row says "with <call>" only for a contact made under some OTHER
    // station. An operation can run under several callsigns, held in one
    // comma-separated field while each contact carries exactly one of them,
    // so comparing a contact against the FIELD marks every row of such an
    // operation as somebody else's.
    final services = await buildServices();
    final current = await services.operations.create(stationCall: 'KI2D, W1AW');
    await services.qsos.add(current.uuid, {
      'their': {'call': 'W2XYZ'},
      'our': {'call': 'KI2D'},
      'band': '20m',
      'startAtMillis': 3000,
    });
    final elsewhere = await services.operations.create(stationCall: 'N0DEV');
    await services.qsos.add(elsewhere.uuid, {
      'their': {'call': 'W2XYZ'},
      'our': {'call': 'N0DEV'},
      'band': '20m',
      'startAtMillis': 2000,
    });

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: CallInfoPanel(operation: current, services: services, call: 'W2XYZ', guess: const {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(t.callInfo.withCall(call: 'KI2D')), findsNothing);
    expect(
      find.textContaining(t.callInfo.withCall(call: 'N0DEV')),
      findsOneWidget,
      reason: 'a contact made under a call this operation does not run still says so',
    );
  });
}
