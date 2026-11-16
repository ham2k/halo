// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The pure half of the data-file pipeline: what turns a downloaded body into
// the rows an extension's mapper receives, and what a log line may say about
// where it came from.
//
// This lives in core because BOTH hosts run it — the app's DataFileManager and
// the CLI's DataFileSync — and the whole value of the CLI is that it reports
// what the app actually does. A second copy diverges silently: the two
// redaction helpers already had, one cutting the query off the string and the
// other rebuilding through `Uri.replace(query: '')` and leaving a stray `?`.
//
// Everything host-specific stays with its host: scheduling, max-age, ETag/304
// caching, the status bar and error notices are the app's; the one-shot "get
// it now" flow is the CLI's. Nothing here does I/O.

import 'dart:convert';
import 'dart:io' show ContentType;

import 'app_clock.dart';
import 'db/database.dart';
import 'dev_log.dart';
import 'repo/lookup_repository.dart';

/// The encoding to decode a data file with, resolved by precedence:
/// the definition's [defEncoding] wins (it overrides a wrong/missing server
/// header), else the `charset` from the response's Content-Type
/// [contentTypeHeader], else null — [decodeDataFileBody] then defaults to
/// UTF-8. This replaces `http.Response.body`, which silently defaults a
/// charset-less response to latin1 and so garbles UTF-8 park names.
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
/// replaced (U+FFFD), never thrown, so one bad byte can't fail a 181k-row file.
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
      // An encoding nothing here handles means the definition or the server is
      // wrong, and the fallback quietly garbles anything non-ASCII — worth a
      // dev's attention, but not worth printing from a release build or from
      // a CLI run whose stdout is JSON.
      DevLog.instance.log('data-file', {'unknownEncoding': encoding, 'decodedAs': 'utf-8'});
      return utf8.decode(bytes, allowMalformed: true);
  }
}

/// Splits one CSV line into fields, honoring `""` escapes inside quoted
/// fields. A quoted [delimiter] stays part of its field, which is what keeps a
/// park named `Smith, John State Park` in one piece.
List<String> parseCsvRow(String line, String delimiter) {
  final fields = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == delimiter && !inQuotes) {
      fields.add(field.toString());
      field.clear();
    } else {
      field.write(char);
    }
  }
  fields.add(field.toString());
  return fields;
}

/// Walks a dotted `rootPath` into a decoded JSON payload. A numeric segment
/// indexes a list, so a payload that wraps its rows in a positional envelope
/// is reachable — ECA and ELA publish `[meta, meta, {data: […]}]`, i.e.
/// rootPath `2.data`. A non-numeric or out-of-range segment is a miss, not a
/// crash. A null or empty [path] returns [value] untouched.
Object? resolveRootPath(Object? value, String? path) {
  if (path == null || path.isEmpty) return value;
  Object? current = value;
  for (final part in path.split('.')) {
    if (current is Map) {
      current = current[part];
    } else if (current is List) {
      final index = int.tryParse(part);
      if (index == null || index < 0 || index >= current.length) return null;
      current = current[index];
    } else {
      return null;
    }
  }
  return current;
}

/// A data-file URL reduced to what a log line may carry.
///
/// Some award programs take their API key as a query parameter — TOTA's list
/// is `tower.php?key=<secret>` — and the key is a real secret, not a public
/// token. Logging the URL whole would put it in the device log on every
/// refresh, and `debugPrint` is not stripped from release builds. Nothing
/// downstream needs the query to identify which file was fetched: the key and
/// the host already say that.
String redactUrlForLog(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return '(unparseable url)';
  // Cut the string rather than rebuilding through Uri: `replace(query: '')`
  // leaves the empty `?` and `#` markers behind.
  final cut = url.indexOf(RegExp(r'[?#]'));
  return cut < 0 ? url : '${url.substring(0, cut)}?…';
}

/// The smallest share of a category's stored rows an unforced import may
/// replace them with. A body that maps to far fewer rows than the last good
/// import — an error page served as a 200, a file caught mid-regeneration —
/// would otherwise reach the stale sweep and delete everything it did not
/// restamp; in the app the file is then stamped fresh with its ETag stored, so
/// the loss lasts at least maxAgeInDays, and past it for as long as the server
/// keeps serving that same body. A forced import (an explicit refresh,
/// `halo-ext data-files sync --force`) goes through regardless, which is how a
/// source that genuinely shrinks this far is accepted.
const minDataFileImportShare = 0.3;

/// An import that mapped fewer than [minDataFileImportShare] of the rows its
/// category already held. Unforced, it is thrown before the stale sweep and
/// the rows the import did not restamp are kept; [forced], it went through and
/// is only reported, so the rate counts accepted shrinks as well.
class DataFileImportShrank implements Exception {
  const DataFileImportShrank(this.key, {required this.imported, required this.existing, this.forced = false});

  final String key;
  final int imported;
  final int existing;
  final bool forced;

  @override
  String toString() => 'DataFileImportShrank: $key mapped $imported rows where $existing were stored${forced ? ' (forced through)' : ''}';
}

/// The [DataFileImportShrank] an import of [imported] rows over [existing]
/// stored ones amounts to, or null when it keeps at least
/// [minDataFileImportShare] of them. Both hosts ask after writing and BEFORE
/// the stale sweep, the step that deletes the rows an import did not restamp.
DataFileImportShrank? dataFileImportShrinkage(String key, {required int imported, required int existing, bool forced = false}) =>
    imported < existing * minDataFileImportShare ? DataFileImportShrank(key, imported: imported, existing: existing, forced: forced) : null;

/// One import replacing [category]'s rows, written as they arrive: every
/// import that replaces a category, in either host, ends here, so the shrink
/// guard and the stale sweep are one piece of code (a ham2k delta changes
/// rows in place and sweeps nothing). [start] counts what the category holds; [write]
/// adds rows, each stamped [updated]; [finish] sweeps the rows this import
/// did not write, unless it brought far fewer than the category held
/// ([dataFileImportShrinkage]), which throws unless [force]d — before the
/// sweep, or a short file would empty the category. A forced shrink goes
/// through, and is answered for the host to report.
///
/// An import that fails before [finish] leaves what it wrote, each row
/// replacing its own key, and sweeps nothing: the next one redoes the file.
class CategoryRowsWriter {
  CategoryRowsWriter._(this._lookups, this.key, this.category, this._existing, {required this.updated, required this.force});

  /// [updated] defaults to now; a host that built its rows before starting
  /// passes the stamp they carry instead.
  /// [existing] is the category's count when the host has just taken it.
  static Future<CategoryRowsWriter> start(
    LookupRepository lookups, {
    required String key,
    required String category,
    required bool force,
    int? updated,
    int? existing,
  }) async => CategoryRowsWriter._(lookups, key, category, existing ?? await lookups.countCategory(category), updated: updated ?? nowMillis(), force: force);

  final LookupRepository _lookups;
  final String key;
  final String category;
  final int _existing;

  /// The stamp every row of this import carries: [finish] sweeps the rest.
  final int updated;
  final bool force;

  /// The rows written so far.
  int get written => _written;
  var _written = 0;

  /// Every row must be [category]'s and carry [updated]: one stamped
  /// otherwise counts toward the guard and is then swept by [finish], so the
  /// import would delete what it just wrote.
  Future<void> write(List<LookupRow> rows) async {
    if (rows.isEmpty) return;
    for (final row in rows) {
      if (row.category != category || row.updated != updated) {
        throw StateError('$key: a row for ${row.category} stamped ${row.updated} written to $category stamped $updated');
      }
    }
    await _lookups.insertLookupBatch(rows);
    _written += rows.length;
  }

  /// [beforeSweep] runs once the guard has let the import through, before
  /// the sweep deletes anything.
  Future<DataFileImportShrank?> finish({Future<void> Function()? beforeSweep}) async {
    final shrank = dataFileImportShrinkage(key, imported: _written, existing: _existing, forced: force);
    if (shrank != null && !force) throw shrank;
    await beforeSweep?.call();
    await _lookups.deleteCategoryStale(category, updated);
    return shrank;
  }
}

/// [CategoryRowsWriter] for rows already in hand, all stamped [updated],
/// written [batchSize] at a time. [onRows] hears the count written so far.
Future<DataFileImportShrank?> replaceCategoryRows(
  LookupRepository lookups,
  String key,
  String category,
  List<LookupRow> rows, {
  required int updated,
  required bool force,
  void Function(int written)? onRows,
  int batchSize = 5000,
}) async {
  final writer = await CategoryRowsWriter.start(lookups, key: key, category: category, force: force, updated: updated);
  for (var start = 0; start < rows.length; start += batchSize) {
    final end = start + batchSize < rows.length ? start + batchSize : rows.length;
    await writer.write(rows.sublist(start, end));
    onRows?.call(end);
  }
  return writer.finish();
}

/// The rows a data-file mapper answered (`dataFileMapCsvBatch`,
/// `dataFileMapJsonBatch`), as [category]'s, stamped [updated]. An entry
/// that is not an object, or has no `key`, names no row and is skipped; a
/// field of the wrong kind — a `key`, `name` or `subCategory` that is not
/// text, `flags` that is not an integer — throws, failing the import: a
/// mapper that writes its keys as numbers would otherwise import nothing and
/// look fine.
List<LookupRow> lookupRowsFromMapped(List<dynamic> mapped, {required String category, required int updated}) {
  final rows = <LookupRow>[];
  for (final item in mapped) {
    if (item is! Map) continue;
    final key = item['key'] as String?;
    if (key == null) continue;
    rows.add(
      LookupRow(
        category: category,
        subCategory: item['subCategory'] as String?,
        key: key,
        name: item['name'] as String?,
        lat: (item['lat'] as num?)?.toDouble(),
        lon: (item['lon'] as num?)?.toDouble(),
        flags: item['flags'] as int?,
        data: item['data'] != null ? jsonEncode(item['data']) : null,
        updated: updated,
      ),
    );
  }
  return rows;
}

final _dataFileKeyPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,127}$');

/// Whether [key] may name a data file registered by [extensionKey]: the
/// extension's own key, or that key followed by `-` or `_` and more, in
/// lowercase letters, digits, `-` and `_`.
///
/// Both hosts name the raw cache file after the key (`<key>.json`), so a key
/// that is not this shape is a path: `../../x` writes, reads and deletes files
/// outside the cache folder. And a key outside the extension's own namespace
/// would read and replace another extension's cached data. A definition that
/// fails this is dropped before any path is built from it.
bool dataFileKeyOwnedBy(String? key, String? extensionKey) {
  if (key == null || extensionKey == null || extensionKey.isEmpty) return false;
  if (!_dataFileKeyPattern.hasMatch(key)) return false;
  return key == extensionKey || key.startsWith('$extensionKey-') || key.startsWith('${extensionKey}_');
}
