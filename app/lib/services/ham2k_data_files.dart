// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DataFileManager's path for a `ham2k` data file (see halo_core's
// ham2k_data_file.dart): a delta from the version held, or the snapshot when
// there is none, the server can't answer the delta, or the caller forces it
// (a Refresh tap, RELOAD, a heal). Rows come from the definition's `fields`,
// so the import never reaches the extension runtime, and a runtime restart
// cannot cut it.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOException;

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/user_agent.dart';
import 'data_file_errors.dart';
import 'error_reporting_service.dart';
import 'extensions/extension_requests.dart';
import 'status_bar_service.dart';

class Ham2kDataFiles {
  final LookupRepository lookups;
  final SharedPreferences prefs;
  final StatusBarService? statusBar;
  final ExtensionClientFactory httpClientFactory;

  /// What the extension a data file belongs to may have the app reach
  /// (ExtensionService.networkGrantFor): its URLs are the extension's.
  final ExtensionNetworkGrant Function(String? extensionKey) grantFor;
  final bool isWeb;
  final Duration headersTimeout;

  /// Where DataFileManager records a refused import, for the Data Files screen.
  final String Function(String key) refusedKey;

  /// Rows a failed snapshot had written are searchable; this says so.
  final VoidCallback onPartialImport;

  Ham2kDataFiles({
    required this.lookups,
    required this.prefs,
    required this.statusBar,
    required this.httpClientFactory,
    required this.grantFor,
    required this.isWeb,
    required this.headersTimeout,
    required this.refusedKey,
    required this.onPartialImport,
  });

  /// How long a body may go without a byte before the download counts as
  /// stalled. An idle ceiling, not a total one: a snapshot of a million
  /// records is tens of MB, which a slow link takes minutes to deliver while
  /// making steady progress.
  static const idleTimeout = Duration(seconds: 60);

  /// Syncs [key], the way DataFileManager.processDataFile does any data file:
  /// whether it ingested anything, notices raised on failure, rethrown.
  ///
  /// The version held is kept where an ETag is, prefixed, so every path that
  /// drops a key's ETag to force its next download drops this too. A failure
  /// keeps it unless a snapshot had started writing (`onSnapshotWrites`):
  /// a device that tried to sync offline asks for the delta again, not the
  /// whole snapshot.
  Future<bool> process(
    String key,
    Map<String, dynamic> def, {
    required String label,
    required bool force,
    required bool notifyOnFailure,
    required bool showProgress,
  }) async {
    final statusKey = 'dataFile:$key';
    final bar = statusBar;
    final versionKey = 'data_file_etag_$key';
    if (showProgress) bar?.setProgress(key: statusKey, title: label, text: t.dataFiles.downloading);
    final Ham2kSyncResult result;
    try {
      final url = def['url'];
      final fields = Ham2kFields.fromDefinition(def['fields']);
      if (url is! String || fields == null) throw FormatException('$key: a ham2k data file needs a url and fields.key');
      final held = prefs.getString(versionKey);
      result = await syncHam2kDataFile(
        key: key,
        category: def['category'] as String? ?? key,
        url: url,
        deltaUrl: def['deltaUrl'] as String?,
        fields: fields,
        heldVersion: held != null && held.startsWith('ham2k:') ? held.substring('ham2k:'.length) : null,
        snapshot: force,
        force: force,
        fetch: (url, {required goneIsAnswer}) => _fetch(key, url, grantFor(def['extensionKey'] as String?), goneIsAnswer: goneIsAnswer),
        lookups: lookups,
        onSnapshotWrites: () => prefs.remove(versionKey),
        onRows: showProgress
            ? (rows) => bar?.setProgress(
                key: statusKey,
                title: label,
                text: t.dataFiles.recordsSoFar(count: rows),
              )
            : null,
      );
    } catch (e, stack) {
      bar?.clear(statusKey);
      onPartialImport();
      // A failure to fetch reads as any data file's download failure, every
      // other as its processing failure, with the same notices. A connection
      // dropped mid-body reaches here as the platform's own IOException
      // (a SocketException on iOS and Android), unwrapped so ErrorPolicy's
      // network rules still see it.
      final fetchFailed = e is DataFileUnavailable || e is ExtensionUrlRefused || e is http.ClientException || e is IOException;
      if (e is DataFileImportShrank) await prefs.setString(refusedKey(key), jsonEncode({'imported': e.imported, 'existing': e.existing}));
      ErrorReportingService.report(
        e,
        stack,
        context: fetchFailed ? 'data-files:download' : 'data-files:import',
        notice: notifyOnFailure && bar != null
            ? ErrorNotice(
                bar,
                key: statusKey,
                title: fetchFailed ? t.dataFiles.downloadFailedTitle(name: label) : t.dataFiles.processingFailedTitle(name: label),
                text: fetchFailed
                    ? friendlyDownloadError(e, isWeb: isWeb)
                    : e is DataFileImportShrank
                    ? t.dataFiles.importTooSmall(imported: e.imported, existing: e.existing)
                    : null,
              )
            : null,
      );
      rethrow;
    }
    if (result.version != null) {
      await prefs.setString(versionKey, 'ham2k:${result.version}');
    } else {
      await prefs.remove(versionKey);
    }
    await prefs.remove(refusedKey(key));
    if (result.forcedShrink case final shrank?) {
      ErrorReportingService.report(shrank, StackTrace.current, context: 'data-files:forced-shrink');
    }
    final ingested = result.kind != Ham2kSyncKind.unchanged;
    if (!showProgress) {
      bar?.clear(statusKey);
    } else if (ingested) {
      bar?.setProgress(
        key: statusKey,
        title: label,
        text: t.dataFiles.importedRecords(count: result.rows, label: label),
        value: 1.0,
      );
    } else {
      bar?.setProgress(key: statusKey, title: label, text: t.dataFiles.upToDate, value: 1.0);
    }
    return ingested;
  }

  /// One request: [headersTimeout] for the answer, [idleTimeout] between body
  /// chunks, and the client closed once the body is read, abandoned or failed.
  Future<Ham2kResponse> _fetch(String key, Uri url, ExtensionNetworkGrant grant, {required bool goneIsAnswer}) async {
    debugPrint('[data-file] Fetching $key from ${redactUrlForLog(url.toString())}');
    final client = ExtensionClient(grant, dataFile: true, clients: httpClientFactory, onWeb: isWeb);
    final http.StreamedResponse response;
    try {
      final request = http.Request('GET', url)..headers['User-Agent'] = await ham2kUserAgent();
      response = await client.send(request).timeout(headersTimeout);
    } on TimeoutException {
      client.close();
      throw DataFileUnavailable.timedOut(key, url.host, DataFileWait.headers);
    } catch (_) {
      client.close();
      rethrow;
    }
    if (response.statusCode != 200 && !(goneIsAnswer && response.statusCode == 410)) {
      client.close();
      throw DataFileUnavailable.status(key, url.host, response.statusCode);
    }
    Stream<List<int>> body() async* {
      try {
        yield* response.stream.timeout(
          idleTimeout,
          onTimeout: (sink) {
            sink.addError(DataFileUnavailable.timedOut(key, url.host, DataFileWait.body));
            sink.close();
          },
        );
      } finally {
        client.close();
      }
    }

    return Ham2kResponse(status: response.statusCode, version: response.headers[ham2kVersionHeader], body: body());
  }
}
