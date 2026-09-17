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
}
