// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  final formDefinition = {
    'title': 'Test Form',
    'subtitle': 'A form to verify fields',
    'elements': [
      {
        'type': 'header',
        'title': 'My Header',
        'subtitle': 'My Subtitle',
      },
      {
        'type': 'divider',
        'title': 'My Divider',
      },
      {
        'type': 'markdown',
        'text': 'This is **bold** text',
      },
      {
        'type': 'field',
        'fieldType': 'text',
        'key': 'name',
        'label': 'Name Field',
        'placeholder': 'Enter name',
      },
      {
        'type': 'field',
        'fieldType': 'multiline',
        'key': 'bio',
        'label': 'Bio Field',
      },
      {
        'type': 'field',
        'fieldType': 'email',
        'key': 'email',
        'label': 'Email Field',
      },
      {
        'type': 'field',
        'fieldType': 'callsign',
        'key': 'callsign',
        'label': 'Callsign Field',
      },
      {
        'type': 'field',
        'fieldType': 'number',
        'key': 'power',
        'label': 'Power Field',
      },
      {
        'type': 'field',
        'fieldType': 'select',
        'key': 'license',
        'label': 'License Field',
        'options': [
          {'label': 'Tech', 'value': 'tech'},
          {'label': 'General', 'value': 'general'},
        ],
      },
      {
        'type': 'field',
        'fieldType': 'radio',
        'key': 'pref',
        'label': 'Pref Field',
        'options': [
          {'label': 'SSB', 'value': 'ssb'},
          {'label': 'CW', 'value': 'cw'},
        ],
      },
      {
        'type': 'field',
        'fieldType': 'checkbox',
        'key': 'agree',
        'label': 'Agree Field',
      },
    ],
  };

  group('FormRenderer', () {
    testWidgets('renders all element types', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormRenderer(
              formDefinition: formDefinition,
              initialState: const {
                'name': 'Initial Name',
                'license': 'tech',
                'pref': 'cw',
                'agree': true,
              },
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ));

      // Verify Title & Subtitle
      expect(find.text('Test Form'), findsOneWidget);
      expect(find.text('A form to verify fields'), findsOneWidget);

      // Verify Header
      expect(find.text('My Header'), findsOneWidget);
      expect(find.text('My Subtitle'), findsOneWidget);

      // Verify Divider
      expect(find.text('My Divider'), findsOneWidget);

      // Verify Markdown
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.text('This is bold text'), findsOneWidget);

      // Verify Input Fields by Labels
      expect(find.text('Name Field'), findsOneWidget);
      expect(find.text('Bio Field'), findsOneWidget);
      expect(find.text('Email Field'), findsOneWidget);
      expect(find.text('Callsign Field'), findsOneWidget);
      expect(find.text('Power Field'), findsOneWidget);
      expect(find.text('License Field'), findsOneWidget);
      expect(find.text('Pref Field'), findsOneWidget);
      expect(find.text('Agree Field'), findsOneWidget);
    });

    testWidgets('gathers input, runs async validation and transformation on submit', (tester) async {
      Map<String, dynamic>? submittedValues;
      var validatorCalled = false;
      var transformerCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormRenderer(
              formDefinition: formDefinition,
              initialState: const {
                'name': 'John Doe',
                'callsign': 'ki2d',
                'agree': false,
              },
              validator: (key, value, state) async {
                validatorCalled = true;
                if (key == 'name' && (value?.toString().isEmpty ?? true)) {
                  return 'Name cannot be empty';
                }
                return null;
              },
              transformer: (key, value, state) async {
                transformerCalled = true;
                if (key == 'callsign') {
                  return value?.toString().toUpperCase();
                }
                return value;
              },
              onSubmit: (vals) {
                submittedValues = vals;
              },
              onCancel: () {},
            ),
          ),
        ),
      ));

      // Enter value in callsign (which forces lowercase text to uppercase via capitalization/formatters)
      final callsignField = find.widgetWithText(TextField, 'Callsign Field');
      await tester.enterText(callsignField, 'ki2d');
      await tester.pumpAndSettle();

      // Click save button
      final saveButton = find.widgetWithText(FilledButton, 'Save');
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify callbacks were run
      expect(validatorCalled, isTrue);
      expect(transformerCalled, isTrue);

      // Verify correct values submitted
      expect(submittedValues, isNotNull);
      expect(submittedValues!['name'], 'John Doe');
      expect(submittedValues!['callsign'], 'KI2D'); // Transformed to uppercase
    });

    testWidgets('shows validation errors and blocks submit', (tester) async {
      var submitted = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormRenderer(
              formDefinition: formDefinition,
              initialState: const {
                'name': 'John Doe',
              },
              validator: (key, value, state) async {
                if (key == 'name') {
                  return 'Name is invalid';
                }
                return null;
              },
              onSubmit: (_) {
                submitted = true;
              },
              onCancel: () {},
            ),
          ),
        ),
      ));

      final saveButton = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Validation error should be displayed, and onSubmit not called
      expect(find.text('Name is invalid'), findsOneWidget);
      expect(submitted, isFalse);
    });
  });
}
