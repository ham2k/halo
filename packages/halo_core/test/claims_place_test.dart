// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A contact records no place of its own; a program asking where it was made
// reads its operation's (docs/design/claims.md §3).

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('withPlaceFrom', () {
    const operation = {'grid': 'FN31pr', 'lat': 41.7, 'lon': -72.7};

    test("a contact's own place is kept", () {
      final side = {'call': 'N0DEV', 'grid': 'FN42aa'};
      expect(withPlaceFrom(side, operation), side);
    });

    test("a contact holding only a placeholder pair takes the operation's place", () {
      // Counted as a place, 0,0 keeps the operation's real one off the
      // contact, and every reader then refuses the pair and finds it nowhere.
      final placed = withPlaceFrom({'call': 'N0DEV', 'lat': 0, 'lon': 0}, operation);
      expect(placed['grid'], 'FN31pr');
      expect(placed['lat'], 41.7);
      expect(placed['lon'], -72.7);
    });

    test("the placeholder pair goes even when the operation states only a grid", () {
      // Copied together or not at all: a 0,0 pair kept beside the operation's
      // grid outranks it for every program that reads the station raw.
      final placed = withPlaceFrom({'call': 'N0DEV', 'lat': 0, 'lon': 0}, {'grid': 'FN31pr'});
      expect(placed, {'call': 'N0DEV', 'grid': 'FN31pr'});
    });
  });
}
