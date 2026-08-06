// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
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
}
