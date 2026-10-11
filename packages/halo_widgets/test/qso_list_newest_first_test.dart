// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QsoList.newestFirst: the list under a logging panel drawn ABOVE it, where
// the live edge — the newest contact — is the top. The default list keeps it
// at the bottom; everything that follows the live edge has to follow it to
// the other end, or a new contact lands out of sight.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

final _day1 = DateTime.utc(2026, 10, 10, 12).millisecondsSinceEpoch;
final _day2 = DateTime.utc(2026, 10, 11, 12).millisecondsSinceEpoch;

Qso _qso(String call, int startAtMillis) => Qso(
  uuid: call,
  operationUuid: '',
  data: {
    'uuid': call,
    'their': {'call': call},
    'band': '20m',
    'mode': 'CW',
    'startAtMillis': startAtMillis,
  },
);

/// [count] contacts a minute apart on day 2, oldest first — the order a log
/// stream hands them over in.
List<Qso> _log(int count) => [for (var i = 0; i < count; i++) _qso('K${i}AA', _day2 + i * 60000)];

Widget _host(List<Qso> qsos) => MaterialApp(
  theme: buildHaLoTheme(Brightness.light),
  home: Scaffold(
    body: QsoList(qsos: qsos, onSelect: (_) {}, newestFirst: true),
  ),
);

double _top(WidgetTester tester, String call) => tester.getTopLeft(find.text(call)).dy;

void main() {
  testWidgets('newest first puts the newer day above the older, and the newest contact of each day at its top', (tester) async {
    await tester.pumpWidget(_host([_qso('OLD1', _day1), _qso('OLD2', _day1 + 60000), _qso('NEW1', _day2), _qso('NEW2', _day2 + 60000)]));
    await tester.pumpAndSettle();

    expect(_top(tester, 'NEW2'), lessThan(_top(tester, 'NEW1')), reason: 'within a day, the later contact first');
    expect(_top(tester, 'NEW1'), lessThan(_top(tester, 'OLD2')), reason: 'the newer day above the older one');
    expect(_top(tester, 'OLD2'), lessThan(_top(tester, 'OLD1')));
  });

  // The trap: the default list jumps to its BOTTOM on open and on every new
  // contact. Newest first, that is the oldest contact — the operator would
  // open the view on last week and log into a list scrolled away from it.
  testWidgets('it opens at the top, and a contact logged there stays in view', (tester) async {
    final qsos = _log(60);
    await tester.pumpWidget(_host(qsos));
    await tester.pumpAndSettle();
    expect(find.text('K59AA'), findsOneWidget, reason: 'the newest contact is on screen when the list opens');

    await tester.pumpWidget(_host([...qsos, _qso('K60AA', _day2 + 60 * 60000)]));
    await tester.pumpAndSettle();
    expect(find.text('K60AA'), findsOneWidget, reason: 'a contact arriving at the live edge is shown');
  });

  // The trap: inserting at the top pushes every row below it down by a row.
  // An operator scrolled down to review — or editing — an earlier contact
  // would see it slide away under the pointer each time one is logged.
  testWidgets('scrolled away from the top, a new contact does not move the rows being read', (tester) async {
    final qsos = _log(60);
    await tester.pumpWidget(_host(qsos));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final reading = find.text('K30AA');
    expect(reading, findsOneWidget);
    final before = _top(tester, 'K30AA');

    await tester.pumpWidget(_host([...qsos, _qso('K60AA', _day2 + 60 * 60000)]));
    await tester.pumpAndSettle();

    expect(_top(tester, 'K30AA'), closeTo(before, 0.5));
  });

  // A contact from earlier in the day — synced from another device, or an
  // import — lands below the newest but still above the rows being read.
  // Anchoring on the newest alone would see nothing move and let them slide.
  testWidgets('a contact landing between the newest and the rows being read still leaves those rows in place', (tester) async {
    final qsos = _log(60);
    await tester.pumpWidget(_host(qsos));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final before = _top(tester, 'K30AA');

    // Between K55AA and K56AA: older than the newest, newer than K30AA.
    final backdated = _qso('W1LATE', _day2 + 55 * 60000 + 30000);
    await tester.pumpWidget(_host([...qsos.take(56), backdated, ...qsos.skip(56)]));
    await tester.pumpAndSettle();

    expect(_top(tester, 'K30AA'), closeTo(before, 0.5));
  });

  testWidgets('a contact opening a new day at the top leaves the rows being read in place, its day header and all', (tester) async {
    final qsos = _log(60);
    await tester.pumpWidget(_host(qsos));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final before = _top(tester, 'K30AA');

    await tester.pumpWidget(_host([...qsos, _qso('NEXTDAY', _day2 + const Duration(days: 1).inMilliseconds)]));
    await tester.pumpAndSettle();

    expect(_top(tester, 'K30AA'), closeTo(before, 0.5));
  });
}
