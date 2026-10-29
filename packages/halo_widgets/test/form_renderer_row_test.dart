// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `type: 'row'` element puts its members side by side. The members are
// still the form's own fields: the trap is a row that draws them but leaves
// them out of what the form registers, validates and saves.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

Map<String, dynamic> _field(String key, {String fieldType = 'text', int? flex, Map<String, dynamic>? visibleWhen}) => {
  'type': 'field',
  'fieldType': fieldType,
  'key': key,
  'label': key,
  'flex': ?flex,
  'visibleWhen': ?visibleWhen,
};

Finder _box(String label) => find.widgetWithText(TextField, label);

void main() {
  Map<String, dynamic>? submitted;
  final actions = <String>[];

  // The row inset a form pane gives its rows.
  const inset = 24.0;

  Widget form(List<Map<String, dynamic>> elements, {Map<String, dynamic> initialState = const {}, FormValidator? validator}) => MaterialApp(
    home: Scaffold(
      body: ListTileTheme.merge(
        contentPadding: const EdgeInsets.symmetric(horizontal: inset),
        child: SingleChildScrollView(
          child: FormRenderer(
            formDefinition: {'elements': elements},
            initialState: initialState,
            validator: validator,
            onAction: (key, method, state) async {
              actions.add(key);
              return null;
            },
            onSubmit: (values) => submitted = values,
            onCancel: () {},
          ),
        ),
      ),
    ),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    submitted = null;
    actions.clear();
  });

  final hostAndPort = {
    'type': 'row',
    'elements': [_field('Host', flex: 7), _field('Port', fieldType: 'number', flex: 3)],
  };

  testWidgets('members share one line by their flex, and save like any field', (tester) async {
    await tester.pumpWidget(form([hostAndPort], initialState: const {'Host': 'shack.local', 'Port': 4535}));

    final host = tester.getRect(_box('Host'));
    final port = tester.getRect(_box('Port'));
    expect(port.top, host.top);
    expect(port.left, greaterThan(host.right));
    expect(host.width / port.width, closeTo(7 / 3, 0.2));

    await tester.enterText(_box('Port'), '4536');
    await save(tester);
    expect(submitted, {'Host': 'shack.local', 'Port': 4536});
  });

  testWidgets('the row takes the form\'s inset once, around all its members', (tester) async {
    // Each member taking the inset itself opens twice its width between
    // every pair, and Turn and Stop drift to opposite ends of the row.
    await tester.pumpWidget(form([hostAndPort]));
    final host = tester.getRect(_box('Host'));
    final port = tester.getRect(_box('Port'));
    expect(host.left, inset);
    expect(port.left - host.right, moreOrLessEquals(Space.md));
    expect(port.right, moreOrLessEquals(tester.view.physicalSize.width / tester.view.devicePixelRatio - inset));
  });

  testWidgets('an error under one box does not move the box beside it', (tester) async {
    // A row centred or bottom-aligned would drop the port by half the
    // error's height, and the pair would no longer read as one line.
    await tester.pumpWidget(form([hostAndPort], validator: (key, value, state) async => key == 'Host' ? 'Host is required' : null));
    final before = tester.getRect(_box('Port'));
    await save(tester);
    expect(find.text('Host is required'), findsOneWidget);
    expect(submitted, isNull, reason: 'a member is validated like any field');
    expect(tester.getRect(_box('Port')), before);
  });

  testWidgets('a button at flex 0 keeps its own width, and the boxes take the rest', (tester) async {
    await tester.pumpWidget(
      form([
        {
          'type': 'row',
          'elements': [
            _field('Azimuth', fieldType: 'number'),
            {'type': 'action', 'key': 'turn', 'label': 'Turn', 'flex': 0},
          ],
        },
      ]),
    );
    final button = tester.getRect(find.widgetWithText(OutlinedButton, 'Turn'));
    // Shared out by flex, a button stretches to half the row on a wide
    // screen and wraps its label a letter a line on a narrow one.
    expect(button.width, lessThan(tester.getRect(_box('Azimuth')).width / 2));

    await tester.tap(find.text('Turn'));
    await tester.pumpAndSettle();
    expect(actions, ['turn']);
  });

  testWidgets('a row follows its members\' visibleWhen', (tester) async {
    const network = {'field': 'link', 'equals': 'network'};
    await tester.pumpWidget(
      form(
        [
          {
            'type': 'field',
            'fieldType': 'radio',
            'key': 'link',
            'label': 'Link',
            'options': [
              {'label': 'Serial', 'value': 'serial'},
              {'label': 'Network', 'value': 'network'},
            ],
          },
          {
            'type': 'row',
            'elements': [_field('Host', flex: 7, visibleWhen: network), _field('Port', fieldType: 'number', flex: 3, visibleWhen: network)],
          },
        ],
        initialState: const {'link': 'serial'},
      ),
    );
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Network'));
    await tester.pumpAndSettle();
    expect(_box('Host'), findsOneWidget);
    expect(_box('Port'), findsOneWidget);
  });

  // A field one group further down that goes unregistered renders against
  // no controller, and what is typed into it never reaches the save.
  testWidgets('a row inside a fold saves its members like any field', (tester) async {
    await tester.pumpWidget(
      form([
        {
          'type': 'disclosure',
          'key': 'advanced',
          'title': 'Advanced',
          'elements': [
            {
              'type': 'row',
              'elements': [_field('Lowest', fieldType: 'number'), _field('Highest', fieldType: 'number')],
            },
          ],
        },
      ]),
    );
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.enterText(_box('Highest'), '450');
    await save(tester);
    expect(submitted?['Highest'], 450);
  });

  // A host adds its own condition to the one a field declared; either one
  // replacing the other shows the field where one of them says not to.
  testWidgets('a list of visibleWhen conditions shows the element only while every one holds', (tester) async {
    Map<String, dynamic> choice(String key, List<String> values) => {
      'type': 'field',
      'fieldType': 'radio',
      'key': key,
      'label': key,
      'options': [
        for (final v in values) {'label': v, 'value': v},
      ],
    };
    await tester.pumpWidget(
      form(
        [
          choice('link', ['serial', 'network']),
          choice('axes', ['az', 'azel']),
          _field('Elevation offset', fieldType: 'number')
            ..['visibleWhen'] = [
              {'field': 'axes', 'equals': 'azel'},
              {'field': 'link', 'equals': 'network'},
            ],
        ],
        initialState: const {'link': 'serial', 'axes': 'azel'},
      ),
    );
    expect(_box('Elevation offset'), findsNothing);
    await tester.tap(find.text('network'));
    await tester.pumpAndSettle();
    expect(_box('Elevation offset'), findsOneWidget);
    await tester.tap(find.text('az'));
    await tester.pumpAndSettle();
    expect(_box('Elevation offset'), findsNothing);
  });

  testWidgets('a category band carries a button for the whole section, and a disabled button does nothing', (tester) async {
    Future<void> show({required bool connected}) => tester.pumpWidget(
      form([
        {
          'type': 'header',
          'style': 'category',
          'title': 'Current State',
          'action': {'type': 'action', 'key': connected ? 'disconnect' : 'connect', 'label': connected ? 'Disconnect' : 'Connect'},
        },
        {
          'type': 'row',
          'elements': [
            _field('Azimuth', fieldType: 'number')..['disabled'] = !connected,
            {'type': 'action', 'key': 'turn', 'label': 'Turn', 'flex': 0, 'disabled': !connected},
          ],
        },
      ]),
    );

    await show(connected: false);
    final band = find.ancestor(of: find.text('Current State'), matching: find.byType(CategoryBand));
    expect(find.descendant(of: band, matching: find.widgetWithText(OutlinedButton, 'Connect')), findsOneWidget);
    await tester.tap(find.text('Turn'));
    await tester.pumpAndSettle();
    expect(actions, isEmpty, reason: 'greyed is not merely drawn grey');
    expect(tester.widget<TextField>(_box('Azimuth')).enabled, isFalse);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(actions, ['connect']);

    await show(connected: true);
    await tester.tap(find.text('Turn'));
    await tester.pumpAndSettle();
    expect(actions, ['connect', 'turn']);
  });

  testWidgets('a band button with an icon is the icon alone, green while connected, and a spinner while busy', (tester) async {
    Future<void> show(Map<String, dynamic> action) => tester.pumpWidget(
      form([
        {'type': 'header', 'style': 'category', 'title': 'Current State', 'action': action},
      ]),
    );

    await show({'type': 'action', 'key': 'connect', 'label': 'Connect', 'icon': 'power-plug-off'});
    expect(find.text('Connect'), findsNothing, reason: 'the label names it for a screen reader, and is not drawn');
    expect(find.bySemanticsLabel('Connect'), findsOneWidget);
    final idle = tester.widget<Icon>(find.byIcon(MdiIcons.powerPlugOff)).color;
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(actions, ['connect']);

    await show({'type': 'action', 'key': 'disconnect', 'label': 'Disconnect', 'icon': 'power-plug', 'tone': 'connected'});
    final theme = Theme.of(tester.element(find.byType(IconButton)));
    expect(tester.widget<Icon>(find.byIcon(MdiIcons.powerPlug)).color, connectedGreen(theme));
    expect(idle, isNot(connectedGreen(theme)));

    // A tap mid-connect could only queue a second change behind the first.
    await show({'type': 'action', 'key': 'connect', 'label': 'Connect', 'icon': 'power-plug-off', 'busy': true});
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
