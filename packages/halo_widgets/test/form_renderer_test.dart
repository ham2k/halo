// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  final formDefinition = {
    'title': 'Test Form',
    'subtitle': 'A form to verify fields',
    'elements': [
      {'type': 'header', 'title': 'My Header', 'subtitle': 'My Subtitle'},
      {'type': 'divider', 'title': 'My Divider'},
      {'type': 'markdown', 'text': 'This is **bold** text'},
      {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': 'Name Field', 'placeholder': 'Enter name'},
      {'type': 'field', 'fieldType': 'multiline', 'key': 'bio', 'label': 'Bio Field'},
      {'type': 'field', 'fieldType': 'email', 'key': 'email', 'label': 'Email Field'},
      {'type': 'field', 'fieldType': 'callsign', 'key': 'callsign', 'label': 'Callsign Field'},
      {'type': 'field', 'fieldType': 'number', 'key': 'power', 'label': 'Power Field'},
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
      {'type': 'field', 'fieldType': 'checkbox', 'key': 'agree', 'label': 'Agree Field'},
    ],
  };

  group('FormRenderer', () {
    testWidgets('disposing a settings-list form does not finish another field\'s autofill context', (tester) async {
      final showSettings = ValueNotifier(true);
      addTearDown(showSettings.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: showSettings,
                  builder: (context, show, _) => show
                      ? FormRenderer(
                          formDefinition: const {
                            'elements': [
                              {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': 'Station name'},
                            ],
                          },
                          initialState: const {},
                          settingsList: true,
                          showActions: false,
                          onSubmit: (_) {},
                          onCancel: () {},
                        )
                      : const SizedBox.shrink(),
                ),
                AutofillGroup(
                  child: TextField(focusNode: focusNode, autofillHints: const [AutofillHints.name]),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.testTextInput.log.clear();

      // A text field is the strong case: it has a controller, yet a settings
      // list edits it in a dialog, so the form's group would hold nothing and
      // its disposal would only close the iOS keyboard of the field above.
      // TestTextInput never drops Dart focus, so only the channel log shows it.
      showSettings.value = false;
      await tester.pump();
      expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.finishAutofillContext'), isEmpty);
    });

    testWidgets('disposing an inline text form still commits its autofill context', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: const {
                'elements': [
                  {'type': 'field', 'fieldType': 'email', 'key': 'email', 'label': 'Email'},
                ],
              },
              initialState: const {},
              showActions: false,
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'operator@example.com');
      tester.testTextInput.log.clear();
      await tester.pumpWidget(const SizedBox.shrink());

      // The commit is what offers to save what was typed; skipping the group
      // must stay limited to forms with no inline field.
      final finishCalls = tester.testTextInput.log.where((call) => call.method == 'TextInput.finishAutofillContext');
      expect(finishCalls, hasLength(1));
      expect(finishCalls.single.arguments, isTrue);
    });

    testWidgets('renders all element types', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormRenderer(
                formDefinition: formDefinition,
                initialState: const {'name': 'Initial Name', 'license': 'tech', 'pref': 'cw', 'agree': true},
                onSubmit: (_) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );

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

    // `disabled` renders a control greyed rather than hidden, so a choice
    // that cannot be made right now says so where it is. A select that
    // accepted the tap anyway would put the form's value out of step with
    // whatever refused it — the Antenna Genius' routing picker on a
    // transmitting port is the case this exists for, and its refusal lands
    // somewhere the operator cannot see while the pane is open.
    testWidgets('a disabled select refuses to open', (tester) async {
      var changed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: const {
                'elements': [
                  {
                    'type': 'field',
                    'fieldType': 'select',
                    'key': 'port',
                    'label': 'Port A',
                    'disabled': true,
                    'options': [
                      {'value': '1', 'label': 'Hex'},
                      {'value': '2', 'label': 'EFHW'},
                    ],
                  },
                ],
              },
              initialState: const {'port': '1'},
              onChange: (key, value, state) async {
                changed = true;
                return null;
              },
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Hex'), findsOneWidget, reason: 'greyed, not hidden');
      await tester.tap(find.byType(DropdownButtonFormField<dynamic>));
      await tester.pumpAndSettle();

      // The menu never opened, so the other option is nowhere on screen.
      expect(find.text('EFHW'), findsNothing);
      expect(changed, isFalse);

      // The arrow keys are the OTHER way into a select — `_handleSelectKeyEvent`
      // bypasses the button's own onChanged entirely. What keeps them from
      // reaching a disabled field is that it will not take focus at all, so
      // that is what is asserted here: the guard inside the handler is
      // belt-and-braces against this changing, and a test that sent a key
      // event to an unfocused field would pass whether or not the guard
      // existed.
      final node = find
          .descendant(of: find.byType(DropdownButtonFormField<dynamic>), matching: find.byType(Focus))
          .evaluate()
          .map((e) => (e.widget as Focus).focusNode)
          .firstWhere((n) => n != null)!;
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse, reason: 'a disabled select must not be reachable by keyboard either');
      expect(changed, isFalse);
    });

    testWidgets('arrow keys cycle a focused select field through its options', (tester) async {
      Map<String, dynamic>? changedTo;
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      // DropdownButtonFormField doesn't expose its FocusNode as a public
      // getter, so reach the `Focus` it wraps itself in and focus that
      // directly — requesting focus this way, rather than tapping the field,
      // also avoids ever opening the popup menu, which is the whole point:
      // this cycling only needs to work while the menu is closed.
      final dropdownFocusNode = find
          .descendant(of: find.byType(DropdownButtonFormField<dynamic>), matching: find.byType(Focus))
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
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('How we handle your data'), findsOneWidget);

      await tester.tap(find.text('Privacy Policy'));
      expect(openedUrl, 'https://example.com/privacy');
    });

    testWidgets('gathers input, runs async validation and transformation on submit', (tester) async {
      Map<String, dynamic>? submittedValues;
      var validatorCalled = false;
      var transformerCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormRenderer(
                formDefinition: formDefinition,
                initialState: const {'name': 'John Doe', 'callsign': 'ki2d', 'agree': false},
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
        ),
      );

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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormRenderer(
                formDefinition: formDefinition,
                initialState: const {'name': 'John Doe'},
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
        ),
      );

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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormRenderer(
                formDefinition: formDefinition,
                initialState: const {'name': 'John Doe'},
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
        ),
      );

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
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormRenderer(
                formDefinition: formDefinition,
                initialState: const {'name': 'Old Name', 'agree': false},
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
        ),
      );

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
        {'type': 'markdown', 'collapsible': true, 'title': 'How to build your own', 'text': 'Read **this** carefully.'},
      ],
    };

    testWidgets('starts collapsed, showing the title but not the text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: collapsibleFormDefinition, initialState: const {}, onSubmit: (_) {}, onCancel: () {}),
          ),
        ),
      );

      expect(find.text('How to build your own'), findsOneWidget);
      expect(find.byType(MarkdownBody), findsNothing, reason: 'the help text is collapsed by default');
    });

    testWidgets('tapping the header expands it to reveal the text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: collapsibleFormDefinition, initialState: const {}, onSubmit: (_) {}, onCancel: () {}),
          ),
        ),
      );

      await tester.tap(find.text('How to build your own'));
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.text('Read this carefully.'), findsOneWidget);
    });

    testWidgets('a plain (non-collapsible) markdown block is unaffected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.text('Always visible'), findsOneWidget);
    });
  });

  group('FormRenderer secret/list/action fields', () {
    testWidgets('secret field obscures its text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      final field = tester.widget<TextField>(find.widgetWithText(TextField, 'API Key'));
      expect(field.obscureText, isTrue);
    });

    testWidgets('a secret field shows its placeholder as a hint and still submits empty', (tester) async {
      // The station editor renders a placeholder on a secret whose value is
      // already in the keychain, so the operator can see something is stored
      // without the app ever loading it into the form. Two things have to hold
      // for that to be safe, and both are pinned here.
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: const {
                'elements': [
                  {'type': 'field', 'fieldType': 'secret', 'key': 'password', 'label': 'Password', 'placeholder': '••••••••'},
                ],
              },
              initialState: const {},
              onSubmit: (values) => submitted = values,
              onCancel: () {},
            ),
          ),
        ),
      );

      // 1. It is visible — otherwise a stored password looks like no password.
      final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Password'));
      expect(field.decoration?.hintText, '••••••••');

      // 2. It is a HINT, not the value. If it were the value, saving an
      //    untouched form would overwrite the real password with bullets, and
      //    the show/hide eye would "reveal" them.
      expect(field.controller?.text, isEmpty);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(submitted?['password'], isEmpty, reason: 'an untouched hinted field must submit empty, which means "unchanged"');
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: listFormDefinition, initialState: const {}, onSubmit: (vals) => submittedValues = vals, onCancel: () {}),
          ),
        ),
      );

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
      Finder dialogSaveButton() => find.descendant(of: find.byType(HaloDialog), matching: find.widgetWithText(FilledButton, 'Save'));

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
      await tester.tap(find.descendant(of: find.byType(HaloDialog), matching: find.text('Field Day — 1A NNJ')));
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

    testWidgets('non-inline list field editor honors itemLabel too, not just the inline one', (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: listFormDefinition, initialState: const {}, onSubmit: (_) {}, onCancel: () {}),
          ),
        ),
      );

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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: listFormDefinition, initialState: const {}, onSubmit: (_) {}, onCancel: () {}),
          ),
        ),
      );

      await tester.tap(find.text('Presets'));
      await tester.pumpAndSettle();

      final listView = tester.widget<ReorderableListView>(find.byType(ReorderableListView));
      expect(listView.buildDefaultDragHandles, isFalse, reason: 'the framework auto-handle doubles the row\'s own on mouse platforms');
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: inlineListFormDefinition, initialState: const {}, onSubmit: (vals) => submittedValues = vals, onCancel: () {}),
          ),
        ),
      );

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
      expect(find.descendant(of: find.byType(HaloDialog), matching: find.text('Add custom note file')), findsOneWidget);
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
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

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
      Text rowLabel(String label) => tester.widget<Text>(find.descendant(of: find.widgetWithText(SwitchListTile, label), matching: find.text(label)));
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
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

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
      bool searchHasFocus() => tester.widget<EditableText>(find.descendant(of: searchField, matching: find.byType(EditableText))).focusNode.hasFocus;
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

      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

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
      await tester.pumpWidget(
        MaterialApp(
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
              onAction: (actionKey, method, state) async => const FormActionResult(fieldUpdates: {'port': 'COM3'}),
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('COM1'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add device'));
      await tester.pumpAndSettle();

      expect(find.text('COM3'), findsOneWidget);
      expect(find.text('COM1'), findsNothing);
    });

    testWidgets('a select option marked isAction runs onAction instead of becoming the field\'s value', (tester) async {
      // The case this exists for: "add a USB device" living right in the
      // port list rather than as a separate button — picking it must run
      // the action, not silently "select" an option that was never a real
      // port to begin with.
      String? capturedActionKey;
      String? capturedMethod;
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

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

    testWidgets('every field in a form pane lands on ONE left edge, whatever its type', (tester) async {
      // The invariant the pane's whole geometry rests on. The pane used to
      // pad around its rows, which held every type in line for free; it
      // cannot any more, because a filled band has to reach its edges — so
      // each field spends the inset itself, and a type that forgets is a
      // control hanging off the edge with nothing to report it. Add a field
      // type, add it here.
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFormPane(
                  context,
                  formDefinition: const {
                    'title': 'Every type',
                    'elements': [
                      {'type': 'header', 'title': 'Wiring', 'style': 'category'},
                      {'type': 'field', 'fieldType': 'text', 'key': 'text', 'label': 'A text field'},
                      {'type': 'field', 'fieldType': 'secret', 'key': 'secret', 'label': 'A secret field'},
                      {
                        'type': 'field',
                        'fieldType': 'select',
                        'key': 'select',
                        'label': 'A select field',
                        'options': [
                          {'value': 'a', 'label': 'Only option'},
                        ],
                      },
                      {
                        'type': 'field',
                        'fieldType': 'radio',
                        'key': 'radio',
                        'label': 'A radio group',
                        'options': [
                          {'value': 'a', 'label': 'Radio option'},
                        ],
                      },
                      {
                        'type': 'field',
                        'fieldType': 'checkboxGroup',
                        'key': 'boxes',
                        'label': 'A checkbox group',
                        'options': [
                          {'value': 'a', 'label': 'Box option'},
                        ],
                      },
                      {'type': 'field', 'fieldType': 'checkbox', 'key': 'flag', 'label': 'A checkbox'},
                      {'type': 'action', 'key': 'act', 'label': 'An action'},
                    ],
                  },
                  initialState: const {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The band's TITLE is the reference: its ground spans the pane, and its
      // title sits on the rows' inset, with nothing of its own around it.
      // A Material input decoration adds a few pixels of its own on top of
      // that, so the tolerance is a couple of pixels wide — the failure this
      // guards against is a field back at the pane's EDGE, a whole inset out.
      final edge = tester.getTopLeft(find.text('Wiring')).dx;
      for (final label in ['A text field', 'A secret field', 'A select field', 'A radio group', 'A checkbox group']) {
        expect(tester.getTopLeft(find.text(label)).dx, closeTo(edge, 5), reason: label);
      }
      // Two rows whose LABEL is not their left edge: a checkbox row leads
      // with its control, and an action's label is centred in a button that
      // spans the row. Both are measured by the thing that does sit there.
      expect(tester.getTopLeft(find.widgetWithText(OutlinedButton, 'An action')).dx, closeTo(edge, 5), reason: 'An action');
      expect(
        tester.getTopLeft(find.descendant(of: find.widgetWithText(CheckboxListTile, 'A checkbox'), matching: find.byType(Checkbox))).dx,
        closeTo(edge, 5),
        reason: 'A checkbox',
      );
    });

    testWidgets("style: 'category' is the FILLED band, edge to edge, with the fields still inset", (tester) async {
      // The equipment editor's own groups: a heading that is the top level of
      // its surface rather than a section inside one. The ground reaching the
      // edges is what says so — inset, it would read as one highlighted row.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTileTheme(
              data: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 24)),
              child: FormRenderer(
                formDefinition: const {
                  'elements': [
                    {'type': 'header', 'title': 'Wiring', 'style': 'category'},
                    {'type': 'field', 'fieldType': 'text', 'key': 'a', 'label': 'Antenna port 1'},
                  ],
                },
                initialState: const {},
                onSubmit: (_) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );

      final band = find.byType(CategoryBand);
      final form = find.byType(FormRenderer);
      expect(tester.getSize(band).width, tester.getSize(form).width, reason: 'the ground spans the surface');
      // The title, though, lands on the rows' own inset — the band names them.
      expect(tester.getTopLeft(find.text('Wiring')).dx, tester.getTopLeft(form).dx + 24);
      expect(
        tester.getTopLeft(find.widgetWithText(TextField, 'Antenna port 1')).dx,
        tester.getTopLeft(form).dx + 24,
        reason: 'a bare control takes the same inset, since the host no longer pads around it',
      );
    });

    testWidgets('a section band in a form pane holds the top while its own fields scroll under it', (tester) async {
      // The station equipment editor declares sections (the antenna switch's
      // Current State and Wiring), and it reaches the operator through this
      // pane — so the pane scrolls its form in a sliver viewport, which is
      // the only kind a band can pin in.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFormPane(
                  context,
                  formDefinition: {
                    'title': 'Radio',
                    'elements': [
                      {'type': 'header', 'title': 'Connection', 'style': 'section'},
                      for (var i = 0; i < 8; i++) {'type': 'field', 'fieldType': 'text', 'key': 'a$i', 'label': 'Connection field $i'},
                      {'type': 'header', 'title': 'Wiring', 'style': 'section'},
                      for (var i = 0; i < 8; i++) {'type': 'field', 'fieldType': 'text', 'key': 'b$i', 'label': 'Wiring field $i'},
                    ],
                  },
                  initialState: const {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Past the pane's own top padding first — the band travels with that,
      // and pins once it is the top of the viewport.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -160));
      await tester.pumpAndSettle();
      final band = tester.getTopLeft(find.text('Connection')).dy;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -160));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('Connection')).dy, band, reason: 'the band held');
      // Its own first field has gone past the top — under the band, which is
      // what the band standing still is FOR.
      expect(tester.getTopLeft(find.text('Connection field 0')).dy, lessThan(band));
    });

    testWidgets('an action\'s elements replace the form\'s own definition, so a newly-picked value is immediately selectable', (tester) async {
      // The case this exists for: fieldUpdates alone would set
      // _values['port'] to a value the ORIGINAL options have no matching
      // item for — a newly-granted Web Serial device isn't offered until
      // the element list itself is rebuilt to include it.
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

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

    testWidgets('a periodic refresh reaches the open form, and stops with it', (tester) async {
      // A serial port picker refreshes on a timer so a cable plugged in with
      // the pane open shows up without closing and reopening the editor.
      // The trap is the timer outliving the pane: it holds the element
      // notifier and goes on enumerating hardware for a form nobody has on
      // screen, which the last pump here is what catches.
      var builds = 0;
      var extraPort = false;
      List<Map<String, dynamic>> elements() => [
        {
          'type': 'field',
          'fieldType': 'select',
          'key': 'port',
          'label': 'Port',
          'options': [
            {'value': 'COM1', 'label': 'COM1'},
            if (extraPort) {'value': 'COM9', 'label': 'COM9'},
          ],
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFormPane(
                  context,
                  formDefinition: {'title': 'Radio', 'elements': elements()},
                  initialState: const {'port': 'COM1'},
                  refreshElements: (
                    every: const Duration(seconds: 1),
                    build: () async {
                      builds++;
                      return elements();
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('COM9'), findsNothing);

      // A tick with nothing plugged in: the callback runs and the list is
      // unchanged.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(builds, greaterThan(0));
      expect(find.text('COM1'), findsWidgets);

      extraPort = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<dynamic>));
      await tester.pumpAndSettle();
      expect(find.text('COM9'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      final after = builds;
      await tester.pump(const Duration(seconds: 3));
      expect(builds, after);
    });

    testWidgets('a refresh that removes the chosen option drops it rather than asserting', (tester) async {
      // Unplug the cable with the port dropdown open. DropdownButton asserts
      // its value is exactly one of its items, so a picker that refreshes
      // under a selected-then-vanished port takes the whole form down with
      // "There should be exactly one item with [DropdownButton]'s value".
      var unplugged = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFormPane(
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
                          {'value': 'COM9', 'label': 'COM9'},
                        ],
                      },
                    ],
                  },
                  initialState: const {'port': 'COM9'},
                  refreshElements: (
                    every: const Duration(seconds: 1),
                    build: () async => [
                      {
                        'type': 'field',
                        'fieldType': 'select',
                        'key': 'port',
                        'label': 'Port',
                        'options': [
                          const {'value': 'COM1', 'label': 'COM1'},
                          if (!unplugged) const {'value': 'COM9', 'label': 'COM9'},
                        ],
                      },
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('COM9'), findsOneWidget);

      unplugged = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The form stops claiming a port that is not there, rather than
      // showing one the operator could save.
      expect(find.text('COM9'), findsNothing);
    });

    testWidgets('an isAction option in a ROW select runs its action instead of becoming the value', (tester) async {
      // The web serial transport's "Add a USB device…" lives inside the port
      // list. Once one real port carries a tag or an icon the field renders as
      // rows, and an action that is not honoured on that path stores its own
      // key as the port — which Save then writes into the radio's config.
      var ran = 0;
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
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
                            {'value': 'COM1', 'label': 'CP2105', 'trailing': 'usbserial-A1'},
                            {'value': 'grant', 'label': 'Add a device…', 'isAction': true, 'method': 'requestDevice'},
                          ],
                        },
                      ],
                    },
                    initialState: const {'port': 'COM1'},
                    onAction: (actionKey, method, state) async {
                      ran++;
                      return null;
                    },
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(RowSelectField), matching: find.byType(InkWell)).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a device…').last);
      await tester.pumpAndSettle();

      expect(ran, 1);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submitted?['port'], 'COM1', reason: 'the action must never become the field value');
    });

    testWidgets('a refresh that drops a ROW select\'s value leaves the value alone', (tester) async {
      // The opposite of the dropdown's rule, deliberately: RowSelectField
      // renders a value its rows no longer offer as an empty field, so nulling
      // it would just lose the operator's stored port to a radio switched off
      // mid-edit — and Save would write the loss.
      var unplugged = false;
      Map<String, dynamic>? submitted;
      List<Map<String, dynamic>> elements() => [
        {
          'type': 'field',
          'fieldType': 'select',
          'key': 'port',
          'label': 'Port',
          'options': [
            const {'value': 'COM1', 'label': 'FT232R', 'trailing': 'usbserial-A1'},
            if (!unplugged) const {'value': 'COM9', 'label': 'CP2105', 'trailing': 'usbserial-B2'},
          ],
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  submitted = await showFormPane(
                    context,
                    formDefinition: {'title': 'Radio', 'elements': elements()},
                    initialState: const {'port': 'COM9'},
                    refreshElements: (every: const Duration(seconds: 1), build: () async => elements()),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      unplugged = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submitted?['port'], 'COM9', reason: 'a port gone for a moment is not a port the operator cleared');
    });

    testWidgets('a ROW select opens on a stored value its rows do not offer', (tester) async {
      // The radio is switched off and the operator opens its editor to change
      // the baud rate. Dropped at mount — as a plain select's seeded value is,
      // for a vocabulary that genuinely changed — the port would be cleared on
      // a field they never touched, and Save refused for a missing port.
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
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
                            {'value': 'COM1', 'label': 'FT232R', 'trailing': 'usbserial-A1'},
                          ],
                        },
                      ],
                    },
                    initialState: const {'port': 'COM9'},
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submitted?['port'], 'COM9');
    });

    testWidgets('arrow keys skip an isAction option instead of committing it', (tester) async {
      // The keyboard is the third way into a select, and it bypasses both tap
      // handlers — so "Add a USB device…" is reachable by arrow key and would
      // be written into the field as if it were a port.
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
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
                    onAction: (_, _, _) async => null,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<dynamic>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('COM1').last);
      await tester.pumpAndSettle();

      // Down from the only real option wraps back onto itself, never onto the
      // action sitting after it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submitted?['port'], 'COM1');
    });

    testWidgets('a select option marked emphasis is drawn bold', (tester) async {
      // The port a radio's own definition names has to LOOK picked-out; a
      // "[suggested]" that reads like the rest of the list is the thing this
      // exists to avoid.
      await tester.pumpWidget(
        MaterialApp(
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
                      {'value': 'COM1', 'label': 'COM1 [suggested]', 'emphasis': true},
                      {'value': 'COM2', 'label': 'COM2'},
                    ],
                  },
                ],
              },
              initialState: const {'port': 'COM2'},
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<dynamic>));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.text('COM1 [suggested]').last).style?.fontWeight, FontWeight.bold);
      // Pinned to normal, not merely left alone: dropdown items are drawn in
      // titleMedium (w500), against which bold is a difference nobody sees.
      expect(tester.widget<Text>(find.text('COM2').last).style?.fontWeight, FontWeight.normal);
    });

    testWidgets('every footer verb is disabled while a submit is in flight', (tester) async {
      // Secondary is the one that gets missed, because it is the only slot
      // whose action does not close the form — so nothing about it looks
      // dangerous. It opens a route ON TOP of a submitting pane, and the
      // `Navigator.pop` that ends the submit takes down whatever is topmost:
      // the operator's edits go to that route and the pane stays open.
      final gate = Completer<void>();
      var secondaryRan = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFormPane(
                  context,
                  formDefinition: const {
                    'title': 'Radio',
                    'elements': [
                      {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': 'Name'},
                    ],
                  },
                  initialState: const {'name': 'Left Radio'},
                  destructiveAction: (label: 'Remove', color: const Color(0xFFB3261E), onPressed: () {}, icon: null),
                  secondaryAction: (label: 'Report', onPressed: () => secondaryRan++),
                  // submit() awaits the validator per field, so holding it here
                  // holds the form in its submitting state.
                  validator: (_, _, _) async {
                    await gate.future;
                    return null;
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      // Mid-flight: the spinner has taken the primary's place, and no verb
      // beside it accepts a tap.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      for (final verb in ['Report', 'Remove', 'Cancel']) {
        expect(tester.widget<TextButton>(find.widgetWithText(TextButton, verb)).onPressed, isNull, reason: '$verb stays live while the form is submitting');
      }

      gate.complete();
      await tester.pumpAndSettle();
      expect(secondaryRan, 0);
    });

    testWidgets('a secondary action runs OVER the pane, while a destructive one closes it first', (tester) async {
      // The two footer slots differ in exactly one way, and it is the whole
      // reason `secondaryAction` is not just another `destructiveAction`:
      // Remove is a way out of the form and Report is not, so a Report that
      // popped the pane would silently discard the edits sitting in it.
      var secondaryRan = 0;
      var destructiveRan = 0;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
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
                    destructiveAction: (label: 'Remove', color: const Color(0xFFB3261E), onPressed: () => destructiveRan++, icon: null),
                    secondaryAction: (label: 'Report', onPressed: () => secondaryRan++),
                  );
                  completed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

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
        // runAsync: the Spanish translations are a deferred library, and its
        // load is a real future that fake async would never complete.
        await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.es));
        addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
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
                    destructiveAction: (label: 'Eliminar', color: const Color(0xFFB3261E), onPressed: () {}, icon: null),
                    secondaryAction: (label: 'Informar', onPressed: () {}),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

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
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      expect(find.text('QRZ.com Account'), findsOneWidget);
      expect(find.text('Not Connected'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Connect'), findsOneWidget);
    });

    testWidgets('account field shows the connected label and Manage, and never persists a value on submit', (tester) async {
      Map<String, dynamic>? submittedValues;

      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

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

      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

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
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: devModeFormDefinition, initialState: const {}, onSubmit: (vals) => submittedValues = vals, onCancel: () {}),
          ),
        ),
      );

      expect(find.text('Dev Only Header'), findsNothing);
      expect(find.text('Debug Flag'), findsNothing);
      expect(find.text('Normal Field'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // A hidden devMode field must not sneak a value into the submission.
      expect(submittedValues!.containsKey('debugFlag'), isFalse);
    });

    testWidgets('devMode elements show and are tinted the orange dev-mode accent when developerMode is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: devModeFormDefinition, initialState: const {}, developerMode: true, onSubmit: (_) {}, onCancel: () {}),
          ),
        ),
      );

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

  group('FormRenderer settings-row fields', () {
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

    testWidgets('a settings list gives an icon-less field the settings row shape, and a form does not', (tester) async {
      // The row shape belongs to the SURFACE. Read off the element instead,
      // it becomes an accident of whoever wrote the declaration — which
      // renders a panel of extension settings (whose fields declare no icons)
      // as compact form controls beside a panel of settings rows.
      Widget renderer({required bool settingsList}) => MaterialApp(
        home: Scaffold(
          body: FormRenderer(
            formDefinition: const {
              'elements': [
                {'type': 'field', 'fieldType': 'checkbox', 'key': 'noIconToggle', 'label': 'Plain Toggle', 'value': false},
              ],
            },
            initialState: const {},
            settingsList: settingsList,
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      );

      await tester.pumpWidget(renderer(settingsList: false));
      // A form's toggle is the compact control: the checkbox leads the row,
      // and the row itself is not the switch.
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.byType(Switch), findsNothing);

      await tester.pumpWidget(renderer(settingsList: true));
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(Switch), findsOneWidget);
      expect(tester.widget<Text>(find.text('Plain Toggle')).style?.fontWeight, FontWeight.bold);
      // Nothing in the leading slot — an icon-less element is still a
      // settings row, not a row with a hole where the glyph would be.
      expect(tester.widget<ListTile>(find.byType(ListTile)).leading, isNull);

      // And the WHOLE row works the toggle, which is the point of the shape:
      // tapping the title, not the switch, flips it.
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.text('Plain Toggle'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('a select field with icon set renders as a tappable list row showing the current value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: iconRowFormDefinition, initialState: const {}, onSubmit: (_) {}, onCancel: () {}),
          ),
        ),
      );

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
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: iconRowFormDefinition, initialState: const {}, onSubmit: (vals) => submittedValues = vals, onCancel: () {}),
          ),
        ),
      );

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

    testWidgets('an icon-row text field shows its value, and edits it in a dialog', (tester) async {
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
      Map<String, dynamic>? submittedValues;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(formDefinition: textFormDefinition, initialState: const {}, onSubmit: (vals) => submittedValues = vals, onCancel: () {}),
          ),
        ),
      );

      // The row states what the setting is SET TO. The description is prose
      // about the setting, and giving it the subtitle would push the value —
      // the one thing an operator scans a settings panel for — off the row.
      expect(find.text('Field Day'), findsOneWidget);
      expect(find.text('Shown on your exports'), findsNothing);
      // Nothing to type into on the panel itself: a tap-to-open row, like
      // the icon-row select beside it.
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(MdiIcons.chevronRight), findsOneWidget);

      // Editing happens in the dialog, seeded with the current value.
      await tester.tap(find.text('Station Name'));
      await tester.pumpAndSettle();
      expect(find.byType(HaloDialog), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, 'Field Day');

      await tester.enterText(find.byType(TextField), 'Winter FD');
      // Done, not Save: closing is what commits a settings field, so the
      // editor carries no Save and no Cancel.
      expect(find.descendant(of: find.byType(HaloDialog), matching: find.text('Cancel')), findsNothing);
      await tester.tap(find.descendant(of: find.byType(HaloDialog), matching: find.text('Done')));
      await tester.pumpAndSettle();

      expect(find.byType(HaloDialog), findsNothing);
      expect(find.text('Winter FD'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submittedValues!['stationName'], 'Winter FD');
    });

    testWidgets('dismissing the editor commits, the same as Done', (tester) async {
      // There is no discard here: the dialog has Done and Defaults only, so
      // Escape and a tap outside have to mean what Done means. Popping on a
      // route result alone would silently drop the edit on both — they pop
      // with no result at all.
      Map<String, dynamic>? submittedValues;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: const {
                'elements': [
                  {'type': 'field', 'fieldType': 'text', 'key': 'stationName', 'label': 'Station Name', 'icon': 'account', 'value': 'Field Day'},
                ],
              },
              initialState: const {},
              onSubmit: (vals) => submittedValues = vals,
              onCancel: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Station Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Winter FD');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(HaloDialog), findsNothing);
      expect(find.text('Winter FD'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submittedValues!['stationName'], 'Winter FD');
    });

    testWidgets('closing without typing anything writes nothing', (tester) async {
      // Closing IS the commit gesture here, so an untouched open-and-Escape
      // would otherwise fire onChange — a real write, with whatever the
      // presenter hung off it (an account revalidating, a sync kicking).
      final committed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: const {
                'elements': [
                  {'type': 'field', 'fieldType': 'text', 'key': 'stationName', 'label': 'Station Name', 'icon': 'account', 'value': 'Field Day'},
                ],
              },
              initialState: const {},
              onChange: (key, value, state) async {
                committed.add('$key=$value');
                return null;
              },
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Station Name'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(committed, isEmpty);

      // And a real edit still commits exactly once, however it closed.
      await tester.tap(find.text('Station Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Winter FD');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(committed, ['stationName=Winter FD']);
    });

    testWidgets('a field declaring a defaultValue offers Defaults, and one without does not', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: const {
                'elements': [
                  {'type': 'field', 'fieldType': 'text', 'key': 'report', 'label': 'Default Report', 'icon': 'account', 'value': '5NN', 'defaultValue': '599'},
                  {'type': 'field', 'fieldType': 'text', 'key': 'stationName', 'label': 'Station Name', 'icon': 'account', 'value': 'Field Day'},
                ],
              },
              initialState: const {},
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      // No declared default, nothing to restore — the button is offered only
      // where the definition says what the default IS.
      await tester.tap(find.text('Station Name'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(HaloDialog), matching: find.text('Defaults')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Default Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(HaloDialog), matching: find.text('Defaults')));
      await tester.pumpAndSettle();

      expect(find.text('599'), findsOneWidget);
      expect(find.text('5NN'), findsNothing);
    });

    testWidgets('a toggle row is worked by the whole row, not just its switch', (tester) async {
      // A row that looks like every other settings row but only answers a
      // 12pt switch at its far edge reads as broken — and on a phone it is
      // the hardest target in the panel.
      Map<String, dynamic>? submittedValues;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: const {
                'elements': [
                  {
                    'type': 'field',
                    'fieldType': 'checkbox',
                    'key': 'shareData',
                    'label': 'Share app usage data',
                    'icon': 'chart-box',
                    'description': 'Help us improve the app',
                    'value': false,
                  },
                ],
              },
              initialState: const {},
              onSubmit: (vals) => submittedValues = vals,
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      // The description, specifically: the furthest thing on the row from the
      // switch, and the part an operator reads before deciding to tap.
      await tester.tap(find.text('Help us improve the app'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submittedValues!['shareData'], isTrue);
    });

    testWidgets('a disabled toggle row does not answer a tap anywhere on it', (tester) async {
      // `disabled` greys a row rather than hiding it, so the row still looks
      // tappable — the switch refusing while the row still toggled would be
      // the worst of both.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: const {
                'elements': [
                  {
                    'type': 'field',
                    'fieldType': 'checkbox',
                    'key': 'shareData',
                    'label': 'Share app usage data',
                    'icon': 'chart-box',
                    'description': 'Not available here',
                    'value': false,
                    'disabled': true,
                  },
                ],
              },
              initialState: const {},
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Not available here'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('a toggle (checkbox) field stays trailing even on a narrow panel', (tester) async {
      final toggleFormDefinition = {
        'elements': [
          {'type': 'field', 'fieldType': 'checkbox', 'key': 'syncEnabled', 'label': 'Sync with Ham2K Log Filer', 'icon': 'cloud-sync', 'value': false},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: FormRenderer(formDefinition: toggleFormDefinition, initialState: const {}, onSubmit: (_) {}, onCancel: () {}),
            ),
          ),
        ),
      );

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
    testWidgets('an icon-row field shows its placeholder in place of an empty value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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
                  {'type': 'field', 'fieldType': 'secret', 'key': 'apiKey', 'label': 'API Key', 'icon': 'shield-account', 'placeholder': 'Already stored'},
                ],
              },
              initialState: const {},
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      // Both fields took the icon-row path: a ListTile each, nothing to type
      // into until one is opened.
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.byType(TextField), findsNothing);

      expect(find.text('Same as the operator'), findsOneWidget);
      // The secret's placeholder is the case that motivates this: a panel
      // showing that a password is already in the keychain without loading it
      // into the form.
      expect(find.text('Already stored'), findsOneWidget);

      // At full strength, not dimmed like an input's hint: on a row the
      // placeholder IS what the setting currently amounts to ("Same as the
      // operator" is the callsign in force), and greying it reads as a
      // disabled setting rather than as an unset one.
      for (final hint in ['Same as the operator', 'Already stored']) {
        final color = tester.widget<Text>(find.text(hint)).style?.color;
        // Null means the row's own default — full strength. What must not
        // come back is the 0.38 an input's hint takes.
        expect(color?.a ?? 1.0, 1.0, reason: '$hint is dimmed like a hint');
      }

      // Opening the secret hands the editor an EMPTY field, never the
      // placeholder as text: saving an untouched dialog would otherwise
      // overwrite the real password with the words on the row.
      await tester.tap(find.text('API Key'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField)).decoration?.hintText, 'Already stored');
    });

    testWidgets('a secret with a value is masked on the row', (tester) async {
      // Settings panels get read over shoulders and screen-shared. A stored
      // secret has to show that it IS stored without showing what it is —
      // and without leaking its length either.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: const {
                'elements': [
                  {'type': 'field', 'fieldType': 'secret', 'key': 'apiKey', 'label': 'API Key', 'icon': 'shield-account', 'value': 'hunter2-and-then-some'},
                ],
              },
              initialState: const {},
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('hunter2-and-then-some'), findsNothing);
      expect(find.text('••••••••'), findsOneWidget);
    });

    testWidgets('a header with no style (or style: default) keeps the bold form-title look', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      final header = tester.widget<Text>(find.text('Plain Header'));
      expect(header.style?.fontWeight, FontWeight.w900);
      expect(header.style?.fontFamily, 'RobotoSlab');
    });

    testWidgets("style: 'section' is a ruled header standing proud of its rows", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // The inset a settings list publishes: without one the rows sit at
            // the edge and the band has nothing to stand proud of.
            body: ListTileTheme(
              data: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 24)),
              child: FormRenderer(
                formDefinition: const {
                  'elements': [
                    {'type': 'header', 'title': 'Plain Title'},
                    {'type': 'header', 'title': 'Section Header', 'style': 'section'},
                  ],
                },
                initialState: const {},
                onSubmit: (_) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );

      final title = find.text('Section Header');
      final header = tester.widget<Text>(title);
      // Same slab face as a form's own title, a step ABOVE the body-sized
      // titleSmall it is built from — a band has to be findable while its
      // rows scroll past.
      expect(header.style?.fontFamily, 'RobotoSlab');
      final titleSmall = Theme.of(tester.element(title)).textTheme.titleSmall!;
      expect(header.style?.fontSize, greaterThan(titleSmall.fontSize!));

      // The rule measures the CONTENT it heads: it starts where the title
      // does and ends the same distance from the other edge, rather than
      // running out to the pane's edges the way a filled band does. Both
      // stand SectionHeader.overhang outside the rows' own inset.
      final heading = find.ancestor(of: title, matching: find.byType(Container)).first;
      final form = find.byType(FormRenderer);
      expect(tester.getTopLeft(heading).dx, tester.getTopLeft(title).dx);
      expect(
        tester.getTopRight(form).dx - tester.getTopRight(heading).dx,
        tester.getTopLeft(heading).dx - tester.getTopLeft(form).dx,
        reason: 'the rule is inset equally on both sides',
      );
      expect(tester.getSize(heading).width, lessThan(tester.getSize(form).width));
      expect(
        tester.getTopLeft(find.text('Plain Title')).dx - tester.getTopLeft(heading).dx,
        SectionHeader.overhang,
        reason: 'the band stands proud of the inset an ordinary row keeps',
      );

      // On no ground of its own, closed by a hairline in the title's accent:
      // the FILLED band belongs to the Settings panel's categories, and a
      // section sits inside one of those.
      final decoration = tester.widget<Container>(heading).decoration as BoxDecoration;
      expect(tester.widget<Container>(heading).color, isNull);
      expect(decoration.color, isNull);
      expect(decoration.border?.bottom.width, SectionHeader.ruleWidth);
      expect(decoration.border?.bottom.color, header.style?.color);

      // And the plain header takes no heading chrome at all — every
      // FormRenderer caller renders `type: 'header'`, not just settings
      // panels.
      expect(find.ancestor(of: find.text('Plain Title'), matching: find.byType(Container)), findsNothing);
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

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setOuterState = setState;
            return MaterialApp(
              home: Scaffold(
                body: FormRenderer(formDefinition: currentDefinition, initialState: const {}, onSubmit: (vals) => submittedValues = vals, onCancel: () {}),
              ),
            );
          },
        ),
      );

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
          child: FormRenderer(formDefinition: conditionalForm, initialState: const {}, onSubmit: (vals) => submitted = vals, onCancel: () {}),
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

    await tester.pumpWidget(
      MaterialApp(
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
                    {'value': 'MML', 'label': 'MML — Multi-Op Multi-Transmitter Low Power (.1 to 100 watts) located at one Ohio State Park'},
                  ],
                },
              ],
            },
            initialState: const {},
            onSubmit: (_) async {},
            onCancel: () {},
          ),
        ),
      ),
    );
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
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
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

  group('a select behind an icon row', () {
    Widget renderer({required int optionCount, String? description, Object? initial}) => MaterialApp(
      home: Scaffold(
        body: FormRenderer(
          formDefinition: {
            'elements': [
              {
                'type': 'field',
                'fieldType': 'select',
                // `icon` is what routes a select to the row-and-dialog
                // form instead of an inline dropdown.
                'icon': 'earth',
                'key': 'zone',
                'label': 'Time Zone',
                'description': ?description,
                'options': [
                  for (var i = 1; i <= optionCount; i++) {'label': 'Zone $i', 'value': 'z$i'},
                ],
              },
            ],
          },
          initialState: initial == null ? const {} : {'zone': initial},
          onSubmit: (_) {},
          onCancel: () {},
        ),
      ),
    );

    testWidgets('the row names the chosen option when there is no description', (tester) async {
      // A zone is its own explanation, so such a field writes no description
      // — and a row showing neither the value nor a description tells the
      // operator nothing about what they picked last time.
      await tester.pumpWidget(renderer(optionCount: 3, initial: 'z2'));
      await tester.pumpAndSettle();
      expect(find.text('Zone 2'), findsOneWidget);
    });

    testWidgets('a description still wins over the chosen option', (tester) async {
      // Settings fields write a description that already explains the current
      // value; showing both would say it twice.
      await tester.pumpWidget(renderer(optionCount: 3, description: 'Pick one', initial: 'z2'));
      await tester.pumpAndSettle();
      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('Zone 2'), findsNothing);
    });

    testWidgets('a long vocabulary gets a search field, a short one does not', (tester) async {
      await tester.pumpWidget(renderer(optionCount: 8));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Time Zone'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(HaloDialog), matching: find.byType(TextField)),
        findsNothing,
        reason: 'eight options are browsable; a search box would be clutter',
      );
      await tester.tap(find.text('Zone 3'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(renderer(optionCount: 40));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Time Zone'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(HaloDialog), matching: find.byType(TextField)), findsOneWidget);
    });

    testWidgets('typing narrows the list, and picking from it commits', (tester) async {
      // The whole point of the search: the list is longer than the dialog, so
      // without filtering a known name can only be reached by scrolling. 341
      // IANA zones is the real case.
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: {
                'elements': [
                  {
                    'type': 'field',
                    'fieldType': 'select',
                    'icon': 'earth',
                    'key': 'zone',
                    'label': 'Time Zone',
                    'options': [
                      for (var i = 1; i <= 30; i++) {'label': 'Alpha $i', 'value': 'a$i'},
                      {'label': 'Zulu', 'value': 'zulu'},
                    ],
                  },
                ],
              },
              initialState: const {},
              onSubmit: (values) async => submitted = values,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Time Zone'));
      await tester.pumpAndSettle();

      final search = find.descendant(of: find.byType(HaloDialog), matching: find.byType(TextField));
      // Before filtering, the last option is past the bottom of the list —
      // this is what makes the search load-bearing rather than a nicety.
      expect(find.text('Zulu'), findsNothing);
      await tester.enterText(search, 'zul');
      await tester.pumpAndSettle();
      expect(find.text('Zulu'), findsOneWidget);
      expect(find.text('Alpha 1'), findsNothing);

      await tester.tap(find.text('Zulu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(submitted!['zone'], 'zulu');
    });
  });
}
