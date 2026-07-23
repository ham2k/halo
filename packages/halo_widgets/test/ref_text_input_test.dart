// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  const potaPattern = r'[A-Z0-9]+-(?:[0-9]{4,5}|TEST)';

  Widget build({List<RefTransform> transforms = const []}) => MaterialApp(
        home: Scaffold(
          body: RefTextInput(
            refType: 'pota',
            label: 'POTA',
            pattern: potaPattern,
            transforms: transforms,
            refs: const [],
            onChanged: (_) {},
          ),
        ),
      );

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
}
