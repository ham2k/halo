// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web BundleStorage: one IndexedDB record per extension key, holding every
// file of its bundle as bytes under the entry's own name.
//
// IndexedDB rather than the Origin Private File System, which would mirror the
// native directory layout: every browser HaLo runs in supports it the same
// way, while OPFS writes from the page are newer and patchier on Safari.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'bundle_storage.dart';
import 'installed_extensions.dart' show kManifestEntry;

const kBundleDatabaseName = 'halo-extensions';
const _bundles = 'bundles';

/// Each bundle's manifest again, on its own. Every listing reads every
/// manifest, and a record holding the whole bundle would be read — its JS and
/// assets structured-cloned — just to get at one small file.
const _manifests = 'manifests';

BundleStorage createBundleStorage() => IndexedDbBundleStorage();

class IndexedDbBundleStorage implements BundleStorage {
  /// [databaseName] is for tests, which each need a database of their own.
  IndexedDbBundleStorage({this.databaseName = kBundleDatabaseName});

  final String databaseName;

  Future<web.IDBDatabase>? _db;

  Future<web.IDBDatabase> _open() => _db ??= _openDatabase();

  Future<web.IDBDatabase> _openDatabase() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(databaseName, 1);
    request.onupgradeneeded = (web.IDBVersionChangeEvent event) {
      final db = request.result! as web.IDBDatabase;
      db.createObjectStore(_bundles);
      db.createObjectStore(_manifests);
    }.toJS;
    request.onsuccess = (web.Event _) {
      final db = request.result! as web.IDBDatabase;
      // Let go when the browser takes the database away (site data cleared
      // with the tab open) or another page deletes it. Without this, every
      // later call fails on a closed connection until the page reloads.
      db.onversionchange = (web.Event _) {
        db.close();
        _db = null;
      }.toJS;
      db.onclose = (web.Event _) {
        _db = null;
      }.toJS;
      completer.complete(db);
    }.toJS;
    request.onerror = (web.Event _) {
      _db = null;
      completer.completeError(StateError('could not open the extension store: ${request.error?.message}'));
    }.toJS;
    return completer.future;
  }

  @override
  Future<Map<String, String?>> manifests() async {
    late web.IDBRequest keys;
    late web.IDBRequest texts;
    // Both in key order, from one transaction, so they pair up by position.
    await _transaction([_manifests], 'readonly', (tx) {
      final store = tx.objectStore(_manifests);
      keys = store.getAllKeys();
      texts = store.getAll();
    });
    final keyList = (keys.result! as JSArray<JSAny?>).toDart;
    final textList = (texts.result! as JSArray<JSAny?>).toDart;
    return {for (var i = 0; i < keyList.length; i++) (keyList[i]! as JSString).toDart: (textList[i] as JSString?)?.toDart};
  }

  @override
  Future<String?> readText(String key, String name) async {
    if (name == kManifestEntry) {
      late web.IDBRequest request;
      await _transaction([_manifests], 'readonly', (tx) => request = tx.objectStore(_manifests).get(key.toJS));
      final text = request.result;
      return text == null || text.isUndefined ? null : (text as JSString).toDart;
    }
    late web.IDBRequest request;
    await _transaction([_bundles], 'readonly', (tx) => request = tx.objectStore(_bundles).get(key.toJS));
    final record = request.result;
    if (record == null || record.isUndefined) return null;
    final bytes = (record as JSObject).getProperty<JSUint8Array?>(name.toJS);
    return bytes == null ? null : utf8.decode(bytes.toDart);
  }

  @override
  Future<void> write(String key, Map<String, List<int>> files) async {
    final record = JSObject();
    for (final MapEntry(key: name, value: bytes) in files.entries) {
      record.setProperty(name.toJS, Uint8List.fromList(bytes).toJS);
    }
    final manifest = files[kManifestEntry];
    // One transaction, so the manifest a listing reads and the bundle it
    // describes can never disagree. put replaces each record whole, which is
    // the contract: a file the new version dropped does not linger.
    await _transaction([_bundles, _manifests], 'readwrite', (tx) {
      tx.objectStore(_bundles).put(record, key.toJS);
      final manifests = tx.objectStore(_manifests);
      if (manifest == null) {
        manifests.delete(key.toJS);
      } else {
        manifests.put(utf8.decode(manifest).toJS, key.toJS);
      }
    });
  }

  @override
  Future<void> remove(String key) => _transaction([_bundles, _manifests], 'readwrite', (tx) {
    tx.objectStore(_bundles).delete(key.toJS);
    tx.objectStore(_manifests).delete(key.toJS);
  });

  /// Runs [body] in one transaction over [stores] and completes when the
  /// TRANSACTION does — a write's success event fires before it is committed,
  /// and a caller told "installed" must be able to reload into it.
  Future<void> _transaction(List<String> stores, String mode, void Function(web.IDBTransaction tx) body) async {
    final storeNames = [for (final name in stores) name.toJS].toJS;
    web.IDBTransaction transaction;
    try {
      transaction = (await _open()).transaction(storeNames, mode);
    } catch (_) {
      // A connection closed under us without an event reaching the handlers
      // above: open a new one, once.
      _db = null;
      transaction = (await _open()).transaction(storeNames, mode);
    }
    final completer = Completer<void>();
    transaction.oncomplete = (web.Event _) {
      completer.complete();
    }.toJS;
    void fail(web.Event _) {
      if (completer.isCompleted) return;
      completer.completeError(StateError('extension store $mode failed: ${transaction.error?.message}'));
    }

    transaction.onerror = fail.toJS;
    transaction.onabort = fail.toJS;
    try {
      body(transaction);
    } catch (e) {
      // A request that throws as it is made (a value that will not clone):
      // the caller hears it once, through the one future, and the abort that
      // follows finds that future already answered.
      completer.completeError(e);
      try {
        transaction.abort();
      } catch (_) {}
    }
    return completer.future;
  }
}
