// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `number` field under the operator's Number Formatting setting.
//
// The trap this file pins: on a device set to comma conventions the numeric
// keyboard's decimal key IS a comma, so a field whose input formatter admits
// only `[0-9.-]` drops every press of it — the value becomes `15` instead of
// `1.5`, with no error, no formatter complaint, and nothing on screen to say
// what happened. `enterText` bypasses the OS keyboard but NOT the formatter,
// so typing a comma here reproduces that exactly.
//
// The second half is the round trip. A field SHOWS a stored value and READS
// what is typed back; if it displays `1.5` where the operator writes `1,5`,
// then merely opening a form and saving it re-parses the number differently.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  // Process-wide, so a leak here would silently retune every later suite in
  // this isolate.
  tearDown(NumberFormatting.instance.reset);

  const definition = {
    'title': 'Numbers',
    'elements': [
      {'type': 'field', 'fieldType': 'number', 'key': 'power', 'label': 'Power'},
    ],
  };

  Future<Map<String, dynamic>?> typeAndSave(WidgetTester tester, String text, {Map<String, dynamic> initialState = const {}}) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormRenderer(formDefinition: definition, initialState: initialState, onSubmit: (values) => submitted = values, onCancel: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (text.isNotEmpty) {
      await tester.enterText(find.widgetWithText(TextField, 'Power'), text);
      await tester.pumpAndSettle();
    }
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    return submitted;
  }

  String shownText(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Power')).controller!.text;

  testWidgets('under period conventions, either decimal key works', (tester) async {
    expect(await typeAndSave(tester, '1.5'), containsPair('power', 1.5));
    // The comma key is what a Spanish or German phone puts under the thumb of
    // someone who chose "always period" — the very operator that option
    // exists for. A filter admitting one mark drops this and stores 15.
    expect(await typeAndSave(tester, '1,5'), containsPair('power', 1.5));
  });

  testWidgets('under comma conventions, either decimal key works too', (tester) async {
    NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');
    expect(await typeAndSave(tester, '1,5'), containsPair('power', 1.5));
    // And the mirror: a desktop numpad emits a period whatever the region.
    expect(await typeAndSave(tester, '1.5'), containsPair('power', 1.5));
  });

  testWidgets('the field itself only ever holds the configured mark', (tester) async {
    // Normalizing on the way in is what keeps the value unambiguous: nothing
    // downstream has to guess whether the mark in `14.285` was a decimal
    // point or a thousands separator, because a foreign one cannot be there.
    NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');
    await typeAndSave(tester, '1.5');
    expect(shownText(tester), '1,5');
  });

  testWidgets('a stored value is shown in the operator\'s own conventions', (tester) async {
    NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');
    await typeAndSave(tester, '', initialState: const {'power': 1.5});
    expect(shownText(tester), '1,5', reason: 'showing "1.5" would make the first edit of an untouched value unparseable');
  });

  testWidgets('and what it shows is what it reads back', (tester) async {
    NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');
    await typeAndSave(tester, '', initialState: const {'power': 12.25});
    final shown = shownText(tester);
    // Re-typing exactly what the field displays must give the value back —
    // opening a form and saving it unchanged must not move the number.
    expect(await typeAndSave(tester, shown, initialState: const {'power': 12.25}), containsPair('power', 12.25));
  });

  testWidgets('a whole number grows no fraction on the way to the field', (tester) async {
    NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');
    await typeAndSave(tester, '', initialState: const {'power': 75});
    expect(shownText(tester), '75');
  });

  testWidgets('a typed thousands mark stays grouping, and is not read as a decimal', (tester) async {
    // A US operator typing `1,500` watts means fifteen hundred. Rewriting
    // that comma to a period gives 1.5 — the same silent thousandfold error
    // the rewriting exists to prevent, pointing the other way. One mark, three
    // trailing digits, nothing after: that reads as grouping, so it is left
    // alone and stripped at parse time.
    expect(await typeAndSave(tester, '1,500'), containsPair('power', 1500));
    NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');
    expect(await typeAndSave(tester, '1.500'), containsPair('power', 1500));
    // But three digits after a mark that is NOT at the end is a decimal.
    expect(await typeAndSave(tester, '1.5'), containsPair('power', 1.5));
  });

  testWidgets('an unparseable entry still arrives as null, on either setting', (tester) async {
    // Unchanged behaviour, asserted because the parse moved: callers built
    // their blank-vs-unparseable handling on this.
    expect(await typeAndSave(tester, '1.2.3'), containsPair('power', null));
    NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');
    expect(await typeAndSave(tester, '1,2,3'), containsPair('power', null));
  });
}
