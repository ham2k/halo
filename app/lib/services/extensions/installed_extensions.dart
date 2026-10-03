// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extensions the operator installed from a `.h2kext` file (HALO-422).
//
// The format is a zip holding `manifest.json`, a built `index.js`, and an
// optional `assets/` — see extensions/tools/h2kext.mjs, which writes them.
//
// Reading one is deliberately two steps. `inspect` opens the file and answers
// what it is and what it wants, WITHOUT writing anything; `install` commits it.
// The gap between them is where the operator is asked, and a consent screen
// that could only be shown after the thing was already unpacked would not be
// one.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../error_reporting_service.dart';
import 'bundle_storage.dart';
import 'extension_relevance.dart';
import 'extension_service.dart';

/// The extension API this build speaks. A bundle declares the one it was built
/// against and anything newer is refused, so an old app meeting a new bundle
/// says so rather than failing somewhere inside a hook. Kept equal to the
/// packer's `H2KEXT_API_VERSION` (extensions/tools/h2kext.mjs), which lists
/// what each version adds.
const kExtensionApiVersion = 5;

/// The prefix reserved for Ham2K's own extensions. Refused to an installed
/// bundle: there is no signing, so anyone could claim it, and the key is what
/// the app shows when it says where a hook came from. The exceptions are the
/// bundles Ham2K itself put there ([BundleProvenance.isReservedPrefixAllowed]):
/// one hash-verified against the extension catalog's listing, which only
/// serves a `ham2k-` key to Ham2K's own publishers, and one the app shipped
/// and pre-loaded.
const kReservedKeyPrefix = 'ham2k-';

/// The extension catalog's host — one of the two sources whose bundles may
/// claim a `ham2k-` key. Baked into every install, exactly like the updates
/// host: nothing typed or discovered at runtime can name it.
const kCatalogHost = 'catalog.ham2k.net';

/// The other one: the app itself, for a bundle it shipped and pre-loaded
/// (HALO-581). Not a host at all, and deliberately not a resolvable name —
/// what it records is that these bytes were never fetched from anywhere.
const kPreloadHost = 'preloaded';

/// A catalog release track: how finished a release is, and deliberately not
/// which edition is asking (the catalog's SPEC §4.5). Steadiest first; [name]
/// is the wire value.
///
/// The catalog cascades — asking for a channel sees the releases on it AND on
/// every steadier one — so a channel asked for reads as "this or better".
enum CatalogChannel {
  stable,
  unstable,
  bleeding;

  /// Null for anything that is not one of the three.
  static CatalogChannel? tryParse(Object? raw) => values.where((channel) => channel.name == raw).firstOrNull;

  /// Whether asking for this channel sees a release that lives on [release].
  bool sees(CatalogChannel release) => release.index <= index;

  /// The rougher of the two.
  CatalogChannel widen(CatalogChannel other) => other.index > index ? other : this;
}

/// The catalog every install talks to, derived from [kCatalogHost] so the two
/// cannot drift: the only other address the app will read is the developer
/// override (`SettingsService.catalogBaseUrl`), typed by hand under developer
/// mode.
const kCatalogBaseUrl = 'https://$kCatalogHost';

/// Where a bundle's bytes came from, when that was the extension catalog and
/// they were verified against its listing — the sha256 the listing promised
/// and the version it named. Persisted per key as
/// `SettingsService.extensionInstalledFrom`; a bundle from a file or an
/// arbitrary link carries none.
class BundleProvenance {
  final String host;
  final String sha256;
  final String version;

  /// For a bundle being installed, the channel its release lives on. Once
  /// recorded, the TRACK the key follows: the update check asks for it, and
  /// it only ever widens on an install (see [followingAtLeast]) — an
  /// extension the operator chose to take unstable keeps taking unstable
  /// releases after a stable one overtakes it. Only the operator's "follow
  /// stable releases only" narrows it.
  final CatalogChannel channel;

  const BundleProvenance({required this.host, required this.sha256, required this.version, this.channel = CatalogChannel.stable});

  /// Whether this record waives the `ham2k-` refusal.
  ///
  /// Two hosts may: the catalog, and the app itself for a bundle it shipped
  /// and pre-loaded (HALO-581). Both are Ham2K putting the bytes there, which
  /// is the whole content of the reserved prefix — and neither is reachable
  /// from a file, since a file install writes no record and an uninstall
  /// clears the one that was there.
  bool get isReservedPrefixAllowed => host == kCatalogHost || host == kPreloadHost;

  /// Whether the bytes came from the catalog specifically — what an update
  /// check compares against, and what a deep link's verified path records.
  bool get isCatalog => host == kCatalogHost;

  /// Whether the app shipped these bytes itself.
  bool get isPreloaded => host == kPreloadHost;

  /// Whether this record's [channel] is a track on the catalog at
  /// [catalogHost]: a record from that host, or a pre-load — the app ships
  /// the catalog's own bundles, so a pre-load counts as whichever catalog is
  /// in force. The one rule for which records carry a track, read by the
  /// update check (`CatalogService.channelFollowedBy`) and by
  /// [followingAtLeast].
  bool isTrackOf(String catalogHost) => host == catalogHost || isPreloaded;

  /// This record, on the rougher of its own channel and [previous]'s — when
  /// [previous] is a track on the same catalog ([isTrackOf]); a pre-load
  /// landing over an unstable install must not quietly put it back on
  /// stable. Any other host is a different publisher's track, which says
  /// nothing about this one.
  BundleProvenance followingAtLeast(BundleProvenance? previous) {
    if (previous == null || !(previous.isTrackOf(host) || isPreloaded)) return this;
    return withChannel(channel.widen(previous.channel));
  }

  BundleProvenance withChannel(CatalogChannel channel) => BundleProvenance(host: host, sha256: sha256, version: version, channel: channel);

  /// `channel` is written only when it is not stable: absent means stable,
  /// the catalog's own reading, and every record predating tracks is one.
  Map<String, String> toJson() => {'host': host, 'sha256': sha256, 'version': version, if (channel != CatalogChannel.stable) 'channel': channel.name};

  static BundleProvenance? fromJson(Map<String, String>? json) {
    if (json == null) return null;
    final host = json['host'];
    final sha256 = json['sha256'];
    final version = json['version'];
    if (host == null || sha256 == null || version == null) return null;
    return BundleProvenance(host: host, sha256: sha256, version: version, channel: CatalogChannel.tryParse(json['channel']) ?? CatalogChannel.stable);
  }
}

/// The lowercase hex sha256 of [bytes] — what a catalog listing promises.
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// The entries a bundle may hold, mirroring the packer's format.
const kManifestEntry = 'manifest.json';
const kBundleEntry = 'index.js';
const kAssetsPrefix = 'assets/';

/// What a key must look like whatever else is true — it namespaces KV storage,
/// scopes secrets and identifies hooks. Mirrors the packer's SAFE_KEY_PATTERN,
/// including the leading digit that plenty of callsigns start with.
final RegExp kSafeKeyPattern = RegExp(r'^[a-z0-9][a-z0-9-]*$');

/// Why a `.h2kext` cannot be installed. Its own type so the UI can say which
/// of these happened rather than showing a sentence it cannot reason about.
enum BundleRejection {
  notAnArchive,
  malformed,
  missingManifest,
  missingBundle,
  invalidKey,
  reservedKey,
  collidesWithBuiltIn,
  apiTooNew,
  unsatisfiedDependency,

  /// An entry whose name would write outside the extension's own directory,
  /// or that the format does not allow. Never a mistake — the only way one
  /// gets into a zip is deliberately — so the bundle is refused rather than
  /// quietly installed without it.
  unsafeEntry,

  /// More than [kMaxUnpackedBytes] once decompressed. A few hundred bytes of
  /// zip can name gigabytes, and this is decided before anything is written.
  tooLarge,

  /// The bytes a catalog handed over are not the bytes its listing
  /// described. Decided before the zip is opened: nothing about a bundle
  /// that fails this is worth reading.
  hashMismatch,

  /// The bytes never arrived: the host answered something other than 200,
  /// or could not be reached at all. A sentence about this link, never a
  /// defect — the same footing as an unreadable file.
  downloadFailed,
}

/// The most a bundle may weigh unpacked. Generous next to a real extension —
/// one carrying its own copy of every library is around 1.5 MB — and far
/// below what a zip bomb needs to hurt.
const kMaxUnpackedBytes = 64 * 1024 * 1024;

/// The most entries one may hold. A bundle is a manifest, a script and some
/// assets; anything near this is not that.
const kMaxEntries = 2000;

/// The most a bundle fetched from a link may weigh on the wire. Well above a
/// real extension carrying its own libraries (~220 KB packed), and far below
/// what would hurt to hold in memory.
const kMaxDownloadBytes = 16 * 1024 * 1024;

class BundleException implements Exception {
  final BundleRejection reason;
  final String message;

  BundleException(this.reason, this.message);

  @override
  String toString() => message;
}

/// A `.h2kext` that has been read and checked but not yet written anywhere.
///
/// Carries what the operator is about to be asked to approve — the identity,
/// and every capability the manifest claims.
class InspectedBundle {
  final Map<String, dynamic> manifest;
  final Archive archive;

  /// Set only when [InstalledExtensions.inspect] verified the bytes against
  /// a catalog listing; what the install records, or clears, for the key.
  final BundleProvenance? provenance;

  InspectedBundle({required this.manifest, required this.archive, this.provenance});

  String get key => manifest['key'] as String;
  String get name => (manifest['name'] as String?) ?? key;
  String get version => (manifest['version'] as String?) ?? '';
  String? get description => manifest['description'] as String?;

  /// The hosts this extension may reach through `host.fetch`. Nothing else is
  /// permitted, so this list IS its network access.
  List<String> get domains => ((manifest['domains'] as List?) ?? const []).cast<String>();

  /// The hosts this extension may hold a `host.webSocket` open to.
  List<String> get webSockets => ((manifest['webSockets'] as List?) ?? const []).cast<String>();
  bool get requiresLocation => manifest['requiresLocation'] == true;
  bool get requiresRadioWrite => manifest['requiresRadioWrite'] == true;
  bool get requiresRadioRead => requiresRadioWrite || manifest['requiresRadioRead'] == true;
  bool get allowUserAgentOverride => manifest['allowUserAgentOverride'] == true;

  /// Whether it asks for anything at all beyond running. A bundle claiming
  /// nothing should not be dressed up as though it did.
  bool get claimsCapabilities => domains.isNotEmpty || webSockets.isNotEmpty || requiresLocation || requiresRadioRead || allowUserAgentOverride;
}

/// Reads, validates, installs and removes `.h2kext` bundles.
///
/// Where the bundles are kept is [BundleStorage]'s business — files natively,
/// IndexedDB on web.
class InstalledExtensions {
  InstalledExtensions({required this.builtInKeys, required this.hostSharedModules, BundleStorage? storage, bool Function(String key)? reservedPrefixAllowed})
    : storage = storage ?? createBundleStorage(),
      _reservedPrefixAllowed = reservedPrefixAllowed ?? _never;

  static bool _never(String key) => false;

  /// Whether [key]'s installed bytes are on record as ones Ham2K put there —
  /// hash-verified from the catalog, or shipped and pre-loaded by the app
  /// itself ([BundleProvenance.isReservedPrefixAllowed]). Consulted on EVERY
  /// read, not only at install: the waiver it grants to a `ham2k-` key has to
  /// die with the record, or a file install of the same key afterwards would
  /// inherit it.
  final bool Function(String key) _reservedPrefixAllowed;

  /// The keys of the extensions the app builds in, read live rather than
  /// captured. An installed bundle may not claim one: hook identity has to
  /// stay unambiguous. Live because the list is read again whenever the
  /// extension index is, and a set captured with the store would not follow
  /// it.
  final Set<String> Function() builtInKeys;

  /// What this build's kernel carries, from `assets/extensions/index.json`, for
  /// checking a bundle's declared `sharedDependencies`.
  final Map<String, String> hostSharedModules;

  /// Where the bundles' files are kept.
  final BundleStorage storage;

  /// Every key the store held at the last [list], including the ones it
  /// skipped — null when that read failed, or before the first.
  ///
  /// What "installed" means when asking what the operator has lost. The list
  /// leaves out a bundle a built-in or a dev server stands in front of, and a
  /// store that cannot be read at all is not one that lost everything.
  Set<String>? get storedKeys => _storedKeys;
  Set<String>? _storedKeys;

  /// Opens [bytes] and checks everything that can be checked without writing:
  /// that it is an archive of the right shape, that the key is usable here, and
  /// that this build can satisfy what it declares.
  ///
  /// [provenance] is the catalog listing the bytes are claimed to match. The
  /// hash is re-checked HERE, before the zip is even sniffed, so the `ham2k-`
  /// waiver it buys hinges on the bytes in hand and never on a caller's word.
  ///
  /// Throws [BundleException]; writes nothing.
  Future<InspectedBundle> inspect(List<int> bytes, {BundleProvenance? provenance}) async {
    if (provenance != null && sha256Hex(bytes) != provenance.sha256.toLowerCase()) {
      throw BundleException(BundleRejection.hashMismatch, 'That download is not the extension the catalog described, so it was not opened.');
    }
    // Sniffed, not trusted from the name: Android's file picker hands back a
    // cache copy whose extension the platform rewrote from the MIME type, so
    // the name says nothing about what this is.
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B || bytes[2] != 0x03 || bytes[3] != 0x04) {
      throw BundleException(BundleRejection.notAnArchive, 'That file is not a Ham2K extension bundle.');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw BundleException(BundleRejection.malformed, 'That extension bundle is damaged and cannot be opened.');
    }

    // One entry per name is guaranteed by the decoder, not assumed here:
    // ZipDecoder skips a repeated filename (`archive.find` before `add`) and
    // `Archive.add` is name-keyed either way. So a bundle carrying two
    // manifests cannot show one on the consent screen and install the other —
    // `inspect` and `install` are reading the same single entry.
    final manifestFile = archive.files.where((f) => f.isFile && f.name == kManifestEntry).firstOrNull;
    if (manifestFile == null) {
      throw BundleException(BundleRejection.missingManifest, 'That bundle has no manifest.json.');
    }
    if (!archive.files.any((f) => f.isFile && f.name == kBundleEntry)) {
      throw BundleException(BundleRejection.missingBundle, 'That bundle has no index.js.');
    }

    final Map<String, dynamic> manifest;
    try {
      final decoded = jsonDecode(utf8.decode(manifestFile.content as List<int>));
      if (decoded is! Map) throw const FormatException('not an object');
      manifest = decoded.cast<String, dynamic>();
    } catch (e) {
      throw BundleException(BundleRejection.malformed, "That bundle's manifest.json is not readable.");
    }

    _checkEntries(archive);
    _checkKey(manifest['key'], reservedAllowed: provenance?.isReservedPrefixAllowed ?? false);
    _checkApi(manifest['api']);
    _checkDisplayFields(manifest);
    _checkSharedDependencies(manifest['sharedDependencies']);
    // The version the listing named is the one the bundle must carry, or the
    // provenance record would vouch for a version the catalog never served.
    if (provenance != null && manifest['version'] != provenance.version) {
      throw BundleException(
        BundleRejection.hashMismatch,
        'That download calls itself version ${manifest['version']}, not the ${provenance.version} the catalog listed.',
      );
    }
    return InspectedBundle(manifest: manifest, archive: archive, provenance: provenance);
  }

  /// The key checks alone, for a caller that knows the key before it has the
  /// bytes — a catalog install refuses a built-in key before downloading
  /// anything. The same refusals [inspect] makes, with the same messages.
  void checkKeyInstallable(String key, {BundleProvenance? provenance}) => _checkKey(key, reservedAllowed: provenance?.isReservedPrefixAllowed ?? false);

  /// Every entry must be one the format allows, sit inside the extension's own
  /// directory, and the whole thing must be a plausible size.
  ///
  /// Refused here rather than skipped at extract time. An entry named `../` is
  /// not a packaging accident — the only way one reaches a zip is on purpose —
  /// and installing the rest of a bundle that contained one, without saying so,
  /// hands the operator an extension nobody has actually agreed to.
  void _checkEntries(Archive archive) {
    if (archive.files.length > kMaxEntries) {
      throw BundleException(BundleRejection.tooLarge, 'That bundle holds far more files than an extension needs.');
    }
    var total = 0;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      // The header's own claim, which the person who built the archive wrote.
      // Cheap, catches an honestly oversized bundle, and is NOT a bound on a
      // hostile one — `install` counts the bytes it actually writes.
      total += file.size;
      if (total > kMaxUnpackedBytes) {
        throw BundleException(BundleRejection.tooLarge, 'That bundle is far larger unpacked than an extension should be.');
      }
      if (safeJoin('/extensions/probe', file.name) == null) {
        throw BundleException(BundleRejection.unsafeEntry, 'That bundle contains a file path it is not allowed to write.');
      }
      if (file.name != kManifestEntry && file.name != kBundleEntry && !file.name.startsWith(kAssetsPrefix)) {
        throw BundleException(BundleRejection.unsafeEntry, 'That bundle contains "${file.name}", which is not part of the extension format.');
      }
    }
  }

  /// The fields the consent screen shows, and the capabilities it describes.
  ///
  /// Checked at the door because they are read while BUILDING that screen: a
  /// manifest saying `"domains": "evil.com"` would otherwise pass inspection
  /// and then throw out of a widget build, from a file supplied by whoever
  /// wrote it. `domains` matters most — it is the fetch allowlist itself, not
  /// a description of one.
  void _checkDisplayFields(Map<String, dynamic> manifest) {
    for (final field in ['name', 'version', 'description', 'category', 'icon', 'shortName']) {
      final value = manifest[field];
      if (value != null && value is! String) {
        throw BundleException(BundleRejection.malformed, "That bundle's manifest has an unreadable '$field'.");
      }
    }
    // Refused here as well as by the packer, whose header says it is "a
    // guardrail, not a gate". An experiment key the app does not define hides
    // the extension permanently — installed, reported installed, and then
    // never loaded, with nothing in the UI to explain it.
    if (manifest['experiments'] != null) {
      throw BundleException(BundleRejection.malformed, "That bundle's manifest lists app experiments, so it could never load.");
    }
    for (final field in ['domains', 'webSockets']) {
      final hosts = manifest[field];
      if (hosts != null && (hosts is! List || hosts.any((d) => d is! String))) {
        throw BundleException(BundleRejection.malformed, "That bundle's manifest has an unreadable '$field' list.");
      }
    }
    // `enabledByDefault` and the retired `geo` are NOT refused here, though
    // the packer and the catalog both refuse them. The difference is who is
    // being told. Those two answer to the author, who can fix the manifest
    // and publish again; refusing at this door tells the OPERATOR, who can do
    // nothing but go without an extension that would have worked. A stale
    // field costs them nothing either: `list` overrides `enabledByDefault`
    // because an installed extension is on, and `geo` is simply not read, so
    // the extension is worldwide instead of regional.
    //
    // The rule this differs from is `experiments`, refused just above,
    // because a bundle carrying one genuinely could never load. Refuse here
    // only what the app cannot run.
    //
    // `relevance` reads as "does not gate" wherever the matcher cannot parse
    // it, so a malformed one would install as worldwide rather than as a
    // mistake — and a value outside the vocabulary would install as relevant
    // to nobody. The packer's rules, applied again at the door.
    //
    // `containsKey`, not a null test: `"relevance": null` is a value, and the
    // packer refuses it.
    if (manifest.containsKey('relevance')) {
      final problems = ExtensionRelevance.validate(manifest['relevance']);
      if (problems.isNotEmpty) {
        throw BundleException(BundleRejection.malformed, "That bundle's manifest has an unreadable 'relevance': ${problems.first}");
      }
    }
  }

  /// [reservedAllowed] waives the reserved prefix and nothing else. The
  /// built-in collision below stands whatever the source, because hook
  /// identity and secret visibility are keyed by name and neither the catalog
  /// nor a file may shadow an extension this app is offering — but it is
  /// judged against what the app offers NOW, which under the catalog
  /// experiment is the core extensions and nothing else.
  void _checkKey(Object? raw, {required bool reservedAllowed}) {
    final key = raw is String ? raw : '';
    if (key.isEmpty || !kSafeKeyPattern.hasMatch(key)) {
      throw BundleException(BundleRejection.invalidKey, 'That bundle has no usable extension key.');
    }
    if (key.startsWith(kReservedKeyPrefix) && !reservedAllowed) {
      throw BundleException(
        BundleRejection.reservedKey,
        'That bundle claims the name "$key". Names beginning "ham2k-" are reserved for Ham2K\'s own extensions.',
      );
    }
    if (builtInKeys().contains(key)) {
      throw BundleException(BundleRejection.collidesWithBuiltIn, 'That bundle calls itself "$key", which is already an extension built into this app.');
    }
  }

  void _checkApi(Object? raw) {
    final api = raw is int ? raw : 0;
    if (api > kExtensionApiVersion) {
      throw BundleException(
        BundleRejection.apiTooNew,
        'That extension needs a newer version of this app (it was built for extension API $api; this app speaks $kExtensionApiVersion).',
      );
    }
  }

  /// A bundle may use the libraries the host carries instead of shipping its
  /// own — around a thirtieth of the size — but only against versions it says
  /// it works with. Checked here rather than at a call site, where a mismatch
  /// surfaces as a hook failing for reasons nothing can explain.
  void _checkSharedDependencies(Object? raw) {
    if (raw == null) return;
    if (raw is! Map) {
      throw BundleException(BundleRejection.malformed, "That bundle's declared dependencies are not readable.");
    }
    for (final entry in raw.cast<String, dynamic>().entries) {
      final have = hostSharedModules[entry.key];
      if (have == null) {
        throw BundleException(BundleRejection.unsatisfiedDependency, 'That extension needs ${entry.key}, which this app does not provide.');
      }
      final wanted = entry.value;
      if (wanted is! String || !_isParseableRange(wanted)) {
        // Distinct from a mismatch: telling an author their version is wrong
        // when the fault is a malformed range sends them looking at the one
        // thing that is fine.
        throw BundleException(BundleRejection.malformed, 'That extension asks for ${entry.key} "$wanted", which is not a version range.');
      }
      if (!_satisfies(have, wanted)) {
        throw BundleException(BundleRejection.unsatisfiedDependency, 'That extension needs ${entry.key} $wanted; this app has $have.');
      }
    }
  }

  /// Ranges are written the npm way (`^1.2.0`) because that is what an
  /// extension author's tooling produces. `pub_semver` parses that syntax, and
  /// agrees with npm on caret for every case that reaches here.
  @visibleForTesting
  static bool satisfies(String have, String range) => _satisfies(have, range);

  static bool _isParseableRange(String range) {
    try {
      VersionConstraint.parse(range);
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _satisfies(String have, String range) {
    try {
      return VersionConstraint.parse(range).allows(Version.parse(have));
    } catch (_) {
      // An unparseable range is the author's mistake, and refusing is the only
      // safe reading — "I could not tell" must not mean "go ahead".
      return false;
    }
  }

  /// Writes an inspected bundle into its own directory, replacing whatever was
  /// there. The KV an earlier version stored is untouched — an update is not a
  /// reinstall, and re-entering credentials on every update would make updating
  /// something people avoid.
  Future<void> install(InspectedBundle bundle) async {
    _checkSafeKey(bundle.key);
    final files = <String, List<int>>{};
    var written = 0;
    for (final file in bundle.archive.files) {
      if (!file.isFile) continue;
      final bytes = file.content as List<int>;
      // The size actually produced, not the size the header claimed. That
      // number comes from the archive's own central directory and the decoder
      // treats it as a hint, so a bundle can declare a kilobyte and inflate to
      // gigabytes. What this does NOT bound is one entry inflating in memory
      // before its length can be read: the decoder has no bounded read, so the
      // header cap, the entry count and the download cap are what stand
      // between a bomb and the heap.
      written += bytes.length;
      if (written > kMaxUnpackedBytes) {
        throw BundleException(BundleRejection.tooLarge, 'That bundle unpacks to far more than an extension should.');
      }
      files[file.name] = bytes;
    }
    await storage.write(bundle.key, files);
  }

  /// [dir] joined with an archive entry name, or null if the result would
  /// escape it.
  static String? safeJoin(String dir, String entryName) {
    if (entryName.startsWith('/') || entryName.contains('\\')) return null;
    final resolved = p.normalize(p.join(dir, entryName));
    if (!p.isWithin(dir, resolved)) return null;
    return resolved;
  }

  Future<void> uninstall(String key) async {
    _checkSafeKey(key);
    await storage.remove(key);
  }

  /// Refuses anything that could name storage other than that extension's
  /// own. Every caller today passes a key that came from [list], but these are
  /// the methods taking a raw one, and a path built from an unchecked key is
  /// how the rest stays safe by luck.
  void _checkSafeKey(String key) {
    if (!kSafeKeyPattern.hasMatch(key)) throw ArgumentError.value(key, 'key', 'not a usable extension key');
  }

  /// Every installed extension, as the loader needs them. A directory whose
  /// manifest no longer reads is skipped rather than taking the list down:
  /// one damaged install must not cost the operator the others.
  Future<List<ExtensionInfo>> list() async {
    _storedKeys = null;
    final manifests = await storage.manifests();
    _storedKeys = manifests.keys.toSet();
    final found = <ExtensionInfo>[];
    for (final MapEntry(key: key, value: raw) in manifests.entries) {
      try {
        if (raw == null) throw StateError('it has no readable $kManifestEntry');
        final manifest = jsonDecode(raw);
        if (manifest is! Map) {
          _skip(key, 'its manifest is not an object');
          continue;
        }
        // The storage key IS the identity — it is what uninstall and sourceFor
        // address, and what the loader keys the source by.
        if (manifest['key'] != key) {
          _skip(key, 'its manifest claims the key "${manifest['key']}"');
          continue;
        }
        // Re-applied on every read, not just at install. The built-in set
        // grows with releases, so a key that was free when it was installed
        // can collide with one the app now ships — and the loader keys
        // secrets, allowlists and hooks by that key, which would hand an
        // installed bundle whatever the built-in was granted.
        // Re-validated on every read for the same reason the key is: the app
        // this bundle was installed into is not the app now reading it. An
        // update can raise a shared library's major or lower the API version,
        // and the point of checking at all is to refuse at the door rather
        // than fail inside a hook.
        try {
          _checkKey(key, reservedAllowed: _reservedPrefixAllowed(key));
          _checkApi(manifest['api']);
          _checkSharedDependencies(manifest['sharedDependencies']);
        } on BundleException catch (e) {
          _skip(key, e.message);
          continue;
        }
        found.add(
          ExtensionInfo.fromJson({
            ...manifest.cast<String, dynamic>(),
            'file': kBundleEntry,
            'core': false,
            'source': 'installed',
            // Overridden rather than trusted, for the installs that predate the
            // door's refusal of it. An extension is on because the operator
            // installed it; honouring a manifest's `false` here would leave one
            // listed and never loaded, and no override anywhere would say why.
            'enabledByDefault': true,
          }),
        );
      } catch (e, stack) {
        // Skipped rather than fatal — one damaged install must not cost the
        // operator the others — but never in silence. An extension that
        // vanishes from the panel with nothing anywhere to say why is the
        // failure nobody can debug six months later.
        _skip(key, '$e');
        ErrorReportingService.report(e, stack, context: 'installed-extensions:read');
      }
    }
    found.sort((a, b) => a.key.compareTo(b.key));
    return found;
  }

  void _skip(String key, String why) => debugPrint('[extensions] ignoring installed "$key": $why');

  /// Whether [key] is already installed — what decides whether the operator
  /// is being asked about an install or an update.
  Future<bool> isInstalled(String key) async {
    _checkSafeKey(key);
    return await storage.readText(key, kManifestEntry) != null;
  }

  /// The JS for an installed extension.
  Future<String> sourceFor(String key) async {
    _checkSafeKey(key);
    return await storage.readText(key, kBundleEntry) ?? (throw StateError('installed extension "$key" has no $kBundleEntry'));
  }
}
