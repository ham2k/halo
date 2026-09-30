// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Downloading the offline reference datasets (park lists, summit lists,
// callsign notes) and importing them through each extension's own mapper.
//
// This is the app's DataFileManager pipeline reduced to what a one-shot
// command needs: fetch, map in chunks, write rows, sweep what this run did
// not stamp — unless the run mapped far fewer rows than the cache holds (the
// guard both hosts share, dataFileImportShrinkage). Left out on purpose,
// because they are the APP's concerns and none of them changes what a row
// ends up containing: scheduling and max-age, ETag/304 caching (a CLI sync
// is always an explicit "get it now"), the status bar, and error notices.
//
// What DOES change what a row contains — charset resolution, CSV field
// splitting, the rootPath walk, log redaction — is not reimplemented here.
// It lives in halo_core's data_file_parsing.dart, which both hosts call, so
// the CLI cannot report behavior the app does not have.
//
// The chunking protocol is NOT a simplification and must not become one.
// Rows cross the bridge POSITIONALLY with the header row sent once per chunk,
// and the kernel zips them back into the `Record<string,string>` that
// `csvToLookupEntry` is declared to take. Building those maps on this side
// would be ~61% redundant bytes on SOTA's 181k-row file — and, worse, would
// silently diverge from what the app hands the same mapper.

import 'dart:convert';
import 'dart:io';

import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show HookCalls;
import 'package:http/http.dart' as http;

import 'lookup_store.dart';
import 'runtime.dart';

/// One `dataFile` registration, as its extension described it.
class DataFileDef {
  final String key;
  final String extensionKey;
  final Map<String, Object?> raw;

  DataFileDef({required this.key, required this.extensionKey, required this.raw});

  String get name => raw['name'] is String ? raw['name'] as String : key;
  String get category => raw['category'] is String ? raw['category'] as String : key;
  String? get url => raw['url'] as String?;
  String get fetchType => raw['fetchType'] as String? ?? 'csv';
}

/// The outcome of importing one file, for the command's JSON output.
class DataFileResult {
  final String key;
  final String? category;
  final int rows;
  final String? error;

  /// A raw file's parsed payload is cached whole rather than turned into
  /// lookup rows, so `rows: 0` would read as "nothing imported" for a file
  /// that imported fine. Raw results say `entries` and where the cache went.
  final String? cachedAt;
  final int? entries;

  /// The import mapped too few rows to replace the cache and was refused;
  /// [rows] is what it wrote before refusing, which stays.
  final bool refused;

  DataFileResult({required this.key, this.category, this.rows = 0, this.error, this.cachedAt, this.entries, this.refused = false});

  Map<String, Object?> toJson() => {
    'key': key,
    if (category != null) 'category': category,
    if (cachedAt != null) ...{'kind': 'raw', 'entries': entries, 'cachedAt': cachedAt} else 'rows': rows,
    if (refused) 'refused': true,
    if (error != null) 'error': error,
  };
}

class DataFileSync {
  final ExtRuntime runtime;
  final LookupStore store;
  final String userAgent;
  final bool verbose;

  /// Accept an import however small next to what the cache holds — the app's
  /// explicit refresh. Without it a short body is refused, not swept in.
  final bool force;

  /// Rows per bridge crossing. The app's number, kept: it is the one these
  /// mappers have been run at, and both the JSON size and the per-call
  /// timeout are tuned around it.
  static const chunkSize = 5000;

  DataFileSync({required this.runtime, required this.store, required this.userAgent, this.verbose = false, this.force = false});

  /// Every registered data file, in registration order.
  Future<List<DataFileDef>> definitions() async {
    final entries = await runtime.host.invokeAll(Hooks.dataFileGetDefinition);
    final defs = <DataFileDef>[];
    for (final entry in entries) {
      if (entry['ok'] != true || entry['value'] is! Map) continue;
      final value = (entry['value'] as Map).cast<String, Object?>();
      final key = value['key'] as String?;
      if (key == null) continue;
      defs.add(DataFileDef(key: key, extensionKey: entry['key'] as String? ?? key, raw: value));
    }
    return defs;
  }

  Future<DataFileResult> import(DataFileDef def) async {
    final url = def.url;
    if (url == null) return DataFileResult(key: def.key, error: 'definition has no url');
    try {
      return await importBody(def, await _download(url, encoding: def.raw['encoding'] as String?));
    } catch (e) {
      return DataFileResult(key: def.key, error: '$e');
    }
  }

  /// [import] after the download: maps [body] and writes it. Public so a test
  /// can feed a body without a server.
  Future<DataFileResult> importBody(DataFileDef def, String body) async {
    try {
      switch (def.fetchType) {
        case 'csv':
          return await _importCsv(def, body);
        case 'json':
          return await _importJson(def, body);
        case 'raw':
          return await _importRaw(def, body);
        default:
          return DataFileResult(key: def.key, error: 'unknown fetchType "${def.fetchType}"');
      }
    } on DataFileImportShrank catch (e) {
      return DataFileResult(key: def.key, category: def.category, rows: e.imported, refused: true, error: '$e (--force accepts it)');
    }
  }

  Future<String> _download(String url, {String? encoding}) async {
    if (verbose) stderr.writeln('[data-file] GET ${redactUrlForLog(url)}');
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': userAgent});
    if (response.statusCode != 200) {
      throw StateError('HTTP ${response.statusCode} from ${redactUrlForLog(url)}');
    }
    return decodeDataFileBody(response.bodyBytes, encoding: resolveDataFileEncoding(encoding, response.headers['content-type']));
  }

  Future<DataFileResult> _importCsv(DataFileDef def, String body) async {
    final options = (def.raw['csvOptions'] as Map?) ?? const {};
    final hasHeaders = options['hasHeaders'] as bool? ?? true;
    final skipRows = options['skipRows'] as int? ?? 0;
    final delimiter = options['delimiter'] as String? ?? ',';

    final rows = <Object?>[];
    List<String>? headers;
    final lines = const LineSplitter().convert(body);
    for (var i = 0; i < lines.length; i++) {
      if (i < skipRows) continue;
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parsed = parseCsvRow(line, delimiter);
      if (hasHeaders && headers == null) {
        headers = parsed;
        continue;
      }
      rows.add(parsed);
    }

    return _mapAndWrite(def, Hooks.dataFileMapCsvBatch, 'rows', rows, extraArgs: headers == null ? null : {'headers': headers});
  }

  Future<DataFileResult> _importJson(DataFileDef def, String body) async {
    final options = (def.raw['jsonOptions'] as Map?) ?? const {};
    final target = resolveRootPath(jsonDecode(body), options['rootPath'] as String?);
    final entries = <Object?>[];
    if (target is List) {
      entries.addAll(target);
    } else if (target is Map) {
      target.forEach((key, value) => entries.add({'key': key, 'value': value}));
    } else {
      throw const FormatException('resolved rootPath is neither an array nor an object');
    }
    return _mapAndWrite(def, Hooks.dataFileMapJsonBatch, 'entries', entries);
  }

  /// Where a raw file's parsed JSON is cached. Keyed by data-file key, which
  /// is also the hook key [replayRawDataFiles] calls back with.
  static String rawCacheDir(LookupStore store) => '${store.file.parent.path}/data-files';

  /// Replays every cached raw data file into a freshly booted runtime.
  ///
  /// Raw files never become lookup rows — the extension keeps the parsed
  /// shape in its own module state, which dies with the process. Without this
  /// the callsign notes exist only during the `data-files sync` run that
  /// downloaded them, while `data-files list` reports the file as present:
  /// the app avoids that with DataFileManager.loadRawDataFiles() at startup,
  /// and this is its counterpart.
  ///
  /// Keyed off the FILES on disk rather than off the registered definitions,
  /// so it costs one cheap directory read on a machine that has never synced
  /// a raw file — the common case — instead of a getDefinition fan-out on
  /// every single invocation.
  static Future<List<String>> replayRawDataFiles(ExtRuntime runtime, LookupStore store) async {
    final dir = Directory(rawCacheDir(store));
    if (!dir.existsSync()) return const [];
    final replayed = <String>[];
    for (final entry in dir.listSync()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      final key = entry.uri.pathSegments.last.replaceAll(RegExp(r'\.json$'), '');
      try {
        await runtime.host.invoke(Hooks.dataFileOnLoadRawData, key: key, args: jsonDecode(entry.readAsStringSync()), timeout: const Duration(seconds: 30));
        replayed.add(key);
      } catch (e) {
        // The extension that owns this file may simply not be loaded (a
        // --only run), which is not a failure of the command the operator
        // actually asked for.
        stderr.writeln('halo-ext: could not replay cached data file $key: $e');
      }
    }
    return replayed;
  }

  /// A raw file is parsed by its own extension into whatever shape that
  /// extension keeps, cached as JSON, and replayed into the runtime — it
  /// never becomes lookup rows. call-notes is the one doing this.
  Future<DataFileResult> _importRaw(DataFileDef def, String body) async {
    final processed = await runtime.host.invoke(
      Hooks.dataFileRawToJsonData,
      key: def.key,
      args: {'body': body, 'url': def.url, 'options': const <String, dynamic>{}},
      timeout: const Duration(seconds: 60),
    );
    final cache = File('${rawCacheDir(store)}/${def.key}.json')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(processed));
    await runtime.host.invoke(Hooks.dataFileOnLoadRawData, key: def.key, args: processed, timeout: const Duration(seconds: 60));
    return DataFileResult(
      key: def.key,
      cachedAt: cache.path,
      entries: switch (processed) {
        final List<dynamic> list => list.length,
        final Map<dynamic, dynamic> map => map.length,
        _ => null,
      },
    );
  }

  Future<DataFileResult> _mapAndWrite(DataFileDef def, HookRef mapping, String argKey, List<Object?> items, {Map<String, Object?>? extraArgs}) async {
    // Stamps every row this run touches, so the sweep below can delete
    // exactly what the source dropped.
    final updatedFlag = nowMillis();
    final existing = await store.repository.countCategory(def.category);
    var imported = 0;

    for (var start = 0; start < items.length; start += chunkSize) {
      final end = start + chunkSize < items.length ? start + chunkSize : items.length;
      if (verbose) stderr.writeln('[data-file] ${def.key}: mapping $end/${items.length}');
      final mapped = await runtime.host.invoke(
        mapping,
        key: def.key,
        args: {argKey: items.sublist(start, end), ...?extraArgs},
        // A 5000-row chunk against a single-threaded engine; the default 10s
        // is a per-CALL budget, not a per-row one.
        timeout: const Duration(seconds: 60),
      );
      if (mapped is! List) {
        // Bailing out protects what is already imported: carrying on to the
        // sweep with nothing imported would delete the whole category.
        throw StateError(
          '${mapping.method} returned ${mapped.runtimeType}, not a list — '
          'dropped rows $start..$end of ${items.length}',
        );
      }

      final rows = <LookupRow>[];
      for (final item in mapped) {
        if (item is! Map) continue;
        final key = item['key'] as String?;
        if (key == null) continue;
        rows.add(
          LookupRow(
            category: def.category,
            subCategory: item['subCategory'] as String?,
            key: key,
            name: item['name'] as String?,
            lat: (item['lat'] as num?)?.toDouble(),
            lon: (item['lon'] as num?)?.toDouble(),
            flags: item['flags'] as int?,
            data: item['data'] != null ? jsonEncode(item['data']) : null,
            updated: updatedFlag,
          ),
        );
      }
      if (rows.isNotEmpty) {
        await store.repository.insertLookupBatch(rows);
        imported += rows.length;
      }
    }

    final shrank = dataFileImportShrinkage(def.key, imported: imported, existing: existing, forced: force);
    if (shrank != null) {
      if (!force) throw shrank;
      stderr.writeln('halo-ext: $shrank');
    }
    await store.repository.deleteCategoryStale(def.category, updatedFlag);
    return DataFileResult(key: def.key, category: def.category, rows: imported);
  }
}
