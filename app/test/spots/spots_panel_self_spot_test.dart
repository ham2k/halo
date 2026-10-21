// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The pinned self-spot row: our own station's spot sits above the board, and
// tapping it re-tunes the VFO to the spotted frequency instead of suggesting
// a QSO — there is no one to work on that row, and offering the operator
// their own callsign as a contact would log nonsense one tap later.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

/// Serves a fixed board instead of reaching for the extension runtime, same
/// shape as spots_panel_reveal_test.dart's fake.
class _FakeExtensions extends ExtensionService {
  _FakeExtensions(this.board, {this.controls = const []});

  final List<Map<String, dynamic>> board;
  final List<Map<String, dynamic>> controls;

  @override
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> getSpots() async => (
    items: board,
    succeeded: board.map((s) => s['hookKey'] as String? ?? 'unknown').toSet().toList(),
    unreachable: const <String>[],
    failed: const <String>[],
  );

  @override
  Future<Map<String, String>> getSpotSourceNames() async => const {'test': 'Test Source'};

  // The panel awaits the runtime boot before asking for controls; the real
  // one never resolves under test, so without this no row ever sees a control.
  @override
  Future<void> start() async {}

  @override
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async => (controls: controls, loadFailed: false);

  // Every call one entity: the second merge pass joins calls only once their
  // entities are known and agree.
  @override
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
    bool recentContext = false,
    String? streakKey,
  }) async => {
    'guess': {'entityPrefix': 'K'},
  };
}

Map<String, dynamic> _spot(String call, {String band = '20m', double freq = 14250.0, int? timeInMillis, List<Map<String, dynamic>> refs = const []}) => {
  'their': {'call': call},
  'freq': freq,
  'band': band,
  'mode': 'SSB',
  'refs': refs,
  'spot': {'timeInMillis': timeInMillis ?? nowMillis() - 60000, 'source': 'test'},
  'hookKey': 'test',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late SettingsService settings;
  late Operation operation;

  Future<HaLoServices> servicesWith(List<Map<String, dynamic>> spots, {List<Map<String, dynamic>> controls = const []}) async {
    // Pinned wide open so the board itself is never narrowed by the radio's
    // band or mode — which filters the self pin ignores is asserted per test
    // by narrowing them back down.
    await settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', 'sortBy': 'frequency', 'groupByBand': true});
    return HaLoServices(db, settings, extensions: _FakeExtensions(spots, controls: controls));
  }

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    operation = await OperationsRepository(db).create(stationCall: 'N0CALL', userTitle: 'Test Op');
  });

  tearDown(() async => db.close());

  /// Mounts the panel and lets the spot fetch and note lookups land. No
  /// pumpAndSettle — the age labels ride the shared once-per-second WallClock,
  /// so a settle loop always finds another scheduled frame.
  Future<void> pumpPanel(
    WidgetTester tester, {
    required HaLoServices services,
    void Function(Map<String, dynamic> qso, {bool reveal})? onSuggestQso,
    ValueChanged<Map<String, dynamic>>? onLogQso,
  }) async {
    tester.view.physicalSize = const Size(500, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          home: Scaffold(
            body: SpotsPanel(
              operation: operation,
              services: services,
              logRevision: 'r1',
              visible: ValueNotifier(true),
              onSuggestQso: onSuggestQso,
              onLogQso: onLogQso,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('our own spot is pinned above the board and taps re-tune instead of suggesting', (tester) async {
    final services = await servicesWith([_spot('K1ABC', freq: 14050.0), _spot('N0CALL', freq: 14285.0)]);
    final suggested = <Map<String, dynamic>>[];
    await pumpPanel(tester, services: services, onSuggestQso: (qso, {reveal = true}) => suggested.add(qso));

    // Pinned as its own leading section, AND still present in its band
    // section below — a duplicate, like the Calls of Note pin.
    expect(find.text('Your Spots - 1 spot'), findsOneWidget);
    expect(find.text('N0CALL'), findsNWidgets(2));

    // The operator has wandered off to hunt: another band, another mode.
    // The trap is a retune that brings back only part of the VFO state.
    services.radio.setVfo('vfoA', freq: 7025.0, mode: 'CW');
    await tester.pump();

    // Tapping the pinned copy must not offer our own station as a contact;
    // it puts the VFO back where — and how — the spot announced us.
    await tester.tap(find.text('N0CALL').first);
    await tester.pump();
    expect(suggested, isEmpty);
    expect(services.radio.vfoA.freq, 14285.0);
    // The spot says 'SSB'; 20m runs upper. Nothing downstream of the VFO
    // should have to work that out a second time.
    expect(services.radio.vfoA.mode, 'USB');

    // Any other spot still suggests a QSO and leaves the VFO alone — the
    // mutation this guards is the isSelf branch leaking onto every row.
    await tester.tap(find.text('K1ABC'));
    await tester.pump();
    expect(suggested, hasLength(1));
    expect((suggested.single['their'] as Map)['call'], 'K1ABC');
    expect(services.radio.vfoA.freq, 14285.0);
    expect(services.radio.vfoA.mode, 'USB');

    // The re-tune schedules a debounced prefs write; flush it so no timer
    // outlives the test.
    await services.radio.flushPendingWrites();
  });

  testWidgets('sliding a self row right cannot log our own station', (tester) async {
    final services = await servicesWith([_spot('K1ABC', freq: 14050.0), _spot('N0CALL', freq: 14285.0)]);
    final suggested = <Map<String, dynamic>>[];
    final logged = <Map<String, dynamic>>[];
    await pumpPanel(tester, services: services, onSuggestQso: (qso, {reveal = true}) => suggested.add(qso), onLogQso: logged.add);

    /// Same drag as spots_panel_reveal_test.dart's slide helper: in steps,
    /// because the commit threshold is watched per drag frame.
    Future<void> slide(String call, double dx) async {
      final gesture = await tester.startGesture(tester.getCenter(find.text(call).first));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(dx / 10, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    // A drag past half the row logs an ordinary spot on release — that is
    // the mutation this test exists to catch: the log action reappearing on
    // a self row when the suppression is dropped.
    await slide('N0CALL', 400);
    expect(logged, isEmpty, reason: 'our own station is not a contact to log');
    expect(suggested, isEmpty, reason: 'a self row must not fill the logging fields either');

    await slide('K1ABC', 400);
    expect(logged, hasLength(1), reason: 'ordinary rows keep the slide-to-log');
    expect((logged.single['their'] as Map)['call'], 'K1ABC');

    await services.radio.flushPendingWrites();
  });

  testWidgets('a merged multi-op row that merely includes us keeps its QSO affordances', (tester) async {
    // Same freq, same refs, non-digital and within 10 minutes: the second
    // merge pass folds these into one 'W1XYZ,N0CALL' row. W1XYZ is a
    // workable station, so the row must NOT be pinned or claimed as self —
    // an any-of predicate here would make W1XYZ unreachable from the board.
    const park = [
      {'type': 'pota', 'ref': 'US-0001'},
    ];
    final services = await servicesWith([
      _spot('N0CALL', freq: 14285.0, timeInMillis: nowMillis() - 120000, refs: park),
      _spot('W1XYZ', freq: 14285.0, timeInMillis: nowMillis() - 60000, refs: park),
    ]);
    final suggested = <Map<String, dynamic>>[];
    await pumpPanel(tester, services: services, onSuggestQso: (qso, {reveal = true}) => suggested.add(qso));

    expect(find.textContaining('Your Spots'), findsNothing);

    await tester.tap(find.text('W1XYZ,N0CALL'));
    await tester.pump();
    expect(suggested, hasLength(1), reason: 'tapping still offers the merged stations as a QSO');
    expect(services.radio.vfoA.freq, isNull, reason: 'no self re-tune on a shared row');
  });

  // The panel must hand EVERY station call to the self check, by base call:
  // taking only the first call, or matching exactly, leaves W1AW/P on the
  // board as a contact to log — the operation logging itself.
  testWidgets('a spot of any station call, under any suffix, is pinned as ours', (tester) async {
    operation = await OperationsRepository(db).create(stationCall: 'N0CALL, W1AW', userTitle: 'Multi Op');
    final services = await servicesWith([_spot('K1ABC', freq: 14050.0), _spot('W1AW/P', freq: 14285.0)]);
    final suggested = <Map<String, dynamic>>[];
    await pumpPanel(tester, services: services, onSuggestQso: (qso, {reveal = true}) => suggested.add(qso));

    expect(find.text('Your Spots - 1 spot'), findsOneWidget);

    await tester.tap(find.text('W1AW/P').first);
    await tester.pump();
    expect(suggested, isEmpty, reason: 'our own station is not a contact to suggest');
    expect(services.radio.vfoA.freq, 14285.0);

    await services.radio.flushPendingWrites();
  });

  testWidgets('the pinned self spot survives a band filter that hides the rest of the board', (tester) async {
    // The moment the pin matters: the operator QSYed and the 'auto'/explicit
    // band filter followed them away from where they self-spotted.
    await settings.setSpottingFilters({'bandFilter': '40m', 'modeFilter': 'any', 'sortBy': 'frequency', 'groupByBand': true});
    final services = HaLoServices(db, settings, extensions: _FakeExtensions([_spot('K1ABC', freq: 14050.0), _spot('N0CALL', freq: 14285.0)]));
    await pumpPanel(tester, services: services);

    // Everything on the board is 20m, so the filter empties it — except the
    // pinned self spot, which is drawn from before any narrowing.
    expect(find.text('N0CALL'), findsOneWidget);
    expect(find.text('K1ABC'), findsNothing);
  });

  testWidgets('a reference icon takes the accent color its extension declares', (tester) async {
    final spot = _spot('K1ABC', freq: 14050.0);
    spot['refs'] = [
      // The HUNTING type, as the POTA spot source emits it — not the
      // activation type an operation's own settings would carry.
      {'type': 'pota', 'ref': 'US-0001'},
    ];
    (spot['spot'] as Map<String, dynamic>)['label'] = 'US-0001 Test Park';
    final services = await servicesWith(
      [spot],
      controls: [
        {
          'key': 'pota',
          'label': 'POTA',
          'icon': 'pine-tree',
          'color': '#068541',
          'input': {'kind': 'refList', 'refType': 'pota'},
        },
      ],
    );
    await pumpPanel(tester, services: services);

    // The icon takes the extension's color, not the row's outline grey.
    // Finding it by the control's own glyph is what proves the control was
    // loaded at all: a row that never saw it renders the generic marker.
    final icon = tester.widget<Icon>(find.byIcon(resolveIconName('pine-tree')));
    expect(icon.color, const Color(0xFF068541));
  });

  // The SDK's Spot declares `icon` at the top level only. A nested one is a
  // misplaced field; rendered anyway, it hides the misplacement from the
  // extension that made it.
  testWidgets("a spot's icon is read from the top level, never from inside `spot`", (tester) async {
    // The icon leads a row's label line, so both carry a label.
    final placed = {..._spot('K1ABC', freq: 14050.0), 'icon': 'pine-tree'};
    (placed['spot'] as Map<String, dynamic>)['label'] = 'Placed';
    final misplaced = _spot('W2XYZ', freq: 14060.0);
    (misplaced['spot'] as Map<String, dynamic>)
      ..['label'] = 'Misplaced'
      ..['icon'] = 'image-filter-hdr';
    await pumpPanel(tester, services: await servicesWith([placed, misplaced]));

    expect(find.byIcon(resolveIconName('pine-tree')), findsOneWidget);
    expect(find.byIcon(resolveIconName('image-filter-hdr')), findsNothing);
    expect(find.byIcon(resolveIconName('radio-tower')), findsOneWidget, reason: 'the misplaced one gets the generic marker');
  });
}
