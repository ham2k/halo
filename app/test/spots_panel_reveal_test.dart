// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spots panel's reveal: which row is tinted as the current QSO, and when
// the list scrolls to it. Every defect found in this machine so far has been a
// state one — a latch set before the work could fail, a visibility flag read
// from a mirror, a key placed by an identity two rows share — and none of them
// is reachable from the pure helpers in spots_panel_current_qso_test.dart.
//
// pumpAndSettle is deliberately absent: the age labels ride the shared
// once-per-second WallClock, so a settle loop keeps finding a scheduled frame
// and runs to its ten-minute timeout instead of failing.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

/// Serves a fixed board instead of reaching for the extension runtime, and
/// answers the call-note lookup the panel makes for every spotted call — that
/// lookup is what decides the "Calls of Note" section, so a test about the
/// pinned duplicate has to drive it.
class _FakeExtensions extends ExtensionService {
  _FakeExtensions(this.board, {this.notedCalls = const {}});

  final List<Map<String, dynamic>> board;
  final Set<String> notedCalls;

  @override
  Future<({List<Map<String, dynamic>> items, List<String> unreachable, List<String> failed})> getSpots() async =>
      (items: board, unreachable: const <String>[], failed: const <String>[]);

  @override
  Future<Map<String, String>> getSpotSourceNames() async => const {'test': 'Test Source'};

  @override
  Future<List<Map<String, dynamic>>> loggingControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      const [];

  @override
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
    bool recentContext = false,
  }) async =>
      notedCalls.contains(call) ? {'guess': {'emoji': '⭐️'}} : null;
}

Map<String, dynamic> _spot(String call, {String band = '20m', double freq = 14250.0}) => {
      'their': {'call': call},
      'freq': freq,
      'band': band,
      'mode': 'SSB',
      'refs': const <Map<String, dynamic>>[],
      'spot': {'timeInMillis': 1700000000000, 'source': 'test'},
      'hookKey': 'test',
    };

/// A board of [count] spots on one band, called K0000, K0001, … — enough rows
/// that the ones at the bottom start well outside the viewport.
List<Map<String, dynamic>> _board(int count) => [
      for (var i = 0; i < count; i++)
        _spot('K${i.toString().padLeft(4, '0')}', freq: 14000.0 + i),
    ];

/// The same board, every spot carrying a reference label. Those rows paint a
/// few pixels TALLER than [spotRowHeight] — the label line draws at the
/// callsign's size rather than the mode's — so the estimate drifts by roughly
/// a row for every twenty, and only the measured correction lands it.
List<Map<String, dynamic>> _labelledBoard(int count) => [
      for (var i = 0; i < count; i++)
        {
          ..._spot('K${i.toString().padLeft(4, '0')}', freq: 14000.0 + i),
          'refs': [
            {'type': 'pota', 'ref': 'US-0001'}
          ],
          'spot': {
            'timeInMillis': 1700000000000,
            'source': 'test',
            'label': 'US-0001 Somewhere National Park',
          },
        },
    ];

CallInfoData _entering(String call, {bool editing = false}) => CallInfoData(call: call, isEditing: editing);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late SettingsService settings;
  late Operation operation;

  Future<HaLoServices> servicesWith(
    List<Map<String, dynamic>> spots, {
    Set<String> notedCalls = const {},
    bool groupCallsWithNotes = false,
  }) async {
    // Pinned so the board is never narrowed by the radio's current band or
    // mode — 'auto' follows the VFO, which no test here is about.
    await settings.setSpottingFilters({
      'bandFilter': 'any',
      'modeFilter': 'any',
      'sortBy': 'frequency',
      'groupByBand': true,
      'groupCallsWithNotes': groupCallsWithNotes,
    });
    return HaLoServices(db, settings, extensions: _FakeExtensions(spots, notedCalls: notedCalls));
  }

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    operation = await OperationsRepository(db).create(stationCall: 'N0CALL', userTitle: 'Test Op');
  });

  tearDown(() async => db.close());

  double offsetOf(WidgetTester tester) =>
      tester.widget<ListView>(find.byType(ListView)).controller!.offset;

  /// Pumps until the list stops moving. A reveal is up to two chained scrolls
  /// — the estimate, then the measured correction — and a fixed frame budget
  /// is a race against whichever one is still animating. pumpAndSettle can't
  /// do this: the age labels ride the shared once-per-second WallClock, so it
  /// always finds another frame scheduled and runs to its timeout.
  Future<void> settle(WidgetTester tester) async {
    var still = 0;
    var moved = false;
    var last = double.nan;
    for (var frame = 0; frame < 120; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      final now = offsetOf(tester);
      if (now != 0) moved = true;
      still = (now - last).abs() < 0.01 ? still + 1 : 0;
      last = now;
      // A list still at rest says nothing about whether a scroll is coming: the
      // reveal is several post-frame hops deep (arriving on screen, then the
      // row-height calibration, then the arm), and how many frames those take
      // is not fixed. Stillness only ends the wait once something has actually
      // moved; a test expecting no movement spends the whole budget, which is
      // the only honest way to conclude nothing was going to happen.
      if (moved && still >= 6) return;
    }
  }

  /// Mounts the panel and lets the spot fetch and the note lookups land.
  /// Returns a setter for the current call-info: re-pumping the same widget
  /// type in the same place hands the existing State a new `callInfo`, which
  /// is exactly how the operation view pushes one down.
  Future<Future<void> Function(CallInfoData?)> pumpPanel(
    WidgetTester tester, {
    required HaLoServices services,
    required ValueNotifier<bool> visible,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(500, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget host(CallInfoData? callInfo) => TranslationProvider(
          child: MaterialApp(
            theme: buildHaLoTheme(Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: SpotsPanel(
                  operation: operation,
                  services: services,
                  logRevision: 'r1',
                  visible: visible,
                  callInfo: callInfo,
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(host(null));
    // The fetch, the source names and the per-call note lookups are all
    // futures kicked off in initState; a few pumps settle them without the
    // WallClock hazard pumpAndSettle would hit.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return (CallInfoData? callInfo) async {
      await tester.pumpWidget(host(callInfo));
      // One frame to build and run the post-frame reveal, then let the scroll
      // (and the correction chained to it) finish.
      await tester.pump();
      await settle(tester);
    };
  }

  /// The fill painted behind [call]'s row, or null when that row is untinted.
  /// Read from the ColoredBox the tile wraps itself in, which is the only
  /// thing the highlight changes.
  Color? tintOf(WidgetTester tester, String call) {
    // Filtered by alpha: Material's own internals put a fully transparent
    // ColoredBox in this ancestry, and it would otherwise answer first.
    final painted = tester
        .widgetList<ColoredBox>(find.ancestor(of: find.text(call), matching: find.byType(ColoredBox)))
        .where((box) => box.color.a > 0);
    return painted.isEmpty ? null : painted.first.color;
  }

  group('the tint', () {
    testWidgets('marks the row for the call being entered, and no other', (tester) async {
      final services = await servicesWith([_spot('K1ABC'), _spot('W2DEF', freq: 14260.0)]);
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      expect(tintOf(tester, 'K1ABC'), isNull, reason: 'nothing entered yet');

      await setCall(_entering('K1ABC'));

      expect(tintOf(tester, 'K1ABC'), isNotNull);
      expect(tintOf(tester, 'W2DEF'), isNull);
    });

    // The panel and the logging controls must agree on which of the two states
    // the operator is in; a spots list that stayed orange while the logging
    // panel went blue would say they are composing a QSO they are editing.
    testWidgets('changes when the QSO goes from composing to editing', (tester) async {
      final services = await servicesWith([_spot('K1ABC')]);
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      await setCall(_entering('K1ABC'));
      final composing = tintOf(tester, 'K1ABC');
      await setCall(_entering('K1ABC', editing: true));

      expect(tintOf(tester, 'K1ABC'), isNot(composing));
    });

    // The regression that made the panel THROW rather than misbehave:
    // sectionSpots pins the same Map instance in "Calls of Note" and again in
    // its band section, so a row key placed by spot identity landed on two
    // tiles at once and the tree rejected the duplicate GlobalKey.
    testWidgets('a spot pinned in Calls of Note and its band section still builds', (tester) async {
      final services = await servicesWith(
        [_spot('K1ABC'), _spot('W2DEF', freq: 14260.0)],
        notedCalls: {'K1ABC'},
        groupCallsWithNotes: true,
      );
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      await setCall(_entering('K1ABC'));

      expect(tester.takeException(), isNull);
      // Both copies are on screen and both are tinted — the pin is a duplicate,
      // not a move, so the operator sees the same row twice.
      expect(find.text('K1ABC'), findsNWidgets(2));
    });
  });

  group('the reveal', () {
    testWidgets('scrolls a row below the fold into view', (tester) async {
      final services = await servicesWith(_board(60));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      expect(offsetOf(tester), 0);
      await setCall(_entering('K0050'));

      expect(offsetOf(tester), greaterThan(0));
      expect(find.text('K0050'), findsOneWidget, reason: 'the row is now built and on screen');
    });

    // The contract that makes this bearable to use: a spot the operator can
    // already see must not move under them just because they typed its call.
    testWidgets('leaves a row that is already on screen exactly where it is', (tester) async {
      final services = await servicesWith(_board(60));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      await setCall(_entering('K0000'));

      expect(offsetOf(tester), 0);
    });

    // The arithmetic alone cannot land this: rows carrying a reference label
    // are taller than the declared row height, so fifty of them put the target
    // several rows below where the estimate says it is. What closes the gap is
    // the measured pass — take it away and the row ends up off screen.
    testWidgets('lands on a row whose neighbours are all taller than the estimate', (tester) async {
      final services = await servicesWith(_labelledBoard(60));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      await setCall(_entering('K0050'));

      expect(find.text('K0050').hitTestable(), findsOneWidget,
          reason: 'on screen, not merely built into the viewport cache');
    });

    // A full POTA board, every row labelled and the target five hundred rows
    // down. This is where an estimate built from ONE representative row height
    // fails outright rather than approximately: three pixels a row is fifteen
    // hundred by the time it reaches the target, far outside what the measured
    // correction can reach, since the row it wants to measure was never
    // mounted. Summing each row's own height is what makes it land.
    testWidgets('lands on a labelled board long enough for per-row drift to matter', (tester) async {
      final services = await servicesWith(_labelledBoard(600));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      await setCall(_entering('K0500'));

      expect(find.text('K0500').hitTestable(), findsOneWidget);
    });

    // The OS accessibility text scale composes on top of the app's own Font
    // Scale (docs/design/ui-scaling.md rule 3), and a tile that is text lines
    // inside constant padding grows with it — 50 becomes 61 at 1.3. Offsets
    // summed from the declared heights land three thousand pixels short of the
    // target here, and because the row was never mounted the correction has
    // nothing to measure: the reveal reports success from the wrong place and
    // the latch retires the call for good. The measured scale is what closes
    // it; without it this is not a near miss but a permanent one.
    testWidgets('reveals a row far down the board at an OS text scale of 1.3', (tester) async {
      final services = await servicesWith(_board(300));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true), textScale: 1.3);

      await setCall(_entering('K0250'));

      expect(find.text('K0250').hitTestable(), findsOneWidget);
    });

    testWidgets('a call with no spot on the board scrolls nowhere', (tester) async {
      final services = await servicesWith(_board(60));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      await setCall(_entering('W9XYZ'));

      expect(offsetOf(tester), 0);
    });
  });

  // spotRowHeightFor is the reveal's entire model of a list it cannot see, and
  // a pixel of error per row becomes a row's worth every fifty. Measured against
  // real tiles, because a test that compares the constants only to each other
  // cannot fail when _SpotTile changes — and a change to what the tile paints
  // is exactly what silently breaks every offset the reveal sums.
  group('the declared row heights', () {
    Future<double> pitchOf(WidgetTester tester, List<Map<String, dynamic>> board,
        {Set<String> notedCalls = const {}}) async {
      final services = await servicesWith(board, notedCalls: notedCalls);
      await pumpPanel(tester, services: services, visible: ValueNotifier(true));
      return tester.getRect(find.text('K0002')).top - tester.getRect(find.text('K0001')).top;
    }

    testWidgets('a plain row paints what spotRowHeightFor declares', (tester) async {
      expect(await pitchOf(tester, _board(6)), closeTo(spotRowHeightFor(hasLabel: false, hasEmoji: false), 0.5));
    });

    testWidgets('a labelled row paints what spotRowHeightFor declares', (tester) async {
      expect(await pitchOf(tester, _labelledBoard(6)), closeTo(spotRowHeightFor(hasLabel: true, hasEmoji: false), 0.5));
    });

    // The emoji stretches a line that is already there rather than adding one,
    // so it is worth about a pixel — a plausible-looking three would drift a
    // row every twenty-five noted spots.
    testWidgets('a noted row paints what spotRowHeightFor declares', (tester) async {
      expect(await pitchOf(tester, _board(6), notedCalls: {'K0001'}),
          closeTo(spotRowHeightFor(hasLabel: false, hasEmoji: true), 0.5));
    });
  });

  group('visibility', () {
    // A hidden pane is still built and still rebuilt — it lives in the tab's
    // keep-alive bucket — so without the gate it scrolls itself, and the
    // operator returns to a list that moved while they were away.
    testWidgets('a hidden panel does not scroll itself', (tester) async {
      final services = await servicesWith(_board(60));
      final visible = ValueNotifier(false);
      final setCall = await pumpPanel(tester, services: services, visible: visible);

      await setCall(_entering('K0050'));

      expect(offsetOf(tester), 0);
    });

    // The call was typed behind another tab, so the reveal is still owed when
    // this one comes back — the latch is deliberately not advanced while
    // hidden, which is what leaves it owed.
    testWidgets('coming back on screen reveals a call entered while it was hidden', (tester) async {
      final services = await servicesWith(_board(60));
      final visible = ValueNotifier(false);
      final setCall = await pumpPanel(tester, services: services, visible: visible);

      await setCall(_entering('K0050'));
      expect(offsetOf(tester), 0, reason: 'still hidden');

      visible.value = true;
      await tester.pump();
      await settle(tester);

      expect(offsetOf(tester), greaterThan(0),
          reason: 'the reveal owed from while it was hidden never ran; K0050 built: '
              '${find.text('K0050').evaluate().isNotEmpty}');
      expect(find.text('K0050'), findsOneWidget);
    });

    // DockPaneVisibility is the dock's own answer, and it is ANDed with the
    // tab's: a pane hidden behind another in its dock group is not on screen
    // however the tab notifier reads. Nothing in the operation view can be
    // asked for this — revealModule surfaces a pane without telling it.
    testWidgets('a pane hidden by its dock group does not scroll, whatever the tab says', (tester) async {
      final services = await servicesWith(_board(60));
      tester.view.physicalSize = const Size(500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Widget host(CallInfoData? callInfo) => TranslationProvider(
            child: MaterialApp(
              theme: buildHaLoTheme(Brightness.light),
              home: Scaffold(
                body: DockPaneVisibility(
                  visible: false,
                  child: SpotsPanel(
                    operation: operation,
                    services: services,
                    logRevision: 'r1',
                    visible: ValueNotifier(true),
                    callInfo: callInfo,
                  ),
                ),
              ),
            ),
          );

      await tester.pumpWidget(host(null));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpWidget(host(_entering('K0050')));
      await tester.pump();
      await settle(tester);

      expect(offsetOf(tester), 0);
    });

    // The contract both halves of the visibility gate have to keep: a call the
    // operator has already been shown is not news, and their scroll position is
    // a deliberate act. Flipping panes in a dock group — or any revealModule,
    // which is how tapping a spot surfaces the logging pane — must not drag the
    // list back to a row they scrolled away from.
    testWidgets('returning to a visible dock pane leaves an unchanged call where it was', (tester) async {
      final services = await servicesWith(_board(60));
      tester.view.physicalSize = const Size(500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Widget host({required bool dockVisible, CallInfoData? callInfo}) => TranslationProvider(
            child: MaterialApp(
              theme: buildHaLoTheme(Brightness.light),
              home: Scaffold(
                body: DockPaneVisibility(
                  visible: dockVisible,
                  child: SpotsPanel(
                    operation: operation,
                    services: services,
                    logRevision: 'r1',
                    visible: ValueNotifier(true),
                    callInfo: callInfo,
                  ),
                ),
              ),
            ),
          );

      await tester.pumpWidget(host(dockVisible: true));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpWidget(host(dockVisible: true, callInfo: _entering('K0050')));
      await tester.pump();
      await settle(tester);
      final revealed = offsetOf(tester);
      expect(revealed, greaterThan(0), reason: 'the reveal happened at all');

      // The operator scrolls elsewhere, then flips to another pane and back.
      tester.widget<ListView>(find.byType(ListView)).controller!.jumpTo(0);
      await tester.pump();
      await tester.pumpWidget(host(dockVisible: false, callInfo: _entering('K0050')));
      await tester.pump();
      await tester.pumpWidget(host(dockVisible: true, callInfo: _entering('K0050')));
      await tester.pump();
      await settle(tester);

      expect(offsetOf(tester), 0, reason: 'came back to where the operator left it, not to $revealed');
    });
  });
}
