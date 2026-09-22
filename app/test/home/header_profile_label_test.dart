// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The active profile's callsign in the home/Settings header right corner:
// the widget shows the current callsign, hides itself when none is set, and
// tracks live changes (e.g. switching accounts) via its SettingsService
// listener — and it's actually wired into the home and Settings headers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/header_profile_label.dart';
import 'package:ham2k_logger/views/home_view.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/halo_test_support.dart';

Future<SettingsService> makeSettings(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  return SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
}

Future<void> pumpLabel(WidgetTester tester, SettingsService settings) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(actions: [HeaderProfileLabel(settings: settings)]),
      ),
    ),
  );
}

Future<HaLoServices> makeServices() async {
  final HaLoHarness(:services, :settings) = await makeHaLoServices();
  await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
  return services;
}

// Tear the tree down and drain the services' debounce timers (lookup, sync)
// so the binding's pending-timer invariant passes.
Future<void> drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

// The callsign, rendered specifically inside the header label (not some
// other KI2D elsewhere in the view).
final _callsignInHeader = find.descendant(of: find.byType(HeaderProfileLabel), matching: find.text('KI2D'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('widget', () {
    testWidgets('shows the active profile callsign', (tester) async {
      final settings = await makeSettings({'profiles': '{"default": {"operatorCall": "KI2D"}}'});
      await pumpLabel(tester, settings);
      expect(find.text('KI2D'), findsOneWidget);
    });

    testWidgets('renders nothing when no callsign is set', (tester) async {
      final settings = await makeSettings({});
      await pumpLabel(tester, settings);
      expect(find.descendant(of: find.byType(HeaderProfileLabel), matching: find.byType(Text)), findsNothing);
    });

    testWidgets('updates live when the callsign changes', (tester) async {
      final settings = await makeSettings({});
      await pumpLabel(tester, settings);
      expect(find.text('W1AW'), findsNothing);

      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'w1aw');
      await tester.pump();
      expect(find.text('W1AW'), findsOneWidget);
    });
  });

  group('wired into the real headers', () {
    testWidgets('the home header shows the callsign', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final services = await makeServices();
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(home: HomeView(services: services)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(_callsignInHeader, findsOneWidget);
      await drain(tester);
    });

    testWidgets('the Settings header shows the callsign', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final services = await makeServices();
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(home: SettingsView(services: services)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(_callsignInHeader, findsOneWidget);
      await drain(tester);
    });
  });
}
