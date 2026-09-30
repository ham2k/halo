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

import 'dev_log.dart';

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
