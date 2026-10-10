// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A device whose position the test sets, for surfaces that read the location
// service (the setup sheet's capture, the Location screen's Device GPS row).

import 'package:geolocator/geolocator.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/location_service.dart';

/// Started and stopped as freely as the caller likes, with no OS behind it.
///
/// [status] follows [fix] — `available` exactly while one is held, as the real
/// service is once its stream has delivered one — unless the test pins
/// [statusOverride]. That is how a REMEMBERED position is expressed: the real
/// service keeps its last position through `stop()`, a restart's
/// `determining` and a stream error, and a fake that could only say
/// "available" whenever it held one would let a stale-fix bug pass.
class FakeGpsLocation extends LocationService {
  GridLocation? fix;

  /// The fix's accuracy radius, in metres, as `Position.accuracy` reports it.
  double accuracy = 5;

  LocationStatus? statusOverride;

  void setFix(GridLocation? value, {double? accuracy}) {
    fix = value;
    if (accuracy != null) this.accuracy = accuracy;
    notifyListeners();
  }

  @override
  Future<void> start() async {}

  @override
  void stop() {}

  @override
  LocationStatus get status => statusOverride ?? (fix == null ? LocationStatus.unknown : LocationStatus.available);

  @override
  Position? get position => switch (fix) {
    null => null,
    final f => Position(
      latitude: f.latitude,
      longitude: f.longitude,
      timestamp: DateTime.utc(2026, 10, 9),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    ),
  };
}
