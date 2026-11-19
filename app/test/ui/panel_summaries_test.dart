// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation Summaries pane exists so a running score stays on screen
// while the next call is typed, in the sections the operator chose. What
// these catch: picks that leak between placements (two panes collapse into
// one), an order that strands a scorer first seen after it was saved, a fold
// that never reaches storage, and a settings edit the pane never hears about.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/information_panel.dart';
import 'package:ham2k_logger/views/operation/information_panel_settings.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_world.dart' show MapPalette;
import 'package:ham2k_logger/views/operation/summaries/operation_summaries_panel.dart';

import '../support/fake_panel_extensions.dart';

/// Core and CQ WW have both scored; DXCC has a detail list, CQ WW a detail
/// table and a short score.
Operation _operation() => Operation(
  uuid: 'op-1',
  data: {
    'stationCall': 'N0DEV',
    'refs': [
      {'type': 'cqww', 'mode': 'CW'},
    ],
  },
  localData: {
    'scoring': {
      'core': {
        'operationSummary': {
          'qsoCount': {'key': 'qsoCount', 'total': 12, 'duplicates': 2},
          'dxcc': {'key': 'dxcc', 'icon': 'earth', 'label': '3 DXCC Entities', 'summary': '3', 'longSummary': 'K, DL, JA'},
        },
      },
      'cqww': {
        'operationSummary': {
          'cqww': {'key': 'cqww', 'icon': 'trophy', 'label': 'CQ WW', 'summary': '72', 'longSummary': '**20m**: 4 QSOs'},
        },
      },
    },
  },
);

class _Harness {
  final FakePanelExtensions extensions;
  final PanelService service;

  _Harness(Map<String, Map<String, dynamic>> configs) : this._(FakePanelExtensions(configs: configs));

  _Harness._(this.extensions) : service = PanelService(extensions) {
    service.registerNative(
      const PanelDefinition(id: operationSummariesPanelId, title: 'Summaries', source: PanelSource.native, multiple: true, formFields: informationPanelFields),
    );
  }

  /// What [panelId] holds: a value written as null is one forgotten, as the
  /// real storage reads it back.
  Map<String, dynamic> stored(String panelId) => {for (final MapEntry(:key, :value) in (extensions.configs[panelId] ?? const {}).entries) key: ?value};
}

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);

/// A Summaries placement, as the dock builds one: the Info pane, never handed a call.
Widget _pane(_Harness harness, String panelId, {Operation? operation}) =>
    InformationPanel(panelId: panelId, panels: harness.service, operation: operation ?? _operation(), qsos: const []);

/// The section titles on screen, top to bottom.
List<String> _titlesShown(WidgetTester tester) {
  final titles = ['Operation Stats', '3 DXCC Entities', 'CQ WW'];
  final found = [
    for (final title in titles)
      if (find.text(title).evaluate().isNotEmpty) title,
  ];
  found.sort((a, b) => tester.getTopLeft(find.text(a)).dy.compareTo(tester.getTopLeft(find.text(b)).dy));
  return found;
}

void main() {
  testWidgets('shows the stats, then contests ahead of core, until the operator orders them', (tester) async {
    final harness = _Harness({});
    await tester.pumpWidget(_app(_pane(harness, 'summaries#1')));
    await tester.pumpAndSettle();

    expect(_titlesShown(tester), ['Operation Stats', 'CQ WW', '3 DXCC Entities']);
    // The duplicates line joins the stats: there is no "Scoring" title here
    // for it to sit under.
    expect(find.text('Duplicates: 2'), findsOneWidget);
    expect(find.text('Scoring'), findsNothing);
  });

  testWidgets("each placement reads its own picks, and a section the order doesn't name still shows", (tester) async {
    final harness = _Harness({
      'summaries#1': {
        // Saved before CQ WW was ever scored: it must not vanish, only go
        // after the sections the order does name.
        infoOrderKey: ['core.dxcc', 'stats'],
      },
      'summaries#2': {
        infoHiddenKey: ['stats', 'core.dxcc'],
      },
    });
    await tester.pumpWidget(_app(_pane(harness, 'summaries#1')));
    await tester.pumpAndSettle();
    expect(_titlesShown(tester), ['3 DXCC Entities', 'Operation Stats', 'CQ WW']);

    await tester.pumpWidget(_app(_pane(harness, 'summaries#2')));
    await tester.pumpAndSettle();
    expect(_titlesShown(tester), ['CQ WW']);
  });

  testWidgets('says so when every section is hidden, rather than drawing an empty pane', (tester) async {
    final harness = _Harness({
      'summaries#1': {
        infoHiddenKey: ['stats', 'core.dxcc', 'cqww.cqww'],
      },
    });
    await tester.pumpWidget(_app(_pane(harness, 'summaries#1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Every section is hidden'), findsOneWidget);
  });

  testWidgets('folding a section keeps its score in sight and is stored for that placement', (tester) async {
    final harness = _Harness({});
    await tester.pumpWidget(_app(_pane(harness, 'summaries#1')));
    await tester.pumpAndSettle();

    // Open, the detail says it in full; the short score would only repeat it.
    expect(find.text('72'), findsNothing);
    await tester.tap(find.text('CQ WW'));
    await tester.pumpAndSettle();

    expect(find.textContaining('4 QSOs'), findsNothing);
    expect(find.text('72'), findsOneWidget, reason: 'a folded section still has to say how it is doing');
    expect(harness.stored('summaries#1')[infoFoldedKey], ['cqww.cqww']);

    // A fresh pane over the same placement comes up folded.
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpWidget(_app(_pane(harness, 'summaries#1')));
    await tester.pumpAndSettle();
    expect(find.text('72'), findsOneWidget);

    await tester.tap(find.text('CQ WW'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 QSOs'), findsOneWidget);
    expect(harness.stored('summaries#1').containsKey(infoFoldedKey), isFalse, reason: 'nothing folded is nothing stored');
  });

  testWidgets('a tally that sets summaryWithDetail keeps its score beside its title with the section open', (tester) async {
    final operation = Operation(
      uuid: 'op-2',
      data: {'stationCall': 'N0DEV'},
      localData: {
        'scoring': {
          'hrwbota': {
            'operationSummary': {
              'hrwbota': {'key': 'hrwbota', 'label': 'HRWBOTA', 'summary': '36 pts', 'summaryWithDetail': true, 'longSummary': 'You worked 9 hosts.'},
            },
          },
        },
      },
    );
    await tester.pumpWidget(_app(_pane(_Harness({}), 'summaries#1', operation: operation)));
    await tester.pumpAndSettle();

    expect(find.textContaining('You worked 9 hosts.'), findsOneWidget);
    expect(find.text('36 pts'), findsOneWidget, reason: 'a points total the detail breaks down, not restates');
  });

  group("the Info pane's own picks", () {
    /// Drags [title]'s heading by [dy], in steps a drag would take.
    Future<void> dragHeading(WidgetTester tester, String title, double dy) async {
      final gesture = await tester.startGesture(tester.getCenter(find.text(title)));
      // A touch platform's drag starts only after a hold, so a swipe over a
      // heading still scrolls.
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var step = 0; step < 20; step++) {
        await gesture.moveBy(Offset(0, dy / 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('dragging a heading in the pane stores the order for that placement', (tester) async {
      final harness = _Harness({});
      await tester.pumpWidget(_app(_pane(harness, 'summaries#1')));
      await tester.pumpAndSettle();

      final above = tester.getTopLeft(find.text('Operation Stats')).dy - tester.getTopLeft(find.text('3 DXCC Entities')).dy;
      await dragHeading(tester, '3 DXCC Entities', above - 20);

      expect(_titlesShown(tester), ['3 DXCC Entities', 'Operation Stats', 'CQ WW']);
      expect(harness.stored('summaries#1')[infoOrderKey], ['core.dxcc', 'stats', 'cqww.cqww']);
    });

    testWidgets("a drag back to how the sections come stores no order of this operation's, and keeps another's", (tester) async {
      final harness = _Harness({
        'summaries#1': {
          infoOrderKey: ['pota.activation', 'core.dxcc', 'stats', 'cqww.cqww'],
        },
      });
      await tester.pumpWidget(_app(_pane(harness, 'summaries#1')));
      await tester.pumpAndSettle();
      expect(_titlesShown(tester), ['3 DXCC Entities', 'Operation Stats', 'CQ WW']);

      final below = tester.getBottomLeft(find.text('CQ WW')).dy - tester.getTopLeft(find.text('3 DXCC Entities')).dy;
      await dragHeading(tester, '3 DXCC Entities', below + 60);

      expect(_titlesShown(tester), ['Operation Stats', 'CQ WW', '3 DXCC Entities']);
      // Stored, an order that only restates the plain one would pin a scorer
      // first seen tomorrow after every one of today's.
      expect(harness.stored('summaries#1')[infoOrderKey], ['pota.activation']);
    });

    testWidgets("a placement's theme draws that pane on its face, and only that one", (tester) async {
      final harness = _Harness({
        'summaries#1': {infoThemeKey: 'teal'},
      });
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              Expanded(child: _pane(harness, 'summaries#1')),
              Expanded(child: _pane(harness, 'summaries#2')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final teal = MapPalette.named('teal').backgroundFor(false);
      final faces = [for (final element in find.text('CQ WW').evaluate()) Theme.of(element).colorScheme.surface];
      expect(faces.first, teal);
      expect(faces.last, isNot(teal));
    });

    testWidgets("a themed pane's headings show their press on its face, not under it", (tester) async {
      final harness = _Harness({
        'summaries#1': {infoThemeKey: 'teal'},
      });
      await tester.pumpWidget(_app(_pane(harness, 'summaries#1')));
      await tester.pumpAndSettle();

      // The ink a heading's InkWell paints lands on its nearest Material; the
      // app's own, beneath an opaque face, would hide every press.
      final material = tester.widget<Material>(find.ancestor(of: find.text('CQ WW'), matching: find.byType(Material)).first);
      expect(material.color, MapPalette.named('teal').backgroundFor(false));
    });

    testWidgets('a checklist highlights the codes still open, until the placement asks for those worked', (tester) async {
      final operation = Operation(
        uuid: 'op-grid',
        data: {'stationCall': 'N0DEV'},
        localData: {
          'scoring': {
            'core': {
              'operationSummary': {
                'states': {'key': 'states', 'label': '1 State', 'longSummary': 'AL  ~~AK~~  AZ', 'grid': true},
              },
            },
          },
        },
      );
      final harness = _Harness({
        'summaries#2': {infoChecklistStyleKey: infoHighlightWorked},
      });
      FontWeight? weight(String panelId, TextStyle? Function(MarkdownStyleSheet sheet) pick) =>
          pick(tester.widget<MarkdownBody>(find.descendant(of: find.byKey(ValueKey(panelId)), matching: find.byType(MarkdownBody))).styleSheet!)?.fontWeight;
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: const ValueKey('summaries#1'),
                  child: _pane(harness, 'summaries#1', operation: operation),
                ),
              ),
              Expanded(
                child: KeyedSubtree(
                  key: const ValueKey('summaries#2'),
                  child: _pane(harness, 'summaries#2', operation: operation),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(weight('summaries#1', (sheet) => sheet.p), FontWeight.w700, reason: 'pending (plain) codes stand out by default');
      expect(weight('summaries#1', (sheet) => sheet.del), isNot(FontWeight.w700));
      expect(weight('summaries#2', (sheet) => sheet.del), FontWeight.w700, reason: 'worked (struck) codes stand out when asked');
      expect(weight('summaries#2', (sheet) => sheet.p), isNot(FontWeight.w700));
    });

    testWidgets('a theme picked in the settings redraws the pane, and Automatic forgets it', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = _Harness({});
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) => InformationPanelSettings(
                    panelId: 'summaries#1',
                    panels: harness.service,
                    sections: informationSections(context, operation: _operation(), qsos: const []),
                  ),
                ),
              ),
              Expanded(child: _pane(harness, 'summaries#1')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final teal = MapPalette.named('teal').backgroundFor(false);
      Color face() => Theme.of(tester.element(find.text('Operation Stats').last)).colorScheme.surface;
      expect(face(), isNot(teal));

      await tester.tap(find.text('Automatic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teal').last);
      await tester.pumpAndSettle();
      expect(harness.stored('summaries#1')[infoThemeKey], 'teal');
      expect(face(), teal);

      await tester.tap(find.text('Teal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automatic').last);
      await tester.pumpAndSettle();
      expect(harness.stored('summaries#1').containsKey(infoThemeKey), isFalse, reason: "the app's own face is stored as none");
      expect(face(), isNot(teal));
    });
  });

  group('settings', () {
    Widget settings(_Harness harness, String panelId) => Builder(
      builder: (context) => InformationPanelSettings(
        panelId: panelId,
        panels: harness.service,
        sections: informationSections(context, operation: _operation(), qsos: const []),
      ),
    );

    /// Whether the Reset list button would do anything: it is always shown.
    bool resetLive(WidgetTester tester) =>
        tester.widget<ButtonStyleButton>(find.ancestor(of: find.text('Reset list'), matching: find.bySubtype<ButtonStyleButton>())).enabled;

    Finder tick(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
      matching: find.byType(Checkbox),
    );

    testWidgets('an unticked section leaves the pane at once, and only that placement', (tester) async {
      // Tall enough that the settings' rows, below its theme and checklist
      // fields, are all built in a third of it.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = _Harness({});
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              Expanded(child: settings(harness, 'summaries#1')),
              Expanded(child: _pane(harness, 'summaries#1')),
              Expanded(child: _pane(harness, 'summaries#2')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CQ WW'), findsNWidgets(3));

      await tester.tap(tick('CQ WW'));
      await tester.pumpAndSettle();

      // The settings row stays, unticked; the edited pane drops it; the other
      // pane, a different placement, keeps it.
      expect(find.text('CQ WW'), findsNWidgets(2));
      expect(harness.stored('summaries#1')[infoHiddenKey], ['cqww.cqww']);
      expect(harness.stored('summaries#2'), isEmpty);
    });

    testWidgets("dragging reorders this operation's sections and keeps another operation's in place", (tester) async {
      final harness = _Harness({
        'summaries#1': {
          // Another operation's POTA section, ordered first there.
          infoOrderKey: ['pota.activation', 'stats', 'cqww.cqww', 'core.dxcc'],
        },
      });
      await tester.pumpWidget(_app(settings(harness, 'summaries#1')));
      await tester.pumpAndSettle();

      final handle = find.descendant(
        of: find.ancestor(of: find.text('3 DXCC Entities'), matching: find.byType(ListTile)),
        matching: find.byIcon(MdiIcons.dragHorizontalVariant),
      );
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(kLongPressTimeout);
      final row = tester.getSize(find.ancestor(of: find.text('3 DXCC Entities'), matching: find.byType(ListTile))).height;
      for (var step = 0; step < 12; step++) {
        await gesture.moveBy(Offset(0, -row * 0.25));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(harness.stored('summaries#1')[infoOrderKey], ['pota.activation', 'core.dxcc', 'stats', 'cqww.cqww']);
    });

    testWidgets("a drag back to how the sections come stores what the pane's own drag would", (tester) async {
      final harness = _Harness({
        'summaries#1': {
          infoOrderKey: ['pota.activation', 'core.dxcc', 'stats', 'cqww.cqww'],
        },
      });
      await tester.pumpWidget(_app(settings(harness, 'summaries#1')));
      await tester.pumpAndSettle();

      final handle = find.descendant(
        of: find.ancestor(of: find.text('3 DXCC Entities'), matching: find.byType(ListTile)),
        matching: find.byIcon(MdiIcons.dragHorizontalVariant),
      );
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(kLongPressTimeout);
      final row = tester.getSize(find.ancestor(of: find.text('3 DXCC Entities'), matching: find.byType(ListTile))).height;
      for (var step = 0; step < 12; step++) {
        await gesture.moveBy(Offset(0, row * 0.25));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Kept, a restated plain order would pin a scorer first seen tomorrow
      // after all of today's, with no "Show all" to clear it: the order
      // shows nothing custom.
      expect(harness.stored('summaries#1')[infoOrderKey], ['pota.activation']);
    });

    testWidgets('reset forgets the picks, and is only live when there are some', (tester) async {
      final harness = _Harness({
        'summaries#1': {
          infoHiddenKey: ['stats'],
          infoOrderKey: ['core.dxcc'],
        },
      });
      await tester.pumpWidget(_app(settings(harness, 'summaries#1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset list'));
      await tester.pumpAndSettle();
      expect(harness.stored('summaries#1'), isEmpty);
      expect(resetLive(tester), isFalse);
    });

    testWidgets("reset puts back this operation's sections and leaves another operation's picks", (tester) async {
      final harness = _Harness({
        'summaries#1': {
          infoOrderKey: ['pota.activation', 'core.dxcc', 'stats'],
          infoHiddenKey: ['pota.activation', 'cqww.cqww'],
        },
      });
      await tester.pumpWidget(_app(settings(harness, 'summaries#1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset list'));
      await tester.pumpAndSettle();
      // A reset that wiped every operation would cost a POTA pane its picks
      // for having been reset from inside a contest.
      expect(harness.stored('summaries#1'), {
        infoOrderKey: ['pota.activation'],
        infoHiddenKey: ['pota.activation'],
      });
    });

    testWidgets("offers no reset when only another operation's sections were picked", (tester) async {
      final harness = _Harness({
        'summaries#1': {
          infoOrderKey: ['pota.activation', 'stats'],
          infoHiddenKey: ['pota.activation'],
        },
      });
      await tester.pumpWidget(_app(settings(harness, 'summaries#1')));
      await tester.pumpAndSettle();
      expect(resetLive(tester), isFalse);
    });

    testWidgets("lays out inside the tab button's dialog", (tester) async {
      // The dialog does not scroll an override itself, so the list must bound
      // and scroll its own height; one that asks for unbounded height throws
      // on open.
      final harness = _Harness({});
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showHaloDialog<void>(
                context: context,
                builder: (dialogContext) => HaloDialog(
                  title: const Text('Summaries'),
                  scrollable: false,
                  content: settings(harness, 'summaries#1'),
                  cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Done')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('CQ WW'), findsOneWidget);
    });
  });
}
