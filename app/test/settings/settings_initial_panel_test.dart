// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Settings opened at a panel — Station Configuration from the Radio
// control's More Settings, Sync from a notice — lands on that panel at any
// width.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/settings_view.dart';
import 'package:ham2k_logger/views/station_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> open(WidgetTester tester, Size size) async {
    final services = (await makeHaLoServices()).services;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: SettingsView(services: services, initialPanel: 'station'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The trap: a narrow screen shows a panel as a screen pushed over the
  // list, so a panel only SELECTED there is the list, not the panel asked for.
  testWidgets('on a narrow screen the panel asked for is opened, over the list', (tester) async {
    await open(tester, const Size(420, 900));
    expect(find.byType(StationPanel), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(StationPanel), findsNothing, reason: 'back is the list');
  });

  testWidgets('on a wide one it is shown beside the list', (tester) async {
    await open(tester, const Size(1280, 900));
    expect(find.byType(StationPanel), findsOneWidget);
  });
}
