// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What is installed and what loads: the available-extension index, `.h2kext`
// installs and uninstalls, dev-served bundles, and the enable/availability
// rules that decide the runtime's bundle set.

part of 'extension_service.dart';

/// Whether a dev-loop reload of one extension can be swapped into the running
/// runtime, or whether the runtime has to be restarted around it.
///
/// [alreadyDevServed] is the one that is easy to leave out and expensive to get
/// wrong. Build secrets are resolved ONCE, when the runtime starts, and a
/// reload deliberately does not re-resolve them — so an extension whose slot
/// was filled from the app's own assets is holding the secrets that come with
/// that, and swapping dev code into it hands them over. The reachable path is
/// not exotic: an extension that fails its FIRST build is left out of the dev
/// server's index, so the app loads that key from assets, and the author's next
/// successful save is a reload of a key that already holds real credentials
/// (HALO-425). Restarting re-resolves them against the dev provenance, which is
/// the only thing that makes them absent.
///
/// [capabilitiesUnchanged] covers the manifest flags a reload cannot carry:
/// `domains` travels with the bundle, but the rest are start-time allowlists
/// in the host ([ExtensionInfo.sameStartTimeCapabilities]).
@visibleForTesting
bool canHotSwapDevBundle({required bool runtimeAlive, required bool alreadyLoaded, required bool alreadyDevServed, required bool capabilitiesUnchanged}) =>
    runtimeAlive && alreadyLoaded && alreadyDevServed && capabilitiesUnchanged;

/// The extensions the app offers with a dev server connected: each [dev] entry
/// REPLACES the asset extension of the same key — which is what lets an author
/// iterate on a core extension itself rather than only on something new — and
/// a dev extension with a key nothing ships is appended.
///
/// Asset order is preserved, so connecting a dev server does not reshuffle the
/// Extensions panel under the operator. Two dev entries claiming one key cannot
/// happen: they arrive from a map keyed by exactly that.
List<ExtensionInfo> mergeDevExtensions(List<ExtensionInfo> fromAssets, List<ExtensionInfo> dev) {
  if (dev.isEmpty) return fromAssets;
  final byKey = {for (final info in dev) info.key: info};
  final unplaced = {...byKey.keys}..removeAll(fromAssets.map((info) => info.key));
  return [for (final info in fromAssets) byKey[info.key] ?? info, for (final key in unplaced) byKey[key]!];
}

mixin _ExtensionInstalls {
  // Owned by the class or by another part of this library.
  ExtensionHost? get host;
  ExtensionHost? get _host;
  SettingsService? get settings;
  StatusBarService? get statusBar;
  CatalogService? get catalog;
  ValueNotifier<int> get runtimeGeneration;
  Set<String> get _loadedExtensionKeys;
  set _commandCatalog(List<Map<String, dynamic>>? value);
  Future<void>? get _restartFuture;
  Future<void> restartRuntime({bool fresh});
  void invalidateHookContext();
  FlutterSecureStorage get _secureStorage;
  Future<({MacOsOptions mOptions, IOSOptions iOptions})> _accountKeychainOptions(String kvKey, {bool fromHostCall});
  Future<bool> _deleteAccountItem(String key, ({MacOsOptions mOptions, IOSOptions iOptions}) o);
  Future<void> copyExtensionSecrets({required String from, required String to});

  /// One extension's JS, from wherever that extension came from.
  Future<String> _sourceFor(ExtensionInfo info) async {
    final dev = _devBundles[info.key];
    if (dev != null) return dev.source;
    if (info.isInstalled) return _requireInstalledStore().sourceFor(info.key);
    return rootBundle.loadString('assets/extensions/${info.file}');
  }

  /// Reads the list again — after anything that changes what is installed.
  /// The one held is kept until the new one is in hand: dropped first, every
  /// reader sees no extensions at all for the length of the read.
  Future<void> reloadAvailableExtensions() => loadAvailableExtensions(force: true);

  /// The catalog's copy of every retired built-in the operator had ON.
  Future<({bool landed, bool complete})> adoptTwins() => adoptCatalogTwins(
    store: _installed,
    settings: settings,
    catalog: catalog,
    available: availableExtensions,
    recordInstall: _recordInstall,
    copySecrets: copyExtensionSecrets,
  );

  /// The extensions the operator installed that the store does not hold
  /// (`SettingsService.extensionsInstalled`), and where each could come
  /// back from. None while the store cannot be read: that is a store
  /// failing, and offering everything back into it would fail every time.
  List<MissingExtension> missingExtensions() {
    final currentSettings = settings;
    final present = _installed?.storedKeys;
    if (currentSettings == null || present == null) return const [];
    final records = currentSettings.extensionInstalledFrom;
    final catalogHost = catalog?.host;
    return [
      for (final MapEntry(:key, value: name) in currentSettings.extensionsInstalled.entries)
        if (!present.contains(key))
          MissingExtension(
            key: key,
            name: name,
            from: switch (BundleProvenance.fromJson(records[key])?.host) {
              null => MissingFrom.file,
              kPreloadHost => MissingFrom.shipped,
              final host when host == catalogHost => MissingFrom.catalog,
              _ => MissingFrom.otherCatalog,
            },
          ),
    ];
  }

  /// Installs [entry]'s release as an extension the operator already had —
  /// never fresh, since their settings and on/off choice are still under its
  /// key — without restarting the runtime.
  Future<void> reinstallFromCatalog(CatalogEntry entry) =>
      installCatalogEntry(store: _requireInstalledStore(), catalog: catalog!, entry: entry, recordInstall: _recordInstall);

  /// Drops a missing extension from what the operator has installed, with
  /// everything it stored — the uninstall of one that is already gone, and
  /// like one, it leaves a shipped bundle switched off.
  Future<void> forgetMissingExtension(String key) async {
    await settings?.forgetExtension(key);
    await _leaveShippedSwitchedOff(key);
    await forgetExtensionKeychainItems(_secureStorage, key, deleteOne: (name) async => _deleteAccountItem(name, await _accountKeychainOptions(key)));
  }

  /// Installs the `.h2kext` bundles the app ships, and answers whether
  /// anything landed — the caller re-reads the store when it did.
  Future<bool> preloadShippedExtensions() async {
    final currentSettings = settings;
    final store = _installed;
    if (currentSettings == null || store == null) return false;
    return installShippedExtensions(
      store: store,
      settings: currentSettings,
      installedVersions: {
        for (final info in availableExtensions)
          if (info.isInstalled) info.key: info.version,
      },
      recordInstall: (bundle, {required bool fresh}) => _recordInstall(bundle, fresh: fresh),
      copySecrets: copyExtensionSecrets,
      restoring: {
        for (final missing in missingExtensions())
          if (missing.from == MissingFrom.shipped) missing.key,
      },
    );
  }

  /// Installs an inspected `.h2kext` and reboots the runtime so it loads.
  ///
  /// The consent the operator gave belongs to the caller — this is the commit,
  /// and by here the asking has happened.
  Future<void> installBundle(InspectedBundle bundle) async {
    final store = _requireInstalledStore();
    // Asked BEFORE the write: afterwards the key is always there.
    final fresh = !await store.isInstalled(bundle.key);
    // Only on a FRESH install of catalog bytes: an update has its own state
    // already, and a file install of a `ham2k-` key never reaches here.
    final carried = fresh && bundle.provenance != null && await carryPredecessorRecords(key: bundle.key, settings: settings, copySecrets: copyExtensionSecrets);
    await store.install(bundle);
    // `fresh` drops a stale on/off choice; one just carried is not stale.
    await _recordInstall(bundle, fresh: fresh && !carried);
    // But the operator just chose to install it from the catalog, which is
    // choosing to run it: a switch carried from a built-in they had off, or
    // kept from a removal that left their settings in place, would land it
    // switched off.
    final currentSettings = settings;
    if (fresh && bundle.provenance != null && currentSettings != null && currentSettings.extensionOverrides[bundle.key] == false) {
      await currentSettings.setExtensionOverrides({...currentSettings.extensionOverrides, bundle.key: true});
    }
    // Re-read, not merely dropped: an empty list for the length of the
    // restart is every panel reading it losing all its rows until the new
    // generation is up, and the restart's own sweep deciding which
    // extensions return against nothing at all.
    await _reloadBeforeRestart();
    // [fresh]: a restart already in flight (a toggle's, another install's)
    // began before this bundle was written, and would load without it.
    await restartRuntime(fresh: true);
  }

  /// [reloadAvailableExtensions] ahead of a restart that must happen whatever
  /// it finds: a failure here leaves the list dropped for the boot to re-read,
  /// rather than skipping the restart that loads what was just written.
  Future<void> _reloadBeforeRestart() async {
    try {
      await reloadAvailableExtensions();
    } catch (e, stack) {
      // Dropped, so the boot re-reads it: the list still held predates what
      // was just written, and a boot from it would load without it.
      _availableExtensions = null;
      ErrorReportingService.report(e, stack, context: 'extensions:reload-before-restart');
    }
  }

  /// The settings an install touches. The provenance record is written for
  /// catalog bytes and cleared for any other: a file install of a key the
  /// catalog once served must not inherit the `ham2k-` waiver. Written on the
  /// track the key already follows, or the release's own when that is
  /// rougher — never narrower, which is what keeps an unstable install taking
  /// unstable releases after a stable one updates it. A revocation
  /// of another version is over. And a catalog install of a key the store
  /// did not have — the built-in that moved to the catalog, switched off by
  /// the operator while it was built in — drops the operator's override and
  /// the disabled-since stamp so it runs; an UPDATE keeps both, because a
  /// switch the operator turned off is not a newer version's to turn on.
  Future<void> _recordInstall(InspectedBundle bundle, {required bool fresh}) async {
    final currentSettings = settings;
    if (currentSettings == null) return;
    final records = {...currentSettings.extensionInstalledFrom};
    final provenance = bundle.provenance;
    if (provenance == null) {
      if (records.remove(bundle.key) != null) await currentSettings.setExtensionInstalledFrom(records);
    } else {
      records[bundle.key] = provenance.followingAtLeast(BundleProvenance.fromJson(records[bundle.key])).toJson();
      await currentSettings.setExtensionInstalledFrom(records);
    }
    await liftInstallRecordsForNewVersion(currentSettings, bundle.key, bundle.version);
    final intended = currentSettings.extensionsInstalled;
    if (intended[bundle.key] != bundle.name) await currentSettings.setExtensionsInstalled({...intended, bundle.key: bundle.name});
    if (provenance == null || !fresh) return;
    final overrides = currentSettings.extensionOverrides;
    if (overrides.remove(bundle.key) != null) await currentSettings.setExtensionOverrides(overrides);
    final disabledSince = currentSettings.extensionDisabledSince;
    if (disabledSince.remove(bundle.key) != null) await currentSettings.setExtensionDisabledSince(disabledSince);
  }

  /// Removes an installed extension and reboots without it.
  ///
  /// Everything it stored goes with it — its settings group and the operator's
  /// enable/disable override — which is what makes this an uninstall rather
  /// than an update. Left behind, they come back silently on a reinstall: old
  /// credentials, and an extension that lands disabled with nothing to say
  /// why.
  ///
  /// Except a bundle the app ships, whose switch is left off
  /// ([_leaveShippedSwitchedOff]). A catalog reinstall still lands on
  /// ([installBundle]).
  Future<void> uninstallExtension(String key) async {
    await _requireInstalledStore().uninstall(key);
    final currentSettings = settings;
    // At once: recorded as installed and gone from the store, it is missing,
    // and a catch-up a restart starts meanwhile puts it back.
    await currentSettings?.forgetExtensionInstalls({key});
    // Re-read, not merely dropped — see [installBundle]. And BEFORE its
    // override goes: forgetting it notifies the panel, and a row still listed
    // with no override reads as on — its switch flipping on for as long as
    // the keychain takes to clear.
    await _reloadBeforeRestart();
    await currentSettings?.forgetExtension(key);
    await _leaveShippedSwitchedOff(key);
    await forgetExtensionKeychainItems(_secureStorage, key, deleteOne: (name) async => _deleteAccountItem(name, await _accountKeychainOptions(key)));
    statusBar?.clearNamespace(key);
    await restartRuntime(fresh: true);
  }

  /// Records [key] switched off when it is a bundle the app pre-loads or a
  /// retired built-in's twin. The pre-load reads no switch as on — falling
  /// back to the built-in's, for a twin — so without it an app update
  /// carrying a newer copy, or the next launch for a twin the pre-load never
  /// recorded, installs again what the operator removed.
  Future<void> _leaveShippedSwitchedOff(String key) async {
    final currentSettings = settings;
    if (currentSettings == null) return;
    if (!currentSettings.extensionPreloaded.containsKey(key) && predecessorBuiltInKey(key) == null) return;
    await currentSettings.setExtensionOverrides({...currentSettings.extensionOverrides, key: false});
  }

  /// Takes [keys]' bundles out of the store, keeping the operator's settings,
  /// credentials and switch for each for whenever it comes back — but not
  /// where it came from ([SettingsService.forgetExtensionInstalls]) — and
  /// answers which came out. One that will not costs only
  /// itself, and is reported. Neither re-reads the list nor restarts: the
  /// caller does both, once.
  Future<Set<String>> removeKeepingSettings(Set<String> keys) async {
    final store = _requireInstalledStore();
    final removed = <String>{};
    for (final key in keys) {
      try {
        await store.uninstall(key);
        removed.add(key);
      } catch (e, stack) {
        ErrorReportingService.report(e, stack, context: 'extensions:remove-keeping-settings');
      }
    }
    if (removed.isNotEmpty) await settings?.forgetExtensionInstalls(removed);
    return removed;
  }

  /// The installed store, or a failure that names what was missing. A bare `!`
  /// here reports "Null check operator used on a null value", which says
  /// nothing about extensions to whoever reads it.
  InstalledExtensions _requireInstalledStore() {
    final store = _installed;
    if (store == null) {
      throw StateError('no installed-extension store yet — loadAvailableExtensions has not run');
    }
    return store;
  }

  /// The extensions the build index declares, with their user-facing
  /// metadata — readable without booting (or evaluating) any JS, so the
  /// Extensions panel can list DISABLED extensions and still render when
  /// the runtime is down. Memoized; [index] lets [_start] reuse its own
  /// parse, and [force] reads afresh past the memo.
  Future<List<ExtensionInfo>> loadAvailableExtensions({Map<String, dynamic>? index, bool force = false}) async {
    if (!force && _availableExtensions != null) return _availableExtensions!;
    final parsed = index ?? jsonDecode(await rootBundle.loadString('assets/extensions/index.json')) as Map<String, dynamic>;
    final fromAssets = [for (final entry in (parsed['extensions'] as List).cast<Map<String, dynamic>>()) ExtensionInfo.fromJson(entry)];
    _hostSharedModules = ((parsed['sharedModules'] as Map?) ?? const {}).cast<String, String>();
    // Built from the asset index, because what an installed bundle may NOT
    // call itself is exactly what the app already ships.
    final store = _installed ??= InstalledExtensions(
      builtInKeys: () => {for (final info in fromAssets) info.key},
      hostSharedModules: _hostSharedModules,
      // Read live too: the record is written by installBundle and
      // cleared by uninstall, and the store outlives both.
      reservedPrefixAllowed: (String key) => BundleProvenance.fromJson(settings?.extensionInstalledFrom[key])?.isReservedPrefixAllowed ?? false,
    );
    // A damaged store must not cost the operator the app's own extensions.
    var fromDisk = const <ExtensionInfo>[];
    var listed = false;
    try {
      fromDisk = await store.list();
      listed = true;
    } catch (e, stack) {
      // Reported, not merely logged. `list` already skips a single unreadable
      // extension, so anything reaching here is the STORE failing — every
      // installed extension gone at once, with the app otherwise behaving
      // normally. Deciding here that it doesn't matter is the ad-hoc policy
      // ErrorPolicy exists to prevent (docs/design/error-reporting.md).
      ErrorReportingService.report(e, stack, context: 'installed-extensions:list');
    }
    // Once, for an install that predates the record: what it holds is what
    // its operator installed. After that only installs and uninstalls write
    // it — a store found short is exactly what it must not follow. Never from
    // a store that could not be read.
    final currentSettings = settings;
    if (listed && currentSettings != null && !currentSettings.extensionsInstalledRecorded) {
      await currentSettings.setExtensionsInstalled({for (final info in fromDisk) info.key: info.name});
    }
    return _availableExtensions = mergeDevExtensions([...fromAssets, ...fromDisk], [for (final entry in _devBundles.values) entry.info]);
  }

  /// The already-loaded metadata, or empty before [loadAvailableExtensions]
  /// first resolves.
  List<ExtensionInfo> get availableExtensions => _availableExtensions ?? const [];
  List<ExtensionInfo>? _availableExtensions;

  /// The one of [availableExtensions] called [key], if any.
  ExtensionInfo? extensionInfo(String key) => availableExtensions.where((info) => info.key == key).firstOrNull;

  @visibleForTesting
  void debugSetAvailableExtensions(List<ExtensionInfo> extensions) => _availableExtensions = extensions;

  /// Installed `.h2kext` extensions (HALO-422). Null until the index has been
  /// read, since it needs the built-in keys and the host's shared-module
  /// versions to validate anything.
  InstalledExtensions? _installed;

  /// The store, once the extension index has been read — null before the
  /// first [loadAvailableExtensions].
  InstalledExtensions? get installed => _installed;

  /// Supplies the store up front, so a test can point it at a directory of its
  /// own — the real one resolves through `appDataDirectory()`, which reaches a
  /// platform channel.
  @visibleForTesting
  set debugInstalledStore(InstalledExtensions store) => _installed = store;

  /// What this build's kernel carries, from index.json — the versions an
  /// installed bundle's `sharedDependencies` are checked against.
  Map<String, String> _hostSharedModules = const {};

  /// Extensions currently served by a dev server, by key: the built source and
  /// the manifest metadata that came with it. An entry here OVERRIDES the
  /// asset extension of the same key, which is what lets an author iterate on
  /// `pota` itself rather than only on something new.
  final Map<String, ({String source, ExtensionInfo info})> _devBundles = {};

  /// Whether [key] is currently being served by a dev server.
  bool isDevExtension(String key) => _devBundles.containsKey(key);

  /// Replaces the whole dev-served set and reboots the runtime. Used on
  /// connect and disconnect — both change WHICH extensions exist, which a
  /// per-extension reload cannot express.
  Future<void> setDevBundles(Map<String, ({String source, ExtensionInfo info})> bundles) async {
    _devBundles
      ..clear()
      ..addAll(bundles);
    _availableExtensions = null; // the index it was memoized from just changed
    await restartRuntime();
  }

  /// Swaps ONE dev extension's code in the running runtime — the hot path, on
  /// every save.
  ///
  /// Falls back to a full restart when the extension isn't loaded yet: a key
  /// the runtime has never seen has no hooks to replace, and its very
  /// existence changes what the app offers (an activity in Operation Setup, a
  /// settings panel), which only a reboot re-reads.
  Future<void> applyDevBundle(String key, {required String source, required ExtensionInfo info}) async {
    // Read BEFORE the insert below: what matters is how this key was loaded
    // into the RUNNING runtime, not what it is about to become.
    final previous = _devBundles[key];
    _devBundles[key] = (source: source, info: info);
    _availableExtensions = null;
    final host = _host;
    if (host == null ||
        !canHotSwapDevBundle(
          runtimeAlive: !host.isDead,
          alreadyLoaded: _loadedExtensionKeys.contains(key),
          alreadyDevServed: previous != null,
          capabilitiesUnchanged: previous != null && previous.info.sameStartTimeCapabilities(info),
        )) {
      await restartRuntime();
      return;
    }
    // The previous code's transient UI is nobody's to clear once its hooks are
    // gone — a progress bar it left behind would sit there for the session.
    statusBar?.clearNamespace(key);
    await host.reloadBundle(
      ExtensionBundle(key: key, source: source, api: info.runtimeApi),
      domains: info.domains,
    );
    // Panels, settings panels and the command catalog are all cached against
    // this counter; the reloaded extension may contribute a different set.
    _commandCatalog = null;
    runtimeGeneration.value++;
  }

  /// Core extensions are always on; the rest follow the user's override,
  /// falling back to the build index's default — except a release the
  /// catalog revoked, which is off whatever the override says: the switch is
  /// the operator's intent, and the revocation is not theirs to undo. A null
  /// [settings] (tests, benches) resolves to defaults. Enabled is the user's
  /// intent only — whether the extension actually loads also requires
  /// [isExtensionAvailable].
  bool isExtensionEnabled(ExtensionInfo info) => info.core || (!isExtensionRevoked(info) && !isExtensionRefused(info) && isExtensionSwitchedOn(info));

  /// The operator's own choice for [info] — its override, else the build
  /// index's default — whatever the app then does with it. Differs from
  /// [isExtensionEnabled] exactly for a revoked or refused release, where
  /// offering the switch again cannot help: it is already on.
  bool isExtensionSwitchedOn(ExtensionInfo info) => settings?.extensionOverrides[info.key] ?? info.enabledByDefault;

  /// Whether the INSTALLED version of [info] is one the engine would not
  /// evaluate (`SettingsService.extensionRefused`).
  ///
  /// Here rather than in [isExtensionAvailable], for the reason revocation is:
  /// unavailable hides the row, and an extension that stopped working is
  /// exactly the one the operator comes to the panel to ask about. This keeps
  /// it listed, badged, and updatable — which is how the refusal is lifted,
  /// since it is judged by version.
  bool isExtensionRefused(ExtensionInfo info) => isBundleRefused(settings, info);

  /// See [isBundleRevoked].
  bool isExtensionRevoked(ExtensionInfo info) => isBundleRevoked(settings, info);

  /// Whether [info] is offered at all: every experiment its manifest
  /// declares (experiments.yaml keys) must be enabled. An unavailable
  /// extension is hidden from the Extensions panel and never loaded, but
  /// its stored override is deliberately KEPT — one enabled before the
  /// experiment turned off comes back enabled when it turns on again. A
  /// null [settings] (tests, benches) resolves to available.
  bool isExtensionAvailable(ExtensionInfo info) {
    final currentSettings = settings;
    if (currentSettings == null) return true;
    return info.experiments.every(currentSettings.experimentEnabled);
  }

  /// Whether [info] actually loads: offered ([isExtensionAvailable]) AND
  /// switched on ([isExtensionEnabled]). Every load-set computation must go
  /// through this one predicate — a gate applied at only some sites makes
  /// the desired and loaded sets disagree, and then a needed restart
  /// silently never happens.
  bool isExtensionActive(ExtensionInfo info) => isExtensionAvailable(info) && isExtensionEnabled(info);

  /// The key the app offers for [key]: the catalog twin of a retired
  /// built-in, else [key] itself.
  ///
  /// For callers that name an extension by its built-in key — onboarding's
  /// activity picks, `ONBOARD_AS`. A choice written under `pota` alone would
  /// reach nothing: `ham2k-pota` is what runs.
  String offeredKeyFor(String key) => kRetiredBuiltIns.containsKey(key) ? twinOf(key) : key;

  /// Persists enable/disable choices and applies them by restarting the
  /// runtime with the filtered bundle set. The overrides land BEFORE any
  /// restart, so a quit mid-apply loses nothing.
  ///
  /// A retired built-in's key is written as given AND under [offeredKeyFor]'s
  /// twin. Both, because the twin may not be installed yet: its own is what
  /// the pre-load asks first (`shippedBundleSwitchedOn`), and the built-in's
  /// is what the adoption asks and the move carries across.
  Future<void> setExtensionsEnabled(Map<String, bool> changes) async {
    final currentSettings = settings;
    if (currentSettings == null || changes.isEmpty) return;
    await currentSettings.setExtensionOverrides({
      ...currentSettings.extensionOverrides,
      ...changes,
      for (final MapEntry(:key, :value) in changes.entries) offeredKeyFor(key): value,
    });
    await applyExtensionAvailability();
  }

  /// Recomputes which extensions should be loaded (overrides + experiment
  /// gates), re-stamps disabledSince, and restarts the runtime — but only
  /// when the effective set actually changes (and the runtime is up; a
  /// pending boot picks the fresh state up on its own). Call after flipping
  /// an experiment; most toggles gate nothing and return cheaply.
  Future<void> applyExtensionAvailability() async {
    final currentSettings = settings;
    if (currentSettings == null) return;
    // Every experiment flip lands here, and HookContext carries the enabled
    // set: without this, an EXP preview within the kernel cache's TTL of a
    // flip still offers the direction the flip just took.
    invalidateHookContext();
    await updateExtensionDisabledSince(settings: currentSettings, available: availableExtensions, isActive: isExtensionActive);
    // Judged after any replacement in flight — an install's, another toggle's.
    // That one read the set before this change landed: compared against
    // now, its host is null and the change looks like a boot's to pick up,
    // and it loads without it.
    await _restartFuture?.catchError((_) {});
    final desired = {
      for (final info in availableExtensions)
        if (isExtensionActive(info)) info.key,
    };
    if (_host == null || setEquals(desired, _loadedExtensionKeys)) return;
    await restartRuntime();
  }

  Future<void> setExtensionEnabled(String key, bool enabled) => setExtensionsEnabled({key: enabled});

  /// The activated extensions of the LIVE runtime, with versions — served
  /// by the kernel's own `kernel-info` extension (the one place versions
  /// exist). Empty when the runtime is down.
  Future<List<Map<String, dynamic>>> listActiveExtensions() async {
    final host = this.host;
    if (host == null) return const [];
    try {
      final result = await host.invoke(Hooks.runtimeListExtensions, key: 'kernel', timeout: const Duration(seconds: 2));
      return result is List ? result.cast<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList() : const [];
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] listActiveExtensions failed: $e');
      return const [];
    }
  }
}
