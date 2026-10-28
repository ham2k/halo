// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `style: 'section'` header folds the rows under it. The declaration is a
// flat list, so what a section owns is inferred — the traps are a fold that
// takes the next section's rows with it, a fold that forgets the operator's
// choice, and one that hides the field a save is refusing.
//
// A shut body stays mounted, so "shut" is `.hitTestable()` finding nothing,
// never a bare findsNothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

class _Folds implements FormSectionFolds {
  final Map<String, bool> stored;
  _Folds([Map<String, bool>? stored]) : stored = stored ?? {};

  @override
  bool? isOpen(String section) => stored[section];

  @override
  void remember(String section, bool open) => stored[section] = open;
}

Map<String, dynamic> _text(String key) => {'type': 'field', 'fieldType': 'text', 'key': key, 'label': key};

final _elements = [
  _text('Callsign'),
  {'type': 'header', 'style': 'section', 'key': 'radio', 'title': 'Radio'},
  _text('Power'),
  {'type': 'header', 'style': 'section', 'title': 'Keyer'},
  _text('Speed'),
];

Finder _field(String label) => find.widgetWithText(TextField, label).hitTestable();

Widget _form(List<Map<String, dynamic>> elements, {bool sliver = false, FormSectionFolds? folds, FormValidator? validator, Key? key}) {
  final form = FormRenderer(
    key: key,
    formDefinition: {'elements': elements},
    initialState: const {},
    sliver: sliver,
    sectionFolds: folds,
    validator: validator,
    showActions: validator != null,
    onSubmit: (_) {},
    onCancel: () {},
  );
  return MaterialApp(
    home: Scaffold(
      body: sliver ? CustomScrollView(slivers: [form]) : SingleChildScrollView(child: form),
    ),
  );
}

void main() {
  for (final sliver in [false, true]) {
    // The two layouts find a section's rows separately: the box wraps them in
    // a fold, the sliver puts them in the band's pinned group.
    testWidgets('a section folds its own rows and no one else\'s (${sliver ? 'sliver' : 'box'})', (tester) async {
      await tester.pumpWidget(_form(_elements, sliver: sliver));
      expect(_field('Power'), findsOneWidget, reason: 'open unless it says otherwise');

      await tester.tap(find.text('Radio'));
      await tester.pumpAndSettle();
      expect(_field('Power'), findsNothing);
      expect(_field('Callsign'), findsOneWidget, reason: 'above the band, so not its row');
      expect(_field('Speed'), findsOneWidget, reason: "the next band's row");

      await tester.tap(find.text('Radio'));
      await tester.pumpAndSettle();
      expect(_field('Power'), findsOneWidget);
    });

    // Without the end, rows another source appends after a section would be
    // drawn as its rows, and fold away with it.
    testWidgets('a sectionEnd hands the rows after it back to no section (${sliver ? 'sliver' : 'box'})', (tester) async {
      await tester.pumpWidget(
        _form([
          {'type': 'header', 'style': 'section', 'key': 'radio', 'title': 'Radio'},
          _text('Power'),
          {'type': 'sectionEnd'},
          _text('Placed'),
        ], sliver: sliver),
      );
      await tester.tap(find.text('Radio'));
      await tester.pumpAndSettle();
      expect(_field('Power'), findsNothing);
      expect(_field('Placed'), findsOneWidget);
    });
  }

  // A section header among a disclosure's members heads no rows of its own:
  // a caret there would turn, and be remembered, while hiding nothing.
  testWidgets('a section header inside a disclosure does not fold', (tester) async {
    final folds = _Folds();
    await tester.pumpWidget(
      _form([
        {
          'type': 'disclosure',
          'key': 'advanced',
          'title': 'Advanced',
          'elements': [
            {'type': 'header', 'style': 'section', 'key': 'timing', 'title': 'Timing'},
            _text('Poll'),
          ],
        },
      ], folds: folds),
    );
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    final timing = find.ancestor(of: find.text('Timing'), matching: find.byType(SectionHeader));
    expect(find.descendant(of: timing, matching: find.byType(DisclosureChevron)), findsNothing);
    await tester.tap(find.text('Timing'));
    await tester.pumpAndSettle();
    expect(_field('Poll'), findsOneWidget);
    expect(folds.stored, isEmpty);
  });

  // One source's elements joined to another's: the second must not land in
  // the first's last section, and a list that leaves none open is untouched.
  test('closingSections ends a section left open, and only one', () {
    const end = {'type': 'sectionEnd'};
    final open = [
      _text('Callsign'),
      {'type': 'header', 'style': 'section', 'title': 'Radio'},
      _text('Power'),
    ];
    expect(FormRenderer.closingSections(open), [...open, end]);
    expect(FormRenderer.closingSections([...open, end]), [...open, end]);
    expect(FormRenderer.closingSections([_text('Callsign')]), [_text('Callsign')]);
    final category = [
      {'type': 'header', 'style': 'category', 'title': 'Station'},
      _text('Callsign'),
    ];
    expect(FormRenderer.closingSections(category), [...category, end], reason: 'a category band owns the rows after it too');
  });

  testWidgets('collapsed: true starts shut, and a category band never folds', (tester) async {
    await tester.pumpWidget(
      _form([
        {'type': 'header', 'style': 'category', 'title': 'Station'},
        _text('Callsign'),
        {'type': 'header', 'style': 'section', 'title': 'Advanced', 'collapsed': true},
        _text('Poll'),
      ]),
    );
    expect(_field('Poll'), findsNothing);
    await tester.tap(find.text('Station'));
    await tester.pumpAndSettle();
    expect(_field('Callsign'), findsOneWidget);
  });

  testWidgets('the operator\'s fold outlasts the form, named by key or else by title', (tester) async {
    final folds = _Folds();
    await tester.pumpWidget(_form(_elements, folds: folds));
    await tester.tap(find.text('Radio'));
    await tester.tap(find.text('Keyer'));
    await tester.pumpAndSettle();
    expect(folds.stored, {'radio': false, 'Keyer': false});

    // A new form, as the next visit builds: without the memory it would
    // start open again.
    await tester.pumpWidget(_form(_elements, folds: folds, key: UniqueKey()));
    expect(_field('Power'), findsNothing);
    expect(_field('Speed'), findsNothing);
  });

  testWidgets('a section the operator opened stays open over its declared default', (tester) async {
    await tester.pumpWidget(
      _form([
        {'type': 'header', 'style': 'section', 'key': 'advanced', 'title': 'Advanced', 'collapsed': true},
        _text('Poll'),
      ], folds: _Folds({'advanced': true})),
    );
    expect(_field('Poll'), findsOneWidget);
  });

  // A save refused for a field nobody can see reads as a dead button. The
  // section opens for it, but that is the form's doing, not the operator's
  // choice, so the next visit still finds it shut.
  testWidgets('a save that refuses a field in a shut section opens it, without remembering that', (tester) async {
    final folds = _Folds({'radio': false});
    await tester.pumpWidget(_form(_elements, folds: folds, validator: (key, value, state) async => key == 'Power' ? 'required' : null));
    expect(_field('Power'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(_field('Power'), findsOneWidget);
    expect(find.text('required'), findsOneWidget);
    expect(folds.stored, {'radio': false});
  });
}
