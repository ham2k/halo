// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The spots list's layout when the board changes under a scrolled list.
//
// pumpAndSettle is deliberately absent: the age labels ride the shared
// once-per-second WallClock, so a settle loop never finds the list idle.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_extension_host.dart' show LookupCallsOneByOne;

/// Serves whatever [board] holds at the moment the panel fetches.
class _FakeExtensions extends ExtensionService with LookupCallsOneByOne {
  List<Map<String, dynamic>> board = const [];

  @override
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> getSpots() async =>
      (items: board, succeeded: const ['test'], unreachable: const <String>[], failed: const <String>[]);

  @override
  Future<Map<String, String>> getSpotSourceNames() async => const {'test': 'Test Source'};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A section list that ends up below the viewport, still holding rows from
  // deep in its content, walks back to its first row when it is next laid out.
  // When the rows it rebuilds on the way are taller than the ones it measured
  // before, the walk comes up short and the list asks the viewport for a
  // scroll correction — and a list below the viewport is handed the same
  // constraints on the retry, so the framework reuses its answer instead of
  // laying it out again. The viewport retries to its cycle limit, which a
  // release build passes silently and then paints a half-laid-out list, every
  // frame after, as a null-check in RenderSliverMultiBoxAdaptor.paint.
  testWidgets('rows growing in a section scrolled out of view leave the list laid out', (tester) async {
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    await settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', 'sortBy': 'frequency', 'groupByBand': true, 'groupCallsWithNotes': false});
    final operation = await OperationsRepository(db).create(stationCall: 'N0CALL', userTitle: 'Test Op');
    final extensions = _FakeExtensions();
    final services = HaLoServices(db, settings, extensions: extensions);

    final spottedAt = nowMillis() - 60000;
    Map<String, dynamic> spot(String call, String band, double freq, {String? label}) => {
      'their': {'call': call},
      'freq': freq,
      'band': band,
      'mode': 'SSB',
      'refs': const <Map<String, dynamic>>[],
      'spot': {'timeInMillis': spottedAt, 'source': 'test', 'label': ?label},
      'hookKey': 'test',
    };
    List<Map<String, dynamic>> board({required bool labelled}) => [
      for (var i = 0; i < 40; i++) spot('K${i}AA', '40m', 7000.0 + i),
      // The same 20m stations both times, so every row keeps its place and its
      // key — only the leading rows' heights change, as a reference label
      // arriving on a later poll does.
      for (var i = 0; i < 40; i++) spot('W${i}BB', '20m', 14000.0 + i, label: labelled && i < 20 ? 'US-0001 Somewhere National Park' : null),
    ];

    extensions.board = board(labelled: false);
    tester.view.physicalSize = const Size(500, 600);
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
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final controller = tester.widget<CustomScrollView>(find.descendant(of: find.byType(SpotsPanel), matching: find.byType(CustomScrollView))).controller!;
    // Deep into the 20m section, so its list holds only rows from its middle.
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('W39BB'), findsOneWidget, reason: 'the setup has to have scrolled the 20m rows into view');
    expect(find.text('W0BB'), findsNothing, reason: 'the 20m list must be holding only rows past the ones that grow');

    extensions.board = board(labelled: true);
    await services.spots.refresh();
    // Back to the top in the same frame the taller rows land, so the 20m list
    // is next laid out entirely below the viewport.
    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('K0AA'), findsOneWidget);
    // Inside the cache extent the 20m list's constraints would move with each
    // correction and the stock list would converge, fix or no fix.
    expect(find.text('K39AA'), findsNothing, reason: 'the 40m section must run past the cache extent, leaving the 20m one beyond it');
  });
}
