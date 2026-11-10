// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Rotator pane turns an antenna by headings measured from its centre,
// so what it says about the rotator and about where it is centred has to be
// true: a heading the controller has stopped confirming is not a heading,
// and a centre the operator did not ask for is a wrong bearing to every
// station on the map.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/drivers/everyware_devices.dart';
import 'package:ham2k_logger/services/cat/drivers/everyware_server.dart' show everywareDeviceConfigKey;
import 'package:ham2k_logger/services/cat/equipment.dart';
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
    CatService? cat;
    late HaLoServices services;
    late String uuid;

    /// Connected on the test's own clock, the rotator's poll and its
    /// silence watch are fake timers that [WidgetTester.pump] moves: on
    /// real ones, a loaded machine stretches the wait for a reading past
    /// the watch, and the pane never sees the node live. Disposed inside
    /// the body, since the harness checks for a pending timer before any
    /// tearDown runs; the teardown that stops the poll resumes from a
    /// subscription cancel that completes on the real event loop.
    void paneTest(String description, Future<void> Function(WidgetTester tester) body) => testWidgets(description, (tester) async {
      cat = null;
      try {
        await body(tester);
      } finally {
        // Only a service this test built: disposing another, or none, would
        // throw here and replace whatever failed in the body.
        if (cat case final built?) {
          built.dispose();
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
      }
    });

    Future<void> pumpPane(WidgetTester tester) async {
      line = FakeGs232Line();
      late final CatService built;
      final harness = await makeHaLoServices(cat: (settings) => cat = built = line.catService(settings));
      services = harness.services;
      uuid = (await built.addNode(typeKey: fakeGs232TypeKey, name: 'Tower')).uuid;
      unawaited(built.connect(uuid));
      await tester.pumpWidget(
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
      );
      expect(built.stateFor(uuid).status, EquipmentStatus.connected);
    }

    /// The controller's answer, and the pane redrawn with it.
    Future<void> hear(WidgetTester tester, String text) async {
      line.say(text);
      await tester.pump();
      await tester.pump();
    }

    // The silence watch marks the node stale, and nothing ever drops a
    // rotator that went quiet: shown as live, the last heading stays on the
    // map for good, and a tap sends a turn to a controller not answering.
    paneTest('a rotator that stops answering is not responding, and a tap turns nothing', (tester) async {
      await pumpPane(tester);
      await hear(tester, '+0123\r\n');
      expect(find.text('123°'), findsOneWidget);
      expect(find.text(p.rotatorNotResponding), findsNothing);
      final east = tester.getCenter(find.byType(RotatorMap)) + const Offset(80, 0);
      line.sent.clear();
      await tester.tapAt(east);
      expect(line.sent.where((command) => command.startsWith('M')), isNotEmpty, reason: 'live, the same tap turns the rotator');

      await tester.pump(catStaleAfter + const Duration(seconds: 1));
      expect(find.text(p.rotatorNotResponding), findsOneWidget);
      expect(find.text('123°'), findsNothing);
      line.sent.clear();
      await tester.tapAt(east);
      expect(line.sent.where((command) => command.startsWith('M')), isEmpty);
    });

    // The driver's refusal problem names the cause — the controller is in
    // another mode — and is the only thing that does.
    paneTest('a controller refusing every poll says why on the pane', (tester) async {
      await pumpPane(tester);
      await hear(tester, '?>\r\n');
      expect(find.text(t.settings.station.rotatorRefused), findsOneWidget);
    });
  });

  // A directional switch knows its antenna's beam, which a rotator never
  // does: drawn with the pane's setting instead, a 90° 4-square shows a beam
  // a third of the width it has.
  testWidgets("an antenna that reports its own beam is drawn with it, over the pane's setting", (tester) async {
    final line = FakeGs232Line(driver: const EverywareDirectionalDriver());
    late final CatService cat;
    final harness = await makeHaLoServices(cat: (settings) => cat = line.catService(settings));
    final uuid = (await cat.addNode(typeKey: fakeGs232TypeKey, name: '4-square', config: {everywareDeviceConfigKey: '80m 4 sq'})).uuid;
    unawaited(cat.connect(uuid));
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: RotatorPanel(panelId: 'rotator#1', services: harness.services, operationLocation: home),
            ),
          ),
        ),
      ),
    );
    line.say(
      'SWITCHADD\u001F2\u001F80m 4 sq\u001FNE\u001D45\u001D90\u001Dfalse\u001FSW\u001D225\u001D90\u001Dfalse\r\n'
      'SWITCHUPDATE\u001F80m 4 sq\u001FSW\u001F0\u001F0\r\n',
    );
    await tester.pump();
    await tester.pump();
    final map = tester.widget<RotatorMap>(find.byType(RotatorMap));
    expect(map.azimuth, 225);
    expect(map.beamWidth, 90, reason: 'the pane is left at its default of $rotatorBeamWidthDefault');
    cat.dispose();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  });
}
