// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Radio control's configured/connected/name fields follow CatService and
// the peer radio offers live, through listeners the panel attaches in
// initState and must detach in dispose.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
import 'package:ham2k_logger/views/operation/logging_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
    operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
  });

  Widget wrap(Widget child) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 800, child: child)),
    ),
  );

  LoggingPanel panel() =>
      LoggingPanel(operation: operation, services: services, qsos: const [], loggingControls: const [], onCommandAction: (action, [params]) async {});

  testWidgets('the cat listener does not outlive the panel', (tester) async {
    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump(const Duration(seconds: 5)); // drain the controls' debounce/clock timers

    // A leaked listener would call setState() on the now-disposed panel the
    // next time anything touches CatService — addNode is a real trigger,
    // not just a bare notifyListeners() a mock could paper over.
    await expectLater(() => services.cat.addNode(typeKey: 'kenwood-serial', name: 'Test Radio'), returnsNormally);
  });

  testWidgets('a radio added while mounted is reflected at once', (tester) async {
    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    LoggingControls controls() => tester.widget<LoggingControls>(find.byType(LoggingControls));
    expect(controls().radio.hasConfiguredRadio, isFalse);

    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Test Radio');
    await tester.pump();

    expect(controls().radio.hasConfiguredRadio, isTrue);
    expect(controls().radio.radioName, 'Test Radio');
  });

  testWidgets("a peer's radio is a configured radio, though this device holds no session", (tester) async {
    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    LoggingControls controls() => tester.widget<LoggingControls>(find.byType(LoggingControls));
    expect(controls().radio.hasConfiguredRadio, isFalse);

    // The role, not locality: the operator picked a rig and the logging
    // panel follows its VFO. Asking `cat.radio1 != null` here answers "is it
    // LOCAL", which reads the Radio control as unconfigured while the
    // Station dialog above it names the rig.
    await services.cat.setRadio1(const PeerRadio(PeerRadioSelection(deviceId: 'device-a', radioId: 'rig-1', deviceName: "VE1SK's iPad", radioName: 'FTDX10')));
    await tester.pump();

    expect(controls().radio.hasConfiguredRadio, isTrue);
    expect(controls().radio.radioName, 'FTDX10', reason: 'the remembered name is the only one there is while the peer is away');
    // The two are read as ONE by the chip: configured-but-not-connected is
    // its red state, so a peer that never reads connected would be a
    // permanent alarm about a radio that is working fine.
    expect(controls().radio.radioConnected, isFalse, reason: 'nobody is offering it yet');

    services.peerRemoteRadios.setOffers('device-a', "VE1SK's iPad", const [PeerRadioOffer(id: 'rig-1', name: 'FTDX10')]);
    await tester.pump();

    expect(controls().radio.radioConnected, isTrue);

    // The peer walking away is this notifier's news alone — CatService hears
    // nothing about it, so a panel listening only to CAT would keep showing
    // green for a rig that is gone.
    services.peerRemoteRadios.setOffers('device-a', "VE1SK's iPad", const []);
    await tester.pump();

    expect(controls().radio.radioConnected, isFalse);
  });
}
