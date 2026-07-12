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
import 'extension_service.dart';

class DataFileManager {
  final LookupRepository lookups;
  final ExtensionService extensions;
  final SharedPreferences prefs;

  DataFileManager({
    required this.lookups,
    required this.extensions,
    required this.prefs,
  });

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

  /// Downloads the file at [url] and returns the HTTP body string or throws.
  /// Uses ETag cached in [prefs] to avoid duplicate downloads, unless
  /// [force] skips sending it — a manual reload wants a full reprocess
  /// even when the server would otherwise report the content unchanged.
  Future<String?> downloadFile(String key, String url, {bool force = false}) async {
    final resolvedUrl = _resolveFetchUrl(resolveDownloadUrl(url));
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(resolvedUrl));
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
    return response.body;
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
    } catch (e) {
      debugPrint('[data-file] failed to fetch definitions: $e');
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
      }
    }));
    return matched;
  }

  /// Natively parses and processes a data file based on its `fetchType`.
  Future<void> processDataFile(String key, Map<String, dynamic> def, {bool force = false}) async {
    final url = def['url'] as String;
    final fetchType = def['fetchType'] as String;

    final body = await downloadFile(key, url, force: force);
    if (body == null) {
      // Unchanged 304.
      return;
    }

    if (fetchType == 'csv') {
      await _processCsv(key, def, body);
    } else if (fetchType == 'json') {
      await _processJson(key, def, body);
    } else if (fetchType == 'raw') {
      await _processRaw(key, def, body);
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

    await _batchWriteToDatabase(key, category, 'mapCsvBatch', 'rows', parsedRows);
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

    await _batchWriteToDatabase(key, category, 'mapJsonBatch', 'entries', entriesToProcess);
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
  }

  /// Triggers loading cached raw files at startup/activation.
  Future<void> loadRawDataFiles() async {
    if (kIsWeb) return;
    final host = extensions.host;
    if (host == null) return;

    final List<dynamic> entries;
    try {
      entries = await host.invokeHookAll('dataFile', method: 'getDefinition');
    } catch (e) {
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
            } catch (e) {
              debugPrint('[data-file] Error loading raw cache file $key: $e');
            }
          }
        }
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
    String mappingMethod,
    String mappingArgKey,
    List<dynamic> items,
  ) async {
    final host = extensions.host;
    if (host == null) return;

    final updatedFlag = DateTime.now().millisecondsSinceEpoch;
    final chunkSize = 5000;

    for (var start = 0; start < items.length; start += chunkSize) {
      final end = start + chunkSize < items.length ? start + chunkSize : items.length;
      final chunk = items.sublist(start, end);

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
        }
      }
    }

    // Clean up any stale records not updated in this run
    await lookups.deleteCategoryStale(category, updatedFlag);
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
