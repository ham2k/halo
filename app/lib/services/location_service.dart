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

enum LocationStatus { unknown, determining, available, unavailable, permissionDenied }

class LocationService extends ChangeNotifier {
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

  Future<void> start() async {
    _listenerCount++;
    // Skip only when a fix is already streaming — a listener count above 1
    // doesn't mean a previous attempt actually succeeded (it may have ended
    // in permissionDenied/unavailable), so a new caller must still be able
    // to retry that check rather than being silently ignored.
    if (_sub != null) return;

    _status = LocationStatus.determining;
    notifyListeners();

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
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
}
