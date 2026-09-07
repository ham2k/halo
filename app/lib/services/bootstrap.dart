// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Boot: open the log, build the service graph, start what can start before
// the first frame, and post the notices boot already knows the answer to.
// The ordering inside bootstrap() is load-bearing — what overlaps what, and
// what waits for what, is stated at each step. Nothing here is sequential or
// concurrent by accident.

import 'dart:async';

import 'package:intl/intl.dart';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, visibleForTesting, TargetPlatform;
// Prefixed separately from the AppExitResponse import above: some import in
// this file's graph makes the bare name `TextDirection` resolve to something
// without an `.ltr` getter, so the real dart:ui one needs this to be reached
// unambiguously.
import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../views/settings_view.dart';
import 'app_storage.dart';
import 'auto_update_service.dart';
import 'database_snapshot_service.dart';

import 'hang_watchdog.dart';

import 'error_reporting_service.dart';
import 'extension_service.dart';
import 'unclean_quit.dart';
import 'metrics_service.dart';
import 'purchase_service.dart';
import 'settings_service.dart';
import 'web_storage_persistence.dart';
import 'window_chrome_service.dart';
import 'update_check_service.dart';
import 'update_service.dart';
import 'shorebird_update_service.dart';
import '../i18n/strings.g.dart';

import '../config/navigation.dart';
import 'app_exit.dart';
import 'halo_services.dart';
import 'peer/peer_pairing_prompt.dart';

/// Forces the bundled color-emoji font's glyph data to load AND shape now,
/// instead of on whichever `Text` — or text *measurement* — happens to need
/// it first (see [bootstrap]'s call site).
///
/// Never throws, but the report is not ceremony: every flag in the app is a
/// glyph from this font and nothing renders one without it, so a load that
/// fails takes the feature with it rather than merely moving a cost.
///
/// It detects only an ABSENT asset, which is the loud case. A font that is
/// present and wrong — truncated, or a build with no flag glyphs — loads
/// here without complaint, because FontLoader accepts bytes it cannot decode
/// and `layout()` never throws for a missing glyph. That case is caught
/// before it ships, by app/test/emoji_font_asset_test.dart reading the
/// artifact, since at runtime it has no signal at all.
Future<void> _preloadEmojiFont() async {
  try {
    // FontLoader needs the family name to register under (matching what
    // emojiStyle() requests) and the asset bytes to register it with,
    // independently — both come from halo_widgets/theme.dart.
    final data = await rootBundle.load(emojiFontAssetPath);
    await (FontLoader(emojiFontFamily)..addFont(Future.value(data))).load();
    // Registering the font is cheap; laying it out is not. A flag emoji is
    // two combined regional-indicator codepoints — Skia's first shape of
    // that combination through a multi-megabyte color font is a real,
    // one-time cost (measured over 1s), paid wherever the first `Text` or
    // width *measurement* using this font happens to land. For QsoList
    // (HALO-258) that was the first operation's row metrics, mid-transition.
    // A throwaway layout here pays it during the splash instead.
    (TextPainter(
      text: TextSpan(text: '🇨🇦', style: emojiStyle()),
      textDirection: dart_ui.TextDirection.ltr,
    )..layout())
        .dispose();
  } catch (error, stackTrace) {
    debugPrint('[boot] emoji font preload failed: $error\n$stackTrace');
    ErrorReportingService.report(error, stackTrace, context: 'boot:emoji-font-preload');
  }
}

/// Runs the shared boot sequence (database, extensions, settings, sync) and
/// returns the assembled services bundle. Distribution-specific entrypoints
/// (e.g. a private `main_dist.dart`) call this with real implementations of
/// the distribution-only services instead of the OSS no-op defaults.
Future<HaLoServices> bootstrap({
  MetricsService? metrics,
  PurchaseService? purchases,
  UpdateService? updates,
  UpdateCheckService? updateCheck,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before everything else: settles where the app's files live and moves any
  // left in an older location, which SettingsService.load() below depends on
  // — once shared_preferences has read its file, it caches it.
  // Held for the notice below: the operator has to be told when settings they
  // had made are gone, and this is the only moment anything knows it.
  final preferencesRecovery = await initializeAppStorage();
  // What drift's web worker actually negotiated — read by
  // [reportWebStorageHealth] once the (lazy) database has opened, so boot
  // can warn when the browser degraded to storage that can lose the log.
  WasmDatabaseResult? webDbResult;
  final db = HaLoDatabase(driftDatabase(
    name: kDatabaseName,
    web: kIsWeb
        ? DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
            onResult: (result) => webDbResult = result,
          )
        : null,
    // drift resolves this lazily, right before opening the file — which is
    // what makes it the correct place to hang the one-shot relocation off
    // Documents: no boot step can accidentally open the database first.
    native: kIsWeb ? null : DriftNativeOptions(databaseDirectory: appDataDirectory),
  ));
  // Opened HERE rather than left to whichever query happens to be first.
  // drift runs its migration on the first statement, so a log written by a
  // newer build refuses to open somewhere deep in a sync round or a list
  // rebuild — and what the operator sees is a feature that quietly stops
  // working, with the only account of why in the console. Asking at boot is
  // what lets the notice below name the cause.
  //
  // NOT awaited here: the open is what every step below is already waiting on
  // lazily, and holding boot for it would put a disk round-trip in front of
  // the extension runtime and the settings load, which currently overlap it.
  final logRefusal = _openLogNow(db);
  final extensions = ExtensionService();
  // Fire-and-forget, and kicked off before awaiting settings below so these
  // two independent boot steps run concurrently instead of serialized; the
  // core logging loop never waits on the extension runtime either way.
  extensions.start();
  final settings = await SettingsService.load();
  // The previous run's database close, if it left a mark: the quit itself has
  // no time to report one, so this boot is the first moment it can be told.
  // Not awaited — the report is fire-and-forget either way, and a boot must
  // not wait on the last quit's postmortem.
  unawaited(reportUncleanQuit(settings.prefs));
  // Existing installs never ran through the 'first-use' counter — it didn't
  // exist yet — but they've already onboarded (see the method doc); a no-op
  // once seeded, so this is safe on every boot.
  await settings.seedFirstUseOnboardingForExistingUsers();
  // Reads the same "already onboarded" signal, so it must run before
  // onboarding gets a chance to write a callsign.
  await settings.seedSyncEnabledDefault();
  LocaleSettings.setLocaleRaw(settings.locale);
  Intl.defaultLocale = settings.locale;
  final services = HaLoServices(
    db,
    settings,
    extensions: extensions,
    metrics: metrics,
    purchases: purchases,
    // The running app checks Shorebird for a Dart patch on the selected track
    // (§4.3); no-ops in any build without the engine. Overridable for tests.
    // Web and debug builds never have the engine, and constructing
    // ShorebirdUpdater() there prints the package's "Updater is unavailable"
    // notice on every boot — skip it and go straight to the no-op.
    updates: updates ?? (kIsWeb || kDebugMode ? const NoopUpdateService() : ShorebirdUpdateService(settings)),
    updateCheck: updateCheck,
  );
  // Cache the running code-push number for the synchronous version displays
  // (views/version_label.dart's buildDetails). Awaited rather than
  // fire-and-forget: a late arrival would leave the first frames naming a
  // build identity that no rebuild is coming to correct. Started here but
  // awaited at the end of boot (see below) so the wait overlaps the keyring,
  // sync and extension work instead of sitting in front of it.
  //
  // Every failure mode is swallowed to null, and deliberately so: this decides
  // a suffix on a version label, and nothing about a version label may cost
  // the operator their log. A hang is bounded by the timeout; a throw is
  // caught here rather than in the callee, because UpdateService is an
  // injectable interface and ShorebirdUpdateService catches only the one
  // exception its package documents — an isolate that fails to spawn under
  // memory pressure, or a future package version's new type, would otherwise
  // escape into bootstrap() and strand the user on the boot-error screen.
  //
  // Note what this does NOT bound: constructing ShorebirdUpdater above reads
  // the patch synchronously on this isolate, and the package's own source
  // warns that can block on the updater's config lock. No timer can fire
  // through that, so the guarantee here covers this read, not that one.
  // `.then` before `.timeout`, so "resolved" marks the read having ANSWERED —
  // a null answer means no push applied, which is a fact. A timeout or a throw
  // leaves it false, and the code-push floor stays silent rather than nagging
  // an install it cannot describe (services/staleness.dart).
  // Both values arrive together, from the layer that knows whether the read
  // answered. Setting "resolved" here instead would be wrong twice over: a
  // timeout does not cancel the future underneath it, so a late completion
  // would flip the flag beside a number nobody assigned; and a read exception
  // swallowed further down already returns a bare null. Either way the pair
  // would read as "no code push applied" and nag an operator who is current.
  final codePushFuture = services.updates
      .currentPatchNumber()
      .timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('[boot] code-push number timed out — the version label drops the suffix');
          return (resolved: false, number: null);
        },
      )
      .catchError((Object e) {
        debugPrint('[boot] code-push number unreadable: $e');
        return (resolved: false, number: null);
      });
  // A locked/absent keyring yields a null device key (ensureSyncDeviceKey no
  // longer throws) — boot must still complete, so skip sync setup and pick it
  // up on a later launch once the keyring is available.
  final syncDeviceKey = await settings.ensureSyncDeviceKey();
  if (syncDeviceKey != null) {
    services.extensions.setSyncCredentials(deviceKey: syncDeviceKey, operatorCall: settings.activeProfile.operatorCall);
    services.syncEngine.start();
    services.watchReceivedTestOperationPurges();
    // Independent of syncEngine.start() above: this registers device
    // identity/the realtime channel regardless of whether the operator has
    // QSO sync enabled — registration pushes no log data, only
    // syncEngine (gated on settings.syncEnabled) does that. Not awaited:
    // it's a network round-trip and boot must not wait on it.
    unawaited(services.connectLofiRealtime());
  } else {
    debugPrint('[boot] no sync device key (secure storage unavailable) — continuing without sync');
  }
  services.maybeStartInboundQsoListener();
  services.maybeStartPeerSync();
  listenForPeerPairingRequests(services);
  // Reads the flag rather than this branch: a null device key means storage
  // threw, but saying so out loud keeps the notice tied to the fact it reports
  // instead of to one caller's control flow.
  if (settings.secureStorageUnavailable) maybeShowNoKeyringNotice(services);
  showPreferencesRecoveryNotice(services, preferencesRecovery);
  await showLogFromNewerBuildNotice(services, await logRefusal);

  // Started before the first thing it guards, and awaited: spawning an isolate
  // is a few milliseconds, and a watchdog that arrives after the call it
  // exists for has missed the only moment it matters. OUTSIDE the experiment
  // gate for the same reason [shutdownOnExit] is — CAT switched on mid-session
  // would otherwise quit unguarded — and it costs an idle isolate to a session
  // that never guards anything.
  await HangWatchdog.start();

  // Reconnect the designated radio (docs/design/cat.md). Not awaited: the
  // radio may be off, and boot must not wait on a socket timeout. Gated on
  // the experiment so nothing opens a connection unless CAT is on.
  if (settings.experimentEnabled('gato') /* stored key, see experiments.yaml */ && !kIsWeb) {
    // Before the reconnect, not after: the notice describes what this launch
    // is about to NOT do, and the call below is fire-and-forget.
    showAutoConnectHeldNotice(services);
    // Taken down again by the Connect the notice asks for — otherwise the
    // instruction to press it outlives the pressing, and in a two-radio shack
    // it would go on naming a rig that is connected. Re-posted rather than
    // simply dismissed, because the other radio may still be held.
    services.cat.onAutoConnectHoldLifted = () {
      services.statusBar.dismissNotice(autoConnectHeldNoticeKey);
      showAutoConnectHeldNotice(services);
    };
    unawaited(services.cat.reconnectDesignatedRadio());
  }

  // OUTSIDE the experiment gate, deliberately: gated inside it, turning CAT
  // on in Settings mid-session and then connecting a radio would leave no
  // listener at all — bypassing exactly the people who had just
  // enabled the feature. shutdown() is a no-op when nothing is connected, so
  // installing it always costs nothing.
  if (!kIsWeb) shutdownOnExit(services);

  // macOS app-menu actions (see WindowChromeService and macos/Runner): "About"
  // shows the release overlay, "Preferences…" (⌘,) opens the Settings view.
  WindowChromeService.onShowReleaseOverlay = services.devSplashTrigger.trigger;
  WindowChromeService.onOpenSettings = () => navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => SettingsView(services: services)),
      );
  WindowChromeService.onCheckForUpdates = () => unawaited(const AutoUpdateService().checkForUpdatesInteractively());

  // The panel catalog is read HERE, before bootstrap returns and the first
  // view builds, rather than by whichever view happens to want it: a saved
  // dock arrangement names extension panels, and a view built against a
  // catalog that has not arrived yet shows placeholders for panes that are
  // perfectly fine.
  //
  // ONE short budget for this and the emoji-font warm-up below, because this
  // is splash time — `runApp` shows the splash until this future resolves,
  // and nothing else in bootstrap waits on the runtime (the logging loop
  // deliberately never does). Overrunning is not a failure and not fatal: a
  // panel that hasn't been read yet renders as a placeholder, the catalog
  // re-reads itself the moment the runtime comes up (`runtimeGeneration`),
  // and an unwarmed emoji font just shapes its first glyph later, exactly as
  // it did before this existed. The wait buys a tidier first frame in the
  // ordinary case; it must never buy a slow one.
  try {
    await Future.wait([
      extensions.start().then((_) => services.panels.refreshExtensionPanels()),
      // See _preloadEmojiFont's doc: pays the color-emoji font's one-time
      // load-and-shape cost here instead of on whichever screen measures or
      // paints the first flag glyph (HALO-258's QsoList open was 1s+ of it).
      if (!kIsWeb) _preloadEmojiFont(),
    ]).timeout(_panelCatalogBootBudget);
  } catch (e) {
    debugPrint('[boot] panel catalog not ready before first build ($e); panes will fill in');
  }

  // Await the extension system being fully booted, then initialize and sync data files
  unawaited(extensions.start().then((_) async {
    // BEFORE the data files, and awaited: connecting replaces the runtime, and
    // a replacement landing mid-load kills it against a disposed host — after
    // which the sync behind it fetches a 304, finds nothing to import, and the
    // session simply runs without that data (HALO-429). Sequenced here so
    // there is one runtime swap and then one load, against the runtime that
    // will actually serve it. Only ever with developer mode on AND the toggle
    // set — no address is ever discovered, only typed.
    if (settings.developerMode &&
        settings.extensionDevServerEnabled &&
        settings.extensionDevServerUrl.isNotEmpty) {
      // Never throws — the client records a failed connection as status
      // rather than an error, so a dev server that has since been stopped
      // costs a restarting app nothing but a line in Developer settings.
      await services.extensionDev.connect(settings.extensionDevServerUrl);
    }
    await services.dataFiles.loadRawDataFiles();
    // Unattended (no user action prompted this): a persistent failure notice
    // here would repeat on every single offline boot.
    await services.dataFiles.syncAllDataFiles(notifyOnFailure: false);
    // After the enabled extensions have refreshed their data-file ownership
    // records, drop the data of any extension disabled long enough ago.
    await services.dataFiles.purgeStaleExtensionData(settings.extensionDisabledSince);
  }).catchError((e) {
    debugPrint('[boot] failed to initialize data files: $e');
  }));

  // Settled BEFORE the flags refresh below, not merely before `return`: the
  // notice environment reads this global to report `appCodePush`, and a
  // `codePushes` rule that evaluated against a not-yet-resolved value would
  // silently target the wrong installs. Everything above has overlapped the
  // wait; by here it has almost always already completed.
  final codePushRead = await codePushFuture;
  currentCodePush = codePushRead.number;
  currentCodePushResolved = codePushRead.resolved;

  // Fetch feature flags + notices for the current callsign once the runtime
  // is up (the callsign→DXCC-entity annotation needs it). Fire-and-forget;
  // failures leave flags empty and are logged inside the service.
  unawaited(extensions.start().then((_) {
    return services.flags.refreshForCall(settings.activeProfile.operatorCall);
  }).catchError((e) {
    debugPrint('[boot] failed to fetch feature flags: $e');
  }));

  // Fire-and-forget like the boot steps above: neither the persistence
  // request nor the health warning is worth delaying first paint for.
  if (kIsWeb) unawaited(reportWebStorageHealth(services, () => webDbResult));

  if (!kIsWeb) {
    // Rotating file-level backups (see DatabaseSnapshotService's header).
    // Delayed well past boot: the first `VACUUM INTO` rides the statement
    // queue, and first paint must not wait behind a whole-file copy.
    final snapshots = DatabaseSnapshotService(db, dataDirectory: appDataDirectory);
    Timer(const Duration(minutes: 2), snapshots.start);
  }

  return services;
}

/// Web only: requests the persistent-storage grant and warns when drift's
/// worker degraded to storage that can lose the log.
///
/// Native builds keep the database in a real file the OS never evicts; on
/// web BOTH halves of durability are opt-in. Without
/// `navigator.storage.persist()` the browser may evict the whole origin
/// under storage pressure (and Safari expires script-writable storage after
/// seven days of disuse) — wiping every QSO that never synced. And drift
/// silently falls back to `unsafeIndexedDb` (two tabs clobber each other)
/// or `inMemory` (gone at tab close) when the worker handshake degrades;
/// the chosen implementation is only observable through
/// `DriftWebOptions.onResult`. The SELECT 1 forces the lazy database open
/// so that callback has fired before [result] is read.
Future<void> reportWebStorageHealth(HaLoServices services, WasmDatabaseResult? Function() result) async {
  // A false is normal on browsers that gate the grant behind engagement
  // heuristics, and asking again next boot is free — so no notice for it;
  // only the storage fallbacks below are worth an operator's attention.
  unawaited(requestPersistentWebStorage());
  try {
    await services.db.customSelect('SELECT 1').get();
  } catch (_) {
    return; // a database that can't even open reports through boot, not here
  }
  final negotiated = result();
  if (negotiated == null) return;
  debugPrint('[web-storage] using ${negotiated.chosenImplementation}'
      '${negotiated.missingFeatures.isEmpty ? '' : ', missing ${negotiated.missingFeatures}'}');
  switch (negotiated.chosenImplementation) {
    case WasmStorageImplementation.inMemory:
      services.statusBar.showNotice(key: 'webStorage', icon: 'database-alert', text: t.notices.webStorageInMemory);
    case WasmStorageImplementation.unsafeIndexedDb:
      services.statusBar.showNotice(key: 'webStorage', icon: 'database-alert', text: t.notices.webStorageUnreliable);
    case WasmStorageImplementation.opfsShared:
    case WasmStorageImplementation.opfsLocks:
    case WasmStorageImplementation.sharedIndexedDb:
      break;
  }
}

/// How long boot will wait for the extension runtime, its panel catalog, and
/// the emoji-font warm-up before showing the first view anyway. Deliberately
/// short: this is splash time, and the only thing it buys is not briefly
/// showing a placeholder panel or an unshaped flag glyph that both turn out
/// to be fine moments later.
const _panelCatalogBootBudget = Duration(seconds: 3);

/// Key for the notice below, and the pref that keeps it to one showing.
const noKeyringNoticeKey = 'accounts:no-keyring';
const _noKeyringNoticeShownKey = 'accounts:noKeyringNoticeShown';

/// Says once, on Linux, that account logins cannot be saved.
///
/// Public for its test: the Linux-only condition and the once-ness are the parts
/// worth pinning.
///
/// Reached when `ensureSyncDeviceKey` came back null, which happens only when
/// secure storage threw — on Linux that is libsecret reporting `KeyringLocked`,
/// which covers no Secret Service running, no default collection, and a
/// genuinely locked one. The copy therefore names all three rather than picking.
///
/// Deliberately NOT shown for the other failure this has: if the libsecret
/// SHARED LIBRARY is missing, the process dies before `main()` and no notice can
/// exist. That case is documentation only (docs/quirks.md).
///
/// Shown once, tracked in prefs rather than in notice history — history is
/// capped at 50 entries and would eventually let this reappear. An undismissed
/// notice is persisted and comes back on its own next launch, so posting it a
/// second time would also resurrect one the operator had dismissed.
@visibleForTesting
void maybeShowNoKeyringNotice(HaLoServices services) {
  // `defaultTargetPlatform` reports the HOST on web, so the kIsWeb guard is what
  // keeps a Linux browser out of a desktop-only message.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.linux) return;
  final prefs = services.settings.prefs;
  if (prefs.getBool(_noKeyringNoticeShownKey) ?? false) return;
  unawaited(prefs.setBool(_noKeyringNoticeShownKey, true));
  services.statusBar.showNotice(
    key: noKeyringNoticeKey,
    // `key-off` is NOT in the bundled MDI table and renders the puzzle-piece
    // fallback; `key-alert` is.
    icon: 'key-alert',
    title: t.settings.accounts.noKeyringTitle,
    text: t.settings.accounts.noKeyringText,
  );
}

/// Tells the operator that this launch had to repair an unreadable
/// preferences file. The upload happens back in [initializeAppStorage], where
/// the fact is first known and cannot be lost to a later boot failure.
///
/// Posted every time rather than once, unlike [maybeShowNoKeyringNotice]:
/// this describes something that happened on THIS launch, and a second
/// occurrence is a second loss of settings, not a repeat of the first.
@visibleForTesting
void showPreferencesRecoveryNotice(HaLoServices services, PreferencesRecovery recovery) {
  if (recovery == PreferencesRecovery.none) return;
  final restored = recovery == PreferencesRecovery.restoredFromBackup;
  services.statusBar.showNotice(
    key: 'preferencesRecovery',
    icon: 'cog-refresh',
    title: restored ? t.notices.preferencesRestoredTitle : t.notices.preferencesResetTitle,
    text: restored ? t.notices.preferencesRestored : t.notices.preferencesReset,
  );
}

/// Tells the operator that a radio was deliberately left alone this launch,
/// because the previous one stopped existing while connecting it
/// (services/cat/auto_connect_guard.dart).
///
/// Worth a notice rather than only the equipment row's own error, and this is
/// the reason: what the operator sees otherwise is a rig that simply is not
/// there — no frequency, no spots following the VFO — with the explanation two
/// screens away in Settings, on a launch that has just recovered from the app
/// failing to start at all.
///
/// Posted every time it applies, like [showPreferencesRecoveryNotice]: the
/// hold is still in force on every one of those launches, so a second launch
/// is a second thing to act on rather than a repeat of the first.
const autoConnectHeldNoticeKey = 'catAutoConnectHeld';

@visibleForTesting
void showAutoConnectHeldNotice(HaLoServices services) {
  final held = services.cat.autoConnectHeldNodes;
  if (held.isEmpty) return;
  final names = held.map(services.cat.displayNameFor).join(', ');
  services.statusBar.showNotice(
    key: autoConnectHeldNoticeKey,
    icon: 'radio-off',
    title: t.notices.autoConnectHeldTitle(name: names),
    text: t.notices.autoConnectHeld(name: names),
  );
}

/// Opens the log, and answers with the refusal if it was written by a build
/// newer than this one.
///
/// Every OTHER failure is left alone: the open is retried by the first real
/// query, so an error swallowed here is reported there instead — exactly as
/// it is today. Turning them all into boot failures is a much bigger change
/// than naming this one.
Future<LogFromNewerBuild?> _openLogNow(HaLoDatabase db) async {
  try {
    await db.customSelect('SELECT 1').get();
  } catch (e, st) {
    // Through `within` rather than an `on LogFromNewerBuild` clause, which
    // would match only in a test: the app opens its database over a
    // background isolate, so the refusal arrives wrapped in a
    // DriftRemoteException. See LogFromNewerBuild.within.
    final refusal = LogFromNewerBuild.within(e);
    if (refusal == null) {
      // Every other failure is left alone: the open is retried by the first
      // real query and reported from there, exactly as it is today.
      debugPrint('[boot] the log did not open yet: $e');
      return null;
    }
    ErrorReportingService.report(e, st, context: 'db:log-from-newer-build');
    return refusal;
  }
  return null;
}

/// Tells the operator that this build cannot open the log it found, and why.
///
/// The versions and the directory are all in the notice, because the two
/// questions this raises — which build wrote it, and which file is it — have
/// no other answer anywhere in the app, and the alternative is diagnosing an
/// app that simply refuses to save from a console line.
@visibleForTesting
Future<void> showLogFromNewerBuildNotice(HaLoServices services, LogFromNewerBuild? refusal) async {
  if (refusal == null) return;
  // Two strings rather than one with a stand-in for the path: on web there
  // is no folder to name — the log is in the browser's own storage — and
  // splicing an English "this browser" into the sentence would leave every
  // other locale reading its own words and then a foreign phrase.
  final text = kIsWeb
      ? t.notices.logFromNewerBuildNoLocation(
          storage: refusal.storage.toString(),
          understood: refusal.understood.toString(),
        )
      : t.notices.logFromNewerBuild(
          storage: refusal.storage.toString(),
          understood: refusal.understood.toString(),
          location: (await appDataDirectory()).path,
        );
  services.statusBar.showNotice(
    key: 'logFromNewerBuild',
    icon: 'database-alert',
    title: t.notices.logFromNewerBuildTitle,
    text: text,
  );
}
