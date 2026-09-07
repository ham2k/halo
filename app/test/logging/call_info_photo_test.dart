// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The call-info photo (HALO-361). Two things it must never do again: vanish
// without a word when the load fails — a 404, a blocked request and a
// callsign with no photo all rendered as the same nothing — and offer no way
// to see the picture at any size larger than the header thumbnail.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/operation/call_info_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> buildServices() async {
    return (await makeHaLoServices()).services;
  }

  /// Every image load fails under the test binding — which is exactly the case
  /// under test: without the placeholder below, this renders as no photo at
  /// all and the test could not tell the two apart either.
  Future<void> pumpPanel(WidgetTester tester, HaLoServices services, {String? image}) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: CallInfoPanel(
            operation: const Operation(uuid: 'op-1', data: {'grid': 'FN31pr'}),
            services: services,
            call: 'W1AW',
            guess: {'image': ?image},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a photo that will not load says so, instead of rendering as no photo at all', (tester) async {
    await pumpPanel(tester, await buildServices(), image: 'https://example.test/w1aw.jpg');

    expect(find.text('Photo unavailable'), findsOneWidget);
  });

  testWidgets('a callsign with no photo shows no photo slot at all', (tester) async {
    // The other half of the pair: "unavailable" must mean a load that failed,
    // not simply a guess that carried no image — otherwise the placeholder is
    // as uninformative as the blank it replaced.
    await pumpPanel(tester, await buildServices());

    expect(find.text('Photo unavailable'), findsNothing);
  });

  testWidgets('a photo that failed to load is not a tap target', (tester) async {
    // There is nothing to enlarge, and a viewer holding a full-window copy of
    // "Photo unavailable" — with its own close button — is a dead end.
    await pumpPanel(tester, await buildServices(), image: 'https://example.test/w1aw.jpg');

    await tester.tap(find.text('Photo unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Photo unavailable'), findsOneWidget, reason: 'the thumbnail only, with no viewer over it');
  });

  testWidgets('the thumbnail opens the viewer while the photo is still loading', (tester) async {
    // The load never completes under the test binding, which is the state
    // between "asked for" and "failed" — the tap must work there, since that
    // is also what a slow photo on a real device looks like. Pumped without
    // settling so the error state has not landed yet.
    final services = await buildServices();
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: CallInfoPanel(
            operation: const Operation(uuid: 'op-1', data: {'grid': 'FN31pr'}),
            services: services,
            call: 'W1AW',
            guess: const {'image': 'https://example.test/w1aw.jpg'},
          ),
        ),
      ),
    ));
    await tester.pump();

    final thumbnail = find.byType(InkWell);
    expect(tester.widget<InkWell>(thumbnail.first).onTap, isNotNull);
  });
}
