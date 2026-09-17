// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The upgrade offer's one integration point is `MaterialApp.builder`, ABOVE
// the Navigator — the same rung as the onboarding and release gates. A
// dialog raised from the gate's own context has no Navigator to land on, and
// the failure is invisible: the offer is fire-and-forget off initState, so
// the throw reaches nobody and the operator simply never sees the dialog.
// This test mounts the gate where the app does, not under `home:`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/config/experiments.dart';
import 'package:ham2k_logger/config/navigation.dart';
import 'package:ham2k_logger/services/catalog_service.dart';
import 'package:ham2k_logger/services/extension_relevance.dart';
import 'package:ham2k_logger/services/installed_extensions.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/app_shell/extension_upgrade_gate.dart';

import '../support/halo_test_support.dart';

/// Always reachable, with something in it.
class _ReachableCatalog extends CatalogService {
  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false}) async => [
        CatalogEntry(
          key: 'wca',
          name: 'WCA',
          version: '1.0.0',
          sha256: 'a' * 64,
          bundleUrl: Uri.parse('https://catalog.example/api/v1/extensions/wca/versions/1.0.0/bundle'),
        ),
      ];
}

/// Answers the upgrade as if every twin arrived, without a network or a
/// store: what this file tests is what the OPERATOR is told afterwards.
class _MigrationSucceeds extends ExtensionServiceWithFakeHost {
  _MigrationSucceeds() : super(FakeExtensionHost({}));

  @override
  Future<bool> preloadShippedExtensions() async => true;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: true, complete: true);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime() async {}
}

/// Answers the upgrade as if the twins never arrived — the half of the
/// outcome the operator must not be told went well.
class _MigrationFails extends ExtensionServiceWithFakeHost {
  _MigrationFails() : super(FakeExtensionHost({}));

  @override
  Future<bool> preloadShippedExtensions() async => false;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: false, complete: false);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime() async {}
}

/// Reachable, and publishing nothing — what a channel looks like before its
/// first release.
class _EmptyCatalog extends CatalogService {
  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false}) async => const [];
}

void main() {
  testWidgets('the offer is raised from above the Navigator', (tester) async {
    final h = await makeHaLoServices(catalog: _ReachableCatalog());
    await h.settings.setExperimentEnabled(kCatalogExperiment, true);
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => ExtensionUpgradeGate(services: h.services, child: child!),
        home: const Scaffold(body: SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeTitle), findsOneWidget);

    // The release notes paint OVER this dialog on a launch that has both. A
    // barrier tap or Esc aimed at the notes must not pop the offer unseen as
    // "Later" — only its own buttons answer it.
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text(t.extensionsPanel.upgradeTitle), findsOneWidget, reason: 'a barrier tap dismissed the offer');
  });

  testWidgets('a finished upgrade says so', (tester) async {
    // The operator agreed to an operation that withdraws the extensions they
    // had. Only the failure was ever reported, so a success looked exactly
    // like a dialog that had done nothing.
    final h = await makeHaLoServices(extensions: _MigrationSucceeds(), catalog: _ReachableCatalog());
    await h.settings.setExperimentEnabled(kCatalogExperiment, true);
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => ExtensionUpgradeGate(services: h.services, child: child!),
        home: const Scaffold(body: SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.extensionsPanel.upgradeAction));
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeDoneTitle), findsOneWidget);
    expect(find.text(t.extensionsPanel.upgradeFailedTitle), findsNothing);
    expect(h.settings.extensionsMigrated, isTrue);
  });

  testWidgets('an upgrade that did not finish says THAT, and withdraws nothing', (tester) async {
    // The two outcomes share one dialog, so a success-only reading of `done`
    // tells an operator whose extensions were NOT migrated that they are
    // ready — the worse of the two wrong answers, since the flag is reverted
    // underneath them and the built-ins are what they still have.
    final h = await makeHaLoServices(extensions: _MigrationFails(), catalog: _ReachableCatalog());
    await h.settings.setExperimentEnabled(kCatalogExperiment, true);
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => ExtensionUpgradeGate(services: h.services, child: child!),
        home: const Scaffold(body: SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.extensionsPanel.upgradeAction));
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeFailedTitle), findsOneWidget);
    expect(find.text(t.extensionsPanel.upgradeDoneTitle), findsNothing);
    expect(h.settings.extensionsMigrated, isFalse, reason: 'a failed upgrade must leave the built-ins in use');
  });

  testWidgets('web is never offered an upgrade it cannot take', (tester) async {
    // No extension store there, so every step of the migration no-ops and it
    // ends in the failure dialog — asked again on the next launch, and on
    // every launch after it, with no answer it could ever give.
    InstalledExtensions.debugTreatAsUnsupported = true;
    addTearDown(() => InstalledExtensions.debugTreatAsUnsupported = null);
    final h = await makeHaLoServices(catalog: _ReachableCatalog());
    await h.settings.setExperimentEnabled(kCatalogExperiment, true);
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => ExtensionUpgradeGate(services: h.services, child: child!),
        home: const Scaffold(body: SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeTitle), findsNothing);
  });

  testWidgets('an empty catalog is not offered against', (tester) async {
    // `[]` is a reachable server with nothing on it, so an upgrade taken
    // against it fails — and the offer returns on the next launch, and the
    // one after that. Silence costs the operator nothing: the offer is made
    // again as soon as the channel has something to give them.
    final h = await makeHaLoServices(catalog: _EmptyCatalog());
    await h.settings.setExperimentEnabled(kCatalogExperiment, true);
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => ExtensionUpgradeGate(services: h.services, child: child!),
        home: const Scaffold(body: SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeTitle), findsNothing);
    expect(h.settings.extensionsMigrated, isFalse);
  });
}
