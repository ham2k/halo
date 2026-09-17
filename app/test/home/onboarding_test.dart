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

import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/sibling_apps_service.dart';
import 'package:ham2k_logger/views/ham2k_logo.dart';
import 'package:ham2k_logger/views/onboarding_overlay.dart';
import 'package:ham2k_logger/views/tester_overlay.dart' show testerOverlayCovering;
import 'package:ham2k_logger/views/settings_view.dart';
import 'package:ham2k_logger/views/splash_view.dart';
import 'package:ham2k_logger/views/switch_accounts_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/halo_test_support.dart';

// WCAG 2.1 contrast ratio — the focus-indicator test below pins an actual
// accessibility threshold rather than a specific color.
double _linear(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _luminance(Color c) => 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);
double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Future<HaLoServices> makeServices({
  Map<String, Object> prefs = const {},
  ExtensionService? extensions,
  SiblingAppsService? siblingApps,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
  final db = HaLoDatabase(NativeDatabase.memory());
  final effectiveExtensions = extensions ?? (ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings);
  if (extensions != null) {
    extensions.settings = settings;
  }
  return HaLoServices(db, settings, extensions: effectiveExtensions, siblingApps: siblingApps);
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

  setUp(() {
    setReleaseNotesForTesting(const []);
    setTesterNotesForTesting(const []);
  });

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

  testWidgets('stepping back to Welcome lays out cleanly while the callsign step slides out', (tester) async {
    // The trap is that both steps are fine AT REST — only the
    // frames between them fail, so a test that settles after each tap sees
    // nothing. On Welcome the band's SizedBox height goes null (unbounded)
    // and the switcher's Stack goes loose, while AnimatedSwitcher keeps the
    // OUTGOING callsign step as a retained widget it never rebuilds — so a
    // flex captured from the previous build meets unbounded constraints
    // mid-slide. Mutating `flex`/`mainAxisSize` back to the passed-in
    // isHeightConstrained must fail this.
    final services = await makeServices();
    await pumpApp(tester, services);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pump(); // the transition starts; both steps are now mounted
    await tester.pump(const Duration(milliseconds: 120)); // mid-slide
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    await drainTimers(tester);
  });

  testWidgets('BootGate: a broken release-notes asset does not block boot for a first run', (tester) async {
    // Regression test for main.dart's BootGateState: _prepareOnboardingPhoto
    // (loadReleaseNotes + precacheImage) used to run outside the try/catch
    // that exists to stop non-bootstrap errors from being mislabeled as a
    // bootstrap failure — a broken release-notes.yaml took down the whole
    // app (BootErrorScreen) instead of onboarding just showing without its
    // photo.
    setReleaseNotesFailureForTesting(Exception('malformed release-notes.yaml'));
    final services = await makeServices();
    await tester.pumpWidget(TranslationProvider(child: BootGate(servicesFuture: Future.value(services))));
    // A couple of plain pumps first, not just pumpAndSettle: BootGate's
    // servicesFuture.then chain needs a few microtask turns (including the
    // rejected release-notes future) before it calls _switchTo, which is
    // what starts the fade animation pumpAndSettle actually waits for.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(BootErrorScreen), findsNothing);
    expect(find.byType(OnboardingOverlayView), findsOneWidget);
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

  testWidgets('a re-shown onboarding seeds the callsign and activity toggles from saved settings', (tester) async {
    // A callsign is saved and SOTA has been enabled (POTA left at its default).
    // DEVONBOARD re-shows the flow, which must reflect that saved state rather
    // than resetting to the first-run defaults.
    final services = await makeServices(prefs: {'profiles': '{"default": {"operatorCall": "KI2D"}}'});
    await services.settings.setExtensionOverrides({'sota': true});
    await pumpApp(tester, services);

    services.devOnboardTrigger.trigger();
    await tester.pumpAndSettle();

    // Welcome → Callsign: the field is prefilled with the saved callsign.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, "Operator's Callsign"));
    expect(callField.controller!.text, 'KI2D');

    // Activities: the SOTA toggle reflects the saved override (on).
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Favorite Activities'), findsOneWidget);
    final sota = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Summits On The Air'));
    expect(sota.value, isTrue);

    await drainTimers(tester);
  });

  test('applyOnboardAsSpec (ONBOARD_AS) sets the callsign and enables the listed activities', () async {
    final services = await makeServices();
    await applyOnboardAsSpec(services, 'ki2d, pota , sota');
    expect(services.settings.activeProfile.operatorCall, 'KI2D');
    expect(services.settings.defaultProfileCallsignDefined, isTrue);
    expect(services.settings.extensionOverrides, {'pota': true, 'sota': true});
  });

  test('applyOnboardAsSpec with only a callsign enables no activities', () async {
    final services = await makeServices();
    await applyOnboardAsSpec(services, 'KI2D');
    expect(services.settings.activeProfile.operatorCall, 'KI2D');
    expect(services.settings.extensionOverrides, isEmpty);
  });

  testWidgets('the overlay keeps its fixed light palette when the app is in dark mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final services = await makeServices();
    await pumpApp(tester, services);
    expect(find.byType(OnboardingOverlayView), findsOneWidget);

    // Without the light-theme pin the panel keeps its white band and black
    // text but its controls resolve dark-mode colors — the Skip chip paints
    // the dark surfaceContainerHighest under teal text.
    //
    // This asserts the pin EXISTS, and only that. It cannot tell whether the
    // overlay actually resolved through it: every context in the tree is
    // below the pin, so this reads light either way. The callsign-field test
    // below is what covers the resolution.
    final ambient = Theme.of(tester.element(find.text('Skip')));
    expect(ambient.brightness, Brightness.light);
    await drainTimers(tester);
  });

  testWidgets('in dark mode the callsign field still focuses DARK, against the overlay\'s white band', (tester) async {
    // The pin above is only half the guarantee. A step builder that resolves a
    // color from the state's own context reads the AMBIENT brightness — that
    // context is an ancestor of the pin, not a descendant — and hands this
    // field a white focus border on a white panel: invisible, and nothing
    // throws. Reading the ambient Theme at a widget in the tree (as the test
    // above does) cannot catch it, because every such context is below the pin.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final services = await makeServices();
    await pumpApp(tester, services);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.widgetWithText(TextField, "Operator's Callsign"));
    final side = field.decoration!.focusedBorder!.borderSide;
    final panel = Theme.of(tester.element(find.text('Continue'))).colorScheme.surface;
    expect(_contrast(side.color, panel), greaterThanOrEqualTo(3.0));
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
    await tester.tap(find.text('Continue'));
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
    expect(settings.extensionOverrides, {'pota': true, 'sota': true, 'wwff': false});
    expect(settings.settingValue('extension_pota', 'enabled'), isNull);
    await drainTimers(tester);
  });

  testWidgets('Done shows a finishing-setup wait state before dismissing (issue #379)', (tester) async {
    final services = await makeServices();
    await pumpApp(tester, services);

    // Walk to the consent (final) step.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, "Operator's Callsign"), 'ki2d');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Data & Privacy'), findsOneWidget);

    await tester.tap(find.text('Done'));
    // A single frame, not pumpAndSettle: catches the wait state mid-flight,
    // before the (mocked, near-instant) data-file sync resolves and the
    // overlay dismisses — proving Done actually pauses rather than just
    // eventually finishing.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Finishing setup — downloading reference data…'), findsOneWidget);
    expect(find.byType(OnboardingOverlayView), findsOneWidget, reason: 'must still be up mid-sync');
    // Both buttons disabled while finishing — no way to back out or double-tap.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Done')).onPressed, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Back')).onPressed, isNull);

    await tester.pumpAndSettle();
    expect(find.byType(OnboardingOverlayView), findsNothing);
    await drainTimers(tester);
  });

  testWidgets('Done still finishes onboarding if enabling extensions/syncing data files throws', (tester) async {
    // A restart failure (e.g. disposing the outgoing runtime) must not strand
    // the user on the finishing-setup wait state with no way out.
    final services = await makeServices(extensions: ThrowingExtensionService());
    await pumpApp(tester, services);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, "Operator's Callsign"), 'ki2d');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Data & Privacy'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingOverlayView), findsNothing);
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

  testWidgets('Enter is inert while the tester overlay covers the flow', (tester) async {
    // Onboarding's Enter shortcut is a HardwareKeyboard handler, which
    // dispatches ahead of the focus tree — the tester overlay mounted on
    // top (fresh installs) cannot swallow it, so the handler stands down
    // via testerOverlayCovering instead. Without that, one Enter dismisses
    // the overlay AND advances this flow past the welcome step.
    final services = await makeServices();
    await pumpApp(tester, services);
    addTearDown(() => testerOverlayCovering.value = false);

    testerOverlayCovering.value = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsNothing);

    testerOverlayCovering.value = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('Already have an account link flows to Link Account Menu and completes on email linking', (tester) async {
    final mockExtensions = MockExtensionService();
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-1'},
      'accounts': [],
      'qsos': {'total': 0},
      'operations': {'total': 0},
    };

    final services = await makeServices(extensions: mockExtensions);
    await pumpApp(tester, services);

    // Welcome → Callsign
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Callsign → Link Account Menu
    expect(find.text('Already have an account?'), findsOneWidget);
    await tester.tap(find.text('Already have an account?'));
    await tester.pumpAndSettle();
    expect(find.text('Link with a QR code'), findsOneWidget);
    expect(find.text('Link with an email address'), findsOneWidget);

    // Link Account Menu → Link with Email
    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the email address of the account you want this device to use.'), findsOneWidget);

    // Enter email and submit
    var linkCalled = false;
    mockExtensions.onLinkClient = (email) {
      expect(email, 'test@example.com');
      linkCalled = true;
      return {
        'permission': {'status': 'pending', 'challenge_token': '123456', 'challenge_expires_at': '2026-12-31T23:59:59Z'}
      };
    };

    await tester.enterText(find.widgetWithText(TextField, 'Email address'), 'test@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();

    expect(linkCalled, isTrue);
    expect(find.text('123456'), findsOneWidget); // Challenge code on screen
    expect(find.text('Waiting for confirmation…'), findsOneWidget);

    // Simulate other device approving (polling detects new UUID)
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-2', 'call': 'W1AW'},
      'accounts': [],
    };

    // Fast-forward or trigger polling tick. Since onboarding overlay uses Timer.periodic with 5s,
    // we can pump with duration to trigger the timer.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Onboarding should be finished/dismissed and active operator callsign updated
    expect(find.byType(OnboardingOverlayView), findsNothing);
    expect(services.settings.activeProfile.operatorCall, 'W1AW');
    await drainTimers(tester);
  });

  testWidgets('Already have an account link redirects to settings if app has existing QSOs', (tester) async {
    final mockExtensions = MockExtensionService();
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-1'},
      'accounts': [],
      'qsos': {'total': 0},
      'operations': {'total': 0},
    };

    final services = await makeServices(extensions: mockExtensions);
    final op = await services.operations.create(stationCall: 'KI2D');
    await services.qsos.add(op.uuid, {'their': {'call': 'W1AW'}});

    await pumpApp(tester, services);

    // Welcome → Callsign
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Callsign → Link Account Menu
    await tester.tap(find.text('Already have an account?'));
    await tester.pumpAndSettle();

    // Link Account Menu → Link with Email
    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();

    // Enter email and submit
    mockExtensions.onLinkClient = (email) {
      return {
        'permission': {'status': 'pending', 'challenge_token': '123456', 'challenge_expires_at': '2026-12-31T23:59:59Z'}
      };
    };

    await tester.enterText(find.widgetWithText(TextField, 'Email address'), 'test@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();

    // Simulate other device approving
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-2', 'call': 'K2DEF'},
      'accounts': [],
    };

    // Trigger polling tick
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Onboarding should be finished/dismissed and operator call updated
    expect(find.byType(OnboardingOverlayView), findsNothing);
    expect(services.settings.activeProfile.operatorCall, 'K2DEF');

    // It should have pushed SettingsView
    expect(find.byType(SettingsView), findsOneWidget);
    expect(find.text('Cloud Sync'), findsWidgets);

    await drainTimers(tester);
  });

  testWidgets('Already have an account link: QR flow renders deep link and Back returns to Callsign step', (tester) async {
    final mockExtensions = MockExtensionService();
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-1'},
      'accounts': [],
    };
    mockExtensions.onLinkClient = (email) {
      expect(email, isNull);
      return {
        'permission': {
          'status': 'pending',
          'client': 'client-123',
          'challenge_token': 'token-456',
          'challenge_expires_at': '2026-12-31T23:59:59Z',
        }
      };
    };

    final services = await makeServices(extensions: mockExtensions);
    await pumpApp(tester, services);

    // Welcome → Callsign → Link Account
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already have an account?'));
    await tester.pumpAndSettle();

    // Tap QR flow
    await tester.tap(find.text('Link with a QR code'));
    await tester.pumpAndSettle();

    // Verify QR code is displayed
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Scan this QR code'), findsOneWidget);

    // ONE Back per level, retracing the way in. The step has no chrome of
    // its own, so the pane carries both the way back to its menu and the way
    // back to the callsign question — spelled the same, they must never be on
    // screen together, or the step offers two "Back" buttons going to
    // different places with nothing to tell them apart.
    expect(find.text('Back'), findsOneWidget);
    await tester.ensureVisible(find.text('Back'));
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Link with a QR code'), findsOneWidget);

    expect(find.text('Back'), findsOneWidget);
    await tester.ensureVisible(find.text('Back'));
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsOneWidget);

    await drainTimers(tester);
  });

  testWidgets('a fresh install that links is not sent to Settings for the QSOs the first round pulled', (tester) async {
    // The sync engine's own rounds keep running under onboarding, and the
    // one that first sees the new account adopts it silently (nothing
    // local) and pulls its log — routinely before the pane's poll notices
    // the grant. Whether this device HAD data is decided when the link flow
    // starts; the mutation to catch is counting at success, which reads the
    // server's log as local and sends an empty install to combine/replace.
    final mockExtensions = MockExtensionService();
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-1'},
      'accounts': [],
    };
    mockExtensions.onLinkClient = (_) => {
          'permission': {'status': 'pending', 'challenge_token': '123456', 'challenge_expires_at': '2026-12-31T23:59:59Z'}
        };
    final services = await makeServices(extensions: mockExtensions);
    await pumpApp(tester, services);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already have an account?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Email address'), 'test@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();

    // The engine got there first: the account's QSOs are already local by
    // the time the poll sees the changed account.
    final op = await services.operations.create(stationCall: 'K2DEF');
    await services.qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-2', 'call': 'K2DEF'},
      'accounts': [],
    };
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingOverlayView), findsNothing);
    expect(find.byType(SettingsView), findsNothing, reason: 'nothing of its own to combine — straight to the home screen');
    await drainTimers(tester);
  });

  // A sibling Ham2K app on the device turns Welcome's Continue into
  // an offer. The mutations these catch: a gate that shows the step for an
  // EMPTY list; a link built by hand instead of by linkClientQrUrl; a return
  // trip that leaves "waiting" on screen with nothing else to press.
  testWidgets('with no sibling app, Welcome goes straight to the callsign step', (tester) async {
    final services = await makeServices(siblingApps: FakeSiblingApps(const []));
    await pumpApp(tester, services);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsOneWidget);
    expect(find.text('Link an existing account?'), findsNothing);
    await drainTimers(tester);
  });

  testWidgets('a sibling app is offered after Welcome; Set up fresh falls through to the callsign step', (tester) async {
    final services = await makeServices(siblingApps: FakeSiblingApps(const [_polo]));
    await pumpApp(tester, services);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Link an existing account?'), findsOneWidget);
    expect(find.textContaining('We found an older version of Ham2K Portable Logger'), findsOneWidget);
    expect(find.text('Link with account in older version'), findsOneWidget);

    await tester.tap(find.text('Set up fresh'));
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsOneWidget);
    // Back from the callsign step retraces through the offer, not past it.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Link an existing account?'), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('linking with a sibling hands it the QR link, and a resume with the grant finishes onboarding', (tester) async {
    final siblings = FakeSiblingApps(const [_polo]);
    final mockExtensions = MockExtensionService();
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-1'},
      'accounts': [],
      'qsos': {'total': 0},
      'operations': {'total': 0},
    };
    String? requestedEmail = 'unset';
    mockExtensions.onLinkClient = (email) {
      requestedEmail = email;
      return {
        'permission': {
          'status': 'pending',
          'client': 'client-123',
          'challenge_token': 'token-456',
          'challenge_expires_at': '2026-12-31T23:59:59Z',
        }
      };
    };
    final services = await makeServices(extensions: mockExtensions, siblingApps: siblings);
    await pumpApp(tester, services);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link with account in older version'));
    await tester.pumpAndSettle();

    // The same orphaned permission the QR flow requests (no email), and the
    // very same link — one builder, so the two readers can't drift.
    expect(requestedEmail, isNull);
    expect(siblings.opened, [(_polo, linkClientQrUrl(clientUuid: 'client-123', challengeToken: 'token-456'))]);
    expect(find.textContaining('Approve the request in Ham2K Portable Logger'), findsOneWidget);
    expect(find.text('Waiting for confirmation…'), findsOneWidget);
    expect(find.textContaining("Didn't work?"), findsNothing);

    // The operator approves over there and switches back: the resume polls
    // at once rather than waiting out the 5s tick.
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-2', 'call': 'W1AW'},
      'accounts': [],
    };
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingOverlayView), findsNothing);
    expect(services.settings.activeProfile.operatorCall, 'W1AW');
    await drainTimers(tester);
  });

  testWidgets('a resume with nothing granted offers Set up fresh, which lands on the callsign step', (tester) async {
    final siblings = FakeSiblingApps(const [_polo]);
    final mockExtensions = MockExtensionService();
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-1'},
      'accounts': [],
    };
    mockExtensions.onLinkClient = (_) => {
          'permission': {
            'status': 'pending',
            'client': 'client-123',
            'challenge_token': 'token-456',
            'challenge_expires_at': '2026-12-31T23:59:59Z',
          }
        };
    final services = await makeServices(extensions: mockExtensions, siblingApps: siblings);
    await pumpApp(tester, services);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link with account in older version'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining("Didn't work?"), findsOneWidget);
    // Still polling: a late grant must still be noticed.
    expect(find.text('Waiting for confirmation…'), findsOneWidget);

    await tester.ensureVisible(find.text('Set up fresh'));
    await tester.tap(find.text('Set up fresh'));
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsOneWidget);
    // The poll is gone with the step: five more seconds fetch nothing that
    // could dismiss the overlay from under the callsign question.
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-2', 'call': 'W1AW'},
      'accounts': [],
    };
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingOverlayView), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('a sibling that will not open says so, and can be tried again', (tester) async {
    final siblings = FakeSiblingApps(const [_polo])..openSucceeds = false;
    final mockExtensions = MockExtensionService();
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-1'},
      'accounts': [],
    };
    mockExtensions.onLinkClient = (_) => {
          'permission': {
            'status': 'pending',
            'client': 'client-123',
            'challenge_token': 'token-456',
            'challenge_expires_at': '2026-12-31T23:59:59Z',
          }
        };
    final services = await makeServices(extensions: mockExtensions, siblingApps: siblings);
    await pumpApp(tester, services);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link with account in older version'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open Ham2K Portable Logger.'), findsOneWidget);

    siblings.openSucceeds = true;
    await tester.ensureVisible(find.text('Open Ham2K Portable Logger again'));
    await tester.tap(find.text('Open Ham2K Portable Logger again'));
    await tester.pumpAndSettle();
    expect(siblings.opened, hasLength(2));
    expect(find.text('Could not open Ham2K Portable Logger.'), findsNothing);
    await drainTimers(tester);
  });

  testWidgets('a sibling started before the account was known offers Try again, not a link that cannot succeed', (tester) async {
    // The poll declares success on a CHANGE from the baseline; a baseline
    // first learned after the sibling approved is the new account, and the
    // change is never seen. So with no baseline the request must not go out.
    final siblings = FakeSiblingApps(const [_polo]);
    final mockExtensions = MockExtensionService();
    var reachable = false;
    var requests = 0;
    mockExtensions.onAccountData = () => reachable ? {'current_account': {'uuid': 'acct-1'}, 'accounts': []} : null;
    mockExtensions.onLinkClient = (_) {
      requests++;
      return {
        'permission': {'status': 'pending', 'client': 'c', 'challenge_token': 't', 'challenge_expires_at': '2026-12-31T23:59:59Z'}
      };
    };
    final services = await makeServices(extensions: mockExtensions, siblingApps: siblings);
    await pumpApp(tester, services);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link with account in older version'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(siblings.opened, isEmpty);
    expect(find.text('Could not reach the sync server. Try again later.'), findsOneWidget);

    reachable = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(siblings.opened, hasLength(1));
    expect(find.text('Waiting for confirmation…'), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('two PoLo flavors are offered by name; a lone PoLo as the older version', (tester) async {
    const beta = SiblingApp(id: 'com.ham2k.polo.beta', name: 'Ham2K Portable Logger (Beta)');
    final services = await makeServices(siblingApps: FakeSiblingApps(const [_polo, beta]));
    await pumpApp(tester, services);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Link with account in older version'), findsNothing);
    expect(find.text('Link with Ham2K Portable Logger'), findsOneWidget);
    expect(find.text('Link with Ham2K Portable Logger (Beta)'), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('the sibling rows also sit on the link-account menu reached from the callsign step', (tester) async {
    final services = await makeServices(siblingApps: FakeSiblingApps(const [_polo]));
    await pumpApp(tester, services);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set up fresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already have an account?'));
    await tester.pumpAndSettle();
    expect(find.text('Link with account in older version'), findsOneWidget);
    expect(find.text('Link with a QR code'), findsOneWidget);
    await drainTimers(tester);
  });

  // The two tests below both catch the same mutation: any step of the band
  // whose widget TYPE changes with the keyboard — a `Container` whose height
  // goes null, an `Expanded` that becomes a bare child — re-inflates the step
  // and destroys whatever State it owns. On a phone that reads as the keyboard
  // opening for a few frames and closing again, taking the step's progress
  // with it; on desktop, where viewInsets never move, it is invisible.
  testWidgets('the callsign field survives the keyboard it opens', (tester) async {
    final services = await makeServices();
    await pumpApp(tester, services);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextField, "Operator's Callsign");
    await tester.enterText(field, 'KI2D');
    await tester.pumpAndSettle();

    final editable = find.descendant(of: field, matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
    // Identity, captured BEFORE the change. Text and focus alone would not
    // prove survival here: the controller is the overlay State's own field,
    // and `autofocus: true` hands focus straight back to a freshly inflated
    // field — so a re-inflated step reads identical on both unless the test
    // pins the State object itself.
    final before = tester.state<EditableTextState>(editable);

    // The soft keyboard arriving: viewInsets grow from the bottom.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(tester.state<EditableTextState>(editable), same(before));
    expect(tester.widget<EditableText>(editable).controller.text, 'KI2D');
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);

    await drainTimers(tester);
  });

  testWidgets('the link-account pane stays on the step the keyboard was opened for', (tester) async {
    final mockExtensions = MockExtensionService();
    mockExtensions.mockAccountData = {
      'current_account': {'uuid': 'acct-1'},
      'accounts': [],
      'qsos': {'total': 0},
      'operations': {'total': 0},
    };

    final services = await makeServices(extensions: mockExtensions);
    await pumpApp(tester, services);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already have an account?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the email address of the account you want this device to use.'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    // The pane owns the email/QR/code mode in its own State: losing it drops
    // the user back to the menu, which reads as an uninvited Back.
    expect(find.text('Enter the email address of the account you want this device to use.'), findsOneWidget);
    expect(find.text('Link with an email address'), findsNothing);

    await drainTimers(tester);
  });
}

/// A device with other Ham2K loggers on it. [opened] records every link
/// handed across, in order.
class FakeSiblingApps extends SiblingAppsService {
  final List<SiblingApp> installed;
  final opened = <(SiblingApp, String)>[];
  bool openSucceeds = true;

  FakeSiblingApps(this.installed);

  @override
  Future<List<SiblingApp>> list() async => installed;

  @override
  Future<bool> open(SiblingApp app, String url) async {
    opened.add((app, url));
    return openSucceeds;
  }
}

const _polo = SiblingApp(id: 'com.ham2k.polo.prod', name: 'Ham2K Portable Logger');

class MockExtensionService extends ExtensionServiceWithFakeHost {
  Map<String, dynamic>? mockAccountData;
  Map<String, dynamic>? Function()? onAccountData;
  Map<String, dynamic>? Function(String?)? onLinkClient;
  Map<String, dynamic>? Function(String)? onLinkClientWithEmail;

  MockExtensionService() : super(FakeExtensionHost({}));

  @override
  Future<Map<String, dynamic>?> syncAccountData() async => onAccountData != null ? onAccountData!() : mockAccountData;

  @override
  Future<Map<String, dynamic>?> syncLinkClient(String? email) async {
    if (onLinkClient != null) return onLinkClient!(email);
    return null;
  }

  @override
  Future<Map<String, dynamic>?> syncLinkClientWithEmail(String email) async {
    if (onLinkClientWithEmail != null) return onLinkClientWithEmail!(email);
    return null;
  }
}

/// Simulates a runtime-restart failure (e.g. disposing the outgoing host)
/// from onboarding's extension-enable step.
class ThrowingExtensionService extends ExtensionServiceWithFakeHost {
  ThrowingExtensionService() : super(FakeExtensionHost({}));

  @override
  Future<void> setExtensionsEnabled(Map<String, bool> changes) async {
    throw StateError('simulated runtime restart failure');
  }
}
