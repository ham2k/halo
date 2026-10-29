// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Rotator pane turns an antenna by headings measured from its centre,
// so what it says about the rotator and about where it is centred has to be
// true: a heading the controller has stopped confirming is not a heading,
// and a centre the operator did not ask for is a wrong bearing to every
// station on the map.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/views/operation/rotator/rotator_map.dart';
import 'package:ham2k_logger/views/operation/rotator/rotator_panel.dart';

import '../support/fake_gs232_line.dart';
import '../support/halo_harness.dart';

void main() {
  final p = t.operation.layout.panels;
  final home = gridToLocation('FN31pr')!;

  group('the map\'s centre', () {
    test('is the operation\'s when the pane names none', () {
      expect(rotatorPanelHome(null, home), (home: home, unreadable: false));
      expect(rotatorPanelHome('  ', home), (home: home, unreadable: false));
    });

    test('is the pane\'s own, as a grid or a latitude and longitude', () {
      expect(rotatorPanelHome('IO91wm', home).home, gridToLocation('IO91wm'));
      expect(rotatorPanelHome('51.5, -0.1', home).home, const GridLocation(51.5, -0.1));
    });

    // Falling back to the operation's grid here draws a perfectly good map
    // somewhere else, and every tap turns the antenna by a bearing from it.
    test('is no centre at all when the pane names one it cannot read', () {
      expect(rotatorPanelHome('FN3', home), (home: null, unreadable: true));
      expect(rotatorPanelHome('91, 0', home), (home: null, unreadable: true));
    });
  });

  group('the pane over a connected rotator', () {
    late FakeGs232Line line;
    late CatService cat;
    late HaLoServices services;
    late String uuid;

    Future<void> pumpPane(WidgetTester tester) async {
      line = FakeGs232Line();
      final harness = await makeHaLoServices(cat: (settings) => cat = line.catService(settings, staleAfter: const Duration(milliseconds: 300)));
      services = harness.services;
      addTearDown(cat.dispose);
      // Real time for the CAT layer's own awaits, which the test's fake clock
      // never runs.
      await tester.runAsync(() async {
        uuid = (await cat.addNode(typeKey: fakeGs232TypeKey, name: 'Tower')).uuid;
        await cat.connect(uuid);
      });
      await tester.runAsync(
        () => tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  height: 400,
                  child: RotatorPanel(panelId: 'rotator#1', services: services, operationLocation: home),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> settle(WidgetTester tester, {int ms = 50}) async {
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
      await tester.pump();
    }

    // The silence watch marks the node stale, and nothing ever drops a
    // rotator that went quiet: shown as live, the last heading stays on the
    // map for good, and a tap sends a turn to a controller not answering.
    testWidgets('a rotator that stops answering is not responding, and a tap turns nothing', (tester) async {
      await pumpPane(tester);
      line.say('+0123\r\n');
      await settle(tester);
      expect(find.text('123°'), findsOneWidget);

      await settle(tester, ms: 400);
      expect(find.text(p.rotatorNotResponding), findsOneWidget);
      expect(find.text('123°'), findsNothing);
      line.sent.clear();
      await tester.tapAt(tester.getCenter(find.byType(RotatorMap)) + const Offset(80, 0));
      expect(line.sent.where((command) => command.startsWith('M')), isEmpty);
    });

    // The driver's refusal problem names the cause — the controller is in
    // another mode — and is the only thing that does.
    testWidgets('a controller refusing every poll says why on the pane', (tester) async {
      await pumpPane(tester);
      line.say('?>\r\n');
      await settle(tester);
      expect(find.text(t.settings.station.rotatorRefused), findsOneWidget);
    });
  });
}
