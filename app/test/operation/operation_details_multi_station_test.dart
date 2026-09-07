// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The multi-station identifier in the Operation Details dialog.
// It is the operator-facing half of `spotCallForSelfSpot`: whatever number is
// typed here is what turns this device's self-spots into `KI2D/OP1`. Three
// things about it are promises rather than cosmetics — it is developer-mode
// only, it takes digits and nothing else, and it is stored as DEVICE-LOCAL
// data, so a value typed on one device must never travel to another through
// the operation's synced data — while the operator beside it does travel, in
// the slot the position names.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_dialogs.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late HaLoServices services;
  late OperationsRepository operations;
  late Operation operation;

  setUp(() async {
    final harness = await makeHaLoServices();
    settings = harness.settings;
    services = harness.services;
    operations = services.operations;
    operation = await operations.create(stationCall: 'KI2D', userTitle: 'Field day');
  });

  /// Opens the real dialog the way OperationView does, and returns the
  /// Operation it handed back once the dialog is dismissed.
  Future<Operation?> openDialog(WidgetTester tester, {required bool developerMode, bool save = true}) async {
    await settings.setDeveloperMode(developerMode);
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
              result = await editOperationDetails(context, services, operation, save: save);
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

  Finder operatorField() => find.widgetWithText(TextField, t.settings.operatorCall);

  // The operator is SHARED data, unlike the position beside it: every device
  // logging the operation should be able to name who is in each seat.
  testWidgets('the operator is stored on the operation, not device-locally', (tester) async {
    await openDialog(tester, developerMode: true);
    await tester.enterText(operatorField(), 'ki2d');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    final stored = await operations.get(operation.uuid);
    expect(stored!.data['operatorCall'], 'KI2D');
    expect(stored.localData.containsKey('operatorCall'), isFalse);
  });

  testWidgets("with a position, the operator lands in that position's own slot", (tester) async {
    // Seat 2's operator has to be stored apart from seat 1's, or the devices
    // converge on one callsign and every log names the same operator.
    await operations.updateLocalData(operation.uuid, {'multiIdentifier': '2'});
    operation = (await operations.get(operation.uuid))!;

    await openDialog(tester, developerMode: true);
    await tester.enterText(operatorField(), 'W2ABC');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    final stored = await operations.get(operation.uuid);
    expect(stored!.data['operator2'], 'W2ABC');
    expect(stored.data.containsKey('operatorCall'), isFalse);
  });

  testWidgets('the operator follows the operator to the seat they move to', (tester) async {
    // The same person is still at this key; they have said which seat they
    // are now in. Seat 2's old name came from a device that is not this one,
    // so it is what gives way — and the seat being left keeps its name, for
    // whoever sits down there next.
    await operations.updateLocalData(operation.uuid, {'multiIdentifier': '1'});
    await operations.saveData(Operation(
      uuid: operation.uuid,
      data: {...operation.data, 'operator1': 'KI2D', 'operator2': 'W2ABC'},
    ));
    operation = (await operations.get(operation.uuid))!;

    await openDialog(tester, developerMode: true);
    await tester.enterText(multiField(), '2');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    final stored = await operations.get(operation.uuid);
    expect(stored!.data['operator2'], 'KI2D');
    expect(stored.data['operator1'], 'KI2D', reason: 'the seat being left is not edited');
  });

  testWidgets('a blank operator carries nothing onto the seat being joined', (tester) async {
    // Nothing to move. Written through, the empty field would erase the new
    // seat's operator on every device logging the operation.
    await operations.updateLocalData(operation.uuid, {'multiIdentifier': '1'});
    await operations.saveData(Operation(
      uuid: operation.uuid,
      data: {...operation.data, 'operator2': 'W2ABC'},
    ));
    operation = (await operations.get(operation.uuid))!;

    await openDialog(tester, developerMode: true);
    await tester.enterText(operatorField(), '');
    await tester.enterText(multiField(), '2');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect((await operations.get(operation.uuid))!.data['operator2'], 'W2ABC');
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
