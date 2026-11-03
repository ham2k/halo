// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension's `about` (docs/extensions/manifest.md#about): read from an
// installed manifest and from a catalog entry, picked by locale, and drawn in
// the extension's details as markdown that fetches nothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/views/extension_install_flow.dart';

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  group('aboutFor', () {
    ExtensionInfo info(Object? about, Map<String, Map<String, Object?>> translations) =>
        ExtensionInfo.fromJson({'key': 'k2hrc-llota', 'file': 'index.js', 'name': 'LLOTA', 'about': about, 'translations': translations});

    test("a translation's about wins, and the base one stands in for a locale without one", () {
      final llota = info('Lakes.', {
        'es': {'about': 'Lagos.'},
        'fr': {'name': 'Lacs'},
      });
      expect(llota.aboutFor('es'), 'Lagos.');
      expect(llota.aboutFor('fr'), 'Lakes.');
      expect(llota.aboutFor('de'), 'Lakes.');
    });

    test("a region's own text is found by its full tag, and stands in for the bare language", () {
      final brazil = info('Lakes.', {
        'pt-BR': {'about': 'Lagos do Brasil.'},
      });
      expect(brazil.aboutFor('pt-BR'), 'Lagos do Brasil.');
      expect(brazil.aboutFor('pt'), 'Lagos do Brasil.');
      final portugal = info('Lakes.', {
        'pt': {'about': 'Lagos.'},
        'pt-BR': {'about': 'Lagos do Brasil.'},
      });
      expect(portugal.aboutFor('pt-BR'), 'Lagos do Brasil.');
      expect(portugal.aboutFor('pt-PT'), 'Lagos.');
    });

    test('a blank or unreadable text is none, and does not hide the base one', () {
      expect(
        info('Lakes.', {
          'es': {'about': '  '},
          'fr': {'about': 42},
        }).aboutFor('es'),
        'Lakes.',
      );
      expect(info('Lakes.', {}).aboutFor('fr'), 'Lakes.');
      expect(info(' \n', {}).aboutFor('en'), isNull);
      expect(info(['not', 'text'], {}).about, isNull);
      expect(info(null, {}).aboutFor('en'), isNull);
    });

    test('a catalog entry carries it too', () {
      final entry = CatalogEntry.fromJson({
        'key': 'k2hrc-llota',
        'name': 'LLOTA',
        'version': '1.2.0',
        'sha256': 'a' * 64,
        'bundleUrl': 'https://catalog.ham2k.net/api/v1/extensions/k2hrc-llota/versions/1.2.0/bundle',
        'about': 'Lakes.',
        'translations': {
          'es': {'about': 'Lagos.'},
        },
      })!;
      expect(entry.aboutFor('en'), 'Lakes.');
      expect(entry.aboutFor('es'), 'Lagos.');
    });
  });

  testWidgets("the details show the about as markdown, an image as its alt text and nothing fetched", (tester) async {
    final info = ExtensionInfo(key: 'k2hrc-llota', file: 'index.js', core: false, name: 'LLOTA', source: ExtensionSource.installed, version: '1.2.0');
    Future<void> open(String? about) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            locale: const Locale('en'),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showExtensionDetails(context, info: info, locale: 'en', installedFrom: 'catalog.ham2k.net', about: about),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    await open('## Lakes\n\nActivate **lakes**.\n\n![a lake at dawn](https://example.org/lake.png)');
    expect(find.byType(ExtensionAbout), findsOneWidget);
    expect(find.text('Lakes'), findsOneWidget);
    expect(find.textContaining('Activate', findRichText: true), findsOneWidget);
    expect(find.text('a lake at dawn'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.text(t.common.done));
    await tester.pumpAndSettle();

    await open(null);
    expect(find.byType(ExtensionAbout), findsNothing);
  });
}
