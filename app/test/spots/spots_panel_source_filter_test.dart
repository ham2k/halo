// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The filter dialog's Sources section lists every installed spot source, not
// only the ones with spots on the board: an idle source (QSO Party Spots
// between party weekends) must be there for the operator to turn off before
// it starts spotting.

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

/// One source on the board, plus whatever [names] says is installed — which
/// a test changes and then announces as a runtime restart.
class _FakeExtensions extends ExtensionService {
  Map<String, String> names = {'test': 'Test Source', 'qp': 'QSO Parties'};

  @override
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> getSpots() async =>
      (items: [_spot('K1ABC')], succeeded: const ['test', 'qp'], unreachable: const <String>[], failed: const <String>[]);

  @override
  Future<Map<String, String>> getSpotSourceNames() async => names;

  // `whenSettled` boots a missing runtime first; the real boot never resolves
  // under test.
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

Map<String, dynamic> _spot(String call) => {
  'their': {'call': call},
  'freq': 14250.0,
  'band': '20m',
  'mode': 'SSB',
  'refs': const <Map<String, dynamic>>[],
  'spot': {'timeInMillis': nowMillis() - 60000, 'source': 'test'},
  'hookKey': 'test',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late SettingsService settings;
  late Operation operation;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    await settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any'});
    operation = await OperationsRepository(db).create(stationCall: 'N0CALL', userTitle: 'Test Op');
  });

  tearDown(() async => db.close());

  /// No pumpAndSettle — the age labels ride the shared once-per-second
  /// WallClock, so a settle loop always finds another scheduled frame.
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpPanel(WidgetTester tester, HaLoServices services) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          home: Scaffold(
            body: SpotsPanel(operation: operation, services: services, logRevision: 'r1', visible: ValueNotifier(true)),
          ),
        ),
      ),
    );
    await pumpFrames(tester);
  }

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.textContaining(' • '));
    await pumpFrames(tester);
  }

  testWidgets('an installed source with nothing on the board still has a row', (tester) async {
    final extensions = _FakeExtensions();
    await pumpPanel(tester, HaLoServices(db, settings, extensions: extensions));
    await openFilters(tester);

    // The trap is the panel passing only the sources with spots: 'qp'
    // answered with an empty list, so nothing on the board names it.
    expect(find.text('Test Source'), findsOneWidget);
    expect(find.text('QSO Parties'), findsOneWidget);
  });

  testWidgets('a source installed while the panel is open gets a row after the runtime restarts', (tester) async {
    final extensions = _FakeExtensions()..names = {'test': 'Test Source'};
    await pumpPanel(tester, HaLoServices(db, settings, extensions: extensions));

    // Installing an extension restarts the runtime without remounting the
    // panel; names fetched only at mount would never list the new source.
    extensions.names = {'test': 'Test Source', 'qp': 'QSO Parties'};
    extensions.runtimeGeneration.value++;
    await pumpFrames(tester);
    await openFilters(tester);

    expect(find.text('QSO Parties'), findsOneWidget);
  });
}
