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
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'app_storage.dart';
import 'error_reporting_service.dart';
import 'extension_service.dart';

/// The extension API this build speaks. A bundle declares the one it was built
/// against and anything newer is refused, so an old app meeting a new bundle
/// says so rather than failing somewhere inside a hook.
const kExtensionApiVersion = 1;

/// Directory under the app's data directory holding installed extensions, one
/// subdirectory per key.
const kInstalledExtensionsDirName = 'extensions';

/// The prefix reserved for Ham2K's own extensions. Refused to an installed
/// bundle: there is no signing, so anyone could claim it, and the key is what
/// the app shows when it says where a hook came from.
const kReservedKeyPrefix = 'ham2k-';

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

  /// Installing is not supported here (web has no store).
  unsupportedPlatform,
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

  InspectedBundle({required this.manifest, required this.archive});

  String get key => manifest['key'] as String;
  String get name => (manifest['name'] as String?) ?? key;
  String get version => (manifest['version'] as String?) ?? '';
  String? get description => manifest['description'] as String?;

  /// The hosts this extension may reach through `host.fetch`. Nothing else is
  /// permitted, so this list IS its network access.
  List<String> get domains => ((manifest['domains'] as List?) ?? const []).cast<String>();
  bool get requiresLocation => manifest['requiresLocation'] == true;
  bool get allowUserAgentOverride => manifest['allowUserAgentOverride'] == true;

  /// Whether it asks for anything at all beyond running. A bundle claiming
  /// nothing should not be dressed up as though it did.
  bool get claimsCapabilities => domains.isNotEmpty || requiresLocation || allowUserAgentOverride;

}

/// Reads, validates, installs and removes `.h2kext` bundles.
///
/// Native only: installed bundles are files on disk. On web the app runs from
/// its own assets and a dev server, and [isSupported] is false.
class InstalledExtensions {
  InstalledExtensions({
    required this.builtInKeys,
    required this.hostSharedModules,
    this.rootOverride,
  });

  /// Keys the app itself ships. An installed bundle may not claim one: hook
  /// identity has to stay unambiguous, and secret visibility is by key prefix,
  /// so an installed extension calling itself `sota` would be asking for
  /// `SOTA_*`.
  final Set<String> builtInKeys;

  /// What this build's kernel carries, from `assets/extensions/index.json`, for
  /// checking a bundle's declared `sharedDependencies`.
  final Map<String, String> hostSharedModules;

  /// Where the installed bundles live, when it isn't the app data directory —
  /// a test needs its own, and `appDataDirectory()` reaches a plugin.
  final Directory? rootOverride;

  /// Installed bundles are files on disk. Web has none, and reaches its
  /// extensions through the app's own assets and a dev server instead — the
  /// same `kIsWeb` guard app_storage.dart uses for the rest of the app's
  /// directories.
  static bool get isSupported => !kIsWeb;

  Future<Directory> _root() async {
    final root = rootOverride ?? Directory(p.join((await appDataDirectory()).path, kInstalledExtensionsDirName));
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  /// Opens [bytes] and checks everything that can be checked without writing:
  /// that it is an archive of the right shape, that the key is usable here, and
  /// that this build can satisfy what it declares.
  ///
  /// Throws [BundleException]; writes nothing.
  Future<InspectedBundle> inspect(List<int> bytes) async {
    if (!isSupported) {
      throw BundleException(
          BundleRejection.unsupportedPlatform, 'Installing extensions is not supported on the web.');
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
    _checkKey(manifest['key']);
    _checkApi(manifest['api']);
    _checkDisplayFields(manifest);
    _checkSharedDependencies(manifest['sharedDependencies']);
    return InspectedBundle(manifest: manifest, archive: archive);
  }

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
        throw BundleException(BundleRejection.unsafeEntry,
            'That bundle contains "${file.name}", which is not part of the extension format.');
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
      throw BundleException(BundleRejection.malformed,
          "That bundle gates itself on an app experiment, so it could never load.");
    }
    final domains = manifest['domains'];
    if (domains != null && (domains is! List || domains.any((d) => d is! String))) {
      throw BundleException(BundleRejection.malformed, "That bundle's manifest has an unreadable 'domains' list.");
    }
  }

  void _checkKey(Object? raw) {
    final key = raw is String ? raw : '';
    if (key.isEmpty || !kSafeKeyPattern.hasMatch(key)) {
      throw BundleException(BundleRejection.invalidKey, 'That bundle has no usable extension key.');
    }
    if (key.startsWith(kReservedKeyPrefix)) {
      throw BundleException(BundleRejection.reservedKey,
          'That bundle claims the name "$key". Names beginning "ham2k-" are reserved for Ham2K\'s own extensions.');
    }
    if (builtInKeys.contains(key)) {
      throw BundleException(BundleRejection.collidesWithBuiltIn,
          'That bundle calls itself "$key", which is already an extension built into this app.');
    }
  }

  void _checkApi(Object? raw) {
    final api = raw is int ? raw : 0;
    if (api > kExtensionApiVersion) {
      throw BundleException(BundleRejection.apiTooNew,
          'That extension needs a newer version of this app (it was built for extension API $api; this app speaks $kExtensionApiVersion).');
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
        throw BundleException(BundleRejection.unsatisfiedDependency,
            'That extension needs ${entry.key}, which this app does not provide.');
      }
      final wanted = entry.value;
      if (wanted is! String || !_isParseableRange(wanted)) {
        // Distinct from a mismatch: telling an author their version is wrong
        // when the fault is a malformed range sends them looking at the one
        // thing that is fine.
        throw BundleException(BundleRejection.malformed,
            'That extension asks for ${entry.key} "$wanted", which is not a version range.');
      }
      if (!_satisfies(have, wanted)) {
        throw BundleException(BundleRejection.unsatisfiedDependency,
            'That extension needs ${entry.key} $wanted; this app has $have.');
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
    final dir = Directory(_dirFor(await _root(), bundle.key));
    // Replaced whole rather than merged: a file the new version dropped must
    // not linger and keep being served.
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    var written = 0;
    for (final file in bundle.archive.files) {
      if (!file.isFile) continue;
      final target = safeJoin(dir.path, file.name);
      // Belt and braces — `_checkEntries` already refused the bundle over an
      // escaping name, so reaching this is a bug rather than an attack.
      if (target == null) continue;
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
        await dir.delete(recursive: true);
        throw BundleException(BundleRejection.tooLarge, 'That bundle unpacks to far more than an extension should.');
      }
      final out = File(target);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes);
    }
  }

  /// [dir] joined with an archive entry name, or null if the result would
  /// escape it.
  @visibleForTesting
  static String? safeJoin(String dir, String entryName) {
    if (entryName.startsWith('/') || entryName.contains('\\')) return null;
    final resolved = p.normalize(p.join(dir, entryName));
    if (!p.isWithin(dir, resolved)) return null;
    return resolved;
  }

  Future<void> uninstall(String key) async {
    final dir = Directory(_dirFor(await _root(), key));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// [root] joined with an extension key, refusing anything that could name a
  /// directory other than that extension's own. Every caller today passes a
  /// key that came from [list], but these are the two methods taking a raw
  /// one, and a path built from an unchecked key is how the rest stays safe
  /// by luck.
  String _dirFor(Directory root, String key) {
    if (!kSafeKeyPattern.hasMatch(key)) throw ArgumentError.value(key, 'key', 'not a usable extension key');
    return p.join(root.path, key);
  }

  /// Every installed extension, as the loader needs them. A directory whose
  /// manifest no longer reads is skipped rather than taking the list down:
  /// one damaged install must not cost the operator the others.
  Future<List<ExtensionInfo>> list() async {
    if (!isSupported) return const [];
    final root = await _root();
    final found = <ExtensionInfo>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final key = p.basename(entry.path);
      try {
        final manifest = jsonDecode(await File(p.join(entry.path, kManifestEntry)).readAsString());
        if (manifest is! Map) {
          _skip(key, 'its manifest is not an object');
          continue;
        }
        // The directory IS the identity — it is what uninstall and sourceFor
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
          _checkKey(key);
          _checkApi(manifest['api']);
          _checkSharedDependencies(manifest['sharedDependencies']);
        } on BundleException catch (e) {
          _skip(key, e.message);
          continue;
        }
        found.add(ExtensionInfo.fromJson({
          ...manifest.cast<String, dynamic>(),
          'file': kBundleEntry,
          'core': false,
          'source': 'installed',
        }));
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
    if (!isSupported) return false;
    return File(p.join(_dirFor(await _root(), key), kManifestEntry)).exists();
  }

  /// The JS for an installed extension.
  Future<String> sourceFor(String key) async =>
      File(p.join(_dirFor(await _root(), key), kBundleEntry)).readAsString();
}
