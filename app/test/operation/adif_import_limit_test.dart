// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An operation refuses an ADIF file holding more than
// `maxOperationImportRecords` records, before planning it. The pair of cases
// sits on the boundary: dropping the check lets 1,001 through to the
// planner, and an off-by-one refuses a file of exactly 1,000. The same
// harness drives a small file held in memory under a name that says nothing,
// which reaches the planner only through the byte sniff.
//
// Developer mode turns the refusal into a warning. Treating any answer other
// than an explicit "Import anyway" as consent would import on Cancel or
// Escape, and a status entry left behind by the warning would report a read
// in progress for as long as the operator takes to decide.

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/views/operation/adif_import_flow.dart';

import '../support/halo_test_support.dart';

XFile _adif(int records, {String path = 'big.adi'}) {
  final body = StringBuffer('<PROGRAMID:4>Test<EOH>\n');
  for (var i = 0; i < records; i++) {
    final minute = (i % 60).toString().padLeft(2, '0');
    final hour = (i ~/ 60 % 24).toString().padLeft(2, '0');
    // A distinct call on each: same-call records inside the duplicate window
    // fold into one, and the summary would no longer count the file.
    final call = 'W${i}X';
    body.write('<CALL:${call.length}>$call<QSO_DATE:8>20260901<TIME_ON:4>$hour$minute<BAND:3>20m<MODE:2>CW<EOR>\n');
  }
  return XFile.fromData(utf8.encode(body.toString()), path: path);
}

Future<HaLoServices> _import(WidgetTester tester, XFile file, {bool developerMode = false}) async {
  late Operation operation;
  final harness = await makeHaLoServices();
  await tester.runAsync(() async {
    operation = await harness.services.operations.create(stationCall: 'N0DEV');
    if (developerMode) await harness.services.settings.setDeveloperMode(true);
  });
  await pumpHaLo(
    tester,
    harness: harness,
    (services) => Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => importAdifFile(context, services: services, operation: operation, file: file),
          child: const Text('import'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('import'));
  await _settleDialog(tester);
  return harness.services;
}

final _warning = find.text(t.adifImport.tooManyDeveloper(filename: 'big.adi', limit: '1,000'));

/// Answers the warning with [button] and lets it finish closing before
/// waiting for what follows: a dialog still playing its exit is a `Dialog`
/// in the tree, and [_settleDialog] would return on it at once, without the
/// real time the planner needs.
Future<void> _answerWarning(WidgetTester tester, String button) async {
  await tester.tap(find.text(button));
  for (var i = 0; i < 20 && _warning.evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(_warning, findsNothing);
  await _settleDialog(tester);
}

/// The planner reads the log through a drift stream, which only delivers
/// on real time — so alternate real waits with frames until a dialog shows.
Future<void> _settleDialog(WidgetTester tester) async {
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
    await _import(tester, _adif(maxOperationImportRecords + 1));
    expect(find.text(t.adifImport.tooMany(filename: 'big.adi', limit: '1,000')), findsOneWidget);
    expect(find.text(t.adifImport.confirm), findsNothing);
  });

  testWidgets('in developer mode a file over the limit is planned once the warning is accepted', (tester) async {
    final services = await _import(tester, _adif(maxOperationImportRecords + 1), developerMode: true);
    expect(_warning, findsOneWidget);
    expect(find.text(t.adifImport.confirm), findsNothing);
    expect(services.statusBar.items.map((item) => item.key), isNot(contains('adifImport:status')));

    await _answerWarning(tester, t.adifImport.importAnyway);
    expect(find.text(t.adifImport.newContacts(count: 1001, formatted: '1,001')), findsOneWidget);
    expect(find.text(t.adifImport.confirm), findsOneWidget);
  });

  testWidgets('in developer mode cancelling the warning plans nothing', (tester) async {
    final services = await _import(tester, _adif(maxOperationImportRecords + 1), developerMode: true);
    await _answerWarning(tester, t.common.cancel);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text(t.adifImport.confirm), findsNothing);
    // The flag is held until the flow returns, so a cancel that went on to
    // plan would still be holding it.
    expect(adifImportInFlight, isFalse);
    expect(services.statusBar.items.map((item) => item.key), isNot(contains('adifImport:status')));
  });

  testWidgets('a file of exactly the limit is planned', (tester) async {
    await _import(tester, _adif(maxOperationImportRecords));
    expect(find.text(t.adifImport.newContacts(count: 1000, formatted: '1,000')), findsOneWidget);
    expect(find.text(t.adifImport.confirm), findsOneWidget);
  });

  testWidgets('a small in-memory file under a name that says nothing is planned', (tester) async {
    // A `.bin` name sends the import to the bytes first, and a sniff that
    // reads past an in-memory file's end reports every small ADIF as a
    // failure.
    await _import(tester, _adif(3, path: 'mylog.bin'));
    expect(find.text(t.adifImport.newContacts(count: 3, formatted: '3')), findsOneWidget);
    expect(find.text(t.adifImport.confirm), findsOneWidget);
  });
}
