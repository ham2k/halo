// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spots Panel of an operation without assistance (`Operation.assistance`).
// The shared spots service still holds what an earlier operation fetched, so
// a panel that merely stopped fetching would go on showing those spots to an
// operator whose rules forbid them. It shows only the spots this station made
// itself, which no rule forbids, with the filters working on them and nothing
// on screen that would fetch.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/local_spots.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/spotting_settings.dart';
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

  /// A spot of the station's own, as the logging fields make one.
  void putLocal() => services.spots.putLocalSpot(
    'draft',
    localSpotFromQso(const {
      'their': {'call': 'W9LOC'},
      'freq': 14260.0,
      'mode': 'SSB',
    }, now: nowMillis())!,
  );

  final refreshPill = find.byIcon(resolveIconName('refresh'));

  testWidgets('shows the spots an operation that allows assistance is offered', (tester) async {
    // The control: without it, the test below would pass on a panel that
    // never shows the held spots, or never offers a refresh, at all.
    putLocal();
    await pumpPanel(tester, await create(const {}));
    expect(find.text('K1ABC'), findsWidgets);
    expect(find.text('W9LOC'), findsWidgets);
    expect(refreshPill, findsOneWidget);
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
    testWidgets("with assistance $label, shows only the station's own spots", (tester) async {
      putLocal();
      await pumpPanel(tester, await create(data));
      expect(find.text('K1ABC'), findsNothing, reason: "the board's spots came from another operation");
      expect(find.text('W9LOC'), findsWidgets, reason: 'a spot the station made itself is no assistance');
      expect(refreshPill, findsNothing, reason: 'a refresh asks the spot sources');
      expect(extensions.fetches, 0, reason: 'the panel showing this operation must not set the board fetching');
    });
  }

  testWidgets('says spots are disabled when the station has made none, and what would make some', (tester) async {
    // Never fetching, the board is never loaded, and a panel waiting for its
    // first fetch shows nothing at all rather than the empty message.
    services = HaLoServices(db, settings, extensions: extensions);
    await pumpPanel(tester, await create(const {'assistance': false}));
    expect(
      find.text(t.operation.spots.disabledLocalOff),
      findsOneWidget,
      reason: 'no filter brings in spots the operation does not ask for: only Local Spots can',
    );

    // Turned on in Settings while the panel stays up: pointing at it still
    // would send the operator to a setting already on.
    await tester.runAsync(() => settings.updateSettingsGroup(SpottingSettings.group, {SpottingSettings.localSpotsKey: true}));
    await pumpFrames(tester);
    expect(find.text(t.operation.spots.disabledNoLocal), findsOneWidget);
  });

  testWidgets("the filters still work on the station's own spots", (tester) async {
    putLocal();
    await pumpPanel(tester, await create(const {'assistance': false}));
    await tester.tap(find.textContaining(' • '));
    await pumpFrames(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text(t.operation.spots.filters.sources), findsNothing, reason: "the sources' states are from another operation's fetch");
  });

  testWidgets('pulling the list down asks no spot source', (tester) async {
    putLocal();
    await pumpPanel(tester, await create(const {'assistance': false}));
    // Shown from its state rather than dragged: a list this short does not
    // overscroll in a test, and the pull is the indicator's to recognise.
    // Not awaited: the indicator's future waits on frames only pumping brings.
    unawaited(tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(extensions.fetches, 0);
  });
}
