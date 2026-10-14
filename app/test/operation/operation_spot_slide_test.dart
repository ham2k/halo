// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The spot slide across the WHOLE operation view, rather than the panel on its
// own. Everything the gesture promises is a round trip — the peek fills the
// logging fields, closing the row empties them again, a tap or a keystroke in
// those fields closes the row — and each leg goes through a different widget.
// A panel-level test holds one end of every one of those and fakes the other,
// which is exactly where a break hides: both halves pass their own tests and
// the app does none of it.

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
import 'package:ham2k_logger/views/operation_view.dart';

class _FakeExtensions extends ExtensionService {
  _FakeExtensions(this.board);

  final List<Map<String, dynamic>> board;

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
    String? streakKey,
  }) async => null;
}

Map<String, dynamic> _spot(String call, {double freq = 14250.0}) => {
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
  late SettingsService settings;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    // The logging fields and the spots list side by side — the arrangement the
    // gesture is designed against, and the only one where both ends of every
    // round trip in this file are on screen at once.
    await settings.setLayoutData(
      LayoutKeys.operationDock,
      DockSplit(
        Axis.horizontal,
        [
          DockGroup(['logging']),
          DockGroup(['spots']),
        ],
        [2, 1],
      ).toJson(),
    );
    await settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', 'sortBy': 'frequency', 'groupByBand': true});
  });

  tearDown(() async => db.close());

  Future<void> pumpOperation(WidgetTester tester) async {
    // Wide enough for the two-pane arrangement, where the logging fields and
    // the spots list are on screen at the same time — the layout the gesture
    // was designed against.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final services = HaLoServices(db, settings, extensions: _FakeExtensions([_spot('K1ABC'), _spot('W2DEF', freq: 14260.0)]));
    final operation = await services.operations.create(stationCall: 'N0CALL');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  /// [call]'s row IN THE SPOTS LIST. Scoped, because once the fields hold that
  /// station the logging panel shows the same text — an unscoped finder starts
  /// matching two widgets the moment the gesture works.
  Finder rowFor(String call) => find.descendant(of: find.byType(SpotsPanel), matching: find.text(call));

  /// Drags [call]'s row right far enough to rest open, and releases.
  Future<void> slideOpen(WidgetTester tester, String call) async {
    final gesture = await tester.startGesture(tester.getCenter(rowFor(call)));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(12, 0));
      await tester.pump();
    }
    await gesture.up();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String callField(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Their call').first).controller?.text ?? '';

  /// Open rows, counted by the action icon each one reveals — scoped to the
  /// spots list, because the logging panel's own submit button carries the
  /// very same glyph (deliberately: the gesture ends in the act that button
  /// performs), and counting it makes an empty list look like an open row.
  int openRows(WidgetTester tester) => tester.widgetList(find.descendant(of: find.byType(SpotsPanel), matching: find.byIcon(MdiIcons.upload))).length;

  testWidgets('a peek fills the logging fields', (tester) async {
    await pumpOperation(tester);
    await slideOpen(tester, 'K1ABC');

    expect(callField(tester), 'K1ABC');
    expect(openRows(tester), 1);

    await unmount(tester);
  });

  testWidgets('sliding another row closes the first and hands the fields over', (tester) async {
    await pumpOperation(tester);
    await slideOpen(tester, 'K1ABC');
    await slideOpen(tester, 'W2DEF');

    expect(openRows(tester), 1, reason: 'only one row is ever open');
    expect(callField(tester), 'W2DEF');

    await unmount(tester);
  });

  testWidgets('tapping a spot closes the open row', (tester) async {
    await pumpOperation(tester);
    await slideOpen(tester, 'K1ABC');
    await tester.tap(rowFor('W2DEF'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(openRows(tester), 0);
    expect(callField(tester), 'W2DEF');

    await unmount(tester);
  });

  testWidgets('typing in the call field closes the open row', (tester) async {
    await pumpOperation(tester);
    await slideOpen(tester, 'K1ABC');
    await tester.enterText(find.widgetWithText(TextField, 'Their call').first, 'W9XYZ');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(openRows(tester), 0);
    expect(callField(tester), 'W9XYZ', reason: 'and what they typed stands');

    await unmount(tester);
  });

  testWidgets('dragging the row back empties the fields again', (tester) async {
    await pumpOperation(tester);
    await slideOpen(tester, 'K1ABC');
    expect(callField(tester), 'K1ABC');

    // Drag the open row back shut.
    final gesture = await tester.startGesture(tester.getCenter(rowFor('K1ABC')));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-12, 0));
      await tester.pump();
    }
    await gesture.up();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(callField(tester), isEmpty);

    await unmount(tester);
  });
}
