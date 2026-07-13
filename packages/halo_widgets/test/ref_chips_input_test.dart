// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

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

  testWidgets('submitting a comma-separated list adds one Ref entry per code, grouped into one chip', (tester) async {
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

    await tester.enterText(find.byType(TextField), 'US-1234,US-5678');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Two distinct Ref entries — the multi-ref storage model — not one
    // entry holding a comma-joined string.
    expect(refs, hasLength(2));
    expect(refs[0]['ref'], 'US-1234');
    expect(refs[1]['ref'], 'US-5678');

    // But rendered as a single grouped chip, comma-joined.
    expect(find.byType(InputChip), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'US-1234, US-5678'), findsOneWidget);
  });

  testWidgets('deleting the grouped chip clears every ref of this type at once', (tester) async {
    var refs = <Map<String, dynamic>>[
      {'type': 'pota', 'ref': 'US-1234'},
      {'type': 'pota', 'ref': 'US-5678'},
    ];

    await tester.pumpWidget(MaterialApp(
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
    ));

    expect(find.byType(InputChip), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(InputChip), matching: find.byType(Icon)));
    await tester.pump();

    expect(refs, isEmpty);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('a duplicate reference is rejected regardless of what else it was submitted alongside', (tester) async {
    var refs = <Map<String, dynamic>>[
      {'type': 'pota', 'ref': 'US-1234'},
    ];

    await tester.pumpWidget(MaterialApp(
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
    ));

    // "US-5678,US-1234" — same park set as a later hypothetical duplicate
    // chip would have had, but here submitted alongside a genuinely new
    // one; the already-present US-1234 must not be re-added, while the new
    // US-5678 still is (partial success, not an all-or-nothing reject).
    await tester.enterText(find.byType(TextField), 'US-5678,US-1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(refs, hasLength(2));
    expect(refs.map((r) => r['ref']), containsAll(['US-1234', 'US-5678']));

    // Submitting the exact same reference again, alone, is rejected outright.
    await tester.enterText(find.byType(TextField), 'US-5678');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(refs, hasLength(2));
    expect(find.text('Already added'), findsOneWidget);
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

  testWidgets('cursor is placed at the end on focus, not selecting the existing text', (tester) async {
    var refs = <Map<String, dynamic>>[];

    Widget build() => MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatefulBuilder(
                  builder: (context, setState) => RefChipsInput(
                    refType: 'pota',
                    label: 'POTA',
                    pattern: potaPattern,
                    refs: refs,
                    onChanged: (updated) => setState(() => refs = updated),
                  ),
                ),
                const TextField(decoration: InputDecoration(labelText: 'Elsewhere')),
              ],
            ),
          ),
        );

    await tester.pumpWidget(build());

    // Rejected submission (no match) leaves the text in place rather than
    // clearing it.
    await tester.enterText(find.byType(TextField).first, 'not a ref');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'NOT A REF');

    // Focus moves away, then back — a stray keystroke on refocus must not
    // wipe out the whole value.
    await tester.tap(find.widgetWithText(TextField, 'Elsewhere'));
    await tester.pump();
    await tester.tap(find.byType(TextField).first);
    await tester.pump();

    final refField = tester.widget<TextField>(find.byType(TextField).first);
    expect(refField.focusNode!.hasFocus, isTrue);
    expect(refField.controller!.selection.isCollapsed, isTrue);
    expect(refField.controller!.selection.baseOffset, refField.controller!.text.length);
  });

  group('transforms', () {
    testWidgets('a transform reformats "us1234" into "US-1234" as the user types', (tester) async {
      var refs = <Map<String, dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RefChipsInput(
              refType: 'pota',
              label: 'POTA',
              pattern: potaPattern,
              transforms: const [
                RefTransform(pattern: r'([A-Z]+)(\d+)', replacement: r'${1}-${2}', flags: 'gi'),
              ],
              refs: refs,
              onChanged: (updated) => setState(() => refs = updated),
            ),
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'us1234');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'US-1234');
    });

    testWidgets('reference text is uppercased live as it is typed, independent of any transform', (tester) async {
      var refs = <Map<String, dynamic>>[];
      await tester.pumpWidget(MaterialApp(
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
      ));

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'ABC');
    });

    testWidgets('a digit-leading replacement literal is not swallowed by group-index parsing', (tester) async {
      var refs = <Map<String, dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RefChipsInput(
              refType: 'pota',
              label: 'POTA',
              pattern: potaPattern,
              transforms: const [
                // Same shape as POTA's real prefix-insertion transform with
                // a DXCC prefix that starts with a digit (Fiji's "3D2").
                RefTransform(pattern: r'(^|,\s*)(\d\d+|TEST)', replacement: r'${1}3D2-${2}', flags: 'gi'),
              ],
              refs: refs,
              onChanged: (updated) => setState(() => refs = updated),
            ),
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      // Not "${13D2-1234" or "$13D2-1234" — the whole braced "${2}" group
      // reference must resolve, not misparse into a nonexistent group 13.
      expect(field.controller!.text, '3D2-1234');
    });

    testWidgets('cursor position survives a mid-string edit through a transform rewrite', (tester) async {
      var refs = <Map<String, dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RefChipsInput(
              refType: 'pota',
              label: 'POTA',
              pattern: potaPattern,
              transforms: const [
                RefTransform(pattern: r'([A-Z]+)(\d+)', replacement: r'${1}-${2}', flags: 'gi'),
              ],
              refs: refs,
              onChanged: (updated) => setState(() => refs = updated),
            ),
          ),
        ),
      ));

      // Seed the field with an already-dashed value, via the same raw
      // remote-text-input channel `enterText` uses, so the next update can
      // supply its own selection (`enterText` always collapses to the end).
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'US-1234,US-5678'));
      await tester.pump();

      // Simulate the single keystroke a user gets from inserting "9" right
      // after the "1" of "1234" (offset 4): the raw post-keystroke value the
      // platform reports has the "9" already inserted, cursor right after
      // it — this is what reaches `_RefTransformFormatter.formatEditUpdate`
      // as `newValue` before any transform runs.
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'US-19234,US-5678',
        selection: TextSelection.collapsed(offset: 5),
      ));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'US-19234,US-5678');
      // Not text.length (17) — the old always-jump-to-end behavior — but
      // right after the "9" the user just typed.
      expect(field.controller!.selection.baseOffset, 5);
    });

    // Regression test for a real bug: an earlier version of POTA's
    // transformsForPrefix had a rule that eagerly inserted the next
    // reference's prefix ("US-") the instant a trailing comma appeared, even
    // with no digits typed yet after it. That made it impossible to delete
    // back through a second reference — backspacing "US-1234,US-5678" down
    // to "US-1234,US-" and then further would immediately regrow the "US-"
    // the transform had just reinserted, so the comma could never be
    // reached. Mirrors POTA's actual (fixed) transform chain for the "US"
    // prefix: continuation after a comma now only happens once 2+ digits
    // appear, same as at the start of the field.
    testWidgets('deleting back through a second reference does not regrow its prefix', (tester) async {
      var refs = <Map<String, dynamic>>[];
      const potaTransforms = [
        RefTransform(pattern: r'([A-Z0-9]-\d+|TEST) +(?=[A-Z0-9])', replacement: r'${1}, ', flags: 'gi'),
        RefTransform(pattern: r'(^|,\s*)(\d\d+|TEST)', replacement: r'${1}US-${2}', flags: 'gi'),
        RefTransform(pattern: r'(?<![A-Z0-9])([A-Z]+)(\d+|TEST)', replacement: r'${1}-${2}', flags: 'gi'),
        RefTransform(pattern: r'[^A-Z0-9\-, ]', replacement: '', flags: 'gi'),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RefChipsInput(
              refType: 'pota',
              label: 'POTA',
              pattern: potaPattern,
              transforms: potaTransforms,
              refs: refs,
              onChanged: (updated) => setState(() => refs = updated),
            ),
          ),
        ),
      ));

      await tester.showKeyboard(find.byType(TextField));
      // Backspacing one character at a time, from a complete two-reference
      // value all the way down through the trailing comma.
      const sequence = [
        'US-1234,US-5678',
        'US-1234,US-567',
        'US-1234,US-56',
        'US-1234,US-5',
        'US-1234,US-',
        'US-1234,US',
        'US-1234,U',
        'US-1234,',
      ];
      for (final text in sequence) {
        tester.testTextInput.updateEditingValue(
          TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
        );
        await tester.pump();
      }

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'US-1234,');
    });
  });
}
