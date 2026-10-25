// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spots Panel of an operation without assistance (`Operation.assistance`).
// The shared spots service still holds what an earlier operation fetched, so
// a panel that merely stopped fetching would go on showing those spots to an
// operator whose rules forbid them. It shows none, says why, and offers no
// control that would fetch or filter.

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

class _FakeExtensions extends ExtensionService {
  int fetches = 0;

  @override
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> getSpots() async {
    fetches++;
    return (items: [_spot('K1ABC')], succeeded: const ['test'], unreachable: const <String>[], failed: const <String>[]);
  }

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
  late _FakeExtensions extensions;
  late HaLoServices services;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    await settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any'});
    extensions = _FakeExtensions();
    services = HaLoServices(db, settings, extensions: extensions);
    // What an earlier operation left on the board.
    await services.spots.refresh();
    extensions.fetches = 0;
  });

  tearDown(() async => db.close());

  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpPanel(WidgetTester tester, Operation operation) async {
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

  Future<Operation> create(Map<String, dynamic> data) async {
    final created = await OperationsRepository(db).create(stationCall: 'N0CALL');
    return Operation(uuid: created.uuid, data: {...created.data, ...data});
  }

  testWidgets('shows the spots an operation that allows assistance is offered', (tester) async {
    // The control: without it, the test below would pass on a panel that
    // never shows the held spots at all.
    await pumpPanel(tester, await create(const {}));
    expect(find.text('K1ABC'), findsWidgets);
    expect(find.text(t.operation.spots.spotsDisabled), findsNothing);
    await tester.tap(find.textContaining(' • '));
    await pumpFrames(tester);
    expect(find.byType(Dialog), findsOneWidget, reason: 'what the disabled panel must not open');
  });

  for (final (label, data) in [
    ('switched off', const <String, dynamic>{'assistance': false}),
    (
      'ruled out by a ref',
      const <String, dynamic>{
        'refs': [
          {'type': 'cqww', 'assistance': false},
        ],
      },
    ),
  ]) {
    testWidgets('with assistance $label, shows no spots and says why', (tester) async {
      await pumpPanel(tester, await create(data));
      expect(find.text(t.operation.spots.spotsDisabled), findsOneWidget);
      expect(find.text('K1ABC'), findsNothing, reason: "the board's spots came from another operation");
      expect(extensions.fetches, 0, reason: 'the panel showing this operation must not set the board fetching');
    });
  }

  testWidgets('offers no filter control', (tester) async {
    await pumpPanel(tester, await create(const {'assistance': false}));
    await tester.tap(find.textContaining(' • '), warnIfMissed: false);
    await pumpFrames(tester);
    expect(find.byType(Dialog), findsNothing);
  });
}
