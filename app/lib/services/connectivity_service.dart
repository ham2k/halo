// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app's one view of device connectivity: a single connectivity_plus
// subscription, exposing the current answer ("are we offline right now")
// and a broadcast stream of changes for anyone who needs the edges
// (DataFileManager's reconnect resync). Everything that cares about
// connectivity reads it from here — a second raw plugin subscription is a
// second platform channel doing the same work.
//
// Static like ErrorReportingService, and for the same reason: the readers
// are far from anything that could hand them an instance (ErrorPolicy
// stamps map errors with the offline flag from inside an error handler).
//
// [isOffline] starts false: until the first probe answers, errors must stay
// loud — "offline" quietens error reporting (see ErrorPolicy's map rule),
// so an optimistic default can only make noise, never hide a real failure.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();

  static bool _offline = false;
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static final _changes = StreamController<List<ConnectivityResult>>.broadcast();

  /// Whether the device currently has no network path at all — every
  /// reported interface is `none`. False until [start]'s first probe
  /// answers.
  static bool get isOffline => _offline;

  /// Connectivity emissions, [Connectivity.onConnectivityChanged]-shaped.
  /// Broadcast, so late subscribers get changes from subscription time on —
  /// pair with [isOffline] for the current state.
  static Stream<List<ConnectivityResult>> get changes => _changes.stream;

  /// Installs the plugin subscription and probes the current state. Idempotent.
  /// [changesSource] and [check] are test seams for the platform channel.
  static void start({
    Stream<List<ConnectivityResult>>? changesSource,
    Future<List<ConnectivityResult>> Function()? check,
  }) {
    if (_subscription != null) return;
    _subscription = (changesSource ?? Connectivity().onConnectivityChanged).listen(_onStreamEvent, onError: (Object e) {
      // A backend that can't be watched (no NetworkManager on Linux) costs
      // the reconnect resync and the offline stamp on map errors — the app
      // stays in the loud-by-default state. Forwarded so subscribers with
      // their own onError (DataFileManager) still see it. The Linux backend
      // can also throw from its own async stream setup, unreachable by this
      // onError; ErrorPolicy's connectivity-backend-unavailable rule covers
      // that leg.
      debugPrint('[connectivity] stream error: $e');
      _changes.addError(e);
    });
    (check ?? Connectivity().checkConnectivity)().then((results) {
      // The probe is a snapshot from before the subscription's first event;
      // a real change that beat it here is newer and must not be clobbered.
      if (!_sawStreamEvent) _onChanged(results);
    }, onError: (Object e) {
      debugPrint('[connectivity] initial check failed: $e');
    });
  }

  static bool _sawStreamEvent = false;

  static void _onStreamEvent(List<ConnectivityResult> results) {
    _sawStreamEvent = true;
    _onChanged(results);
  }

  static void _onChanged(List<ConnectivityResult> results) {
    _offline = results.every((r) => r == ConnectivityResult.none);
    _changes.add(results);
  }

  @visibleForTesting
  static void resetForTesting() {
    _subscription?.cancel();
    _subscription = null;
    _sawStreamEvent = false;
    _offline = false;
  }
}
