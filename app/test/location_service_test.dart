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
}
