// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Device GPS, for the Operation Location screen's "Device GPS" suggestion
// and for feeding nearby-activity search a location when the operation
// itself has no grid set yet. Device-global (like RadioService), not
// per-operation — there's only ever one GPS receiver to ask.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halo_core/halo_core.dart';

import '../config/dev_flags.dart';

enum LocationStatus { unknown, determining, available, unavailable, permissionDenied }

/// Parses the raw `DEV_LOCATION` value into a grid location, or null when
/// unset/invalid (logging the invalid case). Extracted to a top-level
/// function — like `applyOnboardAsSpec` for `ONBOARD_AS` — so the
/// invalid-locator fallback can be exercised with an arbitrary string from a
/// test, rather than only via a real `--dart-define` launch.
@visibleForTesting
GridLocation? parseDevLocation(String raw) {
  if (raw.isEmpty) return null;
  final location = gridToLocation(raw);
  if (location == null) debugPrint('[location] DEV_LOCATION "$raw" is not a valid grid locator, ignoring');
  return location;
}

/// Parses the raw `DEV_LOCATION_STATUS` value into the status to pin the
/// service at, or null when unset/invalid. Same reasoning as
/// [parseDevLocation]: the invalid case is worth exercising from a test.
@visibleForTesting
LocationStatus? parseDevLocationStatus(String raw) {
  if (raw.isEmpty) return null;
  for (final status in LocationStatus.values) {
    if (status.name.toLowerCase() == raw.trim().toLowerCase()) return status;
  }
  debugPrint('[location] DEV_LOCATION_STATUS "$raw" is not one of ${LocationStatus.values.map((s) => s.name)}');
  return null;
}

class LocationService extends ChangeNotifier {
  // `DEV_LOCATION=FN21rq` mocks the device GPS with a fixed grid locator, so
  // dev/testing doesn't need to grant OS location permissions or wait on a
  // real fix. Parsed once — it's a launch-time flag, not something that
  // changes mid-process.
  static final GridLocation? _devLocation =
      parseDevLocation(debugEnvFlag(const String.fromEnvironment('DEV_LOCATION'), 'DEV_LOCATION'));

  // `DEV_LOCATION_STATUS=permissionDenied` pins the service at one status so
  // the states behind it can be looked at on demand. Denied permission and a
  // device that can't produce a fix are otherwise reachable only by revoking
  // an OS permission or taking the hardware away, which makes reviewing what
  // they put on screen far harder than reading the code that draws it.
  // Outranks DEV_LOCATION: a pinned status is the more specific instruction.
  static final LocationStatus? _devStatus = parseDevLocationStatus(
      debugEnvFlag(const String.fromEnvironment('DEV_LOCATION_STATUS'), 'DEV_LOCATION_STATUS'));

  static Position _mockPosition(GridLocation location) => Position(
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: true,
      );

  Position? _position;
  LocationStatus _status = LocationStatus.unknown;
  StreamSubscription<Position>? _sub;

  // Multiple views (the Location screen, the Activities view) may both want
  // live updates at once; only stop the underlying stream once every caller
  // has released it.
  int _listenerCount = 0;

  LocationStatus get status => _status;
  Position? get position => _position;
  String? get grid => _position == null ? null : locationToGrid6(_position!.latitude, _position!.longitude);

  // [start] and [getCurrentPosition] can both ask for permission at once (the
  // Activities view starting the live stream while a WEATHER command with no
  // operation grid does a one-shot fetch) — `geolocator` throws
  // PermissionRequestInProgressException if `requestPermission()` is called
  // again while one is already awaiting the OS prompt. Sharing the in-flight
  // request here means the second caller just awaits the first's result
  // instead of triggering that.
  Future<LocationPermission>? _permissionRequest;

  Future<LocationPermission> _resolvePermission() {
    return _permissionRequest ??= () async {
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        return permission;
      } finally {
        _permissionRequest = null;
      }
    }();
  }

  Future<void> start() async {
    if (_devStatus != null) {
      if (_status == _devStatus) return;
      debugPrint('[location] pinned to ${_devStatus!.name} by DEV_LOCATION_STATUS');
      // A pinned `available` needs a position to be available OF: production
      // only ever sets that status with one in hand, so pinning it without
      // DEV_LOCATION would manufacture a state the app can't otherwise reach
      // and show a GPS pin pulsing forever.
      if (_devStatus == LocationStatus.available) {
        if (_devLocation == null) {
          debugPrint('[location] DEV_LOCATION_STATUS=available needs DEV_LOCATION for a position, ignoring');
          return;
        }
        _position = _mockPosition(_devLocation!);
      }
      // Any other status leaves _position alone — the real service never
      // clears it either, and a bad status over a retained fix is exactly the
      // combination worth being able to look at.
      _status = _devStatus!;
      notifyListeners();
      return;
    }

    if (_devLocation != null) {
      // Mirrors the real path's `if (_sub != null) return;` guard below:
      // skip re-notifying once already mocked, so a second view starting
      // (e.g. the Location screen opened over the Activities view) doesn't
      // retrigger listeners for no actual change.
      if (_status == LocationStatus.available) return;
      _position = _mockPosition(_devLocation!);
      _status = LocationStatus.available;
      notifyListeners();
      return;
    }

    _listenerCount++;
    // Skip only when a fix is already streaming — a listener count above 1
    // doesn't mean a previous attempt actually succeeded (it may have ended
    // in permissionDenied/unavailable), so a new caller must still be able
    // to retry that check rather than being silently ignored.
    if (_sub != null) return;

    _status = LocationStatus.determining;
    notifyListeners();

    try {
      final permission = await _resolvePermission();
      // Every caller may have stopped while the checks above were in
      // flight — don't start a stream nothing will ever cancel.
      if (_listenerCount == 0) return;
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _status = LocationStatus.permissionDenied;
        notifyListeners();
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _status = LocationStatus.unavailable;
        notifyListeners();
        return;
      }
      if (_listenerCount == 0) return;

      const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50);
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (position) {
          _position = position;
          _status = LocationStatus.available;
          notifyListeners();
        },
        onError: (Object e) {
          // A later failure (permission revoked, GPS lost) must surface —
          // otherwise the UI keeps showing an increasingly stale fix as if
          // it were still live.
          debugPrint('[location] stream error: $e');
          _status = LocationStatus.unavailable;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[location] failed to start: $e');
      _status = LocationStatus.unavailable;
      notifyListeners();
    }
  }

  /// Releases one caller's interest in live updates — stops the underlying
  /// stream once every caller has stopped (see [_listenerCount]).
  void stop() {
    if (_listenerCount == 0) return;
    _listenerCount--;
    if (_listenerCount == 0) {
      unawaited(_sub?.cancel());
      _sub = null;
    }
  }

  /// One-shot fix for a caller that doesn't want to open the continuous
  /// stream (the `getLocation` host call, e.g. WEATHER with no operation
  /// grid to fall back to). Always takes a fresh reading rather than
  /// returning [_position] — that field can be long stale (never cleared by
  /// [stop] or a stream [onError]), and reusing it would also skip the
  /// permission/service-enabled checks below. Returns null on any
  /// denial/failure.
  Future<Position?> getCurrentPosition() async {
    // A pinned status answers here too, or a build pretending to have no
    // location would still hand a real fix to whoever asked for one directly.
    if (_devStatus != null) {
      // Whatever the pinned status is standing over — a retained fix under a
      // bad status included, since that is a state the real service reaches.
      return _position;
    }
    if (_devLocation != null) return _mockPosition(_devLocation!);

    try {
      final permission = await _resolvePermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.reduced, timeLimit: Duration(seconds: 5)),
      );
    } catch (e) {
      debugPrint('[location] getCurrentPosition failed: $e');
      return null;
    }
  }
}
