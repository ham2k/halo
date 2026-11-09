// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What an assistant's marks do to the Spots Panel: a boosted spot is pinned
// among the picks and kept in its band, a note follows the label, and a
// hidden spot leaves the list with a count of what went and by whom — never
// silently, since the operator would otherwise never learn it was there.

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

import '../support/fake_extension_host.dart' show LookupCallsOneByOne;

/// Serves a fixed board instead of reaching for the extension runtime, same
/// shape as spots_panel_reveal_test.dart's fake.
class _FakeExtensions extends ExtensionService with LookupCallsOneByOne {
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

  testWidgets('a boosted spot is pinned among the picks with its note; a hidden one is counted, and shown at a tap', (tester) async {
    final services = await servicesWith([_spot('K1ABC', freq: 14050.0), _spot('W2XYZ', freq: 14250.0), _spot('VE3AAA', freq: 14300.0)]);
    await pumpPanel(tester, services: services);
    expect(find.text('W2XYZ'), findsOneWidget);

    final marks = services.extensions.spotMarks;
    marks.mark('k1abc-coach', ['test|W2XYZ|20m|SSB'], (icon: 'star', color: null, note: 'needed for WAS', boost: 1, hidden: false));
    marks.mark('k1abc-coach', ['test|VE3AAA|20m|SSB'], (icon: null, color: null, note: null, boost: 0, hidden: true));
    await tester.pump();

    expect(find.text('Assistant Picks - 1 spot'), findsOneWidget);
    expect(find.text('W2XYZ'), findsNWidgets(2), reason: 'pinned, and still in its band');
    expect(find.textContaining('needed for WAS'), findsNWidgets(2));
    expect(find.text('VE3AAA'), findsNothing);
    expect(find.text('1 spot hidden by k1abc-coach'), findsOneWidget);

    await tester.tap(find.text('Show'));
    await tester.pump();
    expect(find.text('VE3AAA'), findsOneWidget);

    // A spot with no label still shows the icon an assistant gave it: the
    // icons sit on the label's line, and a line drawn only for a label would
    // leave an icon-only mark invisible.
    marks.mark('k1abc-coach', ['test|K1ABC|20m|SSB'], (icon: 'flag-checkered', color: null, note: null, boost: 0, hidden: false));
    await tester.pump();
    expect(find.byIcon(resolveIconName('flag-checkered')), findsOneWidget);

    marks.forget();
    await tester.pump();
    expect(find.text('Assistant Picks - 1 spot'), findsNothing);
    expect(find.textContaining('hidden by'), findsNothing, reason: 'nothing hidden, nothing to count');

    // "Show" answered the bar that went with the last hidden spot: what an
    // assistant hides after that is hidden until the operator asks again.
    marks.mark('k1abc-coach', ['test|VE3AAA|20m|SSB'], (icon: null, color: null, note: null, boost: 0, hidden: true));
    await tester.pump();
    expect(find.text('VE3AAA'), findsNothing);
    expect(find.text('Show'), findsOneWidget);
  });
}
