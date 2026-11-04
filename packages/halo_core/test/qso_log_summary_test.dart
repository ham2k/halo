// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What an operation's statistics read from its log (QsoLogSummary): folded
// once, then extended contact by contact. The stats redraw every second over
// logs a DXpedition fills to six figures, so the extension is the path that
// runs — and it has to land exactly where a fold of the whole log would.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

const _minute = 60 * 1000;
const _hour = 60 * _minute;

Qso _contact(int minute, {bool deleted = false}) => Qso(
  uuid: 'q$minute',
  operationUuid: 'op',
  deleted: deleted,
  data: {
    'startAtMillis': minute * _minute,
    'band': '20m',
    'mode': 'CW',
    'their': {'call': 'W1AW'},
  },
);

Qso _event(String kind, int minute) => Qso(
  uuid: 'e$kind$minute',
  operationUuid: 'op',
  data: {
    'startAtMillis': minute * _minute,
    'band': 'event',
    'event': {'event': kind},
  },
);

Qso _timeless() => Qso(
  uuid: 'timeless',
  operationUuid: 'op',
  data: {
    'band': '20m',
    'their': {'call': 'K1ABC'},
  },
);

String _facts(QsoLogSummary s) =>
    '${s.contacts} ${s.firstContactAtMillis} ${s.lastContactAtMillis} ${s.startedAtMillis} '
    '${s.finishedAtMillis} ${s.pausedMillis} ${s.recentContactMillis}';

void main() {
  test('extended a row at a time, it lands where a fold of the whole log does', () {
    // Every split point: a summary carried forward by the stream must never
    // drift from the one a fresh read would fold.
    final log = [
      _event('note', 0),
      _event('start', 5),
      _contact(10),
      _contact(12, deleted: true),
      _contact(20),
      _event('pause', 21),
      _event('note', 60),
      _event('restart', 90),
      _contact(95),
      _timeless(),
      _contact(95 + 13 * 60),
      _event('stop', 95 + 13 * 60 + 5),
      _event('note', 95 + 14 * 60),
    ];
    final whole = _facts(QsoLogSummary.of(log));
    for (var split = 0; split <= log.length; split++) {
      var summary = QsoLogSummary.of(log.sublist(0, split));
      for (final row in log.sublist(split)) {
        summary = summary.extendedBy([row]);
      }
      expect(_facts(summary), whole, reason: 'split at $split');
    }
  });

  test('time away is the pause, the silence and nothing before the start', () {
    // A note a day before START is not a day the log stood still, and a
    // note after the last row counts nothing until something follows it.
    final summary = QsoLogSummary.of([
      _event('note', 60 - 24 * 60),
      _event('start', 60),
      _contact(70),
      _event('pause', 71),
      _event('restart', 101),
      _contact(110),
      _contact(110 + 12 * 60),
      _event('note', 110 + 25 * 60),
    ]);
    expect(summary.pausedMillis, 30 * _minute + 12 * _hour);
    expect(summary.startedAtMillis, 60 * _minute);
    expect(summary.contacts, 3);
  });

  test('a contact with no start time counts, and moves nothing on the timeline', () {
    // Synced or imported without a time, it is still a contact the log holds;
    // dropped from the count, a log of nothing else would read "No QSOs".
    final summary = QsoLogSummary.of([_contact(10), _timeless(), _contact(20)]);
    expect(summary.contacts, 3);
    expect(summary.firstContactAtMillis, 10 * _minute);
    expect(summary.lastContactAtMillis, 20 * _minute);
    expect(summary.recentContactMillis, [10 * _minute, 20 * _minute]);
    expect(QsoLogSummary.of([_timeless()]).contacts, 1);
  });

  test('it keeps the last hundred contacts, and the whole of the newest hour', () {
    // A rate over the last 60 minutes reads every contact in them, and at a
    // pileup's pace an hour is several hundred; a rate over the last 100
    // reads the hundredth, however long ago it was.
    final pileup = QsoLogSummary.of([
      for (var i = 0; i < 1800; i++) Qso(uuid: 'p$i', operationUuid: 'op', data: {'startAtMillis': i * 6000}),
    ]);
    final newest = 1799 * 6000;
    expect(pileup.recentContactMillis.first, greaterThanOrEqualTo(newest - _hour - 6000));
    expect(pileup.recentContactMillis.where((at) => at >= newest - _hour), hasLength(601));

    final slow = QsoLogSummary.of([for (var i = 0; i < 300; i++) _contact(i * 5)]);
    expect(slow.recentContactMillis, hasLength(qsoLogRecentContacts));
    expect(slow.recentContactMillis.last, 299 * 5 * _minute);
  });
}
