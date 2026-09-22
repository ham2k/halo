// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An operation refuses an ADIF file holding more than
// `maxOperationImportRecords` records, before planning it. The pair of cases
// sits on the boundary: dropping the check lets 1,001 through to the
// planner, and an off-by-one refuses a file of exactly 1,000.

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/operation/adif_import_flow.dart';

import '../support/halo_test_support.dart';

XFile _adif(int records) {
  final body = StringBuffer('<PROGRAMID:4>Test<EOH>\n');
  for (var i = 0; i < records; i++) {
    final minute = (i % 60).toString().padLeft(2, '0');
    final hour = (i ~/ 60 % 24).toString().padLeft(2, '0');
    // A distinct call on each: same-call records inside the duplicate window
    // fold into one, and the summary would no longer count the file.
    final call = 'W${i}X';
    body.write('<CALL:${call.length}>$call<QSO_DATE:8>20260901<TIME_ON:4>$hour$minute<BAND:3>20m<MODE:2>CW<EOR>\n');
  }
  return XFile.fromData(utf8.encode(body.toString()), name: 'big.adi', path: 'big.adi');
}

Future<void> _import(WidgetTester tester, int records) async {
  late Operation operation;
  final harness = await makeHaLoServices();
  await tester.runAsync(() async {
    operation = await harness.services.operations.create(stationCall: 'N0DEV');
  });
  await pumpHaLo(
    tester,
    harness: harness,
    (services) => Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => importAdifFile(context, services: services, operation: operation, file: _adif(records)),
          child: const Text('import'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('import'));
  // The planner reads the log through a drift stream, which only delivers
  // on real time — so alternate real waits with frames until a dialog shows.
  for (var i = 0; i < 20 && find.byType(Dialog).evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  // The flag stays set while a notice is open, and a test ends with one open.
  setUp(() => adifImportInFlight = false);

  testWidgets('a file over the limit is refused before it is planned', (tester) async {
    await _import(tester, maxOperationImportRecords + 1);
    expect(find.text(t.adifImport.tooMany(filename: 'big.adi', limit: '1,000')), findsOneWidget);
    expect(find.text(t.adifImport.confirm), findsNothing);
  });

  testWidgets('a file of exactly the limit is planned', (tester) async {
    await _import(tester, maxOperationImportRecords);
    expect(find.text(t.adifImport.newContacts(count: 1000, formatted: '1,000')), findsOneWidget);
    expect(find.text(t.adifImport.confirm), findsOneWidget);
  });
}
