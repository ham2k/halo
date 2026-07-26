// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/user_agent.dart';
import '../i18n/strings.g.dart';
import 'error_reporting_service.dart';
import 'extension_service.dart';
import 'status_bar_service.dart';

/// The encoding to decode a data file with, resolved by precedence (#317):
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
/// Unknown/unsupported encodings fall back to UTF-8. See #317.
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
  });

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
    return [
      for (final entry in entries)
        if (entry is Map && entry['ok'] == true && entry['value'] != null)
          Map<String, dynamic>.from(entry['value'] as Map),
    ];
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
    return null;
  }

  /// Resolves direct URLs from sharing links for known file sharing systems.
  String resolveDownloadUrl(String url) {
    var u = url.trim();
    if (u.contains('dropbox.com/')) {
      u = u.replaceAll(RegExp(r'[&?]raw=\d'), '').replaceAll(RegExp(r'[&?]dl=\d'), '');
      u = u.contains('?') ? '$u&dl=1&raw=1' : '$u?dl=1&raw=1';
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
      };
      if (allowedDomains.contains(uri.host)) {
        return 'https://services.ham2k.net/${uri.host}${uri.path}${uri.hasQuery ? "?${uri.query}" : ""}';
      }
    }
    return urlString;
  }

  /// Downloads the file at [url] and returns the decoded body string, or null
  /// on a 304, or throws. Decoded per [resolveDataFileEncoding]: the
  /// definition's [encoding] overrides the response's Content-Type charset,
  /// which is otherwise honored, defaulting to UTF-8 — NOT `http.Response.body`,
  /// which defaults a charset-less response to latin1 and so garbled UTF-8 park
  /// names (#317). Uses ETag cached in [prefs] to avoid duplicate downloads,
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

    debugPrint('[data-file] Fetching $key from $resolvedUrl (cached ETag: $cachedEtag)');
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
  Future<int> syncAllDataFiles({bool force = false, String? categoryFilter}) async {
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
          await processDataFile(key, def, force: force);
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
  Future<void> processDataFile(String key, Map<String, dynamic> def, {bool force = false}) async {
    final url = def['url'] as String;
    final fetchType = def['fetchType'] as String;
    final label = _labelFor(key, def);
    final statusKey = 'dataFile:$key';

    statusBar?.setProgress(key: statusKey, title: label, text: t.dataFiles.downloading);
    try {
      final body = await downloadFile(key, url, force: force, encoding: def['encoding'] as String?);
      if (body == null) {
        // Unchanged 304.
        statusBar?.clear(statusKey);
        return;
      }

      if (fetchType == 'csv') {
        await _processCsv(key, def, body);
      } else if (fetchType == 'json') {
        await _processJson(key, def, body);
      } else if (fetchType == 'raw') {
        await _processRaw(key, def, body);
      }
    } catch (e) {
      statusBar?.clear(statusKey);
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
    final lines = const LineSplitter().convert(body);
    final parsedRows = <dynamic>[];
    List<String>? headers;

    for (var i = 0; i < lines.length; i++) {
      if (i < skipRows) continue;
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parsed = parseCsvRow(line, delimiter);
      if (hasHeaders) {
        if (headers == null) {
          headers = parsed;
        } else {
          final rowMap = <String, String>{};
          for (var j = 0; j < headers.length && j < parsed.length; j++) {
            rowMap[headers[j]] = parsed[j];
          }
          parsedRows.add(rowMap);
        }
      } else {
        parsedRows.add(parsed);
      }
    }

    await _batchWriteToDatabase(key, category, _labelFor(key, def), 'mapCsvBatch', 'rows', parsedRows);
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
    List<dynamic> items,
  ) async {
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
      final dynamic response = await host.invokeHook(
        'dataFile',
        key: key,
        method: mappingMethod,
        args: {mappingArgKey: chunk},
      );

      if (response is List) {
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
      } else {
        return null;
      }
    }
    return current;
  }
}
