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
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/views/ham2k_logo.dart';
import 'package:ham2k_logger/views/onboarding_overlay.dart';
import 'package:ham2k_logger/views/settings_view.dart';
import 'package:ham2k_logger/views/splash_view.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'fake_secure_storage.dart';
import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

Future<HaLoServices> makeServices({
  Map<String, Object> prefs = const {},
  ExtensionService? extensions,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
  final db = HaLoDatabase(NativeDatabase.memory());
  final effectiveExtensions = extensions ?? (ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings);
  if (extensions != null) {
    extensions.settings = settings;
  }
  return HaLoServices(db, settings, extensions: effectiveExtensions);
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
    final ambient = Theme.of(tester.element(find.text('Skip')));
    expect(ambient.brightness, Brightness.light);
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
    expect(find.text('LoFi Cloud Sync'), findsWidgets);

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

    // Tap Back to menu
    await tester.ensureVisible(find.text('Back').first);
    await tester.tap(find.text('Back').first);
    await tester.pumpAndSettle();
    expect(find.text('Link with a QR code'), findsOneWidget);

    // Tap Back to Callsign step
    await tester.ensureVisible(find.text('Back').last);
    await tester.tap(find.text('Back').last);
    await tester.pumpAndSettle();
    expect(find.text("What's your callsign?"), findsOneWidget);

    await drainTimers(tester);
  });
}

class MockExtensionService extends ExtensionServiceWithMockHost {
  Map<String, dynamic>? mockAccountData;
  Map<String, dynamic>? Function(String?)? onLinkClient;
  Map<String, dynamic>? Function(String)? onLinkClientWithEmail;

  MockExtensionService() : super(const MockExtensionHost({}));

  @override
  Future<Map<String, dynamic>?> syncAccountData() async => mockAccountData;

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
class ThrowingExtensionService extends ExtensionServiceWithMockHost {
  ThrowingExtensionService() : super(const MockExtensionHost({}));

  @override
  Future<void> setExtensionsEnabled(Map<String, bool> changes) async {
    throw StateError('simulated runtime restart failure');
  }
}
