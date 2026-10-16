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
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/summaries/operation_summaries_panel.dart';
import 'package:ham2k_logger/views/operation/summaries/operation_summaries_settings.dart';

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
      const PanelDefinition(
        id: operationSummariesPanelId,
        title: 'Summaries',
        source: PanelSource.native,
        multiple: true,
        formFields: operationSummariesFields,
      ),
    );
  }

  SummariesConfigWrite writer(String panelId) => (key, value) async {
    final config = extensions.configs.putIfAbsent(panelId, () => {});
    if (value == null) {
      config.remove(key);
    } else {
      config[key] = value;
    }
  };
}

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);

Widget _pane(_Harness harness, String panelId, {Operation? operation}) =>
    OperationSummariesPanel(panelId: panelId, panels: harness.service, operation: operation ?? _operation(), qsos: const [], write: harness.writer(panelId));

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
        summariesOrderKey: ['core.dxcc', 'stats'],
      },
      'summaries#2': {
        summariesHiddenKey: ['stats', 'core.dxcc'],
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
        summariesHiddenKey: ['stats', 'core.dxcc', 'cqww.cqww'],
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
    expect(harness.extensions.configs['summaries#1']?[summariesFoldedKey], ['cqww.cqww']);

    // A fresh pane over the same placement comes up folded.
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpWidget(_app(_pane(harness, 'summaries#1')));
    await tester.pumpAndSettle();
    expect(find.text('72'), findsOneWidget);

    await tester.tap(find.text('CQ WW'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 QSOs'), findsOneWidget);
    expect(harness.extensions.configs['summaries#1']?.containsKey(summariesFoldedKey), isFalse, reason: 'nothing folded is nothing stored');
  });

  group('settings', () {
    Widget settings(_Harness harness, String panelId) => Builder(
      builder: (context) => OperationSummariesSettings(
        panelId: panelId,
        panels: harness.service,
        sections: operationSummarySections(context, operation: _operation(), qsos: const []),
        write: harness.writer(panelId),
      ),
    );

    Finder tick(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
      matching: find.byType(Checkbox),
    );

    testWidgets('an unticked section leaves the pane at once, and only that placement', (tester) async {
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
      expect(harness.extensions.configs['summaries#1']?[summariesHiddenKey], ['cqww.cqww']);
      expect(harness.extensions.configs['summaries#2'], isNull);
    });

    testWidgets("dragging reorders this operation's sections and keeps another operation's in place", (tester) async {
      final harness = _Harness({
        'summaries#1': {
          // Another operation's POTA section, ordered first there.
          summariesOrderKey: ['pota.activation', 'stats', 'cqww.cqww', 'core.dxcc'],
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
      final row = tester.getSize(find.byType(ListTile).first).height;
      for (var step = 0; step < 12; step++) {
        await gesture.moveBy(Offset(0, -row * 0.25));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(harness.extensions.configs['summaries#1']?[summariesOrderKey], ['pota.activation', 'core.dxcc', 'stats', 'cqww.cqww']);
    });

    testWidgets('reset forgets the picks, and is only offered when there are some', (tester) async {
      final harness = _Harness({
        'summaries#1': {
          summariesHiddenKey: ['stats'],
          summariesOrderKey: ['core.dxcc'],
        },
      });
      await tester.pumpWidget(_app(settings(harness, 'summaries#1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      expect(harness.extensions.configs['summaries#1'], isEmpty);
      expect(find.text('Show all'), findsNothing);
    });

    testWidgets("reset puts back this operation's sections and leaves another operation's picks", (tester) async {
      final harness = _Harness({
        'summaries#1': {
          summariesOrderKey: ['pota.activation', 'core.dxcc', 'stats'],
          summariesHiddenKey: ['pota.activation', 'cqww.cqww'],
        },
      });
      await tester.pumpWidget(_app(settings(harness, 'summaries#1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      // A reset that wiped every operation would cost a POTA pane its picks
      // for having been reset from inside a contest.
      expect(harness.extensions.configs['summaries#1'], {
        summariesOrderKey: ['pota.activation'],
        summariesHiddenKey: ['pota.activation'],
      });
    });

    testWidgets("offers no reset when only another operation's sections were picked", (tester) async {
      final harness = _Harness({
        'summaries#1': {
          summariesOrderKey: ['pota.activation', 'stats'],
          summariesHiddenKey: ['pota.activation'],
        },
      });
      await tester.pumpWidget(_app(settings(harness, 'summaries#1')));
      await tester.pumpAndSettle();
      expect(find.text('Show all'), findsNothing);
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
