// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The GPS row under Current Configuration (docs/design/cat.md § GPS
// receivers): a radio row's shape, for where the station's position comes
// from.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/views/station_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    services = (await makeHaLoServices()).services;
  });

  Widget wrap(Widget child) => TranslationProvider(
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets('a station with a receiver shows it, and its tiles paint their ink', (tester) async {
    // No host: unconfigured, so nothing dials out of the test.
    await services.cat.addNode(typeKey: 'nmea-gps-tcp', name: 'Phone GPS');
    await tester.pumpWidget(wrap(StationPanel(services: services)));
    await tester.pumpAndSettle();

    // On a plain coloured box, the row's tiles assert that their ink and
    // hover cannot show — a debug error on every build of the panel.
    expect(tester.takeException(), isNull);
    expect(find.byIcon(MdiIcons.crosshairsGps), findsWidgets);
    expect(find.text('Phone GPS'), findsWidgets);
  });

  testWidgets('picking the operating system names it in the row', (tester) async {
    await services.cat.addNode(typeKey: 'nmea-gps-tcp', name: 'Phone GPS');
    await services.cat.setGpsSource(null);
    await tester.pumpWidget(wrap(StationPanel(services: services)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The test host is neither Windows, macOS nor Linux to the framework.
    expect(find.text('Device Location'), findsOneWidget);
  });

  testWidgets('a station without a receiver has no GPS row', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services)));
    await tester.pumpAndSettle();
    expect(find.byIcon(MdiIcons.crosshairsGps), findsNothing);
  });
}
