// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension accounts: the `account` hooks and the platform keychain their
// credentials and sessions live in, with the per-account sync flag every
// keychain operation for a key has to agree on.

part of 'extension_service.dart';

mixin _ExtensionAccounts {
  // Owned by the class or by another part of this library.
  ExtensionHost? get host;
  ExtensionHost? get _host;
  Future<void>? get _starting;

  static const _keychainAccountName = 'Ham2K Logger';

  final _secureStorage = const FlutterSecureStorage(
    mOptions: MacOsOptions(
      // FILE keychain on macOS. The data-protection keychain needs the RESTRICTED
      // keychain-access-groups entitlement, which a Developer ID build can't
      // carry (no provisioning profile → spawn crash), so it fails every
      // save with errSecMissingEntitlement (-34018). The file keychain needs no
      // entitlement and works under the sandbox.
      // A future Mac App Store build has a profile and can switch back.
      usesDataProtectionKeychain: false,
      accountName: _keychainAccountName,
    ),
    iOptions: IOSOptions(accountName: _keychainAccountName),
  );

  /// Per-account iCloud Keychain sync flag (`kSecAttrSynchronizable`), keyed
  /// by account `kvKey`, as declared by each extension's `account` hook
  /// (`synchronizable`, default false). Resolved ONCE from the account
  /// definitions at runtime start (see [_refreshAccountSynchronizable], called
  /// from [_start], which also covers every restart) so that every read/write/
  /// delete for a given key uses the SAME flag: a synchronizable and a
  /// non-synchronizable item are DISTINCT keychain entries, so a mismatch
  /// would silently miss. An unknown key defaults to false — the fail-safe is
  /// "never accidentally sync". Only `account_creds_`/`account_session_` items
  /// consult this; secret settings fields stay device-local (the default).
  final Map<String, bool> _accountSynchronizable = {};

  /// The resolved flags, so a test can assert the boot-time refresh actually
  /// captured them. Nothing else observes this map directly — its effect is a
  /// keychain option on a platform tests don't run on — so without this the
  /// only provable symptom of the refresh failing is a log line.
  @visibleForTesting
  Map<String, bool> get accountSynchronizable => Map.unmodifiable(_accountSynchronizable);

  /// Completes once [_refreshAccountSynchronizable] has resolved the flags for
  /// the current runtime generation (or start failed) — reset per [_start],
  /// completed in its `finally`. Account access awaits this so an early lookup
  /// (the lookup queue gates on [ready], which flips true before the flags are
  /// cached) can't read a synchronizable account under the wrong flag and miss
  /// it. A fresh, never-started service leaves it pending, so
  /// [_accountKeychainOptions] only awaits it when a start is actually in play.
  Completer<void> _accountSyncReady = Completer<void>();

  /// True while [_refreshAccountSynchronizable] is in flight.
  ///
  /// The refresh asks the kernel for the account definitions, and the kernel
  /// answers by CALLING BACK into Dart (`getAccount`, to build the hook ctx for
  /// any account member that is a function). Without this flag that host call
  /// waits on [_accountSyncReady] — the completer the refresh itself is on its
  /// way to completing — and the two wait on each other until the hook times
  /// out. See [_accountKeychainOptions].
  bool _refreshingAccountSynchronizable = false;

  /// See [AccountContextCache] for what this is and the invariant every
  /// writer of an account item below keeps.
  final _accountItems = AccountContextCache();

  /// The bypass flag as a seam, so a test can pin that a read made while the
  /// flag refresh is in flight never lands in the cache.
  @visibleForTesting
  set debugRefreshingAccountSynchronizable(bool value) => _refreshingAccountSynchronizable = value;

  /// Rebuilds [_accountSynchronizable] from the current account definitions.
  /// Best-effort: a failure leaves accounts device-local, never crashes boot.
  Future<void> _refreshAccountSynchronizable() async {
    _refreshingAccountSynchronizable = true;
    try {
      final accounts = await getAccounts();
      // Couldn't ask (already logged by getAccounts). Leave whatever the last
      // successful refresh resolved in place rather than wiping it: on a
      // restart, stale flags still describe the accounts the user has, while
      // an empty map silently reads and writes every account under the
      // device-local default — the exact miss this cache exists to prevent.
      if (accounts == null) return;
      _accountSynchronizable
        ..clear()
        ..addEntries(accounts.where((a) => a['kvKey'] is String).map((a) => MapEntry(a['kvKey'] as String, a['synchronizable'] == true)));
    } catch (e) {
      debugPrint('[extensions] refreshAccountSynchronizable failed: $e');
    } finally {
      _refreshingAccountSynchronizable = false;
    }
  }

  /// The complete keychain options for one account's items, matching the
  /// instance defaults but with the account's declared `synchronizable` flag.
  /// Per-call options REPLACE (don't merge with) the instance defaults, so
  /// the data-protection-keychain and account-name settings are repeated here.
  ///
  /// Awaits [_accountSyncReady] first (only while a start is in flight, so a
  /// never-started service doesn't hang) so the flag is resolved before the
  /// first read/write. Near-free once the flags are cached.
  ///
  /// macOS: a synchronizable item requires the data-protection keychain, but the
  /// app uses the FILE keychain on macOS (Developer ID can't carry the
  /// keychain-access-groups entitlement the data-protection keychain needs — see
  /// the instance default), so macOS accounts are never synchronizable and stay
  /// device-local. iOS always uses the data-protection keychain, so it syncs when
  /// the account declares it. Both keep `synchronizable` and
  /// `usesDataProtectionKeychain` from ever contradicting.
  /// [fromHostCall] marks the calls the extension runtime makes back into us
  /// while a hook is running. Those must never wait on [_accountSyncReady]
  /// during [_refreshAccountSynchronizable]: the refresh is what completes that
  /// completer, and it cannot finish until the hook it is waiting on returns —
  /// which cannot happen until this call does. Deliberately NOT a blanket
  /// bypass: direct Dart callers (a lookup firing as soon as [ready] flips)
  /// still wait, because getting them the right flag is the whole reason the
  /// gate exists.
  ///
  /// Bypassing yields the device-local defaults. Without the bypass the
  /// refresh deadlocks and times out, leaving the flag map empty for the
  /// whole session — so the bypass is never worse, and unlike the deadlock
  /// the flags are correct a moment later.
  Future<({MacOsOptions mOptions, IOSOptions iOptions})> _accountKeychainOptions(String kvKey, {bool fromHostCall = false}) async {
    final wouldDeadlock = fromHostCall && _refreshingAccountSynchronizable;
    if (!wouldDeadlock && !_accountSyncReady.isCompleted && (_starting != null || _host != null)) {
      await _accountSyncReady.future;
    }
    final declared = _accountSynchronizable[kvKey] ?? false;
    return (
      mOptions: MacOsOptions(
        // File keychain on macOS (see the instance default), so accounts can't
        // be synchronizable here — kSecAttrSynchronizable requires the
        // data-protection keychain, which Developer ID can't use. macOS account
        // creds stay device-local; iOS (always data-protection) still syncs when
        // the account declares it.
        usesDataProtectionKeychain: false,
        accountName: _keychainAccountName,
        synchronizable: false,
      ),
      iOptions: IOSOptions(accountName: _keychainAccountName, synchronizable: declared),
    );
  }

  /// Every extension-declared account, or null when the extensions could not
  /// be asked at all — no runtime yet, a dead one, or the fan-out failing or
  /// timing out. That is deliberately distinct from an empty list ("asked,
  /// and nobody declares an account"): the two look identical to a caller but
  /// mean opposite things, and a caller that caches the answer must never
  /// cache a failure (see settings_view's `_accountsCache`). Failures are
  /// logged here rather than thrown, so a caller that has nothing better to do
  /// can still treat null as "no accounts" with `?? const []`.
  Future<List<Map<String, dynamic>>?> getAccounts() async {
    final host = this.host;
    if (host == null) return null;
    try {
      final entries = await host.invokeHookAll('account', method: 'getDefinition', timeout: const Duration(seconds: 2));
      final accounts = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          accounts.add((entry['value'] as Map).cast<String, dynamic>());
        }
      }
      return accounts;
    } catch (e) {
      debugPrint('[extensions] getAccounts failed: $e');
      return null;
    }
  }

  Future<String> testCredentials(String accountKey, Map<String, String> credentials) async {
    final host = this.host;
    if (host == null) return t.extensionService.runtimeNotReady;
    try {
      final dynamic res = await host.invokeHook('account', key: accountKey, method: 'testCredentials', args: credentials, timeout: const Duration(seconds: 10));
      return res is String ? res : res?.toString() ?? '';
    } catch (e) {
      return t.extensionService.testFailed(error: e);
    }
  }

  /// The credentials stored for [kvKey]: a map, `{}` when nothing is stored —
  /// and NULL when secure storage could not be reached at all.
  ///
  /// The distinction is the whole point. An empty map means "this account is not
  /// connected", which is a fact about the account; null means "we cannot know",
  /// which is a fact about the machine — a Linux box with no Secret Service
  /// running, a locked keyring. Collapsing the two would tell an operator
  /// they had been logged out, and invite them to log in again into a store that
  /// cannot keep it.
  ///
  /// Never let this throw: `_loadAccounts` would spin forever and the account
  /// dialog would render with no fields at all, because both read it before
  /// their own `setState`.
  Future<Map<String, String>?> getAccountCredentials(String kvKey) async {
    final o = await _accountKeychainOptions(kvKey);
    final String? raw;
    try {
      raw = await _secureStorage.read(key: 'account_creds_$kvKey', mOptions: o.mOptions, iOptions: o.iOptions);
    } catch (e, st) {
      // EVERYTHING, not just PlatformException: a build where the plugin failed
      // to register raises MissingPluginException, and catching only the former
      // would reopen the exact hang this exists to prevent — `_loadAccounts`
      // reads this before its own `setState`. `KeyringLocked` on Linux covers three
      // different situations anyway (no Secret Service, no default collection,
      // one that would not unlock), so nothing here claims which.
      debugPrint('[extensions] secure storage unavailable reading $kvKey: $e');
      ErrorReportingService.report(e, st, context: 'accounts:read-credentials');
      return null;
    }
    // The keychain answered, and what it holds may differ from the copy — a
    // failure that has since cleared, or a synced item from another device.
    // The session is unknown here, so the entry is evicted rather than
    // rewritten and the next host call rereads both.
    _accountItems.remove(kvKey);
    if (raw == null) return const {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return const {};
    }
  }

  Future<void> setAccountCredentials(String kvKey, Map<String, String> credentials) async {
    final o = await _accountKeychainOptions(kvKey);
    final encoded = jsonEncode(credentials);
    await _secureStorage.write(key: 'account_creds_$kvKey', value: encoded, mOptions: o.mOptions, iOptions: o.iOptions);
    // Any stored session was derived from the OLD credentials — e.g. OAuth
    // tokens refreshed from a previous login — and could keep acting as the
    // previous account if left behind.
    // A copy saying "no session" over a keychain that still holds the old
    // one would hide that leak until the next launch reads it back.
    if (await _deleteAccountItem('account_session_$kvKey', o)) {
      _accountItems[kvKey] = AccountItems(creds: encoded, session: null);
    } else {
      _accountItems.remove(kvKey);
    }
    // Fresh credentials must reach the very next hook call, not whatever
    // the kernel's context cache still holds.
    _host?.invalidateHookContext();
  }

  Future<void> clearAccount(String kvKey) async {
    final o = await _accountKeychainOptions(kvKey);
    await _deleteAccountItem('account_creds_$kvKey', o);
    await _deleteAccountItem('account_session_$kvKey', o);
    _accountItems.remove(kvKey);
    _host?.invalidateHookContext();
  }

  /// Best-effort keychain delete. Deleting an item that doesn't exist is
  /// fine everywhere except macOS 26, which reports it as
  /// errSecMissingEntitlement (-34018) instead of "not found" — so delete
  /// failures are logged, never thrown. Answers whether the delete went
  /// through, for a caller whose cached copy must not claim more than that.
  Future<bool> _deleteAccountItem(String key, ({MacOsOptions mOptions, IOSOptions iOptions}) o) async {
    try {
      await _secureStorage.delete(key: key, mOptions: o.mOptions, iOptions: o.iOptions);
      return true;
    } catch (e) {
      debugPrint('[extensions] keychain delete $key failed (ignored): $e');
      return false;
    }
  }

  /// Copies every keychain item [from] owned onto [to] — the keychain half
  /// of what `SettingsService.copyExtensionRecords` does for prefs, and what
  /// keeps an operator logged in when an extension changes its key.
  Future<void> copyExtensionSecrets({required String from, required String to}) =>
      copyExtensionKeychainItems(_secureStorage, from: from, to: to, copyOne: _copyAccountItem);

  /// Reads one account item and writes it under another name, each with the
  /// options its own key resolves to. The fallback the keychain copy uses
  /// where the platform will not enumerate — and it has to go through
  /// [_accountKeychainOptions], because an item written under one set of
  /// options is not found by a read issued with another.
  Future<void> _copyAccountItem(String from, String to) async {
    final fromKey = from.replaceFirst(RegExp(r'^account_(creds|session)_'), '');
    final toKey = to.replaceFirst(RegExp(r'^account_(creds|session)_'), '');
    final fromOptions = await _accountKeychainOptions(fromKey);
    final toOptions = await _accountKeychainOptions(toKey);
    if (await _secureStorage.read(key: to, mOptions: toOptions.mOptions, iOptions: toOptions.iOptions) != null) return;
    final value = await _secureStorage.read(key: from, mOptions: fromOptions.mOptions, iOptions: fromOptions.iOptions);
    if (value == null) return;
    await _secureStorage.write(key: to, value: value, mOptions: toOptions.mOptions, iOptions: toOptions.iOptions);
  }
}
