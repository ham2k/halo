// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The multi-station identifier in the Operation Details dialog.
// It is the operator-facing half of `spotCallForSelfSpot`: whatever number is
// typed here is what turns this device's self-spots into `KI2D/OP1`. Three
// things about it are promises rather than cosmetics — it is developer-mode
// only, it takes digits and nothing else, and it is stored as DEVICE-LOCAL
// data, so a value typed on one device must never travel to another through
// the operation's synced data.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/operation_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late OperationsRepository operations;
  late Operation operation;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    operation = await operations.create(stationCall: 'KI2D', userTitle: 'Field day');
  });

  tearDown(() async => db.close());

  /// Opens the real dialog the way OperationView does, and returns the
  /// Operation it handed back once the dialog is dismissed.
  Future<Operation?> openDialog(WidgetTester tester, {required bool developerMode, bool save = true}) async {
    Operation? result;
    var opened = false;
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Builder(builder: (context) {
          if (!opened) {
            opened = true;
            // After the first frame: the dialog needs a Navigator, which this
            // builder's own context does not have until the route is up.
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              result = await editOperationDetails(context, operations, operation,
                  save: save, developerMode: developerMode);
            });
          }
          return const SizedBox.shrink();
        }),
      ),
    ));
    await tester.pumpAndSettle();
    return result;
  }

  Finder multiField() => find.widgetWithText(TextField, t.dialogs.multiStationIdentifier);

  testWidgets('the field is absent without developer mode', (tester) async {
    await openDialog(tester, developerMode: false);
    expect(find.text(t.dialogs.stationCallsign), findsOneWidget, reason: 'the dialog itself should be up');
    expect(multiField(), findsNothing);
  });

  testWidgets('the dialog is the same one when the operation setup sheet opens it', (tester) async {
    // The sheet passes `save: false` — it stages the operation's SHARED data
    // until it closes. The identifier is not shared data and not staged: it
    // is written straight through, or an operator who set it from the sheet
    // would spot as the bare call until they happened to reopen the dialog
    // from the operation menu instead.
    await openDialog(tester, developerMode: true, save: false);
    expect(multiField(), findsOneWidget);
    await tester.enterText(multiField(), '3');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect((await operations.get(operation.uuid))!.localData['multiIdentifier'], '3');
  });

  testWidgets('a draft edit still stages the shared data rather than saving it', (tester) async {
    // The other half of the same promise: writing the identifier through must
    // not drag the station call and title into the database with it.
    await openDialog(tester, developerMode: true, save: false);
    await tester.enterText(find.widgetWithText(TextField, t.dialogs.stationCallsign), 'W1AW');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect((await operations.get(operation.uuid))!.stationCall, 'KI2D');
  });

  testWidgets('a typed number is stored as device-local data, not on the operation itself', (tester) async {
    await openDialog(tester, developerMode: true);
    await tester.enterText(multiField(), '2');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    final stored = await operations.get(operation.uuid);
    expect(stored!.localData['multiIdentifier'], '2');
    // The identifier names a DEVICE, not the operation: on the shared data it
    // would sync to the other operators' devices and every one of them would
    // spot as /OP2.
    expect(stored.data.containsKey('multiIdentifier'), isFalse);
  });

  testWidgets('the field refuses anything but digits', (tester) async {
    // `/OP` plus a letter is a callsign no spot API and no hunter can use.
    await openDialog(tester, developerMode: true);
    await tester.enterText(multiField(), '1a2');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect((await operations.get(operation.uuid))!.localData['multiIdentifier'], '12');
  });

  testWidgets('typing 0 clears the position, the same as the POSITION command', (tester) async {
    // The command's own help says "0 for none", so 0 is what an operator who
    // read it types here. Stored as '0' it would spot as KI2D/OP0.
    await operations.updateLocalData(operation.uuid, {'multiIdentifier': '2'});
    operation = (await operations.get(operation.uuid))!;

    await openDialog(tester, developerMode: true);
    await tester.enterText(multiField(), '0');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect((await operations.get(operation.uuid))!.localData['multiIdentifier'], '');
  });

  testWidgets('clearing the field stores an empty identifier, turning the suffix off', (tester) async {
    await operations.updateLocalData(operation.uuid, {'multiIdentifier': '2'});
    operation = (await operations.get(operation.uuid))!;

    await openDialog(tester, developerMode: true);
    expect(tester.widget<TextField>(multiField()).controller!.text, '2', reason: 'the stored value should be shown');
    await tester.enterText(multiField(), '');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect((await operations.get(operation.uuid))!.localData['multiIdentifier'], '');
  });
}
