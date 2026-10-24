// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Chasing view's rules that need no view around them: which programs
// are being chased and in what order, which controls the logging panel gets,
// what a new contact carries of the chasing location, and where each period
// begins.

import 'package:flutter_test/flutter_test.dart';

import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/chase_service.dart';
import 'package:ham2k_logger/views/chase_view.dart';

Map<String, dynamic> _hunting(String extension, {String label = ''}) => {
  'key': '$extension/hunter',
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

ChasingProgram _program(String key) => ChasingProgram(key: key, label: key.toUpperCase(), version: 1, editions: ChasingEditions.lifetime);

void main() {
  group('resolveChaseGoals', () {
    test('keeps the stored order and on/off, and leaves out programs no longer registered', () {
      final goals = resolveChaseGoals(
        {'pota': _program('pota'), 'wwff': _program('wwff')},
        [
          {'key': 'wwff', 'on': true},
          {'key': 'gone', 'on': true},
          {'key': 'pota', 'on': false},
        ],
      );
      expect([for (final g in goals) (g.key, g.on)], [('wwff', true), ('pota', false)]);
      expect(goals.first.label, 'WWFF', reason: 'the label is the program\'s own');
    });

    // An extension enabled with a program in it is one the operator means to
    // chase; making them add it again in the sheet is a step nobody asked for.
    test('a program registered for the first time joins at the end, chased', () {
      final goals = resolveChaseGoals(
        {'pota': _program('pota'), 'wwff': _program('wwff')},
        [
          {'key': 'pota', 'on': false},
        ],
      );
      expect([for (final g in goals) (g.key, g.on)], [('pota', false), ('wwff', true)]);
    });

    // Removing an extension takes its program out of the list; adding it back
    // must not undo the operator's choice to stop chasing it. Without the
    // entries kept for programs not registered, the round trip turns it on.
    test('a program turned off stays off across its extension being removed and added again', () {
      var stored = <Object?>[
        {'key': 'pota', 'on': true},
        {'key': 'wwff', 'on': false},
      ];
      final withoutWwff = resolveChaseGoals({'pota': _program('pota')}, stored);
      stored = storedChaseGoals([for (final g in withoutWwff) g.withOn(true)], stored);
      final back = resolveChaseGoals({'pota': _program('pota'), 'wwff': _program('wwff')}, stored);
      expect(back.singleWhere((g) => g.key == 'wwff').on, isFalse);
    });
  });

  // The core `dxcc` program became the catalog's `ham2k-dxcc`: the operator
  // put DXCC where they wanted it and turned it on or off, and the move must
  // not undo either.
  group('a program that moved to a new key', () {
    test('keeps its stored place and switch under the new key', () {
      final stored = <Object?>[
        {'key': 'pota', 'on': true},
        {'key': 'dxcc', 'on': false},
      ];
      final goals = resolveChaseGoals({'ham2k-dxcc': _program('ham2k-dxcc'), 'pota': _program('pota')}, stored);
      expect([for (final g in goals) (g.key, g.on)], [('pota', true), ('ham2k-dxcc', false)]);
      expect(storedChaseGoals(goals, stored), [
        {'key': 'pota', 'on': true},
        {'key': 'ham2k-dxcc', 'on': false},
      ], reason: 'stored again under the new key, once');
    });

    test('is kept under the new key while its extension is away', () {
      final stored = storedChaseGoals(resolveChaseGoals({'pota': _program('pota')}, const []), [
        {'key': 'dxcc', 'on': false},
      ]);
      expect(stored, [
        {'key': 'pota', 'on': true},
        {'key': 'ham2k-dxcc', 'on': false},
      ]);
    });
  });

  group('chaseLoggingControls', () {
    test('every hunting control shows, ahead of the rest, whatever the goals', () {
      final controls = [_exchange, _hunting('pota'), _hunting('sota')];
      expect(chaseLoggingControls(controls).map((c) => c['key']), ['pota/hunter', 'sota/hunter', 'cwt/exchange']);
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
