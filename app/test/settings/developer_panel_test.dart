// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Settings → Developer → Extension Dev Server: the address is typed in a
// dialog. The traps: an address typed and then dismissed — Escape or a tap
// outside, not Done — being thrown away, so the author retypes it on every
// visit; and Connect being offered with nothing to connect to.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/settings/developer_panel.dart';

import '../support/halo_test_support.dart';

Future<HaLoServices> _services() async {
  final services = (await makeHaLoServices(extensions: ExtensionServiceWithFakeHost(FakeExtensionHost(const {})))).services;
  await services.settings.setDeveloperMode(true);
  return services;
}

Future<void> _openDialog(WidgetTester tester, HaLoServices services) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(body: DeveloperPanel(services: services)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Server address'));
  await tester.pumpAndSettle();
}

Finder get _addressField => find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));

Finder get _connect => find.widgetWithText(FilledButton, 'Connect');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the Extension Dev Server dialog', () {
    testWidgets('keeps an address typed and dismissed without connecting, and the row shows it', (tester) async {
      final services = await _services();
      await _openDialog(tester, services);

      await tester.enterText(_addressField, '10.0.0.5:8787');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(services.settings.extensionDevServerUrl, '10.0.0.5:8787');
      expect(find.text('10.0.0.5:8787\nNot connected'), findsOneWidget);
    });

    testWidgets('offers Connect only once there is an address', (tester) async {
      final services = await _services();
      await _openDialog(tester, services);

      expect(tester.widget<FilledButton>(_connect).onPressed, isNull);
      await tester.enterText(_addressField, '10.0.0.5:8787');
      await tester.pump();
      expect(tester.widget<FilledButton>(_connect).onPressed, isNotNull);
      await tester.enterText(_addressField, '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(_connect).onPressed, isNull);
    });
  });
}
