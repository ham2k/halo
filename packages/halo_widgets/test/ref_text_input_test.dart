// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  const potaPattern = r'[A-Z0-9]+-(?:[0-9]{4,5}|TEST)';

  Widget build({
    List<RefTransform> transforms = const [],
    ValueChanged<List<Map<String, dynamic>>>? onChanged,
    List<Map<String, dynamic>> refs = const [],
    RefDecorator? decorate,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: RefTextInput(
            refType: 'pota',
            label: 'POTA',
            pattern: potaPattern,
            transforms: transforms,
            refs: refs,
            onChanged: onChanged ?? (_) {},
            decorate: decorate,
          ),
        ),
      );

  /// The field's underline color, which is the whole of how it reports a
  /// reference its program's pattern rejects.
  Color? underlineColor(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).decoration?.enabledBorder?.borderSide.color;

  testWidgets('disables autocorrect, suggestions, and smart punctuation', (tester) async {
    // References like "US-1234" are codes, not prose — the "-" in particular
    // is what iOS smart dashes would turn into an en-dash. The field must
    // keep the soft keyboard out of it.
    await tester.pumpWidget(build());
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autocorrect, isFalse, reason: 'no autocorrect/spell-check');
    expect(field.enableSuggestions, isFalse, reason: 'no predictive suggestions');
    expect(field.smartDashesType, SmartDashesType.disabled, reason: 'no smart dashes');
    expect(field.smartQuotesType, SmartQuotesType.disabled, reason: 'no smart quotes');
  });

  group('transforms', () {
    testWidgets('a transform reformats "us1234" into "US-1234" as the user types', (tester) async {
      await tester.pumpWidget(build(transforms: const [
        RefTransform(pattern: r'([A-Z]+)(\d+)', replacement: r'${1}-${2}', flags: 'gi'),
      ]));

      await tester.enterText(find.byType(TextField), 'us1234');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'US-1234');
    });

    testWidgets('reference text is uppercased live as it is typed, independent of any transform', (tester) async {
      await tester.pumpWidget(build());

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'ABC');
    });

    testWidgets('a digit-leading replacement literal is not swallowed by group-index parsing', (tester) async {
      await tester.pumpWidget(build(transforms: const [
        // Same shape as POTA's real prefix-insertion transform with
        // a DXCC prefix that starts with a digit (Fiji's "3D2").
        RefTransform(pattern: r'(^|,\s*)(\d\d+|TEST)', replacement: r'${1}3D2-${2}', flags: 'gi'),
      ]));

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      // Not "${13D2-1234" or "$13D2-1234" — the whole braced "${2}" group
      // reference must resolve, not misparse into a nonexistent group 13.
      expect(field.controller!.text, '3D2-1234');
    });

    testWidgets('cursor position survives a mid-string edit through a transform rewrite', (tester) async {
      await tester.pumpWidget(build(transforms: const [
        RefTransform(pattern: r'([A-Z]+)(\d+)', replacement: r'${1}-${2}', flags: 'gi'),
      ]));

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
      const potaTransforms = [
        RefTransform(pattern: r'([A-Z0-9]-\d+|TEST) +(?=[A-Z0-9])', replacement: r'${1}, ', flags: 'gi'),
        RefTransform(pattern: r'(^|,\s*)(\d\d+|TEST)', replacement: r'${1}US-${2}', flags: 'gi'),
        RefTransform(pattern: r'(?<![A-Z0-9])([A-Z]+)(\d+|TEST)', replacement: r'${1}-${2}', flags: 'gi'),
        RefTransform(pattern: r'[^A-Z0-9\-, ]', replacement: '', flags: 'gi'),
      ];

      await tester.pumpWidget(build(transforms: potaTransforms));

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

  // The slash is a reference character for SOTA, GMA, ZLOTA and WWBOTA. Since a
  // segment is now KEPT whether or not it matches, a filtered-out slash is no
  // longer merely awkward to type — it is stored and exported as the operator's
  // own code, altered. SOTA survives a stripped slash because its `transforms`
  // put one back; the fourteen programs built on `referenceActivity` declare no
  // transforms at all, so for those the field is the only thing standing
  // between the operator and a silently mangled reference.
  testWidgets('a slash survives the input filter, with no transform to repair it', (tester) async {
    List<Map<String, dynamic>>? emitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RefTextInput(
          refType: 'gmaActivation',
          label: 'GMA',
          // GMA's own shape, and no transforms — exactly what the factory emits.
          pattern: r'[A-Z0-9]+/[A-Z]{2,}-[0-9]{3,}',
          refs: const [],
          onChanged: (refs) => emitted = refs,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'DL/BW-123');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'DL/BW-123');
    expect(emitted?.single['ref'], 'DL/BW-123');
    expect(underlineColor(tester), isNot(Theme.of(tester.element(find.byType(TextField))).colorScheme.error),
        reason: 'a well-formed GMA reference must not read as invalid');
  });

  testWidgets('a reference handed over after the field was built is handed back as the same map', (tester) async {
    // A lookup's guess lands after the chip was opened. The panel takes a
    // guess back BY IDENTITY when the call changes, so a keystroke here that
    // re-emitted the park as a fresh map would leave it on the QSO past the
    // call it was guessed for.
    final guessed = <String, dynamic>{'type': 'pota', 'ref': 'US-2080', 'name': 'Guessed Park'};
    List<Map<String, dynamic>>? emitted;
    await tester.pumpWidget(build(onChanged: (refs) => emitted = refs));
    await tester.pumpWidget(build(refs: [guessed], onChanged: (refs) => emitted = refs));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'US-2080');
    await tester.enterText(find.byType(TextField), 'US-2080,');
    expect(emitted, hasLength(1));
    expect(identical(emitted!.single, guessed), isTrue);
  });

  testWidgets('a reference arriving while the empty field has focus shows; one arriving mid-typing does not',
      (tester) async {
    final park = <String, dynamic>{'type': 'pota', 'ref': 'US-2080'};
    await tester.pumpWidget(build());
    await tester.tap(find.byType(TextField));
    await tester.pump();
    // The operator is sitting in the empty field when the guess lands: the
    // chip will count it, so the field has to show it.
    await tester.pumpWidget(build(refs: [park]));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'US-2080');
    // Mid-typing, a round trip landing must not fight the keystrokes.
    await tester.enterText(find.byType(TextField), 'US-2080, US-1');
    await tester.pumpWidget(build(refs: [park, {'type': 'pota', 'ref': 'US-1234'}]));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'US-2080, US-1');
  });

  testWidgets('a handed-over reference finds its map whatever case it came in, and decoration joins that map',
      (tester) async {
    // A feed hands the code over raw; the field looks codes up uppercased.
    // The decorate round trip then adds the name INTO the guess's own map —
    // the panel takes a guess back by identity, so a swap would lose it.
    final guessed = <String, dynamic>{'type': 'pota', 'ref': 'us-2080'};
    List<Map<String, dynamic>>? emitted;
    var decorations = 0;
    Future<Map<String, dynamic>> decorate(Map<String, dynamic> ref) async {
      decorations++;
      return {...ref, 'name': 'Park ${ref['ref']}'};
    }
    await tester.pumpWidget(build(onChanged: (refs) => emitted = refs, decorate: decorate));
    await tester.pumpWidget(build(refs: [guessed], onChanged: (refs) => emitted = refs, decorate: decorate));
    await tester.enterText(find.byType(TextField), 'US-2080,');
    await tester.pump();
    expect(identical(emitted!.single, guessed), isTrue);
    expect(decorations, 1, reason: 'a bare guess is still owed its name');
    expect(guessed['name'], 'Park US-2080');
    await tester.enterText(find.byType(TextField), 'US-2080, ');
    expect(decorations, 1, reason: 'decorated now: no second round trip');
  });

  group('a reference the pattern rejects', () {
    // The pattern is HaLo's idea of the program, not the program's own: a
    // format that changed, or one this app has wrong, must not cost the
    // operator the code they were handed on the air. Dropping it silently is
    // the failure this group exists to catch — the QSO logged, the reference
    // gone, and nothing on screen having said so.
    testWidgets('reaches the QSO anyway, alongside the well-formed ones', (tester) async {
      List<Map<String, dynamic>>? emitted;
      await tester.pumpWidget(build(onChanged: (refs) => emitted = refs));

      await tester.enterText(find.byType(TextField), 'US-1234, NOT-A-PARK');
      await tester.pump();

      expect(emitted?.map((r) => r['ref']), ['US-1234', 'NOT-A-PARK']);
      expect(emitted?.every((r) => r['type'] == 'pota'), isTrue);
    });

    testWidgets('tints the field, and the tint clears once the code is well formed', (tester) async {
      await tester.pumpWidget(build());
      final error = Theme.of(tester.element(find.byType(TextField))).colorScheme.error;

      await tester.enterText(find.byType(TextField), 'NOPE');
      await tester.pump();
      expect(underlineColor(tester), error);

      await tester.enterText(find.byType(TextField), 'US-1234');
      await tester.pump();
      expect(underlineColor(tester), isNot(error));
    });

    testWidgets('a reference that arrives already invalid is tinted before a key is pressed', (tester) async {
      // An imported QSO, or one opened for editing: nothing recomputes the
      // tint on its own, so a state seeded only by `onChanged` would show a
      // clean field over a reference the operator still has to fix.
      await tester.pumpWidget(build(refs: const [
        {'type': 'pota', 'ref': 'NOT-A-PARK'},
      ]));
      await tester.pump();

      final error = Theme.of(tester.element(find.byType(TextField))).colorScheme.error;
      expect(underlineColor(tester), error);
    });

    testWidgets('is not sent for decoration — there is nothing to look up', (tester) async {
      final looked = <String>[];
      await tester.pumpWidget(build(decorate: (ref) async {
        looked.add(ref['ref'] as String);
        return ref;
      }));

      await tester.enterText(find.byType(TextField), 'US-1234, NOPE');
      await tester.pump();

      expect(looked, ['US-1234']);
    });
  });
}
