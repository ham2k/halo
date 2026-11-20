// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What an extension keeps in the keychain itself, through `host.keychainSet`,
// and its hooks read back on `ctx.keychain` (docs/extensions/host.md).

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show kMaxKvEntryChars, kMaxKvKeysPerBundle;

import '../error_reporting_service.dart';
import 'extension_keychain.dart' show extensionKeychainItemName, extensionKeychainPrefix, isKeychainItemMissing;

/// An extension's keychain values, or one of them, could not be read: the
/// hook is handed no `ctx.keychain`, or the value is left out of it.
class ExtensionKeychainUnreadable implements Exception {
  ExtensionKeychainUnreadable(this.extensionKey, this.cause, {this.key});

  final String extensionKey;

  /// The one value that could not be decoded; null when the keychain itself
  /// refused.
  final String? key;
  final Object cause;

  @override
  String toString() => 'ExtensionKeychainUnreadable: $extensionKey${key == null ? '' : ' "$key"'}: $cause';
}

/// One keychain item per key, `extensionKeychain_<extension>_<key>`, so an
/// uninstall finds them the way it finds every other item an extension owns
/// (extension_keychain.dart), and an extension taking over another's key gets
/// them through [copy].
///
/// They are found again by the names the app records writing ([names]),
/// never by listing the keychain: the macOS file keychain will not list, and
/// an extension that never stored anything then costs no keychain read at
/// all, which every hook call of every extension would otherwise pay.
///
/// Nothing is held here: every read goes to the keychain, and the kernel's
/// short-lived context cache is the only copy, dropped on every write.
class ExtensionKeychainValues {
  ExtensionKeychainValues(this._storage, {required this.names, required this.recordName, required this.forgetName});

  final FlutterSecureStorage _storage;

  /// Every keychain item name the app has recorded writing.
  final Set<String> Function() names;
  final Future<void> Function(String name) recordName;
  final Future<void> Function(String name) forgetName;

  Iterable<String> _namesOf(String extensionKey) {
    final prefix = extensionKeychainPrefix(extensionKey);
    return names().where((name) => name.startsWith(prefix));
  }

  /// [extensionKey]'s values, by key. Throws when the keychain cannot be
  /// read: the hook then sees no `ctx.keychain` rather than an empty one,
  /// which would read as the operator having entered nothing, and a panel
  /// showing that would save it over what they had. A value that reads but
  /// does not decode is left out and reported: it holds nothing to keep, and
  /// the rest stay readable.
  Future<Map<String, Object?>> read(String extensionKey) async {
    final prefix = extensionKeychainPrefix(extensionKey);
    final values = <String, Object?>{};
    for (final name in _namesOf(extensionKey).toList()) {
      final raw = await _storage.read(key: name);
      if (raw == null) continue;
      final key = name.substring(prefix.length);
      try {
        values[key] = jsonDecode(raw);
      } on FormatException catch (e, stack) {
        ErrorReportingService.report(ExtensionKeychainUnreadable(extensionKey, e, key: key), stack, context: 'extensions:keychain-read');
      }
    }
    return values;
  }

  /// Stores [value] under [key] for [extensionKey], or removes it for null.
  /// Held to the limits of `host.kvSet`: [kMaxKvKeysPerBundle] keys, each key
  /// and its JSON at most [kMaxKvEntryChars] characters. Reads none of the
  /// other values, so one that cannot be read never stops the extension
  /// replacing or removing it.
  Future<void> write(String extensionKey, Object? key, Object? value) async {
    if (key is! String || key.isEmpty) throw ArgumentError('keychainSet needs a key, a non-empty string');
    final name = extensionKeychainItemName(extensionKey, key);
    if (value == null) {
      try {
        await _storage.delete(key: name);
      } catch (e) {
        // macOS 26 answers a delete of an item that is not there with an
        // error: removing a key never set is still a key removed.
        if (!isKeychainItemMissing(e)) rethrow;
      }
      await forgetName(name);
      return;
    }
    final encoded = jsonEncode(value);
    if (key.length + encoded.length > kMaxKvEntryChars) {
      throw ArgumentError('keychainSet "$key": a key and its value hold at most $kMaxKvEntryChars characters of JSON');
    }
    final recorded = _namesOf(extensionKey).toSet();
    final isNew = !recorded.contains(name);
    if (isNew && recorded.length >= kMaxKvKeysPerBundle) {
      throw ArgumentError('keychainSet "$key": an extension keeps at most $kMaxKvKeysPerBundle keys in the keychain');
    }
    // Recorded first: an item whose name was never recorded is one no read
    // or uninstall finds again. Forgotten again if the write fails, or it
    // would count against the limit while holding nothing.
    if (isNew) await recordName(name);
    try {
      await _storage.write(key: name, value: encoded);
    } catch (_) {
      if (isNew) await forgetName(name);
      rethrow;
    }
  }

  /// Copies [from]'s values onto [to], leaving [from]'s alone; a value [to]
  /// already holds wins. By the recorded names, so it works where the
  /// keychain will not list (copyExtensionKeychainItems), and records the
  /// copies, which a read would otherwise never find.
  Future<void> copy({required String from, required String to}) async {
    final toPrefix = extensionKeychainPrefix(to);
    final fromPrefix = extensionKeychainPrefix(from);
    final held = _namesOf(to).toSet();
    for (final name in _namesOf(from).toList()) {
      final target = '$toPrefix${name.substring(fromPrefix.length)}';
      if (held.contains(target)) continue;
      try {
        final raw = await _storage.read(key: name);
        if (raw == null) continue;
        await recordName(target);
        await _storage.write(key: target, value: raw);
      } catch (e, stack) {
        ErrorReportingService.report(e, stack, context: 'extensions:copy-secrets');
      }
    }
  }
}
