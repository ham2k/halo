// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  const counties = [
    {'code': 'ALB', 'name': 'Albany'},
    {'code': 'SCH', 'name': 'Schenectady'},
    {'code': 'SCO', 'name': 'Schoharie'},
    {'code': 'SAR', 'name': 'Saratoga'},
    {'code': 'SC', 'name': 'South Carolina', 'standalone': true},
  ];

  Map<String, dynamic> formWith({Map<String, dynamic>? multiValue}) => {
    'title': 'Setup',
    'elements': [
      {'type': 'field', 'fieldType': 'text', 'key': 'location', 'label': 'Location', 'uppercase': true, 'suggestions': counties, 'multiValue': ?multiValue},
      {'type': 'field', 'fieldType': 'text', 'key': 'other', 'label': 'Other'},
    ],
  };

  Future<Map<String, dynamic>?> pump(WidgetTester tester, Map<String, dynamic> form, {Map<String, dynamic> initial = const {}}) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: form, initialState: initial, onSubmit: (values) => submitted = values, onCancel: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return submitted;
  }

  Finder field(String label) => find.widgetWithText(TextField, label);
  Finder suggestion(String name) => find.textContaining(name, findRichText: true);
  // A Text.rich, so the field's own EditableText holding the same string is not a match.
  Finder names(String text) => find.byWidgetPredicate((widget) => widget is Text && widget.textSpan?.toPlainText() == text);

  Color? colorOf(WidgetTester tester, String whole, String part) {
    Color? found;
    tester.widget<Text>(names(whole)).textSpan!.visitChildren((span) {
      if (span is TextSpan && span.text == part) found = span.style?.color;
      return true;
    });
    return found;
  }

  testWidgets('typing offers the matching codes, and picking one fills the field', (tester) async {
    await pump(tester, formWith());
    await tester.tap(field('Location'));
    await tester.enterText(field('Location'), 'SC');
    await tester.pumpAndSettle();

    expect(suggestion('Schenectady'), findsOneWidget);
    expect(suggestion('Schoharie'), findsOneWidget);
    expect(suggestion('Albany'), findsNothing);

    await tester.tap(suggestion('Schoharie'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Location')).controller!.text, 'SCO');
  });

  testWidgets('on a county line, picking completes the county being typed and keeps the one before it', (tester) async {
    // The trap: RawAutocomplete writes the WHOLE field on a pick, so a
    // suggestion that carried only its code would erase `ALB/`.
    await pump(tester, formWith(multiValue: {'separator': '/'}));
    await tester.tap(field('Location'));
    await tester.enterText(field('Location'), 'ALB/SA');
    await tester.pumpAndSettle();

    await tester.tap(suggestion('Saratoga'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Location')).controller!.text, 'ALB/SAR');
  });

  testWidgets('an unknown value is flagged once the operator pauses, without leaving the field', (tester) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: formWith(multiValue: {'separator': '/'}),
              initialState: const {},
              onSubmit: (values) => submitted = values,
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(field('Location'));
    await tester.enterText(field('Location'), 'ALB/XYZ');
    await tester.pump(const Duration(milliseconds: 800));
    // Still inside the pause: a half-typed code would flash red on every keystroke.
    expect(names('Albany'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(names('Albany / XYZ?'), findsOneWidget);
    expect(colorOf(tester, 'Albany / XYZ?', 'XYZ?'), Theme.of(tester.element(field('Other'))).colorScheme.error);
    expect(colorOf(tester, 'Albany / XYZ?', 'Albany'), isNull);

    // Typing again restarts the pause for the value being typed.
    await tester.enterText(field('Location'), 'ALB/XYZQ');
    await tester.pump();
    expect(names('Albany'), findsOneWidget);

    // Leaving the field flags it at once.
    await tester.tap(field('Other'));
    await tester.pump();
    expect(names('Albany / XYZQ?'), findsOneWidget);

    // Flagged, not refused.
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
    expect(submitted?['location'], 'ALB/XYZQ');
  });

  testWidgets('an unknown value before the one being typed is flagged at once', (tester) async {
    await pump(tester, formWith(multiValue: {'separator': '/'}));
    await tester.tap(field('Location'));
    await tester.enterText(field('Location'), 'XYZ/SC');
    await tester.pump();
    expect(names('XYZ?'), findsOneWidget);
  });

  testWidgets('without multiValue a slash is not a separator, so a county line is one unknown value', (tester) async {
    await pump(tester, formWith(), initial: const {'location': 'ALB/SCH'});
    expect(names('ALB/SCH?'), findsOneWidget);
    expect(colorOf(tester, 'ALB/SCH?', 'ALB/SCH?'), isNotNull);
  });

  testWidgets('a standalone code is offered on its own, but never inside a list', (tester) async {
    // A county line is between counties: `ALB/SC` would claim a state as the
    // far side of the line.
    await pump(tester, formWith(multiValue: {'separator': '/'}));
    await tester.tap(field('Location'));
    await tester.enterText(field('Location'), 'S');
    await tester.pumpAndSettle();
    expect(suggestion('South Carolina'), findsOneWidget);

    await tester.enterText(field('Location'), 'ALB/S');
    await tester.pumpAndSettle();
    expect(suggestion('South Carolina'), findsNothing);
    expect(suggestion('Saratoga'), findsOneWidget);
  });

  testWidgets('a standalone code is named alone and flagged in a list', (tester) async {
    await pump(tester, formWith(multiValue: {'separator': '/'}), initial: const {'location': 'SC'});
    expect(names('South Carolina'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pump(tester, formWith(multiValue: {'separator': '/'}), initial: const {'location': 'ALB/SC'});
    expect(names('Albany / SC?'), findsOneWidget);
  });

  testWidgets('Enter takes the suggestion being offered', (tester) async {
    await pump(tester, formWith());
    await tester.tap(field('Location'));
    await tester.enterText(field('Location'), 'SCHO');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Location')).controller!.text, 'SCO');
  });

  testWidgets('Enter on a complete code saves, even when longer codes start with it', (tester) async {
    // `SC` is South Carolina AND the start of SCH and SCO, so the list is still
    // up; Enter there must not strand the operator in a form that neither
    // picks nor saves.
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: formWith(), initialState: const {}, onSubmit: (values) => submitted = values, onCancel: () {}),
          ),
        ),
      ),
    );
    await tester.tap(field('Location'));
    await tester.enterText(field('Location'), 'SC');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(submitted?['location'], 'SC');
  });

  testWidgets('a short later county is offered both ways: as the first one\'s shorthand, and as typed', (tester) async {
    // A 7QP line on the OR/WA border: after `ORDES/`, `WA` may be the start of
    // a Washington county as much as short for an Oregon one. Searching only
    // the shorthand (`ORWA…`) hides every Washington county.
    const sevenQp = [
      {'code': 'ORDES', 'name': 'Deschutes OR'},
      {'code': 'ORJEF', 'name': 'Jefferson OR'},
      {'code': 'IDJEF', 'name': 'Jefferson ID'},
      {'code': 'WAKLI', 'name': 'Klickitat WA'},
    ];
    await pump(tester, {
      'title': 'Setup',
      'elements': [
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'location',
          'label': 'Location',
          'suggestions': sevenQp,
          'multiValue': {'separator': '/', 'inheritPrefix': 2},
        },
      ],
    });
    await tester.tap(field('Location'));
    await tester.enterText(field('Location'), 'ORDES/WAK');
    await tester.pumpAndSettle();
    expect(suggestion('Klickitat WA'), findsOneWidget);

    // And the shorthand, where it names a county, comes first.
    await tester.enterText(field('Location'), 'ORDES/JEF');
    await tester.pumpAndSettle();
    final first = tester.widget<ListTile>(find.byType(ListTile).first);
    expect((first.title as Text).textSpan!.toPlainText(), contains('Jefferson OR'));
  });

  testWidgets('transforms rewrite a comma into the separator as it is typed', (tester) async {
    await pump(tester, {
      'title': 'Setup',
      'elements': [
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'location',
          'label': 'Location',
          'suggestions': counties,
          'multiValue': {'separator': '/'},
          'transforms': [
            {'pattern': ',', 'replacement': '/', 'flags': 'g'},
          ],
        },
      ],
    });
    await tester.tap(field('Location'));
    await tester.enterText(field('Location'), 'ALB,SCH');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Location')).controller!.text, 'ALB/SCH');
    expect(names('Albany / Schenectady'), findsOneWidget);
  });
}
