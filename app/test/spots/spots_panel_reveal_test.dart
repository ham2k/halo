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
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show Scorer;
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_scoring.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

/// Serves a fixed board instead of reaching for the extension runtime, and
/// answers the call-note lookup the panel makes for every spotted call — that
/// lookup is what decides the "Calls of Note" section, so a test about the
/// pinned duplicate has to drive it.
class _FakeExtensions extends ExtensionService {
  _FakeExtensions(this.board, {this.notedCalls = const {}, this.dupeCalls = const {}});

  final List<Map<String, dynamic>> board;
  final Set<String> notedCalls;

  /// Calls scoring reports as already in the log for this band and mode —
  /// the `duplicate` alert a real scorer raises.
  final Set<String> dupeCalls;

  @override
  Future<Map<String, Map<String, List<String>>>?> scoreCandidates({
    required Map<String, dynamic> operation,
    required String operationUuid,
    required Map<String, Map<String, dynamic>> candidates,
    List<Map<String, dynamic>>? segments,
    ScoringResume? resume,
    Future<Map<String, ScoringResume>> Function(List<Scorer> scorers)? resumesFor,
    Set<String> huntedRefTypes = const {},
  }) async => {
    for (final key in candidates.keys)
      if (dupeCalls.contains(key.split('|').first))
        key: const {
          'alerts': ['duplicate'],
        },
  };

  @override
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> getSpots() async => (
    items: board,
    succeeded: board.map((s) => s['hookKey'] as String? ?? 'unknown').toSet().toList(),
    unreachable: const <String>[],
    failed: const <String>[],
  );

  @override
  Future<Map<String, String>> getSpotSourceNames() async => const {'test': 'Test Source'};

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
  }) async => notedCalls.contains(call)
      ? {
          'guess': {'emoji': '⭐️'},
        }
      : null;
}

Map<String, dynamic> _spot(String call, {String band = '20m', double freq = 14250.0}) => {
  'their': {'call': call},
  'freq': freq,
  'band': band,
  'mode': 'SSB',
  'refs': const <Map<String, dynamic>>[],
  'spot': {'timeInMillis': nowMillis() - 60000, 'source': 'test'},
  'hookKey': 'test',
};

/// A board of [count] spots on one band, called K0000, K0001, … — enough rows
/// that the ones at the bottom start well outside the viewport.
List<Map<String, dynamic>> _board(int count) => [for (var i = 0; i < count; i++) _spot('K${i.toString().padLeft(4, '0')}', freq: 14000.0 + i)];

/// The same board, every spot carrying a reference label. Those rows paint a
/// few pixels TALLER than a plain one — the label line draws at the
/// callsign's size rather than the mode's — so the estimate drifts by roughly
/// a row for every twenty, and only the measured correction lands it.
List<Map<String, dynamic>> _labelledBoard(int count) => [
  for (var i = 0; i < count; i++)
    {
      ..._spot('K${i.toString().padLeft(4, '0')}', freq: 14000.0 + i),
      'refs': [
        {'type': 'pota', 'ref': 'US-0001'},
      ],
      'spot': {'timeInMillis': nowMillis() - 60000, 'source': 'test', 'label': 'US-0001 Somewhere National Park'},
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
    Set<String> dupeCalls = const {},
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
    return HaLoServices(
      db,
      settings,
      extensions: _FakeExtensions(spots, notedCalls: notedCalls, dupeCalls: dupeCalls),
    );
  }

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    operation = await OperationsRepository(db).create(stationCall: 'N0CALL', userTitle: 'Test Op');
  });

  tearDown(() async => db.close());

  /// The spots list itself. Scoped to the panel's own subtree because the
  /// filters dialog builds a CustomScrollView of its own — it lands in the
  /// navigator's overlay rather than under the panel, so this cannot match it.
  final spotsList = find.descendant(of: find.byType(SpotsPanel), matching: find.byType(CustomScrollView));

  double offsetOf(WidgetTester tester) => tester.widget<CustomScrollView>(spotsList).controller!.offset;

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
    ValueNotifier<LayoutDensity>? density,
    void Function(Map<String, dynamic> qso, {bool reveal})? onSuggestQso,
    int closeSlidesSerial = 0,
    ValueChanged<String?>? onWithdrawSuggestion,
    VoidCallback? onSuggestionSettled,
    ValueChanged<Map<String, dynamic>>? onLogQso,
  }) async {
    final densityNotifier = density ?? ValueNotifier(LayoutDensity.normal);
    tester.view.physicalSize = const Size(500, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget host(CallInfoData? callInfo) => TranslationProvider(
      child: MaterialApp(
        theme: buildHaLoTheme(Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: ValueListenableBuilder(
            valueListenable: densityNotifier,
            builder: (_, density, _) => LayoutDensityScope(
              density: density,
              child: Scaffold(
                body: SpotsPanel(
                  operation: operation,
                  services: services,
                  logRevision: 'r1',
                  visible: visible,
                  callInfo: callInfo,
                  onSuggestQso: onSuggestQso,
                  closeSlidesSerial: closeSlidesSerial,
                  onWithdrawSuggestion: onWithdrawSuggestion,
                  onSuggestionSettled: onSuggestionSettled,
                  onLogQso: onLogQso,
                ),
              ),
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
    final painted = tester.widgetList<ColoredBox>(find.ancestor(of: find.text(call), matching: find.byType(ColoredBox))).where((box) => box.color.a > 0);
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
      final services = await servicesWith([_spot('K1ABC'), _spot('W2DEF', freq: 14260.0)], notedCalls: {'K1ABC'}, groupCallsWithNotes: true);
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

    // Section headers PIN, so the top of the list is covered by one: a reveal
    // that brings the row flush with the viewport top puts it BEHIND the
    // header, hiding the very row it went to find. Reached by revealing UPWARDS
    // — a row below the fold comes to the BOTTOM edge, which the header cannot
    // cover, so a downward reveal proves nothing about the inset. Both halves
    // are asserted: that the header is up there at all with its own rows
    // scrolled under it, and that the row landed clear of it.
    testWidgets('lands a row revealed upwards below the pinned header', (tester) async {
      final services = await servicesWith(_board(60));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      // Scrolled a few rows down by hand, then a call entered for a row above
      // the fold. Close to the top on purpose: the summed offsets are still
      // exact there, so where the row lands is the inset's doing and not a
      // drift the measured correction happened to leave behind.
      tester.widget<CustomScrollView>(spotsList).controller!.jumpTo(400);
      await tester.pump();
      await setCall(_entering('K0003'));

      // The band itself, not the label inside it: what has to clear the header
      // is the whole row, and the callsign sits low enough in its tile to clear
      // the band even when the tile does not.
      final band = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SpotsSectionHeader');
      expect(band, findsOneWidget, reason: 'the band header is still on screen with its rows scrolled under it');
      final bandRect = tester.getRect(band);
      // Held AT the top, not merely somewhere above the row: an unpinned band
      // that has scrolled off is still laid out in the viewport's cache, and a
      // one-sided "above" check would pass for it too.
      expect(bandRect.top, closeTo(tester.getRect(spotsList).top, 0.5), reason: 'pinned at the top of the list, not scrolled away with its rows');
      final row = find.ancestor(of: find.text('K0003'), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SpotTile'));
      expect(tester.getRect(row).top, greaterThanOrEqualTo(bandRect.bottom), reason: 'the revealed row is below the header, not behind it');
    });

    // What the SliverMainAxisGroup buys, and the reason each band is grouped
    // with its own rows rather than listed as a sibling sliver: pinning is
    // coordinated inside a group, so the band of the section being read is the
    // only one holding the top. Sibling pinned slivers stick independently —
    // scroll past a short section and its band stays up there alongside the
    // next one's, stacking a header per section scrolled through.
    testWidgets('only the section being read keeps its band at the top', (tester) async {
      final services = await servicesWith([
        ..._board(20),
        for (var i = 0; i < 20; i++) _spot('W${i.toString().padLeft(4, '0')}', band: '40m', freq: 7100.0 + i),
      ]);
      await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      // Deep into the second band, with the first band's rows all above.
      tester.widget<CustomScrollView>(spotsList).controller!.jumpTo(1400);
      await tester.pump();

      final listTop = tester.getRect(spotsList).top;
      final atTheTop = [
        for (final band in find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SpotsSectionHeader').evaluate())
          if ((tester.getRect(find.byWidget(band.widget)).top - listTop).abs() < 1.0) (band.widget as dynamic).label as String,
      ];
      expect(atTheTop, hasLength(1), reason: 'one band at the top, not one per section scrolled through');
      // And it is the band whose rows are actually being read: this board's
      // 20m spots are called K…, its 40m spots W….
      final reading = atTheTop.single.startsWith('20m') ? 'K' : 'W';
      expect(find.textContaining(RegExp('^$reading[0-9]{4}\$')).hitTestable(), findsWidgets, reason: 'the pinned band names the rows on screen');
    });

    // The contract that makes this bearable to use: a spot the operator can
    // already see must not move under them just because they typed its call.
    testWidgets('leaves a row that is already on screen exactly where it is', (tester) async {
      final services = await servicesWith(_board(60));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      await setCall(_entering('K0000'));

      expect(offsetOf(tester), 0);
    });

    // Picking a spot from its band row puts its call in the fields, and "Calls
    // of Note" pins a second copy of that row at the top. The first copy is
    // the pinned one, so a reveal that takes the first match jumps the list
    // away from the row the operator just picked.
    testWidgets('stays beside an on-screen copy of a call pinned in Calls of Note', (tester) async {
      final services = await servicesWith(_board(60), notedCalls: {'K0040'}, groupCallsWithNotes: true);
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      tester.widget<CustomScrollView>(spotsList).controller!.jumpTo(1900);
      await tester.pump();
      expect(find.text('K0040').hitTestable(), findsOneWidget, reason: 'the band copy is on screen and the pinned copy is not');
      final before = offsetOf(tester);

      await setCall(_entering('K0040'));

      expect(offsetOf(tester), before);
    });

    // Neither copy on screen: the reveal goes to the nearer one rather than
    // always climbing back to the pinned copy at the top of the board.
    testWidgets('reveals the nearer copy of a pinned call when neither is on screen', (tester) async {
      final services = await servicesWith(_board(60), notedCalls: {'K0040'}, groupCallsWithNotes: true);
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      tester.widget<CustomScrollView>(spotsList).controller!.jumpTo(1400);
      await tester.pump();
      expect(find.text('K0040').hitTestable(), findsNothing, reason: 'neither copy is on screen to begin with');

      await setCall(_entering('K0040'));

      expect(offsetOf(tester), greaterThan(1400), reason: 'down to the band copy, not up to the pinned one');
      expect(find.text('K0040').hitTestable(), findsOneWidget);
    });

    // The arithmetic alone cannot land this: rows carrying a reference label
    // are taller than the declared row height, so fifty of them put the target
    // several rows below where the estimate says it is. What closes the gap is
    // the measured pass — take it away and the row ends up off screen.
    testWidgets('lands on a row whose neighbours are all taller than the estimate', (tester) async {
      final services = await servicesWith(_labelledBoard(60));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      await setCall(_entering('K0050'));

      expect(find.text('K0050').hitTestable(), findsOneWidget, reason: 'on screen, not merely built into the viewport cache');
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

    // The scale is a whole-row ratio, but the OS text scale it stands for
    // stretches only the text — the tile's padding and line gap are the two
    // things the density ladder moves, and neither grows with it. So a scale
    // learned at one rung is wrong at the next, and the calibration row that
    // could re-learn it is only mounted near the top of a list this operator
    // has long since scrolled past. Carrying the stretch across the change is
    // what lands this; leave the scale alone and every summed row is ~6% short.
    testWidgets('reveals a far row at an OS text scale of 1.3 after the density changes', (tester) async {
      final services = await servicesWith(_board(300));
      final density = ValueNotifier(LayoutDensity.sparsest);
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true), textScale: 1.3, density: density);

      // Learn the scale at the roomiest rung, then drop to the tightest — the
      // widest gap the ladder offers, and the direction a window resize takes.
      await setCall(_entering('K0010'));
      density.value = LayoutDensity.densest;
      await tester.pump();

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
    Future<double> pitchOf(
      WidgetTester tester,
      List<Map<String, dynamic>> board, {
      Set<String> notedCalls = const {},
      LayoutDensity density = LayoutDensity.normal,
    }) async {
      final services = await servicesWith(board, notedCalls: notedCalls);
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), density: ValueNotifier(density));
      return tester.getRect(find.text('K0002')).top - tester.getRect(find.text('K0001')).top;
    }

    // Every rung, not just `normal`: the tile's padding is the one thing that
    // moves with the density, so a tile left on a constant would keep passing
    // at `normal` while every other rung's reveal scrolled to the wrong place.
    for (final density in LayoutDensity.values) {
      testWidgets('a plain row paints what spotRowHeightFor declares at $density', (tester) async {
        expect(await pitchOf(tester, _board(6), density: density), closeTo(spotRowHeightFor(metrics: density.metrics, hasLabel: false, hasEmoji: false), 0.5));
      });

      testWidgets('a labelled row paints what spotRowHeightFor declares at $density', (tester) async {
        expect(
          await pitchOf(tester, _labelledBoard(6), density: density),
          closeTo(spotRowHeightFor(metrics: density.metrics, hasLabel: true, hasEmoji: false), 0.5),
        );
      });
    }

    // The emoji stretches a line that is already there rather than adding one,
    // so it is worth about a pixel — a plausible-looking three would drift a
    // row every twenty-five noted spots. Checked at both ends of the ladder
    // like the other two shapes: the claim that the emoji does not answer to
    // density is only worth anything if some rung other than `normal` tests it.
    for (final density in [LayoutDensity.densest, LayoutDensity.normal, LayoutDensity.sparsest]) {
      testWidgets('a noted row paints what spotRowHeightFor declares at $density', (tester) async {
        expect(
          await pitchOf(tester, _board(6), notedCalls: {'K0001'}, density: density),
          closeTo(spotRowHeightFor(metrics: density.metrics, hasLabel: false, hasEmoji: true), 0.5),
        );
      });
    }
  });

  // The slide is the only gesture in the app that acts on a row, and both of
  // its ends are destructive in their own way: one logs a contact, the other
  // strikes a station off the board. What these pin is that neither happens
  // by accident, and that the row's declared geometry survives a widget that
  // moves it sideways.
  group('sliding a row', () {
    /// Drags the row for [call] horizontally by [dx] and releases. Note that
    /// `kTouchSlop` (18) is consumed before the recognizer starts moving the
    /// row, so the DISPLACEMENT is about 18 less than [dx] — which is why the
    /// resting-open drags below are larger than the 36pt peek threshold
    /// rather than just over it.
    Future<void> slide(WidgetTester tester, String call, double dx) async {
      final gesture = await tester.startGesture(tester.getCenter(find.text(call)));
      // In steps, because the commit threshold is watched per drag frame — a
      // single jump past it would pass even if the crossing were never seen.
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(dx / 10, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    double openDx(WidgetTester tester, String call, {required String closed}) =>
        tester.getTopLeft(find.text(call)).dx - tester.getTopLeft(find.text(closed)).dx;

    testWidgets('a short drag right rests open and suggests, without logging', (tester) async {
      final services = await servicesWith(_board(6));
      final suggested = <Map<String, dynamic>>[];
      final reveals = <bool>[];
      final logged = <Map<String, dynamic>>[];
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) {
          suggested.add(qso);
          reveals.add(reveal);
        },
        onLogQso: logged.add,
      );

      await slide(tester, 'K0001', 120);

      expect(suggested.single['their'], {'call': 'K0001'}, reason: 'opening fills the fields');
      // The whole point of the gesture on a narrow window: the operator is
      // working the spots list, so nothing may surface the logging panel and
      // take it away mid-slide.
      expect(reveals, [false], reason: 'a slide must never navigate away');
      expect(logged, isEmpty, reason: 'a short drag only offers the button');
      expect(find.byIcon(MdiIcons.upload), findsOneWidget, reason: 'the action is icon-only');
    });

    testWidgets('the QSO is not suggested until the drag means it', (tester) async {
      final services = await servicesWith(_board(6));
      final suggested = <Map<String, dynamic>>[];
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) => suggested.add(qso),
        onLogQso: (_) {},
      );

      // Past kTouchSlop but short of the 36pt peek threshold: the row has
      // moved a little and nothing has been chosen. Suggesting on the first
      // pixel of movement would retune the radio on a twitch.
      final gesture = await tester.startGesture(tester.getCenter(find.text('K0001')));
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(9, 0));
        await tester.pump();
      }
      expect(suggested, isEmpty, reason: 'still under the peek threshold');

      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(9, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(suggested.single['their'], {'call': 'K0001'});
      expect(suggested, hasLength(1), reason: 'once per open, not once per drag frame');
    });

    testWidgets('the action icon crosses its well once the drag is armed', (tester) async {
      final services = await servicesWith(_board(6));
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: (_) {});

      double iconDx() => tester.getCenter(find.byIcon(MdiIcons.upload)).dx;

      final rowDx = tester.getCenter(find.text('K0001')).dx;
      final gesture = await tester.startGesture(tester.getCenter(find.text('K0001')));
      // Open, but short of the commit point — the icon rides centred in the
      // well the drag is opening.
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }
      // The content's displacement IS the width of the well it uncovered, and
      // measuring it beats deriving it from the travel: the recogniser eats an
      // opening slop this test has no business knowing the size of.
      final revealed = tester.getCenter(find.text('K0001')).dx - rowDx;
      expect(iconDx(), closeTo(revealed / 2, 1), reason: 'centred in what has been uncovered, not pinned to either edge');
      final resting = iconDx();

      // Past two fifths of the 500pt row: the icon rides across to sit against
      // the row it is about to act on.
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final armed = iconDx();

      expect(armed, greaterThan(resting), reason: 'the icon moved toward the row, not merely with the widening well');
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a row resting open centres its icon in the well', (tester) async {
      final services = await servicesWith(_board(6));
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: (_) {});

      await slide(tester, 'K0001', 120);

      // 72pt well, so its middle is 36 from the row's leading edge. The
      // mutation this catches is pinning the icon back to the outer edge,
      // which leaves it hard against the panel's frame.
      expect(tester.getCenter(find.byIcon(MdiIcons.upload)).dx, closeTo(36, 1));
    });

    testWidgets('a drag past two fifths of the row logs it on release', (tester) async {
      final services = await servicesWith(_board(6));
      final logged = <Map<String, dynamic>>[];
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: logged.add);

      // The panel is 500 wide, so the commit point is 200 of displacement and
      // 240 of travel clears it by less than the old half-width rule would
      // have — a drag that rests open under 0.5 and fires under 0.4. Mutation
      // check: drop the threshold test in _onDragEnd and the short-drag case
      // above logs too; raise the fraction back to 0.5 and this one stops.
      await slide(tester, 'K0001', 240);

      expect(logged.single['their'], {'call': 'K0001'});
    });

    // The peek's fill is the OPEN ROW's, not the operator's. Every way a row
    // stops being open has to take it back, or the logging fields keep a
    // station the operator has visibly moved on from — and the next Log is a
    // contact with whoever was slid last.
    // A touch taken away rather than lifted — a system gesture claiming it,
    // the app backgrounded. Flutter reports that to an ACCEPTED drag as an
    // ordinary `onEnd` (`onHorizontalDragCancel` fires only before acceptance),
    // so the row cannot tell the two apart on its own and a takeover past the
    // commit point would log a contact nobody released.
    testWidgets('a drag past the commit point that is cancelled logs nothing', (tester) async {
      final services = await servicesWith(_board(6));
      final logged = <Map<String, dynamic>>[];
      final withdrawn = <String?>[];
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) {},
        onWithdrawSuggestion: withdrawn.add,
        onLogQso: logged.add,
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('K0001')));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(25, 0));
        await tester.pump();
      }
      await gesture.cancel();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(logged, isEmpty, reason: 'a cancelled gesture was never released');
      expect(openDx(tester, 'K0001', closed: 'K0003'), 0, reason: 'and the row shuts rather than resting open');
      // Shutting is what takes the peek back. A cancel that left the fill
      // behind would leave a station the operator never chose sitting in the
      // logging fields, with no open row left to take it away.
      expect(withdrawn, ['K0001'], reason: 'the peek goes back with the row');
    });

    // The cancel guard must key on the pointer that ENDS the gesture, not on
    // any cancel over the row: a second touch the system takes away would
    // otherwise disarm a release the operator did make, swallowing the contact
    // with no log, no error and nothing in the console to find it by.
    testWidgets('a second touch cancelled mid-drag still lets the release log', (tester) async {
      final services = await servicesWith(_board(6));
      final logged = <Map<String, dynamic>>[];
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: logged.add);

      final row = tester.getCenter(find.text('K0001'));
      final a = await tester.startGesture(row, pointer: 7);
      for (var i = 0; i < 20; i++) {
        await a.moveBy(const Offset(25, 0));
        await tester.pump();
      }
      // A palm or second thumb landing on the same row, which the OS then
      // takes away. The drag under finger A was never interrupted.
      final b = await tester.startGesture(row, pointer: 8);
      await tester.pump();
      await b.cancel();
      await tester.pump();
      await a.up();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(logged, hasLength(1), reason: 'the operator released past the commit point');
    });

    // The guard is armed per gesture, so it has to be disarmed per gesture
    // too. A flag left set outlives the touch that set it — the row's State
    // survives an ordinary re-spot — and every later release on that row would
    // shut it without logging, losing contacts with nothing to find them by.
    testWidgets('a row whose drag was cancelled can still be slid to log', (tester) async {
      final services = await servicesWith(_board(6));
      final logged = <Map<String, dynamic>>[];
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: logged.add);

      final cancelled = await tester.startGesture(tester.getCenter(find.text('K0001')));
      for (var i = 0; i < 20; i++) {
        await cancelled.moveBy(const Offset(25, 0));
        await tester.pump();
      }
      await cancelled.cancel();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(logged, isEmpty, reason: 'the cancelled gesture logged nothing');

      final released = await tester.startGesture(tester.getCenter(find.text('K0001')));
      for (var i = 0; i < 20; i++) {
        await released.moveBy(const Offset(25, 0));
        await tester.pump();
      }
      await released.up();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(logged, hasLength(1), reason: 'the next release on the same row still logs');
    });

    // A thumb scrolling the board arcs, so its early samples can cross the
    // horizontal slop in the very frame they cross the vertical one — and the
    // row's recognizer, being the inner one on the hit-test path, is asked
    // first and takes the pointer. The whole list then refuses to scroll while
    // a row slides under a finger that meant to move the board.
    //
    // Mutation check: drop the dominance test from
    // _AxisLockedHorizontalDragGestureRecognizer and this drag opens the row
    // and fills the logging fields with a station nobody chose.
    testWidgets('a drag that is mostly vertical scrolls rather than sliding', (tester) async {
      final services = await servicesWith(_board(40));
      final suggested = <Map<String, dynamic>>[];
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) => suggested.add(qso),
        onLogQso: (_) {},
      );

      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final gesture = await tester.startGesture(tester.getCenter(find.text('K0001')));
      // Ten across for every thirteen up: both axes pass the 18px slop within
      // the same move, which is the tie this recognizer has to lose.
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(10, -13));
        await tester.pump();
      }
      // Held still before lifting, so the release carries no velocity: a fling
      // would leave a ballistic timer running past the end of the test.
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(suggested, isEmpty, reason: 'a scroll must not pick up a station');
      expect(find.byIcon(MdiIcons.upload), findsNothing, reason: 'no row opened');
      expect(position.pixels, greaterThan(0), reason: 'the board scrolled instead');
    });

    // A palm or a second thumb can land on the row while the first finger is
    // still scrolling, and it lands wherever it lands — often far across the
    // row. Mutation check: measure the travel from one recognizer-wide origin
    // instead of per pointer and the second touch becomes the first finger's
    // starting point, which reads as a long sideways move and opens the row.
    testWidgets('a second finger landing mid-scroll does not open the row', (tester) async {
      final services = await servicesWith(_board(40));
      final suggested = <Map<String, dynamic>>[];
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) => suggested.add(qso),
        onLogQso: (_) {},
      );

      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final row = tester.getCenter(find.text('K0001'));
      final scrolling = await tester.startGesture(row);
      final resting = await tester.startGesture(row + const Offset(200, 0));
      // Long enough that a row which DID take the pointer would end up resting
      // open, and steep enough throughout that a row judging the scrolling
      // finger by its own landing point never can.
      for (var i = 0; i < 12; i++) {
        await scrolling.moveBy(const Offset(10, -13));
        await tester.pump();
      }
      // The palm lifts and the thumb carries on scrolling — the point at which
      // a row that took the pointer under the wrong origin starts moving under
      // the finger, because the drag it began is now the only one tracking it.
      await resting.up();
      for (var i = 0; i < 8; i++) {
        await scrolling.moveBy(const Offset(10, -13));
        await tester.pump();
      }

      // Judged with the thumb still down: a row that DID take the pointer
      // slides under them, and only the release guard (which refuses to act
      // while another finger is down) would tidy it away afterwards — long
      // after the operator has watched their scroll turn into a slide.
      expect(suggested, isEmpty, reason: 'the scrolling finger is judged by where IT landed');
      expect(openDx(tester, 'K0001', closed: 'K0002'), 0, reason: 'the row never moved');
      expect(position.pixels, greaterThan(0), reason: 'the board scrolled once the palm lifted');

      await scrolling.up();
      await tester.pumpAndSettle();
    });

    // The gesture is the only route to these actions, and the buttons it
    // reveals are on screen only while the row is displaced — so a row that
    // declares no drag to the semantics tree offers a screen-reader user
    // nothing at all. Mutation check: drop the `semantics:` delegate and the
    // default one looks the drag up by the exact recognizer type, finds this
    // row's subclass under its own key, and declares no action.
    testWidgets('an assistive horizontal scroll runs the whole slide', (tester) async {
      final semantics = tester.ensureSemantics();
      final services = await servicesWith(_board(6));
      final logged = <Map<String, dynamic>>[];
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: logged.add);

      final node = tester.getSemantics(find.ancestor(of: find.text('K0001'), matching: find.byType(RawGestureDetector)).first);
      expect(node.getSemanticsData().hasAction(SemanticsAction.scrollRight), isTrue);

      node.owner!.performAction(node.id, SemanticsAction.scrollRight);
      await tester.pumpAndSettle();

      expect(logged.single['their'], {'call': 'K0001'}, reason: 'one synthesised drag, start to end');
      semantics.dispose();
    });

    testWidgets('dragging back takes the suggestion away again', (tester) async {
      final services = await servicesWith(_board(6));
      final suggested = <Map<String, dynamic>>[];
      var withdrawn = 0;
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) => suggested.add(qso),
        onWithdrawSuggestion: (_) => withdrawn++,
        onLogQso: (_) {},
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('K0001')));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }
      expect(suggested, hasLength(1), reason: 'the peek filled the fields');
      expect(withdrawn, 0);

      // All the way back under the peek, without ever lifting: the gesture the
      // operator changed their mind halfway through.
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-12, 0));
        await tester.pump();
      }
      expect(withdrawn, 1, reason: 'the fields are no longer anybody\'s choice of station');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('setting the spot aside takes it away too', (tester) async {
      final services = await servicesWith(_board(6));
      var withdrawn = 0;
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) {},
        onWithdrawSuggestion: (_) => withdrawn++,
        onLogQso: (_) {},
      );

      // Open on the log side, then carry the same finger through the middle
      // and out the other side to strike the row off the board.
      await slide(tester, 'K0001', 120);
      await slide(tester, 'K0001', -300);

      expect(withdrawn, 1, reason: 'a spot being set aside is not the spot being worked');
    });

    testWidgets('opening another row hands the fields to the new spot', (tester) async {
      final services = await servicesWith(_board(6));
      final suggested = <String>[];
      var withdrawn = 0;
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) => suggested.add(qso['their']['call'] as String),
        onWithdrawSuggestion: (_) => withdrawn++,
        onLogQso: (_) {},
      );

      await slide(tester, 'K0001', 120);
      await slide(tester, 'K0002', 120);

      // Order matters as much as the count: the first row's withdrawal has to
      // land BEFORE the second row's suggestion, or the panel sees the new
      // spot arrive over a call it still believes is in progress and asks the
      // operator about work it filled in itself.
      expect(suggested, ['K0001', 'K0002']);
      expect(withdrawn, 1, reason: 'the row that filled the fields closed when the next one opened');
    });

    testWidgets('a committed slide spends its peek rather than withdrawing it', (tester) async {
      final services = await servicesWith(_board(6));
      var withdrawn = 0;
      final logged = <Map<String, dynamic>>[];
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) {},
        onWithdrawSuggestion: (_) => withdrawn++,
        onLogQso: logged.add,
      );

      await slide(tester, 'K0001', 240);

      expect(logged, hasLength(1));
      // The mutation this catches: withdrawing on the way to firing, which
      // empties the very fields the log is made from.
      expect(withdrawn, 0, reason: 'what the peek filled is what the commit logs');
    });

    testWidgets('the row coming to rest is what settles the gesture', (tester) async {
      final services = await servicesWith(_board(6));
      var settled = 0;
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) {},
        onSuggestionSettled: () => settled++,
        onLogQso: (_) {},
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('K0001')));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }
      // Still down. Anything the panel raises here is a modal over a live
      // gesture: the drag runs on underneath it and the release still commits.
      expect(settled, 0, reason: 'the finger has not left the row');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(settled, 1);
    });

    testWidgets('REPRO a slashed call keeps taking suggestions', (tester) async {
      // A slashed call is a spot like any other, but the logging panel reports
      // its own callsign back as `callInfo` — and everything the panel does
      // with that (locate the row, arm the reveal, scroll) runs between one
      // slide and the next.
      final services = await servicesWith([_spot('EA3/KI2D'), _spot('W2DEF', freq: 14260.0)]);
      final suggested = <String>[];
      var withdrawn = 0;
      final setCall = await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) => suggested.add(qso['their']['call'] as String),
        onWithdrawSuggestion: (_) => withdrawn++,
        onLogQso: (_) {},
      );

      await slide(tester, 'EA3/KI2D', 120);
      expect(suggested, ['EA3/KI2D']);
      // What the logging panel sends back once it has taken the suggestion.
      await setCall(const CallInfoData(call: 'EA3/KI2D'));

      await slide(tester, 'W2DEF', 120);
      expect(suggested, ['EA3/KI2D', 'W2DEF'], reason: 'the next slide still fills the fields');
      expect(withdrawn, greaterThanOrEqualTo(1));
    });

    testWidgets('tapping a spot closes whatever row is open', (tester) async {
      final services = await servicesWith(_board(6));
      final suggested = <String>[];
      final reveals = <bool>[];
      var withdrawn = 0;
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) {
          suggested.add(qso['their']['call'] as String);
          reveals.add(reveal);
        },
        onWithdrawSuggestion: (_) => withdrawn++,
        onLogQso: (_) {},
      );

      await slide(tester, 'K0001', 120);
      await tester.tap(find.text('K0002'));
      await tester.pumpAndSettle();

      // The tap answers the question the open row was asking, so the row may
      // not stay armed behind it — and the withdrawal has to land BEFORE the
      // tap's own suggestion, or it takes the tapped station straight back out.
      expect(withdrawn, 1);
      expect(suggested, ['K0001', 'K0002']);
      expect(reveals, [false, true], reason: 'a tap reveals the panel, a slide never does');
      expect(find.byIcon(MdiIcons.upload), findsNothing, reason: 'the open row closed');
    });

    testWidgets('the logging panel taking the fields closes an open row', (tester) async {
      final services = await servicesWith(_board(6));
      var withdrawn = 0;
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        closeSlidesSerial: 0,
        onSuggestQso: (qso, {bool reveal = true}) {},
        onWithdrawSuggestion: (_) => withdrawn++,
        onLogQso: (_) {},
      );
      await slide(tester, 'K0001', 120);
      expect(find.byIcon(MdiIcons.upload), findsOneWidget);

      // What the operator typing in (or wiping) the call field arrives as.
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        closeSlidesSerial: 1,
        onSuggestQso: (qso, {bool reveal = true}) {},
        onWithdrawSuggestion: (_) => withdrawn++,
        onLogQso: (_) {},
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.upload), findsNothing);
      expect(withdrawn, 1, reason: 'and the peek it made goes with it');
    });

    testWidgets('tapping the revealed button logs it', (tester) async {
      final services = await servicesWith(_board(6));
      final logged = <Map<String, dynamic>>[];
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: logged.add);

      await slide(tester, 'K0001', 120);
      await tester.tap(find.byIcon(MdiIcons.upload));
      await tester.pumpAndSettle();

      expect(logged.single['their'], {'call': 'K0001'});
    });

    // The trailing action always reverses what the row SAYS, so it reads the
    // same whether the strikethrough came from scoring or from an earlier
    // slide. Only the slide-made case is reachable from this harness (scoring
    // arrives through the extension host), but both go through the one
    // `worked` value the row is built from.
    testWidgets('the trailing action flips between taking a spot off the board and putting it back', (tester) async {
      final services = await servicesWith(_board(6));
      await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      // A live spot offers backspace — take this off my board.
      await slide(tester, 'K0001', -120);
      expect(find.byIcon(MdiIcons.backspace), findsOneWidget);
      expect(find.byIcon(MdiIcons.undoVariant), findsNothing);

      await tester.tap(find.byIcon(MdiIcons.backspace));
      await tester.pumpAndSettle();

      // Now struck through, the same slide offers undo instead.
      await slide(tester, 'K0001', -120);
      expect(find.byIcon(MdiIcons.undoVariant), findsOneWidget);
      expect(find.byIcon(MdiIcons.backspace), findsNothing);
    });

    // A row is dimmed by folding the factor into every colour it paints. The
    // trap is that this is invisible when it goes wrong: wrapping the row in an
    // `Opacity` as well still looks "dimmed", just twice as much, and nothing
    // in the suite noticed for two rounds of review. So assert the ARITHMETIC —
    // one factor, not two — rather than that the row looks faded.
    testWidgets('a worked row is dimmed exactly once', (tester) async {
      final services = await servicesWith(_board(6));
      await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      final theme = buildHaLoTheme(Brightness.light);
      double alphaOf(String call) => tester.widget<Text>(find.text(call)).style!.color!.a;

      final live = alphaOf('K0001');
      expect(live, closeTo(theme.colorScheme.onSurface.a, 0.001), reason: 'sanity: undimmed to start');

      await slide(tester, 'K0001', -400);

      expect(alphaOf('K0001'), closeTo(theme.colorScheme.onSurface.a * 0.6, 0.001), reason: 'one 0.6, not 0.6 squared');
      // Mutation check: restore the Opacity wrapper and this still passes — the
      // style colour is unchanged by it — so the layer has to be checked too.
      expect(
        tester.widgetList<Opacity>(find.ancestor(of: find.text('K0001'), matching: find.byType(Opacity))),
        isEmpty,
        reason: 'no second dim wrapped around the row',
      );
    });

    testWidgets('a spot taken off the board can still be logged', (tester) async {
      // Working a station twice is the operator's call to make, not this
      // panel's to prevent — a second contact on another band or mode is an
      // ordinary thing to want, and the row being struck through says only
      // that they have worked it before.
      final services = await servicesWith(_board(6));
      final logged = <Map<String, dynamic>>[];
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: logged.add);

      await slide(tester, 'K0001', -400);
      await slide(tester, 'K0001', 400);

      expect(logged.single['their'], {'call': 'K0001'});
    });

    testWidgets('sliding left far enough greys the row out without striking it', (tester) async {
      final services = await servicesWith(_board(6));
      await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      // The same accessor the sibling test below watches turn to
      // lineThrough, so an assertion that it stays null here cannot be
      // passing because the finder matched nothing.
      TextStyle? style() => tester.widget<Text>(find.text('K0001')).style;

      final full = style()!.color!.a;
      expect(style()?.decoration, isNull, reason: 'nothing has been ignored yet');

      await slide(tester, 'K0001', -400);
      // The strikethrough belongs to calls already in the log: a set-aside
      // spot that borrowed it would be indistinguishable from a worked one.
      expect(style()?.decoration, isNull, reason: 'an ignored spot is not a logged one');
      expect(style()!.color!.a, lessThan(full), reason: 'an ignored spot greys out');

      // Reversible on purpose: a mis-slide that could not be undone would
      // make the gesture something an operator learns to avoid.
      await slide(tester, 'K0001', -400);
      expect(style()!.color!.a, full);
    });

    // The two states have to stay tellable apart: grey says "not this one,
    // right now", the strikethrough says "already in the log". A slide moves
    // only the first, in either direction.
    testWidgets('a slide never adds or removes the log strikethrough', (tester) async {
      final services = await servicesWith(_board(6), dupeCalls: {'K0001'});
      await pumpPanel(tester, services: services, visible: ValueNotifier(true));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      TextStyle? style() => tester.widget<Text>(find.text('K0001')).style;

      expect(style()?.decoration, TextDecoration.lineThrough, reason: 'K0001 is in the log');
      final dimmed = style()!.color!.a;

      // Slid to restore: back on the board, at full contrast — but the
      // contact it duplicates has not been un-made.
      await slide(tester, 'K0001', -400);
      expect(style()?.decoration, TextDecoration.lineThrough);
      expect(style()!.color!.a, greaterThan(dimmed));
    });

    testWidgets('ignoring one spot leaves its neighbours alone', (tester) async {
      final services = await servicesWith(_board(6));
      await pumpPanel(tester, services: services, visible: ValueNotifier(true));

      final before = tester.widget<Text>(find.text('K0002')).style?.color;
      await slide(tester, 'K0001', -400);

      expect(tester.widget<Text>(find.text('K0002')).style?.color, before, reason: 'the ignore set is keyed by call, not applied to the list');
    });

    /// How far [call]'s row is displaced from where it sits closed. Measured
    /// against a row that is certainly shut, because the list itself may have
    /// scrolled: counting "Log it" buttons cannot tell an open SECOND row
    /// from a first row that never closed.
    // The real sequence a slide sets off: opening the row suggests the QSO,
    // the logging panel fills, and the call comes back as this panel's
    // `callInfo` — which makes the slid row the CURRENT one and moves
    // `_currentRowKey`, a GlobalKey, onto the very row under the finger.
    // A GlobalKey landing on a widget re-parents its element, and an element
    // that is deactivated mid-gesture takes the drag down with it.
    testWidgets('the drag survives the slid row becoming the current QSO', (tester) async {
      final services = await servicesWith(_board(6));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: (_) {});

      final closedAt = tester.getTopLeft(find.text('K0003')).dx;
      final gesture = await tester.startGesture(tester.getCenter(find.text('K0001')));
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }
      // Mid-drag, exactly as the logging panel's round trip does it.
      await setCall(_entering('K0001'));
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('K0001')).dx - closedAt, greaterThan(0), reason: 'the row stayed open — the re-key did not cancel the drag');
    });

    testWidgets('scrolling the board leaves an open row open', (tester) async {
      // The operator peeking at one spot's action while scanning the rest of
      // the board is reading, not abandoning the peek. A list that closed the
      // row under the scroll would also withdraw what it filled, emptying the
      // logging fields for a gesture the operator never made.
      final services = await servicesWith(_board(60));
      var withdrawn = 0;
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) {},
        onWithdrawSuggestion: (_) => withdrawn++,
        onLogQso: (_) {},
      );

      await slide(tester, 'K0001', 120);
      expect(openDx(tester, 'K0001', closed: 'K0003'), greaterThan(0));

      tester.widget<Scrollable>(find.byType(Scrollable).first).controller?.jumpTo(20);
      await tester.pumpAndSettle();

      expect(openDx(tester, 'K0001', closed: 'K0003'), greaterThan(0), reason: 'the scroll left the peek alone');
      expect(withdrawn, 0, reason: 'and left what it filled in the logging fields');
    });

    testWidgets('a mid-drag close does not take the row out from under the finger', (tester) async {
      final services = await servicesWith(_board(60));
      final suggested = <Map<String, dynamic>>[];
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) => suggested.add(qso),
        onLogQso: (_) {},
      );

      final closedAt = tester.getTopLeft(find.text('K0003')).dx;
      final gesture = await tester.startGesture(tester.getCenter(find.text('K0001')));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }
      final beforeClose = tester.getTopLeft(find.text('K0001')).dx - closedAt;
      expect(beforeClose, greaterThan(0));

      // What crossing the peek arms: suggesting the QSO edits the call being
      // logged, and the operation view answers by bumping `closeSlidesSerial`
      // — which closes every open row, this one included, mid-gesture.
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        closeSlidesSerial: 1,
        onSuggestQso: (qso, {bool reveal = true}) => suggested.add(qso),
        onLogQso: (_) {},
      );

      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(suggested, hasLength(1), reason: 'the row was never reset, so the peek was not re-crossed');
    });

    testWidgets('a row discarded while open takes its fill with it', (tester) async {
      // Nothing closed this row — it was DISCARDED. Its key carries the spot's
      // own timestamp, so the next poll that re-spots the open station builds
      // a different row and this one's State is gone mid-peek, with what it
      // filled still sitting in the logging fields and no open row left to
      // take it back.
      final board = [_spot('K1ABC'), _spot('W2DEF', freq: 14260.0)];
      final services = await servicesWith(board);
      var withdrawn = 0;
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) {},
        onWithdrawSuggestion: (_) => withdrawn++,
        onLogQso: (_) {},
      );

      await slide(tester, 'K1ABC', 120);
      expect(withdrawn, 0);

      // Re-spotted a minute later: same call, same frequency, new time — a new
      // key, and so a new row.
      board[0] = {
        ..._spot('K1ABC'),
        'spot': {'timeInMillis': 1700000060000, 'source': 'test'},
      };
      await tester.pump(const Duration(minutes: 3));
      await settle(tester);

      expect(withdrawn, 1, reason: 'the fill went with the row that made it');
    });

    testWidgets('a row that refused to close mid-drag is still the open one afterwards', (tester) async {
      // The refusal and the bookkeeping have to agree. Crossing the peek
      // suggests the QSO, which edits the call being logged, whose
      // `closeSlidesSerial` closes open rows — and this row, with a finger
      // still on it, says no. A group that forgets it anyway leaves a row that
      // is open and untracked: nothing closes it, and every later slide adds
      // another, until the list is a column of open rows.
      final services = await servicesWith(_board(60));
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: (_) {});

      final gesture = await tester.startGesture(tester.getCenter(find.text('K0001')));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }
      await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        closeSlidesSerial: 1,
        onSuggestQso: (qso, {bool reveal = true}) {},
        onLogQso: (_) {},
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.upload), findsOneWidget, reason: 'the drag survived the close');

      await slide(tester, 'K0004', 120);

      expect(find.byIcon(MdiIcons.upload), findsOneWidget, reason: 'and only one row is ever open');
    });

    testWidgets('opening a second row closes the first, and the second ends up open', (tester) async {
      final services = await servicesWith(_board(6));
      await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: (_) {});

      await slide(tester, 'K0001', 120);
      expect(openDx(tester, 'K0001', closed: 'K0003'), greaterThan(0));

      await slide(tester, 'K0002', 120);

      // Two rows sitting open at once means two armed actions and no way to
      // tell which one a press belongs to — but closing the old one may not
      // cost the new one its drag, which is the failure this pins: the second
      // slide was interrupted mid-gesture and the row snapped back shut.
      expect(openDx(tester, 'K0001', closed: 'K0003'), 0, reason: 'the first row closed');
      expect(openDx(tester, 'K0002', closed: 'K0003'), greaterThan(0), reason: 'the second row is open — its slide was not suspended by the first closing');
    });

    /// The last spot whose row the fold cuts: rendered, its text still on
    /// screen, but the row itself running past the bottom edge. That is the
    /// only row a reveal would move for — one entirely on screen is already
    /// revealed and never scrolls — so a slide test that used the top row
    /// would pass with the suppression taken back out.
    String callCutByTheFold(WidgetTester tester, int count) {
      final fold = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final pitch = tester.getRect(find.text('K0002')).top - tester.getRect(find.text('K0001')).top;
      for (var i = count - 1; i >= 0; i--) {
        final call = 'K${i.toString().padLeft(4, '0')}';
        final found = find.text(call);
        if (found.evaluate().isEmpty) continue;
        final centre = tester.getRect(found).center.dy;
        // Its centre is still on screen — the drag has to land on it — while
        // the row it sits in runs past the bottom edge.
        if (centre < fold && centre + pitch / 2 > fold) return call;
      }
      fail('no row is cut by the fold — the board is too short to test a reveal');
    }

    testWidgets('sliding the row the fold cuts leaves the list where it is', (tester) async {
      final services = await servicesWith(_board(20));
      Map<String, dynamic>? suggested;
      final setCall = await pumpPanel(
        tester,
        services: services,
        visible: ValueNotifier(true),
        onSuggestQso: (qso, {bool reveal = true}) => suggested = qso,
        onLogQso: (_) {},
      );

      // Scrolled off a row boundary, the way a board the operator has scanned
      // sits: without this every row lands whole inside the viewport and no
      // reveal would move the list even with the suppression taken out.
      final controller = tester.widget<CustomScrollView>(spotsList).controller!;
      controller.jumpTo(25);
      await tester.pump();

      final call = callCutByTheFold(tester, 20);
      final gesture = await tester.startGesture(tester.getCenter(find.text(call)));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }
      expect(suggested?['their'], {'call': call}, reason: 'the peek filled the fields');

      // What the operation view does with that suggestion: the call comes
      // straight back down as the current QSO. The finger is still on the row.
      await setCall(_entering(call));

      expect(offsetOf(tester), 25, reason: 'the row may not be scrolled out from under the finger');

      await gesture.up();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(offsetOf(tester), 25, reason: 'nor once the row comes to rest open with the call still in the fields');

      // Dragged back shut, with the call left in the fields — what a peek the
      // operator typed over leaves behind, since the withdrawal declines to
      // take back an entry that is no longer the peek's own. This is what the
      // LATCH buys over simply skipping the scroll: skipping would let the
      // very next build arm the call afresh and scroll to it a moment after
      // the gesture ended, which is the yank arriving late rather than not at
      // all.
      final back = await tester.startGesture(tester.getCenter(find.text(call)));
      for (var i = 0; i < 10; i++) {
        await back.moveBy(const Offset(-12, 0));
        await tester.pump();
      }
      await back.up();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // The rebuild matters: the row closing does not rebuild the PANEL, so
      // without one nothing re-arms and even an un-latched call sits still.
      // The board polls, so a rebuild always comes — here it is a fresh
      // callInfo carrying the same call, which is what the operation view
      // pushes down on every one of its own rebuilds.
      await setCall(_entering(call));

      expect(offsetOf(tester), 25, reason: 'and not once the row has closed either');
    });

    testWidgets('a call the open row did not put there is still revealed', (tester) async {
      final services = await servicesWith(_board(20));
      final setCall = await pumpPanel(tester, services: services, visible: ValueNotifier(true), onSuggestQso: (qso, {bool reveal = true}) {}, onLogQso: (_) {});

      final gesture = await tester.startGesture(tester.getCenter(find.text('K0001')));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
      }

      // Typing a call closes open rows — but only AFTER the frame, and the
      // build carrying the typed call runs first. Suppressing on "some row is
      // open" would latch this call while the row was still registered and
      // retire it for good: the operator types a spotted call and the list
      // never goes to it, then or ever.
      await setCall(_entering('K0015'));

      expect(offsetOf(tester), greaterThan(0), reason: 'a call that is nobody\'s peek still reveals');
      expect(find.text('K0015').hitTestable(), findsOneWidget);

      await gesture.up();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
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

      expect(
        offsetOf(tester),
        greaterThan(0),
        reason:
            'the reveal owed from while it was hidden never ran; K0050 built: '
            '${find.text('K0050').evaluate().isNotEmpty}',
      );
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
              child: SpotsPanel(operation: operation, services: services, logRevision: 'r1', visible: ValueNotifier(true), callInfo: callInfo),
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
              child: SpotsPanel(operation: operation, services: services, logRevision: 'r1', visible: ValueNotifier(true), callInfo: callInfo),
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
      tester.widget<CustomScrollView>(spotsList).controller!.jumpTo(0);
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
