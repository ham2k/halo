// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Issue #348: per-flow onboarding counters, plus the two triggers that read
// them — the operation sheet auto-opening once for a user who's never seen
// it (independent of the existing new-operation auto-open, covered in
// new_operation_flow_test.dart), and the home FAB's wiggle nudge stopping
// once enough new operations have been opened.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/home_view.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService onboarding counters', () {
    late SettingsService settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsService(await SharedPreferences.getInstance());
    });

    test('a flow that has never shown reads as count 0', () {
      expect(settings.onboardingShownCount(OnboardingFlows.firstUse), 0);
    });

    test('recording bumps the count and stamps first/last shown', () async {
      await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
      expect(settings.onboardingShownCount(OnboardingFlows.operationSheet), 1);
      final state = settings.onboardingStates[OnboardingFlows.operationSheet] as Map;
      expect(state['firstShownAtMillis'], isNotNull);
      expect(state['lastShownAtMillis'], state['firstShownAtMillis']);

      await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
      expect(settings.onboardingShownCount(OnboardingFlows.operationSheet), 2);
      final second = settings.onboardingStates[OnboardingFlows.operationSheet] as Map;
      expect(second['firstShownAtMillis'], state['firstShownAtMillis'], reason: 'first-shown never moves');
    });

    test('flows are independent of each other', () async {
      await settings.recordOnboardingShown(OnboardingFlows.newOperation);
      expect(settings.onboardingShownCount(OnboardingFlows.newOperation), 1);
      expect(settings.onboardingShownCount(OnboardingFlows.operationSheet), 0);
      expect(settings.onboardingShownCount(OnboardingFlows.firstUse), 0);
    });

    test('the count survives a fresh SettingsService over the same prefs', () async {
      await settings.recordOnboardingShown(OnboardingFlows.newOperation);
      await settings.recordOnboardingShown(OnboardingFlows.newOperation);
      final reloaded = SettingsService(await SharedPreferences.getInstance());
      expect(reloaded.onboardingShownCount(OnboardingFlows.newOperation), 2);
    });

    group('seedFirstUseOnboardingForExistingUsers', () {
      test('seeds count 1 when the profile already has a callsign', () async {
        await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
        expect(settings.onboardingShownCount(OnboardingFlows.firstUse), 0);

        await settings.seedFirstUseOnboardingForExistingUsers();

        expect(settings.onboardingShownCount(OnboardingFlows.firstUse), 1);
      });

      test('does nothing for a fresh install with no callsign yet', () async {
        await settings.seedFirstUseOnboardingForExistingUsers();
        expect(settings.onboardingShownCount(OnboardingFlows.firstUse), 0);
      });

      test('is a no-op once the counter is already non-zero — never overwrites a real count', () async {
        await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
        await settings.recordOnboardingShown(OnboardingFlows.firstUse);
        await settings.recordOnboardingShown(OnboardingFlows.firstUse);
        expect(settings.onboardingShownCount(OnboardingFlows.firstUse), 2);

        await settings.seedFirstUseOnboardingForExistingUsers();

        expect(settings.onboardingShownCount(OnboardingFlows.firstUse), 2, reason: 'seeding must not clobber a real count');
      });
    });
  });

  group('operation-sheet onboarding — independent auto-open', () {
    testWidgets('opening an EXISTING operation (not new) auto-opens the sheet once, for a user who has never seen it',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final HaLoHarness(:services, :settings) = await makeHaLoServices();
      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');

      // An operation that predates this feature — created WITHOUT the
      // new-operation flow's openActivities, same as any operation logged
      // before issue #348 shipped.
      final operation = await services.operations.create(stationCall: 'KI2D');
      expect(settings.onboardingShownCount(OnboardingFlows.operationSheet), 0);

      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          // openActivities: false — this is the "just opening an operation
          // I already had" path, not the new-operation one.
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OperationSheet), findsOneWidget,
          reason: 'first-ever operation open must show the sheet once, per issue #348');
      expect(settings.onboardingShownCount(OnboardingFlows.operationSheet), 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a SECOND operation open, after the first has been seen, does not auto-open again', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final HaLoHarness(:services, :settings) = await makeHaLoServices();
      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
      // Already seen, as if from an earlier operation view (or an earlier
      // session entirely).
      await settings.recordOnboardingShown(OnboardingFlows.operationSheet);

      final operation = await services.operations.create(stationCall: 'KI2D');

      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OperationSheet), findsNothing);
      expect(settings.onboardingShownCount(OnboardingFlows.operationSheet), 1, reason: 'unchanged — already seen');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('new-operation FAB nudge', () {
    Future<HaLoServices> servicesWithNewOperationCount(int count) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      for (var i = 0; i < count; i++) {
        await settings.recordOnboardingShown(OnboardingFlows.newOperation);
      }
      final db = HaLoDatabase(NativeDatabase.memory());
      return HaLoServices(db, settings);
    }

    // Precise finder: the nudge wraps the FAB in an extra Transform (from
    // Transform.rotate) that nothing else near the plus icon introduces —
    // checking the ROTATION value wouldn't work here, since the animation
    // is pinned to 0 under test (see _NewOperationNudgeState's FLUTTER_TEST
    // guard), so presence/absence of the wrapper is what's actually testable.
    Finder wiggleWrapper() => find.ancestor(of: find.byIcon(MdiIcons.plus), matching: find.byType(Transform));

    /// The nudge only appears after the screen has sat untouched for
    /// `_newOperationNudgeDelay` (see home_fab_settle_test.dart for the delay
    /// and its cancellation); these tests are about WHETHER it appears at a
    /// given onboarding count, so they wait that out first.
    const nudgeDelay = Duration(seconds: 5);

    testWidgets('wiggles below the threshold', (tester) async {
      final services = await servicesWithNewOperationCount(0);
      addTearDown(services.db.close);
      await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: HomeView(services: services))));
      await tester.pumpAndSettle();
      await tester.pump(nudgeDelay);

      expect(wiggleWrapper(), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('still wiggles at one below the threshold', (tester) async {
      final services = await servicesWithNewOperationCount(1);
      addTearDown(services.db.close);
      await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: HomeView(services: services))));
      await tester.pumpAndSettle();
      await tester.pump(nudgeDelay);

      expect(wiggleWrapper(), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('stops once the threshold is reached', (tester) async {
      final services = await servicesWithNewOperationCount(2);
      addTearDown(services.db.close);
      await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: HomeView(services: services))));
      await tester.pumpAndSettle();
      await tester.pump(nudgeDelay);

      expect(wiggleWrapper(), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('creating a new operation records the count the nudge reads', (tester) async {
      final services = await servicesWithNewOperationCount(0);
      addTearDown(services.db.close);
      await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: HomeView(services: services))));
      await tester.pumpAndSettle();
      await tester.pump(nudgeDelay);

      expect(wiggleWrapper(), findsOneWidget);

      await tester.tap(find.byIcon(MdiIcons.plus));
      // The tap navigates away (into a fresh OperationView); the count is
      // what's under test here, not the FAB's post-navigation state.
      await tester.pump();

      expect(services.settings.onboardingShownCount(OnboardingFlows.newOperation), 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
