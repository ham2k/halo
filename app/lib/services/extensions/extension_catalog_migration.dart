// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Moving an install from the app's own extensions to the catalog's
// (docs/extensions/distribution.md).
//
// One operation, offered once and deferrable: the operator is asked at start
// and may say later, so nothing is withdrawn until the replacements are in
// hand. `SettingsService.extensionsMigrated` is the switch, and it is written
// LAST — until then the built-ins run exactly as they always did, which is
// what makes "later" cost nothing and an offline launch harmless.

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:halo_i18n/halo_i18n.dart';

import '../connectivity_service.dart';
import '../error_reporting_service.dart';
import 'extension_service.dart';
import 'preloaded_extensions.dart';
import '../settings_service.dart';

/// The graph handed the extension service no catalog — a wiring defect, and
/// the reason this exists as a type is that it must not read as an
/// unreachable server: its disposition is decided in `ErrorPolicy`
/// (docs/design/error-reporting.md), where it uploads without a notice,
/// because there is nothing the operator can do about it.
class CatalogNotWired implements Exception {
  const CatalogNotWired();

  @override
  String toString() => 'ExtensionService.catalog is null';
}

/// The graph handed the migration no settings — the same family of wiring
/// defect as [CatalogNotWired], and told apart from it only so a reader of a
/// report knows which end was unwired.
class SettingsNotWired implements Exception {
  const SettingsNotWired();

  @override
  String toString() => 'ExtensionService.settings is null';
}

/// The upgrade check has found no usable catalog [launches] launches in a
/// row — nothing answered, or ([empty]) the listing had nothing in it.
class UpgradeCatalogUnavailable implements Exception {
  const UpgradeCatalogUnavailable({required this.launches, required this.empty});

  final int launches;
  final bool empty;

  @override
  String toString() => 'the upgrade check found ${empty ? 'an empty catalog' : 'no catalog'} $launches launches in a row';
}

/// Launches in a row without a usable catalog before the upgrade check says
/// so. One is a device that was offline; several is an install the catalog
/// cannot reach.
const kUpgradeCheckMissesReported = 3;

/// How an upgrade ended, in the operator's terms rather than a bool's.
///
/// The four ways an upgrade ends short are not one message: one asks the
/// operator to try again when they are online, one asks them to wait a
/// moment, one tells them their own extensions are back, and one is a defect
/// they can do nothing about. Folded into a bool they read alike, and two of
/// them reach the operator without writing a line anywhere.
enum UpgradeOutcome {
  /// Every twin arrived and the runtime came back with them.
  done,

  /// The catalog could not be reached, or a download did not arrive. Nothing
  /// was withdrawn; trying again when online is the whole remedy.
  incomplete,

  /// Something else went wrong on the way — a store write, a keychain that
  /// refused, a disk with no room. Told apart from [incomplete] because a
  /// message naming the network sends an operator to fix a connection that
  /// was never the problem.
  failed,

  /// A pass was already running — the boot's own catch-up. Nothing failed,
  /// and a moment later the same button works.
  busy,

  /// The twins installed, and the runtime did not come back with them: one
  /// bundle that will not evaluate takes the whole generation down with it
  /// (`EngineRuntime.load` throws if any bundle fails). The upgrade is
  /// reverted and the built-ins ARE running again by the time this is read.
  runtimeReverted,

  /// Neither the upgraded set nor the reverted one would start, so the
  /// install is running no extensions at all. Told apart from
  /// [runtimeReverted] because that one's whole message is "the ones you had
  /// are back and working", and here they are not.
  runtimeDead,

  /// A wiring defect — reported, and nothing the operator can act on.
  notWired,
}

/// A bundle the engine would not evaluate, now kept out of the runtime.
class BundleWouldNotEvaluate implements Exception {
  const BundleWouldNotEvaluate(this.key, this.version);

  final String key;
  final String version;

  @override
  String toString() => '$key $version would not evaluate; keeping it out of the runtime';
}

/// Neither the upgraded extensions nor the ones they replaced would start.
///
/// Its own type so the crash backend can answer "how often does an upgrade
/// leave an install with no runtime at all?" — the boot failure itself
/// reports under `extensions:restart`, where it cannot be told from any other
/// crash.
class UpgradeLeftNoRuntime implements Exception {
  const UpgradeLeftNoRuntime();

  @override
  String toString() => 'the upgrade was reverted and the runtime still did not start';
}

/// True while a migration or catch-up is in flight.
///
/// Both entry points run off a runtime start, and a start happens again on
/// every restart — an extension toggled in the panel, a runtime that died.
/// Without this a restart during the ~30 downloads begins a second pass over
/// the same `extensionAdopted` snapshot: the same keys fetched and installed
/// twice, and whichever pass writes its records last discards the other's.
bool _inFlight = false;

/// Whether the catalog can be reached right now.
///
/// Asked before the upgrade is offered, so nobody is shown a dialog whose
/// button cannot work. Forced past the listing cache: a five-minute-old yes is
/// not evidence about the connection this launch has.
Future<bool> canReachCatalog(ExtensionService service) async {
  final catalog = service.catalog;
  // A catalog the graph never wired is not an unreachable one, and the `?.`
  // that would fold the two together answers "offline" forever without
  // reaching any of CatalogService's own logging — an install where the offer
  // can never appear and nothing anywhere says why.
  if (catalog == null) {
    ErrorReportingService.report(const CatalogNotWired(), StackTrace.current, context: 'extensions:migrate');
    return false;
  }
  final listing = await catalog.fetchCatalog(force: true);
  // EMPTY is not ready either. A channel with nothing published answers `[]`
  // rather than null, and an upgrade offered against it can only end in the
  // failure dialog — then be offered again on the next launch, and every
  // launch after it, with no answer it could ever give. Saying nothing and
  // asking again once something is published is what an operator wants from
  // both cases, so they are one case here.
  final usable = listing != null && listing.isNotEmpty;
  await _countUpgradeCheck(service.settings, usable: usable, empty: listing != null);
  return usable;
}

/// Reports the upgrade check stuck, exactly once per stretch: at the launch
/// that reaches [kUpgradeCheckMissesReported], and not again until a usable
/// answer resets the count. At-or-above would report every launch of an
/// install that is stuck for good.
Future<void> _countUpgradeCheck(SettingsService? settings, {required bool usable, required bool empty}) async {
  if (settings == null) return;
  if (usable) {
    await settings.setUpgradeCheckMisses(0);
    return;
  }
  // A device known to be offline says nothing about the catalog — a field
  // station can go days without a route — so it neither counts nor resets.
  if (ConnectivityService.isOffline) return;
  final misses = settings.upgradeCheckMisses + 1;
  await settings.setUpgradeCheckMisses(misses);
  if (misses == kUpgradeCheckMissesReported) {
    ErrorReportingService.report(
      UpgradeCatalogUnavailable(launches: misses, empty: empty),
      StackTrace.current,
      context: 'extensions:upgrade-offer',
    );
  }
}

/// Moves this install's extensions to the catalog, and answers how it ended.
///
/// The downloads happen while the built-ins are still working, and the flag
/// that withdraws them is reverted if anything did not arrive. An upgrade that
/// fails half way leaves the operator exactly where they were, which is what
/// lets it be offered again next launch.
Future<UpgradeOutcome> migrateToCatalogExtensions(ExtensionService service) async {
  final settings = service.settings;
  if (settings == null) {
    ErrorReportingService.report(const SettingsNotWired(), StackTrace.current, context: 'extensions:migrate');
    return UpgradeOutcome.notWired;
  }
  // The console is the only place that says why the button did nothing: the
  // boot's own catch-up holds the flag, and nothing failed.
  if (_inFlight) {
    debugPrint('[extensions] upgrade declined: a catalog pass is already running');
    return UpgradeOutcome.busy;
  }
  _inFlight = true;
  try {
    return await _migrate(service, settings);
  } catch (e, stack) {
    // The flag is written FIRST, so a throw anywhere after it leaves the one
    // state this must never end in: migrated, with nothing adopted — every
    // non-core built-in withdrawn and no replacement on disk. Reverting here
    // puts the operator back where they were and lets the offer return next
    // launch, which is what the whole shape of this is for.
    ErrorReportingService.report(e, stack, context: 'extensions:migrate');
    await settings.setExtensionsMigrated(false);
    return UpgradeOutcome.failed;
  } finally {
    _inFlight = false;
  }
}

Future<UpgradeOutcome> _migrate(ExtensionService service, SettingsService settings) async {
  await settings.setExtensionsMigrated(true);
  await service.preloadShippedExtensions();
  await carryBuiltInChoicesToTwins(settings);
  // BEFORE the adoption looks: it decides what to fetch from the installed
  // list, and the seven the pre-load just installed are not in a memoized one.
  // They would be downloaded again from the catalog over bytes already on
  // disk — and one of those downloads failing would roll the whole upgrade
  // back over bundles that had shipped inside the app.
  await service.reloadAvailableExtensions();
  final adoption = await service.adoptTwins();
  if (!adoption.complete) {
    await settings.setExtensionsMigrated(false);
    // Whatever DID arrive is installed and recorded, and the memoized list
    // predates it. Left stale, the rest of the session decides what to load
    // from a list missing bundles that are on disk — and the built-ins those
    // twins supersede are back, so the runtime has to be told which of the two
    // it is running.
    if (adoption.landed) {
      await service.reloadAvailableExtensions();
      await service.restartRuntime();
    }
    return UpgradeOutcome.incomplete;
  }
  await service.reloadAvailableExtensions();
  // Fresh, because the verdict below is about THIS generation: a replacement
  // already in flight began before the twins were installed, and reading the
  // host after it would judge a runtime that never saw them.
  await service.restartRuntime(fresh: true);
  // Asked directly, because a boot failure cannot be thrown at us: `_start`
  // catches everything and schedules the crash backoff, so the upgrade would
  // otherwise report success over an install running NO extensions at all —
  // one twin that will not evaluate takes the whole generation with it.
  if (service.runtimeIsHealthy) return UpgradeOutcome.done;

  // The boot names the bundle it died on, so the rest of the operator's
  // extensions do not have to go down with it: put that one aside and try
  // once more. Recorded against the version that failed, so the next release
  // of the same extension is given its chance by an ordinary update.
  final culprit = service.lastStartFailureKey;
  if (culprit != null && await _refuse(service, settings, culprit)) {
    await service.reloadAvailableExtensions();
    await service.restartRuntime(fresh: true);
    if (service.runtimeIsHealthy) return UpgradeOutcome.done;
  }

  // The record STAYS, even though putting it aside did not get a runtime
  // back: the bundle still will not evaluate, and an extension with no
  // built-in behind it — a sideloaded one, or a catalog-only one installed
  // before the upgrade — is in the reverted set too. Re-admitting it there
  // kills the boot that was about to give the operator everything back. What
  // it costs is a name, and every dialog below carries it.
  await settings.setExtensionsMigrated(false);
  await service.reloadAvailableExtensions();
  await service.restartRuntime(fresh: true);
  // Asked AGAIN, for the reason it was asked the first time: this restart
  // cannot report its own failure either, and the difference is what the
  // operator is told. "The ones you had are back and working" over an install
  // running nothing at all is the worst answer this can give.
  if (service.runtimeIsHealthy) return UpgradeOutcome.runtimeReverted;
  ErrorReportingService.report(const UpgradeLeftNoRuntime(), StackTrace.current, context: 'extensions:migrate');
  return UpgradeOutcome.runtimeDead;
}

/// Records [key] as a bundle that will not evaluate, and answers whether that
/// is news — a key already refused at this version was tried before, and
/// refusing it again would restart the runtime for nothing.
Future<bool> _refuse(ExtensionService service, SettingsService settings, String key) async {
  // The INSTALLED entry: a key can appear twice — `ham2k-lookup` ships as an
  // asset and is pre-loaded from the catalog — and the list puts the asset
  // first. Taking that one records the app's own version, which refuses the
  // built-in for good and leaves the bundle that actually failed in the set.
  final version = service.availableExtensions.where((info) => info.key == key && info.isInstalled).map((info) => info.version).firstOrNull;
  // Nothing to key the refusal to, so nothing that a later version could
  // lift: reverting the whole upgrade is the safer answer.
  if (version == null) {
    debugPrint('[extensions] $key would not evaluate, and has no version to record it against');
    return false;
  }
  final refused = {...settings.extensionRefused};
  if (refused[key] == version) return false;
  // Reported, not just printed: once a bundle is refused it never loads
  // again, so the boot failure stops arriving under `extensions:restart`
  // after at most two attempts per install. The rate here is what says
  // whether one download went bad or the catalog is serving something this
  // app cannot run to everybody.
  ErrorReportingService.report(BundleWouldNotEvaluate(key, version), StackTrace.current, context: 'extensions:refuse');
  refused[key] = version;
  await settings.setExtensionRefused(refused);
  return true;
}

/// The names of the built-ins the operator has switched on that the catalog
/// serves no twin of — what the upgrade withdrew with nothing to put in its
/// place.
///
/// Switched on NOW, not whenever the adoption last recorded them: one
/// switched off since was the operator's own choice, and naming it as lost
/// tells them something the upgrade did not do.
List<String> unservedBuiltInNames(ExtensionService service) =>
    _names(service, (info) => info.source == ExtensionSource.asset && kBuiltInsWithoutTwin.contains(info.key) && service.isExtensionEnabled(info));

/// The names of the extensions that arrived and would not run.
///
/// Told apart from [unservedBuiltInNames] because the remedy is the opposite:
/// nothing replaces a built-in the catalog does not serve, while one of these
/// is installed, served, and one update away from working — so a sentence
/// sending the operator to look for a substitute would send them nowhere.
///
/// `isExtensionEnabled` is false for a refused extension, so the operator's
/// own choice is read from the override: one they switched off is no loss.
///
/// And AVAILABLE: after a revert, a downloaded copy is superseded by the
/// built-in it replaced — its panel row is gone, there is nothing to update,
/// and the extension the operator knows by that name is running. Naming it
/// as one that "would not run" tells them something false twice over.
List<String> refusedExtensionNames(ExtensionService service) =>
    _names(service, (info) => service.isExtensionRefused(info) && service.isExtensionAvailable(info) && service.isExtensionSwitchedOn(info));

/// A set, because a key can appear twice — `ham2k-lookup` ships as an asset
/// and is pre-loaded — and naming it twice reads as two extensions lost.
List<String> _names(ExtensionService service, bool Function(ExtensionInfo) include) {
  // The name the Extensions panel gave it. A dialog that is otherwise in the
  // operator's language naming an extension in English names something they
  // have never seen under that name.
  final locale = LocaleSettings.currentLocale.languageCode;
  return {
    for (final info in service.availableExtensions)
      if (include(info)) info.nameFor(locale),
  }.toList();
}

/// The boot-time half: whatever is still owed from an upgrade already taken.
///
/// A pre-load the app update brought, and any twin a previous launch could not
/// download. Never throws into the caller — this is fire-and-forget off the
/// end of a boot, and an exception escaping here has no one left to catch it.
Future<void> catchUpOnCatalogExtensions(ExtensionService service) async {
  if (_inFlight) return;
  _inFlight = true;
  try {
    var landed = await service.preloadShippedExtensions();
    // Re-read before the adoption looks, or "after the pre-load" is not true
    // of the list it reads: what the pre-load just installed would be fetched
    // from the catalog as well.
    if (landed) await service.reloadAvailableExtensions();
    landed = (await service.adoptTwins()).landed || landed;
    if (landed) {
      await service.reloadAvailableExtensions();
      // Fresh: this runs unawaited from inside `_start`, so the replacement
      // that boot came through is still in flight and would be handed back —
      // leaving what was just installed unloaded until the next launch.
      await service.restartRuntime(fresh: true);
    }
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'extensions:preload');
  } finally {
    _inFlight = false;
  }
}
