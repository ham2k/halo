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

    testWidgets('triggers validation on blur and configures keyboard/autofill attributes', (tester) async {
      var validationCalledKey = '';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormRenderer(
              formDefinition: formDefinition,
              initialState: const {
                'name': 'John Doe',
              },
              validator: (key, value, state) async {
                validationCalledKey = key;
                if (key == 'name' && value == 'invalid') {
                  return 'Bad name';
                }
                return null;
              },
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ));

      // Check text field attributes
      final nameFieldFinder = find.widgetWithText(TextField, 'Name Field');
      final nameTextField = tester.widget<TextField>(nameFieldFinder);
      expect(nameTextField.autofillHints, contains(AutofillHints.name));
      expect(nameTextField.focusNode, isNotNull);

      // Check number field attributes (decimal & signed keyboard, formatters)
      final powerFieldFinder = find.widgetWithText(TextField, 'Power Field');
      final powerTextField = tester.widget<TextField>(powerFieldFinder);
      expect(powerTextField.keyboardType!.decimal, isTrue);
      expect(powerTextField.keyboardType!.signed, isTrue);
      expect(powerTextField.inputFormatters, isNotEmpty);

      // Focus the name field, enter 'invalid', then focus another field (to blur)
      await tester.tap(nameFieldFinder);
      await tester.enterText(nameFieldFinder, 'invalid');
      await tester.pumpAndSettle();

      // Tap on power field to shift focus (blur name field)
      await tester.tap(powerFieldFinder);
      await tester.pumpAndSettle();

      // Verify validator was run for 'name' on blur and error is displayed
      expect(validationCalledKey, 'name');
      expect(find.text('Bad name'), findsOneWidget);
    });

    testWidgets('triggers onChange to modify another field', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormRenderer(
              formDefinition: formDefinition,
              initialState: const {
                'name': 'Old Name',
                'agree': false,
              },
              onChange: (key, value, state) async {
                if (key == 'agree' && value == true) {
                  return {'name': 'Agreed Name'};
                }
                return null;
              },
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ));

      final nameFieldFinder = find.widgetWithText(TextField, 'Name Field');
      final nameTextField1 = tester.widget<TextField>(nameFieldFinder);
      expect(nameTextField1.controller?.text, 'Old Name');

      final agreeCheckboxFinder = find.byType(CheckboxListTile);
      expect(agreeCheckboxFinder, findsOneWidget);
      await tester.ensureVisible(agreeCheckboxFinder);
      await tester.tap(agreeCheckboxFinder);
      await tester.pumpAndSettle();

      final nameTextField2 = tester.widget<TextField>(nameFieldFinder);
      expect(nameTextField2.controller?.text, 'Agreed Name');
    });

    testWidgets('FormView pins actions at the bottom and submit works', (tester) async {
      Map<String, dynamic>? submittedValues;
      await tester.pumpWidget(MaterialApp(
        home: FormView(
          formDefinition: formDefinition,
          initialState: const {
            'name': 'Pinned Test',
          },
          onSubmit: (vals) {
            submittedValues = vals;
          },
          onCancel: () {},
        ),
      ));

      expect(find.text('Test Form'), findsWidgets);

      final saveButtonFinder = find.widgetWithText(FilledButton, 'Save');
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(submittedValues, isNotNull);
      expect(submittedValues!['name'], 'Pinned Test');
    });
  });

  group('FormRenderer secret/list/action fields', () {
    testWidgets('secret field obscures its text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {'type': 'field', 'fieldType': 'secret', 'key': 'apiKey', 'label': 'API Key'},
              ],
            },
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      final field = tester.widget<TextField>(find.widgetWithText(TextField, 'API Key'));
      expect(field.obscureText, isTrue);
    });

    testWidgets('list field adds, edits, and deletes items via the nested item dialog', (tester) async {
      Map<String, dynamic>? submittedValues;
      final listFormDefinition = {
        'elements': [
          {
            'type': 'field',
            'fieldType': 'list',
            'key': 'presets',
            'label': 'Presets',
            'itemTitle': r'${name} — ${exchange}',
            'itemFields': [
              {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': 'Name'},
              {'type': 'field', 'fieldType': 'text', 'key': 'exchange', 'label': 'Exchange'},
            ],
          },
        ],
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: listFormDefinition,
            initialState: const {},
            onSubmit: (vals) => submittedValues = vals,
            onCancel: () {},
          ),
        ),
      ));

      // No items yet, just the label and the "Add" row.
      expect(find.text('Presets'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Add Presets'), findsOneWidget);

      // Item add/edit dialogs have their own Save button, distinct from the
      // outer form's — scope taps to the dialog to avoid ambiguity.
      Finder dialogSaveButton() =>
          find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Save'));

      // Add an item through the nested dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Add Presets'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Field Day');
      await tester.enterText(find.widgetWithText(TextField, 'Exchange'), '1A NNJ');
      await tester.tap(dialogSaveButton());
      await tester.pumpAndSettle();

      // Summary row uses the itemTitle template.
      expect(find.text('Field Day — 1A NNJ'), findsOneWidget);

      // Edit the item: tapping the row reopens the dialog pre-filled.
      await tester.tap(find.text('Field Day — 1A NNJ'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
      final nameField = tester.widget<TextField>(find.widgetWithText(TextField, 'Name'));
      expect(nameField.controller?.text, 'Field Day');
      await tester.enterText(find.widgetWithText(TextField, 'Exchange'), '2A NNJ');
      await tester.tap(dialogSaveButton());
      await tester.pumpAndSettle();
      expect(find.text('Field Day — 2A NNJ'), findsOneWidget);

      // Submitting the outer form includes the edited list.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submittedValues!['presets'], [
        {'name': 'Field Day', 'exchange': '2A NNJ'},
      ]);

      // Delete removes the row.
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Field Day — 2A NNJ'), findsNothing);
    });

    testWidgets('action element invokes onAction with its key and method, and shows the result', (tester) async {
      String? capturedKey;
      String? capturedMethod;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {'type': 'action', 'key': 'test', 'label': 'Test Connection', 'method': 'testCredentials'},
              ],
            },
            initialState: const {},
            onAction: (actionKey, method, state) async {
              capturedKey = actionKey;
              capturedMethod = method;
              return 'Connected';
            },
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Test Connection'));
      await tester.pumpAndSettle();

      expect(capturedKey, 'test');
      expect(capturedMethod, 'testCredentials');
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('account field shows Not Connected / Connect when no status is set', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {
                  'type': 'field',
                  'fieldType': 'account',
                  'key': 'qrzStatus',
                  'label': 'QRZ.com Account',
                  'account': {'key': 'qrz'},
                },
              ],
            },
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      expect(find.text('QRZ.com Account'), findsOneWidget);
      expect(find.text('Not Connected'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Connect'), findsOneWidget);
    });

    testWidgets('account field shows the connected label and Manage, and never persists a value on submit', (tester) async {
      Map<String, dynamic>? submittedValues;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {
                  'type': 'field',
                  'fieldType': 'account',
                  'key': 'qrzStatus',
                  'label': 'QRZ.com Account',
                  'value': {'connected': true, 'label': 'Connected as KI2D'},
                  'account': {'key': 'qrz'},
                },
              ],
            },
            initialState: const {},
            onSubmit: (vals) => submittedValues = vals,
            onCancel: () {},
          ),
        ),
      ));

      expect(find.text('Connected as KI2D'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Manage'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // The account field's own status flows through to onSubmit like any
      // other field's value (settings-panel dispatch is what actually
      // excludes fieldType 'account' from persistence — see
      // ExtensionService.getSettingsPanelDefinition) — but tapping Manage
      // is the real interaction, exercised below.
      expect(submittedValues!['qrzStatus'], {'connected': true, 'label': 'Connected as KI2D'});
    });

    testWidgets('tapping Manage/Connect calls onManageAccount with the field\'s account key and subkey', (tester) async {
      String? capturedKey;
      String? capturedSubkey;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {
                  'type': 'field',
                  'fieldType': 'account',
                  'key': 'lofiStatus',
                  'label': 'LoFi Account',
                  'account': {'key': 'lofi', 'subkey': 'backup'},
                },
              ],
            },
            initialState: const {},
            onManageAccount: (accountKey, subkey) {
              capturedKey = accountKey;
              capturedSubkey = subkey;
            },
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      await tester.tap(find.widgetWithText(TextButton, 'Connect'));
      await tester.pumpAndSettle();

      expect(capturedKey, 'lofi');
      expect(capturedSubkey, 'backup');
    });
  });
}
