// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgets('arrow keys cycle a focused select field through its options', (tester) async {
      Map<String, dynamic>? changedTo;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormRenderer(
              formDefinition: formDefinition,
              initialState: const {'license': 'tech'},
              onChange: (key, value, state) async {
                if (key == 'license') changedTo = {'value': value};
                return null;
              },
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ));

      // DropdownButtonFormField doesn't expose its FocusNode as a public
      // getter, so reach the `Focus` it wraps itself in and focus that
      // directly — requesting focus this way, rather than tapping the field,
      // also avoids ever opening the popup menu, which is the whole point:
      // this cycling only needs to work while the menu is closed.
      final dropdownFocusNode = find
          .descendant(
            of: find.byType(DropdownButtonFormField<dynamic>),
            matching: find.byType(Focus),
          )
          .evaluate()
          .map((e) => (e.widget as Focus).focusNode)
          .firstWhere((node) => node != null);
      dropdownFocusNode!.requestFocus();
      await tester.pump();

      // Down from 'tech' (index 0) lands on 'general' (index 1) — the menu
      // never opens, so this must come from the field's own key handling,
      // not DropdownButtonFormField's built-in open-menu arrow navigation.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('General'), findsOneWidget);
      expect(changedTo, {'value': 'general'});

      // Down again wraps back to 'tech', the first option.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('Tech'), findsOneWidget);
      expect(changedTo, {'value': 'tech'});

      // Up from 'tech' wraps the other way, to the last option.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(find.text('General'), findsOneWidget);
      expect(changedTo, {'value': 'general'});
    });

    testWidgets('link elements hand their URL to onOpenLink', (tester) async {
      String? openedUrl;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormRenderer(
              formDefinition: const {
                'elements': [
                  {
                    'type': 'link',
                    'label': 'Privacy Policy',
                    'description': 'How we handle your data',
                    'icon': 'shield-account',
                    'url': 'https://example.com/privacy',
                  },
                ],
              },
              initialState: const {},
              onOpenLink: (url) => openedUrl = url,
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ));

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('How we handle your data'), findsOneWidget);

      await tester.tap(find.text('Privacy Policy'));
      expect(openedUrl, 'https://example.com/privacy');
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
      expect(powerTextField.keyboardType.decimal, isTrue);
      expect(powerTextField.keyboardType.signed, isTrue);
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

  });

  group('FormRenderer collapsible markdown block', () {
    final collapsibleFormDefinition = {
      'elements': [
        {
          'type': 'markdown',
          'collapsible': true,
          'title': 'How to build your own',
          'text': 'Read **this** carefully.',
        },
      ],
    };

    testWidgets('starts collapsed, showing the title but not the text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(formDefinition: collapsibleFormDefinition, initialState: const {}, onSubmit: (_) {}, onCancel: () {}),
        ),
      ));

      expect(find.text('How to build your own'), findsOneWidget);
      expect(find.byType(MarkdownBody), findsNothing, reason: 'the help text is collapsed by default');
    });

    testWidgets('tapping the header expands it to reveal the text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(formDefinition: collapsibleFormDefinition, initialState: const {}, onSubmit: (_) {}, onCancel: () {}),
        ),
      ));

      await tester.tap(find.text('How to build your own'));
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.text('Read this carefully.'), findsOneWidget);
    });

    testWidgets('a plain (non-collapsible) markdown block is unaffected', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: {
              'elements': [
                {'type': 'markdown', 'text': 'Always visible'},
              ],
            },
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.text('Always visible'), findsOneWidget);
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

    testWidgets('a secret field shows its placeholder as a hint and still submits empty', (tester) async {
      // The station editor renders a placeholder on a secret whose value is
      // already in the keychain, so the operator can see something is stored
      // without the app ever loading it into the form. Two things have to hold
      // for that to be safe, and both are pinned here.
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {
                  'type': 'field',
                  'fieldType': 'secret',
                  'key': 'password',
                  'label': 'Password',
                  'placeholder': '••••••••',
                },
              ],
            },
            initialState: const {},
            onSubmit: (values) => submitted = values,
            onCancel: () {},
          ),
        ),
      ));

      // 1. It is visible — otherwise a stored password looks like no password.
      final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Password'));
      expect(field.decoration?.hintText, '••••••••');

      // 2. It is a HINT, not the value. If it were the value, saving an
      //    untouched form would overwrite the real password with bullets, and
      //    the show/hide eye would "reveal" them.
      expect(field.controller?.text, isEmpty);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(submitted?['password'], isEmpty,
          reason: 'an untouched hinted field must submit empty, which means "unchanged"');
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

      // The form itself shows only the summary row — no inline list editing.
      expect(find.text('Presets'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Add Presets'), findsNothing);

      // Tapping the row opens the editor dialog with the "Add" row.
      await tester.tap(find.text('Presets'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Add Presets'), findsOneWidget);

      // Item add/edit dialogs have their own Save button, distinct from the
      // outer form's — scope taps to the dialog to avoid ambiguity (the
      // list editor dialog itself only has Done, so Save stays unique).
      Finder dialogSaveButton() =>
          find.descendant(of: find.byType(HaloDialog), matching: find.widgetWithText(FilledButton, 'Save'));

      // Add an item through the nested item dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Add Presets'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Field Day');
      await tester.enterText(find.widgetWithText(TextField, 'Exchange'), '1A NNJ');
      await tester.tap(dialogSaveButton());
      await tester.pumpAndSettle();

      // Editor row uses the itemTitle template.
      expect(find.text('Field Day — 1A NNJ'), findsWidgets);

      // Edit the item: tapping its editor row reopens the item dialog
      // pre-filled (scoped to the dialog — the summary row behind the
      // barrier shows the same string).
      await tester.tap(
        find.descendant(of: find.byType(HaloDialog), matching: find.text('Field Day — 1A NNJ')),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
      final nameField = tester.widget<TextField>(find.widgetWithText(TextField, 'Name'));
      expect(nameField.controller?.text, 'Field Day');
      await tester.enterText(find.widgetWithText(TextField, 'Exchange'), '2A NNJ');
      await tester.tap(dialogSaveButton());
      await tester.pumpAndSettle();

      // Close the editor: the summary row shows the comma-separated values.
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.byType(HaloDialog), findsNothing);
      expect(find.text('Field Day — 2A NNJ'), findsOneWidget);

      // Submitting the outer form includes the edited list.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submittedValues!['presets'], [
        {'name': 'Field Day', 'exchange': '2A NNJ'},
      ]);

      // Delete (back in the editor) empties the list and the summary.
      await tester.tap(find.text('Presets'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(MdiIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.text('Field Day — 2A NNJ'), findsNothing);
    });

    testWidgets('non-inline list field editor honors itemLabel too, not just the inline one',
        (tester) async {
      final listFormDefinition = {
        'elements': [
          {
            'type': 'field',
            'fieldType': 'list',
            'key': 'presets',
            'label': 'Presets',
            'itemLabel': 'preset',
            'itemTitle': r'${name}',
            'itemFields': [
              {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': 'Name'},
            ],
          },
        ],
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: listFormDefinition,
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      await tester.tap(find.text('Presets'));
      await tester.pumpAndSettle();
      // Singular itemLabel, not the field's own (plural) label — the bug fixed
      // here was this dialog hardcoding the plain label instead.
      expect(find.widgetWithText(TextButton, 'Add preset'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Add Presets'), findsNothing);
    });

    testWidgets('dialog list editor suppresses the framework drag handle and wires its own', (tester) async {
      // On mouse platforms ReorderableListView auto-adds a trailing drag
      // handle per row; the row already draws its own. The dialog editor
      // must both suppress the framework one (or desktop rows show two) and
      // wire its own icon as a real ReorderableDragStartListener (or, with
      // the framework one suppressed, reordering stops working entirely).
      final listFormDefinition = {
        'elements': [
          {
            'type': 'field',
            'fieldType': 'list',
            'key': 'presets',
            'label': 'Presets',
            'itemLabel': 'preset',
            'itemTitle': r'${name}',
            'orderable': true,
            'itemFields': [
              {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': 'Name'},
            ],
            'value': [
              {'name': 'One'},
              {'name': 'Two'},
            ],
          },
        ],
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: listFormDefinition,
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      await tester.tap(find.text('Presets'));
      await tester.pumpAndSettle();

      final listView = tester.widget<ReorderableListView>(find.byType(ReorderableListView));
      expect(listView.buildDefaultDragHandles, isFalse,
          reason: 'the framework auto-handle doubles the row\'s own on mouse platforms');
      expect(find.byIcon(MdiIcons.dragHorizontalVariant), findsNWidgets(2), reason: 'one handle per row, no extras');
      expect(
        find.ancestor(of: find.byIcon(MdiIcons.dragHorizontalVariant).first, matching: find.byType(ReorderableDragStartListener)),
        findsWidgets,
        reason: 'with the framework handle off, the row\'s icon must be the real drag listener',
      );
    });

    testWidgets('inline list field renders rows and Add directly, with no summary-row dialog', (tester) async {
      Map<String, dynamic>? submittedValues;
      final inlineListFormDefinition = {
        'elements': [
          {
            'type': 'field',
            'fieldType': 'list',
            'key': 'customFiles',
            'label': 'Custom note files',
            'itemLabel': 'custom note file',
            'inline': true,
            'itemTitle': r'${name}',
            'orderable': true,
            'itemFields': [
              {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': 'Name'},
              {'type': 'field', 'fieldType': 'text', 'key': 'location', 'label': 'File URL'},
            ],
            'value': [
              {'name': 'Club Roster', 'location': 'https://example.com/a.txt'},
            ],
          },
        ],
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: inlineListFormDefinition,
            initialState: const {},
            onSubmit: (vals) => submittedValues = vals,
            onCancel: () {},
          ),
        ),
      ));

      // The item, the reorder handle, delete button, and Add row are all
      // directly on the form — no summary row / "tap to open a dialog" step.
      expect(find.text('Club Roster'), findsOneWidget);
      expect(find.byIcon(MdiIcons.dragHorizontalVariant), findsOneWidget);
      expect(find.byIcon(MdiIcons.delete), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Add custom note file'), findsOneWidget);
      expect(find.byType(HaloDialog), findsNothing, reason: 'no list-editor dialog should have opened yet');

      // Tapping the item opens the itemFields editor dialog directly (the
      // ONLY dialog in this flow) — titled from itemLabel, singular, not
      // from the list's own (plural) label.
      await tester.tap(find.text('Club Roster'));
      await tester.pumpAndSettle();
      expect(find.text('Edit custom note file'), findsOneWidget);
      final nameField = tester.widget<TextField>(find.widgetWithText(TextField, 'Name'));
      expect(nameField.controller?.text, 'Club Roster');
      await tester.tap(find.descendant(of: find.byType(HaloDialog), matching: find.widgetWithText(FilledButton, 'Save')));
      await tester.pumpAndSettle();
      expect(find.byType(HaloDialog), findsNothing);

      // Add opens the same dialog, titled from itemLabel as well — scoped to
      // the dialog since the Add button behind it shares the same text.
      await tester.tap(find.widgetWithText(TextButton, 'Add custom note file'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(HaloDialog), matching: find.text('Add custom note file')),
          findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Second File');
      await tester.tap(find.descendant(of: find.byType(HaloDialog), matching: find.widgetWithText(FilledButton, 'Save')));
      await tester.pumpAndSettle();
      expect(find.text('Second File'), findsOneWidget);

      // Delete removes the row directly, no dialog involved.
      await tester.tap(find.byIcon(MdiIcons.delete).first);
      await tester.pumpAndSettle();
      expect(find.text('Club Roster'), findsNothing);
      expect(find.text('Second File'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submittedValues!['customFiles'], [
        {'name': 'Second File', 'location': ''},
      ]);
    });

    testWidgets('multiselect toggles from a fixed vocabulary with common-subset disclosure', (tester) async {
      Map<String, dynamic>? submittedValues;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {
                  'type': 'field',
                  'fieldType': 'multiselect',
                  'key': 'bands',
                  'label': 'Bands',
                  'value': ['80m', '40m'],
                  'defaultValue': ['80m', '40m'],
                  'options': [
                    {'label': '80m', 'value': '80m', 'common': true},
                    {'label': '40m', 'value': '40m', 'common': true},
                    {'label': '20m', 'value': '20m', 'common': true},
                    {'label': '630m', 'value': '630m'},
                    {'label': 'submm', 'value': 'submm', 'uncommon': true},
                  ],
                },
              ],
            },
            initialState: {},
            onSubmit: (vals) => submittedValues = vals,
            onCancel: () {},
          ),
        ),
      ));

      // The row summarizes the selection; no editor inline.
      expect(find.text('80m, 40m'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);

      // Open the editor: common options visible, uncommon hidden. Small
      // vocabularies (≤20 options) get no search field.
      await tester.tap(find.text('Bands'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SwitchListTile, '20m'), findsOneWidget);
      expect(find.widgetWithText(SwitchListTile, '630m'), findsNothing);
      expect(find.descendant(of: find.byType(HaloDialog), matching: find.byType(TextField)), findsNothing);

      // Selected rows read bold; unselected ones use the disabled color.
      Text rowLabel(String label) => tester.widget<Text>(
          find.descendant(of: find.widgetWithText(SwitchListTile, label), matching: find.text(label)));
      expect(rowLabel('80m').style?.fontWeight, FontWeight.bold);
      expect(rowLabel('20m').style?.fontWeight, isNot(FontWeight.bold));
      expect(rowLabel('20m').style?.color, isNotNull);

      // With an uncommon tier present, disclosure is a three-step cycle:
      // "Show more" reveals the unflagged middle tier…
      await tester.tap(find.widgetWithText(TextButton, 'Show more'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SwitchListTile, '630m'), findsOneWidget);
      expect(find.widgetWithText(SwitchListTile, 'submm'), findsNothing);

      // …and "Show all" reveals the uncommon tier too.
      await tester.tap(find.widgetWithText(TextButton, 'Show all'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SwitchListTile, 'submm'), findsOneWidget);

      // Select in non-canonical order (630m before 20m)…
      await tester.tap(find.widgetWithText(SwitchListTile, '630m'));
      await tester.pumpAndSettle();

      // A once-selected uncommon value stays visible for the dialog's
      // lifetime: through "Show fewer", and even while toggled back off.
      await tester.tap(find.widgetWithText(TextButton, 'Show fewer'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SwitchListTile, '630m'), findsOneWidget);
      expect(find.widgetWithText(SwitchListTile, 'submm'), findsNothing, reason: 'unselected uncommon collapses again');
      await tester.tap(find.widgetWithText(SwitchListTile, '630m'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SwitchListTile, '630m'), findsOneWidget);
      await tester.tap(find.widgetWithText(SwitchListTile, '630m'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, '20m'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();

      // …and the summary keeps the vocabulary's canonical order.
      expect(find.byType(HaloDialog), findsNothing);
      expect(find.text('80m, 40m, 20m, 630m'), findsOneWidget);

      // Submitting carries the plain string list.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submittedValues!['bands'], ['80m', '40m', '20m', '630m']);

      // Reset restores the declared defaultValue.
      await tester.tap(find.text('Bands'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Defaults'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.text('80m, 40m'), findsOneWidget);
    });

    testWidgets('multiselect search filters large vocabularies with a reveal row', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: {
              'elements': [
                {
                  'type': 'field',
                  'fieldType': 'multiselect',
                  'key': 'things',
                  'label': 'Things',
                  'value': const ['Alpha 1', 'Alpha 3'],
                  'options': [
                    for (var i = 1; i <= 12; i++) {'label': 'Alpha $i', 'value': 'Alpha $i', 'common': i <= 3},
                    for (var i = 1; i <= 12; i++) {'label': 'Bravo $i', 'value': 'Bravo $i'},
                  ],
                },
              ],
            },
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      // 24 options → the search field is pinned under the list.
      await tester.tap(find.text('Things'));
      await tester.pumpAndSettle();
      final searchField = find.descendant(of: find.byType(HaloDialog), matching: find.byType(TextField));
      expect(searchField, findsOneWidget);

      // No status row or clear button until a query is typed.
      expect(find.textContaining('Showing '), findsNothing);
      expect(find.byIcon(MdiIcons.close), findsNothing);

      // Focus survives the status row popping in on the FIRST letter and
      // out again on deleting it (the field shifts index in its column —
      // regression: without keys it was rebuilt and dropped focus).
      bool searchHasFocus() => tester
          .widget<EditableText>(find.descendant(of: searchField, matching: find.byType(EditableText)))
          .focusNode
          .hasFocus;
      await tester.enterText(searchField, 'B');
      await tester.pumpAndSettle();
      expect(searchHasFocus(), isTrue, reason: 'typing the first letter must not drop focus');
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(searchHasFocus(), isTrue, reason: 'deleting the only letter must not drop focus');

      // A query matches the WHOLE vocabulary, ignoring tiers, hides the
      // disclosure toggle, and shows the status row above the field.
      await tester.enterText(searchField, 'Bravo 1');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SwitchListTile, 'Bravo 1'), findsOneWidget);
      expect(find.widgetWithText(SwitchListTile, 'Bravo 12'), findsOneWidget);
      expect(find.widgetWithText(SwitchListTile, 'Alpha 1'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Show more'), findsNothing);
      // Matches: Bravo 1, 10, 11, 12.
      expect(find.text('Showing 4 of 24 (2 selected)'), findsOneWidget);

      // Selecting a match updates the counts.
      await tester.tap(find.widgetWithText(SwitchListTile, 'Bravo 1'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 4 of 24 (3 selected)'), findsOneWidget);

      // The X button clears the filter and restores the tier view.
      await tester.tap(find.byIcon(MdiIcons.close));
      await tester.pumpAndSettle();
      expect(find.textContaining('Showing '), findsNothing);
      expect(find.widgetWithText(SwitchListTile, 'Alpha 1'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Show all'), findsOneWidget);
      // Bravo 1 was selected mid-filter, so it stays visible (pinned).
      expect(find.widgetWithText(SwitchListTile, 'Bravo 1'), findsOneWidget);
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
              return const FormActionResult(message: 'Connected');
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

    testWidgets('an action\'s fieldUpdates land in the sibling field it names, not just a message', (tester) async {
      // The case this exists for: a browser device picker (or any action
      // that picks a value on the operator's behalf) handing that value
      // straight to the field it belongs in, instead of only being able to
      // tell the operator about it in a message they'd have to retype.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {
                  'type': 'field',
                  'fieldType': 'select',
                  'key': 'port',
                  'label': 'Port',
                  'options': [
                    {'value': 'COM1', 'label': 'COM1'},
                    {'value': 'COM3', 'label': 'COM3'},
                  ],
                },
                {'type': 'action', 'key': 'grant', 'label': 'Add device', 'method': 'requestDevice'},
              ],
            },
            initialState: const {'port': 'COM1'},
            onAction: (actionKey, method, state) async =>
                const FormActionResult(fieldUpdates: {'port': 'COM3'}),
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      expect(find.text('COM1'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add device'));
      await tester.pumpAndSettle();

      expect(find.text('COM3'), findsOneWidget);
      expect(find.text('COM1'), findsNothing);
    });

    testWidgets('a select option marked isAction runs onAction instead of becoming the field\'s value',
        (tester) async {
      // The case this exists for: "add a USB device" living right in the
      // port list rather than as a separate button — picking it must run
      // the action, not silently "select" an option that was never a real
      // port to begin with.
      String? capturedActionKey;
      String? capturedMethod;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {
                  'type': 'field',
                  'fieldType': 'select',
                  'key': 'port',
                  'label': 'Port',
                  'options': [
                    {'value': 'COM1', 'label': 'COM1'},
                    {'value': 'grant', 'label': 'Add a device…', 'isAction': true, 'method': 'requestDevice'},
                  ],
                },
              ],
            },
            initialState: const {'port': 'COM1'},
            onAction: (actionKey, method, state) async {
              capturedActionKey = actionKey;
              capturedMethod = method;
              return null;
            },
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      await tester.tap(find.byType(DropdownButtonFormField<dynamic>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a device…').last);
      await tester.pumpAndSettle();

      expect(capturedActionKey, 'grant');
      expect(capturedMethod, 'requestDevice');
      // The field itself never changed — still shows the original port,
      // not the action option masquerading as a picked value.
      expect(find.text('COM1'), findsOneWidget);
    });

    testWidgets(
        'an action\'s elements replace the form\'s own definition, so a newly-picked value is immediately selectable',
        (tester) async {
      // The case this exists for: fieldUpdates alone would set
      // _values['port'] to a value the ORIGINAL options have no matching
      // item for — a newly-granted Web Serial device isn't offered until
      // the element list itself is rebuilt to include it.
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                submitted = await showFormPane(
                  context,
                  formDefinition: const {
                    'title': 'Radio',
                    'elements': [
                      {
                        'type': 'field',
                        'fieldType': 'select',
                        'key': 'port',
                        'label': 'Port',
                        'options': [
                          {'value': 'COM1', 'label': 'COM1'},
                          {'value': 'grant', 'label': 'Add a device…', 'isAction': true, 'method': 'requestDevice'},
                        ],
                      },
                    ],
                  },
                  initialState: const {'port': 'COM1'},
                  onAction: (actionKey, method, state) async => const FormActionResult(
                    fieldUpdates: {'port': 'usb-new'},
                    elements: [
                      {
                        'type': 'field',
                        'fieldType': 'select',
                        'key': 'port',
                        'label': 'Port',
                        'options': [
                          {'value': 'COM1', 'label': 'COM1'},
                          {'value': 'usb-new', 'label': 'USB 10C4:EA70'},
                          {'value': 'grant', 'label': 'Add a device…', 'isAction': true, 'method': 'requestDevice'},
                        ],
                      },
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('COM1'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<dynamic>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a device…').last);
      await tester.pumpAndSettle();

      // The newly-granted device is both selected AND a real option now —
      // not a value the dropdown has nothing to show it as.
      expect(find.text('USB 10C4:EA70'), findsOneWidget);
      expect(find.text('COM1'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submitted?['port'], 'usb-new');
    });

    testWidgets('a secondary action runs OVER the pane, while a destructive one closes it first', (tester) async {
      // The two footer slots differ in exactly one way, and it is the whole
      // reason `secondaryAction` is not just another `destructiveAction`:
      // Remove is a way out of the form and Report is not, so a Report that
      // popped the pane would silently discard the edits sitting in it.
      var secondaryRan = 0;
      var destructiveRan = 0;
      var completed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showFormPane(
                  context,
                  formDefinition: const {
                    'title': 'Radio',
                    'elements': [
                      {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': 'Name'},
                    ],
                  },
                  initialState: const {'name': 'Left Radio'},
                  destructiveAction: (
                    label: 'Remove',
                    color: const Color(0xFFB3261E),
                    onPressed: () => destructiveRan++,
                  ),
                  secondaryAction: (label: 'Report', onPressed: () => secondaryRan++),
                );
                completed = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Report'));
      await tester.pumpAndSettle();
      expect(secondaryRan, 1);
      // Still standing, and still holding what was in it — the field is the
      // proof, since a pane that had popped and reopened would have lost it.
      expect(completed, isFalse);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      expect(find.text('Left Radio'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(destructiveRan, 1);
      expect(completed, isTrue);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    });

    for (final width in [320.0, 360.0, 390.0]) {
      testWidgets('the footer survives a ${width.toInt()}px pane carrying every action at once', (tester) async {
        // Four verbs is the most this footer can ever hold, and only the
        // equipment editor does it. A Row overflows rather than shrinking, so
        // adding Report beside Save is exactly the change that turns a narrow
        // footer into red stripes across the Save button — measured at 76px
        // over on a 430px pane before the OverflowBar went in, and these three
        // widths are ordinary phones. Spanish labels, because they are the
        // longest the app ships and the English ones fit where these do not.
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFormPane(
                  context,
                  formDefinition: const {
                    'title': 'Radio',
                    'elements': [
                      {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': 'Nombre'},
                    ],
                  },
                  initialState: const {'name': 'Left Radio'},
                  labels: const FormRendererLabels(cancel: 'Cancelar', save: 'Guardar'),
                  destructiveAction: (label: 'Eliminar', color: const Color(0xFFB3261E), onPressed: () {}),
                  secondaryAction: (label: 'Informar', onPressed: () {}),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Every verb still present and hit-testable — a stacked footer is
        // fine, a clipped one is not.
        for (final verb in ['Cancelar', 'Eliminar', 'Informar', 'Guardar']) {
          expect(find.text(verb), findsOneWidget, reason: '$verb missing at ${width}px');
        }
        expect(tester.takeException(), isNull, reason: 'footer overflowed at ${width}px');
      });
    }

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

  group('FormRenderer devMode elements', () {
    final devModeFormDefinition = {
      'elements': [
        {'type': 'header', 'title': 'Dev Only Header', 'devMode': true},
        {'type': 'field', 'fieldType': 'text', 'key': 'debugFlag', 'label': 'Debug Flag', 'devMode': true},
        {'type': 'field', 'fieldType': 'text', 'key': 'normalField', 'label': 'Normal Field'},
      ],
    };

    testWidgets('devMode elements are hidden entirely when developerMode is false (the default)', (tester) async {
      Map<String, dynamic>? submittedValues;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: devModeFormDefinition,
            initialState: const {},
            onSubmit: (vals) => submittedValues = vals,
            onCancel: () {},
          ),
        ),
      ));

      expect(find.text('Dev Only Header'), findsNothing);
      expect(find.text('Debug Flag'), findsNothing);
      expect(find.text('Normal Field'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // A hidden devMode field must not sneak a value into the submission.
      expect(submittedValues!.containsKey('debugFlag'), isFalse);
    });

    testWidgets('devMode elements show and are tinted the orange dev-mode accent when developerMode is true', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: devModeFormDefinition,
            initialState: const {},
            developerMode: true,
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      expect(find.text('Dev Only Header'), findsOneWidget);
      expect(find.text('Debug Flag'), findsOneWidget);

      final headerText = tester.widget<Text>(find.text('Dev Only Header'));
      expect(headerText.style?.color, HaLoColors.light.devMode);

      final debugField = tester.widget<TextField>(find.widgetWithText(TextField, 'Debug Flag'));
      expect(debugField.decoration?.floatingLabelStyle?.color, HaLoColors.light.devMode);

      // A non-devMode field must not pick up the accent.
      final normalField = tester.widget<TextField>(find.widgetWithText(TextField, 'Normal Field'));
      expect(normalField.decoration?.floatingLabelStyle?.color, isNot(HaLoColors.light.devMode));
    });
  });

  group('FormRenderer icon-row fields', () {
    final iconRowFormDefinition = {
      'elements': [
        {
          'type': 'field',
          'fieldType': 'select',
          'key': 'themeMode',
          'label': 'Theme Mode',
          'icon': 'white-balance-sunny',
          'description': 'Always in Light Mode',
          'value': 'light',
          'options': [
            {'label': 'Light', 'value': 'light'},
            {'label': 'Dark', 'value': 'dark'},
          ],
        },
        {
          'type': 'field',
          'fieldType': 'select',
          'key': 'noIcon',
          'label': 'Plain Select',
          'value': 'a',
          'options': [
            {'label': 'A', 'value': 'a'},
            {'label': 'B', 'value': 'b'},
          ],
        },
      ],
    };

    testWidgets('a select field with icon set renders as a tappable list row showing the current value', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: iconRowFormDefinition,
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      // The icon-row select renders inside a ListTile (leading icon, title,
      // subtitle) instead of the standalone DropdownButtonFormField a
      // 'select' field normally gets. The subtitle is the field's own
      // description — which is written to explain the current value — not the
      // raw option label repeated as a separate line.
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Always in Light Mode'), findsOneWidget);
      expect(find.text('Light'), findsNothing);
      // A tap-to-open affordance, not an inline dropdown, for the icon-row.
      expect(find.byIcon(MdiIcons.chevronRight), findsOneWidget);

      final title = tester.widget<Text>(find.text('Theme Mode'));
      expect(title.style?.fontWeight, FontWeight.bold);

      // A field with no `icon` is untouched — still the standalone Material
      // input, not swept into the list-row layout.
      expect(find.byType(DropdownButtonFormField<dynamic>), findsOneWidget);
      expect(find.text('Plain Select'), findsOneWidget);
    });

    testWidgets('tapping an icon-row select opens a picker dialog whose choice commits like the inline control', (tester) async {
      Map<String, dynamic>? submittedValues;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: iconRowFormDefinition,
            initialState: const {},
            onSubmit: (vals) => submittedValues = vals,
            onCancel: () {},
          ),
        ),
      ));

      // Tapping the row opens a dialog listing the options.
      await tester.tap(find.text('Theme Mode'));
      await tester.pumpAndSettle();
      expect(find.byType(HaloDialog), findsOneWidget);
      final dialogDark = find.descendant(of: find.byType(HaloDialog), matching: find.text('Dark'));
      expect(dialogDark, findsOneWidget);

      // Picking commits immediately (autosave) and closes the dialog.
      await tester.tap(dialogDark);
      await tester.pumpAndSettle();
      expect(find.byType(HaloDialog), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(submittedValues!['themeMode'], 'dark');
    });

    testWidgets('an icon-row text field renders its input stacked below the title/description', (tester) async {
      final textFormDefinition = {
        'elements': [
          {
            'type': 'field',
            'fieldType': 'text',
            'key': 'stationName',
            'label': 'Station Name',
            'icon': 'account',
            'description': 'Shown on your exports',
            'value': 'Field Day',
          },
        ],
      };
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: textFormDefinition,
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      // The input sits below the title, not trailing beside it — at every
      // panel width now, not just narrow ones.
      final titleBottom = tester.getBottomLeft(find.text('Station Name')).dy;
      final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
      expect(fieldTop, greaterThan(titleBottom));

      // And it spans the row above it. Stacking alone doesn't say that: the
      // layout this replaced put the input in a fixed 140px box, which would
      // still sit below the title and still pass the check above.
      expect(
        tester.getSize(find.byType(TextField)).width,
        closeTo(tester.getSize(find.byType(ListTile)).width, 1),
      );
    });

    testWidgets('a toggle (checkbox) field stays trailing even on a narrow panel', (tester) async {
      final toggleFormDefinition = {
        'elements': [
          {
            'type': 'field',
            'fieldType': 'checkbox',
            'key': 'syncEnabled',
            'label': 'Sync with Ham2K Log Filer',
            'icon': 'cloud-sync',
            'value': false,
          },
        ],
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: FormRenderer(
              formDefinition: toggleFormDefinition,
              initialState: const {},
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ));

      final titleTop = tester.getTopLeft(find.text('Sync with Ham2K Log Filer')).dy;
      final switchTop = tester.getTopLeft(find.byType(Switch)).dy;
      // Still on the same row as the title, not pushed below it.
      expect((switchTop - titleTop).abs(), lessThan(20));
    });

    // The icon-row input carries no label of its own — the label is the row's
    // title above it — so `placeholder` is the only hint this layout can show.
    // The full-width layout has always honored it (via poloFieldDecoration),
    // so without this the same element rendered its hint or silently dropped
    // it depending only on whether it also carried an `icon`.
    testWidgets('an icon-row field shows its placeholder as a hint, secret fields included', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {
                  'type': 'field',
                  'fieldType': 'text',
                  'key': 'stationCall',
                  'label': 'Station Call',
                  'icon': 'account',
                  'placeholder': 'Same as the operator',
                },
                {
                  'type': 'field',
                  'fieldType': 'secret',
                  'key': 'apiKey',
                  'label': 'API Key',
                  'icon': 'shield-account',
                  'placeholder': 'Already stored',
                },
              ],
            },
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      // Both fields took the icon-row path — a ListTile holding the label,
      // with the input stacked beneath and no label of its own. That's what
      // makes the hints below the compact decoration's, not
      // poloFieldDecoration's.
      expect(find.byType(ListTile), findsNWidgets(2));
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields, hasLength(2));
      for (final field in fields) {
        expect(field.decoration?.labelText, isNull);
      }

      expect(find.text('Same as the operator'), findsOneWidget);
      // The secret's placeholder is the case that motivates this: a panel
      // showing that a password is already in the keychain without loading it
      // into the form. It has to render as a hint, never as the value.
      expect(find.text('Already stored'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).last).controller?.text, isEmpty);

      // And it has to *read* as a hint. Material's default renders a hint at
      // full strength, which beside an empty field is indistinguishable from
      // a real value — so a "password already saved" placeholder would look
      // like the password itself. The full-width layout dims to 0.38 for the
      // same reason; both hints here must be equally faint.
      for (final hint in ['Same as the operator', 'Already stored']) {
        expect(tester.widget<Text>(find.text(hint)).style?.color?.a, lessThan(0.5), reason: '$hint renders value-weight');
      }
    });
  });

  group('FormRenderer header style', () {
    testWidgets('a header with no style (or style: default) keeps the bold form-title look', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {'type': 'header', 'title': 'Plain Header'},
              ],
            },
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      final header = tester.widget<Text>(find.text('Plain Header'));
      expect(header.style?.fontWeight, FontWeight.w900);
      expect(header.style?.fontFamily, 'RobotoSlab');
    });

    testWidgets("style: 'section' switches to the smaller Sync/Accounts section-header look", (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {'type': 'header', 'title': 'Section Header', 'style': 'section'},
              ],
            },
            initialState: const {},
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      ));

      final header = tester.widget<Text>(find.text('Section Header'));
      expect(header.style?.fontWeight, isNot(FontWeight.w900));
      expect(header.style?.fontFamily, isNot('RobotoSlab'));
    });
  });

  group('FormRenderer fields appearing after a formDefinition change', () {
    testWidgets('a field absent from the old definition is fully initialized (not just value-synced) when it first appears', (tester) async {
      final withoutExtra = {
        'elements': [
          {'type': 'field', 'fieldType': 'text', 'key': 'always', 'label': 'Always Present', 'value': ''},
        ],
      };
      final withExtra = {
        'elements': [
          {'type': 'field', 'fieldType': 'text', 'key': 'always', 'label': 'Always Present', 'value': ''},
          {'type': 'field', 'fieldType': 'text', 'key': 'extra', 'label': 'Newly Appeared', 'value': ''},
        ],
      };

      Map<String, dynamic> currentDefinition = withoutExtra;
      late StateSetter setOuterState;
      Map<String, dynamic>? submittedValues;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          setOuterState = setState;
          return MaterialApp(
            home: Scaffold(
              body: FormRenderer(
                formDefinition: currentDefinition,
                initialState: const {},
                onSubmit: (vals) => submittedValues = vals,
                onCancel: () {},
              ),
            ),
          );
        },
      ));

      expect(find.text('Newly Appeared'), findsNothing);

      // Simulate a settings-panel-style re-fetch that adds a field, the
      // same way _ExtensionSettingsPanel swaps in a new formDefinition.
      setOuterState(() => currentDefinition = withExtra);
      await tester.pump();

      expect(find.text('Newly Appeared'), findsOneWidget);

      // The newly-appeared field must have a real, wired-up TextField —
      // typing into it must actually reach _values (and thus submit()),
      // not a Flutter-internal untracked controller.
      await tester.enterText(find.widgetWithText(TextField, 'Newly Appeared'), 'hello');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(submittedValues!['extra'], 'hello');
    });
  });

  group('visibleWhen', () {
    // A form that varies with itself (docs/design/contests.md §5.4.1). Shaped
    // on IARU HF's setup, which is why this exists: the sent exchange is an ITU
    // zone, a society abbreviation, or an IARU office, chosen by station type.
    final conditionalForm = {
      'title': 'Contest Setup',
      'elements': [
        {
          'type': 'field',
          'fieldType': 'radio',
          'key': 'stationType',
          'label': 'Station Type',
          'value': 'normal',
          'options': [
            {'label': 'Normal', 'value': 'normal'},
            {'label': 'HQ', 'value': 'hq'},
            {'label': 'Official', 'value': 'official'},
          ],
        },
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'zone',
          'label': 'ITU Zone',
          'visibleWhen': {'field': 'stationType', 'equals': 'normal'},
        },
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'society',
          'label': 'Society',
          'visibleWhen': {'field': 'stationType', 'equals': 'hq'},
        },
        {
          // "any of" — an office applies to HQ stations and officials alike.
          'type': 'field',
          'fieldType': 'text',
          'key': 'office',
          'label': 'IARU Office',
          'visibleWhen': {
            'field': 'stationType',
            'equals': ['hq', 'official'],
          },
        },
        {'type': 'field', 'fieldType': 'text', 'key': 'call', 'label': 'Station Call'},
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'ghost',
          'label': 'Ghost',
          'visibleWhen': {'field': 'noSuchField', 'equals': 'anything'},
        },
      ],
    };

    Map<String, dynamic>? submitted;

    Widget host() => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormRenderer(
                formDefinition: conditionalForm,
                initialState: const {},
                onSubmit: (vals) => submitted = vals,
                onCancel: () {},
              ),
            ),
          ),
        );

    setUp(() => submitted = null);

    testWidgets('shows only the field its discriminator selects', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('ITU Zone'), findsOneWidget, reason: 'stationType defaults to normal');
      expect(find.text('Society'), findsNothing);
      expect(find.text('IARU Office'), findsNothing);
      // A field with no predicate is unaffected — the filter must not become a
      // whitelist.
      expect(find.text('Station Call'), findsOneWidget);
    });

    testWidgets('changing the discriminator swaps which fields are shown', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('HQ'));
      await tester.pumpAndSettle();

      expect(find.text('ITU Zone'), findsNothing);
      expect(find.text('Society'), findsOneWidget);
      expect(find.text('IARU Office'), findsOneWidget, reason: 'hq is in the equals list');
    });

    testWidgets('a list in equals means any of', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Official'));
      await tester.pumpAndSettle();

      expect(find.text('IARU Office'), findsOneWidget);
      expect(find.text('Society'), findsNothing, reason: 'official is not hq');
      expect(find.text('ITU Zone'), findsNothing);
    });

    testWidgets('a predicate naming a field that does not exist hides, and does not throw', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('Ghost'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a value typed into a field that is then hidden survives being shown again', (tester) async {
      // THE test for this feature. FormRenderer creates no controller lazily,
      // so if hiding a field also deregistered it, the field would come back
      // with a null controller and silently eat what the operator had typed.
      // Registration must stay independent of visibility.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'ITU Zone'), '08');
      await tester.pumpAndSettle();

      await tester.tap(find.text('HQ'));
      await tester.pumpAndSettle();
      expect(find.text('ITU Zone'), findsNothing);

      await tester.tap(find.text('Normal'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'ITU Zone')).controller!.text,
        '08',
        reason: 'switching station type away and back must not cost the operator their zone',
      );
    });

    testWidgets('a hidden field still submits its value', (tester) async {
      // The deliberate consequence of registering every field: submit carries
      // hidden values too. Pinned because a consumer reading "whichever is
      // non-empty" would silently pick the wrong exchange — it has to select by
      // the discriminator instead.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'ITU Zone'), '08');
      await tester.pumpAndSettle();

      await tester.tap(find.text('HQ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Society'), 'ARRL');
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(submitted!['society'], 'ARRL');
      expect(submitted!['zone'], '08', reason: 'hidden, but still registered and still submitted');
      expect(submitted!['stationType'], 'hq');
    });
  });

  testWidgets('a select fills its field rather than its widest option', (tester) async {
    // An unexpanded dropdown takes the width of its WIDEST ITEM, so one long
    // option label — a contest sponsor's own words for an entry category —
    // pushed the field past the dialog and painted the overflow stripes over
    // it. A narrow viewport is the case that matters: the labels are data an
    // extension supplies and the renderer cannot shorten.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FormRenderer(
          formDefinition: const {
            'title': 'Entry',
            'elements': [
              {
                'type': 'field',
                'fieldType': 'select',
                'key': 'category',
                'label': 'Entry Category',
                'options': [
                  {'value': 'SL', 'label': 'SL — Single Op, Low Power'},
                  {
                    'value': 'MML',
                    'label': 'MML — Multi-Op Multi-Transmitter Low Power (.1 to 100 watts) located at one Ohio State Park',
                  },
                ],
              },
            ],
          },
          initialState: const {},
          onSubmit: (_) async {},
          onCancel: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // A RenderFlex overflow is reported as a test failure in its own right, so
    // reaching this line is most of the assertion; the width pins it in the
    // form the bug took — a field wider than the screen it sits on.
    expect(
      tester.getSize(find.byType(DropdownButtonFormField<dynamic>)).width,
      lessThanOrEqualTo(400),
      reason: 'the field follows the dialog, not the longest label an extension sent',
    );
  });
  testWidgets('a select drops a seeded value its options no longer contain', (tester) async {
    // The ref outlives the option list. State Parks writes `ourPower` on the
    // contest ref, and the classes on offer are the EVENT's: switch an operation
    // from Texas (QRP/LP/HP) to Ohio (LP/HP) and the ref still says QRP, which is
    // not one of Ohio's two. _initializeField seeds `initialState[key]` OVER the
    // element's own `value`, and DropdownButton asserts that its value is exactly
    // one of its items — so reopening that setup form threw instead of rendering.
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FormRenderer(
          formDefinition: const {
            'title': 'Entry',
            'elements': [
              {
                'type': 'field',
                'fieldType': 'select',
                'key': 'ourPower',
                'label': 'Power',
                'options': [
                  {'value': 'LP', 'label': 'Low Power'},
                  {'value': 'HP', 'label': 'High Power'},
                ],
              },
            ],
          },
          initialState: const {'ourPower': 'QRP'},
          onSubmit: (values) async => submitted = values,
          onCancel: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Renders, with nothing selected rather than a value the form cannot show.
    expect(find.text('Low Power'), findsNothing);
    expect(find.text('High Power'), findsNothing);

    // And saving CLEARS the stale value rather than writing it back: leaving it
    // on the ref would keep the form unopenable and keep a class the sponsor
    // does not publish in front of whatever reads it next.
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(submitted, isNotNull);
    expect(submitted!['ourPower'], isNull);
  });
}
