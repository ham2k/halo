// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-17: the Add Reference suggestion list hardcoded "km" regardless of
// the user's Distance Unit preference. Pin both units so a regression to
// the hardcoded string breaks a test, not just a bug report.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/tools/distance_format.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // suggestActivities() needs a live extension host (FakeExtensionHost yields
  // empty controls/suggestions here — see activities_disabled_extension_test),
  // so instead of mocking the search, we add a ref with a distance and remove
  // it: _deleteRef resurfaces the exact same map as a Suggestion, which drives
  // the same distance Text() this bug is in.
  Future<void> pumpSuggestionList(WidgetTester tester, SettingsService settings) async {
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final operation = Operation(
      uuid: 'op-123',
      data: const {
        'refs': [
          {'type': 'pota', 'ref': 'US-1234', 'name': 'Test Park', 'distance': 100},
        ],
      },
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: OperationSheet(services: services, operation: operation),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Remove'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the suggestion distance in miles when that is the preference', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setDistanceUnits(DistanceUnits.miles);

    await pumpSuggestionList(tester, settings);

    expect(find.text(fmtDistance(100, miles: true)), findsOneWidget);
    expect(find.text(fmtDistance(100, miles: false)), findsNothing);
  });

  testWidgets('shows the suggestion distance in kilometers when that is the preference', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setDistanceUnits(DistanceUnits.kilometers);

    await pumpSuggestionList(tester, settings);

    expect(find.text(fmtDistance(100, miles: false)), findsOneWidget);
    expect(find.text(fmtDistance(100, miles: true)), findsNothing);
  });
}
