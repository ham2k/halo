// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Editing an operation's station or operator callsign, and what happens to the
// contacts already logged under the old one (HALO-279).
//
// The trap this file exists to catch: changing the call in the dialog decides
// what FUTURE contacts carry, and silently leaves the log behind. An operator
// fixing a typo has no way to tell — so the offer to restamp has to appear
// exactly when there is one call to replace, must never fire without being
// asked, and must not reach contacts made from another operating position.

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

  late HaLoDatabase db;
  late SettingsService settings;
  late HaLoServices services;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late Operation operation;

  setUp(() async {
    final harness = await makeHaLoServices();
    db = harness.db;
    settings = harness.settings;
    services = harness.services;
    operations = services.operations;
    qsos = services.qsos;
    operation = await operations.create(stationCall: 'N0DEV', userTitle: 'Field day');
  });

  Future<void> logContact(
    String theirCall, {
    String ourCall = 'N0DEV',
    String? operatorCall,
    String? position,
  }) async {
    await qsos.add(operation.uuid, {
      'their': {'call': theirCall},
      'our': {
        'call': ourCall,
        'operatorCall': ?operatorCall,
        'multiIdentifier': ?position,
      },
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1721736000000,
    });
  }

  Future<void> openDialog(
    WidgetTester tester, {
    bool developerMode = false,
    String ownCall = '',
    bool suggestDefaultOperator = true,
  }) async {
    // The dialog reads all three from settings now, so the test states them
    // there rather than passing them in.
    if (developerMode) await settings.setDeveloperMode(true);
    if (ownCall.isNotEmpty) await settings.setProfileOperatorCall(SettingsService.defaultProfileId, ownCall);
    if (!suggestDefaultOperator) {
      await settings.setSettingValue(SettingsService.loggingGroup, 'suggestDefaultOperator', false);
    }
    var opened = false;
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Builder(builder: (context) {
          if (!opened) {
            opened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await editOperationDetails(context, services, operation);
            });
          }
          return const SizedBox.shrink();
        }),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder stationField() => find.widgetWithText(TextField, t.dialogs.stationCallsign);
  Finder operatorField() => find.widgetWithText(TextField, t.settings.operatorCall);

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
  }

  Future<List<Qso>> storedContacts() => qsos.forOperation(operation.uuid);

  group('station callsign', () {
    // The station call is what a SEGMENT states, so its contacts follow it
    // with nothing to ask — the dialog carries no station offer at all, and
    // the restamp happens in `onLocalSave` for every writer, not just here.
    testWidgets('offers nothing, and says nothing, about the station call', (tester) async {
      await logContact('W1AW');
      await logContact('K1ABC');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('changing it rewrites the segment\'s contacts, unasked', (tester) async {
      // Through the repository's save hook, not the dialog: every writer of
      // the station call gets this, not just this one screen.
      await logContact('W1AW');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
      await save(tester);

      expect((await operations.get(operation.uuid))!.stationCall, 'KI2D');
      expect((await storedContacts()).single.ourCall, 'KI2D');
    });
  });

  group('what reaches the log and the operation', () {
    testWidgets('the restamp writes the parsed call, not the raw field text', (tester) async {
      // One backspace away from a two-call operation: the field reads
      // "N0DEV, ". Writing it verbatim would put a trailing comma on every
      // contact, and into every export and sync record after it.
      await logContact('W1AW', ourCall: 'W2XYZ');
      await openDialog(tester);
      await tester.enterText(stationField(), 'N0DEV, ');
      await save(tester);

      expect((await storedContacts()).single.ourCall, 'N0DEV');
    });

    testWidgets('a second station callsign clears the operation\'s operator', (tester) async {
      // The dialog says each contact records its own operator. An operator
      // left in the operation's data would go on stamping every new contact
      // behind that statement, from a field too disabled to take it out.
      await operations.saveData(Operation(
        uuid: operation.uuid,
        data: {...operation.data, 'operatorCall': 'W2XYZ'},
      ));
      operation = (await operations.get(operation.uuid))!;
      await openDialog(tester);
      await tester.enterText(stationField(), 'N0DEV, W1AW');
      await save(tester);

      expect(operatorCallFor((await operations.get(operation.uuid))!), '');
    });

    testWidgets('a contact that vanished mid-edit is reported, not quietly dropped', (tester) async {
      // The offer named a number. `writeBatch` counts the rows it actually
      // affected, and agreeing to "2 contacts" while 1 changes is exactly what
      // that honest count exists to surface — silence here would leave the
      // operator believing a log they never got.
      await logContact('W1AW', operatorCall: 'KI2D');
      await logContact('K1ABC', operatorCall: 'KI2D');
      await openDialog(tester);
      await tester.enterText(operatorField(), 'W2XYZ');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Straight out of the table, which is what the row's disappearance
      // looks like to this write however it happened — a purged test
      // operation, a hard delete arriving from sync. A soft delete would not
      // do: `writeBatch` updates a tombstone and counts it.
      final vanished = (await storedContacts()).first.uuid;
      await (db.delete(db.qsos)..where((q) => q.uuid.equals(vanished))).go();
      await save(tester);

      expect(
        services.statusBar.activeNotices.map((notice) => notice.text),
        contains(t.dialogs.callChange.restampShortfall(written: 1, planned: 2)),
      );
    });

    testWidgets('Enter with an empty station callsign discards nothing', (tester) async {
      // Save is disabled for it, but every field submits on Enter and would
      // otherwise walk straight past the button — dropping the title, the
      // notes and any ticked restamp as silently as Cancel.
      await openDialog(tester);
      await tester.enterText(stationField(), '');
      await tester.enterText(find.widgetWithText(TextField, t.home.titleOptional), 'Weekend activation');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text(t.dialogs.operationDetails), findsOneWidget, reason: 'the dialog should still be open');
    });
  });

  group('callsign validation', () {
    testWidgets('warns about an unparseable call without blocking the save', (tester) async {
      // A special-event or portable form this regex does not know is still a
      // callsign somebody worked — a refusal here makes it unloggable.
      await openDialog(tester);
      await tester.enterText(stationField(), 'ZZZZ');
      await tester.pumpAndSettle();
      expect(find.text(t.dialogs.callChange.invalidCallsign(call: 'ZZZZ')), findsOneWidget);

      await save(tester);
      expect((await operations.get(operation.uuid))!.stationCall, 'ZZZZ');
    });

    testWidgets('names every bad call when several are given', (tester) async {
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D, ZZZZ, QQ');
      await tester.pumpAndSettle();

      expect(find.text(t.dialogs.callChange.invalidCallsigns(calls: 'ZZZZ, QQ')), findsOneWidget);
    });
  });

  group('operator callsign', () {
    testWidgets('restamps the operator separately from the station call', (tester) async {
      await logContact('W1AW');
      await openDialog(tester);
      await tester.enterText(operatorField(), 'KI2D');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await save(tester);

      final stored = (await storedContacts()).single;
      expect(stored.ourOperatorCall, 'KI2D');
      expect(stored.ourCall, 'N0DEV', reason: 'the station call was never edited');
    });

    testWidgets('an emptied operator field offers no restamp at all', (tester) async {
      // An empty field is also every intermediate state of typing one, so it
      // says nothing — clearing the operator on the operation leaves the
      // contacts that recorded one alone.
      await logContact('W1AW', operatorCall: 'KI2D');
      await operations.saveData(Operation(
        uuid: operation.uuid,
        data: {...operation.data, 'operatorCall': 'KI2D'},
      ));
      operation = (await operations.get(operation.uuid))!;
      await openDialog(tester);
      await tester.enterText(operatorField(), '');
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      await save(tester);
      expect((await storedContacts()).single.ourOperatorCall, 'KI2D');
    });

    testWidgets('is disabled, and offers nothing, under several station calls', (tester) async {
      // No single operator applies: each contact carries its own, whichever
      // station call it was made under.
      await logContact('W1AW');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D, W1AW');
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(operatorField()).enabled, isFalse);
      expect(find.text(t.dialogs.callChange.operatorSeveralStations), findsOneWidget);
    });

    testWidgets('reaches only this position\'s contacts in a multi-operator operation', (tester) async {
      // The operation names an operator PER SEAT. A blanket restamp would
      // relabel contacts made by everyone else at the station as this
      // device's operator.
      await logContact('W1AW', operatorCall: 'KI2D', position: '1');
      await logContact('K1ABC', operatorCall: 'N0ONE', position: '2');
      await operations.updateLocalData(operation.uuid, {'multiIdentifier': '2'});
      operation = (await operations.get(operation.uuid))!;

      await openDialog(tester, developerMode: true);
      await tester.enterText(operatorField(), 'W2XYZ');
      await tester.pumpAndSettle();
      expect(find.text(t.dialogs.callChange.operatorRestamp(count: 1, typed: 'W2XYZ')), findsOneWidget,
          reason: 'only seat 2 has a contact this device may speak for');
      await tester.tap(find.byType(Checkbox));
      await save(tester);

      final stored = {for (final qso in await storedContacts()) qso.theirCall: qso.ourOperatorCall};
      expect(stored['K1ABC'], 'W2XYZ');
      expect(stored['W1AW'], 'KI2D', reason: 'seat 1 belongs to another operator');
    });
  });

  group('suggested operator', () {
    testWidgets('offers the operator\'s own call when the station is somebody else\'s', (tester) async {
      await openDialog(tester, ownCall: 'KI2D');
      expect(tester.widget<TextField>(operatorField()).controller!.text, 'KI2D');
    });

    testWidgets('offers nothing when the station call is the operator\'s own', (tester) async {
      operation = await operations.create(stationCall: 'KI2D');
      await openDialog(tester, ownCall: 'KI2D');
      expect(tester.widget<TextField>(operatorField()).controller!.text, '');
    });

    testWidgets('takes the suggestion back when it stops meaning anything', (tester) async {
      // Typing the operator's own call as the station call makes the operator
      // field redundant — leaving the suggestion there would log an OPERATOR
      // field on every contact that says nothing the station call doesn't.
      await openDialog(tester, ownCall: 'KI2D');
      await tester.enterText(stationField(), 'KI2D');
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(operatorField()).controller!.text, '');
    });

    testWidgets('never overwrites a name the operator typed', (tester) async {
      await openDialog(tester, ownCall: 'KI2D');
      await tester.enterText(operatorField(), 'W1AW');
      await tester.enterText(stationField(), 'KI2D');
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(operatorField()).controller!.text, 'W1AW');
    });

    testWidgets('never refills an operator the operation deliberately cleared', (tester) async {
      // An emptied operator is an answer. Refilling it on the next open means
      // opening the dialog to fix a title silently re-adds the name they
      // removed, on the following Save.
      await operations.saveData(Operation(
        uuid: operation.uuid,
        data: {...operation.data, 'operatorCall': ''},
      ));
      operation = (await operations.get(operation.uuid))!;
      await openDialog(tester, ownCall: 'KI2D');

      expect(tester.widget<TextField>(operatorField()).controller!.text, '');
    });

    testWidgets('stays out of the way when the setting is off', (tester) async {
      await openDialog(tester, ownCall: 'KI2D', suggestDefaultOperator: false);
      expect(tester.widget<TextField>(operatorField()).controller!.text, '');
    });
  });
}
