// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A pane whose extension is not running offers what would bring it back
// (docs/design/layouts.md § Layout files): an operator handed a layout full
// of panels from extensions they lack has no other way to tell which
// extension a pane needs, or where to get it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/services/extensions/extension_relevance.dart' show OperatorGeo;
import 'package:ham2k_logger/services/extensions/installed_extensions.dart' show CatalogChannel;
import 'package:ham2k_logger/views/operation/missing_panel_pane.dart';

import '../support/halo_test_support.dart';

void main() {
  final t = AppLocale.en.buildSync().operation.layout;

  Future<void> pumpPane(WidgetTester tester, HaLoServices services, String panelId) => tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: MissingPanelPane(services: services, panelId: panelId, gainWith: (gain) => gain()),
        ),
      ),
    ),
  );

  testWidgets('an extension the app does not have is looked up when Install is pressed, and the pane says when the catalog cannot help', (tester) async {
    final catalog = _Catalog();
    final HaLoHarness(:services) = await makeHaLoServices(catalog: catalog);
    await pumpPane(tester, services, 'ext:wx:forecast');
    // Asked on the press, not on the draw: a layout of such panes would be a
    // fetch every time it is opened.
    expect(catalog.asked, 0);

    await tester.tap(find.text(t.missingExtensionInstall));
    await tester.pumpAndSettle();
    expect(catalog.asked, 1);
    expect(find.text(t.missingExtensionCatalogUnreachable), findsOneWidget, reason: 'an unreachable catalog is not an absent extension');

    catalog.entries = const [];
    await tester.tap(find.text(t.missingExtensionCatalogUnreachable));
    await tester.pumpAndSettle();
    expect(find.text(t.missingExtensionNotInCatalog), findsOneWidget);
  });

  testWidgets('an install that fails says so, rather than looking like nothing happened', (tester) async {
    final catalog = _Catalog()..fails = true;
    final HaLoHarness(:services) = await makeHaLoServices(catalog: catalog);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            // As both hosts do: the failure is reported there, and the answer
            // is the same false a declined consent gives.
            body: MissingPanelPane(
              services: services,
              panelId: 'ext:wx:forecast',
              gainWith: (gain) async {
                try {
                  return await gain();
                } catch (_) {
                  return false;
                }
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(t.missingExtensionInstall));
    await tester.pumpAndSettle();
    expect(find.text(t.missingExtensionFailed), findsOneWidget);
  });

  testWidgets('an extension installed and switched off is one press from back', (tester) async {
    final HaLoHarness(:services, :extensions) = await makeHaLoServices();
    // Real file reads, which the test's fake clock would never let finish.
    await tester.runAsync(() => preloadShippedExtensionsForTest(extensions));
    final info = extensions.availableExtensions.firstWhere((info) => info.isInstalled && !info.core);
    await tester.runAsync(() => extensions.setExtensionEnabled(info.key, false));
    await pumpPane(tester, services, 'ext:${info.key}:anything');

    await tester.tap(find.text(t.missingExtensionEnable));
    await tester.pumpAndSettle();
    expect(extensions.isExtensionEnabled(info), isTrue);
  });
}

class _Catalog extends CatalogService {
  /// What the catalog answers; null for one it could not reach.
  List<CatalogEntry>? entries;
  bool fails = false;
  int asked = 0;

  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false, CatalogChannel? channel}) async {
    asked++;
    if (fails) throw StateError('catalog broke');
    return entries;
  }
}
