// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extensions the app ships already packaged (docs/extensions/distribution.md).
//
// The app builds in only its core extensions. Everything else is a catalog
// bundle: some shipped as `.h2kext` files under `assets/preloaded-extensions/`
// and installed into the ordinary store on first run, the rest fetched from
// the catalog. Once installed they are ordinary installed extensions: the
// same panel rows, the same update check, the same Update and uninstall.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, mapEquals;
import 'package:flutter/services.dart' show rootBundle;
import 'package:halo_extension_host/halo_extension_host.dart' show kRetiredBuiltIns;
import 'package:pub_semver/pub_semver.dart';

import 'catalog_service.dart';
import '../error_reporting_service.dart';
import 'extension_info.dart';
import 'installed_extensions.dart';
import '../settings_service.dart';

export 'package:halo_extension_host/halo_extension_host.dart' show kRetiredBuiltIns;

/// The index shipped beside the bundles, naming each one.
const kPreloadIndexAsset = 'assets/preloaded-extensions/index.json';
const kPreloadAssetDir = 'assets/preloaded-extensions';

/// The catalog's name for the retired built-in [builtIn].
String twinOf(String builtIn) => '$kReservedKeyPrefix$builtIn';

/// Whether the operator had the retired built-in [builtIn] switched on: their
/// own choice where they made one, else its default.
bool retiredBuiltInWasOn(SettingsService settings, String builtIn) => settings.extensionOverrides[builtIn] ?? kRetiredBuiltIns[builtIn] ?? false;

/// Retired built-ins the catalog deliberately serves no twin of: nothing
/// replaces them when they go.
///
/// Named here rather than inferred from a listing that lacks the twin: that
/// absence reads the same whether the catalog will never serve a key or has
/// not published it yet, and only the first may stop asking for it. A key
/// retired from the catalog on purpose is added here in the same change.
///
/// `qp` is served as one extension per party, and `stateparks` as one per
/// event — `ham2k-flspota`, `ham2k-gaspota`, `ham2k-ohspota`, `ham2k-txspota`
/// and `ham2k-wispota` (docs/design/contests.md §5.6). Each carries the legacy
/// `{type: 'qp' | 'stateparks', ref: …}` an existing operation already holds,
/// so the events outlive it; the built-in they were split out of is
/// what has no twin, and the operator installs the ones they want.
const kBuiltInsWithoutTwin = {'qp', 'stateparks'};

/// Writes each retired built-in's on/off choice onto its twin, over whatever
/// the twin holds.
///
/// For an install moving off the built-ins. The pre-load carries a choice only
/// on its FIRST install, so twins an earlier attempt already installed still
/// hold that attempt's choices — and a built-in switched in between would be
/// lost. Overwriting is right here: until the move, the twin never ran, so the
/// built-in's choice is the only one the operator could have made.
Future<void> carryBuiltInChoicesToTwins(SettingsService settings) async {
  final overrides = settings.extensionOverrides;
  final carried = {
    for (final builtIn in kRetiredBuiltIns.keys)
      if (overrides[builtIn] case final on? when overrides[twinOf(builtIn)] != on) twinOf(builtIn): on,
  };
  if (carried.isNotEmpty) await settings.setExtensionOverrides({...overrides, ...carried});
}

/// The retired built-in whose stored state [key] inherits, or null — `wca`
/// for `ham2k-wca`, nothing for a catalog key that merely looks like one.
String? predecessorBuiltInKey(String key) {
  if (!key.startsWith(kReservedKeyPrefix)) return null;
  final stripped = key.substring(kReservedKeyPrefix.length);
  return kRetiredBuiltIns.containsKey(stripped) ? stripped : null;
}

/// One `.h2kext` the app ships, as `index.json` names it.
class PreloadedBundle {
  final String key;
  final String version;

  /// The asset's file name, not a path: the directory is [kPreloadAssetDir],
  /// so nothing read from the index can point the loader anywhere else.
  final String file;

  /// Lowercase hex of the asset's bytes. Not a security check — the bytes
  /// ship inside the app — but it is what the install records as provenance,
  /// and what an update compares against.
  final String sha256;

  const PreloadedBundle({required this.key, required this.version, required this.file, required this.sha256});

  /// The built-in whose stored state this one inherits, or null.
  String? get replaces => predecessorBuiltInKey(key);

  String get assetPath => '$kPreloadAssetDir/$file';

  /// Lenient per entry: an unreadable one is dropped rather than costing the
  /// operator all the others. A file name is refused if it names anything
  /// but a plain file, so the index cannot reach outside its own directory.
  static PreloadedBundle? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final version = json['version'];
    final file = json['file'];
    final sha256 = json['sha256'];
    if (key is! String || key.isEmpty) return null;
    if (version is! String || version.isEmpty) return null;
    if (file is! String || !_safeFilePattern.hasMatch(file)) return null;
    if (sha256 is! String || !_sha256Pattern.hasMatch(sha256)) return null;
    return PreloadedBundle(key: key, version: version, file: file, sha256: sha256.toLowerCase());
  }

  static final _safeFilePattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*\.h2kext$');
  static final _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');
}

/// Every bundle the index names, in the order it names them.
List<PreloadedBundle> parsePreloadIndex(Object? json) {
  if (json is! Map) return const [];
  final raw = json['preloaded'];
  if (raw is! List) return const [];
  return [for (final entry in raw) ?PreloadedBundle.fromJson(entry)];
}

/// Whether [bundle] should be installed now.
///
/// [preloadedVersion] is the highest version of this key the app has ever
/// pre-loaded (`SettingsService.extensionPreloaded`) and [installedVersion]
/// what the store holds, either null when there is none.
///
/// Three questions, in this order, and the order is the whole rule:
///
/// 1. Have we already offered this bundle, or a newer one? Then no —
///    whatever became of it. This is what makes an uninstall stick, and what
///    stops every launch reinstalling over an update the operator took.
/// 2. Is what is installed already this new? Then no. A catalog release ahead
///    of the shipped one must not be dragged backwards by an app that merely
///    launched.
/// 3. Otherwise yes: either nothing has been pre-loaded for this key, or the
///    app has been updated and now carries a newer bundle than it did.
///
/// A version neither side can parse answers no, because a bundle nobody can
/// order is not one to install over anything.
bool shouldPreload(PreloadedBundle bundle, {String? preloadedVersion, String? installedVersion}) {
  final shipped = _parse(bundle.version);
  if (shipped == null) return false;
  final preloaded = _parse(preloadedVersion);
  if (preloaded != null && shipped <= preloaded) return false;
  final installed = _parse(installedVersion);
  if (installed != null && shipped <= installed) return false;
  return true;
}

Version? _parse(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return Version.parse(raw);
  } catch (_) {
    return null;
  }
}

/// Installs whichever shipped bundles are due, and answers whether anything
/// landed.
///
/// Here rather than on ExtensionService because it is the rest of this
/// feature: the index, the decision, and the install are one idea, and the
/// service's two contributions — recording the install and copying keychain
/// items — arrive as callbacks.
///
/// [restoring] names bundles the operator had installed that the store no
/// longer holds (`SettingsService.extensionsInstalled`). They are installed
/// whatever the pre-load record says — it says they were already offered,
/// which is true and beside the point — and never as a first install: the
/// operator's settings and on/off choice are still under their key, and
/// carrying a predecessor's over them, or dropping the choice as stale, would
/// undo what they set.
///
/// Every failure is per-bundle and reported, never fatal. Every other
/// extension working and one that says why beats a boot that stops on the
/// first bad zip; a bundle the store refuses is not tried again, and anything
/// else is, and the adoption fetches the catalog's copy meanwhile when the
/// operator had it switched on.
Future<bool> installShippedExtensions({
  required InstalledExtensions store,
  required SettingsService settings,
  required Map<String, String?> installedVersions,
  required Future<void> Function(InspectedBundle bundle, {required bool fresh}) recordInstall,
  required Future<void> Function({required String from, required String to}) copySecrets,
  Set<String> restoring = const {},
  Future<ByteData> Function(String key)? loadAsset,
  Future<String> Function(String key)? loadIndex,
}) async {
  final assets = loadAsset ?? rootBundle.load;
  List<PreloadedBundle> shipped;
  try {
    shipped = parsePreloadIndex(jsonDecode(await (loadIndex ?? rootBundle.loadString)(kPreloadIndexAsset)));
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'extensions:preload-index');
    return false;
  }

  final preloaded = {...settings.extensionPreloaded};
  var installedAny = false;

  for (final bundle in shipped) {
    final restore = restoring.contains(bundle.key) && !installedVersions.containsKey(bundle.key);
    if (!restore && !shouldPreload(bundle, preloadedVersion: preloaded[bundle.key], installedVersion: installedVersions[bundle.key])) {
      continue;
    }
    final first = !restore && !preloaded.containsKey(bundle.key) && !installedVersions.containsKey(bundle.key);
    try {
      // Through the view's own offset and length: a ByteData from the bundle
      // may be a window into a shared buffer, and `.buffer.asUint8List()`
      // reads from the start of that buffer instead.
      final data = await assets(bundle.assetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final inspected = await store.inspect(
        bytes,
        provenance: BundleProvenance(host: kPreloadHost, sha256: sha256Hex(bytes), version: bundle.version),
      );
      // The predecessor's settings and credentials move BEFORE the install,
      // so the extension's first activation already sees them: an account
      // hook that finds no credentials on its first run reports itself
      // disconnected, and the operator is asked to log in to something they
      // never logged out of.
      final replaces = bundle.replaces;
      final carried = first && replaces != null;
      if (carried) {
        await settings.copyExtensionRecords(from: replaces, to: bundle.key);
        await copySecrets(from: replaces, to: bundle.key);
        // No choice to carry is still a state to carry: the built-in's own
        // default. An installed extension is on unless switched off, so
        // without this SOTA and WWFF, off by default as built-ins, arrive on
        // — for a moving install and for a new one that skips onboarding alike.
        final overrides = settings.extensionOverrides;
        final fallback = kRetiredBuiltIns[replaces];
        if (!overrides.containsKey(bundle.key) && fallback != null) {
          await settings.setExtensionOverrides({...overrides, bundle.key: fallback});
        }
      }
      // A choice already under this very key is the operator's too:
      // `ham2k-lookup` was built in under the name its pre-load has, so its
      // on/off choice needs no carrying and must not be dropped either.
      final ownChoice = settings.extensionOverrides.containsKey(bundle.key);
      await store.install(inspected);
      // NOT fresh where a predecessor's state was just carried, or the key
      // already holds a choice. `fresh` is what drops a stale on/off choice so
      // a key the store did not have runs — and these are not stale, they are
      // the operator's own about this very extension. Dropping one turns an
      // extension they had switched off back on.
      await recordInstall(inspected, fresh: first && !carried && !ownChoice);
      preloaded[bundle.key] = bundle.version;
      installedAny = true;
    } catch (e, stack) {
      // Recorded only when the BUNDLE is at fault: one the store refuses will
      // be refused on every launch, and retrying it costs a zip parse and the
      // same report forever. Anything else — a keychain that would not open, a
      // full disk — may pass next launch, and recorded as offered it never
      // would: the pre-load is the only thing that installs an extension the
      // operator had switched off.
      if (e is BundleException) preloaded[bundle.key] = bundle.version;
      ErrorReportingService.report(e, stack, context: 'extensions:preload:${bundle.key}');
    }
  }

  if (!mapEquals(preloaded, settings.extensionPreloaded)) await settings.setExtensionPreloaded(preloaded);
  return installedAny;
}

/// Copies the built-in predecessor's settings and credentials onto [key], and
/// answers whether there was one.
///
/// Copied rather than moved: a twin whose install fails after the carry has
/// to find the built-in's state still there on the next attempt.
Future<bool> carryPredecessorRecords({
  required String key,
  required SettingsService? settings,
  required Future<void> Function({required String from, required String to}) copySecrets,
}) async {
  if (settings == null) return false;
  final from = predecessorBuiltInKey(key);
  if (from == null) return false;
  await settings.copyExtensionRecords(from: from, to: key);
  await copySecrets(from: from, to: key);
  return true;
}

/// Installs the catalog's copy of every retired built-in the operator had
/// switched ON that is not installed yet, and answers whether anything landed.
///
/// The pre-load covers the ones the app ships. This fetches the rest — every
/// retired built-in the pre-load has not offered, which includes one it could
/// not install for a reason that may pass — carrying the settings and
/// credentials across so each comes back configured, rather than simply
/// vanishing with the activities an operator uses every day.
///
/// Only what was ON. An extension the operator had switched off is one they
/// chose not to run, and downloading it to leave it switched off is work
/// nobody asked for. An install that never ran the built-ins has no choice
/// recorded for them, so this falls to their defaults — on only for the ones
/// the app pre-loads anyway.
///
/// No consent screen: this is not the operator acquiring something, it is the
/// app keeping what they already had through a change of its own making — the
/// same extension, from the publisher whose copy they were already running.
///
/// A built-in in [kBuiltInsWithoutTwin] is never asked for. Any other twin the
/// listing lacks is NOT an answer: it leaves the job incomplete and is asked
/// for again next launch. `landed` is whether anything was installed — what
/// tells the caller to restart the runtime. `complete` is whether the job
/// finished: false when the catalog could not be reached or a download failed.
///
/// Every piece is nullable and answers false: this runs off the end of a boot
/// that may have got nowhere, and the preconditions belong with the work
/// rather than at the one call site that has to gather them.
Future<({bool landed, bool complete})> adoptCatalogTwins({
  required InstalledExtensions? store,
  required SettingsService? settings,
  required CatalogService? catalog,
  required List<ExtensionInfo> available,
  required Future<void> Function(InspectedBundle, {required bool fresh}) recordInstall,
  required Future<void> Function({required String from, required String to}) copySecrets,
}) async {
  if (store == null || settings == null || catalog == null) return (landed: false, complete: false);
  final adopted = {...settings.extensionAdopted};
  final wanted = twinsStillWanted(settings, available);
  if (wanted.isEmpty) return (landed: false, complete: true);

  // Ungeo'd deliberately: geo ranks a listing, and what this needs from it is
  // membership — whether the catalog has this key at all. Stable, whatever
  // the developer searches: these install with no consent screen.
  final listing = await catalog.fetchCatalog(channel: CatalogChannel.stable);
  if (listing == null) return (landed: false, complete: false);
  final offered = {for (final entry in listing) entry.key: entry};

  // Said, because it is the one reason adoption stalls that reports nothing
  // else: the extension simply stays missing, launch after launch, until the
  // catalog publishes the key.
  final missing = [
    for (final twin in wanted)
      if (!offered.containsKey(twin)) twin,
  ];
  if (missing.isNotEmpty) debugPrint('[extensions] catalog listing lacks ${missing.join(', ')}; adoption incomplete');

  var landed = false;
  var complete = true;
  for (final twin in wanted) {
    final entry = offered[twin];
    if (entry == null) {
      // Absence is not an answer: a listing cannot tell "never served" from
      // "not published on this channel yet", nor from an entry dropped as
      // unparseable or filtered out by the `api` parameter. Recording it would
      // retire a twin the catalog may well carry — which is why the built-ins
      // that truly have none are named in [kBuiltInsWithoutTwin] instead.
      complete = false;
      continue;
    }
    try {
      // Never fresh: the point of the adoption is that the operator's state
      // for this extension already exists, under the name it used to have.
      await installCatalogEntry(
        store: store,
        catalog: catalog,
        entry: entry,
        recordInstall: recordInstall,
        beforeInstall: () => carryPredecessorRecords(key: twin, settings: settings, copySecrets: copySecrets),
      );
      // Recorded only on success. A download that failed is almost always the
      // connection, which is the one thing that changes between launches —
      // recording the attempt would retire a twin the operator still needs on
      // the strength of a dropped Wi-Fi.
      adopted[twin] = entry.version;
      landed = true;
    } catch (e, stack) {
      // One twin that will not install must not cost the others theirs, but
      // the job as a whole did not finish.
      complete = false;
      ErrorReportingService.report(e, stack, context: 'extensions:adopt');
    }
  }
  await settings.setExtensionAdopted(adopted);
  return (landed: landed, complete: complete);
}

/// The twins of the retired built-ins the operator had switched on that are
/// not installed, and that neither the pre-load nor an earlier adoption has
/// already put in place — what [adoptCatalogTwins] goes and gets, and what a
/// move off the built-ins is still owed.
List<String> twinsStillWanted(SettingsService settings, List<ExtensionInfo> available) {
  final installed = {
    for (final info in available)
      if (info.isInstalled) info.key,
  };
  final adopted = settings.extensionAdopted;
  final preloaded = settings.extensionPreloaded;
  return [
    for (final builtIn in kRetiredBuiltIns.keys)
      // Not recorded as answered when skipped for having no twin: the day the
      // catalog serves this key and it leaves the list, every install that ever
      // ran this code would still be asking for it.
      if (!kBuiltInsWithoutTwin.contains(builtIn) && retiredBuiltInWasOn(settings, builtIn))
        // Not one the pre-load already offered: an operator who uninstalled
        // it would otherwise have it back, logged in again, at the next
        // restart.
        if (twinOf(builtIn) case final twin when !installed.contains(twin) && !adopted.containsKey(twin) && !preloaded.containsKey(twin)) twin,
  ];
}

/// Downloads [entry]'s release, checks it against the listing, and installs
/// it as an extension the operator already had — recorded never fresh, so
/// their on/off choice stands. [beforeInstall] runs between the check and the
/// write, for state that has to be in place before the first activation.
///
/// Throws whatever the download or the check throws, and writes nothing then.
Future<void> installCatalogEntry({
  required InstalledExtensions store,
  required CatalogService catalog,
  required CatalogEntry entry,
  required Future<void> Function(InspectedBundle, {required bool fresh}) recordInstall,
  Future<void> Function()? beforeInstall,
}) async {
  final bytes = await catalog.download(entry.release);
  final inspected = await store.inspect(
    bytes,
    provenance: BundleProvenance(host: catalog.host, sha256: entry.sha256, version: entry.version, channel: entry.channel),
  );
  await beforeInstall?.call();
  await store.install(inspected);
  await recordInstall(inspected, fresh: false);
}

/// Where a missing extension could come back from.
enum MissingFrom {
  /// A bundle the app ships: back from its own assets, at boot, unasked —
  /// or from the catalog, when this build no longer ships it.
  shipped,

  /// The catalog this build talks to.
  catalog,

  /// A catalog other than the one this build talks to now — the developer
  /// override, or production while it is on. Not fetched from here: the
  /// bytes would come from a publisher the operator never agreed to.
  otherCatalog,

  /// A file, which only the operator has.
  file,
}

/// An extension the operator installed that the store does not hold.
class MissingExtension {
  const MissingExtension({required this.key, required this.name, required this.from});

  final String key;
  final String name;
  final MissingFrom from;

  /// Whether the catalog this build talks to can put it back.
  bool get fetchable => from == MissingFrom.catalog || from == MissingFrom.shipped;
}
