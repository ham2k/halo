// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ham2k_logger/services/location_service.dart';

void main() {
  group('parseDevLocation (DEV_LOCATION)', () {
    test('unset yields no mock location', () {
      expect(parseDevLocation(''), isNull);
    });

    test('a valid grid locator yields its center location', () {
      final location = parseDevLocation('FN21rq');
      expect(location, isNotNull);
      expect(location!.latitude, closeTo(41.6875, 0.001));
      expect(location.longitude, closeTo(-74.5417, 0.001));
    });

    test('an invalid locator is ignored rather than thrown', () {
      expect(parseDevLocation('not a grid'), isNull);
      expect(parseDevLocation('ZZ99'), isNull);
    });
  });

  group('parseDevLocationStatus (DEV_LOCATION_STATUS)', () {
    test('unset pins nothing', () {
      expect(parseDevLocationStatus(''), isNull);
    });

    test('every status is reachable by name', () {
      // A flag that silently accepts only some of them would send whoever is
      // reviewing those states to the wrong screen, looking like the code.
      for (final status in LocationStatus.values) {
        expect(parseDevLocationStatus(status.name), status, reason: status.name);
      }
    });

    test('case and surrounding space do not have to be got right', () {
      expect(parseDevLocationStatus('  permissiondenied '), LocationStatus.permissionDenied);
      expect(parseDevLocationStatus('UNAVAILABLE'), LocationStatus.unavailable);
    });

    test('an unrecognized name pins nothing rather than throwing at launch', () {
      expect(parseDevLocationStatus('denied'), isNull);
      expect(parseDevLocationStatus('nonsense'), isNull);
    });
  });

  group('a paired peer\'s fix as the fallback source (HALO-334)', () {
    Position peerFix({double lat = 40.7, double lon = -74.0}) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    test('held but not served while nothing has asked the local hardware', () {
      // `unknown` means the local receiver has not even been tried. Serving
      // the peer fix there would mean a device that COULD get its own fix
      // shows someone else's the moment a peer connects.
      final service = LocationService();
      service.setPeerPosition(peerFix(), deviceId: 'device-a', deviceName: 'Phone');

      expect(service.status, LocationStatus.unknown);
      expect(service.position, isNull);
      expect(service.positionIsFromPeer, isFalse);
      expect(service.peerPositionProviderId, 'device-a', reason: 'held latent — it serves the instant local hardware fails');
    });

    test('serves position, status and grid once the local receiver cannot deliver', () async {
      final service = LocationService();
      // In a VM test the geolocator plugin is absent, so the real start()
      // path lands in `unavailable` — exactly the laptop-without-GPS state.
      await service.start();
      expect(service.status, LocationStatus.unavailable, reason: 'precondition');

      service.setPeerPosition(peerFix(), deviceId: 'device-a', deviceName: 'Phone');

      expect(service.status, LocationStatus.available);
      expect(service.position?.latitude, 40.7);
      expect(service.positionIsFromPeer, isTrue);
      expect(service.grid, isNotNull);
      expect(service.peerPositionDeviceName, 'Phone', reason: 'the Location screen must be able to say WHOSE position this is');
    });

    test('a clear names its provider, so it cannot blank a newer peer\'s fix', () async {
      final service = LocationService();
      await service.start();
      service.setPeerPosition(peerFix(), deviceId: 'device-a');
      service.setPeerPosition(peerFix(lat: 51.5, lon: -0.1), deviceId: 'device-b');

      // device-a's disconnect notice arrives after device-b superseded it.
      service.setPeerPosition(null, deviceId: 'device-a');
      expect(service.position?.latitude, 51.5, reason: 'the stale clear must not take the newer provider\'s fix with it');

      service.setPeerPosition(null, deviceId: 'device-b');
      expect(service.position, isNull);
      expect(service.status, LocationStatus.unavailable, reason: 'back to the local truth');
    });

    test('getCurrentPosition answers with the peer fix when the local read cannot', () async {
      final service = LocationService();
      service.setPeerPosition(peerFix(), deviceId: 'device-a');

      // The plugin is absent, so the one-shot read fails — the case a laptop
      // with no GPS hits every time WEATHER asks.
      final position = await service.getCurrentPosition();
      expect(position?.latitude, 40.7);
    });
  });
}
