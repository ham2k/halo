// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The port picker's own control: a list of near-identical device nodes is
// only scannable when the node has a column of its own, which is the one
// thing a DropdownMenuItem's single string cannot give it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void _ignore(Object? _) {}

void main() {
  Widget host(Widget child, {double width = 600}) =>
      MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: width, child: child))));

  testWidgets('a select whose options carry structure is rendered as rows, not as a dropdown', (tester) async {
    await tester.pumpWidget(host(FormRenderer(
      formDefinition: const {
        'elements': [
          {
            'type': 'field',
            'fieldType': 'select',
            'key': 'port',
            'label': 'Port',
            'options': [
              {'value': 'a', 'label': 'CP2105', 'tags': ['suggested'], 'trailing': 'usbserial-A1', 'emphasis': true},
              {'value': 'b', 'label': 'FT232R', 'tags': [], 'trailing': 'usbserial-B2'},
            ],
          },
        ],
      },
      initialState: const {'port': 'b'},
      onSubmit: (_) {},
      onCancel: () {},
    )));
    await tester.pumpAndSettle();

    // The seam: a plain dropdown here means the trailing column silently went
    // back to being part of one string.
    expect(find.byType(RowSelectField), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<dynamic>), findsNothing);
  });

  testWidgets('the suggested row is heavier than the rest, which is what makes it visible', (tester) async {
    await tester.pumpWidget(host(RowSelectField(
      label: 'Port',
      value: 'b',
      rows: const [
        SelectRow(value: 'a', name: 'CP2105', tags: ['suggested'], trailing: 'usbserial-A1', emphasis: true),
        SelectRow(value: 'b', name: 'FT232R', trailing: 'usbserial-B2'),
      ],
      onChanged: (_) {},
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text('CP2105')).style?.fontWeight, FontWeight.w700);
    // Bold against a list that is ALSO bold is not a difference anyone sees.
    expect(tester.widget<Text>(find.text('FT232R').last).style?.fontWeight, FontWeight.w600);
    expect(find.text('suggested'), findsOneWidget);
    expect(find.text('usbserial-A1'), findsOneWidget);
  });

  testWidgets('a value no row offers still says what it is, rather than reading as unset', (tester) async {
    // Unplug the cable with the list open. This is what the DropdownButton it
    // replaced threw on — "there should be exactly one item with this value".
    // The value survives (the port is configured, its cable is just out), so
    // a blank field would have the operator re-picking a port they had
    // already chosen — and their form still holds the old one.
    await tester.pumpWidget(host(const RowSelectField(
      label: 'Port',
      value: 'COM9',
      rows: [SelectRow(value: 'a', name: 'CP2105', trailing: 'usbserial-A1')],
      onChanged: _ignore,
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('CP2105'), findsNothing);
    expect(find.text('COM9'), findsOneWidget);
  });

  testWidgets('a pane too narrow for one line gives the name its own, and pairs tags with the node', (tester) async {
    // Squeezing name, tags and node onto one line costs the name — the part
    // actually being read — so past that width the row becomes two.
    const rows = [
      SelectRow(
        value: 'a',
        name: 'CP2105 Dual USB to UART Bridge Controller #1',
        tags: ['suggested'],
        subtitle: 'Recently connected',
        trailing: 'usbserial-00F8E1EB0',
      ),
    ];
    await tester.pumpWidget(host(
      const RowSelectField(label: 'Port', value: 'a', rows: rows, onChanged: _ignore),
      width: 220,
    ));
    await tester.pumpAndSettle();

    final name = tester.getRect(find.text('CP2105 Dual USB to UART Bridge Controller #1'));
    final node = tester.getRect(find.text('usbserial-00F8E1EB0'));
    final tag = tester.getRect(find.text('suggested'));
    expect(node.top, greaterThan(name.bottom - 1), reason: 'the node belongs on the second line');
    expect(tag.left, lessThan(node.left), reason: 'tags left, node right');

    // Given room for all three, it is one line again, with the node beside
    // the name rather than under it. (Short name, because the test font is
    // far wider than any real one.)
    await tester.pumpWidget(host(
      const RowSelectField(
        label: 'Port',
        value: 'a',
        rows: [SelectRow(value: 'a', name: 'CP2105', trailing: 'usbserial-00F8E1EB0')],
        onChanged: _ignore,
      ),
      width: 700,
    ));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('usbserial-00F8E1EB0')).top,
        lessThan(tester.getRect(find.text('CP2105')).bottom));
  });

  testWidgets('a row that appears while the menu is open shows up in it', (tester) async {
    // The whole point of the refresh: the operator has the list down, plugs
    // the cable in, and the port is there — no closing and reopening.
    var rows = const [SelectRow(value: 'a', name: 'CP2105', trailing: 'usbserial-A1')];
    late StateSetter setOuter;
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) {
        setOuter = setState;
        return RowSelectField(label: 'Port', value: 'a', rows: rows, onChanged: (_) {});
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('FT232R'), findsNothing);

    setOuter(() => rows = const [
          SelectRow(value: 'a', name: 'CP2105', trailing: 'usbserial-A1'),
          SelectRow(value: 'b', name: 'FT232R', subtitle: 'Recently connected', trailing: 'usbserial-B2'),
        ]);
    await tester.pumpAndSettle();
    expect(find.text('FT232R'), findsOneWidget);
    expect(find.text('Recently connected'), findsOneWidget);
  });
}
