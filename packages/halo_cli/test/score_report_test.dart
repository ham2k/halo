// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The markdown report. Fixtures are the real shapes core's scorer emits —
// taken from scoring a POTA activation — because the rendering rules here
// exist to serve those exact quirks: a tally with an empty `label` and a
// composed `longSummary`, and a tally whose breakdown the scorer never spells
// out.

import 'package:halo_cli/src/score_report.dart';
import 'package:test/test.dart';

void main() {
  const qsoCount = {'key': 'qsoCount', 'total': 44, 'count': 44, 'duplicates': 0, 'label': '44 QSOs', 'summary': '44'};
  const dxcc = {
    'key': 'dxcc',
    'total': 4,
    'entities': {'K': 35, 'KP4': 1, 'HK': 1, 'HI': 7},
    'label': '4 DXCC Entities',
    'summary': '',
  };
  const bandsAndModes = {
    'key': 'bandsAndModes',
    'total': 1,
    'bands': {'20m': 44},
    'modes': {'SSB': 44},
    'label': '',
    'longSummary': '**20m**: 44 SSB',
  };

  group('summaries', () {
    test('a scorer that composed a long summary is not repeated back to it', () {
      // bandsAndModes says "**20m**: 44 SSB" AND carries the bands/modes
      // maps it built that from. Appending them prints every count twice.
      final md = scoreSummariesMarkdown(const {'bandsAndModes': bandsAndModes});
      expect(md, contains('**20m**: 44 SSB'));
      expect(md, isNot(contains('bands:')));
      expect(md, isNot(contains('modes:')));
    });

    test('a breakdown the scorer did NOT spell out is shown', () {
      // "4 DXCC Entities" does not say which four. Dropping the map would
      // lose the only place that answer exists.
      final md = scoreSummariesMarkdown(const {'dxcc': dxcc});
      expect(md, contains('4 DXCC Entities'));
      expect(md, contains('entities: K 35, HI 7, HK 1, KP4 1'));
    });

    test('breakdowns are ordered by count, then by name', () {
      // Ties broken on the name so two runs of the same log render
      // identically — a report that reshuffles is a report you cannot diff.
      final md = scoreSummariesMarkdown(const {
        'dxcc': {
          'total': 3,
          'entities': {'ZZ': 2, 'AA': 2, 'MM': 9},
          'label': '3 entities',
        },
      });
      expect(md, contains('entities: MM 9, AA 2, ZZ 2'));
    });

    test('duplicates are mentioned only when there are any', () {
      expect(scoreSummariesMarkdown(const {'qsoCount': qsoCount}), isNot(contains('duplicate')));
      expect(
        scoreSummariesMarkdown(const {
          'qsoCount': {'total': 43, 'duplicates': 1, 'label': '43 QSOs'},
        }),
        contains('1 duplicate'),
      );
    });

    test('an unknown tally from another scorer still renders', () {
      // A contest's tallies are its own (zones, sections, multipliers). The
      // renderer must not have a list of the four core ones.
      final md = scoreSummariesMarkdown(const {
        'zones': {
          'total': 12,
          'label': '12 Zones',
          'zones': {'5': 30, '8': 2},
        },
      });
      expect(md, contains('`zones`'));
      expect(md, contains('12 Zones'));
      expect(md, contains('zones: 5 30, 8 2'));
    });

    test('nothing scored says so instead of rendering an empty table', () {
      expect(scoreSummariesMarkdown(const {}), contains('No tallies'));
    });
  });

  group('sections', () {
    test('columns are the union across days, in first-seen order', () {
      // A scorer can start reporting a tally on the day it first applies;
      // taking only the first day's keys would drop it from the table.
      final md = scoreSectionsMarkdown(const [
        {
          'day': 1784073600000,
          'count': 44,
          'scores': {'qsoCount': qsoCount},
        },
        {
          'day': 1784160000000,
          'count': 3,
          'scores': {'qsoCount': qsoCount, 'dxcc': dxcc},
        },
      ]);
      expect(md, contains('| Day (UTC) | QSOs | `qsoCount` | `dxcc` |'));
      expect(md, contains('| 2026-07-15 | 44 |'));
      expect(md, contains('| 2026-07-16 | 3 |'));
    });

    test('the day is the UTC bucket it is, not a local date', () {
      // Day sections are 24h UTC buckets by convention; rendering them in the
      // local zone would shift a late-evening activation onto the wrong day.
      expect(
        scoreSectionsMarkdown(const [
          {'day': 1784073600000, 'count': 1, 'scores': {}},
        ]),
        contains('2026-07-15'),
      );
    });
  });

  group('qsos', () {
    const scores = {
      'q1': {
        'value': 1,
        'notices': ['newState'],
      },
      'q2': {
        'value': 0,
        'alerts': ['duplicate'],
      },
    };

    test('joins the verdicts to the log, since a uuid table says nothing', () {
      final md = scoreQsosMarkdown(
        scores,
        qsos: const [
          {
            'uuid': 'q1',
            'startAtMillis': 1784154300000,
            'band': '20m',
            'mode': 'SSB',
            'their': {'call': 'N2JIM'},
          },
          {
            'uuid': 'q2',
            'startAtMillis': 1784154360000,
            'band': '20m',
            'mode': 'SSB',
            'their': {'call': 'N2JIM'},
          },
        ],
      );
      expect(md, contains('| Time (UTC) | Call | Band | Mode | Points | Notices |'));
      expect(md, contains('N2JIM'));
      expect(md, contains('newState'));
      // Alerts are the louder half of the same vocabulary, so they share the
      // column and are marked rather than silently reading like a notice.
      expect(md, contains('**duplicate**'));
    });

    test('without a log the uuid is shown, not omitted', () {
      final md = scoreQsosMarkdown(scores);
      expect(md, contains('| QSO | Points | Notices |'));
      expect(md, contains('`q1`'));
    });

    test('a QSO the log does not carry leaves blanks, not a crash', () {
      // The log and the verdicts can disagree — a caller may score one file
      // and pass another. Better a blank row than an exception.
      final md = scoreQsosMarkdown(
        const {
          'missing': {'value': 1},
        },
        qsos: const [
          {
            'uuid': 'other',
            'their': {'call': 'W1AW'},
          },
        ],
      );
      expect(md, contains('| 1 |'));
    });
  });

  test('a pipe in a cell cannot break the table', () {
    // Extension-supplied text lands in these cells; an unescaped pipe would
    // silently add a column and misalign every row after it.
    final md = scoreSummariesMarkdown(const {
      'odd': {'total': 1, 'label': 'a | b'},
    });
    expect(md, contains(r'a \| b'));
  });
}
