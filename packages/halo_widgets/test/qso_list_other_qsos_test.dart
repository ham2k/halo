// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QsoList.otherQsos: the station's contacts from outside the log, shown under
// their own header by an exact-callsign find. They are there to be read
// after the log, never to displace it — the list still rests on the log's
// newest row, scrolls to the log's rows where they are, and keeps the log's
// columns — and never to be edited from it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

const _label = 'Other contacts outside of this operation';
const _noLogQsos = 'No QSOs in this operation';

final _past = DateTime.utc(2025, 3, 14, 12).millisecondsSinceEpoch;
final _today = DateTime.utc(2026, 10, 11, 12).millisecondsSinceEpoch;

Qso _qso(String uuid, String call, int startAtMillis, {double freq = 14025}) => Qso(
  uuid: uuid,
  operationUuid: '',
  data: {
    'uuid': uuid,
    'their': {'call': call},
    'freq': freq,
    'mode': 'CW',
    'startAtMillis': startAtMillis,
  },
);

/// [count] contacts a minute apart today, oldest first, each its own call.
List<Qso> _log(int count) => [for (var i = 0; i < count; i++) _qso('log$i', 'K${i}AA', _today + i * 60000)];

/// [count] contacts with K1AB a day apart, oldest first.
List<Qso> _others(int count, {double freq = 14025}) => [for (var i = 0; i < count; i++) _qso('other$i', 'K1AB', _past + i * 86400000, freq: freq)];

Widget _host(List<Qso> qsos, List<Qso> others, {List<Qso>? log, bool newestFirst = false, String? selectedUuid, void Function(Qso)? onSelect}) => MaterialApp(
  theme: buildHaLoTheme(Brightness.light),
  home: Scaffold(
    body: SizedBox(
      height: 400,
      child: QsoList(
        qsos: qsos,
        log: log,
        noQsosLabel: _noLogQsos,
        otherQsos: others,
        otherQsosLabel: _label,
        onSelect: onSelect ?? (_) {},
        newestFirst: newestFirst,
        selectedUuid: selectedUuid,
      ),
    ),
  ),
);

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  for (final newestFirst in [false, true]) {
    testWidgets('the section follows the log (newestFirst: $newestFirst)', (tester) async {
      await tester.pumpWidget(_host(_log(3), _others(2), newestFirst: newestFirst));
      await tester.pumpAndSettle();
      expect(_top(tester, find.text('K0AA')), lessThan(_top(tester, find.text(_label))));
      expect(_top(tester, find.text('K2AA')), lessThan(_top(tester, find.text(_label))));
      expect(_top(tester, find.text('2025-03-14')) < _top(tester, find.text('2025-03-15')), !newestFirst, reason: 'the section runs in the list\'s own order');
    });
  }

  // The trap: oldest first, the list rests on its bottom, which is now the
  // section's end — the operator would open a find on a screenful of last
  // year's contacts with this operation's scrolled away.
  testWidgets('oldest first, a log longer than the screen still opens on its newest match', (tester) async {
    await tester.pumpWidget(_host(_log(40), _others(30)));
    await tester.pumpAndSettle();
    expect(find.text('K39AA'), findsOneWidget, reason: 'the newest contact is on screen');
    expect(find.text('2025-04-12'), findsNothing, reason: 'the section\'s end is not');
  });

  // Rows show only the time of day, and no day header groups these: without
  // the date, a contact from last year reads as one from this morning.
  testWidgets('another operation\'s contact shows its date in place of its time', (tester) async {
    await tester.pumpWidget(_host(const [], _others(1)));
    await tester.pumpAndSettle();
    expect(find.text('2025-03-14'), findsOneWidget);
    expect(find.text('12:00z'), findsNothing);
  });

  // Without the log's own header above them, the section's rows sit at the
  // top of the list where the log's matches go, and read as matches in it.
  for (final newestFirst in [false, true]) {
    testWidgets('with no matches in the log, its last day and a line saying so hold its place (newestFirst: $newestFirst)', (tester) async {
      final log = [
        _qso('a', 'W1AW', DateTime.utc(2026, 10, 9, 12).millisecondsSinceEpoch),
        _qso('b', 'W2AW', DateTime.utc(2026, 10, 10, 12).millisecondsSinceEpoch),
      ];
      final dayOf = DateTime.utc(2026, 10, 10).millisecondsSinceEpoch;
      await tester.pumpWidget(_host(const [], _others(2), log: log, newestFirst: newestFirst));
      await tester.pumpAndSettle();
      expect(find.text('K1AB'), findsNWidgets(2));
      final header = find.byWidgetPredicate((w) => w is DayHeaderRow && w.dayMillis == dayOf && w.count == null);
      expect(header, findsOneWidget, reason: 'the log\'s last day, with no count beside it');
      expect(_top(tester, header), lessThan(_top(tester, find.text(_noLogQsos))));
      final row = QsoList.rowHeightOf(tester.element(find.byType(QsoList)));
      final section = find.ancestor(of: find.text(_label), matching: find.byType(Material)).first;
      expect(
        _top(tester, section) - tester.getBottomLeft(find.text(_noLogQsos)).dy,
        greaterThanOrEqualTo(2 * row),
        reason: 'the gap still sets the section apart',
      );
    });
  }

  // Selecting loads a row into this log's editor, whose save stamps it with
  // this operation's station — rewriting a contact from somewhere else.
  testWidgets('a tap on another operation\'s contact selects nothing', (tester) async {
    final selected = <Qso>[];
    await tester.pumpWidget(_host(_log(1), _others(1), onSelect: selected.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025-03-14'));
    await tester.tap(find.text('K0AA'));
    expect(selected.map((q) => q.uuid), ['log0']);
  });

  testWidgets('the section header stays pinned while its contacts scroll under it', (tester) async {
    await tester.pumpWidget(_host(const [], _others(40)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final scroller = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(find.text('2025-03-14'), findsNothing, reason: 'scrolled to the far end of the section');
    expect(_top(tester, find.ancestor(of: find.text(_label), matching: find.byType(Material)).first), scroller);
  });

  testWidgets('the section is set apart from the log by two rows of blank', (tester) async {
    await tester.pumpWidget(_host(_log(1), _others(2)));
    await tester.pumpAndSettle();
    final row = QsoList.rowHeightOf(tester.element(find.byType(QsoList)));
    final logRow = find.ancestor(of: find.text('K0AA'), matching: find.byType(InkWell)).first;
    final section = find.ancestor(of: find.text(_label), matching: find.byType(Material)).first;
    expect(_top(tester, section) - tester.getBottomLeft(logRow).dy, greaterThanOrEqualTo(2 * row));
  });

  // The section is read after the find applies, so it always lands on a list
  // already drawn. Mounting with it already there proves none of what
  // follows.
  group('when the section lands after the log', () {
    testWidgets('onto the empty message, the list opens on the log\'s place and the section\'s start', (tester) async {
      await tester.pumpWidget(_host(const [], const []));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(const [], _others(40)));
      await tester.pumpAndSettle();
      expect(find.text(_noLogQsos), findsOneWidget);
      expect(find.text('2025-03-14'), findsOneWidget, reason: 'the oldest of the other contacts, first under the header');
    });

    // The trap: the section grows the list below the newest row, and a list
    // that follows its growing end there scrolls the log's matches away.
    testWidgets('at the live edge, the log\'s newest stays in view', (tester) async {
      final log = _log(40);
      await tester.pumpWidget(_host(log, const []));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(log, _others(30)));
      await tester.pumpAndSettle();
      expect(find.text('K39AA'), findsOneWidget);
    });

    // The trap: the position was laid out for the find, and measured
    // against the full log's end it reads as scrolled away — so the log
    // reopens on its oldest rows rather than the contact just logged.
    testWidgets('closing the find brings the full log back to its newest contact', (tester) async {
      final log = _log(30);
      await tester.pumpWidget(_host(log, const []));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host([log[5]], const [], log: log));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host([log[5]], _others(40), log: log));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(log, const []));
      await tester.pumpAndSettle();
      expect(find.text('K29AA'), findsOneWidget);
    });

    testWidgets('scrolled away, the rows being read stay where they are', (tester) async {
      final log = _log(60);
      await tester.pumpWidget(_host(log, const []));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
      await tester.pumpAndSettle();
      final before = _top(tester, find.text('K3AA'));

      await tester.pumpWidget(_host(log, _others(10)));
      await tester.pumpAndSettle();
      expect(find.text('K3AA'), findsOneWidget);
      expect(_top(tester, find.text('K3AA')), before);
    });
  });

  testWidgets('oldest first, a jump to the log\'s oldest row lands on it', (tester) async {
    final log = _log(60);
    final others = _others(10);
    await tester.pumpWidget(_host(log, others));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(log, others, selectedUuid: 'log0'));
    await tester.pumpAndSettle();
    final scroller = tester.getRect(find.byType(CustomScrollView));
    final rowTop = _top(tester, find.text('K0AA'));
    expect(rowTop, greaterThanOrEqualTo(scroller.top + DayHeaderRow.pinnedHeightOf(tester.element(find.byType(QsoList)))));
    expect(tester.getBottomLeft(find.text('K0AA')).dy, lessThanOrEqualTo(scroller.bottom));
  });

  // The log's columns are sized over the whole log, so a find never moves
  // them under the operator. Sized together with a VHF contact from
  // elsewhere, the frequency column would widen and push every callsign right.
  testWidgets('the log\'s rows keep their columns whatever the other contacts hold', (tester) async {
    final log = _log(1);
    await tester.pumpWidget(_host(log, const []));
    await tester.pumpAndSettle();
    final alone = tester.getTopLeft(find.text('K0AA')).dx;

    await tester.pumpWidget(_host(log, _others(1, freq: 1296123.456)));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('K0AA')).dx, alone);
    expect(tester.takeException(), isNull, reason: 'the wider frequency fits its own row');
  });
}
