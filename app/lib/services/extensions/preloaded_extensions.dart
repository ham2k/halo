// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extensions the app ships already packaged, for the upgrade to catalog
// extensions to start from (HALO-581, docs/extensions/distribution.md).
//
// Once upgraded the app offers none of its own extensions but the core ones,
// so it ships eight of the catalog's instead — `.h2kext` bundles
// under `assets/preloaded-extensions/`, installed into the ordinary store on
// first run. Once installed they are ordinary installed extensions: the same
// panel rows, the same update check, the same Update and uninstall.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, mapEquals;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pub_semver/pub_semver.dart';

import 'catalog_service.dart';
import '../error_reporting_service.dart';
import 'extension_info.dart';
import 'installed_extensions.dart';
import '../settings_service.dart';

/// The index shipped beside the bundles, naming each one.
const kPreloadIndexAsset = 'assets/preloaded-extensions/index.json';
const kPreloadAssetDir = 'assets/preloaded-extensions';

/// The built-in each pre-loaded extension takes over from, for the operator's
/// settings and credentials to follow it.
///
/// The catalog cannot serve a bare `pota`: the keys it hands Ham2K's own
/// publishers all carry the reserved prefix. So the catalog's copy of a
/// built-in is the same extension under a different name, and everything the
/// app stores per extension — its settings group, its panel values, its
/// account credentials, the operator's on/off choice — hangs off that name.
///
/// `ham2k-lookup` is absent because it is already called that as a built-in,
/// so there is nothing to carry. A key absent from this map simply has no
/// predecessor, which is the right answer for anything new.
const kPreloadReplaces = <String, String>{
  'ham2k-pota': 'pota',
  'ham2k-sota': 'sota',
  'ham2k-wwff': 'wwff',
  'ham2k-qrz': 'qrz',
  'ham2k-call-notes': 'call-notes',
  'ham2k-spot-history': 'spot-history',
  'ham2k-call-history': 'call-history',
};

/// Built-ins the catalog deliberately serves no twin of, so the upgrade
/// withdraws them with nothing to replace them.
///
/// Named here rather than inferred from a listing that lacks the twin: that
/// absence reads the same whether the catalog will never serve a key or has
/// not published it yet, and only the first may end the upgrade. A key
/// retired from the catalog on purpose is added here in the same change.
///
/// `qp` is served as one extension per party, and `stateparks` as one per
/// event — `ham2k-flspota`, `ham2k-gaspota`, `ham2k-ohspota`, `ham2k-txspota`
/// and `ham2k-wispota` (docs/design/contests.md §5.6). Each carries the legacy
/// `{type: 'qp' | 'stateparks', ref: …}` an existing operation already holds,
/// so the events survive the upgrade; the built-in they were split out of is
/// what has no twin, and the operator keeps it until they install the ones
/// they want.
const kBuiltInsWithoutTwin = {'qp', 'stateparks'};

/// Writes each built-in's on/off choice onto the shipped twin that replaces
/// it, over whatever the twin holds.
///
/// For an upgrade being taken. The pre-load carries a choice only on its
/// FIRST install, so an upgrade that reverted and is taken again finds its
/// twins already there, still holding the first attempt's choices — and a
/// built-in switched in between would be lost. Overwriting is right here:
/// while the upgrade is not taken the twin is withdrawn, so the built-in's
/// choice is the only one the operator could have made.
Future<void> carryBuiltInChoicesToTwins(SettingsService settings) async {
  final overrides = settings.extensionOverrides;
  final carried = {
    for (final MapEntry(key: twin, value: builtIn) in kPreloadReplaces.entries)
      if (overrides[builtIn] case final on? when overrides[twin] != on) twin: on,
  };
  if (carried.isNotEmpty) await settings.setExtensionOverrides({...overrides, ...carried});
}

/// The built-in whose stored state [key] inherits, or null.
///
/// [kPreloadReplaces] first, for the seven whose names do not follow the rule;
/// otherwise the rule itself — the catalog serves Ham2K's own extensions under
/// the reserved prefix, so `ham2k-wca` is the built-in `wca` under a name the
/// catalog can carry.
///
/// A key that IS a built-in has no predecessor, whatever it starts with:
/// `ham2k-lookup` is called that as a built-in too, and stripping the prefix
/// would hand it the state of a different extension entirely.
///
/// [builtInKeys] is what the app SHIPS, not what it currently offers — the two
/// differ exactly when this matters. Once migrated, `isBuiltInOffered` is
/// false for every non-core built-in, so a set of the offered ones is core-only
/// and every predecessor here would come back null: each adopted twin would
/// arrive unconfigured and logged out, which is the one thing adoption exists
/// to prevent. A catalog key that merely looks like a built-in —
/// `ham2k-something-nobody-shipped` — still inherits nothing.
String? predecessorBuiltInKey(String key, Set<String> builtInKeys) {
  if (builtInKeys.contains(key)) return null;
  final named = kPreloadReplaces[key];
  if (named != null) return named;
  if (!key.startsWith(kReservedKeyPrefix)) return null;
  final stripped = key.substring(kReservedKeyPrefix.length);
  return builtInKeys.contains(stripped) ? stripped : null;
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
  String? get replaces => kPreloadReplaces[key];

  String get assetPath => '$kPreloadAssetDir/$file';

  /// Lenient per entry: an unreadable one is dropped rather than costing the
  /// operator the other seven. A file name is refused if it names anything
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
/// [builtInDefaults] is each shipped built-in's `enabledByDefault`, for a
/// predecessor the operator never switched either way.
///
/// Every failure is per-bundle and reported, never fatal. Seven working
/// extensions and one that says why beats a boot that stops on the first bad
/// zip, and the operator can install the missing one from the catalog by
/// hand, which is the same path anyone else takes.
Future<bool> installShippedExtensions({
  required InstalledExtensions store,
  required SettingsService settings,
  required Map<String, String?> installedVersions,
  required Map<String, bool> builtInDefaults,
  required Future<void> Function(InspectedBundle bundle, {required bool fresh}) recordInstall,
  required Future<void> Function({required String from, required String to}) copySecrets,
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
    if (!shouldPreload(bundle, preloadedVersion: preloaded[bundle.key], installedVersion: installedVersions[bundle.key])) {
      continue;
    }
    // Recorded whatever happens next. A bundle that cannot be installed is
    // one this app will not manage to install on the next launch either, and
    // retrying it every boot costs a zip parse and reports the same failure
    // forever.
    final first = !preloaded.containsKey(bundle.key) && !installedVersions.containsKey(bundle.key);
    preloaded[bundle.key] = bundle.version;
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
        // — for an upgrade and for a new install that skips onboarding alike.
        final overrides = settings.extensionOverrides;
        final fallback = builtInDefaults[replaces];
        if (!overrides.containsKey(bundle.key) && fallback != null) {
          await settings.setExtensionOverrides({...overrides, bundle.key: fallback});
        }
      }
      await store.install(inspected);
      // NOT fresh where a predecessor's state was just carried. `fresh` is
      // what drops a stale on/off choice so a key the store did not have
      // runs — and the choice here is not stale, it is the one the operator
      // made about this very extension under its old name, copied three
      // lines ago. Dropping it turns every extension they had switched off
      // back on the moment the experiment is flipped.
      await recordInstall(inspected, fresh: first && !carried);
      installedAny = true;
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'extensions:preload:${bundle.key}');
    }
  }

  if (!mapEquals(preloaded, settings.extensionPreloaded)) await settings.setExtensionPreloaded(preloaded);
  return installedAny;
}

/// Copies the built-in predecessor's settings and credentials onto [key], and
/// answers whether there was one.
///
/// Copied rather than moved, like the pre-load's own carry: turning the
/// experiment back off has to find the built-in exactly as it was.
Future<bool> carryPredecessorRecords({
  required String key,
  required SettingsService? settings,
  required Set<String> builtInKeys,
  required Future<void> Function({required String from, required String to}) copySecrets,
}) async {
  if (settings == null) return false;
  final from = predecessorBuiltInKey(key, builtInKeys);
  if (from == null) return false;
  await settings.copyExtensionRecords(from: from, to: key);
  await copySecrets(from: from, to: key);
  return true;
}

/// Installs the catalog's copy of every built-in the operator had switched ON,
/// and answers whether anything landed.
///
/// The experiment withdraws all forty-one of the app's own extensions and
/// ships eight; the other thirty-three would simply vanish, taking the
/// activities an operator uses every day with them. This fetches their twins
/// instead, carrying the settings and credentials across so the extension
/// comes back configured.
///
/// Only what was ON. An extension the operator had switched off is one they
/// chose not to run, and downloading it to leave it switched off is work
/// nobody asked for.
///
/// No consent screen: this is not the operator acquiring something, it is the
/// app keeping what they already had through a change of its own making — the
/// same bundle, from the publisher whose copy they were already running.
/// Nothing here reaches a key the app does not itself ship.
///
/// A built-in in [kBuiltInsWithoutTwin] is recorded as answered without
/// asking the catalog. Any other twin the listing lacks is NOT an answer: it
/// leaves the job incomplete and is asked for again next launch.
/// `landed` is whether anything was installed — what tells the caller to
/// restart the runtime. `complete` is whether the job finished: false when the
/// catalog could not be reached or a download failed, which is what stops the
/// upgrade declaring itself done.
///
/// Every piece is nullable and answers false: this runs off the end of a boot
/// that may have got nowhere, and the preconditions belong with the work
/// rather than at the one call site that has to gather them.
Future<({bool landed, bool complete})> adoptCatalogTwins({
  required InstalledExtensions? store,
  required SettingsService? settings,
  required CatalogService? catalog,
  required List<ExtensionInfo> available,
  required bool Function(ExtensionInfo) isEnabled,
  required Future<void> Function(InspectedBundle, {required bool fresh}) recordInstall,
  required Future<void> Function({required String from, required String to}) copySecrets,
}) async {
  if (store == null || settings == null || catalog == null) return (landed: false, complete: false);
  // Only once migrated: before that the app runs its own extensions, and
  // fetching their twins would put two of each in the panel.
  if (!settings.catalogExtensionsInUse) return (landed: false, complete: true);
  // Everything the app ships, offered or withdrawn — see predecessorBuiltInKey.
  final shipped = {
    for (final info in available)
      if (info.source == ExtensionSource.asset) info.key,
  };
  final installed = {
    for (final info in available)
      if (info.isInstalled) info.key,
  };
  final adopted = {...settings.extensionAdopted};
  final wanted = <String>[];
  for (final info in available) {
    if (info.source != ExtensionSource.asset || info.core) continue;
    if (!isEnabled(info)) continue;
    // A built-in already carrying the prefix IS its own catalog name;
    // prefixing again asks for `ham2k-ham2k-lookup`, which nothing serves and
    // which would then be recorded as answered forever.
    if (info.key.startsWith(kReservedKeyPrefix)) continue;
    final twin = '$kReservedKeyPrefix${info.key}';
    if (shipped.contains(twin) || installed.contains(twin) || adopted.containsKey(twin)) continue;
    // Not recorded: the record would be read as "already answered" on every
    // later launch, so the day the catalog serves this key and it leaves the
    // list, no install that ever ran this code would fetch it.
    if (kBuiltInsWithoutTwin.contains(info.key)) continue;
    wanted.add(twin);
  }
  if (wanted.isEmpty) return (landed: false, complete: true);

  // Ungeo'd deliberately: geo ranks a listing, and what this needs from it is
  // membership — whether the catalog has this key at all.
  final listing = await catalog.fetchCatalog();
  if (listing == null) return (landed: false, complete: false);
  final offered = {for (final entry in listing) entry.key: entry};

  // Said, because it is the one reason the upgrade fails that reports nothing
  // else: the operator only sees "we couldn't finish", launch after launch,
  // until the catalog publishes the key.
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
      final bytes = await catalog.download(entry.release);
      final inspected = await store.inspect(
        bytes,
        provenance: BundleProvenance(host: catalog.host, sha256: entry.sha256, version: entry.version),
      );
      await carryPredecessorRecords(key: twin, settings: settings, builtInKeys: shipped, copySecrets: copySecrets);
      await store.install(inspected);
      // Never fresh: the point of the adoption is that the operator's state
      // for this extension already exists, under the name it used to have.
      await recordInstall(inspected, fresh: false);
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
