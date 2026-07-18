// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// First-run onboarding (Issue #43). The load-bearing rules: the overlay
// shows only while the default profile's operatorCall has NEVER been
// written — an explicit '' (a previous Skip) or a real callsign both count
// as answered — and every exit (Skip or the full flow) writes the callsign
// key so onboarding cannot re-trigger. The full flow must land its answers
// in the places the rest of the app reads: the default profile, the
// privacy group, and the extensions' own settings groups.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/ham2k_logo.dart';
import 'package:ham2k_logger/views/onboarding_overlay.dart';

import 'fake_secure_storage.dart';
import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

Future<HaLoServices> makeServices({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
  return HaLoServices(db, settings, extensions: extensions);
}

Future<void> pumpApp(WidgetTester tester, HaLoServices services) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(TranslationProvider(child: HaLoApp(services: services)));
  await tester.pumpAndSettle();
}

Future<void> drainTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => setReleaseNotesForTesting(const []));

  testWidgets('shows only while the default profile callsign is undefined', (tester) async {
    // Undefined → onboarding.
    final services = await makeServices();
    await pumpApp(tester, services);
    expect(find.byType(OnboardingOverlayView), findsOneWidget);
    await drainTimers(tester);

    // Explicitly empty (a previous Skip) → no onboarding.
    final skipped = await makeServices(prefs: {'profiles': '{"default": {"operatorCall": ""}}'});
    await pumpApp(tester, skipped);
    expect(find.byType(OnboardingOverlayView), findsNothing);
    await drainTimers(tester);

    // A real callsign → no onboarding.
    final defined = await makeServices(prefs: {'profiles': '{"default": {"operatorCall": "KI2D"}}'});
    await pumpApp(tester, defined);
    expect(find.byType(OnboardingOverlayView), findsNothing);
    await drainTimers(tester);
  });

  testWidgets('on Welcome, tapping anywhere advances to the callsign step', (tester) async {
    final services = await makeServices();
    await pumpApp(tester, services);

    // The brand mark is well outside the band and its buttons.
    await tester.tap(find.byType(Ham2kBrandMark));
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('DEVONBOARD force-shows even with a callsign defined, and re-shows after dismissal', (tester) async {
    final services = await makeServices(prefs: {'profiles': '{"default": {"operatorCall": "KI2D"}}'});
    await pumpApp(tester, services);
    expect(find.byType(OnboardingOverlayView), findsNothing);

    services.devOnboardTrigger.trigger();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingOverlayView), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingOverlayView), findsNothing);

    // A second trigger must work — the overlay entry is per-showing.
    services.devOnboardTrigger.trigger();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingOverlayView), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await drainTimers(tester);
  });

  testWidgets('Skip marks the callsign as explicitly empty and finishes', (tester) async {
    final services = await makeServices();
    await pumpApp(tester, services);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingOverlayView), findsNothing);
    expect(services.settings.defaultProfileCallsignDefined, isTrue);
    expect(services.settings.activeProfile.operatorCall, '');
    await drainTimers(tester);
  });

  testWidgets('the full flow writes callsign, activity picks, and consents', (tester) async {
    final services = await makeServices();
    await pumpApp(tester, services);

    // Welcome → Callsign.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, "Operator's Callsign"), 'ki2d');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Activities: POTA pre-checked; also turn SOTA on.
    expect(find.text('Favorite Activities'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Summits On The Air'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Consent: usage pre-checked; also turn operation data on; Done.
    expect(find.text('Data & Privacy'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Share Operation Data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingOverlayView), findsNothing);
    final settings = services.settings;
    expect(settings.activeProfile.operatorCall, 'KI2D');
    expect(settings.defaultProfileCallsignDefined, isTrue);
    expect(settings.consentAppData, isTrue);
    expect(settings.consentOpData, isTrue);
    // Activity picks are real extension enable/disable overrides now
    // (Extensions panel, issue #25) — not settings-group keys.
    expect(settings.extensionOverrides, {'pota': true, 'sota': true});
    expect(settings.settingValue('extension_pota', 'enabled'), isNull);
    await drainTimers(tester);
  });

  testWidgets('Enter advances every step like its primary button', (tester) async {
    final services = await makeServices();
    await pumpApp(tester, services);

    // Welcome → Callsign — even with no text field focused, Enter must
    // reach the overlay's shortcut.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, "Operator's Callsign"), 'ki2d');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Favorite Activities'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Data & Privacy'), findsOneWidget);

    // Done: the flow finishes with the answers persisted.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingOverlayView), findsNothing);
    expect(services.settings.activeProfile.operatorCall, 'KI2D');
    await drainTimers(tester);
  });
}
