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
/// iterate on `pota` itself rather than only on something new — and a dev
/// extension with a key nothing ships is appended.
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

  /// The catalog's copy of every withdrawn built-in the operator had ON.
  Future<({bool landed, bool complete})> adoptTwins() => adoptCatalogTwins(
    store: _installed,
    settings: settings,
    catalog: catalog,
    available: availableExtensions,
    isEnabled: isExtensionEnabled,
    recordInstall: _recordInstall,
    copySecrets: copyExtensionSecrets,
  );

  /// Installs the `.h2kext` bundles the app ships (HALO-581), and answers
  /// whether anything landed — the caller re-reads the store when it did.
  ///
  /// Only under the catalog experiment: off it, the app runs its own
  /// extensions and pre-loading their catalog twins would put two of each in
  /// the panel, one of them switched off and unexplained.
  Future<bool> preloadShippedExtensions() async {
    final currentSettings = settings;
    final store = _installed;
    if (currentSettings == null || store == null) return false;
    if (!currentSettings.catalogExtensionsInUse) return false;
    return installShippedExtensions(
      store: store,
      settings: currentSettings,
      installedVersions: {
        for (final info in availableExtensions)
          if (info.isInstalled) info.key: info.version,
      },
      recordInstall: (bundle, {required bool fresh}) => _recordInstall(bundle, fresh: fresh),
      copySecrets: copyExtensionSecrets,
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
    final carried =
        fresh &&
        bundle.provenance != null &&
        await carryPredecessorRecords(
          key: bundle.key,
          settings: settings,
          // What the app SHIPS, not what it offers — see predecessorBuiltInKey.
          builtInKeys: {
            for (final i in availableExtensions)
              if (i.source == ExtensionSource.asset) i.key,
          },
          copySecrets: copyExtensionSecrets,
        );
    await store.install(bundle);
    // `fresh` drops a stale on/off choice; one just carried is not stale.
    await _recordInstall(bundle, fresh: fresh && !carried);
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
  /// catalog once served must not inherit the `ham2k-` waiver. A revocation
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
      records[bundle.key] = provenance.toJson();
      await currentSettings.setExtensionInstalledFrom(records);
    }
    await liftInstallRecordsForNewVersion(currentSettings, bundle.key, bundle.version);
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
  Future<void> uninstallExtension(String key) async {
    await _requireInstalledStore().uninstall(key);
    await settings?.forgetExtension(key);
    await forgetExtensionKeychainItems(_secureStorage, key, deleteOne: (name) async => _deleteAccountItem(name, await _accountKeychainOptions(key)));
    // Re-read, not merely dropped — see [installBundle].
    await _reloadBeforeRestart();
    statusBar?.clearNamespace(key);
    await restartRuntime(fresh: true);
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
    // Not on web: there is no store there, and a non-null one whose every
    // method refuses is a thing every caller has to remember about.
    final store = InstalledExtensions.isSupported
        ? (_installed ??= InstalledExtensions(
            // Read live, not captured, and only what the app is OFFERING: the
            // catalog experiment withdraws every non-core built-in, and the
            // bundle pre-loaded for `ham2k-lookup` is one the app also ships.
            builtInKeys: () => {
              for (final info in fromAssets)
                if (isBuiltInOffered(info)) info.key,
            },
            hostSharedModules: _hostSharedModules,
            // Read live too: the record is written by installBundle and
            // cleared by uninstall, and the store outlives both.
            reservedPrefixAllowed: (String key) => BundleProvenance.fromJson(settings?.extensionInstalledFrom[key])?.isReservedPrefixAllowed ?? false,
          ))
        : null;
    // A damaged store must not cost the operator the app's own extensions.
    var fromDisk = const <ExtensionInfo>[];
    try {
      fromDisk = await store?.list() ?? const [];
    } catch (e, stack) {
      // Reported, not merely logged. `list` already skips a single unreadable
      // extension, so anything reaching here is the STORE failing — every
      // installed extension gone at once, with the app otherwise behaving
      // normally. Deciding here that it doesn't matter is the ad-hoc policy
      // ErrorPolicy exists to prevent (docs/design/error-reporting.md).
      ErrorReportingService.report(e, stack, context: 'installed-extensions:list');
    }
    return _availableExtensions = mergeDevExtensions([...fromAssets, ...fromDisk], [for (final entry in _devBundles.values) entry.info]);
  }

  /// The already-loaded metadata, or empty before [loadAvailableExtensions]
  /// first resolves.
  List<ExtensionInfo> get availableExtensions => _availableExtensions ?? const [];
  List<ExtensionInfo>? _availableExtensions;

  @visibleForTesting
  void debugSetAvailableExtensions(List<ExtensionInfo> extensions) => _availableExtensions = extensions;

  /// Installed `.h2kext` extensions (HALO-422). Null until the index has been
  /// read, since it needs the built-in keys and the host's shared-module
  /// versions to validate anything.
  InstalledExtensions? _installed;

  /// The store, once the extension index has been read. Null on web, and
  /// before the first [loadAvailableExtensions].
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
      ExtensionBundle(key: key, source: source),
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

  /// Whether an extension the app SHIPS is one it currently offers.
  ///
  /// Core extensions always are — they are the app itself, and `ham2k-lofi`
  /// among them, so sync does not stop. Every other built-in is withdrawn
  /// while the catalog experiment is on (HALO-581): the point of that
  /// experiment is to run on what the catalog serves, and a built-in left
  /// loaded beside its catalog twin would register the same hooks and the
  /// same `ref:` types twice.
  ///
  /// Withdrawn, not forgotten. The entry stays in [availableExtensions] so
  /// that [updateExtensionDisabledSince] does not prune the operator's on/off
  /// choice for it, and so it comes back untouched when the experiment goes
  /// off.
  ///
  /// Nothing is withdrawn where there is no store to put anything in its
  /// place. On web an installed extension is a file on disk the platform does
  /// not have, so the pre-loads never land — and withdrawing the built-ins
  /// there would leave the app with the core extensions and nothing else.
  bool isBuiltInOffered(ExtensionInfo info) {
    if (info.source != ExtensionSource.asset || info.core) return true;
    if (!InstalledExtensions.isSupported) return true;
    // MIGRATED, not merely offered: an operator who deferred the upgrade, or
    // who was offline when it was offered, keeps every extension they had.
    // Withdrawing on the experiment alone is what left "Later" meaning "with
    // no extensions until you are next online".
    return !(settings?.catalogExtensionsInUse ?? false);
  }

  /// Whether [info] is an installed extension the app is currently doing
  /// itself — a pre-loaded `ham2k-pota` while the built-in `pota` is back.
  ///
  /// The mirror of [isBuiltInOffered], and the reason it has to exist: the
  /// experiment withdraws the built-ins, but turning it off does not withdraw
  /// what replaced them. Both would then load, both would register `ref:pota`,
  /// one of them would win by position, and the panel would list the same
  /// extension twice with no way to tell which is answering.
  ///
  /// Judged against the built-in actually being OFFERED, not merely shipped,
  /// so this stops applying by itself on the day the app stops carrying its
  /// own copy — which is where all of this is going.
  ///
  /// Withdrawn, not uninstalled. The bundle and everything it stored stay
  /// where they are, so turning the experiment back on picks it up mid-stride.
  bool isSupersededByBuiltIn(ExtensionInfo info) {
    if (info.source != ExtensionSource.installed) return false;
    // The same rule the carry uses, not the seven named renames alone: the
    // adoption installs up to thirty-three more under `ham2k-<builtin>`, and
    // `ham2k-lookup` is served under the name it already has. Judged by the
    // map only, every one of those loads BESIDE its restored built-in the
    // moment the experiment goes off — two bundles under one key for lookup,
    // and two registrations of `ref:wca` for the rest.
    final shipped = {
      for (final i in availableExtensions)
        if (i.source == ExtensionSource.asset) i.key,
    };
    final replaces = shipped.contains(info.key) ? info.key : predecessorBuiltInKey(info.key, shipped);
    if (replaces == null) return false;
    return availableExtensions.any((other) => other.key == replaces && other.source == ExtensionSource.asset && isBuiltInOffered(other));
  }

  /// Whether [info] is offered at all: every experiment its manifest
  /// declares (experiments.yaml keys) must be enabled. An unavailable
  /// extension is hidden from the Extensions panel and never loaded, but
  /// its stored override is deliberately KEPT — one enabled before the
  /// experiment turned off comes back enabled when it turns on again. A
  /// null [settings] (tests, benches) resolves to available.
  bool isExtensionAvailable(ExtensionInfo info) {
    final currentSettings = settings;
    if (currentSettings == null) return true;
    if (!isBuiltInOffered(info)) return false;
    if (isSupersededByBuiltIn(info)) return false;
    return info.experiments.every(currentSettings.experimentEnabled);
  }

  /// Whether [info] actually loads: offered ([isExtensionAvailable]) AND
  /// switched on ([isExtensionEnabled]). Every load-set computation must go
  /// through this one predicate — a gate applied at only some sites makes
  /// the desired and loaded sets disagree, and then a needed restart
  /// silently never happens.
  bool isExtensionActive(ExtensionInfo info) => isExtensionAvailable(info) && isExtensionEnabled(info);

  /// Persists enable/disable choices and applies them by restarting the
  /// runtime with the filtered bundle set. The overrides land BEFORE any
  /// restart, so a quit mid-apply loses nothing.
  Future<void> setExtensionsEnabled(Map<String, bool> changes) async {
    final currentSettings = settings;
    if (currentSettings == null || changes.isEmpty) return;
    await currentSettings.setExtensionOverrides({...currentSettings.extensionOverrides, ...changes});
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
