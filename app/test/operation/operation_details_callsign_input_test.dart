// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation Details dialog's callsign fields take callsigns and nothing
// else. What's typed there is stored as-is and split on commas downstream, so
// a space, a stray symbol, or a comma in the single-call Operator field ends
// up in the log. And a soft keyboard left free to suggest and autocorrect
// turns a callsign into a word.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/operation_dialogs.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late OperationsRepository operations;
  late Operation operation;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
    operations = services.operations;
    operation = await operations.create(stationCall: 'KI2D', userTitle: 'Field day');
  });

  Future<void> openDialog(WidgetTester tester) async {
    var opened = false;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              if (!opened) {
                opened = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => editOperationDetails(context, services, operation));
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder stationField() => find.widgetWithText(TextField, t.dialogs.stationCallsign);
  Finder operatorField() => find.widgetWithText(TextField, t.settings.operatorCall);

  testWidgets('station calls keep their commas and lose spaces and punctuation', (tester) async {
    await openDialog(tester);
    await tester.enterText(stationField(), 'n0dev, k1abc!');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect((await operations.get(operation.uuid))!.stationCall, 'N0DEV,K1ABC');
  });

  testWidgets('two calls pasted into the one-call Operator field are warned about, not run together', (tester) async {
    // Run together, "W2ABCK1X" passes as a callsign and nothing warns.
    await openDialog(tester);
    await tester.enterText(operatorField(), 'w2abc, k1x');
    await tester.pump();

    expect(tester.widget<TextField>(operatorField()).controller!.text, 'W2ABC K1X');
    expect(find.text(t.dialogs.callChange.invalidCallsign(call: 'W2ABC K1X')), findsOneWidget);
  });

  testWidgets('neither callsign field lets the keyboard suggest or autocorrect', (tester) async {
    await openDialog(tester);
    for (final field in [stationField(), operatorField()]) {
      final widget = tester.widget<TextField>(field);
      expect(widget.autocorrect, isFalse);
      expect(widget.enableSuggestions, isFalse);
      expect(widget.textCapitalization, TextCapitalization.characters);
    }
  });

  testWidgets('a call that does not parse is warned about, not refused', (tester) async {
    // A special-event form the regex doesn't know is still a callsign
    // somebody worked.
    await openDialog(tester);
    await tester.enterText(stationField(), '12345');
    await tester.pump();
    expect(find.text(t.dialogs.callChange.invalidCallsign(call: '12345')), findsOneWidget);

    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
    expect((await operations.get(operation.uuid))!.stationCall, '12345');
  });
}
