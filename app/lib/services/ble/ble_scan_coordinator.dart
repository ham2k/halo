// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One platform scan, shared. `universal_ble` runs a single scan per process:
// a second `startScan` replaces the first one's filter, and any `stopScan`
// ends it for everybody. Peer discovery scans for its own service for as long
// as its switch is on; the CAT device picker scans for anything with a name,
// for a few seconds. Each takes a lease here instead of calling the plugin,
// and this runs the one scan that serves every lease — filtered to the union
// of their services while all of them name some, unfiltered while any does
// not — and hands each lease only the results it asked for.
//
// Nothing else in the app may call `UniversalBle.startScan`/`stopScan`, or
// set `onScanResult`: either would end a lease's scan without telling it.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

class BleScanLease {
  BleScanLease._(this.services, this._onResult);

  /// Null is "everything".
  final Set<String>? services;
  final void Function(BleDevice device) _onResult;
}

class BleScanCoordinator {
  BleScanCoordinator._();

  static final instance = BleScanCoordinator._();

  final _leases = <BleScanLease>[];
  StreamSubscription<BleDevice>? _results;

  /// What the running scan was started with — `'*'` unfiltered, the sorted
  /// services otherwise — or null when none is running. Cleared only once
  /// the stop has completed, and set only once the start has: results still
  /// arriving from a wide scan being narrowed must be read as wide ones.
  /// Cleared when the stop FAILS too: Android refuses a stop while Bluetooth
  /// is off, when there is no scan left to stop, and a value kept would read
  /// as a scan still running — and skip the start once Bluetooth is back.
  String? _running;

  /// Every start and stop goes through here in order: two leases changing at
  /// once would otherwise interleave a stop between the other's start and its
  /// bookkeeping.
  Future<void> _tail = Future.value();

  /// Starts serving [onResult]. Throws — with the lease already withdrawn —
  /// when the scan could not be started.
  Future<BleScanLease> acquire({Set<String>? services, required void Function(BleDevice device) onResult}) async {
    final lease = BleScanLease._(services == null ? null : {for (final uuid in services) BleUuidParser.string(uuid)}, onResult);
    _leases.add(lease);
    try {
      await _reconcile();
    } catch (_) {
      _leases.remove(lease);
      await _reconcile().catchError((Object e) => debugPrint('[ble] scan restore after a failed start: $e'));
      rethrow;
    }
    return lease;
  }

  /// Idempotent. The remaining leases keep a scan, refiltered if this one
  /// was what widened it.
  Future<void> release(BleScanLease lease) async {
    if (!_leases.remove(lease)) return;
    await _reconcile();
  }

  Future<void> _reconcile() {
    final next = _tail.then((_) => _apply());
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> _apply() async {
    final unfiltered = _leases.any((lease) => lease.services == null);
    final services = unfiltered ? const <String>[] : ({for (final lease in _leases) ...lease.services!}.toList()..sort());
    final wanted = _leases.isEmpty ? null : (unfiltered ? '*' : _keyOf(services));
    if (wanted == _running) return;
    if (_running != null) {
      try {
        await UniversalBle.stopScan();
      } finally {
        _running = null;
      }
    }
    if (wanted == null) {
      await _results?.cancel();
      _results = null;
      return;
    }
    _results ??= UniversalBle.scanStream.listen(_dispatch);
    await UniversalBle.startScan(scanFilter: unfiltered ? null : ScanFilter(withServices: services));
    _running = wanted;
  }

  static String _keyOf(List<String> sortedServices) => sortedServices.join(',');

  void _dispatch(BleDevice device) {
    final advertised = {for (final uuid in device.services) ?BleUuidParser.stringOrNull(uuid)};
    for (final lease in List.of(_leases)) {
      final wanted = lease.services;
      // A lease whose own filter is the one running IS the platform's
      // filter, so its results pass as they always did: a platform that
      // matched the filter but left the service out of the result must not
      // lose them here. Any other scan — a wider one, or one mid-change —
      // is checked against what the device advertised.
      final platformFiltered = wanted != null && _running == _keyOf(wanted.toList()..sort());
      if (wanted == null || platformFiltered || wanted.any(advertised.contains)) lease._onResult(device);
    }
  }
}
