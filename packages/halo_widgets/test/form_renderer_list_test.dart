// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `fieldType: 'list'` field's rows and item editor: an item is deleted from
// its own editor's footer, not from a button on its row, and a list that
// declares `itemSwitch` turns each item on and off from a switch on its row.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Future<List<List<Map<String, dynamic>>>> pumpList(WidgetTester tester, List<Map<String, dynamic>> items, {bool inline = true}) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final commits = <List<Map<String, dynamic>>>[];
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: FormRenderer(
              formDefinition: {
                'elements': [
                  {
                    'type': 'field',
                    'fieldType': 'list',
                    'key': 'channels',
                    'label': 'Channels',
                    'itemLabel': 'Channel',
                    'itemTitle': r'${name}',
                    'itemSwitch': 'enabled',
                    'inline': inline,
                    'itemFields': [
                      {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': 'Name'},
                    ],
                    'value': items,
                  },
                ],
              },
              initialState: const {},
              showActions: false,
              onChange: (key, value, state) async {
                commits.add((value as List).cast<Map<String, dynamic>>());
                return null;
              },
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return commits;
  }

  testWidgets('an item is deleted from its editor, and its row has no delete button of its own', (tester) async {
    final commits = await pumpList(tester, [
      {'name': 'Club'},
      {'name': 'Friends'},
    ]);
    expect(find.byIcon(MdiIcons.delete), findsNothing);
    expect(find.text(t.formChrome.removeItem), findsNothing);

    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.formChrome.removeItem));
    await tester.pumpAndSettle();

    expect(find.text(t.formChrome.editItem(label: 'Channel')), findsNothing, reason: 'the editor closes');
    expect(find.text(t.formChrome.deleteItemTitle(name: 'Friends')), findsOneWidget);
    expect(commits, isEmpty, reason: 'not before the operator confirms');
    await tester.tap(find.text(t.formChrome.removeItem));
    await tester.pumpAndSettle();
    expect(commits.last, [
      {'name': 'Club'},
    ]);
  });

  // Delete sits in the same footer as Save: a slip must cost nothing.
  testWidgets('an item whose deletion is cancelled stays', (tester) async {
    final commits = await pumpList(tester, [
      {'name': 'Club'},
    ]);
    await tester.tap(find.text('Club'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.formChrome.removeItem));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(commits, isEmpty);
    expect(find.text('Club'), findsOneWidget);
  });

  testWidgets('a new item has nothing to delete yet', (tester) async {
    await pumpList(tester, const []);
    await tester.tap(find.text(t.formChrome.addItem(label: 'Channel')));
    await tester.pumpAndSettle();
    expect(find.text(t.formChrome.removeItem), findsNothing);
  });

  // An item without the key is a new one, and a new one is on. Reading the
  // absence as off would show every channel added before the switch existed
  // as switched off, though it still sends.
  testWidgets("a row's switch turns its item on and off, an item without the key reading as on", (tester) async {
    final commits = await pumpList(tester, [
      {'name': 'Club'},
      {'name': 'Friends', 'enabled': false},
    ]);
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect([for (final s in switches) s.value], [true, false]);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(commits.last, [
      {'name': 'Club', 'enabled': false},
      {'name': 'Friends', 'enabled': false},
    ]);
  });

  // The editor shows only `itemFields`; replacing the item with what it
  // returns would drop every other key — switching a channel back on by
  // renaming it.
  testWidgets('saving an edited item keeps the keys its editor does not show', (tester) async {
    final commits = await pumpList(tester, [
      {'name': 'Club', 'enabled': false},
    ]);
    await tester.tap(find.text('Club'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Club 2');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
    expect(commits.last, [
      {'name': 'Club 2', 'enabled': false},
    ]);
  });

  testWidgets('the list editor dialog has the same rows: a switch, and no delete button', (tester) async {
    await pumpList(tester, [
      {'name': 'Club'},
    ], inline: false);
    await tester.tap(find.text('Channels'));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byIcon(MdiIcons.delete), findsNothing);
  });
}
