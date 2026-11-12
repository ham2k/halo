// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Why a data file did not download, and how the notice words it. Shared by
// DataFileManager's paths (data_file_manager.dart re-exports it).

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:http/http.dart' as http;

import 'extensions/extension_requests.dart' show ExtensionUrlRefused;

/// The message shown in a download-failure notice. `package:http`'s
/// BrowserClient wraps every browser-level fetch failure (a cross-origin
/// download the browser refuses — one that would work from a native build
/// — but also a plain network outage) in a [http.ClientException]; that
/// class gets a plain-language hint appended, worded to cover both causes
/// rather than assuming it's specifically a CORS block. Check the TYPE,
/// never the message text: `'Failed to fetch'` is Chromium/V8's own wording
/// for the underlying `fetch()` TypeError, and Firefox and Safari phrase
/// the identical failure differently — a string match silently never fires
/// for them. A [DataFileUnavailable], [ExtensionUrlRefused] or
/// [N1mmCallHistoryUnavailable] gets its own translated sentence; every other failure (a malformed URL) is shown
/// as-is, since guessing at THOSE causes would be more likely to mislead than
/// help. [isWeb] defaults to
/// [kIsWeb] but is overridable — the constant itself isn't, so a test can't
/// flip platforms without this.
String friendlyDownloadError(Object error, {bool isWeb = kIsWeb}) {
  if (error is DataFileUnavailable) {
    // A 404 or 410 will not fix itself with time — most often a custom file's
    // address that is mistyped or no longer shared. Every other status is
    // told to wait: a 429, a 408 or a challenge's 403 clears on its own, and
    // a built-in source has no address for the operator to check.
    final status = error.statusCode;
    if (status == null) return t.dataFiles.downloadTimedOut;
    if (status == 404 || status == 410) return t.dataFiles.downloadNotAvailable(host: error.host, status: status);
    return t.dataFiles.downloadServerError(host: error.host, status: status);
  }
  if (error is ExtensionUrlRefused) return t.dataFiles.downloadRefused(host: error.url.host);
  if (error is N1mmCallHistoryUnavailable) {
    return error.noMatch ? t.dataFiles.n1mmHistoryNoMatch(stem: error.stem) : t.dataFiles.n1mmHistoryUnavailable(stem: error.stem);
  }
  final message = error.toString();
  if (isWeb && error is http.ClientException) {
    return '$message\n\n${t.dataFiles.downloadFailedWebHint}';
  }
  return message;
}

/// Which of a download's two ceilings ran out: `DataFileManager.headersTimeout`
/// (the host never answered) or `DataFileManager.bodyTimeout` (it answered,
/// then the body stalled or crawled).
enum DataFileWait { headers, body }

/// A data file's server did not deliver it: a [timedOut] wait, or an answer
/// ([statusCode]) other than 200 or 304 — exactly one of the two is set.
///
/// Its own type so the disposition is a rule rather than a catch site (see
/// `ErrorPolicy`), and so that rule can quieten a download's timeout without
/// quietening every bare `TimeoutException` in the app. [host] is the server
/// that failed to answer — on web, for a proxied source, the proxy.
class DataFileUnavailable implements Exception {
  const DataFileUnavailable.timedOut(this.key, this.host, DataFileWait this.timedOut) : statusCode = null;
  const DataFileUnavailable.status(this.key, this.host, int this.statusCode) : timedOut = null;

  final String key;
  final String host;
  final DataFileWait? timedOut;
  final int? statusCode;

  @override
  String toString() => statusCode != null
      ? 'DataFileUnavailable: $host answered HTTP $statusCode for $key'
      : 'DataFileUnavailable: $host timed out waiting for the ${timedOut!.name} of $key';
}
