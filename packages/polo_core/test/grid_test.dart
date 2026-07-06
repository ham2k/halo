// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:polo_core/polo_core.dart';
import 'package:test/test.dart';

void main() {
  group('gridToLocation', () {
    test('decodes a 6-character grid to near its real-world location', () {
      // FN31pr is ARRL HQ's grid square (Newington, CT — ~41.71N, 72.73W).
      final location = gridToLocation('FN31pr')!;
      expect(location.latitude, closeTo(41.71, 0.05));
      expect(location.longitude, closeTo(-72.71, 0.05));
    });

    test('decodes a 4-character grid to the center of its square', () {
      final location = gridToLocation('FN31')!;
      expect(location.latitude, closeTo(41.5, 0.5));
      expect(location.longitude, closeTo(-73, 1));
    });

    test('is case-insensitive', () {
      final upper = gridToLocation('FN31PR')!;
      final lower = gridToLocation('fn31pr')!;
      expect(lower.latitude, upper.latitude);
      expect(lower.longitude, upper.longitude);
    });

    test('returns null for invalid input', () {
      expect(gridToLocation(null), isNull);
      expect(gridToLocation(''), isNull);
      expect(gridToLocation('F1'), isNull); // too short
      expect(gridToLocation('991a'), isNull); // field chars must be letters
      expect(gridToLocation('FNaa'), isNull); // square chars must be digits
    });
  });
}
