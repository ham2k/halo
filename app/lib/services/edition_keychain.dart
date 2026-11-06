// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where each edition keeps its secrets on macOS, and the one-time move of an
// install's secrets out of the keychain name all the editions share.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/version.dart';
import 'error_reporting_service.dart';

/// The iOS keychain service. Data-protection items belong to the app's own
/// access group, so the editions cannot collide there and share this name.
const iosKeychainService = 'Ham2K Logger';

/// The keychain service (the item's name in Keychain Access) this edition's
/// secrets belong under on macOS — one per edition. The editions install side
/// by side as different apps, and the file keychain trusts only the apps on
/// an item's access list: an item another edition created makes this one ask
/// for the login keychain password ("…wants to use your confidential
/// information stored in …").
String get editionMacKeychainService => switch (kEdition) {
  Edition.prod => 'Ham2K Power Logger',
  Edition.next => 'Ham2K Power Logger (Next)',
  Edition.dev => 'Ham2K Power Logger (Dev)',
};

/// The macOS service every edition shares, where an install that ran before
/// [editionMacKeychainService] existed has its secrets. Only
/// [MacKeychainMove] reads it, and nothing deletes from it: another edition
/// may still be using what is there.
const sharedMacKeychainService = 'Ham2K Logger';

/// The macOS service this launch reads and writes: the edition's own once the
/// install's secrets have moved, the shared one until then.
String get macKeychainService => MacKeychainMove.pending ? sharedMacKeychainService : editionMacKeychainService;

/// macOS options for this edition's items, under [macKeychainService] as it
/// is at the moment of the call — read it per call, never keep it.
///
/// The FILE keychain, not the data-protection keychain: that one needs the
/// `keychain-access-groups` entitlement, which is RESTRICTED — a Developer ID
/// direct-download build has no provisioning profile to validate it, so
/// ADDING it makes the app fail to spawn and NOT adding it makes every save
/// throw errSecMissingEntitlement (-34018). The file keychain needs no
/// entitlement and works under the sandbox, but it cannot hold a
/// synchronizable item, so macOS secrets stay on the device.
MacOsOptions get macKeychainOptions => _macOptions(macKeychainService);

MacOsOptions _macOptions(String service, {bool allowDialog = true}) =>
    MacOsOptions(usesDataProtectionKeychain: false, accountName: service, authenticationUIBehavior: allowDialog ? null : _authenticationUIFail);

/// `kSecUseAuthenticationUIFail`: a query that would need the operator's
/// approval fails (errSecInteractionNotAllowed) instead of showing a dialog.
const _authenticationUIFail = 'u_AuthUIF';

bool get _onMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// [FlutterSecureStorage] under this edition's keychain service: on macOS
/// [macKeychainService], resolved on every call because a move finishing
/// mid-session switches it; on iOS [iosKeychainService].
class EditionSecureStorage extends FlutterSecureStorage {
  EditionSecureStorage() : super(iOptions: const IOSOptions(accountName: iosKeychainService));

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => super.read(
    key: key,
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions ?? macKeychainOptions,
    wOptions: wOptions,
  );

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    // A change under the shared name while a move reads it; see MacKeychainMove._touched.
    MacKeychainMove._touch(key);
    return super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions ?? macKeychainOptions,
      wOptions: wOptions,
    );
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    // A change under the shared name while a move reads it; see MacKeychainMove._touched.
    MacKeychainMove._touch(key);
    return super.delete(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions ?? macKeychainOptions,
      wOptions: wOptions,
    );
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => super.containsKey(
    key: key,
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions ?? macKeychainOptions,
    wOptions: wOptions,
  );

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => super.readAll(
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions ?? macKeychainOptions,
    wOptions: wOptions,
  );

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => super.deleteAll(
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions ?? macKeychainOptions,
    wOptions: wOptions,
  );
}

/// The one-time move, on macOS, of an install's secrets from
/// [sharedMacKeychainService] to [editionMacKeychainService].
///
/// A first install has nothing to move and starts under its own name: its
/// preferences are empty the first time [start] runs. Any other install reads
/// every item under the shared name, without letting macOS ask for the
/// keychain password, and only once all of them are read writes them under
/// its own name and switches. Until then it stays [pending] and keeps using
/// the shared name, and the operator is told and decides: [retry], which may
/// show that dialog, or [continueWithout]. Each later launch tries again
/// silently first.
///
/// The move never replaces or deletes an item it finds already under the
/// edition's name: that is another install of this edition (a second build,
/// a developer data sandbox), whose secrets are not this move's to change.
abstract final class MacKeychainMove {
  static const _movedPref = 'keychain.moved';
  static const _splitPref = 'keychain.splitSyncClient';
  static const _channel = MethodChannel('ham2k/keychain');

  /// The plugin itself: the move names every service explicitly, and must
  /// not be redirected by [EditionSecureStorage].
  static const _storage = FlutterSecureStorage();

  static SharedPreferences? _prefs;
  static bool _pending = false;
  static Future<bool>? _running;

  /// Keys this install wrote or deleted under the shared name while an
  /// attempt was reading it: the value read may already be stale, so each is
  /// read again before the switch. Without this, a secret saved during a
  /// Retry or Continue would be left behind, and the switch would answer the
  /// older copy.
  static final _touched = <String>{};

  /// Whether a silent read under the shared name was refused: an item another
  /// edition created, so the device key this install brings along may be that
  /// edition's too. The evidence a sync client split is decided on.
  static bool _anotherEdition = false;

  /// Whether this install's secrets are still under the shared name.
  static bool get pending => _pending;

  /// Notes a write or delete through [EditionSecureStorage].
  static void _touch(String key) {
    if (_pending) _touched.add(key);
  }

  /// Whether this install, having moved, still has to give itself a sync
  /// client of its own: another edition evidently used the shared name, and
  /// editions sharing one client share its sync cooldown. See
  /// `HaLoServices.splitSyncClientIfDue`.
  static bool get syncClientSplitDue => !_pending && (_prefs?.getBool(_splitPref) ?? false);

  /// The split is done, or has nothing to do.
  static Future<void> settleSyncClientSplit() async {
    try {
      await _prefs?.remove(_splitPref);
    } catch (e, st) {
      // Asked again on the next launch, which only splits once more.
      ErrorReportingService.report(e, st, context: 'keychain:move');
    }
  }

  /// Once per launch, after the preferences have been relocated or recovered
  /// and before anything reads the keychain or writes a preference.
  static Future<void> start(SharedPreferences prefs) async {
    if (!_onMacOS) return;
    _prefs = prefs;
    final moved = prefs.getBool(_movedPref);
    if (moved == true) return;
    if (moved == null && prefs.getKeys().isEmpty) {
      // Under its own name even if the flag cannot be saved: the shared
      // name holds only other editions' items, and reading one of those is
      // the password dialog this whole move exists to avoid.
      await _saveMoved();
      return;
    }
    _pending = true;
    try {
      await prefs.setBool(_movedPref, false);
    } catch (e, st) {
      // Already pending, and the attempt below still runs. What the flag
      // keeps is the decision that this install is not a first one, for a
      // next launch whose preferences are still empty.
      ErrorReportingService.report(e, st, context: 'keychain:move');
    }
    await _attempt(allowDialog: false, regardless: false);
  }

  /// Reads again, letting macOS ask for the login keychain password for an
  /// item only it can release, and moves if everything was read.
  static Future<bool> retry() => _attempt(allowDialog: true, regardless: false);

  /// Moves with what can be read without a dialog; what stayed behind is
  /// entered again where it is needed.
  static Future<void> continueWithout() async {
    await _running;
    if (_pending) await _attempt(allowDialog: false, regardless: true);
  }

  /// One attempt at a time: a second caller waits on the first.
  static Future<bool> _attempt({required bool allowDialog, required bool regardless}) {
    if (!_pending) return Future.value(true);
    return _running ??= _move(allowDialog: allowDialog, regardless: regardless).whenComplete(() => _running = null);
  }

  /// Reads every item under the shared name, then — when all were read, or
  /// [regardless] — writes them under the edition's name, saves the move and
  /// switches. A failed attempt leaves nothing under the edition's name.
  ///
  /// The switch waits for the flag to be saved. A launch that switched
  /// without it would move again on the next one, past everything written
  /// under the edition's name in between.
  static Future<bool> _move({required bool allowDialog, required bool regardless}) async {
    _touched.clear();
    final values = <String, String?>{};
    Object? failure;
    StackTrace? failureStack;
    // Anything, not only a keychain refusal: this runs at boot, and a listing
    // the runner cannot answer (MissingPluginException) must leave the
    // install where it is rather than stop the app.
    try {
      final from = _macOptions(sharedMacKeychainService, allowDialog: allowDialog);
      for (final key in await _listKeys(sharedMacKeychainService)) {
        try {
          values[key] = await _storage.read(key: key, mOptions: from);
        } on PlatformException catch (e, st) {
          if (!allowDialog) _anotherEdition = true;
          failure ??= e;
          failureStack ??= st;
        }
      }
    } catch (e, st) {
      failure ??= e;
      failureStack ??= st;
    }
    if (failure != null) {
      _report(failure, failureStack);
      if (!regardless) return false;
    }

    final written = <String>{};
    try {
      for (final MapEntry(:key, :value) in values.entries) {
        await _commit(key, value, written);
      }
      await _carryTouched(written);
      if (!await _saveMoved(splitSyncClient: _anotherEdition)) throw StateError('the move could not be saved');
    } catch (e, st) {
      if (e is! StateError) _report(e, st);
      for (final key in written) {
        try {
          await _storage.delete(key: key, mOptions: _macOptions(editionMacKeychainService));
        } catch (_) {
          // Left behind, it is only a copy the next attempt will not replace.
        }
      }
      return false;
    }
    // Saved: whatever lands under the shared name from here until the switch
    // is carried too, and the switch follows the last check with nothing in
    // between, so no write can fall between the two names.
    await _carryTouched(written);
    _pending = false;
    return true;
  }

  /// Puts [value] under the edition's name for [key] — or, for null, takes
  /// away what this move put there — unless the item there is not one this
  /// move wrote.
  static Future<void> _commit(String key, String? value, Set<String> written) async {
    final to = _macOptions(editionMacKeychainService);
    if (!written.contains(key) && await _storage.containsKey(key: key, mOptions: to)) return;
    if (value == null) {
      if (written.remove(key)) await _storage.delete(key: key, mOptions: to);
      return;
    }
    await _storage.write(key: key, value: value, mOptions: to);
    written.add(key);
  }

  /// Reads again, and commits, every key written under the shared name since
  /// it was read, until no more arrive. These are this install's own writes,
  /// so they read without a dialog; one that cannot be carried is reported
  /// and left behind rather than holding up the switch.
  static Future<void> _carryTouched(Set<String> written) async {
    final from = _macOptions(sharedMacKeychainService, allowDialog: false);
    while (_touched.isNotEmpty) {
      final keys = {..._touched};
      _touched.clear();
      for (final key in keys) {
        try {
          await _commit(key, await _storage.read(key: key, mOptions: from), written);
        } catch (e, st) {
          _report(e, st);
        }
      }
    }
  }

  static void _report(Object error, StackTrace? stackTrace) =>
      ErrorReportingService.report(KeychainMoveIncomplete(error), stackTrace, context: 'keychain:move');

  static Future<Set<String>> _listKeys(String service) async {
    final keys = await _channel.invokeListMethod<String>('listKeys', {'service': service});
    return {...?keys};
  }

  /// Saves the move as done; [splitSyncClient] when another edition evidently
  /// shared the name the secrets came from.
  static Future<bool> _saveMoved({bool splitSyncClient = false}) async {
    try {
      if (splitSyncClient) await _prefs!.setBool(_splitPref, true);
      await _prefs!.setBool(_movedPref, true);
      return true;
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'keychain:move');
      return false;
    }
  }

  @visibleForTesting
  static void reset() {
    _prefs = null;
    _pending = false;
    _running = null;
    _touched.clear();
    _anotherEdition = false;
  }
}

/// What a keychain move ([MacKeychainMove]) reports when an item could not
/// be read or carried: the [cause] the keychain gave. ErrorPolicy decides
/// what that deserves — a refusal is the expected answer for an item another
/// edition created, and the move's own notice already tells the operator.
class KeychainMoveIncomplete implements Exception {
  final Object cause;

  const KeychainMoveIncomplete(this.cause);

  @override
  String toString() => 'Keychain move incomplete: $cause';
}
