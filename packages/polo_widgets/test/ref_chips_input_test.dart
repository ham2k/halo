// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polo_widgets/polo_widgets.dart';

/// Harness that exposes an external `wipe()`, so a test can simulate a
/// parent (like LoggingControls) clearing refs out from under a pending
/// decoration.
class _Harness extends StatefulWidget {
  final RefDecorator decorate;
  const _Harness({super.key, required this.decorate});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  List<Map<String, dynamic>> refs = [];

  void wipe() => setState(() => refs = []);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: RefChipsInput(
          refType: 'pota',
          label: 'POTA',
          pattern: r'[A-Z0-9]+-(?:[0-9]{4,5}|TEST)',
          refs: refs,
          onChanged: (updated) => setState(() => refs = updated),
          decorate: widget.decorate,
        ),
      ),
    );
  }
}

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

  testWidgets('a parent wipe while decoration is pending does not resurrect the ref', (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    final harnessKey = GlobalKey<_HarnessState>();

    await tester.pumpWidget(_Harness(key: harnessKey, decorate: (ref) => completer.future));

    await tester.enterText(find.byType(TextField), 'US-1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Chip is present optimistically while decoration is still pending.
    expect(find.widgetWithText(InputChip, 'US-1234'), findsOneWidget);

    // Parent wipes (e.g. LoggingControls._wipe after logging the QSO) before
    // the decoration resolves.
    harnessKey.currentState!.wipe();
    await tester.pump();
    expect(find.byType(InputChip), findsNothing);

    // Decoration resolves late, for the ref that's no longer there.
    completer.complete({'type': 'pota', 'ref': 'US-1234', 'name': 'Example State Park'});
    await tester.pump();
    await tester.pump();

    // The ghost ref must not reappear.
    expect(find.byType(InputChip), findsNothing);
    expect(harnessKey.currentState!.refs, isEmpty);
  });
}
