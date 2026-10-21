// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Layout files (docs/design/layouts.md § Layout files): what leaves the
// device and what a device makes of one. A file is written on one device
// and read on another, so every rule here is about ids that mean nothing
// outside the device that wrote them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/dock_host.dart' show DockLayoutClass;
import 'package:ham2k_logger/views/dock_layouts/layout_diagram.dart';
import 'package:ham2k_logger/views/dock_layouts/layout_file.dart';
import 'package:ham2k_logger/views/dock_layouts/yaml_writer.dart';
import 'package:ham2k_logger/views/operation/pane_layout_options.dart';
import 'package:yaml/yaml.dart';

const _text = 'ext:custom-text:text';

DockNode _sample() => DockSplit(
  Axis.horizontal,
  [
    DockGroup(['logging']),
    DockGroup(
      ['spots', 'nested#1'],
      nested: {
        'nested#1': DockSplit(
          Axis.vertical,
          [
            DockGroup(['map']),
            DockGroup(['$_text#2']),
          ],
          [1, 2],
        ),
      },
    ),
  ],
  [2, 1],
);

LayoutFileArrangement _export(DockNode spec, {bool Function(String)? keep}) => LayoutFileArrangement.fromDock(
  spec,
  paneOptions: {
    '$_text#2': const PaneLayoutOptions(title: 'Skeds'),
    'nested#1': const PaneLayoutOptions(title: 'Lower'),
  },
  viewOptions: const PaneLayoutOptions(density: 'dense'),
  settingsFor: (id) => id == '$_text#2' ? {'text': 'line one\nline two'} : const {},
  keep: keep,
)!;

bool _multiple(String id, {required bool fileSaysInstance}) => id == _text;

bool _offered(String id) => true;

void main() {
  group('yaml writer', () {
    test('reads back equal, including what a plain scalar would misread', () {
      final value = {
        'yes': 'no',
        'colon': 'a: b',
        'hash': 'a #b',
        'number-like': '123',
        'id': 'ext:custom-text:text#2',
        'empty': '',
        'lead': '- dash',
        'multi': 'one\ntwo\n',
        'multiNoEnd': 'one\ntwo',
        'trailingSpace': 'one \ntwo',
        'weights': [2.0, 1.5],
        'nested': [
          {
            'a': 1,
            'b': [
              {'c': true},
            ],
          },
          [1, 'x'],
        ],
        'emptyMap': <String, dynamic>{},
        'emptyList': <dynamic>[],
        'null': null,
      };
      final read = jsonRoundTrip(loadYaml(toYaml(value)));
      expect(read, {
        ...value,
        'weights': [2, 1.5],
      });
    });
  });

  group('export', () {
    test('names panels, not placements', () {
      final file = LayoutFile(view: 'operation', name: 'Contest', description: 'Sprint: log, spots', arrangements: {DockLayoutClass.wide: _export(_sample())});
      final yaml = file.toYaml();
      // `#2` is a slot in THIS device's config store; on another device it is
      // either free or someone else's.
      expect(yaml, isNot(contains('#2')));
      final parsed = LayoutFile.parse(yaml);
      expect(parsed.arrangements[DockLayoutClass.wide]!.panels, ['logging', 'spots', 'map', _text]);
      expect(parsed.name, 'Contest');
      expect(parsed.description, 'Sprint: log, spots');
    });

    test('a partial export keeps the shape of what was picked', () {
      final arrangement = _export(_sample(), keep: (id) => id == 'map' || id == 'spots');
      final root = arrangement.root as LayoutFileGroup;
      // The container lost one of its two panes, so it folds back into a
      // plain tab: a container holding one pane is two tabs deep for nothing.
      expect([for (final tab in root.tabs) tab.panel], ['spots', 'map']);
    });

    test('nothing picked is nothing to export', () {
      expect(
        LayoutFileArrangement.fromDock(_sample(), paneOptions: const {}, viewOptions: PaneLayoutOptions.none, settingsFor: (_) => const {}, keep: (_) => false),
        isNull,
      );
    });
  });

  group('import', () {
    LayoutFileArrangement roundTrip() =>
        LayoutFile.parse(LayoutFile(arrangements: {DockLayoutClass.wide: _export(_sample())}).toYaml()).arrangements[DockLayoutClass.wide]!;

    test('an instance gets an id nothing on this device is using, and keeps its settings', () {
      final result = roundTrip().materialize(isMultiple: _multiple, isOffered: _offered, takenIds: ['$_text#1', '$_text#2']);
      final modules = result.spec!.collectModules();
      expect(modules, contains('$_text#3'), reason: '#1 and #2 hold another layout\'s contents');
      expect(result.settings['$_text#3'], {'text': 'line one\nline two'});
      expect(result.paneOptions['$_text#3']?.title, 'Skeds');
      expect(result.viewOptions.density, 'dense');
    });

    test('a panel placed once is skipped when the layout already has it', () {
      // Adding to an arrangement that already shows the log: a second
      // `logging` would hand one widget to two tabs.
      final result = roundTrip().materialize(isMultiple: _multiple, isOffered: _offered, presentIds: ['logging']);
      expect(result.spec!.collectModules(), isNot(contains('logging')));
      expect(result.skipped, ['logging']);
    });

    test('a container gets an id clear of the arrangement it joins, with its options', () {
      final result = roundTrip().materialize(isMultiple: _multiple, isOffered: _offered, takenContainerIds: ['nested#1']);
      expect(result.spec!.collectContainerIds(), ['nested#2']);
      expect(result.paneOptions['nested#2']?.title, 'Lower');
    });

    test('a panel the view does not offer is left out', () {
      final result = roundTrip().materialize(isMultiple: _multiple, isOffered: (id) => id != 'logging');
      expect(result.spec!.collectModules(), ['spots', 'map', '$_text#1']);
      expect(result.skipped, ['logging']);
    });

    test('nothing this arrangement can hold still says what was left out', () {
      // Null with no list would make a file whose other arrangement holds only
      // another view's panes come in as the view's default, unannounced.
      final result = roundTrip().materialize(isMultiple: _multiple, isOffered: (_) => false);
      expect(result.spec, isNull);
      expect(result.skipped, ['logging', 'spots', 'map', _text]);
    });

    test('refuses what is not a layout file, saying why in a way that can be translated', () {
      // The reason reaches the operator's screen; an English parser message
      // there would sit untranslated inside a translated sentence.
      Matcher problem(LayoutFileProblem problem, {int? line}) =>
          throwsA(isA<LayoutFileException>().having((e) => e.problem, 'problem', problem).having((e) => e.line, 'line', line));
      expect(() => LayoutFile.parse('a: 1'), problem(LayoutFileProblem.notLayoutFile));
      expect(() => LayoutFile.parse('ham2k-layout: 99\nwide: {root: {tabs: [{panel: x}]}}'), problem(LayoutFileProblem.newerVersion));
      expect(() => LayoutFile.parse('ham2k-layout: 1\nname: x\nwide: ['), problem(LayoutFileProblem.notYaml, line: 3));
      expect(() => LayoutFile.parse('ham2k-layout: 1\nname: x'), problem(LayoutFileProblem.noArrangement));
    });

    test('a file of nested aliases is refused, not expanded', () {
      // Each level names the one before ten times: a few hundred bytes that
      // copy out to ten billion values, freezing the app while it reads.
      final levels = StringBuffer('ham2k-layout: 1\na0: &a0 [x, x, x, x, x, x, x, x, x, x]\n');
      for (var i = 1; i <= 10; i++) {
        levels.writeln('a$i: &a$i [${List.filled(10, '*a${i - 1}').join(', ')}]');
      }
      final watch = Stopwatch()..start();
      expect(() => LayoutFile.parse('$levels'), throwsA(isA<LayoutFileException>().having((e) => e.problem, 'problem', LayoutFileProblem.tooLarge)));
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('a file nested past any layout is refused before it is parsed', () {
      // The parser's time grows with the square of the depth: this line of
      // brackets, handed to it, holds the app for about fifteen seconds.
      const depth = 100000;
      final watch = Stopwatch()..start();
      expect(
        () => LayoutFile.parse('ham2k-layout: 1\nwide: ${'[' * depth}${']' * depth}'),
        throwsA(isA<LayoutFileException>().having((e) => e.problem, 'problem', LayoutFileProblem.tooLarge)),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('a file nested past what the parser can follow is refused, never a crash', () {
      // No brackets for the depth count to see: a line of `- ` a hundred
      // thousand deep runs the parser out of stack, an Error the import's
      // catch never meets.
      expect(
        () => LayoutFile.parse('ham2k-layout: 1\nwide:\n  ${'- ' * 100000}x\n'),
        throwsA(isA<LayoutFileException>().having((e) => e.problem, 'problem', LayoutFileProblem.tooLarge)),
      );
    });

    test('a hand-written slip is a file that does not read, never a crash', () {
      // A type the reader casts rather than tests escapes the import's catch
      // as a generic error report of the operator's typo.
      expect(() => LayoutFile.parse('ham2k-layout: 1\nwide: {root: {split: horizontal, children: foo}}'), throwsA(isA<LayoutFileException>()));
      final file = LayoutFile.parse(
        'ham2k-layout: 1\nextensions: pota\nwide: {root: {split: horizontal, weights: 3, children: [{tabs: [{panel: map}]}, {tabs: [{panel: spots}]}]}}',
      );
      expect(file.extensions, isEmpty);
      expect((file.arrangements[DockLayoutClass.wide]!.root as LayoutFileSplit).weights, [1, 1]);
    });
  });

  group('diagram', () {
    testWidgets('a tab set is named as one, with its tabs indented under it', (tester) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: LayoutDiagram(
                root: const LayoutDiagramGroup([LayoutDiagramTab(key: 'spots', label: 'Spots'), LayoutDiagramTab(key: 'map', label: 'Map')]),
                selected: const {'spots', 'map'},
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      final set = find.text(AppLocale.en.buildSync().operation.layout.layouts.tabSet);
      expect(set, findsOneWidget);
      // Level with the set's own tick, the tabs read as its siblings rather
      // than as what it holds.
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(3));
      expect(tester.getTopLeft(checkboxes.at(1)).dx, greaterThan(tester.getTopLeft(checkboxes.at(0)).dx));
      expect(tester.getTopLeft(checkboxes.at(2)).dx, tester.getTopLeft(checkboxes.at(1)).dx);
    });

    testWidgets('a container\'s contents are indented under its tick', (tester) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: LayoutDiagram(
                root: const LayoutDiagramGroup([
                  LayoutDiagramTab(key: 'map', label: 'Map'),
                  LayoutDiagramTab(
                    key: 'nested#1',
                    label: 'More',
                    container: LayoutDiagramSplit(
                      Axis.vertical,
                      [
                        LayoutDiagramGroup([LayoutDiagramTab(key: 'spots', label: 'Spots')]),
                        LayoutDiagramGroup([LayoutDiagramTab(key: 'info', label: 'Info')]),
                      ],
                      [1, 1],
                    ),
                  ),
                ]),
                selected: const {'map', 'spots', 'info'},
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      double tickOf(String label) => tester.getTopLeft(find.widgetWithText(Row, label).first).dx;
      // Level with More's own tick, Spots and Info read as its siblings in the
      // tab set rather than as what More holds.
      expect(tickOf('More'), tickOf('Map'));
      // A step a reader sees, not the couple of pixels a box's own border adds.
      expect(tickOf('Spots'), greaterThanOrEqualTo(tickOf('More') + Space.xl));
      expect(tickOf('Info'), tickOf('Spots'));
    });
  });
}

Object? jsonRoundTrip(Object? node) => switch (node) {
  final Map<dynamic, dynamic> map => {for (final e in map.entries) '${e.key}': jsonRoundTrip(e.value)},
  final List<dynamic> list => [for (final item in list) jsonRoundTrip(item)],
  _ => node,
};
