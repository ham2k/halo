// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The last mile of the POWER command (typing "5W" into the call field or a
// quick-lookup bar) — the seam between `handleCommandAction` and the VFO
// write its `setPower` case makes, exercised the way
// settings_command_dispatch_test.dart exercises SET/SHOW.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/views/home_view.dart';

import '../support/halo_test_support.dart';

/// Returns the POWER command's interpretation for "5W" — the real hook's
/// shape, without booting a JS engine.
class _PowerCommandExtensions extends ExtensionService {
  @override
  bool get ready => true;

  @override
  Future<void> start() async {}

  @override
  Future<Map<String, dynamic>?> interpretCommand(
    String input, [
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    bool execute = false,
  ]) async {
    if (input.trim().toUpperCase() != '5W') return null;
    return {
      'describe': 'Change power to **5W**?',
      'confirm': 'Power set to **5W**',
      'commands': [
        {
          'setPower': {'watts': 5},
        },
      ],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> buildServices() async {
    return (await makeHaLoServices(extensions: _PowerCommandExtensions())).services;
  }

  testWidgets('Enter on a wattage command writes the power to the VFO', (tester) async {
    final services = await buildServices();
    expect(services.radio.vfoA.power, isNull);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(body: HomeQuickLookup(services: services)),
      ),
    ));

    final field = find.byType(TextField);
    await tester.enterText(field, '5W');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The VFO's own persist debounce, which would otherwise outlive the
    // widget tree and fail the test on a pending timer.
    await tester.runAsync(services.radio.flushPendingWrites);

    expect(services.radio.vfoA.power, 5,
        reason: 'the VFO is where every power surface reads it from; a connected radio '
            'hears about it from there, through CatService');
    expect(services.cat.displayedPower, 5,
        reason: 'no radio is connected in this test, so the VFO is what the app displays');
  });
}
