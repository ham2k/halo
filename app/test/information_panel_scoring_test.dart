// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Info pane is where a contester checks their running score without
// exporting a Cabrillo file, so a contest's summary reaching it — in full,
// per-band table and all — is the point. This pane already silently lost its
// scoring block once when `local_data.scoring` became per-scorer, with no test
// to catch it; these cover both the core lines and a contest's own section.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/operation/information_panel.dart';

/// What ScoringService caches once core and CQ WW have both scored.
Operation _operation() => Operation(
      uuid: 'op-1',
      data: {
        'stationCall': 'N0DEV',
        'refs': [
          {'type': 'cqww', 'mode': 'CW', 'shortLabel': 'CQ WW CW'},
        ],
      },
      localData: {
        'scoring': {
          'core': {
            'operationSummary': {
              'qsoCount': {'key': 'qsoCount', 'total': 12, 'duplicates': 2},
              'dxcc': {
                'key': 'dxcc',
                'total': 3,
                'entities': {'K': 5, 'DL': 4, 'JA': 3},
              },
            },
          },
          'cqww': {
            'operationSummary': {
              'cqww': {
                'key': 'cqww',
                'icon': 'earth',
                'total': 72,
                'label': '18 × 4',
                'summary': '72',
                'longSummary': '**20m**: 4 QSOs, 12 pts, 2 mults\n**40m**: 2 QSOs, 6 pts, 2 mults',
              },
            },
          },
        },
      },
    );

Future<void> _pump(
  WidgetTester tester,
  Operation operation, {
  List<Qso> qsos = const [],
  List<Map<String, dynamic>> activityControls = const [],
}) async {
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: InformationPanel(operation: operation, qsos: qsos, activityControls: activityControls),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a contest summary reaches the pane in full, under the contest\'s own name', (tester) async {
    await _pump(tester, _operation());

    // Headed by what decorateRef called it, not the bare extension key.
    expect(find.text('CQ WW CW'), findsOneWidget);
    expect(find.text('cqww'), findsNothing);

    // The tally's label and score.
    expect(find.text('18 × 4'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);

    // The per-band breakdown renders as markdown rather than being dropped or
    // shown as literal asterisks.
    final markdown = tester.widgetList<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.any((m) => m.data.contains('**20m**')), isTrue);
    // Single newlines must break lines — otherwise the table reads as one
    // run-on paragraph.
    expect(markdown.any((m) => m.softLineBreak == true), isTrue);
  });

  testWidgets(
    'a tally icon is tinted with its own extension\'s accent color, not the QSO rows\' neutral foreground (APP-20)',
    (tester) async {
      await _pump(
        tester,
        _operation(),
        activityControls: [
          {
            'icon': 'earth',
            'color': '#FF00FF',
            'input': {'refType': 'cqww'},
          },
        ],
      );

      final finder = find.byIcon(MdiIcons.earth);
      final icon = tester.widget<Icon>(finder);
      final scheme = Theme.of(tester.element(finder)).colorScheme;
      expect(icon.color, const Color(0xFFFF00FF));
      expect(icon.color, isNot(scheme.onSurface));
    },
  );

  testWidgets(
    'a tally icon falls back to plain grey when its extension declares no accent color (APP-20)',
    (tester) async {
      await _pump(tester, _operation());

      final finder = find.byIcon(MdiIcons.earth);
      final icon = tester.widget<Icon>(finder);
      final scheme = Theme.of(tester.element(finder)).colorScheme;
      expect(icon.color, scheme.onSurfaceVariant);
    },
  );

  testWidgets('core keeps its curated lines, including the duplicate count', (tester) async {
    await _pump(tester, _operation());
    // `duplicates` lives in a tally field, not a label, so a generic render
    // would silently drop it.
    expect(find.textContaining('2'), findsWidgets);
    expect(find.textContaining('Duplicates'), findsOneWidget);
    expect(find.textContaining('DXCC'), findsWidgets);
  });

  testWidgets('an operation with no scoring yet renders without a contest section', (tester) async {
    await _pump(tester, Operation(uuid: 'op-2', data: {'stationCall': 'N0DEV'}));
    expect(find.text('Operation Stats'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsNothing);
  });

  testWidgets('the pane scrolls, so a long contest table cannot push content out of reach', (tester) async {
    await _pump(tester, _operation());
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.widget<ListView>(find.byType(ListView)).physics, isNot(isA<NeverScrollableScrollPhysics>()));
  });

  testWidgets('never shows the station callsign — the pane is stats and scoring, not identity', (tester) async {
    await _pump(tester, _operation());
    expect(find.text('N0DEV'), findsNothing);
  });

  testWidgets('leads with the basic stats block (count/duration, then rate)', (tester) async {
    final qsos = [
      for (var i = 0; i < 11; i++)
        Qso(uuid: 'q$i', operationUuid: 'op-1', data: {'their': {'call': 'W1AW$i'}, 'startAtMillis': i * 60000}),
    ];
    await _pump(tester, Operation(uuid: 'op-1', data: {'stationCall': 'N0DEV'}), qsos: qsos);

    expect(find.text('Operation Stats'), findsOneWidget);
    expect(find.textContaining('11 QSOs in'), findsOneWidget);
    expect(find.textContaining('Q/h for last 10'), findsOneWidget);
  });
}
