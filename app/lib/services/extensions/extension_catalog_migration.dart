// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeping an install's catalog extensions in hand (docs/design/extension-install.md):
// the bundles the app ships, the catalog copies of the built-ins it no longer
// has, and whatever the operator installed that the store lost.
//
// The app builds in only its core extensions. An install that ran the others
// as built-ins moves onto their catalog copies at its first boot on a build
// without them — unasked, since there is nothing left to run instead —
// carrying each one's settings, credentials and on/off choice across.
// `SettingsService.extensionsMigrated` records that the move is done.
//
// An install can hold every bundle the app ships, switched on or not. Those
// switched off are taken out of the store once, their settings kept
// (`SettingsService.extensionsSwitchedOffRemoved`).

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, mapEquals;

import 'package:halo_i18n/halo_i18n.dart';

import 'catalog_service.dart';
import '../error_reporting_service.dart';
import 'extension_service.dart';
import 'installed_extensions.dart' show BundleProvenance, CatalogChannel;
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

/// A bundle the engine would not evaluate, now kept out of the runtime.
class BundleWouldNotEvaluate implements Exception {
  const BundleWouldNotEvaluate(this.key, this.version);

  final String key;
  final String version;

  @override
  String toString() => '$key $version would not evaluate; keeping it out of the runtime';
}

/// Extensions that just arrived left the install running none at all, even
/// with every bundle the boot named set aside.
///
/// Its own type so the crash backend can answer "how often does a batch of
/// installs leave an install with no runtime at all?" — the boot failure
/// itself reports under `extensions:restart`, where it cannot be told from any
/// other crash.
class UpgradeLeftNoRuntime implements Exception {
  const UpgradeLeftNoRuntime();

  @override
  String toString() => 'extensions that just arrived were set aside and the runtime still did not start';
}

/// True while a catch-up or a restore is in flight.
///
/// Both run off a runtime start, and a start happens again on every restart —
/// an extension toggled in the panel, a runtime that died. Without this a
/// restart during the downloads begins a second pass over the same
/// `extensionAdopted` snapshot: the same keys fetched and installed twice, and
/// whichever pass writes its records last discards the other's.
///
/// Completed as the pass ends, for a caller that must run one of its own
/// rather than step aside ([settleOnboardingExtensions]).
Completer<void>? _pass;

bool get _inFlight => _pass != null;

/// The services whose launch has already tried the one-time removal over a
/// store it could read. One that would not come out is tried again next
/// launch, not on every restart — each of which runs a catch-up.
final _sweepTried = Expando<bool>('sweepTried');

void _hold() => _pass = Completer<void>();

void _release() {
  _pass?.complete();
  _pass = null;
}

/// Records [key] as a bundle that will not evaluate, and answers whether that
/// is news — a key already refused at this version was tried before, and
/// refusing it again would restart the runtime for nothing.
Future<bool> _refuse(ExtensionService service, SettingsService settings, String key) async {
  // The INSTALLED entry: only an installed bundle is ever put aside. One the
  // app builds in that will not evaluate is a defect in the app, and skipping
  // it would ship an install quietly missing part of itself.
  final version = service.availableExtensions.where((info) => info.key == key && info.isInstalled).map((info) => info.version).firstOrNull;
  // Nothing to key the refusal to, so nothing that a later version could
  // lift.
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

/// The names of the retired built-ins the operator had switched on that the
/// catalog serves no twin of — what the move off the built-ins leaves with
/// nothing in its place.
List<String> unservedBuiltInNames(SettingsService settings) => [
  for (final builtIn in kBuiltInsWithoutTwin)
    if (retiredBuiltInWasOn(settings, builtIn)) _retiredName(builtIn),
];

/// In the operator's language: a dialog otherwise in theirs naming an
/// extension in English names something they have never seen under that name.
String _retiredName(String builtIn) => switch (builtIn) {
  'qp' => t.extensionsPanel.retiredQp,
  'stateparks' => t.extensionsPanel.retiredStateparks,
  _ => builtIn,
};

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
/// And AVAILABLE: one hidden by an experiment has no panel row to update from.
List<String> refusedExtensionNames(ExtensionService service) =>
    _names(service, (info) => service.isExtensionRefused(info) && service.isExtensionAvailable(info) && service.isExtensionSwitchedOn(info));

/// A set, because the list can hold a key twice — a dev-served copy over an
/// installed one — and naming it twice reads as two extensions lost.
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

/// Whatever the install is owed at boot: the move off the built-ins, if it has
/// not happened; a pre-load the app update brought; the twin of any retired
/// built-in the operator had on that is not installed yet; and, once, the
/// pre-loaded bundles and built-ins' twins they have switched off taken out
/// of the store — every time when [removeSwitchedOff]. Without [fetch], the
/// adoption, the one step that waits on the catalog, is skipped.
///
/// Nothing is installed until onboarding has been answered: the bundles to
/// pre-load are the activities it asks about, and installing on their
/// defaults first leaves whichever the operator then turns down installed
/// and switched off. Onboarding settles them when it is done
/// ([settleOnboardingExtensions]).
///
/// Never throws into the caller — this is fire-and-forget off the end of a
/// boot, and an exception escaping here has no one left to catch it.
///
/// Answers whether it ran: false when another catch-up or a restore already
/// holds the flag — as the restart this one triggers does, re-entering from
/// `_start` — so "done" is only ever the outermost run's; and false with no
/// settings yet, which the boot wires in only after starting the runtime.
/// Without them nothing can be carried or recorded, so that one does not
/// count: wiring them runs it again (`HaLoServices`).
Future<bool> catchUpOnCatalogExtensions(ExtensionService service, {bool removeSwitchedOff = false, bool fetch = true}) async {
  if (_inFlight) return false;
  final settings = service.settings;
  if (settings == null) {
    debugPrint('[extensions] catch-up waits for settings to be wired');
    return false;
  }
  _hold();
  try {
    final answered = settings.defaultProfileCallsignDefined;
    // Not before onboarding is answered: the move is recorded done once the
    // pre-load has run, and until then the pre-load installs nothing.
    final moving = answered && !settings.extensionsMigrated;
    if (moving) await carryBuiltInChoicesToTwins(settings);
    final refusedBefore = settings.extensionRefused;
    final landed = answered && await service.preloadShippedExtensions();
    // Re-read before the adoption looks, or "after the pre-load" is not true
    // of the list it reads: what the pre-load just installed would be fetched
    // from the catalog as well.
    if (landed) await service.reloadAvailableExtensions();
    final adopted = answered && fetch && (await service.adoptTwins()).landed;
    if (adopted) await service.reloadAvailableExtensions();
    final sweeping = removeSwitchedOff || (!settings.extensionsSwitchedOffRemoved && _sweepTried[service] != true);
    final swept = sweeping ? await _removeSwitchedOff(service, settings) : (removed: false, complete: false);
    if (sweeping && service.installed?.storedKeys != null) _sweepTried[service] = true;
    final removed = swept.removed;
    if (removed) await service.reloadAvailableExtensions();
    var dead = false;
    if (landed || adopted || removed) {
      // Fresh: this runs unawaited from inside `_start`, so the replacement
      // that boot came through is still in flight and would be handed back —
      // leaving what was just installed unloaded until the next launch.
      await service.restartRuntime(fresh: true);
      dead = await _setAsideWhatWillNotRun(service, settings, attempts: service.availableExtensions.length, context: 'extensions:preload');
    }
    // After the pre-load, not before: a boot killed half way carries the
    // choices again next time, which is harmless, while a flag written first
    // would leave the twins it never installed without them.
    if (moving) await settings.setExtensionsMigrated(true);
    // Only once it saw the whole store and cleared it: a store that would not
    // read lists nothing installed, and recorded done, what it holds stays.
    if (swept.complete) await settings.setExtensionsSwitchedOffRemoved(true);
    final newlyRefused = !mapEquals(refusedBefore, settings.extensionRefused);
    if (moving || dead || newlyRefused) _announce(service, settings, moved: moving, dead: dead);
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'extensions:preload');
  } finally {
    _release();
    service.markFirstCatchUpDone();
  }
  return true;
}

/// Brings the installed extensions in line with what onboarding just
/// recorded: the shipped bundles it switched on installed and, on a
/// [firstRun], any it switched off taken back out — a catch-up that ran
/// between the callsign step and the last one installed on the defaults.
/// Not on a replay (DEVONBOARD): the install is the operator's own, and what
/// they keep switched off is theirs.
///
/// Waits out a pass already running rather than stepping aside: onboarding
/// happens once, and its choices would otherwise wait for the next launch.
/// Fetches nothing — what onboarding offers ships with the app — so the
/// operator is not kept waiting on the catalog.
///
/// Nothing before the store has been read — `ONBOARD_AS`, or a Skip, as the
/// app comes up: the boot's own catch-up is still to come, and finds
/// onboarding answered. Run now, it would settle that first catch-up early.
Future<void> settleOnboardingExtensions(ExtensionService service, {required bool firstRun}) async {
  if (service.installed == null) return;
  for (var pass = _pass; pass != null; pass = _pass) {
    await pass.future;
  }
  await catchUpOnCatalogExtensions(service, removeSwitchedOff: firstRun, fetch: false);
}

/// Takes out of the store every pre-loaded bundle and built-in's twin that
/// is switched off, keeping what the operator set for each. Answers whether
/// any went, and whether the job is complete: the store was read, and
/// everything due came out.
///
/// Only those: the app put them there, whatever their switch. Any other
/// catalog extension the operator went and got, and keeps switched off
/// between the events it is for; a file install, nothing could bring back.
///
/// By the operator's own switch, not by whether it runs: one revoked,
/// refused or behind an experiment that they have on comes back to life with
/// an update or the experiment, and is theirs to keep.
Future<({bool removed, bool complete})> _removeSwitchedOff(ExtensionService service, SettingsService settings) async {
  if (service.installed?.storedKeys == null) return (removed: false, complete: false);
  final records = settings.extensionInstalledFrom;
  final keys = {
    for (final info in service.availableExtensions)
      if (info.isInstalled && !service.isExtensionSwitchedOn(info))
        if (BundleProvenance.fromJson(records[info.key]) case final from? when from.isPreloaded || predecessorBuiltInKey(info.key) != null) info.key,
  };
  if (keys.isEmpty) return (removed: false, complete: true);
  final removed = await service.removeKeepingSettings(keys);
  return (removed: removed.isNotEmpty, complete: removed.length == keys.length);
}

/// Tells the operator what a catch-up changed that they would otherwise only
/// find by its absence: that their extensions now come from the catalog, after
/// the move off the built-ins; and, whenever it happens, a runtime that would
/// not start or an extension put aside. A notice rather than a dialog: the
/// move was not theirs to decide, and most of the time nothing they use
/// changed.
///
/// The move also names what did not come along — a built-in with no twin, and
/// how many twins are still to arrive — since this is where the operator
/// learns either.
void _announce(ExtensionService service, SettingsService settings, {required bool moved, required bool dead}) {
  final unserved = moved ? unservedBuiltInNames(settings) : const <String>[];
  final missing = moved ? twinsStillWanted(settings, service.availableExtensions).length : 0;
  final refused = refusedExtensionNames(service);
  final panel = t.extensionsPanel;
  service.statusBar?.showNotice(
    key: 'extensions:upgradeResult',
    title: dead
        ? panel.upgradeRuntimeDeadTitle
        : moved
        ? panel.upgradeDoneTitle
        : panel.refusedTitle,
    text: [
      if (moved) panel.upgradeDoneBody,
      if (dead) panel.runtimeDeadBody,
      if (missing > 0) panel.upgradeDoneMissing(count: missing),
      if (unserved.isNotEmpty) '${panel.upgradeDoneUnserved(names: unserved.join(', '))} ${panel.upgradeDoneUnservedHint}',
      if (refused.isNotEmpty) '${panel.upgradeDoneRefused(names: refused.join(', '))} ${panel.upgradeDoneRefusedHint}',
    ].join('\n\n'),
  );
}

/// Restarts without each bundle the boot dies on, one at a time, up to
/// [attempts] times: one bundle that will not evaluate takes the whole
/// generation down with it (`EngineRuntime.load` throws if any bundle fails),
/// and the boot names it so the rest do not have to go down too.
///
/// A boot failure cannot be thrown at us: `_start` catches everything and
/// schedules the crash backoff, so the runtime's health is asked directly.
/// Reports an install left running nothing, and answers whether it was.
Future<bool> _setAsideWhatWillNotRun(ExtensionService service, SettingsService? settings, {required int attempts, required String context}) async {
  for (var attempt = 0; attempt < attempts && !service.runtimeIsHealthy && settings != null; attempt++) {
    final culprit = service.lastStartFailureKey;
    if (culprit == null || !await _refuse(service, settings, culprit)) break;
    await service.reloadAvailableExtensions();
    await service.restartRuntime(fresh: true);
  }
  if (service.runtimeIsHealthy) return false;
  ErrorReportingService.report(const UpgradeLeftNoRuntime(), StackTrace.current, context: context);
  return true;
}

/// What putting missing extensions back came to, by name.
class RestoreResult {
  const RestoreResult({this.installed = const [], this.failed = const [], this.wouldNotRun = const [], this.busy = false, this.runtimeDead = false});

  final List<String> installed;

  /// Not in the listing, not downloaded, or refused by the check — offered
  /// again next launch, since they are still missing.
  final List<String> failed;

  /// Installed, and would not run: set aside so the others do, kept
  /// installed and marked in the Extensions panel, where an update is the way
  /// back.
  final List<String> wouldNotRun;

  /// Nothing was tried: another catalog pass held the store. Every one is
  /// still missing, and offered again next launch.
  final bool busy;

  /// What landed is installed, and the runtime would not start with it — for
  /// a reason no installed bundle is named in, so none could be set aside.
  final bool runtimeDead;
}

/// Installs the [wanted] extensions the catalog can put back, each on its
/// own: one that cannot be downloaded or checked costs only itself. The
/// runtime restarts with everything that landed, and a bundle the engine
/// will not evaluate is set aside — as the catch-up does — and named, rather
/// than taking the others down.
Future<RestoreResult> restoreMissingExtensions(ExtensionService service, List<MissingExtension> wanted) async {
  final fetchable = [
    for (final missing in wanted)
      if (missing.fetchable) missing,
  ];
  final names = {for (final missing in fetchable) missing.key: missing.name};
  // Held like an upgrade: a catch-up running beside this would read the store
  // mid-write. The console is the only place that says why nothing happened.
  if (_inFlight) {
    debugPrint('[extensions] restore declined: a catalog pass is already running');
    return const RestoreResult(busy: true);
  }
  final catalog = service.catalog;
  if (catalog == null) {
    ErrorReportingService.report(const CatalogNotWired(), StackTrace.current, context: 'extensions:restore');
    return RestoreResult(failed: names.values.toList());
  }
  _hold();
  try {
    // Each on the track it followed — its record outlives the store — with
    // one listing per track in use. Forced: the operator is watching this,
    // and a listing from before they went offline and came back is the one
    // thing that would fail every key.
    final tracks = {for (final missing in fetchable) missing.key: catalog.channelFollowedBy(missing.key)};
    final listings = <CatalogChannel, Map<String, CatalogEntry>?>{
      for (final channel in tracks.values.toSet())
        channel: switch (await catalog.fetchCatalog(force: true, channel: channel)) {
          final listing? => {for (final entry in listing) entry.key: entry},
          null => null,
        },
    };
    final landed = <String>[];
    final failed = <String>[];
    for (final missing in fetchable) {
      final listing = listings[tracks[missing.key]];
      final entry = listing?[missing.key];
      if (entry == null) {
        // Unreachable, or no longer served here — withdrawn, another channel,
        // an API this build does not speak. The operator can Forget it.
        debugPrint('[extensions] restore: ${missing.key} is not in the catalog listing${listing == null ? ' (no listing)' : ''}');
        failed.add(missing.key);
        continue;
      }
      try {
        await service.reinstallFromCatalog(entry);
        landed.add(missing.key);
      } catch (e, stack) {
        failed.add(missing.key);
        ErrorReportingService.report(e, stack, context: 'extensions:restore');
      }
    }
    var runtimeDead = false;
    if (landed.isNotEmpty) {
      await service.reloadAvailableExtensions();
      await service.restartRuntime(fresh: true);
      // Bounded by what landed, since only those are new to this runtime.
      // "Installed again" over a runtime running nothing is the worst answer
      // this can give, so that is asked too.
      runtimeDead = await _setAsideWhatWillNotRun(service, service.settings, attempts: landed.length, context: 'extensions:restore');
    }
    final wouldNotRun = {
      for (final info in service.availableExtensions)
        if (landed.contains(info.key) && service.isExtensionRefused(info)) info.key,
    };
    return RestoreResult(
      installed: [
        for (final key in landed)
          if (!wouldNotRun.contains(key)) names[key]!,
      ],
      failed: [for (final key in failed) names[key]!],
      wouldNotRun: [for (final key in wouldNotRun) names[key]!],
      runtimeDead: runtimeDead,
    );
  } finally {
    _release();
  }
}
