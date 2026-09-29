// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The web extension store runs only in a browser, so every VM test of the
// store exercises the file backend instead. Without this, a web build could
// install nothing, lose every bundle on reload, or list a bundle under a
// manifest that is not its own — and the whole native suite would stay green.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/bundle_storage_web.dart';
import 'package:web/web.dart' as web;

void main() {
  // Each test its own database: the browser keeps them for the whole run.
  final run = Random().nextInt(1000000000);
  var databases = 0;
  IndexedDbBundleStorage fresh() => IndexedDbBundleStorage(databaseName: 'halo-extensions-test-$run-${databases++}');

  test('a store survives a reload, and lists every manifest in one read', () async {
    final first = fresh();
    await first.write('ki2d-clock', {'manifest.json': utf8.encode('{"key":"ki2d-clock"}'), 'index.js': utf8.encode('/* clock */')});
    await first.write('ki2d-radio', {'manifest.json': utf8.encode('{"key":"ki2d-radio"}'), 'index.js': utf8.encode('/* radio */')});

    final reloaded = IndexedDbBundleStorage(databaseName: first.databaseName);
    expect(await reloaded.manifests(), {'ki2d-clock': '{"key":"ki2d-clock"}', 'ki2d-radio': '{"key":"ki2d-radio"}'});
    expect(await reloaded.readText('ki2d-clock', 'index.js'), '/* clock */');
  });

  test('an update replaces the bundle whole', () async {
    // A file the new version dropped must not linger and keep being served.
    final store = fresh();
    await store.write('ki2d-clock', {'index.js': utf8.encode('v1'), 'assets/old.txt': utf8.encode('stale')});
    await store.write('ki2d-clock', {'index.js': utf8.encode('v2')});
    expect(await store.readText('ki2d-clock', 'index.js'), 'v2');
    expect(await store.readText('ki2d-clock', 'assets/old.txt'), isNull);
  });

  test('an uninstall leaves nothing behind, and a missing key is not an error', () async {
    final store = fresh();
    await store.write('ki2d-clock', {'index.js': utf8.encode('x')});
    await store.remove('ki2d-clock');
    await store.remove('never-installed');
    expect(await store.manifests(), isEmpty);
    expect(await store.readText('ki2d-clock', 'index.js'), isNull);
  });

  test('a manifest reads back from the same write as its bundle, and goes with it', () async {
    // Manifests are kept apart so a listing does not read every bundle. Kept
    // apart and written separately, a listing could name a bundle that is not
    // there, or miss one that is.
    final store = fresh();
    await store.write('ki2d-clock', {'manifest.json': utf8.encode('{"v":1}'), 'index.js': utf8.encode('x')});
    expect(await store.readText('ki2d-clock', 'manifest.json'), '{"v":1}');
    await store.write('ki2d-clock', {'manifest.json': utf8.encode('{"v":2}'), 'index.js': utf8.encode('y')});
    expect(await store.readText('ki2d-clock', 'manifest.json'), '{"v":2}');
    await store.remove('ki2d-clock');
    expect(await store.readText('ki2d-clock', 'manifest.json'), isNull);
  });

  test('a store whose database is taken away mid-session keeps working', () async {
    // What clearing site data with the tab open does. Holding on to the
    // closed connection, every later install and listing fails until reload.
    final store = fresh();
    await store.write('ki2d-clock', {'index.js': utf8.encode('x')});
    final deleted = Completer<void>();
    final request = web.window.indexedDB.deleteDatabase(store.databaseName);
    request.onsuccess = (web.Event _) {
      deleted.complete();
    }.toJS;
    request.onblocked = (web.Event _) {
      if (!deleted.isCompleted) deleted.completeError(StateError('the store kept its connection open'));
    }.toJS;
    await deleted.future;

    expect(await store.manifests(), isEmpty);
    await store.write('ki2d-clock', {'index.js': utf8.encode('again')});
    expect(await store.readText('ki2d-clock', 'index.js'), 'again');
  });
}
