// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension catalog client (catalog.ham2k.net): what is published for
// the catalog's stable channel, whether an installed extension has a newer release,
// and the bundle bytes themselves — verified against the listing's sha256
// before anything opens them.
//
// Never a throw to a caller asking a question: an unreachable or broken
// catalog answers null, and what it deserves (a streak report, a plain
// report, nothing) is decided here once. The download path is the exception
// by design — it is the `read` step of the install flow, whose refusals are
// BundleExceptions the consent screen already knows how to show.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOException;
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/foundation.dart' show ChangeNotifier, VoidCallback, debugPrint;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import '../../config/user_agent.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../error_reporting_service.dart';
import '../../config/experiments.dart' show kCatalogExperiment;
import 'extension_relevance.dart';
import 'extension_service.dart' show ExtensionInfo, ExtensionSearchable;
import 'installed_extensions.dart';
import '../settings_service.dart';
import '../status_bar_service.dart';

/// Listing and update requests; a catalog that takes longer than this is
/// treated as absent rather than stalling a boot step or the panel.
const kCatalogRequestTimeout = Duration(seconds: 5);

/// A bundle download. Well past what a real bundle needs; a link that takes
/// longer is not one worth waiting on.
const kCatalogDownloadTimeout = Duration(seconds: 30);

/// How long a listing answers from memory. The catalog itself serves
/// `max-age=300`, so asking sooner buys nothing.
const _cacheTtl = Duration(minutes: 5);

/// What an install needs of one listed release: which bytes, and what they
/// must hash to. A catalog entry yields its own ([CatalogEntry.release]); a
/// catalog deep link assembles one from the link and the listing it names.
typedef CatalogRelease = ({String key, String version, String sha256, Uri bundleUrl});

/// One entry of `GET /api/v1/catalog`: what the panel shows of an extension's
/// current release on this channel, and what an install needs of it. Only
/// the fields something reads; `fromJson` ignores the rest of the row.
///
/// A distinct DTO, never fed to `ExtensionInfo.fromJson`: that reader's
/// `core` default would hide a catalog entry, and its shape is the build
/// index's, not the catalog's.
class CatalogEntry with ExtensionSearchable {
  @override
  final String key;
  @override
  final String name;
  @override
  final String? description;
  final String? category;
  final String? icon;

  /// The manifest's `accentColor` as `'#RRGGBB'`, which the catalog serves
  /// alongside the icon — the tile a suggested row draws is the tile the
  /// catalog site draws for the same extension.
  final String? accentColor;
  @override
  final List<String> keywords;

  /// The manifest's `hooks`, as the catalog serves them (SPEC.md §8.1) — the
  /// same list `ExtensionInfo` carries, and read for the same reason: a
  /// `ref:` entry is how a reference nothing installed handles finds the
  /// extension that does, without any of its code having run.
  final List<String> hooks;

  /// Where, when and for whom the extension is relevant; null is worldwide
  /// and undated.
  final ExtensionRelevance? relevance;
  @override
  final Map<String, Map<String, Object?>> translations;
  final String version;

  /// Lowercase hex, what the bundle bytes must hash to.
  final String sha256;
  final Uri bundleUrl;

  const CatalogEntry({
    required this.key,
    required this.name,
    required this.version,
    required this.sha256,
    required this.bundleUrl,
    this.description,
    this.category,
    this.icon,
    this.accentColor,
    this.keywords = const [],
    this.hooks = const [],
    this.relevance,
    this.translations = const {},
  });

  static final _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Lenient per entry, strict about what an install needs. An entry missing
  /// a usable key, name, version, sha256 or bundle URL is null — dropped by
  /// the caller — so one broken row never costs the operator the list.
  static CatalogEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final name = json['name'];
    final version = json['version'];
    final sha256 = json['sha256'];
    final bundleUrl = json['bundleUrl'] is String ? Uri.tryParse(json['bundleUrl'] as String) : null;
    if (key is! String || !kSafeKeyPattern.hasMatch(key)) return null;
    if (name is! String || name.isEmpty) return null;
    if (version is! String || version.isEmpty) return null;
    if (sha256 is! String || !_sha256Pattern.hasMatch(sha256)) return null;
    if (bundleUrl == null || bundleUrl.host.isEmpty) return null;
    return CatalogEntry(
      key: key,
      name: name,
      version: version,
      sha256: sha256.toLowerCase(),
      bundleUrl: bundleUrl,
      description: json['description'] is String ? json['description'] as String : null,
      category: json['category'] is String ? json['category'] as String : null,
      icon: json['icon'] is String ? json['icon'] as String : null,
      accentColor: json['accentColor'] is String ? json['accentColor'] as String : null,
      keywords: json['keywords'] is List ? (json['keywords'] as List).whereType<String>().toList() : const [],
      hooks: json['hooks'] is List ? (json['hooks'] as List).whereType<String>().toList() : const [],
      relevance: json['relevance'] is Map ? ExtensionRelevance.fromJson((json['relevance'] as Map).cast<String, dynamic>()) : null,
      translations: {
        if (json['translations'] is Map)
          for (final entry in (json['translations'] as Map).entries)
            if (entry.key is String && entry.value is Map) entry.key as String: (entry.value as Map).cast<String, Object?>(),
      },
    );
  }

  /// This entry as the install flow's input.
  CatalogRelease get release => (key: key, version: version, sha256: sha256, bundleUrl: bundleUrl);

  /// Whether [installedVersion] is older than this release. Both sides are
  /// parsed leniently, and either failing to parse means "no update": a
  /// version nobody can order is not one to offer as newer.
  bool isNewerThan(String? installedVersion) {
    final installed = parseVersion(installedVersion);
    final mine = parseVersion(version);
    return installed != null && mine != null && mine > installed;
  }

  /// `Version.parse` without the throw; null for anything it cannot read.
  static Version? parseVersion(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return Version.parse(raw);
    } on FormatException {
      return null;
    }
  }
}

/// The three tiers of the catalog's own ordering rule: what the operator's
/// callsign is in the audience of, what is for everyone, and the rest —
/// alphabetical within each. With no callsign known yet there is no first
/// tier: worldwide leads, and every gated entry follows.
///
/// One copy, because two places rank catalog entries for the same operator —
/// the Extensions panel's Catalog section and the operation sheet's activity
/// search — and a Texan offered the Texas party first in one place and third
/// in the other would be reading two different catalogs.
List<CatalogEntry> orderedCatalogEntries(List<CatalogEntry> entries, OperatorGeo? operator, String locale) {
  int tier(CatalogEntry entry) {
    final relevance = entry.relevance;
    if (relevance == null || relevance.isWorldwide) return 1;
    return operator != null && relevance.matchesOperator(operator) ? 0 : 2;
  }

  final tiers = {for (final entry in entries) entry.key: tier(entry)};
  return [...entries]..sort((a, b) {
    final byTier = tiers[a.key]!.compareTo(tiers[b.key]!);
    if (byTier != 0) return byTier;
    return a.nameFor(locale).toLowerCase().compareTo(b.nameFor(locale).toLowerCase());
  });
}

/// One version of `GET /api/v1/extensions/:key` — the hash a deep link's
/// bytes are checked against.
class CatalogVersion {
  final String version;
  final String sha256;

  const CatalogVersion({required this.version, required this.sha256});

  static CatalogVersion? fromJson(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    final sha256 = json['sha256'];
    if (version is! String || version.isEmpty) return null;
    if (sha256 is! String || !CatalogEntry._sha256Pattern.hasMatch(sha256)) return null;
    return CatalogVersion(version: version, sha256: sha256.toLowerCase());
  }
}

/// `GET /api/v1/extensions/:key`: every version visible on this channel.
class CatalogExtension {
  final String key;
  final List<CatalogVersion> versions;

  const CatalogExtension({required this.key, required this.versions});

  CatalogVersion? versionNamed(String version) => versions.where((v) => v.version == version).firstOrNull;
}

/// One row of `POST /api/v1/updates`' `updates`: a release to offer for an
/// installed key, and what the catalog made of the version installed.
class CatalogUpdate {
  final CatalogEntry entry;

  /// `current`, `withdrawn` or `unknown` — whether the installed version is a
  /// release the channel can see.
  final String installedStatus;

  const CatalogUpdate({required this.entry, required this.installedStatus});
}

/// An installed `(key, version)` the catalog has revoked, with the admin's
/// note. The client disables it and says so.
class CatalogRevocation {
  final String key;
  final String version;
  final String note;

  const CatalogRevocation({required this.key, required this.version, required this.note});
}

/// The answer to `POST /api/v1/updates`.
class CatalogUpdates {
  final List<CatalogUpdate> updates;
  final List<CatalogRevocation> revoked;

  /// Installed pairs the catalog could not judge, with its reason — a
  /// version that is not strict semver, typically.
  final List<({String key, String reason})> ignored;

  const CatalogUpdates({required this.updates, required this.revoked, required this.ignored});

  static CatalogUpdates fromJson(Map<String, dynamic> json) => CatalogUpdates(
    updates: [
      if (json['updates'] is List)
        for (final raw in json['updates'] as List)
          if (CatalogEntry.fromJson(raw) case final entry?)
            CatalogUpdate(entry: entry, installedStatus: raw is Map && raw['installedStatus'] is String ? raw['installedStatus'] as String : 'unknown'),
    ],
    revoked: [
      if (json['revoked'] is List)
        for (final raw in json['revoked'] as List)
          if (raw is Map && raw['key'] is String && raw['version'] is String)
            CatalogRevocation(key: raw['key'] as String, version: raw['version'] as String, note: raw['note'] is String ? raw['note'] as String : ''),
    ],
    ignored: [
      if (json['ignored'] is List)
        for (final raw in json['ignored'] as List)
          if (raw is Map && raw['key'] is String) (key: raw['key'] as String, reason: raw['reason'] is String ? raw['reason'] as String : ''),
    ],
  );
}

/// The catalog did not answer — a failure below the application layer, or
/// the request timeout — never a response it did give. Its own type so
/// ErrorPolicy can keep the unattended check quiet (`catalog-unreachable`)
/// without widening the rule to every bare TimeoutException in the app.
class CatalogUnreachable implements Exception {
  final Uri url;
  final Object cause;

  CatalogUnreachable(this.url, this.cause);

  @override
  String toString() => 'CatalogUnreachable: $url ($cause)';
}

class CatalogService {
  final http.Client _client;
  final SettingsService? _settings;
  final Future<String> Function() _userAgent;
  final String Function() _locale;

  /// A test's seams for the two timeouts; the defaults are the contract.
  final Duration _requestTimeout;
  final Duration _downloadTimeout;

  /// Streak key for [ErrorReportingService.reportIfRepeated]: the whole
  /// catalog is one streak, because one dead catalog is one defect.
  static const _failureKey = 'catalog';

  CatalogService({
    http.Client? client,
    this._settings,
    Future<String> Function()? userAgent,
    String Function()? locale,
    this._requestTimeout = kCatalogRequestTimeout,
    this._downloadTimeout = kCatalogDownloadTimeout,
  }) : _client = client ?? http.Client(),
       // The fallback resolver never throws, so a missing native build
       // number cannot block a background check.
       _userAgent = userAgent ?? ham2kUserAgentOrFallback,
       _locale = locale ?? (() => LocaleSettings.currentLocale.languageCode);

  /// The channel asked for.
  ///
  /// `stable`, whichever edition is running. A channel says how finished a
  /// release is; an edition says who is running the app. Tying them together
  /// — which is what asking for the edition's name did — meant a Dev build
  /// could not choose to run only finished extensions and a Prod build could
  /// not try an unfinished one at all.
  ///
  /// Constant until there is a setting for it. The catalog cascades, so
  /// asking for a rougher channel later ADDS releases rather than replacing
  /// them, and nothing an operator already installed goes away.
  String get channel => kCatalogChannel;

  /// Whether the developer override is in force — developer mode on AND an
  /// address typed. The two together, not the address alone: developer mode
  /// going off must return the app to the real catalog with nothing else
  /// touched, the same way the dev server drops out.
  bool get _overrideActive {
    final settings = _settings;
    return settings != null && settings.developerMode && settings.catalogBaseUrl.isNotEmpty;
  }

  /// The catalog in force: the developer override under developer mode,
  /// otherwise the built-in address.
  String get baseUrl => _overrideActive ? _settings!.catalogBaseUrl : kCatalogBaseUrl;

  /// The host bundles are attributed to — on the consent screen, and in the
  /// provenance record that waives the `ham2k-` refusal ONLY when it is
  /// [kCatalogHost]. A local catalog under the override is named as itself.
  String get host => Uri.parse(baseUrl).host;

  /// Whether [url] is on the catalog in force — the built-in one, or the
  /// override's origin while that is on. What routes a deep link through
  /// the hash-verified path instead of the plain download. The ACTIVE
  /// catalog only: under an override, a production link would otherwise be
  /// resolved against the override's listings, which never served it.
  bool isCatalogUrl(Uri url) {
    if (url.scheme != 'https' && url.scheme != 'http') return false;
    final active = Uri.tryParse(baseUrl);
    return active != null && active.host.isNotEmpty && url.origin == active.origin;
  }

  static final _bundlePath = RegExp(r'^/api/v1/extensions/([a-z0-9][a-z0-9-]*)/versions/([^/]+)/bundle$');

  /// The key and version a bundle URL names, or null for any other path.
  static ({String key, String version})? parseBundleUrl(Uri url) {
    final match = _bundlePath.firstMatch(url.path);
    if (match == null) return null;
    return (key: match.group(1)!, version: Uri.decodeComponent(match.group(2)!));
  }

  Uri bundleUrlFor(String key, String version) => Uri.parse('$baseUrl/api/v1/extensions/$key/versions/${Uri.encodeComponent(version)}/bundle');

  final Map<String, ({int at, Object value})> _cache = {};

  /// REAL clock, both sides (docs/design/time.md §1, category 2): the TTL is
  /// a staleness timeout mirroring the catalog's own `max-age`, which is
  /// measured on real seconds. Travelled, a listing fetched under `DEVTT`
  /// would expire at once or never.
  T? _cached<T>(Uri url) {
    final hit = _cache[url.toString()];
    if (hit == null) return null;
    if (realNowMillis() - hit.at > _cacheTtl.inMilliseconds) {
      _cache.remove(url.toString());
      return null;
    }
    return hit.value as T;
  }

  void _remember(Uri url, Object value) => _cache[url.toString()] = (at: realNowMillis(), value: value);

  /// Drops every cached listing, so the next question reaches the network.
  void invalidate() => _cache.clear();

  /// What the catalog publishes for this channel, ranked by the caller. Only
  /// the geo values that are known travel — an absent parameter is
  /// "unknown" to the catalog — and never the callsign. Null when the
  /// catalog could not be read; an entry that could not be parsed is
  /// dropped, not the list.
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false}) async {
    final url = Uri.parse(
      '$baseUrl/api/v1/catalog',
    ).replace(queryParameters: {'channel': channel, ...?geo?.toQueryParameters(), 'api': '$kExtensionApiVersion', 'lang': _locale()});
    // [force] for a caller that IS the operator asking — opening the panel is
    // the one moment where an answer from a few minutes ago is not good
    // enough: they have come to see what is there, and a version published
    // since is exactly what they came for.
    final cached = force ? null : _cached<List<CatalogEntry>>(url);
    if (cached != null) return cached;
    final json = await _getJson(url);
    if (json == null) return null;
    final raw = json['extensions'];
    if (raw is! List) {
      _malformed(url, 'no "extensions" list');
      return null;
    }
    final entries = [for (final item in raw) ?CatalogEntry.fromJson(item)];
    // A catalog older than this app still names the field `geo`, which
    // nothing here reads. Every entry would then rank as worldwide and the
    // listing would lose its order entirely, looking exactly like a catalog
    // whose extensions happen to be worldwide — so it says so once rather
    // than never. The rows are kept: an unranked listing beats none.
    if (raw.any((item) => item is Map && item['relevance'] == null && item['geo'] is Map)) {
      _malformed(url, 'entries carry the retired "geo" key, so nothing ranks');
    }
    _remember(url, entries);
    return entries;
  }

  /// One extension's page: every version visible on this channel. Null when
  /// the catalog could not be read, or has no such key.
  ///
  /// With [expecting], a cached listing that lacks that version is read
  /// again past the cache, once: a link can name a release younger than the
  /// five minutes the listing answers from memory, and refusing it on the
  /// strength of a stale page would be refusing the catalog's own link.
  Future<CatalogExtension?> fetchExtension(String key, {String? expecting}) async {
    if (!kSafeKeyPattern.hasMatch(key)) return null;
    final url = Uri.parse('$baseUrl/api/v1/extensions/$key').replace(queryParameters: {'channel': channel});
    final cached = _cached<CatalogExtension>(url);
    if (cached != null && (expecting == null || cached.versionNamed(expecting) != null)) return cached;
    final json = await _getJson(url);
    if (json == null) return null;
    final listing = CatalogExtension(
      key: json['key'] is String ? json['key'] as String : key,
      versions: [
        if (json['versions'] is List)
          for (final raw in json['versions'] as List) ?CatalogVersion.fromJson(raw),
      ],
    );
    _remember(url, listing);
    return listing;
  }

  /// Asks which of [installed] have a newer release, and which are revoked.
  /// Only the installed store's extensions are sent — a built-in one is not
  /// the catalog's to update — and nothing is asked when there are none:
  /// what keeps every fresh install and every developer build off the
  /// network for this.
  Future<CatalogUpdates?> checkUpdates(Iterable<ExtensionInfo> installed) async {
    final pairs = [
      for (final info in installed)
        if (info.isInstalled) {'key': info.key, 'version': info.version ?? ''},
    ];
    if (pairs.isEmpty) return null;
    final url = Uri.parse('$baseUrl/api/v1/updates');
    final json = await _postJson(url, {'channel': channel, 'api': kExtensionApiVersion, 'installed': pairs});
    if (json == null) return null;
    return CatalogUpdates.fromJson(json);
  }

  /// The bundle bytes of a listed release, verified against its sha256.
  /// Throws a [BundleException] — the install flow's `read` step.
  Future<List<int>> download(CatalogRelease release, {void Function(double? fraction)? onProgress}) =>
      downloadBundle(release.bundleUrl, sha256: release.sha256, onProgress: onProgress);

  /// Whether a bundle may be fetched from [url]. https, always — with the one
  /// exception of a loopback address while the developer override is in
  /// force, so the catalog's own dev loop can be exercised from the panel.
  /// Loopback only: an `http://` catalog on the LAN is exactly the rewrite
  /// https exists to rule out.
  bool _allowsBundleUrl(Uri url) {
    if (url.scheme == 'https') return true;
    if (!_overrideActive || url.scheme != 'http') return false;
    return url.host == 'localhost' || url.host == '127.0.0.1';
  }

  /// Fetches a bundle from [source], refusing anything implausibly large
  /// before it is held in memory — the link naming it is not one this app
  /// chose to trust. With [sha256], the bytes must hash to it or they are
  /// refused BEFORE anything looks inside them ([BundleRejection.hashMismatch]).
  ///
  /// Throws a [BundleException] for every refusal, a transport failure
  /// included ([BundleRejection.downloadFailed]): a host that never answered
  /// is a sentence about this link, which the install flow shows as it shows
  /// an unreadable file — not a defect for it to report.
  ///
  /// [onProgress] hears the fraction received as chunks arrive, or null for a
  /// response that did not say how long it is.
  Future<List<int>> downloadBundle(Uri source, {String? sha256, void Function(double? fraction)? onProgress}) async {
    var target = source;
    if (!_allowsBundleUrl(target)) {
      throw BundleException(BundleRejection.notAnArchive, t.extensionsPanel.downloadNotHttps);
    }
    final userAgent = await _userAgent();
    try {
      // Redirects followed by hand, because the point of demanding https is
      // that nobody on the path can rewrite what the consent screen describes —
      // and a client following redirects for us will happily walk https into
      // http and hand back the result as though it were the URL we asked for.
      for (var hop = 0; hop < 5; hop++) {
        final request = http.Request('GET', target)
          ..followRedirects = false
          ..headers['User-Agent'] = userAgent;
        final response = await _client.send(request).timeout(_downloadTimeout);
        final location = response.headers['location'];
        if (response.statusCode >= 300 && response.statusCode < 400 && location != null) {
          final next = target.resolve(location);
          if (!_allowsBundleUrl(next)) {
            throw BundleException(BundleRejection.notAnArchive, t.extensionsPanel.downloadNotSecure);
          }
          target = next;
          continue;
        }
        if (response.statusCode != 200) {
          throw BundleException(BundleRejection.downloadFailed, t.extensionsPanel.downloadFailed(source: target.host, status: response.statusCode));
        }
        // Counted as it arrives. Reading the whole body first and measuring it
        // afterwards is a cap that has already let the thing it refuses into
        // memory.
        final builder = BytesBuilder(copy: false);
        final total = response.contentLength;
        onProgress?.call(total == null || total <= 0 ? null : 0);
        await for (final chunk in response.stream.timeout(_downloadTimeout)) {
          builder.add(chunk);
          if (builder.length > kMaxDownloadBytes) {
            throw BundleException(BundleRejection.tooLarge, t.extensionsPanel.downloadTooLarge);
          }
          if (total != null && total > 0) onProgress?.call((builder.length / total).clamp(0.0, 1.0));
        }
        final bytes = builder.takeBytes();
        if (sha256 != null && sha256Hex(bytes) != sha256.toLowerCase()) {
          throw BundleException(BundleRejection.hashMismatch, t.extensionsPanel.downloadHashMismatch);
        }
        return bytes;
      }
    } on http.ClientException catch (e) {
      throw BundleException(BundleRejection.downloadFailed, _unreachable(target, e));
    } on TimeoutException catch (e) {
      throw BundleException(BundleRejection.downloadFailed, _unreachable(target, e));
    } on IOException catch (e) {
      throw BundleException(BundleRejection.downloadFailed, _unreachable(target, e));
    }
    throw BundleException(BundleRejection.downloadFailed, t.extensionsPanel.downloadFailed(source: source.host, status: 310));
  }

  String _unreachable(Uri target, Object cause) {
    debugPrint('[catalog] could not fetch $target: $cause');
    return t.extensionsPanel.downloadUnreachable(source: target.host);
  }

  Future<Map<String, dynamic>?> _getJson(Uri url) => _json(url, (headers) => _client.get(url, headers: headers));

  Future<Map<String, dynamic>?> _postJson(Uri url, Map<String, Object?> body) =>
      _json(url, (headers) => _client.post(url, headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode(body)));

  /// One request, one policy. A non-200 is null and a console line — a
  /// missing key is a 404 and normal. A 200 that is not a JSON object is
  /// something having published a broken response, reported on the first
  /// occurrence. Not being answered at all is reported only as a streak:
  /// one failure is a tunnel or a captive portal, the same failure every time
  /// is a defect.
  ///
  /// "Not answered" is everything the transport can throw: `package:http`'s
  /// own ClientException, the timeout wrapped around the call, and the
  /// `dart:io` failures IOClient hands up unwrapped — a TLS handshake
  /// refused, a socket reset. Every one is [CatalogUnreachable] to the
  /// policy; a bare one escaping this unattended check would reach the
  /// operator as a notice about a server they never asked about.
  Future<Map<String, dynamic>?> _json(Uri url, Future<http.Response> Function(Map<String, String> headers) send) async {
    final http.Response response;
    try {
      response = await send({'User-Agent': await _userAgent(), 'Accept': 'application/json'}).timeout(_requestTimeout);
    } on http.ClientException catch (e, st) {
      return _unanswered(url, e, st);
    } on TimeoutException catch (e, st) {
      return _unanswered(url, e, st);
    } on IOException catch (e, st) {
      return _unanswered(url, e, st);
    }
    ErrorReportingService.recordSuccess(_failureKey);
    if (response.statusCode != 200) {
      debugPrint('[catalog] $url answered ${response.statusCode}');
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (e, st) {
      debugPrint('[catalog] $url is not JSON: $e');
      ErrorReportingService.report(e, st, context: 'catalog-fetch');
      return null;
    }
    if (decoded is! Map) {
      _malformed(url, 'body is not an object');
      return null;
    }
    return decoded.cast<String, dynamic>();
  }

  Null _unanswered(Uri url, Object cause, StackTrace st) {
    debugPrint('[catalog] could not reach $url: $cause');
    ErrorReportingService.reportIfRepeated(_failureKey, CatalogUnreachable(url, cause), st, context: 'catalog-fetch');
    return null;
  }

  /// A 200 that parsed and still cannot be used. Reported like a non-JSON
  /// body: the catalog published a shape this client does not read, and the
  /// operator-facing symptom — an empty section — looks exactly like a
  /// catalog with nothing in it.
  void _malformed(Uri url, String what) {
    debugPrint('[catalog] malformed response from $url — $what');
    ErrorReportingService.report(FormatException('catalog response: $what', url.toString()), StackTrace.current, context: 'catalog-fetch');
  }
}

/// The unattended update check: once the runtime is up and again on every
/// resume, at most once per [interval] — judged against a persisted stamp on
/// the REAL clock (docs/design/time.md §1: the stamp outlives any travel that
/// wrote it, and a travelled stamp would either spam the catalog or silence
/// the check for the length of the offset).
///
/// It only ever tells: a status-bar notice and [pendingUpdates] for the
/// panel's badge. Every install still asks consent, so nothing here installs.
/// A revoked pair is the exception — that one is recorded as revoked and
/// stops running on the spot, with a notice carrying the catalog's note,
/// because the release it names has been pulled for a reason.
class CatalogUpdateCheck extends ChangeNotifier with WidgetsBindingObserver {
  static const interval = Duration(hours: 6);
  static const noticeKey = 'catalog:updates';
  static String revokedNoticeKey(String key) => 'catalog:revoked:$key';

  final CatalogService catalog;
  final SettingsService settings;
  final StatusBarService statusBar;

  /// Every known extension; only the installed ones are asked about.
  final List<ExtensionInfo> Function() installed;

  /// Whether an installed extension actually loads — ExtensionService's
  /// `isSupersededByBuiltIn`, inverted.
  ///
  /// An update OFFER is about something the operator is using, and before the
  /// catalog upgrade is taken every pre-loaded or hand-installed twin sits
  /// dormant behind the built-in it replaces. Offering an update for one of
  /// those is the app talking about an extension that is not running, on an
  /// install that has not moved to the catalog at all. Revocation is judged
  /// over everything installed regardless — a bundle withdrawn for cause is
  /// still on disk, and a built-in going away later would light it up.
  /// Defaults to "everything loads", which is what a test without an
  /// extension service means by it.
  final bool Function(ExtensionInfo) inUse;

  /// Re-applies which extensions load, once a revocation is on record —
  /// ExtensionService.applyExtensionAvailability, which reads that record.
  final Future<void> Function() applyAvailability;

  /// Opens the Extensions panel, for the notice's own button.
  ///
  /// A callback rather than a route: this service is constructed in
  /// HaLoServices and tested without a navigator, and a notice that could only
  /// be posted where one exists would go untested precisely where it matters.
  /// Null leaves the notice with nothing but its text, which is what it had.
  final VoidCallback? openExtensions;

  /// Takes every pending update in place, for the notice's Update all — the
  /// same reasons as [openExtensions] for being a callback. Null leaves the
  /// notice with More info alone.
  final Future<void> Function(List<CatalogEntry> entries)? updateAll;

  /// The clock the stamp is written and judged on. Defaults to the real
  /// clock, and that DEFAULT is the contract (time.md §7) — pinned by
  /// `catalog_service_test.dart`.
  final int Function() _realNow;

  CatalogUpdateCheck({
    required this.catalog,
    required this.settings,
    required this.statusBar,
    required this.installed,
    required this.applyAvailability,
    bool Function(ExtensionInfo)? inUse,
    this.openExtensions,
    this.updateAll,
    int Function()? realNow,
  }) : inUse = inUse ?? _everythingLoads,
       _realNow = realNow ?? realNowMillis;

  static bool _everythingLoads(ExtensionInfo info) => true;

  Map<String, CatalogEntry> _pending = const {};

  /// The releases the last answer offered, by key — what the panel badges
  /// before its own catalog fetch has resolved.
  Map<String, CatalogEntry> get pendingUpdates => _pending;

  bool _checking = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// On resume rather than on a timer: the interval is wall-clock, and no
  /// Timer survives a sleeping laptop or a backgrounded phone well enough to
  /// be worth the wakeups.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  /// Runs the check if it is due. Returns whether the catalog was asked and
  /// answered; false for a skip (no store, the experiment off, nothing
  /// installed, not yet due, a check already in flight) and for a catalog
  /// that did not answer — which leaves the stamp alone, so the next trigger
  /// asks again.
  ///
  /// [announce] false runs the check without raising the footer notice, for a
  /// caller that IS the detail the notice points at. The notice's own action
  /// dismisses it on the way to the panel, and the panel's opening check would
  /// otherwise put it straight back — the app asking twice about something the
  /// operator is looking at. A notice already up stays up, and an empty
  /// pending set still takes one down.
  Future<bool> check({bool force = false, bool announce = true}) async {
    if (!InstalledExtensions.isSupported) return false;
    // Behind the experiment while the catalog is not live — the same skip as
    // no store, BEFORE the stamp: nothing is asked and nothing is written, so
    // the first check after the flip is due at once rather than six hours on.
    if (!settings.experimentEnabled(kCatalogExperiment)) return false;
    final candidates = installed().where((info) => info.isInstalled).toList();
    if (candidates.isEmpty) return false;
    final last = settings.catalogUpdateCheckedAt;
    if (!force && last != null && _realNow() - last < interval.inMilliseconds) return false;
    if (_checking) return false;
    _checking = true;
    try {
      final result = await catalog.checkUpdates(candidates);
      if (result == null) return false;
      await settings.setCatalogUpdateCheckedAt(_realNow());
      final loading = {
        for (final info in candidates)
          if (inUse(info)) info.key,
      };
      _pending = {
        for (final update in result.updates)
          if (loading.contains(update.entry.key)) update.entry.key: update.entry,
      };
      notifyListeners();
      _noticeUpdates(candidates, announce: announce);
      await _handleRevoked(result.revoked, candidates);
      return true;
    } finally {
      _checking = false;
    }
  }

  /// An install of [key] at [version] landed. Drops it from the pending
  /// set when it is no older than what was offered, and takes the notice
  /// down with the last one: "an update is available" over an update just
  /// taken is the footer lying.
  void noteInstalled(String key, String version) {
    final offered = _pending[key];
    if (offered == null || offered.isNewerThan(version)) return;
    _pending = {..._pending}..remove(key);
    notifyListeners();
    if (_pending.isEmpty) statusBar.dismissNotice(noticeKey);
  }

  void _noticeUpdates(List<ExtensionInfo> candidates, {bool announce = true}) {
    if (_pending.isEmpty) {
      statusBar.dismissNotice(noticeKey);
      return;
    }
    if (!announce) return;
    final locale = LocaleSettings.currentLocale.languageCode;
    final names = [for (final key in _pending.keys) candidates.where((info) => info.key == key).firstOrNull?.nameFor(locale) ?? key];
    // Two names, then a count. A notice is read at a glance from the footer:
    // one name is the whole story, two still are, and by the third the list is
    // longer than the sentence around it — what is left is a number and the
    // button that shows the rest.
    final listed = names.take(2).join(', ');
    statusBar.showNotice(
      key: noticeKey,
      icon: 'update',
      title: t.extensionsPanel.updatesAvailableTitle,
      text: switch (names.length) {
        1 => t.extensionsPanel.updateAvailableFor(name: names.single),
        2 => t.extensionsPanel.updatesAvailableFor(names: listed),
        _ => t.extensionsPanel.updatesAvailable(names: listed, count: names.length - 2),
      },
      actions: [
        if (openExtensions != null)
          StatusBarAction(
            label: t.extensionsPanel.updatesNoticeAction,
            // Dismissed as it navigates: the panel it opens IS the detail, and
            // a notice still sitting in the footer behind it is the app asking
            // twice for something already being answered. The next check says
            // so again if it is still true.
            onTap: () {
              statusBar.dismissNotice(noticeKey);
              openExtensions!();
            },
          ),
        // The primary, on the trailing edge: the job the notice is about,
        // done without leaving the screen the operator is on. It takes the
        // notice down itself once confirmed; a Cancel leaves it up.
        if (updateAll != null)
          StatusBarAction(label: t.extensionsPanel.updateAllAction, primary: true, onTap: () => unawaited(updateAll!(_pending.values.toList()))),
      ],
      // Not persisted: the next launch checks again and says so again if it
      // is still true, and an update taken in between must not leave a stale
      // "update available" in the footer.
      persist: false,
    );
  }

  /// Records each revoked pair that is installed, applies it, and tells the
  /// operator once. The RECORD is what says "told": a check every six hours
  /// must not repeat the notice, and the operator's own switch cannot stand
  /// in for it — an extension they had already switched off is revoked all
  /// the same, and would otherwise never learn it.
  Future<void> _handleRevoked(List<CatalogRevocation> revoked, List<ExtensionInfo> candidates) async {
    final locale = LocaleSettings.currentLocale.languageCode;
    final records = settings.extensionRevoked;
    var recorded = false;
    for (final revocation in revoked) {
      final info = candidates.where((i) => i.key == revocation.key && i.version == revocation.version).firstOrNull;
      if (info == null) continue;
      if (records[info.key]?['version'] == revocation.version) continue;
      records[info.key] = {'version': revocation.version, 'note': revocation.note};
      recorded = true;
      statusBar.showNotice(
        key: revokedNoticeKey(info.key),
        icon: 'alert',
        title: t.extensionsPanel.revokedTitle(name: info.nameFor(locale)),
        text: [t.extensionsPanel.revokedBody, if (revocation.note.isNotEmpty) revocation.note].join(' '),
      );
    }
    if (!recorded) return;
    await settings.setExtensionRevoked(records);
    await applyAvailability();
  }
}
