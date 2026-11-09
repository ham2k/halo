// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `ham2k` data file: a Ham2K service's versioned dataset. The snapshot at
// `url` is NDJSON, one record per line; `deltaUrl` (with `{since}` standing
// for the version held) answers `{added, changed, removed}` from that
// version, or 410 when it can't. Both name the version they bring the device
// to in `X-Lookups-Version`. The records are already clean, so a row comes
// from the definition's `fields` and never crosses into an extension.
//
// Shared by the app's DataFileManager and halo_cli's data-files command, so
// the two hosts cannot disagree about what a row contains. Fetching (timeouts,
// proxies, error wording) and where the version is kept are each host's own.

import 'dart:async';
import 'dart:convert';

import 'app_clock.dart';
import 'data_file_parsing.dart';
import 'db/database.dart';
import 'repo/lookup_repository.dart';

/// The header both answers name their version in.
const ham2kVersionHeader = 'x-lookups-version';

/// One answer from a `ham2k` server: its status, the version it names, and
/// the body, read as it arrives.
class Ham2kResponse {
  final int status;
  final String? version;
  final Stream<List<int>> body;

  Ham2kResponse({required this.status, required this.version, required this.body});
}

/// Fetches [url]. A status other than 200 — or 410 where [goneIsAnswer] — is
/// the host's to throw as its own error.
typedef Ham2kFetch = Future<Ham2kResponse> Function(Uri url, {required bool goneIsAnswer});

/// Which record fields fill a lookup row's columns.
class Ham2kFields {
  final String key;
  final String? name;
  final String? lat;
  final String? lon;
  final String? subCategory;
  final String? flags;

  const Ham2kFields({required this.key, this.name, this.lat, this.lon, this.subCategory, this.flags});

  /// From a definition's `fields`, or null when it names no `key`.
  static Ham2kFields? fromDefinition(Object? fields) {
    if (fields is! Map || fields['key'] is! String) return null;
    String? field(String name) => fields[name] is String ? fields[name] as String : null;
    return Ham2kFields(
      key: fields['key'] as String,
      name: field('name'),
      lat: field('lat'),
      lon: field('lon'),
      subCategory: field('subCategory'),
      flags: field('flags'),
    );
  }

  /// [record]'s row, or null for one with no string key. [json] is the
  /// record's own text when the caller has it, kept as `data` unchanged.
  LookupRow? row(Map<String, dynamic> record, {required String category, required int updated, String? json}) {
    final key = record[this.key];
    if (key is! String || key.isEmpty) return null;
    T? typed<T>(String? field) => field != null && record[field] is T ? record[field] as T : null;
    return LookupRow(
      category: category,
      subCategory: typed<String>(subCategory),
      key: key,
      name: typed<String>(name),
      lat: typed<num>(lat)?.toDouble(),
      lon: typed<num>(lon)?.toDouble(),
      flags: typed<int>(flags),
      data: json ?? jsonEncode(record),
      updated: updated,
    );
  }
}

enum Ham2kSyncKind { snapshot, delta, unchanged }

class Ham2kSyncResult {
  final Ham2kSyncKind kind;

  /// The version the category now holds, or null when the server named none
  /// (the next sync then takes the snapshot again).
  final String? version;

  /// Records written: a snapshot's rows, or a delta's added and changed ones.
  final int rows;

  /// A forced snapshot that shrank the category past the guard went through;
  /// this is the host's to report, as for any other data file.
  final DataFileImportShrank? forcedShrink;

  Ham2kSyncResult(this.kind, this.version, this.rows, {this.forcedShrink});
}

/// Brings [category] from [heldVersion] to the server's latest: a delta when
/// a version is held, the category holds rows and [snapshot] is not asked
/// for; the snapshot otherwise, or when the server can't answer the delta.
/// [onRows] hears the running count while a snapshot imports.
///
/// A snapshot replaces the category: rows it did not write are swept, unless
/// it wrote far fewer than the category holds and [force] is off
/// ([dataFileImportShrinkage]). A delta writes and deletes in one transaction.
///
/// [onSnapshotWrites] runs before a snapshot's first write: from there until
/// it returns, the category is at no version, and the host must stop holding
/// one. Every failure before it leaves the category as it was, so a host
/// keeps its version through a failed fetch or delta and asks for a delta
/// again rather than the whole snapshot.
Future<Ham2kSyncResult> syncHam2kDataFile({
  required String key,
  required String category,
  required String url,
  required String? deltaUrl,
  required Ham2kFields fields,
  required String? heldVersion,
  required bool snapshot,
  required bool force,
  required Ham2kFetch fetch,
  required LookupRepository lookups,
  required Future<void> Function() onSnapshotWrites,
  void Function(int rows)? onRows,
  int batchSize = 5000,
}) async {
  final existing = await lookups.countCategory(category);
  // An empty category is at no version whatever the host holds (a purge, an
  // extension that moved its category): a delta would leave it holding only
  // the day's changes.
  if (!snapshot && heldVersion != null && deltaUrl != null && existing > 0) {
    final response = await fetch(Uri.parse(deltaUrl.replaceAll('{since}', Uri.encodeQueryComponent(heldVersion))), goneIsAnswer: true);
    if (response.status == 200) {
      if (response.version == heldVersion) {
        await response.body.drain<void>();
        return Ham2kSyncResult(Ham2kSyncKind.unchanged, heldVersion, 0);
      }
      final delta = jsonDecode(await utf8.decodeStream(response.body));
      if (delta is! Map) throw FormatException('$key: a delta is not an object');
      final updated = nowMillis();
      final upserts = <LookupRow>[
        for (final list in [delta['added'], delta['changed']])
          if (list is List)
            for (final record in list)
              if (record is Map<String, dynamic>) ?fields.row(record, category: category, updated: updated),
      ];
      final removed = [
        if (delta['removed'] case final List<dynamic> list)
          for (final key in list)
            if (key is String) key,
      ];
      await lookups.applyLookupChanges(category, upserts, removed);
      return Ham2kSyncResult(Ham2kSyncKind.delta, response.version, upserts.length);
    }
    await response.body.drain<void>();
  }

  final response = await fetch(Uri.parse(url), goneIsAnswer: false);
  final updated = nowMillis();
  var imported = 0;
  var batch = <LookupRow>[];
  Future<void> flush() async {
    if (batch.isEmpty) return;
    if (imported == 0) await onSnapshotWrites();
    await lookups.insertLookupBatch(batch);
    imported += batch.length;
    batch = [];
    onRows?.call(imported);
  }

  await for (final line in response.body.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) continue;
    final Object? record;
    try {
      record = jsonDecode(line);
    } on FormatException {
      continue;
    }
    if (record is! Map<String, dynamic>) continue;
    final row = fields.row(record, category: category, updated: updated, json: line);
    if (row == null) continue;
    batch.add(row);
    if (batch.length >= batchSize) await flush();
  }
  await flush();

  final shrank = dataFileImportShrinkage(key, imported: imported, existing: existing, forced: force);
  if (shrank != null && !force) throw shrank;
  // An empty snapshot's first write is this sweep.
  if (imported == 0) await onSnapshotWrites();
  await lookups.deleteCategoryStale(category, updated);
  return Ham2kSyncResult(Ham2kSyncKind.snapshot, response.version, imported, forcedShrink: shrank);
}
