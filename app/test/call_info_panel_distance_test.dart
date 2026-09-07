// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-31: the full Call Info panel's distance line always said "away",
// never pointing "to" a place the way the compact call-info line does. Pin
// the "to <location>" case, its country/entity-name fallback (no callbook
// hit, just a DXCC-prefix guess), and the plain "away" fallback, so a
// regression to the old always-away phrasing breaks a test, not just a bug
// report.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/tools/distance_format.dart';
import 'package:ham2k_logger/views/operation/call_info_panel.dart';

import 'support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> buildServices() async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.setDistanceUnits(DistanceUnits.miles);
    return services;
  }

  Future<void> pumpPanel(WidgetTester tester, HaLoServices services, Map<String, dynamic>? guess) async {
    final operation = Operation(uuid: 'op-123', data: const {'grid': 'FN31pr'});
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: CallInfoPanel(operation: operation, services: services, call: 'N0CALL', guess: guess),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('points "to" the guess location when one is known', (tester) async {
    final services = await buildServices();
    // Grid-based fix, so the distance is exact (no "~"): same km this test
    // pins against fmtDistance directly, rather than a hand-computed literal.
    final km = distanceOnEarthKm(gridToLocation('EM12ax')!, gridToLocation('FN31pr')!);
    final distStr = fmtDistance(km, miles: true);

    await pumpPanel(tester, services, {'grid': 'EM12ax', 'location': 'Testville, TX'});

    expect(find.text('$distStr to Testville, TX'), findsOneWidget);
  });

  testWidgets('falls back to the country when there is no location but one is known', (tester) async {
    final services = await buildServices();
    final km = distanceOnEarthKm(gridToLocation('EM12ax')!, gridToLocation('FN31pr')!);
    final distStr = fmtDistance(km, miles: true);

    await pumpPanel(tester, services, {'grid': 'EM12ax', 'entityName': 'Germany'});

    expect(find.text('$distStr to Germany'), findsOneWidget);
  });

  testWidgets('falls back to "away" when there is no location to point to', (tester) async {
    final services = await buildServices();
    final km = distanceOnEarthKm(gridToLocation('EM12ax')!, gridToLocation('FN31pr')!);
    final distStr = fmtDistance(km, miles: true);

    await pumpPanel(tester, services, {'grid': 'EM12ax'});

    expect(find.text('$distStr away'), findsOneWidget);
    expect(find.textContaining(' to '), findsNothing);
  });
}
