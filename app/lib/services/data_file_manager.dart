// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/user_agent.dart';
import '../i18n/strings.g.dart';
import 'error_reporting_service.dart';
import 'extension_service.dart';
import 'status_bar_service.dart';

/// The encoding to decode a data file with, resolved by precedence:
/// the definition's [defEncoding] wins (it overrides a wrong/missing server
/// header), else the `charset` from the response's Content-Type
/// [contentTypeHeader], else null — [decodeDataFileBody] then defaults to
/// UTF-8. This replaces Dart's `http.Response.body`, which silently defaults a
/// charset-less response to latin1 and so garbled UTF-8 park names.
String? resolveDataFileEncoding(String? defEncoding, String? contentTypeHeader) {
  if (defEncoding != null && defEncoding.isNotEmpty) return defEncoding;
  if (contentTypeHeader == null) return null;
  try {
    return ContentType.parse(contentTypeHeader).charset; // dart:io lowercases it
  } catch (_) {
    return null; // unparseable header — fall back to the UTF-8 default
  }
}

/// Decodes a downloaded data-file body from raw bytes into a Dart string
/// (internally Unicode). [encoding] comes from [resolveDataFileEncoding]
/// (definition override → server charset → UTF-8 default). Malformed bytes are
/// replaced (U+FFFD), never thrown, so one bad byte can't fail the whole file.
/// Unknown/unsupported encodings fall back to UTF-8.
String decodeDataFileBody(List<int> bytes, {String? encoding}) {
  switch ((encoding ?? 'utf-8').toLowerCase().replaceAll('_', '-')) {
    case 'latin1':
    case 'latin-1':
    case 'iso-8859-1':
      return latin1.decode(bytes, allowInvalid: true);
    case 'ascii':
    case 'us-ascii':
      return ascii.decode(bytes, allowInvalid: true);
    case 'utf-8':
    case 'utf8':
      return utf8.decode(bytes, allowMalformed: true);
    default:
      debugPrint('[data-file] unknown encoding "$encoding" — decoding as UTF-8');
      return utf8.decode(bytes, allowMalformed: true);
  }
}

/// The message shown in a download-failure notice. `package:http`'s
/// BrowserClient wraps every browser-level fetch failure (a cross-origin
/// download the browser refuses — one that would work from a native build
/// — but also a plain network outage) in a [http.ClientException]; that
/// class gets a plain-language hint appended, worded to cover both causes
/// rather than assuming it's specifically a CORS block. Check the TYPE,
/// never the message text: `'Failed to fetch'` is Chromium/V8's own wording
/// for the underlying `fetch()` TypeError, and Firefox and Safari phrase
/// the identical failure differently — a string match silently never fires
/// for them. Every other failure (a 404, a malformed URL) is shown
/// as-is, since guessing at THOSE causes would be more likely to mislead
/// than help. [isWeb] defaults to [kIsWeb] but is overridable — the
/// constant itself isn't, so a test can't flip platforms without this.
@visibleForTesting
String friendlyDownloadError(Object error, {bool isWeb = kIsWeb}) {
  final message = error.toString();
  if (isWeb && error is http.ClientException) {
    return '$message\n\n${t.dataFiles.downloadFailedWebHint}';
  }
  return message;
}

/// One registered data file's definition plus its last-download time, for
/// the Data Files settings panel. [updatedAt] is null when the file has
/// never been downloaded on this device.
class DataFileStatus {
  final String key;
  final String name;

  /// The extension's own icon name (MDI, resolved via resolveIconName), if
  /// it declared one — today's [DataFileDefinition] doesn't, so this is
  /// almost always null and the panel falls back to a generic icon.
  final String? icon;

  final DateTime? updatedAt;

  DataFileStatus({
    required this.key,
    required this.name,
    this.icon,
    this.updatedAt,
  });

  DataFileStatus withUpdatedAt(DateTime updatedAt) =>
      DataFileStatus(key: key, name: name, icon: icon, updatedAt: updatedAt);
}

class DataFileManager {
  final LookupRepository lookups;
  final ExtensionService extensions;
  final SharedPreferences prefs;
  final StatusBarService? statusBar;

  DataFileManager({
    required this.lookups,
    required this.extensions,
    required this.prefs,
    this.statusBar,
  }) {
    // Every successful runtime start can register dataFile hooks that did
    // not exist before — a custom file added in a settings panel, an
    // extension enabled from the Extensions panel, a crash-recovery start
    // finally coming up — and nothing else fetches those until the next
    // boot. runtimeGeneration ticks once per successful start (never on a
    // failed one), so listening to it covers every restart path with one
    // channel. Cheap when nothing changed: fresh files are age-skipped, so
    // a no-op pass costs one definition fan-out. Failures notify — a
    // restart-adjacent sync is an attended moment, unlike the boot sync
    // (whose own explicit call happens before this listener is registered,
    // since HaLoServices constructs DataFileManager lazily after start).
    extensions.runtimeGeneration.addListener(_onRuntimeReplaced);
  }

  bool _postStartSyncRunning = false;
  bool _postStartSyncQueued = false;

  void _onRuntimeReplaced() => unawaited(_syncAfterRuntimeReplaced());

  /// One sync per generation tick, serialized: concurrent full syncs would
  /// double-download the same files. A tick landing mid-sync queues exactly
  /// one follow-up pass (it may carry registrations the running pass's
  /// snapshot predates).
  Future<void> _syncAfterRuntimeReplaced() async {
    if (_postStartSyncRunning) {
      _postStartSyncQueued = true;
      return;
    }
    _postStartSyncRunning = true;
    try {
      do {
        _postStartSyncQueued = false;
        await syncAllDataFiles();
      } while (_postStartSyncQueued);
    } finally {
      _postStartSyncRunning = false;
    }
  }

  /// The serializable definitions every enabled extension contributes
  /// through the `dataFile`/`getDefinition` hook. Malformed or failed
  /// entries are dropped rather than throwing, same as [syncAllDataFiles].
  Future<List<Map<String, dynamic>>> _fetchDefinitions() async {
    final host = extensions.host;
    if (host == null) return const [];
    final List<dynamic> entries;
    try {
      entries = await host.invokeHookAll('dataFile', method: 'getDefinition');
    } catch (e, st) {
      debugPrint('[data-file] failed to fetch definitions: $e');
      ErrorReportingService.report(e, st, context: 'data-files:fetch-definitions');
      return const [];
    }
    final defs = <Map<String, dynamic>>[];
    for (final entry in entries) {
      if (entry is! Map || entry['ok'] != true || entry['value'] == null) continue;
      try {
        defs.add(Map<String, dynamic>.from(entry['value'] as Map));
      } catch (e) {
        // Matches this method's own doc comment: a malformed entry (here,
        // `value` present but not actually a Map — some extension's
        // `dataFile.getDefinition` hook returning the wrong shape) is
        // dropped, not left to throw uncaught out of every caller.
        // refreshDataFile then finds no definition for the key and raises
        // its own no-definition notice — dropping here is safe because that
        // path speaks.
        debugPrint('[data-file] dropping malformed definition entry: $e');
      }
    }
    return defs;
  }

  /// Lists every registered data file with its last-download time (read
  /// from the `data_file_updated_$key` prefs the sync/refresh paths stamp),
  /// sorted by name — the Data Files settings panel's data source.
  Future<List<DataFileStatus>> listDataFiles() async {
    final files = <DataFileStatus>[];
    for (final def in await _fetchDefinitions()) {
      final key = def['key'] as String?;
      if (key == null) continue;
      final millis = prefs.getInt('data_file_updated_$key');
      files.add(DataFileStatus(
        key: key,
        name: def['name'] as String? ?? key,
        icon: def['icon'] as String?,
        updatedAt: millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis),
      ));
    }
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return files;
  }

  /// Forces a fresh download + reprocess of the single data file [key]
  /// (bypassing ETag caching, like [syncAllDataFiles] with `force`) and
  /// re-stamps its last-download time, which it returns so the caller can
  /// update its row without re-listing. Returns null if no registered data
  /// file has that key. Progress and errors surface through the status bar
  /// (see [processDataFile]); the exception is rethrown so the caller can
  /// react too.
  Future<DateTime?> refreshDataFile(String key) async {
    for (final def in await _fetchDefinitions()) {
      if (def['key'] != key) continue;
      await processDataFile(key, def, force: true);
      final now = DateTime.now();
      await prefs.setInt('data_file_updated_$key', now.millisecondsSinceEpoch);
      return now;
    }
    // No matching definition: the host is mid-restart, the whole fetch
    // failed, or this key's entry was dropped as malformed. None of those
    // paths reach processDataFile, so without a notice HERE a Refresh tap
    // would end in silence — spinner stops, timestamp unchanged, nothing
    // said.
    statusBar?.showNotice(
      key: 'dataFile:$key',
      icon: 'alert-circle',
      title: t.dataFiles.downloadFailedTitle(name: key),
      text: t.dataFiles.definitionUnavailable,
    );
    return null;
  }

  /// Resolves direct URLs from sharing links for known file sharing systems.
  String resolveDownloadUrl(String url) {
    var u = url.trim();
    if (u.contains('dropbox.com/')) {
      u = u.replaceAll(RegExp(r'[&?]raw=\d'), '').replaceAll(RegExp(r'[&?]dl=\d'), '');
      u = u.contains('?') ? '$u&dl=1&raw=1' : '$u?dl=1&raw=1';
      // Dropbox serves share links from both the bare and `www.` host, but
      // only `www.dropbox.com` is in `_resolveFetchUrl`'s allowedDomains (and
      // the services.ham2k.net proxy route) — without this, a bare-host link
      // would skip the CORS proxy on web and hit the exact failure this is
      // meant to fix.
      u = u.replaceFirstMapped(RegExp(r'^(https?://)dropbox\.com/'), (m) => '${m[1]}www.dropbox.com/');
    } else if (u.contains('drive.google.com/')) {
      final match = RegExp(r'file/d/([\w_-]+)').firstMatch(u);
      if (match != null) {
        u = 'https://drive.google.com/uc?id=${match.group(1)}&export=download';
      }
    } else if (u.contains('docs.google.com/document')) {
      final match = RegExp(r'/d/([\w_-]+)').firstMatch(u);
      if (match != null) {
        u = 'https://docs.google.com/document/export?format=txt&id=${match.group(1)}';
      }
    } else if (u.contains('gist.github.com/') &&
        !(Uri.tryParse(u)?.pathSegments.contains('raw') ?? false)) {
      // The share page itself is HTML, not the file's content — `/raw`
      // (no filename) redirects to the latest revision's raw content,
      // which is what every other branch above resolves to as well. The
      // owner segment is optional: pre-2018 anonymous gists (GitHub stopped
      // letting new ones be created, but existing ones stay reachable) are
      // keyed by hash alone, with no username in the URL.
      //
      // Skipped entirely when the URL already has a `raw` PATH SEGMENT:
      // that's already a direct download link, possibly naming one specific
      // file in a multi-file gist — rewriting it to the generic
      // latest-revision form would discard that filename and silently fetch
      // a different file. Matched as a segment, not a substring: a gist
      // owner named `rawmilk` must not disable the rewrite.
      final match = RegExp(r'gist\.github\.com/(?:([\w-]+)/)?([0-9a-fA-F]+)').firstMatch(u);
      if (match != null) {
        final owner = match.group(1);
        final hash = match.group(2);
        u = owner != null
            ? 'https://gist.githubusercontent.com/$owner/$hash/raw'
            : 'https://gist.githubusercontent.com/$hash/raw';
      }
    }
    return u;
  }

  String _resolveFetchUrl(String urlString) {
    if (kIsWeb) {
      final uri = Uri.parse(urlString);
      const allowedDomains = {
        'api.pota.app',
        'logbook.qrz.com',
        'xmldata.qrz.com',
        'api.hamdb.org',
        'country-files.com',
        'pota.app',
        'www.sotadata.org.uk',
        'sotadata.org.uk',
        // Custom data-file hosts (e.g. call-notes' custom note files):
        // neither sends CORS headers on its share-link redirect hop, so a
        // direct browser fetch is blocked even though the final redirected
        // response is itself CORS-permissive. docs.google.com and GitHub
        // Gists' raw content aren't listed here — both already send
        // permissive CORS headers directly, verified against the real
        // services, so proxying them would be needless indirection.
        'www.dropbox.com',
        'drive.google.com',
      };
      if (allowedDomains.contains(uri.host)) {
        return 'https://services.ham2k.net/${uri.host}${uri.path}${uri.hasQuery ? "?${uri.query}" : ""}';
      }
    }
    return urlString;
  }

  /// A fetch URL safe to write to a log: everything up to the path, with any
  /// query string replaced by `?…`.
  ///
  /// Some award programs carry their API key as a query parameter — TOTA's
  /// list is `tower.php?key=<secret>` — and the key is a real secret, not a
  /// public token. Logging the URL whole would put it in the device log on
  /// every refresh, and `debugPrint` is not stripped from release builds.
  /// Nothing downstream needs the query to identify which file was fetched:
  /// the key and the host already say that.
  @visibleForTesting
  static String redactUrlForLog(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return '(unparseable url)';
    // Cut the string rather than rebuilding through Uri: `replace(query: '')`
    // leaves the empty `?` and `#` markers behind.
    final cut = url.indexOf(RegExp(r'[?#]'));
    return cut < 0 ? url : '${url.substring(0, cut)}?…';
  }

  /// Downloads the file at [url] and returns the decoded body string, or null
  /// on a 304, or throws. Decoded per [resolveDataFileEncoding]: the
  /// definition's [encoding] overrides the response's Content-Type charset,
  /// which is otherwise honored, defaulting to UTF-8 — NOT `http.Response.body`,
  /// which defaults a charset-less response to latin1 and so garbles UTF-8 park
  /// names. Uses ETag cached in [prefs] to avoid duplicate downloads,
  /// unless [force] skips sending it — a manual reload wants a full reprocess
  /// even when the server would otherwise report the content unchanged.
  Future<String?> downloadFile(String key, String url, {bool force = false, String? encoding}) async {
    final resolvedUrl = _resolveFetchUrl(resolveDownloadUrl(url));
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(resolvedUrl));
    request.headers['User-Agent'] = await ham2kUserAgent();
    final etagKey = 'data_file_etag_$key';
    final cachedEtag = force ? null : prefs.getString(etagKey);
    if (cachedEtag != null) {
      request.headers['If-None-Match'] = cachedEtag;
    }

    debugPrint('[data-file] Fetching $key from ${redactUrlForLog(resolvedUrl)} (cached ETag: $cachedEtag)');
    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    client.close();

    if (response.statusCode == 304) {
      debugPrint('[data-file] File $key unchanged (304)');
      return null;
    }

    if (response.statusCode != 200) {
      throw HttpException('Failed to download $key: HTTP ${response.statusCode}');
    }

    final newEtag = response.headers['etag'];
    if (newEtag != null) {
      await prefs.setString(etagKey, newEtag);
    }
    final resolved = resolveDataFileEncoding(encoding, response.headers['content-type']);
    return decodeDataFileBody(response.bodyBytes, encoding: resolved);
  }

  /// Schedules sync and processing of registered data files. With
  /// [categoryFilter], only data files whose `category` matches
  /// (case-insensitively) are considered — used by the RELOAD command to
  /// target a single activity (e.g. "RELOAD POTA"). [force] additionally
  /// bypasses ETag caching (see [downloadFile]), not just the staleness
  /// check — RELOAD's whole point is usually that our own mapping logic
  /// changed, not the source data, so an unchanged server response still
  /// needs reprocessing. Returns how many data files matched the filter.
  ///
  /// [notifyOnFailure] forwards to [processDataFile] — the boot/onboarding
  /// callers of this method pass `false` so an offline device doesn't raise a
  /// persistent notice on every single unattended sync; a
  /// user-driven caller (Update All, RELOAD) leaves it at the default `true`.
  Future<int> syncAllDataFiles({bool force = false, String? categoryFilter, bool notifyOnFailure = true}) async {
    final host = extensions.host;
    if (host == null) {
      debugPrint('[data-file] Extension host not ready');
      return 0;
    }

    final List<dynamic> entries;
    try {
      entries = await host.invokeHookAll('dataFile', method: 'getDefinition');
    } catch (e, st) {
      debugPrint('[data-file] failed to fetch definitions: $e');
      ErrorReportingService.report(e, st, context: 'data-files:sync-all-fetch-definitions');
      return 0;
    }

    await _purgeOrphanedKeys(entries);

    var matched = 0;
    await Future.wait(entries.map((entry) async {
      if (entry is! Map || entry['ok'] != true || entry['value'] == null) return;

      // Everything below — including parsing `entry['value']` itself — is
      // guarded in one block: a malformed definition from one extension
      // must not throw out of this closure uncaught, or it takes down
      // `Future.wait`'s overall result for every other (well-formed) data
      // file's caller too (e.g. the RELOAD command's completion notice).
      try {
        final def = Map<String, dynamic>.from(entry['value'] as Map);
        final key = def['key'] as String;
        final category = (def['category'] as String? ?? key).toUpperCase();
        if (categoryFilter != null && category != categoryFilter) return;
        matched++;

        // Remember which extension owns this data file (and its lookup
        // category) so the stale-data purge can find it later, when the
        // extension is disabled and can no longer describe itself.
        await _recordOwnership(key, def);

        final maxAgeDays = def['maxAgeInDays'] as int? ?? 14;
        final lastUpdateKey = 'data_file_updated_$key';
        final lastUpdateTime = prefs.getInt(lastUpdateKey) ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - lastUpdateTime;
        final isStale = age > maxAgeDays * 24 * 60 * 60 * 1000;

        if (force || isStale || lastUpdateTime == 0) {
          await processDataFile(key, def, force: force, notifyOnFailure: notifyOnFailure);
          await prefs.setInt(lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
        }
      } catch (e, stack) {
        debugPrint('[data-file] Error processing data file entry ${entry['value']}: $e\n$stack');
        ErrorReportingService.report(e, stack, context: 'data-files:process-entry');
      }
    }));
    return matched;
  }

  /// Resolves the human-facing name to show for a data file in status bar
  /// messages: its own name if the extension gave it one, else the label of
  /// the extension that registered it, else its raw key as a last resort.
  String _labelFor(String key, Map<String, dynamic> def) {
    return def['name'] as String? ?? def['extensionName'] as String? ?? key;
  }

  /// Natively parses and processes a data file based on its `fetchType`.
  ///
  /// [notifyOnFailure] gates the persistent status-bar notice below — off
  /// for the unattended background path ([syncAllDataFiles]'s boot/onboarding
  /// callers), which would otherwise raise the same alert on every single
  /// offline boot; on (the default) for every user-driven caller (a Refresh
  /// tap, Update All, RELOAD), which is the one place users actually need to
  /// see it.
  Future<void> processDataFile(String key, Map<String, dynamic> def, {bool force = false, bool notifyOnFailure = true}) async {
    final label = _labelFor(key, def);
    final statusKey = 'dataFile:$key';

    statusBar?.setProgress(key: statusKey, title: label, text: t.dataFiles.downloading);
    final String? body;
    final String fetchType;
    try {
      // `url`/`fetchType` extraction lives INSIDE this try, not before it —
      // a malformed definition (an extension's getDefinition() missing or
      // mistyping either) would otherwise throw uncaught, reaching a caller
      // like _refresh's silent catch with zero feedback at all, where every
      // other failure at least shows a notice.
      final url = def['url'] as String;
      fetchType = def['fetchType'] as String;
      body = await downloadFile(key, url, force: force, encoding: def['encoding'] as String?);
    } catch (e) {
      statusBar?.clear(statusKey);
      debugPrint('[data-file] Failed to download $key: $e');
      // A persistent notice, not the transient progress line above — every
      // caller of processDataFile (a single Refresh tap, Update All, the
      // background sync after adding a custom file) funnels through here,
      // so this is the one place that needs to say so; callers that also
      // catch this (e.g. syncAllDataFiles) still get to report/log it too.
      if (notifyOnFailure) {
        statusBar?.showNotice(
          key: statusKey,
          icon: 'alert-circle',
          title: t.dataFiles.downloadFailedTitle(name: label),
          text: friendlyDownloadError(e),
        );
      }
      rethrow;
    }
    if (body == null) {
      // Unchanged 304.
      statusBar?.clear(statusKey);
      return;
    }

    try {
      if (fetchType == 'csv') {
        await _processCsv(key, def, body);
      } else if (fetchType == 'json') {
        await _processJson(key, def, body);
      } else if (fetchType == 'raw') {
        await _processRaw(key, def, body);
      }
    } catch (e) {
      statusBar?.clear(statusKey);
      debugPrint('[data-file] Failed to process $key: $e');
      // Distinct title from the download-failure notice above — a JSON/CSV
      // parsing error after a successful download is a config/data problem,
      // not a network one, and labeling it "Couldn't download" misdiagnoses
      // it.
      if (notifyOnFailure) {
        statusBar?.showNotice(
          key: statusKey,
          icon: 'alert-circle',
          title: t.dataFiles.processingFailedTitle(name: label),
          text: e.toString(),
        );
      }
      rethrow;
    }
  }

  Future<void> _processCsv(String key, Map<String, dynamic> def, String body) async {
    final category = def['category'] as String? ?? key;
    final csvOpts = def['csvOptions'] as Map<dynamic, dynamic>? ?? const {};
    final hasHeaders = csvOpts['hasHeaders'] as bool? ?? true;
    final skipRows = csvOpts['skipRows'] as int? ?? 0;
    final delimiter = csvOpts['delimiter'] as String? ?? ',';

    // Parse lines
    //
    // Rows stay as positional lists and the header row is sent ONCE per chunk,
    // for the kernel to zip back into the `Record<string,string>` that
    // `csvToLookupEntry` expects (extensions/sdk/src/kernel.ts). Building the
    // maps here instead would repeat every column name in the JSON for every
    // row: measured on SOTA's 181,604-row file that is ~241 of the ~395
    // bytes per row — 61% of everything crossing the boundary would be the
    // same 17 strings over and over, paid four times (encode, escape into
    // the eval source, tokenize, JSON.parse).
    final lines = const LineSplitter().convert(body);
    final parsedRows = <dynamic>[];
    List<String>? headers;

    for (var i = 0; i < lines.length; i++) {
      if (i < skipRows) continue;
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parsed = parseCsvRow(line, delimiter);
      if (hasHeaders && headers == null) {
        headers = parsed;
        continue;
      }
      parsedRows.add(parsed);
    }

    await _batchWriteToDatabase(key, category, _labelFor(key, def), 'mapCsvBatch', 'rows', parsedRows,
        extraArgs: headers == null ? null : {'headers': headers});
  }

  Future<void> _processJson(String key, Map<String, dynamic> def, String body) async {
    final category = def['category'] as String? ?? key;
    final jsonOpts = def['jsonOptions'] as Map<dynamic, dynamic>? ?? const {};
    final rootPath = jsonOpts['rootPath'] as String?;

    final decoded = jsonDecode(body);
    final target = resolveRootPath(decoded, rootPath);

    final List<dynamic> entriesToProcess = [];
    if (target is List) {
      entriesToProcess.addAll(target);
    } else if (target is Map) {
      target.forEach((k, v) {
        entriesToProcess.add({'key': k, 'value': v});
      });
    } else {
      throw FormatException('Resolved target at rootPath is neither Array nor Object');
    }

    await _batchWriteToDatabase(key, category, _labelFor(key, def), 'mapJsonBatch', 'entries', entriesToProcess);
  }

  Future<void> _processRaw(String key, Map<String, dynamic> def, String body) async {
    final host = extensions.host;
    if (host == null) return;

    // 1. Pass down to JS converter rawToJSONData
    final dynamic processedJson = await host.invokeHook(
      'dataFile',
      key: key,
      method: 'rawToJSONData',
      args: {
        'body': body,
        'url': def['url'],
        'options': const {},
      },
    );

    // 2. Cache processed JSON to local file
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final dataFilesDir = Directory(p.join(dir.path, 'data_files'));
      if (!await dataFilesDir.exists()) {
        await dataFilesDir.create(recursive: true);
      }
      final cacheFile = File(p.join(dataFilesDir.path, '$key.json'));
      await cacheFile.writeAsString(jsonEncode(processedJson));
    }

    // 3. Load processed data by calling onLoadRawData
    await host.invokeHook(
      'dataFile',
      key: key,
      method: 'onLoadRawData',
      args: processedJson,
    );

    final statusKey = 'dataFile:$key';
    final label = _labelFor(key, def);
    final count = processedJson is List ? processedJson.length : null;
    statusBar?.setProgress(
      key: statusKey,
      title: label,
      text: count != null
          ? t.dataFiles.importedRecords(count: count, label: label)
          : t.dataFiles.importedData(label: label),
      value: 1.0,
    );
  }

  /// Triggers loading cached raw files at startup/activation.
  Future<void> loadRawDataFiles() async {
    if (kIsWeb) return;
    final host = extensions.host;
    if (host == null) return;

    final List<dynamic> entries;
    try {
      entries = await host.invokeHookAll('dataFile', method: 'getDefinition');
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'data-files:load-raw-fetch-definitions');
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final dataFilesDir = Directory(p.join(dir.path, 'data_files'));
    if (!await dataFilesDir.exists()) return;

    for (final entry in entries) {
      if (entry is Map && entry['ok'] == true && entry['value'] != null) {
        final def = Map<String, dynamic>.from(entry['value'] as Map);
        final key = def['key'] as String;
        final fetchType = def['fetchType'] as String;

        if (fetchType == 'raw') {
          final cacheFile = File(p.join(dataFilesDir.path, '$key.json'));
          if (await cacheFile.exists()) {
            try {
              final content = await cacheFile.readAsString();
              final processedJson = jsonDecode(content);
              await host.invokeHook(
                'dataFile',
                key: key,
                method: 'onLoadRawData',
                args: processedJson,
              );
            } catch (e, st) {
              debugPrint('[data-file] Error loading raw cache file $key: $e');
              ErrorReportingService.report(e, st, context: 'data-files:load-raw-cache-file');
            }
          }
        }
      }
    }
  }

  static const _ownershipKey = 'data_file_ownership';

  /// `{dataFileKey: {ext, category}}` — persisted so the stale-data purge
  /// can identify (and delete) a disabled extension's data even though the
  /// extension is no longer loaded to describe it.
  Map<String, dynamic> _ownership() {
    final raw = prefs.getString(_ownershipKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _recordOwnership(String key, Map<String, dynamic> def) async {
    final ext = def['extensionKey'] as String?;
    if (ext == null) return;
    final category = def['category'] as String? ?? key;
    final all = _ownership();
    final existing = all[key];
    if (existing is Map && existing['ext'] == ext && existing['category'] == category) return;
    all[key] = {'ext': ext, 'category': category};
    await prefs.setString(_ownershipKey, jsonEncode(all));
  }

  /// Purges the disk cache/etag/last-updated prefs of a dataFile key whose
  /// owning extension is still enabled and loaded, but no longer registers
  /// that key — e.g. a call-notes `customFiles` entry whose URL (and so
  /// derived identifier) changed. Distinct from [purgeStaleExtensionData],
  /// which only acts on entire DISABLED extensions; without this, the OLD
  /// identifier's cache/prefs would persist on disk forever, since no other
  /// path ever revisits a key that stopped being registered.
  /// [entries] is [syncAllDataFiles]'s own `getDefinition` fan-out — the set
  /// of keys an extension registers THIS pass, before any [categoryFilter]
  /// narrows what actually gets downloaded.
  Future<void> _purgeOrphanedKeys(List<dynamic> entries) async {
    // Purging is destructive and this snapshot is the sole evidence, so it
    // must be TRUSTWORTHY before any key is condemned:
    // - a start that proceeded past the bounded activation wait can be
    //   missing registrations an extension makes after its own internal
    //   await — a partial picture, not an authoritative one;
    // - a single ok:false record (a throwing url()/description() ctx
    //   function, a transient host-call failure) means some registered key
    //   is invisible this pass — and the failed record carries no
    //   extensionKey, so it cannot even be matched to its owner.
    // Either way: stand down; a later clean pass purges genuinely orphaned
    // keys. The cost of deferring is a stale cache file; the cost of
    // purging on a partial snapshot is destroying offline data.
    if (extensions.activationIncomplete) return;
    for (final entry in entries) {
      if (entry is! Map || entry['ok'] != true) return;
    }
    final currentKeysByExtension = <String, Set<String>>{};
    for (final entry in entries) {
      if (entry is! Map || entry['ok'] != true || entry['value'] is! Map) continue;
      final def = entry['value'] as Map;
      final key = def['key'] as String?;
      final ext = def['extensionKey'] as String?;
      if (key == null || ext == null) continue;
      (currentKeysByExtension[ext] ??= {}).add(key);
    }

    final all = _ownership();
    var purged = 0;
    for (final entry in all.entries.toList()) {
      final owner = entry.value;
      if (owner is! Map) continue;
      final liveKeys = currentKeysByExtension[owner['ext']];
      // The extension didn't appear in this sync pass at all (disabled, or
      // the runtime isn't up) — purgeStaleExtensionData handles that case on
      // its own schedule; nothing to do here unless it's currently loaded
      // and simply dropped this one key.
      if (liveKeys == null || liveKeys.contains(entry.key)) continue;
      final key = entry.key;
      final category = owner['category'] as String? ?? key;
      debugPrint('[data-file] Purging orphaned key $key (extension ${owner['ext']} no longer registers it)');
      await _purgeDataFileData(key, category);
      all.remove(key);
      purged++;
    }
    if (purged > 0) await prefs.setString(_ownershipKey, jsonEncode(all));
  }

  /// Purges the downloaded data of extensions that have been DISABLED for at
  /// least [grace] (default 7 days) — their lookup rows, raw cache files,
  /// and bookkeeping prefs. Data of extensions that are enabled, or
  /// recently disabled (a re-enable inside the window keeps everything), is
  /// left untouched. [disabledSince] is `settings.extensionDisabledSince`.
  /// Runs at startup, after the runtime is up and the enabled extensions
  /// have refreshed their ownership records.
  Future<void> purgeStaleExtensionData(
    Map<String, int> disabledSince, {
    Duration grace = const Duration(days: 7),
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now()).millisecondsSinceEpoch - grace.inMilliseconds;
    final staleExtensions = {
      for (final e in disabledSince.entries)
        if (e.value <= cutoff) e.key,
    };
    if (staleExtensions.isEmpty) return;

    final all = _ownership();
    var purged = 0;
    for (final entry in all.entries.toList()) {
      final owner = entry.value;
      if (owner is! Map || !staleExtensions.contains(owner['ext'])) continue;
      final key = entry.key;
      final category = owner['category'] as String? ?? key;
      debugPrint('[data-file] Purging data for $key (extension ${owner['ext']} disabled > ${grace.inDays}d)');
      await _purgeDataFileData(key, category);
      all.remove(key);
      purged++;
    }
    if (purged > 0) {
      await prefs.setString(_ownershipKey, jsonEncode(all));
      // A completed-progress item auto-dismisses after the usual delay.
      statusBar?.setProgress(
        key: 'dataFile:purge',
        icon: 'delete-clock',
        title: t.dataFiles.cleanedUpTitle,
        text: t.dataFiles.removedData(count: purged),
        value: 1.0,
      );
    }
  }

  /// The Dart-side deletion a data file leaves behind — lookup rows, raw
  /// cache file, and etag/last-update prefs. Unlike [removeDataFile] it does
  /// NOT call the extension's `onRemoveRawData` hook (a purge targets
  /// DISABLED extensions, which aren't loaded to receive it) and uses the
  /// recorded lookup category rather than assuming it equals the key.
  Future<void> _purgeDataFileData(String key, String category) async {
    await prefs.remove('data_file_etag_$key');
    await prefs.remove('data_file_updated_$key');
    await lookups.deleteCategory(category);
    if (!kIsWeb) {
      // The lookup rows and prefs are the substance; a leftover cache file
      // is minor and self-heals on re-sync, so a filesystem hiccup here
      // mustn't abort the purge.
      try {
        final dir = await getApplicationDocumentsDirectory();
        final cacheFile = File(p.join(dir.path, 'data_files', '$key.json'));
        if (await cacheFile.exists()) await cacheFile.delete();
      } catch (e) {
        debugPrint('[data-file] could not delete cache file for $key: $e');
      }
    }
  }

  /// Removes a cached data file and triggers its clean-up hooks.
  Future<void> removeDataFile(String key) async {
    final host = extensions.host;
    if (host != null) {
      try {
        await host.invokeHook('dataFile', key: key, method: 'onRemoveRawData', args: const {});
      } catch (e) {
        // ignore if not present
      }
    }

    final etagKey = 'data_file_etag_$key';
    final lastUpdateKey = 'data_file_updated_$key';
    await prefs.remove(etagKey);
    await prefs.remove(lastUpdateKey);

    // Delete from lookups by category
    await lookups.deleteCategory(key);

    // Delete raw cache files
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File(p.join(dir.path, 'data_files', '$key.json'));
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    }
  }

  /// Helper to send chunks across FFI boundary and write to Drift in database batches.
  Future<void> _batchWriteToDatabase(
    String key,
    String category,
    String label,
    String mappingMethod,
    String mappingArgKey,
    List<dynamic> items, {
    Map<String, dynamic>? extraArgs,
  }) async {
    final host = extensions.host;
    if (host == null) return;

    final updatedFlag = DateTime.now().millisecondsSinceEpoch;
    final chunkSize = 5000;
    final statusKey = 'dataFile:$key';
    var imported = 0;

    for (var start = 0; start < items.length; start += chunkSize) {
      final end = start + chunkSize < items.length ? start + chunkSize : items.length;
      final chunk = items.sublist(start, end);

      statusBar?.setProgress(
        key: statusKey,
        title: label,
        text: t.dataFiles.recordsProgress(end: end, total: items.length),
        value: items.isEmpty ? 1.0 : end / items.length,
      );

      // Invoke chunk mapper in QuickJS
      //
      // The timeout is explicit because the default 10s is a per-CALL budget
      // that a 5000-row chunk shares with every other data file being synced
      // at the same time — `syncAllDataFiles` starts ~20 of them at once and
      // they all queue through the one single-threaded engine.
      //
      // TODO: 60s is cover for that contention, not a considered per-chunk
      // budget. If syncAllDataFiles moves to parallel downloads + serial
      // processing (APP-16), this should come back down.
      final dynamic response = await host.invokeHook(
        'dataFile',
        key: key,
        method: mappingMethod,
        args: {mappingArgKey: chunk, ...?extraArgs},
        timeout: const Duration(seconds: 60),
      );

      if (response is! List) {
        // Loud, not silent: losing a whole chunk is a data-integrity problem,
        // and the caller already treats a failed data file as a failed sync.
        //
        // Throwing here also protects what is already in the table. Skipping
        // instead would let the loop run to the `deleteCategoryStale` below
        // with nothing imported, which sweeps every row that this run did not
        // stamp — a mapper that returned nothing would WIPE the whole
        // category. Bailing out leaves the partial import in place (same primary key,
        // insertOrReplace, so no duplicates), skips the sweep, and leaves
        // `data_file_updated_$key` unstamped, so the next sync redoes the file
        // in full and sweeps then.
        throw ExtensionHostException(
          'dataFile $key: $mappingMethod returned ${response.runtimeType}, not a list — '
          'dropping rows $start..$end of ${items.length}',
        );
      }

      final lookupRows = <LookupRow>[];
      for (final item in response) {
        if (item is Map) {
          final entryKey = item['key'] as String?;
          if (entryKey != null) {
            lookupRows.add(LookupRow(
              category: category,
              subCategory: item['subCategory'] as String?,
              key: entryKey,
              name: item['name'] as String?,
              lat: (item['lat'] as num?)?.toDouble(),
              lon: (item['lon'] as num?)?.toDouble(),
              flags: item['flags'] as int?,
              data: item['data'] != null ? jsonEncode(item['data']) : null,
              updated: updatedFlag,
            ));
          }
        }
      }
      if (lookupRows.isNotEmpty) {
        await lookups.insertLookupBatch(lookupRows);
        imported += lookupRows.length;
      }
    }

    // Clean up any stale records not updated in this run
    await lookups.deleteCategoryStale(category, updatedFlag);

    statusBar?.setProgress(
        key: statusKey, title: label, text: t.dataFiles.importedRecords(count: imported, label: label), value: 1.0);
  }

  List<String> parseCsvRow(String line, String delimiter) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    result.add(sb.toString());
    return result;
  }

  dynamic resolveRootPath(dynamic obj, String? path) {
    if (path == null || path.isEmpty) return obj;
    final parts = path.split('.');
    dynamic current = obj;
    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else if (current is List) {
        // A numeric segment indexes a list, so a payload that wraps its rows in
        // a positional envelope is reachable — ECA and ELA publish
        // `[meta, meta, {data: [...]}]`, i.e. rootPath `2.data`. A non-numeric
        // or out-of-range segment is a miss, not a crash.
        final index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) return null;
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }
}
