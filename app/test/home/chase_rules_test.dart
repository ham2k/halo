// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Chasing view's rules that need no view around them: which activities
// are being chased and in what order, which controls the logging panel gets
// for them, what a new contact carries of the chasing location, and where
// each period begins.

import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/services/extensions/extension_service.dart' show controlExtensionKeyField;
import 'package:ham2k_logger/views/chase_view.dart';

/// As the fan-out hands it over, with the answering extension stamped on.
Map<String, dynamic> _hunting(String extension, {String label = ''}) => {
  'key': '$extension/hunter',
  controlExtensionKeyField: extension,
  'label': label.isEmpty ? extension.toUpperCase() : label,
  'icon': 'pine-tree',
  'color': '#2e7d32',
  'input': {'kind': 'refList', 'refType': extension},
};

const Map<String, dynamic> _exchange = {
  'key': 'cwt/exchange',
  'label': 'Exchange',
  'input': {'kind': 'text'},
};

void main() {
  group('resolveChaseGoals', () {
    test('keeps the stored order and on/off, and drops activities no longer offered', () {
      final goals = resolveChaseGoals(
        [_hunting('pota'), _hunting('sota')],
        [
          {'key': 'sota', 'on': true},
          {'key': 'gone', 'on': true},
          {'key': 'pota', 'on': false},
        ],
      );
      expect([for (final g in goals) (g.key, g.on)], [('sota', true), ('pota', false)]);
    });

    // Enabling an extension makes an activity AVAILABLE. Chasing it on every
    // contact from then on is the operator's call, made in the sheet — not a
    // side effect of a toggle in Manage Extensions.
    test('an activity offered for the first time is not chased until it is added', () {
      final goals = resolveChaseGoals(
        [_hunting('pota'), _hunting('wwff')],
        [
          {'key': 'pota', 'on': true},
        ],
      );
      expect(goals.singleWhere((g) => g.key == 'wwff').on, isFalse);
      expect(resolveChaseGoals([_hunting('pota')], const []).single.on, isFalse, reason: 'nothing stored yet: nothing chased');
    });

    test('only hunting reference controls are goals, one per extension', () {
      final goals = resolveChaseGoals([
        _hunting('pota'),
        _exchange,
        {..._hunting('pota'), 'key': 'pota/second'},
      ], const []);
      expect(goals.map((g) => g.key), ['pota']);
      expect(goals.single.color, '#2e7d32', reason: 'the accent travels with the goal, for its icon');
    });

    test('a goal is the extension that answered, not its control key\'s namespace', () {
      // The catalog's POTA is `ham2k-pota` and keys its controls `pota/…`;
      // a second supplier keying its controls the same way must still be a
      // goal of its own.
      final goals = resolveChaseGoals([
        {..._hunting('pota'), controlExtensionKeyField: 'ham2k-pota'},
        {..._hunting('pota'), controlExtensionKeyField: 'ki2d-pota'},
      ], const []);
      expect(goals.map((g) => g.key), ['ham2k-pota', 'ki2d-pota']);
    });
  });

  group('chaseLoggingControls', () {
    test("a goal's control shows only while chased, in goal order, ahead of the rest", () {
      final controls = [_exchange, _hunting('pota'), _hunting('sota'), _hunting('wwff')];
      final goals = resolveChaseGoals(controls, [
        {'key': 'sota', 'on': true},
        {'key': 'wwff', 'on': false},
        {'key': 'pota', 'on': true},
      ]);
      expect(chaseLoggingControls(controls, goals).map((c) => c['key']), ['sota/hunter', 'pota/hunter', 'cwt/exchange']);
    });
  });

  group('qsoWithChaseLocation', () {
    const location = {'grid': 'FN31pr', 'gridSource': 'gps', 'lat': 41.7, 'lon': -72.7, 'state': 'CT', 'county': 'Hartford'};

    test('a new contact carries the chasing location on its own side', () {
      final stamped = qsoWithChaseLocation({
        'their': {'call': 'K1ABC'},
        'our': {'call': 'KI2D'},
      }, location);
      expect(stamped['our'], {'call': 'KI2D', ...location});
    });

    // Re-saving an edit to yesterday's contact must not move it to wherever
    // the operator happens to be chasing from today.
    test('an earlier contact being edited, and an event row, keep what they have', () {
      final edited = {
        'uuid': 'q1',
        'our': {'call': 'KI2D', 'grid': 'EM12'},
      };
      expect(qsoWithChaseLocation(edited, location), same(edited));
      final event = {'band': 'event', 'our': <String, dynamic>{}};
      expect(qsoWithChaseLocation(event, location), same(event));
    });

    // locations.md: a coordinate outranks the grid wherever both are read, so
    // a grid written beside a coordinate it did not come with is discarded
    // by every reader.
    test('a place is written whole: a grid with no coordinate clears the pair it would sit beside', () {
      final stamped = qsoWithChaseLocation(
        {
          'our': {'call': 'KI2D', 'lat': 10.0, 'lon': 20.0},
        },
        {'grid': 'FN31'},
      );
      final our = stamped['our'] as Map;
      expect(our['grid'], 'FN31');
      expect(our.containsKey('lat'), isFalse);
      expect(our.containsKey('lon'), isFalse);
    });

    test('with no chasing location a contact is left as it is', () {
      final qso = {
        'our': {'call': 'KI2D'},
      };
      expect(qsoWithChaseLocation(qso, const {}), same(qso));
    });
  });

  group('ChasePeriod.startMillis', () {
    // A Wednesday, mid-afternoon UTC.
    final now = DateTime.utc(2026, 10, 14, 15, 30);
    int at(int year, int month, int day) => DateTime.utc(year, month, day).millisecondsSinceEpoch;

    test('every period starts at a UTC midnight, so the log moves on at 0000Z and at no other time', () {
      expect(ChasePeriod.today.startMillis(now), at(2026, 10, 14));
      expect(ChasePeriod.thisWeek.startMillis(now), at(2026, 10, 12), reason: 'weeks start on Monday');
      expect(ChasePeriod.last14Days.startMillis(now), at(2026, 10, 1), reason: 'today and the thirteen days before it');
      expect(ChasePeriod.thisMonth.startMillis(now), at(2026, 10, 1));
    });

    test('a minute either side of 0000Z is a different today', () {
      expect(ChasePeriod.today.startMillis(DateTime.utc(2026, 10, 14, 23, 59)), at(2026, 10, 14));
      expect(ChasePeriod.today.startMillis(DateTime.utc(2026, 10, 15, 0, 1)), at(2026, 10, 15));
    });

    test('on a Monday the week starts that day', () {
      expect(ChasePeriod.thisWeek.startMillis(DateTime.utc(2026, 10, 12, 1)), at(2026, 10, 12));
    });
  });
}
