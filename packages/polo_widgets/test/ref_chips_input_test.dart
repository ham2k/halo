// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polo_widgets/polo_widgets.dart';

void main() {
  const potaPattern = r'[A-Z0-9]+-(?:[0-9]{4,5}|TEST)';

  testWidgets('adds valid refs as chips, rejects invalid input', (tester) async {
    var refs = <Map<String, dynamic>>[];

    Widget build() => MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => RefChipsInput(
                refType: 'pota',
                label: 'POTA',
                pattern: potaPattern,
                refs: refs,
                onChanged: (updated) => setState(() => refs = updated),
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());

    await tester.enterText(find.byType(TextField), 'not a ref');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(refs, isEmpty);
    expect(find.text('Not a valid POTA reference'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'us-1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(refs, hasLength(1));
    expect(refs.single['ref'], 'US-1234');
    expect(refs.single['type'], 'pota');
    expect(find.widgetWithText(InputChip, 'US-1234'), findsOneWidget);

    // Duplicates are rejected.
    await tester.enterText(find.byType(TextField), 'US-1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(refs, hasLength(1));
    expect(find.text('Already added'), findsOneWidget);
  });

  testWidgets('async decoration updates the chip when it lands', (tester) async {
    var refs = <Map<String, dynamic>>[];

    Future<Map<String, dynamic>> decorate(Map<String, dynamic> ref) async {
      return {...ref, 'name': 'Example State Park', 'shortLabel': 'POTA ${ref['ref']}'};
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => RefChipsInput(
            refType: 'pota',
            label: 'POTA',
            pattern: potaPattern,
            refs: refs,
            onChanged: (updated) => setState(() => refs = updated),
            decorate: decorate,
          ),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'US-1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();

    expect(refs.single['name'], 'Example State Park');
    expect(find.widgetWithText(InputChip, 'POTA US-1234'), findsOneWidget);
    expect(find.textContaining('Example State Park'), findsOneWidget);
  });
}
