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

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late SettingsService settings;
  late HaLoServices services;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late Operation operation;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    db = HaLoDatabase(NativeDatabase.memory());
    services = HaLoServices(db, settings);
    operations = services.operations;
    qsos = services.qsos;
    operation = await operations.create(stationCall: 'N0DEV', userTitle: 'Field day');
  });

  tearDown(() async => db.close());

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
        if (operatorCall != null) 'operatorCall': operatorCall,
        if (position != null) 'multiIdentifier': position,
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
    testWidgets('names what the log holds and offers to restamp it', (tester) async {
      await logContact('W1AW');
      await logContact('K1ABC');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
      await tester.pumpAndSettle();

      expect(find.text(t.dialogs.callChange.stationSoFar(previous: 'N0DEV', typed: 'KI2D')), findsOneWidget);
      expect(find.text(t.dialogs.callChange.stationRestamp(count: 2, typed: 'KI2D')), findsOneWidget);
    });

    testWidgets('leaves the log alone unless the offer is accepted', (tester) async {
      // The whole point of asking: an operator who genuinely swapped calls
      // mid-operation must keep the earlier contacts under the old one.
      await logContact('W1AW');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
      await save(tester);

      expect((await storedContacts()).single.ourCall, 'N0DEV');
      expect((await operations.get(operation.uuid))!.stationCall, 'KI2D');
    });

    testWidgets('restamps every contact once accepted', (tester) async {
      await logContact('W1AW');
      await logContact('K1ABC');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await save(tester);

      expect((await storedContacts()).map((qso) => qso.ourCall), everyElement('KI2D'));
    });

    testWidgets('a further edit drops a restamp already ticked', (tester) async {
      // The number on the checkbox was about the call that was typed when it
      // was ticked. Carrying the tick across to a different call would restamp
      // the log to something the operator never agreed to.
      await logContact('W1AW');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.enterText(stationField(), 'W1AW');
      await save(tester);

      expect((await storedContacts()).single.ourCall, 'N0DEV');
    });

    testWidgets('a tick dropped by widening the station call does not write', (tester) async {
      // The offer names a call, a count and a scope. Type a second station
      // call and the operator offer leaves the screen entirely — a tick that
      // outlived it would rewrite contacts against a rule the dialog has just
      // said does not apply.
      await logContact('W1AW', operatorCall: 'KI2D');
      await openDialog(tester);
      await tester.enterText(operatorField(), 'W2XYZ');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.enterText(stationField(), 'N0DEV, W1AW');
      await save(tester);

      expect((await storedContacts()).single.ourOperatorCall, 'KI2D');
    });

    testWidgets('both restamps in one save reach the same contact', (tester) async {
      // Two updates for one record is what `writeBatch` refuses outright, so
      // the fold in `editOperationDetails` is load-bearing: without it the
      // headline case — an operation set up under the wrong call AND the
      // wrong operator — throws instead of saving.
      await logContact('W1AW');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
      await tester.enterText(operatorField(), 'W2XYZ');
      await tester.pumpAndSettle();
      for (final box in find.byType(Checkbox).evaluate().toList()) {
        await tester.tap(find.byWidget(box.widget));
        await tester.pumpAndSettle();
      }
      await save(tester);

      final stored = (await storedContacts()).single;
      expect(stored.ourCall, 'KI2D');
      expect(stored.ourOperatorCall, 'W2XYZ');
    });

    testWidgets('a concurrent edit survives the restamp', (tester) async {
      // The contacts were read when the dialog opened. A sync pull or a peer
      // merge landing while it sat open must survive everywhere the restamp
      // did not touch — that is what `updateBases` buys, and without it the
      // whole stored blob is replaced by the snapshot taken at open time.
      await logContact('W1AW');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final concurrent = (await storedContacts()).single;
      await qsos.update(Qso(
        uuid: concurrent.uuid,
        operationUuid: concurrent.operationUuid,
        data: {...concurrent.data, 'notes': 'landed while the dialog was open'},
      ));
      await save(tester);

      final stored = (await storedContacts()).single;
      expect(stored.ourCall, 'KI2D');
      expect(stored.data['notes'], 'landed while the dialog was open');
    });

    testWidgets('contacts that already carry the call are not counted', (tester) async {
      // The number on the offer is what actually changes. Counting contacts
      // that are already right would promise twelve and rewrite two.
      await logContact('W1AW', ourCall: 'KI2D');
      await logContact('K1ABC');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
      await tester.pumpAndSettle();

      expect(find.text(t.dialogs.callChange.stationRestamp(count: 1, typed: 'KI2D')), findsOneWidget);
    });

    testWidgets('offers nothing when the log already holds several calls', (tester) async {
      await logContact('W1AW');
      await logContact('K1ABC', ourCall: 'W2XYZ');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
      await tester.pumpAndSettle();

      expect(find.text(t.dialogs.callChange.stationSeveral(calls: 'N0DEV, W2XYZ', typed: 'KI2D')), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('offers nothing while several station calls are being typed', (tester) async {
      // A restamp would have to pick one of them to write onto every contact,
      // and nothing here knows which.
      await logContact('W1AW');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D, W1AW');
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('says nothing at all when the log already agrees', (tester) async {
      await logContact('W1AW');
      await openDialog(tester);
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text(t.dialogs.callChange.stationSoFar(previous: 'N0DEV', typed: 'N0DEV')), findsNothing,
          reason: 'nothing has changed; the dialog is just a form');
    });
  });

  group('what reaches the log and the operation', () {
    testWidgets('a restamp writes the parsed call, not the raw field text', (tester) async {
      // One backspace away from a two-call operation: the field reads
      // "N0DEV, " and the offer appears normally, because the parser drops
      // the empty tail. Stamping the field verbatim would put a trailing
      // comma on every contact, and into every export and sync record.
      await logContact('W1AW', ourCall: 'W2XYZ');
      await openDialog(tester);
      await tester.enterText(stationField(), 'N0DEV, ');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
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
      await logContact('W1AW');
      await logContact('K1ABC');
      await openDialog(tester);
      await tester.enterText(stationField(), 'KI2D');
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
