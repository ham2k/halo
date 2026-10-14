// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Logs destination's table, picker and editor. Each case below guards a
// decision a reasonable-looking change would undo: the order an operator
// opens on, where a newly offered column lands, what the view remembers
// between visits, and — above all — that an edit typed into the editor is
// never thrown away without the operator being asked.

import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/home_navigation_rail.dart';
import 'package:ham2k_logger/views/home_view.dart';
import 'package:ham2k_logger/views/logs_view.dart';
import 'package:ham2k_logger/views/operation/adif_import_flow.dart';

import '../support/halo_test_support.dart';

int _utc(int day, int hour) => DateTime.utc(2026, 9, day, hour).millisecondsSinceEpoch;

/// The table docked alone: the Info and Map panes beside it by default
/// mount a callsign lookup and a platform webview, neither of which a widget
/// test can serve. And the test font draws every glyph as a square as wide as
/// it is tall, so a frequency that fits its column in Roboto Mono overflows
/// it here — widened for the test only; nothing below is about widths.
Future<HaLoHarness> _harness() async {
  final h = await makeHaLoServices();
  await h.settings.setLayoutData(LayoutKeys.logsDock, DockGroup([LogsView.qsoTablePanelId]).toJson());
  await h.settings.setLayoutData(LayoutKeys.logsQsoColumnWidths, {'freq': 140.0, 'date': 160.0, 'time': 100.0, 'call': 120.0});
  return h;
}

Future<Qso> _log(HaLoServices services, Operation operation, String their, int at, {Map<String, dynamic> theirExtra = const {}}) =>
    services.qsos.add(operation.uuid, {
      'our': {'call': operation.stationCall},
      'their': {'call': their, ...theirExtra},
      'band': '20m',
      'mode': 'CW',
      'startAtMillis': at,
    });

/// Three contacts on two days, logged out of order so the table's order is
/// its own and not the insert order's.
Future<(Operation, Map<String, Qso>)> _seed(HaLoServices services, {String stationCall = 'K1ABC', String userTitle = ''}) async {
  final operation = await services.operations.create(stationCall: stationCall, userTitle: userTitle);
  final k2aa = await _log(services, operation, 'K2AA', _utc(21, 9));
  final w1aw = await _log(services, operation, 'W1AW', _utc(20, 10));
  final n3bb = await _log(services, operation, 'N3BB', _utc(21, 12));
  return (operation, {'K2AA': k2aa, 'W1AW': w1aw, 'N3BB': n3bb});
}

Future<void> _pumpLogs(WidgetTester tester, HaLoHarness h) async {
  await pumpHaLo(
    tester,
    (services) => LogsView(services: services),
    harness: h,
    size: const Size(1400, 900),
  );
  await settleFrames(tester);
}

/// Logs as the app shows it: over Home, inside the shell that draws the
/// rail.
Future<void> _pumpShell(WidgetTester tester, HaLoHarness h) async {
  await h.settings.setExperimentEnabled('logs', true) /* stored key, see experiments.yaml */;
  addTearDown(() => homeRail.destination = HomeDestination.operations);
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: HomeRailShell(
          services: h.services,
          routes: HomeView(services: h.services),
        ),
      ),
    ),
  );
  homeRail.destination = HomeDestination.logs;
  await settleFrames(tester);
}

/// Unmounts the shell and lets Home's chained timers run out before the
/// pending-timer check.
Future<void> _unmountShell(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 6));
  }
}

/// The QSO table's own list — the one fixed-extent list on screen, so a
/// callsign the info pane also shows is not mistaken for a row.
final _table = find.byWidgetPredicate((widget) => widget is ListView && widget.itemExtent != null);

Finder _row(String call) => find.descendant(of: _table, matching: find.text(call));

/// The table's callsigns top to bottom, of the ones given.
List<String> _order(WidgetTester tester, List<String> calls) {
  final shown = [
    for (final call in calls)
      if (_row(call).evaluate().isNotEmpty) call,
  ];
  return shown..sort((a, b) => tester.getTopLeft(_row(a)).dy.compareTo(tester.getTopLeft(_row(b)).dy));
}

Finder _field(String label) => find.widgetWithText(TextField, label);

/// The focus the table's keys arrive on — what a tap on a row gives focus to,
/// and what typing into the editor takes it from.
FocusNode _listFocus(WidgetTester tester) => tester
    .widget<Focus>(find.ancestor(of: _table, matching: find.byWidgetPredicate((widget) => widget is Focus && widget.onKeyEvent != null)).first)
    .focusNode!;

/// Which QSO the editor is open on, by its Their call field — null when it
/// is closed.
String? _editing(WidgetTester tester) {
  final field = _field('Their call');
  return field.evaluate().isEmpty ? null : tester.widget<TextField>(field).controller!.text;
}

Future<Qso> _stored(WidgetTester tester, HaLoServices services, Qso qso) async =>
    (await tester.runAsync(() => services.qsos.forOperation(qso.operationUuid)))!.singleWhere((row) => row.uuid == qso.uuid);

Future<void> _tapRow(WidgetTester tester, String call) async {
  await tester.tap(_row(call));
  await settleFrames(tester, frames: 6);
}

/// The table is up with a focused field or a dialog, and neither settles:
/// unmount and let drift's zero-length timer run before the pending-timer
/// check.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the table', () {
    testWidgets('opens newest first, re-sorts from a header, and keeps that sort for the next visit', (tester) async {
      final h = await _harness();
      // Ungrouped, so a sort runs across the whole table rather than within
      // each day.
      await h.settings.setLayoutData(LayoutKeys.logsFilter, {'group': 'none'});
      await _seed(h.services);
      await _pumpLogs(tester, h);
      const calls = ['K2AA', 'W1AW', 'N3BB'];

      // A log is read from the latest contact back: opened on the oldest,
      // anything just logged would be a scroll away.
      expect(_order(tester, calls), ['N3BB', 'K2AA', 'W1AW']);

      await tester.tap(find.descendant(of: find.byType(Row), matching: find.text('Call')).first);
      await settleFrames(tester, frames: 3);
      expect(_order(tester, calls), ['K2AA', 'N3BB', 'W1AW'], reason: 'a new column sorts ascending');

      await tester.tap(find.text('Call').first);
      await settleFrames(tester, frames: 3);
      expect(_order(tester, calls), ['W1AW', 'N3BB', 'K2AA'], reason: 'the sorted column flips');

      await _unmount(tester);
      await _pumpLogs(tester, h);
      expect(_order(tester, calls), ['W1AW', 'N3BB', 'K2AA'], reason: 'the sort outlives the visit');
      await _unmount(tester);
    });

    testWidgets('sorts by the whole timestamp from either clock header, not by the day or the time of day alone', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);
      const calls = ['K2AA', 'W1AW', 'N3BB'];

      // Oldest first: by the day alone, the 21st's two contacts would fall
      // back to the newest-first tie-break and come out N3BB, K2AA.
      await tester.tap(find.text('Date').first);
      await settleFrames(tester, frames: 3);
      expect(_order(tester, calls), ['W1AW', 'K2AA', 'N3BB']);

      // Time runs on the same clock, so it flips the order rather than
      // re-sorting. By the time of day alone, W1AW (10:00 on the 20th) would
      // land between N3BB (12:00) and K2AA (09:00 on the 21st).
      await tester.tap(find.text('Time').first);
      await settleFrames(tester, frames: 3);
      expect(_order(tester, calls), ['N3BB', 'K2AA', 'W1AW']);
      await _unmount(tester);
    });

    testWidgets('groups by year, month and day, each counted, and a sort reorders within them', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);
      const calls = ['K2AA', 'W1AW', 'N3BB'];

      expect(_row('2026'), findsOneWidget);
      expect(_row('September'), findsOneWidget);
      expect(
        find.descendant(of: _table, matching: find.text('3 QSOs')),
        findsNWidgets(2),
        reason: 'the year and the month hold all three',
      );
      expect(
        find.descendant(of: _table, matching: find.text('2 QSOs')),
        findsOneWidget,
        reason: 'the 21st',
      );

      // By callsign, W1AW would lead the list; grouped, it stays under the
      // 20th, after the 21st's two.
      await tester.tap(find.descendant(of: find.byType(Row), matching: find.text('Call')).first);
      await settleFrames(tester, frames: 3);
      expect(_order(tester, calls), ['K2AA', 'N3BB', 'W1AW']);

      // A header folds its group away, and opens it again.
      await tester.tap(_row('September'));
      await settleFrames(tester, frames: 3);
      expect(_row('K2AA'), findsNothing);
      expect(_row('September'), findsOneWidget);
      await tester.tap(_row('September'));
      await settleFrames(tester, frames: 3);
      expect(_row('K2AA'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('not grouped, it is one list with no headers at all', (tester) async {
      final h = await _harness();
      await h.settings.setLayoutData(LayoutKeys.logsFilter, {'group': 'none'});
      await _seed(h.services);
      await _pumpLogs(tester, h);

      expect(_row('2026'), findsNothing);
      expect(_row('September'), findsNothing);
      expect(_order(tester, ['K2AA', 'W1AW', 'N3BB']), ['N3BB', 'K2AA', 'W1AW']);
      await _unmount(tester);
    });

    testWidgets('DX starts collapsed, keeps what is opened, and a modifier-click folds the siblings and everything in them', (tester) async {
      final h = await _harness();
      await h.settings.setLayoutData(LayoutKeys.logsFilter, {'group': 'dx'});
      final operation = await h.services.operations.create(stationCall: 'K1ABC');
      final dx = [('NA', 'United States'), ('NA', 'Canada'), ('EU', 'Germany'), ('AS', 'Japan')];
      for (final (i, (continent, entity)) in dx.indexed) {
        await _log(h.services, operation, 'K${i}AA', _utc(20 + i, 9), theirExtra: {'continent': continent, 'entityName': entity});
      }
      await _pumpLogs(tester, h);

      // Continents and entities are many: an index to open from, not a
      // wall of every QSO.
      expect(_row('North America'), findsOneWidget);
      expect(_row('Canada'), findsNothing);

      await tester.tap(_row('North America'));
      await settleFrames(tester, frames: 3);
      expect(_row('Canada'), findsOneWidget);
      expect(_row('K1AA'), findsNothing, reason: 'the entity inside stays as it was');

      await _unmount(tester);
      await _pumpLogs(tester, h);
      expect(_row('Canada'), findsOneWidget, reason: 'what was opened outlives the visit');

      // Alt on a closed continent opens every continent and every entity in
      // them; Ctrl on an open one closes them all again.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.tap(_row('Europe'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settleFrames(tester, frames: 3);
      expect(_row('Japan'), findsOneWidget);
      expect(_row('K2AA'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(_row('Asia'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settleFrames(tester, frames: 3);
      expect(_row('Canada'), findsNothing);
      expect(_row('Germany'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('a search opens every group, and what it folds goes with it', (tester) async {
      final h = await _harness();
      await h.settings.setLayoutData(LayoutKeys.logsFilter, {'group': 'dx'});
      final operation = await h.services.operations.create(stationCall: 'K1ABC');
      final dx = [('NA', 'United States'), ('NA', 'Canada'), ('EU', 'Germany'), ('AS', 'Japan')];
      for (final (i, (continent, entity)) in dx.indexed) {
        await _log(h.services, operation, 'K${i}AA', _utc(20 + i, 9), theirExtra: {'continent': continent, 'entityName': entity});
      }
      await _pumpLogs(tester, h);
      await tester.tap(_row('North America'));
      await settleFrames(tester, frames: 3);

      // Under DX's closed groups, a match would be a count with nothing to
      // read.
      await tester.enterText(find.byType(TextField), 'K2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleFrames(tester, frames: 3);
      expect(_row('K2AA'), findsOneWidget);
      await tester.tap(_row('Germany'));
      await settleFrames(tester, frames: 3);
      expect(_row('K2AA'), findsNothing, reason: 'a group still folds during a search');

      await tester.tap(find.byIcon(MdiIcons.close));
      await settleFrames(tester, frames: 3);
      expect(_row('Canada'), findsOneWidget, reason: 'the open continent is open again');
      expect(_row('Germany'), findsNothing, reason: 'Europe is closed again');
      expect(h.settings.layoutData(LayoutKeys.logsFilter)?['folds'], {
        'dx': {
          'own': {'NA': false},
          'under': <String, bool>{},
        },
      }, reason: 'nothing folded during the search is stored');
      await _unmount(tester);
    });

    testWidgets('a modifier-click stores one entry however many groups it folds, and they still open folded', (tester) async {
      final h = await _harness();
      final operation = await h.services.operations.create(stationCall: 'K1ABC');
      for (var day = 1; day <= 20; day++) {
        await _log(h.services, operation, 'K${day}AA', _utc(day, 9));
      }
      await _pumpLogs(tester, h);
      Object? stored() => h.settings.layoutData(LayoutKeys.logsFilter)?['folds'];
      Future<void> modifierTap(String header) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(_row(header));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await settleFrames(tester, frames: 3);
      }

      // Kept path by path, a log's years, months and days would each be one.
      await modifierTap('2026');
      expect(stored(), {
        'date': {
          'own': <String, bool>{},
          'under': {'': true},
        },
      });
      await tester.tap(_row('2026'));
      await settleFrames(tester, frames: 3);
      expect(_row('September'), findsOneWidget);
      expect(_row('K20AA'), findsNothing, reason: 'the month inside opens still folded');

      await modifierTap('September');
      expect(_row('K20AA'), findsOneWidget);
      await modifierTap('2026');
      expect(stored(), {
        'date': {
          'own': <String, bool>{},
          'under': {'': true},
        },
      }, reason: 'a modifier-click clears what it reaches into');
      await modifierTap('2026');
      expect(stored(), isEmpty, reason: 'all open is how Date starts');
      await _unmount(tester);
    });

    testWidgets('pins the headers of the groups scrolled through over the top of the table', (tester) async {
      final h = await _harness();
      final operation = await h.services.operations.create(stationCall: 'K1ABC');
      for (var day = 1; day <= 20; day++) {
        await _log(h.services, operation, 'K${day}AA', _utc(day, 9));
        await _log(h.services, operation, 'W${day}BB', _utc(day, 15));
      }
      await _pumpLogs(tester, h);

      tester.widget<ListView>(_table).controller!.jumpTo(800);
      await settleFrames(tester, frames: 3);

      // Far below the year's and the month's own rows, both still name the
      // rows under them, stacked at the table's top edge.
      final top = tester.getTopLeft(_table).dy;
      final extent = tester.getSize(find.ancestor(of: find.text('2026').first, matching: find.byType(InkWell)).first).height;
      double? pinnedAt(String text) {
        for (final element in find.descendant(of: find.byType(Stack), matching: find.text(text)).evaluate()) {
          final dy = tester.getTopLeft(find.byElementPredicate((e) => e == element)).dy - top;
          if (dy >= 0 && dy < extent * 3) return (dy / extent).floorToDouble();
        }
        return null;
      }

      expect(pinnedAt('2026'), 0);
      expect(pinnedAt('September'), 1);
      await _unmount(tester);
    });

    testWidgets('crossing the two-pane boundary does not trip the pinned headers', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);

      // The compact list and the wide one share the scroll controller, and
      // for the frame of the swap both are attached: read then, the offset
      // asserts.
      for (final width in [500.0, 1400.0]) {
        tester.view.physicalSize = Size(width, 900);
        await settleFrames(tester, frames: 3);
        expect(tester.takeException(), isNull, reason: 'at $width');
      }
      await _unmount(tester);
    });

    testWidgets('drops a dragged header into the gap on the side of the column it is over', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);
      const headers = ['Date', 'Time', 'Frequency', 'Mode', 'Call', 'Name'];
      List<String> headerOrder() => [...headers]..sort((a, b) => tester.getTopLeft(find.text(a).first).dx.compareTo(tester.getTopLeft(find.text(b).first).dx));
      Rect column(String header) => tester.getRect(find.ancestor(of: find.text(header).first, matching: find.byType(SizedBox)).first);
      final dropLine = find.byKey(const ValueKey('logsColumnDropLine'));

      Future<TestGesture> lift(String header) async {
        final gesture = await tester.startGesture(tester.getCenter(find.text(header).first));
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
        return gesture;
      }

      // Over Date's right half: the gap between Date and Time, marked in
      // that gap — lighting up Date's whole cell instead would leave the side
      // it lands on to guesswork.
      var gesture = await lift('Call');
      final date = column('Date');
      await gesture.moveTo(Offset(date.left + date.width * 0.75, date.center.dy));
      await tester.pump();
      final line = tester.getRect(dropLine);
      expect(line.center.dx, greaterThan(date.right));
      expect(line.center.dx, lessThan(column('Time').left));

      // What the pointer carries is the header cell, on the header's gray.
      final background = Theme.of(tester.element(find.text('Date').first)).colorScheme.surfaceContainerHighest;
      expect(find.ancestor(of: find.text('Call').last, matching: find.byWidgetPredicate((w) => w is Material && w.color == background)), findsOneWidget);

      await gesture.up();
      await settleFrames(tester, frames: 3);
      expect(headerOrder(), ['Date', 'Call', 'Time', 'Frequency', 'Mode', 'Name']);
      expect(dropLine, findsNothing);

      // Over its left half: the gap before it, here the table's first.
      gesture = await lift('Mode');
      final dateNow = column('Date');
      await gesture.moveTo(Offset(dateNow.left + dateNow.width * 0.25, dateNow.center.dy));
      await tester.pump();
      await gesture.up();
      await settleFrames(tester, frames: 3);
      expect(headerOrder(), ['Mode', 'Date', 'Call', 'Time', 'Frequency', 'Name']);

      // Either side of the dragged column is where it already is: no line,
      // and nothing moves.
      gesture = await lift('Time');
      final time = column('Time');
      await gesture.moveTo(Offset(time.left + time.width * 0.9, time.center.dy));
      await tester.pump();
      expect(dropLine, findsNothing);
      await gesture.up();
      await settleFrames(tester, frames: 3);
      expect(headerOrder(), ['Mode', 'Date', 'Call', 'Time', 'Frequency', 'Name']);
      await _unmount(tester);
    });

    testWidgets('a header let go over a pane\'s tab bar plants nothing in the layout', (tester) async {
      // The default dock: the table beside Info and Map, both with title
      // bars — the dock's tab strips, which take any `String` dropped on them
      // as a pane to add.
      final h = await makeHaLoServices();
      await h.settings.setLayoutData(LayoutKeys.logsQsoColumnWidths, {'freq': 140.0, 'date': 160.0, 'time': 100.0, 'call': 120.0});
      await _seed(h.services);
      await _pumpLogs(tester, h);

      final gesture = await tester.startGesture(tester.getCenter(find.text('Mode').first));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Info')));
      await tester.pump();
      await gesture.up();
      await settleFrames(tester, frames: 3);

      // Accepted there, it would be an empty pane titled "mode", persisted.
      expect(find.text('mode'), findsNothing);
      expect(h.settings.layoutData(LayoutKeys.logsDock), isNull);
      await _unmount(tester);
    });

    testWidgets('opens on stored settings of the wrong shape instead of failing', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      // Written by another build, or hand-edited: a throw reading any of
      // these in initState would take the column menu — the only way to put
      // them right — down with the view.
      await h.settings.setLayoutData(LayoutKeys.logsQsoVisibleColumns, {'grid': 'yes', 'name': 1});
      await h.settings.setLayoutData(LayoutKeys.logsQsoColumnWidths, {'date': 'wide'});
      await h.settings.setLayoutData(LayoutKeys.logsQsoColumnOrder, {'order': 'date,time'});
      await h.settings.setLayoutData(LayoutKeys.logsQsoSort, {'column': 7, 'ascending': 'yes'});
      await _pumpLogs(tester, h);

      expect(tester.takeException(), isNull);
      expect(_row('W1AW'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('keeps the columns nobody asked for out of the way', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);

      for (final label in ['Station', 'Band', 'Sent', 'Rcvd', 'Grid', 'State', 'Country', 'Refs']) {
        expect(find.text(label), findsNothing, reason: '$label is offered in the menu, not shown unasked');
      }
      expect(find.text('Name'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('puts a column switched on after the order was saved ahead of Name, which keeps stretching', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      // An order saved when the table had six columns, and Grid switched on
      // since.
      await h.settings.setLayoutData(LayoutKeys.logsQsoColumnOrder, {
        'order': ['date', 'time', 'freq', 'mode', 'call', 'name'],
      });
      await h.settings.setLayoutData(LayoutKeys.logsQsoVisibleColumns, {'grid': true});
      await _pumpLogs(tester, h);

      // Appended, Grid would trail and take the stretch, leaving Name at its
      // fixed width with the pane's slack piled up in the Grid column.
      expect(tester.getTopLeft(find.text('Grid')).dx, lessThan(tester.getTopLeft(find.text('Name')).dx));
      expect(tester.getTopLeft(find.text('Call')).dx, lessThan(tester.getTopLeft(find.text('Grid')).dx));
      await _unmount(tester);
    });
  });

  group('the sheet', () {
    testWidgets('opens from the title even with one callsign, and a second one widens the view to All', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);

      // One callsign leaves nothing to pick there, but the grouping and the
      // period are still the sheet's: the title opens it regardless.
      expect(find.text('Logs for K1ABC'), findsOneWidget);
      await tester.tap(find.text('Logs for K1ABC'));
      await settleFrames(tester, frames: 6);
      expect(find.widgetWithText(ListTile, 'Not grouped'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settleFrames(tester, frames: 6);

      // The view chose K1ABC by itself, so a second callsign widens it to
      // All — pinned, the new callsign's QSOs would stay hidden. An open
      // editor rides along: its QSO is in All.
      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Name'), 'Hiram');
      final other = await h.services.operations.create(stationCall: 'W2XYZ');
      await _log(h.services, other, 'VE3CC', _utc(22, 8));
      await settleFrames(tester, frames: 4);
      expect(find.text('All Logs'), findsOneWidget);
      expect(_row('VE3CC'), findsOneWidget);
      expect(tester.widget<TextField>(_field('Name')).controller!.text, 'Hiram');
      await _unmount(tester);
    });

    testWidgets('an open sheet follows what the log does on its own', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      final second = await h.services.operations.create(stationCall: 'W2XYZ');
      await _log(h.services, second, 'VE3CC', _utc(22, 8));
      await _pumpLogs(tester, h);
      await tester.tap(find.text('All Logs'));
      await settleFrames(tester, frames: 6);
      expect(find.widgetWithText(ListTile, 'N4QQ'), findsNothing);

      // A third station callsign arrives while the sheet is up, on All
      // already: the filter stays as it is, so the new callsign reaches the
      // sheet only because the callsigns themselves changed — nothing the
      // operator did wrote a setting that would have told it so.
      final third = await h.services.operations.create(stationCall: 'N4QQ');
      await _log(h.services, third, 'VE3DD', _utc(22, 9));
      await settleFrames(tester, frames: 6);
      expect(find.widgetWithText(ListTile, 'N4QQ'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settleFrames(tester, frames: 6);
      await _unmount(tester);
    });

    testWidgets('opens on every callsign at once, and on the last pick after that', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      final other = await h.services.operations.create(stationCall: 'W2XYZ');
      await _log(h.services, other, 'VE3CC', _utc(22, 8));
      await _pumpLogs(tester, h);

      expect(find.text('All Logs'), findsOneWidget);
      expect(_order(tester, ['VE3CC', 'N3BB']), ['VE3CC', 'N3BB'], reason: 'both stations, one table');

      await tester.tap(find.text('All Logs'));
      await settleFrames(tester, frames: 6);
      await tester.tap(find.widgetWithText(ListTile, 'W2XYZ'));
      await settleFrames(tester, frames: 4);
      await tester.tap(find.text('OK'));
      await settleFrames(tester, frames: 6);
      expect(_row('N3BB'), findsNothing);
      expect(_row('VE3CC'), findsOneWidget);

      await _unmount(tester);
      await _pumpLogs(tester, h);
      expect(find.text('Logs for W2XYZ'), findsOneWidget, reason: 'the title names the remembered pick');
      expect(_row('N3BB'), findsNothing);
      expect(_row('VE3CC'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('the time period', () {
    testWidgets('a custom range shows its days alone, and the period picked in the sheet outlives the visit', (tester) async {
      final h = await _harness();
      await h.settings.setLayoutData(LayoutKeys.logsFilter, {'period': 'custom', 'from': '2026-09-21', 'to': '2026-09-21'});
      await _seed(h.services);
      await _pumpLogs(tester, h);

      expect(_row('K2AA'), findsOneWidget);
      expect(_row('W1AW'), findsNothing, reason: 'the 20th is outside the range');
      expect(find.text('Logs for K1ABC in Custom Range'), findsOneWidget);

      await tester.tap(find.text('Logs for K1ABC in Custom Range'));
      await settleFrames(tester, frames: 6);
      await tester.tap(find.widgetWithText(ListTile, 'All time'));
      await settleFrames(tester, frames: 4);
      await tester.tap(find.text('OK'));
      await settleFrames(tester, frames: 6);
      expect(_row('W1AW'), findsOneWidget);

      await _unmount(tester);
      await _pumpLogs(tester, h);
      expect(_row('W1AW'), findsOneWidget, reason: 'All time is remembered');
      expect(find.text('Logs for K1ABC'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a stored Custom with no days to span opens on All time', (tester) async {
      final h = await _harness();
      await h.settings.setLayoutData(LayoutKeys.logsFilter, {'period': 'custom', 'from': 'garbage'});
      await _seed(h.services);
      await _pumpLogs(tester, h);

      // Showing every QSO under a title naming a range would say one thing
      // and show another.
      expect(find.text('Logs for K1ABC'), findsOneWidget);
      expect(_row('W1AW'), findsOneWidget);
      await _unmount(tester);
    });

    // At 13 Oct 2026. Every span is whole calendar months or years — a
    // rolling "3 months back from today" starts mid-July and splits a
    // month's log across the boundary.
    final now = DateTime.utc(2026, 10, 13, 15);
    DateTime? at(int? millis) => millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

    test('runs over calendar months and years', () {
      expect(at(LogsPeriod.thisMonth.bounds(now).start), DateTime.utc(2026, 10));
      expect(at(LogsPeriod.last3Months.bounds(now).start), DateTime.utc(2026, 8), reason: 'this month and the two before it');
      expect(at(LogsPeriod.thisYear.bounds(now).start), DateTime.utc(2026));
      final lastYear = LogsPeriod.lastYear.bounds(now);
      expect((at(lastYear.start), at(lastYear.end)), (DateTime.utc(2025), DateTime.utc(2026)), reason: 'all of 2025, and nothing of 2026');
      expect(LogsPeriod.allTime.bounds(now), (start: null, end: null));
    });

    test('a custom range includes its last day', () {
      final range = DateTimeRange(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 31));
      final bounds = LogsPeriod.custom.bounds(now, range: range);
      expect((at(bounds.start), at(bounds.end)), (DateTime.utc(2026, 3), DateTime.utc(2026, 4)));
    });
  });

  group('the header', () {
    testWidgets('carries the count and the whole date span under the title', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);

      // Over all time the period has no days of its own: the span is the
      // QSOs' own.
      expect(find.text('3 QSOs · 2026-09-20 – 2026-09-21'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('dims the search hint', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);

      // At full strength the hint reads as a search already typed.
      final hint = tester.widget<Text>(find.text('Search callsign or name'));
      expect(hint.style?.color?.a, closeTo(0.38, 0.01));
      await _unmount(tester);
    });

    testWidgets('searches once typing pauses, or at once on Enter or clear', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);
      final field = find.byType(TextField);

      // Every search refilters and re-sorts the whole log; one per keystroke
      // stalls typing on a large one. Each keystroke restarts the wait.
      await tester.enterText(field, 'W');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(field, 'W1');
      await tester.pump(const Duration(milliseconds: 500));
      expect(_row('K2AA'), findsOneWidget, reason: 'still typing: 500 ms since the last keystroke');
      await tester.pump(const Duration(milliseconds: 200));
      expect(_row('K2AA'), findsNothing);
      expect(_row('W1AW'), findsOneWidget);

      await tester.tap(find.byIcon(MdiIcons.close));
      await tester.pump();
      expect(_row('K2AA'), findsOneWidget, reason: 'clearing is not typing');

      await tester.enterText(field, 'N3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_row('K2AA'), findsNothing, reason: 'Enter does not wait');
      expect(_row('N3BB'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('the editor', () {
    testWidgets('asks before another row takes it, and does what the answer says', (tester) async {
      final h = await _harness();
      final (_, qsos) = await _seed(h.services);
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Name'), 'Hiram');
      await _tapRow(tester, 'K2AA');
      expect(find.text('Unsaved changes'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await settleFrames(tester, frames: 4);
      expect(_editing(tester), 'W1AW', reason: 'Cancel stays on the edit');
      expect(tester.widget<TextField>(_field('Name')).controller!.text, 'Hiram');

      await _tapRow(tester, 'K2AA');
      await tester.tap(find.text('Discard'));
      await settleFrames(tester, frames: 6);
      expect(_editing(tester), 'K2AA');
      expect((await _stored(tester, h.services, qsos['W1AW']!)).theirName, isNull, reason: 'Discard writes nothing');

      await tester.enterText(_field('Name'), 'Bob');
      await _tapRow(tester, 'N3BB');
      await tester.tap(find.text('Save'));
      await settleFrames(tester, frames: 6);
      expect(_editing(tester), 'N3BB');
      expect((await _stored(tester, h.services, qsos['K2AA']!)).theirName, 'Bob');
      await _unmount(tester);
    });

    testWidgets('keeps an open edit when the log narrows the filter on its own', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      final other = await h.services.operations.create(stationCall: 'W2XYZ');
      final lone = await _log(h.services, other, 'VE3CC', _utc(22, 8));
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Name'), 'Hiram');
      // The other station's last QSO goes — from another device, say — and
      // All becomes K1ABC alone. Nothing the operator did asked the editor
      // to close.
      await tester.runAsync(() => h.services.qsos.softDelete(lone));
      await settleFrames(tester, frames: 6);

      expect(find.text('Unsaved changes'), findsNothing);
      expect(_editing(tester), 'W1AW');
      expect(tester.widget<TextField>(_field('Name')).controller!.text, 'Hiram');
      await _unmount(tester);
    });

    testWidgets('an ADIF drop settles the edit before it starts', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Name'), 'Hiram');
      // The import takes the table — and the editor in it — down while it
      // writes, so it asks first like everything else that would close it.
      unawaited(
        tester
            .widget<AdifDropTarget>(find.byType(AdifDropTarget))
            .onFile(XFile.fromData(Uint8List.fromList(utf8.encode('<eoh>')), name: 'log.adi', path: 'log.adi')),
      );
      await settleFrames(tester, frames: 4);
      expect(find.text('Unsaved changes'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await settleFrames(tester, frames: 4);
      expect(find.text('Reading ADIF file…'), findsNothing, reason: 'Cancel is no import at all');
      expect(tester.widget<TextField>(_field('Name')).controller!.text, 'Hiram');
      await _unmount(tester);
    });

    testWidgets('outlives a search that matches nothing', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Name'), 'Hiram');
      // The search hides the selected row with the rest; with the table's
      // empty state standing in for the whole pane, the editor would go too.
      await tester.enterText(find.widgetWithText(TextField, 'Search callsign or name'), 'ZZ9');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleFrames(tester, frames: 4);
      expect(find.text('No QSOs match your search'), findsOneWidget);
      expect(tester.widget<TextField>(_field('Name')).controller!.text, 'Hiram');
      await _unmount(tester);
    });

    testWidgets('an ADIF drop closes the editor it settled, saved or discarded', (tester) async {
      final h = await _harness();
      final (_, qsos) = await _seed(h.services);
      await _pumpLogs(tester, h);
      Future<void> drop() async {
        unawaited(
          tester
              .widget<AdifDropTarget>(find.byType(AdifDropTarget))
              .onFile(XFile.fromData(Uint8List.fromList(utf8.encode('<eoh>')), name: 'log.adi', path: 'log.adi')),
        );
        await settleFrames(tester, frames: 4);
      }

      Future<void> finishImport() async {
        // Nothing in the file: the import stops at its summary.
        for (var i = 0; i < 20 && find.text('Done').evaluate().isEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.text('Done'));
        await settleFrames(tester, frames: 4);
      }

      // Left open after Discard, the discarded text stays on screen — and
      // the next Enter writes it after all.
      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Name'), 'Hiram');
      await drop();
      await tester.tap(find.text('Discard'));
      await finishImport();
      expect(_editing(tester), isNull);
      expect((await _stored(tester, h.services, qsos['W1AW']!)).theirName, isNull);

      // Left open after Save, the saved edit still reads as unsaved.
      await _tapRow(tester, 'K2AA');
      await tester.enterText(_field('Name'), 'Bob');
      await drop();
      await tester.tap(find.text('Save'));
      await finishImport();
      expect(_editing(tester), isNull);
      expect((await _stored(tester, h.services, qsos['K2AA']!)).theirName, 'Bob');
      await _unmount(tester);
    });

    testWidgets('a second drop while the first settles the editor is turned away as busy', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);
      final onFile = tester.widget<AdifDropTarget>(find.byType(AdifDropTarget)).onFile;
      XFile file() => XFile.fromData(Uint8List.fromList(utf8.encode('<eoh>')), name: 'log.adi', path: 'log.adi');

      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Name'), 'Hiram');
      unawaited(onFile(file()));
      await settleFrames(tester, frames: 2);
      // The first import is waiting on the editor. Claimed only after that
      // wait, the busy flag would let this one through to race it.
      unawaited(onFile(file()));
      await settleFrames(tester, frames: 2);
      expect(find.text('An import is already running. Wait for it to finish before starting another.'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('↓ onto a row that goes while the dialog is up closes the editor instead', (tester) async {
      final h = await _harness();
      final (_, qsos) = await _seed(h.services);
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'N3BB');
      await tester.enterText(_field('Name'), 'Bob');
      _listFocus(tester).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleFrames(tester, frames: 2);
      expect(find.text('Unsaved changes'), findsOneWidget);
      // K2AA, the row ↓ was headed for, is deleted from elsewhere meanwhile.
      await tester.runAsync(() => h.services.qsos.softDelete(qsos['K2AA']!));
      await settleFrames(tester, frames: 2);
      await tester.tap(find.text('Save'));
      await settleFrames(tester, frames: 6);

      // Selected anyway, the vanished row would open no editor and anchor
      // the keyboard on nothing: Enter would reach no row at all.
      expect(_editing(tester), isNull);
      expect((await _stored(tester, h.services, qsos['N3BB']!)).theirName, 'Bob');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleFrames(tester, frames: 4);
      expect(_editing(tester), 'N3BB', reason: 'the keyboard is still on the row it left');
      await _unmount(tester);
    });

    testWidgets('one "Unsaved changes" dialog however many keys land before it has focus', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'N3BB');
      await tester.enterText(_field('Name'), 'Bob');
      _listFocus(tester).requestFocus();
      await tester.pump();
      // Two presses in one frame: a held key, or a quick double tap.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleFrames(tester, frames: 2);
      expect(find.text('Unsaved changes'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('names a staged delete for what it is, and Discard keeps the QSO', (tester) async {
      final h = await _harness();
      final (_, qsos) = await _seed(h.services);
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pump();
      await _tapRow(tester, 'K2AA');
      // "Unsaved changes" with a Save that deletes would have the operator
      // delete the QSO while meaning to keep their work.
      expect(find.text('This QSO is marked for deletion.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await settleFrames(tester, frames: 6);
      expect(_editing(tester), 'K2AA');
      expect((await _stored(tester, h.services, qsos['W1AW']!)).deleted, isFalse);
      await _unmount(tester);
    });

    testWidgets('Enter on a button in the editor is the button, not a save', (tester) async {
      final h = await _harness();
      final (_, qsos) = await _seed(h.services);
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Name'), 'Hiram');
      Focus.of(tester.element(find.byIcon(MdiIcons.trashCanOutline))).requestFocus();
      await tester.pump();

      // On the delete button Enter stages the delete…
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byIcon(MdiIcons.undo), findsOneWidget);
      expect(_editing(tester), 'W1AW', reason: 'not saved and closed');

      // …and on the Undo it becomes, Enter undoes it. Taken as a save, it
      // would have committed the very delete being undone.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleFrames(tester, frames: 3);
      expect(find.byIcon(MdiIcons.trashCanOutline), findsOneWidget);
      expect((await _stored(tester, h.services, qsos['W1AW']!)).deleted, isFalse);
      await _unmount(tester);
    });

    testWidgets('a malformed grid changes nothing', (tester) async {
      final h = await _harness();
      final operation = await h.services.operations.create(stationCall: 'K1ABC');
      final qso = await _log(h.services, operation, 'W1AW', _utc(20, 10), theirExtra: {'grid': 'FN31pr', 'lat': 41.71, 'lon': -72.73});
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Grid'), 'FN3');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleFrames(tester, frames: 6);

      // Stored, "FN3" would name no square, and the pair written with it
      // would erase the coordinate — the same rule a bad date or frequency
      // follows.
      final their = (await _stored(tester, h.services, qso)).data['their'] as Map;
      expect(their['grid'], 'FN31pr');
      expect((their['lat'], their['lon']), (41.71, -72.73));
      await _unmount(tester);
    });

    testWidgets('closes without asking when nothing was changed', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      await _tapRow(tester, 'K2AA');
      // A prompt on every click through a log would teach the operator to
      // answer it without reading.
      expect(find.text('Unsaved changes'), findsNothing);
      expect(_editing(tester), 'K2AA');
      await _unmount(tester);
    });

    testWidgets('opens the operation the QSO belongs to from a button naming it', (tester) async {
      final h = await _harness();
      await _seed(h.services, userTitle: 'Hilltop');
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      // The button that opens it, named by it: in a log spanning every
      // operation, an icon alone says nothing about where it leads.
      final button = find.ancestor(of: find.text('K1ABC Hilltop'), matching: find.byType(OutlinedButton));
      expect(button, findsOneWidget);
      expect(find.descendant(of: button, matching: find.byIcon(MdiIcons.openInNew)), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a typed grid replaces the stored coordinate, and an untouched guess stays a guess', (tester) async {
      final h = await _harness();
      final operation = await h.services.operations.create(stationCall: 'K1ABC');
      final qso = await _log(
        h.services,
        operation,
        'W1AW',
        _utc(20, 10),
        theirExtra: {
          'lat': 41.71,
          'lon': -72.73,
          'guess': {'name': 'Hiram Percy Maxim', 'state': 'CT'},
        },
      );
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      expect(tester.widget<TextField>(_field('Name')).controller!.text, 'Hiram Percy Maxim', reason: 'the guess is what the operator sees');
      await tester.enterText(_field('Grid'), 'FN20');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleFrames(tester, frames: 6);

      final their = (await _stored(tester, h.services, qso)).data['their'] as Map;
      final center = locationForStatedGrid('FN20')!;
      expect(their['grid'], 'FN20');
      // Left behind, the old pair would outrank the typed grid everywhere a
      // location is read (docs/design/locations.md).
      expect((their['lat'], their['lon']), (center.latitude, center.longitude));
      // Written back, the guess would become the operator's statement and
      // stop following the lookup.
      expect(their.containsKey('name'), isFalse);
      expect(their.containsKey('state'), isFalse);
      expect(_editing(tester), isNull, reason: 'Enter saves and closes');
      await _unmount(tester);
    });
  });

  group('the keyboard', () {
    testWidgets('↑/↓ step through the rows, Esc closes, and Enter goes into the editor and saves from it', (tester) async {
      final h = await _harness();
      final (_, qsos) = await _seed(h.services);
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'N3BB');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleFrames(tester, frames: 4);
      expect(_editing(tester), 'K2AA');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleFrames(tester, frames: 4);
      expect(_editing(tester), 'N3BB');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleFrames(tester, frames: 6);
      expect(_editing(tester), isNull);
      // The keyboard keeps its place after the editor closes.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleFrames(tester, frames: 6);
      expect(_editing(tester), 'K2AA');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tester.widget<TextField>(_field('Their call')).focusNode!.hasFocus, isTrue);
      await tester.enterText(_field('Their call'), 'K2AB');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleFrames(tester, frames: 6);
      expect((await _stored(tester, h.services, qsos['K2AA']!)).theirCall, 'K2AB');
      expect(_editing(tester), isNull);
      await _unmount(tester);
    });

    testWidgets('↑/↓ carry on from a row a collapsed group hides', (tester) async {
      final h = await _harness();
      final operation = await h.services.operations.create(stationCall: 'K1ABC');
      await _log(h.services, operation, 'K22AA', _utc(22, 9));
      await _log(h.services, operation, 'K21AA', _utc(21, 9));
      await _log(h.services, operation, 'K20AA', _utc(20, 9));
      await _pumpLogs(tester, h);

      // From the top or the bottom, the keys would jump past every row
      // between there and the one that was selected.
      await _tapRow(tester, 'K21AA');
      await tester.tap(_row('Mon, Sep 21'));
      await settleFrames(tester, frames: 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleFrames(tester, frames: 4);
      expect(_editing(tester), 'K20AA');

      await tester.tap(_row('Mon, Sep 21'));
      await settleFrames(tester, frames: 4);
      await _tapRow(tester, 'K21AA');
      await tester.tap(_row('Mon, Sep 21'));
      await settleFrames(tester, frames: 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleFrames(tester, frames: 4);
      expect(_editing(tester), 'K22AA');
      await _unmount(tester);
    });

    testWidgets('↓ keeps the selected row in view when the pane runs its own density', (tester) async {
      final h = await _harness();
      final operation = await h.services.operations.create(stationCall: 'K1ABC');
      for (var i = 0; i < 80; i++) {
        await _log(h.services, operation, 'AA${i.toString().padLeft(3, '0')}', _utc(20, 0) + i * 60000);
      }
      // A pane density roomier than the view's: rows taller than the view
      // alone would say, so an offset worked out from the view's density
      // falls short by more at every row.
      await h.settings.setLayoutData(LayoutKeys.logsPaneOptions, {
        LogsView.qsoTablePanelId: {'density': 'sparsest'},
      });
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'AA079');
      for (var i = 0; i < 60; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      await settleFrames(tester, frames: 8);
      expect(_editing(tester), 'AA019');
      final table = tester.getRect(_table);
      final row = tester.getRect(_row('AA019'));
      expect(row.top, greaterThanOrEqualTo(table.top));
      expect(row.bottom, lessThanOrEqualTo(table.bottom));
      await _unmount(tester);
    });

    testWidgets('Esc in the editor discards what was typed', (tester) async {
      final h = await _harness();
      final (_, qsos) = await _seed(h.services);
      await _pumpLogs(tester, h);

      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Name'), 'Hiram');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleFrames(tester, frames: 6);
      expect(find.text('Unsaved changes'), findsNothing, reason: 'Esc is the operator saying discard');
      expect(_editing(tester), isNull);
      expect((await _stored(tester, h.services, qsos['W1AW']!)).theirName, isNull);
      await _unmount(tester);
    });
  });

  group('leaving the destination', () {
    testWidgets('asks first when the editor holds an edit', (tester) async {
      final h = await _harness();
      await _seed(h.services);
      await _pumpShell(tester, h);

      await _tapRow(tester, 'W1AW');
      await tester.enterText(_field('Name'), 'Hiram');
      // The rail and the back key both leave through here.
      final leaving = homeRail.leaveTo(HomeDestination.operations);
      await settleFrames(tester, frames: 4);
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleFrames(tester, frames: 4);
      await leaving;
      expect(homeRail.destination, HomeDestination.logs, reason: 'Cancel keeps the operator on the edit');

      final leavingAgain = homeRail.leaveTo(HomeDestination.operations);
      await settleFrames(tester, frames: 4);
      await tester.tap(find.text('Discard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await leavingAgain;
      expect(homeRail.destination, HomeDestination.operations);
      // Mid-slide, Logs is still mounted — and a way back to it. Settled but
      // left open, the discarded edit would still be there to save by mistake.
      expect(find.byType(LogsView), findsOneWidget);
      expect(_editing(tester), isNull);
      await settleFrames(tester);

      await _unmountShell(tester);
    });
  });

  // With semantics on — a screen reader, or the dev web build, which forces
  // them on for agent tooling — Flutter web turns tappable semantics nodes
  // into DOM elements that receive the clicks themselves. So a node that
  // overlaps something it doesn't paint takes that thing's clicks.
  group('the semantics a click can land on', () {
    testWidgets('the title is named by its own two lines alone', (tester) async {
      final semantics = tester.ensureSemantics();
      final h = await _harness();
      await _seed(h.services);
      final other = await h.services.operations.create(stationCall: 'W2XYZ');
      await _log(h.services, other, 'VE3CC', _utc(22, 8));
      await _pumpLogs(tester, h);

      // Web lays the name out as DOM text in the title's own box, overflow
      // showing. A name longer than what the title shows — run together
      // with a label for the sheet's dots — wraps below the AppBar, and
      // clicks on the table header under it open the sheet.
      expect(
        tester.getSemantics(find.ancestor(of: find.text('All Logs'), matching: find.byType(InkWell)).first),
        isSemantics(label: 'All Logs, 4 QSOs · 2026-09-20 – 2026-09-22', hasTapAction: true),
      );
      await _unmount(tester);
      semantics.dispose();
    });

    testWidgets('Home leaves the semantics tree while Logs covers it', (tester) async {
      final semantics = tester.ensureSemantics();
      final h = await _harness();
      await _seed(h.services);
      await _pumpShell(tester, h);

      // Painted over but still in the tree, Home's operation cards take the
      // clicks on every empty stretch of the Logs view and open an operation
      // nobody can see.
      expect(find.bySemanticsLabel(RegExp('General Operation')), findsNothing);

      homeRail.destination = HomeDestination.operations;
      await settleFrames(tester);
      expect(find.bySemanticsLabel(RegExp('General Operation')), findsWidgets, reason: 'and comes back with Home');

      await _unmountShell(tester);
      semantics.dispose();
    });
  });
}
