// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  EditableText editable(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText));

  testWidgets('starts obscured and toggles visibility on the button', (tester) async {
    await tester.pumpWidget(host(const SecretTextField(decoration: InputDecoration(labelText: 'Password'))));

    // A secret field must hide its text until the operator asks to see it.
    expect(editable(tester).obscureText, isTrue);

    // The eye button reveals it...
    await tester.tap(find.byTooltip('Show'));
    await tester.pump();
    expect(editable(tester).obscureText, isFalse);

    // ...and hides it again (the tooltip flips with the state).
    await tester.tap(find.byTooltip('Hide'));
    await tester.pump();
    expect(editable(tester).obscureText, isTrue);
  });

  testWidgets('injecting the toggle keeps the caller decoration and password autofill', (tester) async {
    await tester.pumpWidget(host(const SecretTextField(decoration: InputDecoration(labelText: 'API key'))));

    // The suffix button must not clobber the field's own label...
    expect(find.text('API key'), findsOneWidget);
    // ...and a password manager must still see it as a password (autofill/save).
    expect(tester.widget<TextField>(find.byType(TextField)).autofillHints, contains(AutofillHints.password));
  });

  testWidgets('a revealed secret still refuses autocorrect and keyboard suggestions', (tester) async {
    await tester.pumpWidget(host(const SecretTextField(decoration: InputDecoration(labelText: 'Password'))));

    // Reveal it: obscureText no longer forces these off, so the field itself
    // must — a shown password must not be autocorrected or learned/suggested
    // by the soft keyboard.
    await tester.tap(find.byTooltip('Show'));
    await tester.pump();
    final e = editable(tester);
    expect(e.obscureText, isFalse);
    expect(e.autocorrect, isFalse);
    expect(e.enableSuggestions, isFalse);
  });
}
