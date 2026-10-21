// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension's catalog screenshots (catalog SPEC §4.8): the strip of
// thumbnails on the activity search's install row and in an installed
// extension's details, and the viewer a tap opens.
//
// The images themselves never load here — the test binding answers every
// request with an error — so these pin what is laid out and reachable, which
// is what a broken image must not change either.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/views/extension_install_flow.dart';
import 'package:ham2k_logger/views/extension_screenshots.dart';
import 'package:ham2k_logger/views/operation/activities_catalog_tier.dart';

List<CatalogScreenshot> _shots(int count, {String? caption}) => [
  for (var n = 1; n <= count; n++)
    CatalogScreenshot(
      url: Uri.parse('https://catalog.ham2k.net/api/v1/extensions/k2hrc-llota/media/$n'),
      thumbUrl: Uri.parse('https://catalog.ham2k.net/api/v1/extensions/k2hrc-llota/media/t$n'),
      width: 1600,
      height: 900,
      caption: n == 1 ? caption : null,
    ),
];

CatalogEntry _entry({List<CatalogScreenshot> screenshots = const []}) => CatalogEntry(
  key: 'k2hrc-llota',
  name: 'LLOTA',
  version: '1.2.0',
  sha256: 'a' * 64,
  bundleUrl: Uri.parse('https://catalog.ham2k.net/api/v1/extensions/k2hrc-llota/versions/1.2.0/bundle'),
  screenshots: screenshots,
);

Future<void> _pump(WidgetTester tester, Widget child, {double width = 600}) => tester.pumpWidget(
  TranslationProvider(
    child: MaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  group('ExtensionScreenshotStrip', () {
    test('fits what fits, and at least the first one', () {
      expect(ExtensionScreenshotStrip.fitting([100, 100, 100], 320, 8), 3);
      expect(ExtensionScreenshotStrip.fitting([100, 100, 100], 300, 8), 2);
      expect(ExtensionScreenshotStrip.fitting([100], 50, 8), 0);
    });

    testWidgets('says how many more there are when they do not all fit, and shows nothing for none', (tester) async {
      // Without the count, the screenshots past the row's edge are reachable
      // only by an operator who already knows to open the first one.
      // 64 px high at 16:9 is 113.8 px wide; three and their gaps fit in 360.
      await _pump(tester, ExtensionScreenshotStrip(screenshots: _shots(5), title: 'LLOTA'), width: 360);
      expect(find.text(t.extensionsPanel.moreScreenshots(count: 2)), findsOneWidget);
      expect(find.bySemanticsLabel(t.extensionsPanel.screenshotLabel(n: 3, count: 5)), findsOneWidget);
      expect(find.bySemanticsLabel(t.extensionsPanel.screenshotLabel(n: 4, count: 5)), findsNothing);

      await _pump(tester, ExtensionScreenshotStrip(screenshots: _shots(2), title: 'LLOTA'), width: 360);
      expect(find.textContaining('+'), findsNothing);

      await _pump(tester, const ExtensionScreenshotStrip(screenshots: [], title: 'LLOTA'));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('a screen reader can press a thumbnail, not only see one', (tester) async {
      // `tester.tap` goes around the semantics tree; a thumbnail whose node
      // excluded the InkWell's action would pass every other test here.
      final handle = tester.ensureSemantics();
      await _pump(tester, ExtensionScreenshotStrip(screenshots: _shots(2), title: 'LLOTA'));
      expect(tester.getSemantics(find.bySemanticsLabel(t.extensionsPanel.screenshotLabel(n: 1, count: 2))), isSemantics(isButton: true, hasTapAction: true));
      handle.dispose();
    });

    testWidgets('a tap opens every screenshot full size at the one tapped, paged by the arrow keys', (tester) async {
      await _pump(
        tester,
        ExtensionScreenshotStrip(
          screenshots: _shots(3, caption: 'Logging a park'),
          title: 'LLOTA',
        ),
      );
      await tester.tap(find.bySemanticsLabel(t.extensionsPanel.screenshotLabel(n: 2, count: 3)));
      await tester.pumpAndSettle();
      expect(find.text('LLOTA'), findsOneWidget);
      expect(find.text(t.extensionsPanel.screenshotLabel(n: 2, count: 3)), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      // The caption stands in for the counter where the publisher wrote one.
      expect(find.text('Logging a park'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Logging a park'), findsOneWidget, reason: 'paged past the first screenshot');
    });
  });

  testWidgets("the activity search's install row shows the extension's screenshots before anything is downloaded", (tester) async {
    await _pump(
      tester,
      InstallExtensionRow(
        entry: _entry(screenshots: _shots(2)),
        onTap: () {},
      ),
    );
    expect(find.byType(ExtensionScreenshotStrip), findsOneWidget);
    expect(find.text(t.activitiesView.installExtensionHint), findsOneWidget);

    await _pump(tester, InstallExtensionRow(entry: _entry(), onTap: () {}));
    expect(find.byType(ExtensionScreenshotStrip), findsNothing);
    expect(find.text(t.activitiesView.installExtensionHint), findsOneWidget);
  });

  testWidgets("an installed extension's details show its catalog screenshots", (tester) async {
    final info = ExtensionInfo(key: 'k2hrc-llota', file: 'index.js', core: false, name: 'LLOTA', source: ExtensionSource.installed, version: '1.2.0');
    for (final (screenshots, expected) in [(_shots(2), findsOneWidget), (const <CatalogScreenshot>[], findsNothing)]) {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            locale: const Locale('en'),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showExtensionDetails(context, info: info, locale: 'en', installedFrom: 'catalog.ham2k.net', screenshots: screenshots),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(t.extensionsPanel.screenshotLabel(n: 1, count: 2)), expected);
      await tester.tap(find.text(t.common.done));
      await tester.pumpAndSettle();
    }
  });
}
