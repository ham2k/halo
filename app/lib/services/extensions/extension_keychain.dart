// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keychain items an extension owns, found by the one handle left once it
// is gone: its key.
//
// By the time an extension is being uninstalled — or a pre-loaded one is
// taking over a built-in's identity (HALO-581) — its hooks are absent, so
// nothing can be asked which panels or accounts it had. The prefixes below
// are the same ones `registerHook` enforces for every key an extension may
// claim, which is what makes enumeration sound.

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../error_reporting_service.dart';
import 'extension_store_settings.dart' show isExtensionPanelIdOf, renamedExtensionPanelId;

/// Every shape a key `<extension>` may own, as a prefix that ends in `_`.
List<String> _prefixesFor(String key) => ['settingsPanel_secret_${key}_', 'account_creds_${key}_', 'account_session_${key}_'];

/// The two that are the bare key rather than a prefix of one.
List<String> _exactFor(String key) => ['account_creds_$key', 'account_session_$key'];

/// A docked panel's secret is `settingsPanel_secret_<panel id>_<field>`, and
/// the panel id names the extension (`renamedExtensionPanelId`).
const _docked = 'settingsPanel_secret_';

bool _isDockedSecretOf(String storedKey, String key) => storedKey.startsWith(_docked) && isExtensionPanelIdOf(storedKey.substring(_docked.length), key);

/// Whether [storedKey] is an account credential or session, which carry
/// per-account keychain options and so may not be read or written with the
/// instance defaults.
bool _isAccountItem(String storedKey) => storedKey.startsWith('account_creds_') || storedKey.startsWith('account_session_');

/// Copies every keychain item [from] owned onto [to], leaving [from] alone.
///
/// This is what keeps an operator logged in when an extension changes its
/// key: `ham2k-sota` is the built-in `sota` under a name the catalog can
/// serve, and without this its first act would be to ask for a login the
/// operator already gave.
///
/// An item already stored under [to] wins.
///
/// [copyOne] is how an item is moved when the keychain cannot be enumerated
/// — it is handed a pair of names and does the read and the write with the
/// options its writer used. Only the names that can be known without
/// enumerating reach it, which is the account pair; a settings-panel secret
/// is `settingsPanel_secret_<key>_<field>` and nothing here can guess the
/// field.
Future<void> copyExtensionKeychainItems(
  FlutterSecureStorage storage, {
  required String from,
  required String to,
  required Future<void> Function(String from, String to) copyOne,
}) async {
  final stored = await _readAllOrNull(storage, context: 'extensions:copy-secrets');
  if (stored != null) {
    for (final entry in stored.entries) {
      final moved = _renamed(entry.key, from: from, to: to);
      if (moved == null || stored.containsKey(moved)) continue;
      try {
        // An ACCOUNT item goes through the caller, which reads and writes it
        // under that account's own options — `synchronizable` among them. A
        // plain write here uses the instance defaults, so on a platform where
        // enumeration works the credential lands under options its owner does
        // not read back with, and the extension starts logged out. The
        // settings-panel secrets have no per-item options and are copied here.
        if (_isAccountItem(entry.key)) {
          await copyOne(entry.key, moved);
        } else {
          await storage.write(key: moved, value: entry.value);
        }
      } catch (e, stack) {
        ErrorReportingService.report(e, stack, context: 'extensions:copy-secrets');
      }
    }
    return;
  }
  // No enumeration on this platform. The account pair is the half that
  // matters — it is the operator's login, and the one whose absence they
  // notice immediately — and its names are fixed by convention rather than
  // by anything the extension chose.
  final fromNames = _exactFor(from);
  final toNames = _exactFor(to);
  for (var i = 0; i < fromNames.length; i += 1) {
    try {
      await copyOne(fromNames[i], toNames[i]);
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'extensions:copy-secrets');
    }
  }
}

/// Everything the keychain holds, or null when it will not say.
///
/// `readAll` is not available everywhere this app runs. On macOS it answers
/// errSecParam (-50) against the FILE keychain this build has to use, so a
/// caller that treats enumeration as reliable does nothing at all and reports
/// a platform exception instead of the work it skipped. Null is the answer
/// that lets a caller fall back to names it can construct.
Future<Map<String, String>?> _readAllOrNull(FlutterSecureStorage storage, {required String context}) async {
  if (_enumerationRefused) return null;
  try {
    return await storage.readAll();
  } catch (e, stack) {
    // Latched only for errSecParam, which is the platform saying it cannot do
    // this AT ALL — the macOS file keychain, which does not become listable
    // later in the same run. Remembering it saves a migration seven slow round
    // trips at boot to be told the same thing seven times.
    //
    // Not for anything else. A locked keychain (errSecInteractionNotAllowed)
    // is a moment, not a platform, and latching on it would downgrade every
    // later call for the life of the process — including the uninstall, which
    // then falls back to the two account items it can name and leaves every
    // `settingsPanel_secret_` behind. Silently resurrecting a credential the
    // operator removed is the failure this whole file exists to prevent.
    if (e is PlatformException && e.details is int && e.details == _errSecParam) {
      _enumerationRefused = true;
    }
    ErrorReportingService.report(e, stack, context: context);
    return null;
  }
}

/// Whether [error] is the keychain saying the item is not there: macOS 26
/// answers a delete of a missing item with errSecMissingEntitlement (-34018)
/// rather than errSecItemNotFound (-25300).
bool isKeychainItemMissing(Object error) => error is PlatformException && (error.details == -34018 || error.details == -25300);

/// What macOS answers a `readAll` against the file keychain (ErrorPolicy's
/// `keychain-cannot-enumerate` rule reads the same value).
const _errSecParam = -50;

/// Whether this platform has already refused to list the keychain.
///
/// Never reset. A keychain that cannot be enumerated at all is the macOS file
/// keychain, which does not become listable later in the same run.
bool _enumerationRefused = false;

/// Lets a test start from a platform that has not answered yet.
@visibleForTesting
void debugResetKeychainEnumeration() => _enumerationRefused = false;

/// What [storedKey] would be called under [to], or null when it is not
/// [from]'s to rename.
String? _renamed(String storedKey, {required String from, required String to}) {
  for (final prefix in _prefixesFor(from)) {
    if (storedKey.startsWith(prefix)) {
      return prefix.replaceFirst('_${from}_', '_${to}_') + storedKey.substring(prefix.length);
    }
  }
  if (storedKey.startsWith(_docked)) {
    if (renamedExtensionPanelId(storedKey.substring(_docked.length), from: from, to: to) case final rest?) return '$_docked$rest';
  }
  final exactFrom = _exactFor(from);
  final index = exactFrom.indexOf(storedKey);
  return index < 0 ? null : _exactFor(to)[index];
}

/// Whether the keychain item [storedKey] is one extension [key] owns.
bool isExtensionKeychainItemOf(String storedKey, String key) =>
    _prefixesFor(key).any(storedKey.startsWith) || _exactFor(key).contains(storedKey) || _isDockedSecretOf(storedKey, key);

/// Removes every keychain item [key] owned — its settings-panel secrets, its
/// docked panels' secrets and its account credentials — and answers whether
/// every one is known to be gone.
///
/// A reinstall inheriting these is the resurrection `forgetPanelConfig`
/// exists to prevent, and the uninstall dialog says they are removed.
/// [deleteOne] removes an account item with the options its writer used,
/// and answers whether it is gone: an item written with one set of keychain
/// options is not found by a delete issued with another. The account pair is
/// named outright as well as listed, since a listing need not include items
/// stored under other options.
///
/// [named] adds names known some other way — what the extension declares,
/// what the app recorded writing — for a keychain that will not list; only
/// those [key] owns are removed.
///
/// False when the keychain would not list for a reason that may pass (a
/// locked keychain), or when a delete failed: the caller tries again rather
/// than recording it done. Where the platform cannot list at all (the macOS
/// file keychain), only [named] and the account pair are removed: true once
/// those are gone when [namedIsEverything], and false otherwise, since
/// nothing then says what else is there.
Future<bool> forgetExtensionKeychainItems(
  FlutterSecureStorage storage,
  String key, {
  required Future<bool> Function(String name) deleteOne,
  Iterable<String> named = const [],
  bool namedIsEverything = true,
}) async {
  final stored = await _readAllOrNull(storage, context: 'extension-uninstall:secrets');
  var complete = stored != null || (_enumerationRefused && namedIsEverything);
  final names = {
    ..._exactFor(key),
    ...[...?stored?.keys, ...named].where((k) => isExtensionKeychainItemOf(k, key)),
  };
  for (final name in names) {
    try {
      if (_isAccountItem(name)) {
        if (!await deleteOne(name)) complete = false;
      } else {
        await storage.delete(key: name);
      }
    } catch (e, stack) {
      // Reported, not swallowed: credentials outliving the extension that
      // owned them is the thing this exists to prevent, so failing at it
      // silently is the one outcome worth knowing about.
      complete = false;
      ErrorReportingService.report(e, stack, context: 'extension-uninstall:secrets');
    }
  }
  return complete;
}

/// Whether the keychain will list what it holds — without which only names
/// known some other way can be removed.
Future<bool> keychainLists(FlutterSecureStorage storage) async => await _readAllOrNull(storage, context: 'extension-install:secrets') != null;

/// Whether every keychain item [from] owns has its copy under [to]
/// ([copyExtensionKeychainItems]) — what makes [from]'s safe to remove. A
/// copy that failed, or a login the operator has since removed from [to],
/// both answer false, and [from]'s stay. [readOne] reads an account item
/// with the options its writer used.
Future<bool> keychainItemsCopied(
  FlutterSecureStorage storage, {
  required String from,
  required String to,
  required Future<String?> Function(String name) readOne,
}) async {
  final stored = await _readAllOrNull(storage, context: 'extensions:retired-secrets');
  if (stored == null && !_enumerationRefused) return false;
  final names = {..._exactFor(from), ...?stored?.keys.where((k) => isExtensionKeychainItemOf(k, from))};
  for (final name in names) {
    final copy = _renamed(name, from: from, to: to);
    if (copy == null) continue;
    try {
      final held = _isAccountItem(name) ? await readOne(name) != null : stored!.containsKey(name);
      if (!held) continue;
      final copied = _isAccountItem(copy) ? await readOne(copy) != null : stored!.containsKey(copy);
      if (!copied) return false;
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'extensions:retired-secrets');
      return false;
    }
  }
  return true;
}
