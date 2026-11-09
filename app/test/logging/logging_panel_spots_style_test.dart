// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the logging panel hands its controls for spotting: a local spot only
// with the setting on AND a rig reporting the set's frequency
// (docs/design/logging-fields.md § Local spots), and a self-spot moving the
// set's operating style (§ Operating style).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/operating_style.dart';
import 'package:ham2k_logger/services/local_spots.dart';
import 'package:ham2k_logger/services/spots_service.dart' show callOfSpot;
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
import 'package:ham2k_logger/services/spotting_settings.dart';
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

  Future<LoggingControls Function()> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: LoggingPanel(
                operation: operation,
                services: services,
                qsos: const [],
                loggingControls: const [],
                onCommandAction: (action, [params]) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
    return () => tester.widget<LoggingControls>(find.byType(LoggingControls));
  }

  /// A rig reporting the set's frequency: a peer's, offered — the cheapest
  /// way to make `radio1IsLive` true without a session.
  Future<void> goLive(WidgetTester tester) async {
    await services.cat.setRadio1(const PeerRadio(PeerRadioSelection(deviceId: 'device-a', radioId: 'rig-1', deviceName: 'iPad', radioName: 'FTDX10')));
    services.peerRemoteRadios.setOffers('device-a', 'iPad', const [PeerRadioOffer(id: 'rig-1', name: 'FTDX10')]);
    await tester.pump();
  }

  const draft = {
    'their': {'call': 'W1AW'},
    'freq': 14250.0,
    'band': '20m',
    'mode': 'SSB',
  };

  List<String> localCalls() => [for (final spot in services.spots.spotsBySource[localSpotSource] ?? const <Map<String, dynamic>>[]) callOfSpot(spot) ?? '?'];

  // Without CAT the entry's frequency is the last one typed, so a spot would
  // put the station where the operator is not listening.
  testWidgets('a call entered makes a local spot only with the setting on and a live radio', (tester) async {
    final controls = await mount(tester);
    await goLive(tester);
    expect(controls().session.onDraftSpot!('k', draft), isFalse, reason: 'off by default, live radio or not');

    services.peerRemoteRadios.setOffers('device-a', 'iPad', const []);
    await services.settings.setSettingValue(SpottingSettings.group, SpottingSettings.localSpotsKey, true);
    await tester.pump();
    expect(controls().session.onDraftSpot!('k', draft), isFalse, reason: 'no radio reports the frequency');
    expect(localCalls(), isEmpty);

    await goLive(tester);
    expect(controls().session.onDraftSpot!('k', draft), isTrue);
    expect(localCalls(), ['W1AW']);
  });

  // The trap: a CAT blip mid-contact read as "no local spots" would take
  // down a station that really was there, and the log would not put it back.
  testWidgets('a radio dropping out leaves a spot standing, unmoved, until it is taken back', (tester) async {
    final controls = await mount(tester);
    await services.settings.setSettingValue(SpottingSettings.group, SpottingSettings.localSpotsKey, true);
    await goLive(tester);
    expect(controls().session.onDraftSpot!('k', draft), isTrue);

    services.peerRemoteRadios.setOffers('device-a', 'iPad', const []);
    await tester.pump();
    expect(controls().session.onDraftSpot!('k', {...draft, 'freq': 14280.0}), isTrue);
    expect(services.spots.spotsBySource[localSpotSource]!.single['freq'], 14250.0, reason: 'a typed frequency is not where the station is');

    expect(controls().session.onDraftSpot!('k', null), isFalse);
    expect(localCalls(), isEmpty);
  });

  // Band tags mark a place the operator names, not a station heard there:
  // they need the setting, not a rig.
  testWidgets('a band tag needs only the setting', (tester) async {
    AppClock.followZoneClock = true; // so the tag's expiry, pumped below, finds it expired
    addTearDown(() => AppClock.followZoneClock = false);
    final controls = await mount(tester);
    const at = {'freq': 14250.0, 'band': '20m', 'mode': 'SSB'};
    expect(controls().session.onBandTag!('QRM', at), isFalse, reason: 'local spots off');
    await services.settings.setSettingValue(SpottingSettings.group, SpottingSettings.localSpotsKey, true);
    await tester.pump();
    expect(controls().session.onBandTag!('QRM', at), isTrue);
    await tester.pump(const Duration(hours: 3));
  });

  testWidgets('a self-spot runs the set, any comment but QRT; spotting another station does not', (tester) async {
    final controls = await mount(tester);
    final sendSpot = controls().spotting.sendSpot!;
    expect(services.cat.styleOf('A'), OperatingStyle.normal, reason: 'sanity');

    await sendSpot(sources: const [], operation: operation.data, qso: draft, comment: 'CQ');
    expect(services.cat.styleOf('A'), OperatingStyle.normal, reason: 'a spot of the station worked says nothing about our style');

    await sendSpot(sources: const [], operation: operation.data, comment: 'QRX 5');
    expect(services.cat.styleOf('A'), OperatingStyle.run);

    await sendSpot(sources: const [], operation: operation.data, comment: 'QRT, 73');
    expect(services.cat.styleOf('A'), OperatingStyle.normal);
  });
}
