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

/// `permissionDenied` and `permissionBlocked` are kept apart because their
/// FIXES are: the first is one the app may ask for again, the second the
/// operator has to grant in OS settings and asking again does nothing.
enum LocationStatus { unknown, determining, available, unavailable, permissionDenied, permissionBlocked }

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
        timestamp: nowLocal(),
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

  Position? _peerPosition;
  String? _peerPositionDeviceId;
  String? _peerPositionDeviceName;

  /// A paired device's fix, offered as a FALLBACK (HALO-334): it answers only
  /// while this device's own hardware cannot — [LocationStatus.unavailable]
  /// or either permission status. A device with a working GPS never silently
  /// shows someone else's position, and the moment the local receiver
  /// delivers, it wins again with nothing to clear.
  ///
  /// One slot, latest wins. [deviceId] names the providing peer so its
  /// disconnect can clear exactly its own fix and nothing newer.
  void setPeerPosition(Position? position, {String? deviceId, String? deviceName}) {
    // A clear only clears the peer whose fix is actually standing — a
    // disconnect notice arriving after another peer already superseded the
    // fix must not blank the newer one.
    if (position == null && deviceId != null && deviceId != _peerPositionDeviceId) return;
    _peerPosition = position;
    _peerPositionDeviceId = position == null ? null : deviceId;
    _peerPositionDeviceName = position == null ? null : deviceName;
    notifyListeners();
  }

  bool get _localCannotDeliver =>
      _status == LocationStatus.unavailable ||
      _status == LocationStatus.permissionDenied ||
      _status == LocationStatus.permissionBlocked;

  /// True when [position] is currently answering with a peer's fix rather
  /// than this device's own — what the outbound share reads so a relayed fix
  /// is never re-broadcast, and what the UI reads to say whose position it
  /// is showing.
  bool get positionIsFromPeer => _localCannotDeliver && _peerPosition != null;

  /// The name of the device whose fix [position] is serving, when
  /// [positionIsFromPeer] — for the Location screen's tile, which must not
  /// call a peer's position "Device GPS".
  String? get peerPositionDeviceName => positionIsFromPeer ? _peerPositionDeviceName : null;

  /// Which peer's fix is HELD — serving or latent behind a working local
  /// GPS. The router reads this to clear a disconnected peer's fix, which
  /// must happen either way: a latent stale fix would otherwise surface the
  /// moment the local receiver failed, hours later.
  String? get peerPositionProviderId => _peerPositionDeviceId;

  LocationStatus get status => positionIsFromPeer ? LocationStatus.available : _status;

  /// The device's OWN hardware truth, unmasked by a serving peer fix. The
  /// surfaces that let the operator FIX their local GPS (grant permission,
  /// open settings) key off this: a peer standing in makes [status] read
  /// `available`, and remediation keyed on that disappears exactly while a
  /// peer hides the problem — resurfacing the moment the peer walks away.
  LocationStatus get localStatus => _status;
  Position? get position => positionIsFromPeer ? _peerPosition : _position;
  /// The fix as a 6-character locator. Kept beside [displayGrid] for the one
  /// comparison that has to happen at six characters: an operation stored
  /// before `gridSource` existed carries a 6-character grid, and deciding
  /// whether it came from GPS means comparing like with like.
  String? get grid {
    final resolved = position;
    return resolved == null ? null : locationToGrid6(resolved.latitude, resolved.longitude);
  }

  /// The fix as a locator at the operator's [GridPrecision] — what they are
  /// SHOWN, and what is stored as the grid when they adopt this position. The
  /// coordinate is stored alongside it either way, so the setting decides how
  /// finely the app SPEAKS about a fix, never how finely it holds one.
  String? get displayGrid {
    final resolved = position;
    if (resolved == null) return null;
    return gridForLocation(resolved.latitude, resolved.longitude);
  }

  /// The fix as a plain coordinate, for everything that measures rather than
  /// displays — nearby search, distance, the map's "you are here".
  GridLocation? get location {
    final resolved = position;
    return resolved == null ? null : GridLocation(resolved.latitude, resolved.longitude);
  }

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

    return _seekFix();
  }

  /// Resolves permission and opens the position stream. Separate from [start]
  /// because it must be retryable WITHOUT taking another listener: [start] is
  /// paired one-to-one with [stop], and a retry that went through it would
  /// leave a count nobody ever releases and a stream that never stops.
  Future<void> _seekFix() async {
    _status = LocationStatus.determining;
    notifyListeners();

    try {
      final permission = await _resolvePermission();
      // Every caller may have stopped while the checks above were in
      // flight — don't start a stream nothing will ever cancel. Back out of
      // `determining` on the way, or the next view to open inherits a pulsing
      // "GPS…" for a fix nobody is looking for any more.
      if (_listenerCount == 0) {
        _status = LocationStatus.unknown;
        return;
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _status = permission == LocationPermission.deniedForever
            ? LocationStatus.permissionBlocked
            : LocationStatus.permissionDenied;
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

  /// Asks the OS for location permission again, then retries the fix.
  ///
  /// Only meaningful from [LocationStatus.permissionDenied]: once the OS says
  /// `deniedForever` it answers instantly without prompting, which is why that
  /// state is [LocationStatus.permissionBlocked] and is offered
  /// [openSystemSettings] instead. Answers whether a fix is now being sought,
  /// so a caller can say something when the OS said no again.
  ///
  /// The in-flight request is cleared first: `_resolvePermission` memoizes, and
  /// a retry that re-awaits the previous denial would never reach the OS.
  Future<bool> requestPermissionAgain() async {
    if (_devStatus != null) return false;
    // Not while one is already in flight: geolocator throws
    // PermissionRequestInProgressException for a second concurrent request,
    // and a double-tap would turn into an unhandled error rather than a
    // second prompt. Clearing the memo is what makes THIS ask reach the OS
    // rather than re-await the refusal that got us here.
    if (_permissionRequest != null) return false;
    _permissionRequest = null;
    final LocationPermission permission;
    try {
      permission = await _resolvePermission();
    } catch (e) {
      debugPrint('[location] permission re-request failed: $e');
      return false;
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _status = permission == LocationPermission.deniedForever
          ? LocationStatus.permissionBlocked
          : LocationStatus.permissionDenied;
      notifyListeners();
      return false;
    }
    // Granted. The stream was never opened (start() returned at the denial),
    // so this is what actually goes and gets a fix — without taking a second
    // listener the caller would never release.
    await _seekFix();
    return true;
  }

  /// Opens the OS's own settings page for this app — the only place a
  /// `deniedForever` can be undone. False when there is no such page to open.
  ///
  /// Not every platform has one: geolocator's web implementation throws
  /// outright and Linux never implements it. Answering false lets the caller
  /// say what to do instead, where letting the throw escape would turn the one
  /// button on screen into an error toast.
  Future<bool> openSystemSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('[location] no app settings page to open: $e');
      return false;
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
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return _peerPosition;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return _peerPosition;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.reduced, timeLimit: Duration(seconds: 5)),
      );
    } catch (e) {
      // The peer fix answers the failure cases the same way it backs the
      // stream: only when this device's own read could not deliver.
      debugPrint('[location] getCurrentPosition failed: $e');
      return _peerPosition;
    }
  }

  /// [start], but only if the OS permission is ALREADY granted — never
  /// prompting. For a caller acting on its own initiative rather than the
  /// operator's (peer sharing coming up), where a permission dialog out of
  /// nowhere would read as the app spying. Answers whether it started.
  Future<bool> startIfPermitted() async {
    if (_devStatus != null || _devLocation != null) {
      await start();
      return true;
    }
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        return false;
      }
    } catch (e) {
      debugPrint('[location] permission check failed: $e');
      return false;
    }
    await start();
    return true;
  }
}
