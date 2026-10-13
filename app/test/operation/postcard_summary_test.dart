// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The summary pages promise the Info pane's content, all of it, on as many
// pictures as it takes: a section never split when a page could hold it
// whole, and one that no page can hold carried on under its heading with no
// line lost or drawn twice and none running into the footer.

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/operation/operation_postcard.dart';
import 'package:ham2k_logger/views/operation/postcard_options_dialog.dart';
import 'package:ham2k_logger/views/operation/postcard_summary.dart';

void main() {
  group("the scorers' markdown", () {
    List<Object> shape(List<PostcardParagraph> paragraphs) => [
      for (final p in paragraphs)
        [
          p.kind,
          for (final r in p.runs) [r.text, r.bold, r.struck],
        ],
    ];

    test('keeps each line of a breakdown on a line of its own, as the pane does', () {
      expect(shape(postcardParagraphs('**20m**: 12 — 8 CW\n**40m**: 3')), [
        [
          PostcardTextKind.body,
          ['20m', true, false],
          [': 12 — 8 CW\n', false, false],
          ['40m', true, false],
          [': 3', false, false],
        ],
      ]);
    });

    // A multi-operator breakdown indents each block's band lines with
    // non-breaking spaces and separates the blocks with a blank line. Trimming
    // a line, or reading the blank line as a break inside one paragraph, runs
    // one operator's bands into the next operator's heading.
    test("keeps an operator block's indent, and each block a paragraph of its own", () {
      const indent = '\u00A0\u00A0\u00A0\u00A0';
      expect(shape(postcardParagraphs('**Overall**: 3 QSOs\n$indent**20m**: 3 CW\n\n**KI2D**: 2 QSOs\n$indent**20m**: 2 CW')), [
        [
          PostcardTextKind.body,
          ['Overall', true, false],
          [': 3 QSOs\n$indent', false, false],
          ['20m', true, false],
          [': 3 CW', false, false],
        ],
        [
          PostcardTextKind.body,
          ['KI2D', true, false],
          [': 2 QSOs\n$indent', false, false],
          ['20m', true, false],
          [': 2 CW', false, false],
        ],
      ]);
    });

    test("reads a grid's worked codes, its headings and its paragraphs", () {
      expect(shape(postcardParagraphs('5 × 3 = 15\n\n### 2 of 67 Counties\n**~~ADA~~** ALL', grid: true)), [
        [
          PostcardTextKind.grid,
          ['5 × 3 = 15', false, false],
        ],
        [
          PostcardTextKind.subheading,
          ['2 of 67 Counties', false, false],
        ],
        [
          PostcardTextKind.grid,
          ['ADA', true, true],
          [' ALL', false, false],
        ],
      ]);
    });

    test('takes a hash with no space after it for text, as Markdown does', () {
      expect(shape(postcardParagraphs('#1 hunter')), [
        [
          PostcardTextKind.body,
          ['#1 hunter', false, false],
        ],
      ]);
    });
  });

  group('the sections', () {
    Future<List<PostcardSummarySection>> sectionsFor(WidgetTester tester, Operation operation, List<Qso> qsos) async {
      late List<PostcardSummarySection> sections;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                sections = postcardSummarySections(context, operation: operation, qsos: qsos);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return sections;
    }

    Map<String, dynamic> day(int millis, int count, {Map<String, dynamic> extra = const {}}) => {
      'day': millis,
      'scores': {
        'qsoCount': {'key': 'qsoCount', 'for': 'day', 'count': count},
        ...extra,
      },
    };

    final scoring = {
      'core': {
        'operationSummary': {
          'qsoCount': {'key': 'qsoCount', 'total': 12, 'duplicates': 2},
          'bandsAndModes': {'key': 'bandsAndModes', 'label': '2 Bands', 'summary': '2', 'longSummary': '**80m**: 2\n**30m**: 10'},
          'states': {'key': 'states', 'label': '3 States', 'summary': '3', 'icon': 'star'},
        },
      },
      'cqww': {
        'operationSummary': {
          'cqww': {'key': 'cqww', 'icon': 'earth', 'label': '18 × 4', 'summary': '72', 'longSummary': '**20m**: 4 QSOs'},
        },
      },
    };

    testWidgets("are the Info pane's: the stats, then the contest, then core's own tallies", (tester) async {
      final sections = await sectionsFor(tester, Operation(uuid: 'op', data: const {}, localData: {'scoring': scoring}), const []);
      expect([for (final s in sections) s.heading.title], ['Operation Stats', '18 × 4', '2 Bands', '3 States']);
      expect([for (final s in sections) s.key], ['stats', 'cqww.cqww', 'core.bandsAndModes', 'core.states'], reason: 'the same from one operation to the next');
      // A tally's detail says its number in full; the figure stands beside it
      // only where there is none.
      expect([for (final s in sections.skip(1)) s.heading.trailing], [null, null, '3']);
      expect(sections[2].body.single, isA<PostcardParagraph>());
    });

    testWidgets('leave out the now-relative "since last", and count the duplicates with the stats', (tester) async {
      final recent = Qso(uuid: 'q', operationUuid: 'op', data: {'uuid': 'q', 'startAtMillis': nowMillis() - 60000, 'band': '20m'});
      final sections = await sectionsFor(tester, Operation(uuid: 'op', data: const {}, localData: {'scoring': scoring}), [recent]);
      final lines = [for (final p in sections.first.body.cast<PostcardParagraph>()) p.runs.map((r) => r.text).join()];
      expect(lines.any((line) => line.contains('since last')), isFalse, reason: 'a picture is looked at long after it was made');
      expect(lines.last, 'Duplicates: 2');
    });

    testWidgets("give each day its own section only when there is more than one, with that day's own tallies", (tester) async {
      final pota = {'key': 'activation', 'for': 'day', 'label': 'POTA: 12', 'icon': 'pine-tree', 'longSummary': '✅ **US-1234: 12**'};
      final carried = {'key': 'dxcc', 'for': 'operation', 'label': '3 DXCC'};
      Operation withDays(List<Map<String, dynamic>> days) => Operation(
        uuid: 'op',
        data: const {},
        localData: {
          'scoring': {
            'core': {'daySections': days},
            'pota': {
              'daySections': [
                {
                  'day': days.first['day'],
                  'scores': {'activation': pota, 'dxcc': carried},
                },
              ],
            },
          },
        },
      );

      final one = await sectionsFor(tester, withDays([day(0, 12)]), const []);
      expect(one, hasLength(1), reason: "one day's breakdown would only restate the totals");

      final two = await sectionsFor(tester, withDays([day(0, 12), day(86400000, 5)]), const []);
      expect(
        [for (final s in two) (s.heading.title, s.heading.trailing)],
        [('Operation Stats', null), ('Thursday, January 1, 1970', '12 QSOs'), ('Friday, January 2, 1970', '5 QSOs')],
      );
      final heading = two[1].body.first as PostcardHeading;
      expect((heading.title, heading.major), ('POTA: 12', false), reason: 'the day-scoped tally, a heading inside the day');
      expect(two[1].body, hasLength(2), reason: 'not the operation-wide tally carried into the day');
    });
  });

  group('the sections picked', () {
    PostcardSummarySection section(String key, [String title = '']) => PostcardSummarySection(PostcardHeading(title.isEmpty ? key : title), const [], key: key);
    List<String> titles(List<PostcardSummarySection> sections) => [for (final s in sections) s.heading.title];
    final sections = [section('stats'), section('days', 'Mon'), section('days', 'Tue'), section('pota.activation'), section('core.dxcc')];

    test('go in the order picked, the days together, less those left out', () {
      expect(titles(postcardSectionsPicked(sections, order: ['core.dxcc', 'days', 'stats'], hidden: {'stats'})), [
        'core.dxcc',
        'Mon',
        'Tue',
        'pota.activation',
      ]);
    });

    test("keep another operation's sections where they were when this one's are reordered", () {
      // Operation A put POTA before its stats; operation B, without POTA,
      // now puts DXCC before its stats. A must still find POTA first.
      final order = postcardSectionsOrder(['pota.activation', 'stats'], ['core.dxcc', 'stats'], here: {'stats', 'core.dxcc'});
      expect(order, ['pota.activation', 'core.dxcc', 'stats']);
      expect(titles(postcardSectionsPicked([section('stats'), section('pota.activation')], order: order)), ['pota.activation', 'stats']);
    });

    test('put a section the order does not name after the rest, as it came, and ignore keys this operation lacks', () {
      expect(titles(postcardSectionsPicked(sections, order: ['wwff.activation', 'core.dxcc'])), ['core.dxcc', 'stats', 'Mon', 'Tue', 'pota.activation']);
    });
  });

  group('the options dialog', () {
    const choices = <PostcardSectionChoice>[
      (key: 'stats', label: 'Operation Stats', icon: null, iconColor: null),
      (key: 'days', label: 'Each day', icon: null, iconColor: null),
      (key: 'core.dxcc', label: '6 DXCC Entities', icon: 'earth', iconColor: null),
    ];

    Future<PostcardOptionsPick?> pick(
      WidgetTester tester,
      Future<void> Function() steps, {
      bool legend = true,
      List<PostcardSectionChoice> choices = choices,
      bool custom = false,
    }) async {
      PostcardOptionsPick? result;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showPostcardOptionsDialog(context, legend: legend, choices: choices, hidden: {'days'}, custom: custom),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await steps();
      return result;
    }

    Finder tick(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
      matching: find.byType(Checkbox),
    );

    testWidgets('ticks, reorders by the handle, and saves what it shows', (tester) async {
      final result = await pick(tester, () async {
        expect(tester.widget<Checkbox>(tick('Each day')).value, isFalse, reason: 'left out as it was');
        await tester.tap(tick('Each day'));
        await tester.tap(tick('Operation Stats'));
        await tester.pump();
        expect(
          [
            for (final label in ['Operation Stats', 'Each day', '6 DXCC Entities']) tester.widget<Checkbox>(tick(label)).value,
          ],
          [false, true, true],
        );
        // The last one dragged to the top.
        final handle = find.descendant(
          of: find.ancestor(of: find.text('6 DXCC Entities'), matching: find.byType(ListTile)),
          matching: find.byIcon(MdiIcons.dragHorizontalVariant),
        );
        final gesture = await tester.startGesture(tester.getCenter(handle));
        await tester.pump(kLongPressTimeout);
        final row = tester.getSize(find.byType(ListTile).first).height;
        for (var step = 0; step < 10; step++) {
          await gesture.moveBy(Offset(0, -row * 0.25));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      });
      expect(result?.order, ['core.dxcc', 'stats', 'days']);
      expect(result?.hidden, {'stats'});
      expect(result?.reset, isFalse);
      expect(result?.legend, isTrue, reason: 'left on as it was');
    });

    testWidgets('turns the band legend off from its own row, above the sections and their heading', (tester) async {
      final result = await pick(tester, () async {
        expect(find.text('Postcard Options'), findsOneWidget);
        expect(tester.getTopLeft(find.text('Show band legend')).dy, lessThan(tester.getTopLeft(find.text('Summary Sections and Ordering')).dy));
        expect(tester.getTopLeft(find.text('Summary Sections and Ordering')).dy, lessThan(tester.getTopLeft(find.text('Operation Stats')).dy));
        await tester.tap(find.text('Show band legend'));
        await tester.pump();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      });
      expect(result?.legend, isFalse);
      expect(result?.hidden, {'days'}, reason: 'the sections as they were');
    });

    testWidgets('with no sections to pick, offers the legend alone', (tester) async {
      await pick(tester, () async {
        expect(find.text('Show band legend'), findsOneWidget);
        expect(find.text('Summary Sections and Ordering'), findsNothing, reason: 'a heading over nothing');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }, choices: const []);
    });

    testWidgets('a reset turns the legend back on with the sections', (tester) async {
      final result = await pick(
        tester,
        () async {
          await tester.tap(find.text('Reset'));
          await tester.pumpAndSettle();
        },
        legend: false,
        custom: true,
      );
      expect(result?.reset, isTrue);
      expect(result?.legend, isTrue);
    });

    testWidgets('changes nothing when cancelled', (tester) async {
      final result = await pick(tester, () async {
        await tester.tap(tick('Each day'));
        await tester.pump();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });
      expect(result, isNull);
    });
  });

  group('the layout', () {
    const page = Size(540, 960);
    String continued(String title) => '$title (continued)';

    PostcardSummarySection section(String title, int lines, {bool apart = true}) => PostcardSummarySection(
      PostcardHeading(title),
      apart ? [for (var i = 0; i < lines; i++) PostcardParagraph.plain('line $i')] : [PostcardParagraph.plain(List.filled(lines, 'line').join('\n'))],
    );

    void fitsItsPages(PostcardSummaryLayout layout) {
      for (final pieces in layout.pages) {
        for (final piece in pieces) {
          expect(piece.top + piece.height, lessThanOrEqualTo(layout.content.height + 0.01), reason: 'into the footer');
        }
      }
    }

    test('leaves no page for nothing', () {
      expect(postcardSummaryLayout(const [], page: page, header: 100, continued: continued).pages, isEmpty);
    });

    test('starts a section on a new page rather than split one a page could hold whole', () {
      final layout = postcardSummaryLayout([section('One', 15), section('Two', 15)], page: page, header: 100, continued: continued);
      expect(layout.pages, hasLength(2), reason: 'the case being tested: both do not fit on one');
      final second = layout.pages[1];
      expect((second.first.block as PostcardHeading).title, 'Two');
      expect(second, hasLength(16), reason: 'all of it, heading and every line');
      fitsItsPages(layout);
    });

    test('runs a section taller than a page on under its heading, continued, losing and repeating no line', () {
      final layout = postcardSummaryLayout([section('Long', 100, apart: false)], page: page, header: 100, continued: continued);
      expect(layout.pages.length, greaterThanOrEqualTo(3));
      for (final pieces in layout.pages.skip(1)) {
        expect((pieces.first.block as PostcardHeading).title, 'Long (continued)');
      }
      final parts = [for (final pieces in layout.pages) ...pieces.where((p) => p.block is PostcardParagraph)];
      expect(parts.first.from, 0);
      for (var i = 1; i < parts.length; i++) {
        expect(parts[i].from, closeTo(parts[i - 1].from + parts[i - 1].height, 1e-6), reason: 'each page picks up where the last left off');
      }
      // The whole of it, as a page tall enough to hold it in one piece has it.
      final whole = postcardSummaryLayout([section('Long', 100, apart: false)], page: const Size(540, 100000), header: 100, continued: continued);
      expect(parts.last.from + parts.last.height, closeTo(whole.pages.single.last.height, 0.01));
      fitsItsPages(layout);
    });

    test("never ends a page on a heading, whatever the header's height", () {
      // Each taller than a page, so that tallies' headings land all down
      // the pages as the header's height moves them.
      final sections = [
        for (var s = 0; s < 3; s++)
          PostcardSummarySection(PostcardHeading('Day $s'), [
            for (var t = 0; t < 10; t++) ...[PostcardHeading('Tally $t', major: false), PostcardParagraph.plain(List.filled(3, 'row').join('\n'))],
          ]),
      ];
      for (var header = 60.0; header <= 300; header += 3) {
        final layout = postcardSummaryLayout(sections, page: page, header: header, continued: continued);
        for (final pieces in layout.pages) {
          expect(pieces.last.block, isA<PostcardParagraph>(), reason: 'a heading at the foot of a page heads nothing (header $header)');
        }
        fitsItsPages(layout);
      }
    });
  });

  testWidgets('draws a page outside the tree at its logical size times the ratio', (tester) async {
    final image = await tester.runAsync(
      () => paintOffscreen(
        const ColoredBox(color: Color(0xFFFF0000)),
        size: const Size(30, 20),
        pixelRatio: 2,
        view: tester.view,
      ),
    );
    final pixels = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    expect((image!.width, image.height), (60, 40));
    expect(pixels!.getUint32(4 * (40 * 60 - 1)), 0xFF0000FF, reason: 'drawn to its far corner');
    image.dispose();
  });

  testWidgets("a summary page lays its pieces where the layout put them, the overlay's header over it", (tester) async {
    final layout = postcardSummaryLayout(
      [
        PostcardSummarySection(const PostcardHeading('Stats'), [PostcardParagraph.plain('12 QSOs')]),
      ],
      page: PostcardShape.portrait.logicalSize,
      header: 100,
      continued: (t) => t,
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: PostcardSummaryPage(
              shape: PostcardShape.portrait,
              text: const PostcardText(title: 'N0CALL', subtitle: '', stats: '1 QSO', date: ''),
              attribution: '© OSM',
              isDark: false,
              layout: layout,
              page: 0,
            ),
          ),
        ),
      ),
    );
    final origin = tester.getTopLeft(find.byType(PostcardSummaryPage));
    final line = layout.pages.single.last;
    expect(tester.getTopLeft(find.text('12 QSOs', findRichText: true)) - origin, layout.content.topLeft + Offset(0, line.top));
  });

  testWidgets("a summary page draws no band legend: its text runs into the legend's corner", (tester) async {
    final layout = postcardSummaryLayout(
      [
        PostcardSummarySection(const PostcardHeading('Stats'), [PostcardParagraph.plain('12 QSOs')]),
      ],
      page: PostcardShape.portrait.logicalSize,
      header: 100,
      continued: (t) => t,
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: PostcardSummaryPage(
              shape: PostcardShape.portrait,
              text: const PostcardText(
                title: 'N0CALL',
                subtitle: '',
                stats: '3 QSOs',
                date: '',
                bands: [
                  (band: '40m', color: Color(0xFF1686F0), count: '1 Q'),
                  (band: '20m', color: Color(0xFF49C215), count: '1 Q'),
                  (band: '6m', color: Color(0xFFEB1018), count: '1 Q'),
                ],
              ),
              attribution: '© OSM',
              isDark: false,
              layout: layout,
              page: 0,
            ),
          ),
        ),
      ),
    );
    expect(find.text('40m'), findsNothing);
  });
}
