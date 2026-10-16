// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  testWidgets('template editor previews, rejects invalid input, and cancels without committing', (tester) async {
    String? saved;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: TemplateEditorScope(
            preview: (template, sample) async {
              if (template == 'broken') throw Exception('Unclosed tag');
              return template.replaceAll('{{ log.station }}', 'N0CALL');
            },
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    saved = await showTextTemplateEditor(
                      context,
                      field: {'label': 'File name', 'defaultValue': '{{ log.station }}', 'templateContext': 'export'},
                      value: '{{ log.station }}',
                    );
                  },
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('N0CALL'), findsOneWidget);
    expect(find.text('Available Attributes').hitTestable(), findsNothing);
    await tester.tap(find.text('Templating Docs'));
    await tester.pumpAndSettle();
    final editorPosition = tester.getTopLeft(find.byType(TextField));
    final docs = find.ancestor(of: find.text('Available Attributes'), matching: find.byType(SingleChildScrollView));
    await tester.drag(docs, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(TextField)), editorPosition);
    expect(find.text('N0CALL').hitTestable(), findsOneWidget);
    final previewSize = tester.getSize(find.byType(SelectableText).first);
    await tester.enterText(find.byType(TextField), 'broken');
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(SelectableText).first), previewSize);
    expect(find.text('N0CALL'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.textContaining('Unclosed tag'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
  });

  testWidgets('textTemplate forms save only the edited draft after confirmation', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: TemplateEditorScope(
            preview: (template, sample) async => template,
            child: Scaffold(
              body: FormRenderer(
                formDefinition: {
                  'elements': [
                    {'type': 'field', 'fieldType': 'textTemplate', 'key': 'name', 'label': 'File name', 'value': 'original'},
                  ],
                },
                initialState: const {},
                showActions: false,
                onChange: (key, value, state) async {
                  changes.add(value as String);
                  return null;
                },
                onSubmit: (_) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sample preview: original'), findsOneWidget);
    await tester.tap(find.text('File name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'updated');
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(changes, ['updated']);
  });

  // A render started per rebuild blanks the preview line until it lands, and
  // the form rebuilds on every keystroke in any field: in a dialog sized to
  // its content, the template rows would shrink and regrow with each letter,
  // as if the dialog were closing.
  testWidgets('typing in another field neither renders the template sample again nor blanks it', (tester) async {
    var renders = 0;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: TemplateEditorScope(
            preview: (template, sample) async {
              renders++;
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return template;
            },
            child: Scaffold(
              body: FormRenderer(
                formDefinition: {
                  'elements': [
                    {'type': 'field', 'fieldType': 'text', 'key': 'channel', 'label': 'Name'},
                    {'type': 'field', 'fieldType': 'textTemplate', 'key': 'message', 'label': 'Message', 'value': 'hello'},
                  ],
                },
                initialState: const {},
                showActions: false,
                onChange: (key, value, state) async => null,
                onSubmit: (_) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sample preview: hello'), findsOneWidget);
    expect(renders, 1);

    for (final text in ['K', 'KI', 'KI2D']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      expect(find.text('Sample preview: hello'), findsOneWidget, reason: 'still showing the frame after "$text" was typed');
    }
    await tester.pumpAndSettle();
    expect(renders, 1);
  });
}
