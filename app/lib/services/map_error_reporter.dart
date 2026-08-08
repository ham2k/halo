// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every map backend's error funnel into ErrorReportingService, so map
// failures reach ErrorPolicy instead of dying in a console — without this
// funnel a blank map produces no evidence at all. The explicit report()
// path uploads but never raises the "Something went wrong" notice, so the
// ceiling here is console + backend by construction; the map pane's own
// overlay is the operator-facing surface.
//
// [MapError] is stamped with the device's connectivity at arrival —
// ErrorPolicy's `map-offline` rule quietens errors from an offline device
// (a field operation without coverage fails every tile and style fetch,
// and that is the normal state of a POTA activation, not a defect).

import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';
import 'error_reporting_service.dart';

/// A failure surfaced by one of the map backends. [offline] is the device's
/// connectivity when the error arrived, not when it is classified — an error
/// raised offline stays quiet even if the device is back online by the time
/// anyone looks at it.
@immutable
class MapError implements Exception {
  /// Which backend raised it: 'webview', 'web', 'native', or 'osm'.
  final String backend;

  /// Stable failure class within the backend (e.g. 'gl-error',
  /// 'style-timeout', 'tile-load') — the JS side's kinds pass through
  /// verbatim.
  final String kind;

  final String message;
  final bool offline;

  MapError({required this.backend, required this.kind, required this.message})
      : offline = ConnectivityService.isOffline;

  @visibleForTesting
  const MapError.raw({required this.backend, required this.kind, required this.message, required this.offline});

  @override
  String toString() => 'MapError($backend/$kind${offline ? ', offline' : ''}): $message';
}

/// Session-scoped throttle in front of [ErrorReportingService.report]: a map
/// error repeats — every pan retries the same tiles, every rebuild re-fails
/// the same style — and each repeat carries no new information, so only the
/// first occurrence of each (backend, kind, message) is reported, and each
/// (backend, kind) reports at most a handful of distinct messages (tile
/// errors online can vary only by URL, which would otherwise upload once per
/// tile). Repeats still print, so a developer watching the console sees the
/// error live, not just its first occurrence.
class MapErrorReporter {
  MapErrorReporter._();

  static final _seen = <String>{};
  static final _perKind = <String, int>{};

  /// Distinct messages reported per (backend, kind) per session.
  static const maxPerKind = 3;

  static void report({required String backend, required String kind, required String message, StackTrace? stack}) {
    final error = MapError(backend: backend, kind: kind, message: message);
    // The offline stamp is part of the key: an error first seen offline is
    // quiet (ErrorPolicy's map-offline rule) and must not consume the budget
    // of the same failure recurring online, where it is fresh evidence.
    final kindKey = '$backend/$kind/${error.offline}';
    // Cap first, and don't grow _seen past it: once a kind is capped no
    // entry can change a decision, and per-URL message variants would
    // otherwise accrete one string per failing tile all session. The
    // suppressed lines are debug-only — flutter_map and the webview console
    // already print their own line per failure, and release has no reader.
    if ((_perKind[kindKey] ?? 0) >= maxPerKind) {
      if (kDebugMode) debugPrint('[map-$backend] capped: $error');
      return;
    }
    if (!_seen.add('$kindKey/$message')) {
      if (kDebugMode) debugPrint('[map-$backend] repeat: $error');
      return;
    }
    _perKind[kindKey] = (_perKind[kindKey] ?? 0) + 1;
    ErrorReportingService.report(error, stack, context: 'map-$backend');
  }

  @visibleForTesting
  static void resetForTesting() {
    _seen.clear();
    _perKind.clear();
  }
}
