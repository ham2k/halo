// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/extensions/bundle_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/extensions/installed_extensions.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/views/operation/information_panel.dart' show scorerKeyOfDayTally;
import 'package:ham2k_logger/views/extension_markdown_images.dart';

import '../support/error_reporting_fakes.dart';
import '../support/memory_bundle_storage.dart';

/// A 1x1 PNG.
const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
const _svg = '<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4"><rect width="4" height="4"/></svg>';

InstalledExtensions _store(BundleStorage storage) => InstalledExtensions(builtInKeys: () => const {}, hostSharedModules: const {}, storage: storage);

MemoryBundleStorage _storageWith(Map<String, List<int>> files) =>
    MemoryBundleStorage()..files['ki2d-panel'] = {'manifest.json': utf8.encode('{}'), 'index.js': utf8.encode(''), ...files};

Future<void> _pump(WidgetTester tester, String markdown, {InstalledExtensions? store}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ExtensionMarkdownImages(
          store: store,
          extensionKey: 'ki2d-panel',
          child: HaloMarkdown(data: markdown),
        ),
      ),
    ),
  );
  // The asset read, then the frame that draws it.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('assetEntryName', () {
    test('takes a path inside assets/, normalized', () {
      expect(InstalledExtensions.assetEntryName('assets/logo.png'), 'assets/logo.png');
      expect(InstalledExtensions.assetEntryName('./assets/logo.png'), 'assets/logo.png');
      expect(InstalledExtensions.assetEntryName('assets/x/../logo.png'), 'assets/logo.png');
    });

    test('refuses anything that leaves assets/', () {
      for (final path in ['index.js', 'manifest.json', 'assets/../index.js', '../other/assets/a.png', '/assets/a.png', r'assets\a.png', 'assets/', 'assets']) {
        expect(InstalledExtensions.assetEntryName(path), isNull, reason: path);
      }
    });
  });

  group('readAsset', () {
    test("reads the extension's own file, and drops it when the extension is reinstalled or removed", () async {
      final storage = _storageWith({
        'assets/logo.png': [1, 2, 3],
      });
      final store = _store(storage);
      expect(await store.readAsset('ki2d-panel', 'assets/logo.png'), [1, 2, 3]);

      // Kept: a change underneath is not seen until the store is told.
      storage.files['ki2d-panel']!['assets/logo.png'] = [4, 5, 6];
      expect(await store.readAsset('ki2d-panel', 'assets/logo.png'), [1, 2, 3]);

      await store.uninstall('ki2d-panel');
      expect(await store.readAsset('ki2d-panel', 'assets/logo.png'), isNull);
    });

    test('reads nothing outside assets/, nor for a key that is not one', () async {
      final store = _store(_storageWith({}));
      expect(await store.readAsset('ki2d-panel', 'index.js'), isNull);
      expect(await store.readAsset('ki2d-panel', 'assets/../manifest.json'), isNull);
    });

    test('draws nothing too large to hold', () async {
      final store = _store(_storageWith({'assets/huge.png': List.filled(kMaxAssetImageBytes + 1, 0)}));
      expect(await store.readAsset('ki2d-panel', 'assets/huge.png'), isNull);
    });
  });

  group('readAsset, when the store fails', () {
    tearDown(ErrorReportingService.resetForTesting);

    test('fails the read and reports it once, however often it is asked, until it reads again', () async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        final storage = _FailingStorage(
          _storageWith({
            'assets/logo.png': [1, 2, 3],
          }),
        );
        final store = _store(storage);
        for (var i = 0; i < 3; i++) {
          await expectLater(store.readAsset('ki2d-panel', 'assets/logo.png'), throwsA(isA<StateError>()));
        }
        expect(backend.exceptions.where((e) => e.context == 'installed-extensions:asset'), hasLength(1));

        storage.failing = false;
        expect(await store.readAsset('ki2d-panel', 'assets/logo.png'), [1, 2, 3]);
        storage.failing = true;
        await store.uninstall('ki2d-panel');
        storage.files['ki2d-panel'] = {
          'assets/logo.png': [1],
        };
        await expectLater(store.readAsset('ki2d-panel', 'assets/logo.png'), throwsA(isA<StateError>()));
        expect(backend.exceptions.where((e) => e.context == 'installed-extensions:asset'), hasLength(2));
      }, backend: backend);
    });
  });

  group('readAsset, held', () {
    test('keeps what it read at hand, as the same bytes', () async {
      final store = _store(_storageWith({'assets/logo.png': base64.decode(_png)}));
      expect(store.readAssetNow('ki2d-panel', 'assets/logo.png'), isNull);
      final first = await store.readAsset('ki2d-panel', 'assets/logo.png');
      expect(identical(store.readAssetNow('ki2d-panel', 'assets/logo.png'), first), isTrue);
      expect(identical(await store.readAsset('ki2d-panel', 'assets/logo.png'), first), isTrue);
    });

    test('drops the least recently drawn once it holds more than its budget', () async {
      // One more image at the largest size drawn than the budget holds.
      final names = [for (var i = 0; i <= kAssetCacheBytes ~/ kMaxAssetImageBytes; i++) 'assets/$i.png'];
      final image = List.filled(kMaxAssetImageBytes, 0);
      final store = _store(_storageWith({for (final name in names) name: image}));
      for (final name in names) {
        await store.readAsset('ki2d-panel', name);
      }
      expect(store.readAssetNow('ki2d-panel', names.first), isNull);
      for (final name in names.skip(1)) {
        expect(store.readAssetNow('ki2d-panel', name), isNotNull, reason: name);
      }
    });
  });

  group('ExtensionMarkdownImages', () {
    test("an extension's builder is kept, and a new one follows an install or uninstall of it", () async {
      final store = _store(_storageWith({}));
      final first = extensionMarkdownImageBuilder(store, 'ki2d-panel');
      expect(identical(extensionMarkdownImageBuilder(store, 'ki2d-panel'), first), isTrue);
      await store.uninstall('ki2d-panel');
      expect(identical(extensionMarkdownImageBuilder(store, 'ki2d-panel'), first), isFalse);
    });

    testWidgets("draws the extension's own PNG", (tester) async {
      await _pump(tester, '![logo](assets/logo.png)', store: _store(_storageWith({'assets/logo.png': base64.decode(_png)})));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('logo', findRichText: true), findsNothing);
    });

    testWidgets("draws the extension's own SVG", (tester) async {
      await _pump(tester, '![chart](assets/chart.svg)', store: _store(_storageWith({'assets/chart.svg': utf8.encode(_svg)})));
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('draws a data: image', (tester) async {
      await _pump(tester, '![dot](data:image/png;base64,$_png)');
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('an image from anywhere else is its alt text', (tester) async {
      for (final src in ['https://tracker.example/p.png', '//tracker.example/p.png', 'file:///etc/p.png']) {
        await _pump(tester, '![elsewhere]($src)', store: _store(_storageWith({})));
        expect(find.text('elsewhere', findRichText: true), findsOneWidget, reason: src);
        expect(find.byType(Image), findsNothing, reason: src);
      }
    });

    testWidgets('a file that is not there, or not an image format, is its alt text', (tester) async {
      final store = _store(_storageWith({'assets/notes.txt': utf8.encode('hello')}));
      await _pump(tester, '![missing](assets/missing.png)', store: store);
      expect(find.text('missing', findRichText: true), findsOneWidget);
      await _pump(tester, '![notes](assets/notes.txt)', store: store);
      expect(find.text('notes', findRichText: true), findsOneWidget);
      await _pump(tester, '![page](data:text/html;base64,PGI+aGk8L2I+)', store: store);
      expect(find.text('page', findRichText: true), findsOneWidget);
    });

    testWidgets('an escape that is no character is its alt text, and the rest still draws', (tester) async {
      await _pump(tester, 'Hello\n\n![odd](assets/%FF.png)', store: _store(_storageWith({})));
      expect(tester.takeException(), isNull);
      expect(find.text('Hello', findRichText: true), findsOneWidget);
      expect(find.text('odd', findRichText: true), findsOneWidget);
    });

    testWidgets("never reaches outside the extension's assets/", (tester) async {
      final store = _store(_storageWith({}));
      await _pump(tester, '![code](assets/../index.js)', store: store);
      expect(find.text('code', findRichText: true), findsOneWidget);
    });
  });

  group('owners', () {
    test('a notice keeps the extension that posted it, in the history across a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      StatusBarService(prefs)
        ..showNotice(key: 'ki2d-panel:hello', text: '![Logo](assets/logo.png)', extensionKey: 'ki2d-panel')
        ..showNotice(key: 'accounts:lookup', text: 'The app’s own');
      await Future<void>.delayed(Duration.zero);
      final history = StatusBarService(prefs).history;
      expect({for (final notice in history) notice.key: notice.extensionKey}, {'ki2d-panel:hello': 'ki2d-panel', 'accounts:lookup': null});
    });

    test("a day's tally names its scorer before the first dot", () {
      expect(scorerKeyOfDayTally('ham2k-pota_activity.activation'), 'ham2k-pota_activity');
      expect(scorerKeyOfDayTally('k2hrc.refs.day'), 'k2hrc');
      expect(scorerKeyOfDayTally('core.bands'), 'core');
      expect(scorerKeyOfDayTally('bare'), 'bare');
    });
  });
}

/// A store whose reads fail while [failing] — a damaged disk, a broken
/// IndexedDB — over [MemoryBundleStorage]'s files.
class _FailingStorage implements BundleStorage {
  _FailingStorage(this._inner);

  final MemoryBundleStorage _inner;
  bool failing = true;

  Map<String, Map<String, List<int>>> get files => _inner.files;

  @override
  Future<Map<String, String?>> manifests() => _inner.manifests();

  @override
  Future<String?> readText(String key, String name) => _inner.readText(key, name);

  @override
  Future<List<int>?> readBytes(String key, String name) async => failing ? throw StateError('the store is damaged') : _inner.readBytes(key, name);

  @override
  Future<void> write(String key, Map<String, List<int>> files) => _inner.write(key, files);

  @override
  Future<void> remove(String key) => _inner.remove(key);
}
