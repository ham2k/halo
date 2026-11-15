// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spots Panel holds its rows still while the operator is using the list:
// a row that moves under the pointer gets the wrong station tapped. What
// arrives meanwhile waits behind a toast, and goes in when the operator asks
// or after four quiet seconds.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/local_spots.dart';
import 'package:ham2k_logger/services/spot_board.dart' show spotAgeOptionsInMinutes;
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/list_update_hold.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

class _FakeExtensions extends ExtensionService {
  List<Map<String, dynamic>> offered = [];

  @override
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> getSpots() async =>
      (items: offered, succeeded: const ['test'], unreachable: const <String>[], failed: const <String>[]);

  @override
  Future<Map<String, String>> getSpotSourceNames() async => const {'test': 'Test Source'};

  @override
  Future<void> start() async {}

  @override
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async =>
      (controls: const <Map<String, dynamic>>[], loadFailed: false);

  @override
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
    bool recentContext = false,
    String? streakKey,
  }) async => null;
}

Map<String, dynamic> _spot(String call, double freq) => {
  'their': {'call': call},
  'freq': freq,
  'band': '20m',
  'mode': 'SSB',
  'refs': const <Map<String, dynamic>>[],
  'spot': {'timeInMillis': nowMillis() - 60000, 'source': 'test'},
  'hookKey': 'test',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late _FakeExtensions extensions;
  late HaLoServices services;
  late SpotsPanelController controller;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    await settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any'});
    extensions = _FakeExtensions()..offered = [_spot('K1ABC', 14250)];
    services = HaLoServices(db, settings, extensions: extensions);
    await services.spots.refresh();
    controller = SpotsPanelController();
  });

  tearDown(() async => db.close());

  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final created = await tester.runAsync(() => OperationsRepository(db).create(stationCall: 'N0CALL'));
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          home: Scaffold(
            body: SpotsPanel(operation: created!, services: services, logRevision: 'r1', visible: ValueNotifier(true), controller: controller),
          ),
        ),
      ),
    );
    await pumpFrames(tester);
  }

  /// A spot the sources now offer, fetched while the panel is up.
  Future<void> arrive(WidgetTester tester, Map<String, dynamic> spot) async {
    extensions.offered = [...extensions.offered, spot];
    await tester.runAsync(services.spots.refresh);
    await pumpFrames(tester);
  }

  /// A mouse moving over the list: the lightest thing that counts as using it.
  Future<TestGesture> hover(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.text('K1ABC')));
    await mouse.moveBy(const Offset(0, 4));
    await tester.pump();
    return mouse;
  }

  final toast = find.text(t.operation.spots.pendingUpdates(count: 1));

  testWidgets('a spot arriving while the list sits untouched shows at once', (tester) async {
    // The control: without it, the hold below could be a panel that never
    // shows a refresh at all.
    await pumpPanel(tester);
    await arrive(tester, _spot('W2XYZ', 14260));
    expect(find.text('W2XYZ'), findsOneWidget);
    expect(toast, findsNothing);
  });

  testWidgets('a spot arriving while the pointer moves over the list waits behind the toast', (tester) async {
    await pumpPanel(tester);
    await hover(tester);
    await arrive(tester, _spot('W2XYZ', 14260));
    expect(find.text('W2XYZ'), findsNothing, reason: 'a new row would push the one under the pointer');
    expect(toast, findsOneWidget);

    await tester.tap(toast);
    await pumpFrames(tester);
    expect(find.text('W2XYZ'), findsOneWidget);

    // Tapping the toast was using the list too, so the next one waits again.
    await arrive(tester, _spot('K3DEF', 14270));
    expect(find.text('K3DEF'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('four quiet seconds let what waited in, and the toast fades out', (tester) async {
    await pumpPanel(tester);
    await hover(tester);
    await arrive(tester, _spot('W2XYZ', 14260));

    // A mouse resting still is not using the list: the clock runs from its
    // last movement, not from when it leaves.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('W2XYZ'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await pumpFrames(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('W2XYZ'), findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(find.ancestor(of: toast, matching: find.byType(AnimatedOpacity))).opacity, 0);
  });

  testWidgets('a re-post of a spot already listed is not counted as an update', (tester) async {
    await pumpPanel(tester);
    await hover(tester);
    // K1ABC posted again, newer, beside one station that is new.
    extensions.offered = [
      {
        ..._spot('K1ABC', 14250),
        'spot': {'timeInMillis': nowMillis() - 1000, 'source': 'test'},
      },
      _spot('W2XYZ', 14260),
    ];
    await tester.runAsync(services.spots.refresh);
    await pumpFrames(tester);
    expect(tester.widget<PendingUpdatesToast>(find.byType(PendingUpdatesToast)).count, 1, reason: 'the re-post moves no row the operator is looking at');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a spot arriving below what is in view goes in at once, one above it waits', (tester) async {
    // Holding back a change nobody can see only leaves the list staler: the
    // hold is for rows that would move under the pointer.
    await services.settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', 'sortBy': 'frequency'});
    extensions.offered = [
      for (var i = 0; i < 40; i++)
        if (i == 0) _spot('K1ABC', 14200) else _spot('W${i}AA', 14200.0 + i),
    ];
    await tester.runAsync(services.spots.refresh);
    await pumpPanel(tester);
    await hover(tester);

    await arrive(tester, _spot('W9LOW', 14300));
    expect(find.text(t.operation.spots.spotsCount(count: 41)), findsOneWidget, reason: 'the row below the fold is in the list');
    expect(tester.widget<PendingUpdatesToast>(find.byType(PendingUpdatesToast)).count, 0);

    await arrive(tester, _spot('W9TOP', 14100));
    expect(find.text('W9TOP'), findsNothing, reason: 'a row at the top pushes down every row in view');
    expect(tester.widget<PendingUpdatesToast>(find.byType(PendingUpdatesToast)).count, 1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a spot arriving above the view of a scrolled list goes in, and the rows in view stay put', (tester) async {
    await services.settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', 'sortBy': 'frequency'});
    extensions.offered = [for (var i = 0; i < 40; i++) _spot('W${i}AA', 14200.0 + i)];
    await tester.runAsync(services.spots.refresh);
    await pumpPanel(tester);
    tester.state<ScrollableState>(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable))).position.jumpTo(600);
    await pumpFrames(tester);
    final inView = find.text('W25AA');
    final before = tester.getTopLeft(inView).dy;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(inView));
    await mouse.moveBy(const Offset(0, 4));
    await tester.pump();

    await arrive(tester, _spot('W9TOP', 14100));
    expect(find.text(t.operation.spots.spotsCount(count: 41)), findsOneWidget, reason: 'the row above the view is in the list');
    expect(tester.widget<PendingUpdatesToast>(find.byType(PendingUpdatesToast)).count, 0);
    // Without the scroll following the new row, every row in view moves down
    // by its height, under the pointer.
    expect(tester.getTopLeft(inView).dy, moreOrLessEquals(before, epsilon: 1));
    await tester.pump(const Duration(seconds: 5));
  });

  /// Forty stations a kilohertz apart from 14200, K1ABC first, sorted by
  /// frequency: more than the view shows.
  Future<void> pumpLongList(WidgetTester tester) async {
    await services.settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', 'sortBy': 'frequency'});
    extensions.offered = [for (var i = 0; i < 40; i++) i == 0 ? _spot('K1ABC', 14200) : _spot('W${i}AA', 14200.0 + i)];
    await tester.runAsync(services.spots.refresh);
    await pumpPanel(tester);
  }

  /// [spots] fetched at once, while the panel is up.
  Future<void> arriveAll(WidgetTester tester, List<Map<String, dynamic>> spots) async {
    extensions.offered = [...extensions.offered, ...spots];
    await tester.runAsync(services.spots.refresh);
    await pumpFrames(tester);
  }

  testWidgets('the toast counts only the updates that change the list in view', (tester) async {
    // The count is what tapping it would change on screen: a spot below the
    // fold changes nothing there.
    await pumpLongList(tester);
    await hover(tester);
    await arriveAll(tester, [_spot('W9TOP', 14100), _spot('W9LOW', 14300)]);
    expect(tester.widget<PendingUpdatesToast>(find.byType(PendingUpdatesToast)).count, 1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a spot changing in place shows while the list holds, beside one that waits', (tester) async {
    // The hold is for rows that move: one that only changes what it says
    // moves nothing, so holding it back only shows a stale comment.
    await pumpLongList(tester);
    await hover(tester);
    extensions.offered = [
      {
        ..._spot('K1ABC', 14200),
        'spot': {'timeInMillis': nowMillis() - 1000, 'source': 'test', 'label': 'Moved to the summit'},
      },
      ...extensions.offered.skip(1),
      _spot('W9TOP', 14100),
    ];
    await tester.runAsync(services.spots.refresh);
    await pumpFrames(tester);
    expect(find.textContaining('Moved to the summit', findRichText: true), findsOneWidget);
    expect(find.text('W9TOP'), findsNothing);
    expect(tester.widget<PendingUpdatesToast>(find.byType(PendingUpdatesToast)).count, 1, reason: 'the comment gaining a line is not one of them');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets("an assistant hiding a spot waits like the spot's leaving would", (tester) async {
    // Verdicts and marks reorder and hide rows as surely as the sources do:
    // holding only the sources' spots leaves the row free to vanish from
    // under the pointer, with no toast to say why.
    await pumpPanel(tester);
    await hover(tester);
    extensions.spotMarks.mark('coach', ['test|K1ABC|20m|SSB'], (icon: null, color: null, note: null, boost: 0, hidden: true));
    await pumpFrames(tester);
    expect(find.text('K1ABC'), findsOneWidget);
    expect(tester.widget<PendingUpdatesToast>(find.byType(PendingUpdatesToast)).count, 1);

    await tester.pump(const Duration(seconds: 5));
    await pumpFrames(tester);
    expect(find.text('K1ABC'), findsNothing);
  });

  testWidgets('a finger resting on a row keeps the list held past the quiet period', (tester) async {
    // A press that stops moving reports nothing: timed from its last event
    // alone, the hold ends under a finger still deciding what to do.
    await pumpPanel(tester);
    final finger = await tester.startGesture(tester.getCenter(find.text('K1ABC')));
    await arrive(tester, _spot('W2XYZ', 14260));
    await tester.pump(const Duration(seconds: 6));
    await pumpFrames(tester);
    expect(find.text('W2XYZ'), findsNothing);

    await finger.up();
    await tester.pump(const Duration(seconds: 5));
    await pumpFrames(tester);
    expect(find.text('W2XYZ'), findsOneWidget);
  });

  testWidgets('the station the operator is working moving takes what waited along', (tester) async {
    // The local spot is the operator's own doing, and never waits — nor can
    // it go in alone, when its row's place depends on everything else.
    await pumpPanel(tester);
    await hover(tester);
    await arrive(tester, _spot('W2XYZ', 14260));
    expect(find.text('W2XYZ'), findsNothing);

    services.spots.putLocalSpot(
      'draft',
      localSpotFromQso(const {
        'their': {'call': 'W9LOC'},
        'freq': 14280.0,
        'mode': 'SSB',
      }, now: nowMillis())!,
    );
    await pumpFrames(tester);
    expect(find.text('W9LOC'), findsWidgets);
    expect(find.text('W2XYZ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a list held while empty takes the spots that arrive', (tester) async {
    // An empty list has no row to keep still: holding it leaves the operator
    // an empty list behind a toast, for as long as the pointer moves.
    extensions.offered = [];
    await tester.runAsync(services.spots.refresh);
    await pumpPanel(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.byType(ListUpdateHoldDetector)));
    await mouse.moveBy(const Offset(0, 4));
    await tester.pump();

    await arrive(tester, _spot('W2XYZ', 14260));
    expect(find.text('W2XYZ'), findsOneWidget);
    expect(tester.widget<PendingUpdatesToast>(find.byType(PendingUpdatesToast)).count, 0);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('two rows of one station on one frequency each keep their own spot while held', (tester) async {
    // The merge keeps spots half an hour apart as two rows; matched by
    // station and frequency alone, both rows would draw the same one.
    await services.settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', 'ageMinutes': spotAgeOptionsInMinutes.last});
    extensions.offered = [
      {
        ..._spot('K1ABC', 14250),
        'spot': {'timeInMillis': nowMillis() - 45 * 60000, 'source': 'test', 'label': 'Earlier park'},
      },
      {
        ..._spot('K1ABC', 14250),
        'spot': {'timeInMillis': nowMillis() - 60000, 'source': 'test', 'label': 'Later park'},
      },
    ];
    await tester.runAsync(services.spots.refresh);
    await pumpPanel(tester);
    expect(find.textContaining('Earlier park', findRichText: true), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.text('K1ABC').first));
    await mouse.moveBy(const Offset(0, 4));
    await tester.pump();

    await arrive(tester, _spot('W9TOP', 14100));
    expect(find.text('W9TOP'), findsNothing);
    expect(find.textContaining('Earlier park', findRichText: true), findsOneWidget);
    expect(find.textContaining('Later park', findRichText: true), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets("the toast's refresh keeps the top row in view where it is", (tester) async {
    await pumpLongList(tester);
    tester.state<ScrollableState>(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable))).position.jumpTo(600);
    await pumpFrames(tester);
    final above = find.text('W20AA');
    final before = tester.getTopLeft(above).dy;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(above));
    await mouse.moveBy(const Offset(0, 4));
    await tester.pump();

    // One in view, so the list holds; one above it, which moves every row
    // in view down unless the scroll follows it.
    await arriveAll(tester, [_spot('W9MID', 14225.5), _spot('W9TOP', 14100)]);
    expect(find.text('W9MID'), findsNothing);
    await tester.tap(find.byType(PendingUpdatesToast));
    await pumpFrames(tester);
    expect(find.text('W9MID'), findsOneWidget);
    expect(tester.getTopLeft(above).dy, moreOrLessEquals(before, epsilon: 1));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a re-post that moves a row to the top under the time sort is an update', (tester) async {
    // In both lists, so neither arriving nor leaving: counted by neither, the
    // list would hold with no toast to say why.
    await services.settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', 'sortBy': 'time', 'groupByBand': false});
    extensions.offered = [
      _spot('K1ABC', 14250),
      {
        ..._spot('W2XYZ', 14260),
        'spot': {'timeInMillis': nowMillis() - 30000, 'source': 'test'},
      },
    ];
    await tester.runAsync(services.spots.refresh);
    await pumpPanel(tester);
    await hover(tester);
    extensions.offered = [
      {
        ..._spot('K1ABC', 14250),
        'spot': {'timeInMillis': nowMillis() - 1000, 'source': 'test'},
      },
      extensions.offered[1],
    ];
    await tester.runAsync(services.spots.refresh);
    await pumpFrames(tester);
    expect(tester.widget<PendingUpdatesToast>(find.byType(PendingUpdatesToast)).count, 1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a spot does not age off the list while it is held', (tester) async {
    // The age filter reads the clock, not the board: holding the board alone
    // still lets a row drop out from under the pointer.
    await services.settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', 'ageMinutes': 15});
    extensions.offered = [
      ...extensions.offered,
      {
        ..._spot('W9OLD', 14280),
        'spot': {'timeInMillis': nowMillis() - 14 * 60000, 'source': 'test'},
      },
    ];
    await tester.runAsync(services.spots.refresh);
    await pumpPanel(tester);
    expect(find.text('W9OLD'), findsOneWidget);

    await hover(tester);
    AppClock.instance.travel(delta: const Duration(minutes: 2));
    addTearDown(AppClock.instance.reset);
    await arrive(tester, _spot('W2XYZ', 14260));
    expect(find.text('W9OLD'), findsOneWidget);
    expect(tester.widget<PendingUpdatesToast>(find.byType(PendingUpdatesToast)).count, 2, reason: 'one row arriving, one leaving');

    await tester.pump(const Duration(seconds: 5));
    await pumpFrames(tester);
    expect(find.text('W9OLD'), findsNothing);
  });

  testWidgets('the refresh button shows what it fetched even while the list is held', (tester) async {
    await pumpPanel(tester);
    await hover(tester);
    extensions.offered = [...extensions.offered, _spot('W2XYZ', 14260)];
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(resolveIconName('refresh')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await pumpFrames(tester);
    expect(find.text('W2XYZ'), findsOneWidget, reason: 'the operator asked for the board as it stands');
  });

  testWidgets("the panel's controller opens the filter dialog, as the tab's settings button does", (tester) async {
    await pumpPanel(tester);
    unawaited(controller.openFilters());
    await pumpFrames(tester);
    expect(find.text(t.operation.spots.filters.title), findsOneWidget);
  });
}
