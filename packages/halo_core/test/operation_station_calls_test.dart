// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which station calls a contact was made under. On an operation run under
// several calls, who is present changes as the operation goes on, and each
// call's submission has to hold exactly the contacts made while it was on
// the air — so a contact records the calls as it is logged, and nothing
// that changes the operation afterwards may move the contacts behind it.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  Operation operation(String calls, {List<String>? off}) => Operation(uuid: 'op', data: {'stationCall': calls, stationCallsOffKey: ?off});

  Qso contact(String uuid, {List<String>? calls, String ourCall = 'N0A', int at = 1000}) => Qso(
    uuid: uuid,
    operationUuid: 'op',
    data: {
      'their': {'call': 'W1AW'},
      'our': {'call': ourCall, ourStationCallsKey: ?calls},
      'band': '20m',
      'startAtMillis': at,
    },
  );

  group('onAirStationCalls', () {
    test('leaves out the calls marked off', () {
      expect(onAirStationCalls(operation('N0A, N0B, N0C', off: ['N0B'])), ['N0A', 'N0C']);
    });

    test('puts every call back on the air rather than none', () {
      // A stale off-list synced from a device that saw a different list must
      // not leave the next contact belonging to no submission at all.
      expect(onAirStationCalls(operation('N0A, N0B', off: ['N0A', 'N0B'])), ['N0A', 'N0B']);
    });
  });

  group('qsoWithStationCalls', () {
    test('stamps a new contact with the calls on the air, first of them as our call', () {
      final stamped = qsoWithStationCalls({'band': '20m'}, operation('N0A, N0B', off: ['N0A']));
      expect(stamped['our'], {
        'call': 'N0B',
        ourStationCallsKey: ['N0B'],
      });
    });

    test('keeps the station call another program logged under, first and listed even when unchecked here', () {
      // WSJT-X ran as N0B: its contact is N0B's, whatever HaLo's checkboxes
      // say — they do not govern the other program. Restamped to N0A it would
      // leave N0B's submission.
      final stamped = qsoWithStationCalls({
        'band': '20m',
        'our': {'call': 'N0B'},
      }, operation('N0A, N0B, N0C', off: ['N0B']));
      expect(stamped['our'], {
        'call': 'N0B',
        ourStationCallsKey: ['N0B', 'N0A', 'N0C'],
      });
    });

    test('leaves a contact timed in a stretch run under other calls to that stretch', () {
      // Back-dated past a break that changed the calls: today's on-air set
      // says nothing about it, and stamped with it the contact would leave
      // the submissions of the calls it was made under.
      final qso = {'band': '20m'};
      expect(qsoWithStationCalls(qso, operation('N0C, N0D'), segment: {'stationCall': 'N0A, N0B'}), same(qso));
      expect(stationCallsOfOur(asQsonMap(qsoWithStationCalls(qso, operation('N0C, N0D'), segment: {'stationCall': 'N0C,N0D'})['our'])), ['N0C', 'N0D']);
    });

    test("leaves a contact naming another station's call alone", () {
      // Not one of the operation's calls: the import panels flag it, and a
      // stamp would hide it under ours.
      final qso = {
        'band': '20m',
        'our': {'call': 'W9XYZ'},
      };
      expect(qsoWithStationCalls(qso, operation('N0A, N0B')), same(qso));
    });

    test('leaves a one-call operation alone', () {
      // Its segment's call already says everything; a list would copy
      // our.call onto every contact of every ordinary log.
      final qso = {
        'band': '20m',
        'our': <String, dynamic>{'call': 'N0A'},
      };
      expect(qsoWithStationCalls(qso, operation('N0A')), same(qso));
    });

    test('never re-stamps a saved contact', () {
      // Re-saving an old contact to fix a typo must not hand it to whoever
      // is on the air now.
      final qso = {
        'uuid': 'q1',
        'band': '20m',
        'our': <String, dynamic>{'call': 'N0A'},
      };
      expect(qsoWithStationCalls(qso, operation('N0A, N0B', off: ['N0A'])), same(qso));
    });

    test('keeps calls a contact already names', () {
      final stamped = qsoWithStationCalls({
        'band': '20m',
        'our': {
          'call': 'N0A',
          ourStationCallsKey: ['N0A'],
        },
      }, operation('N0A, N0B'));
      expect(stationCallsOfOur(asQsonMap(stamped['our'])), ['N0A']);
    });

    test('reaches every contact logged through qsoWithOperator', () {
      // The one stamp every logging path already applies; a path that
      // stamped the operator and not the calls would file its contacts
      // under every call on the list.
      final stamped = qsoWithOperator({'band': '20m'}, operation('N0A, N0B', off: ['N0B']));
      expect(stationCallsOfOur(asQsonMap(stamped['our'])), ['N0A']);
    });
  });

  group('contactUsesStationCall', () {
    final segmented = SegmentedOperation.from(operation: operation('N0A, N0B').data, qsos: const []);

    test('a listed contact belongs only to the calls it lists', () {
      final qso = contact('q1', calls: ['N0A']);
      expect(contactUsesStationCall(qso, segmented, 'N0A'), isTrue);
      expect(contactUsesStationCall(qso, segmented, 'N0B'), isFalse, reason: 'N0B was off the air when it was made');
    });

    test('an unlisted contact belongs to every call of its segment', () {
      final qso = contact('q1');
      expect(contactUsesStationCall(qso, segmented, 'N0A'), isTrue);
      expect(contactUsesStationCall(qso, segmented, 'N0B'), isTrue);
    });
  });

  test('allStationCallsOf keeps a call taken off the list while contacts still name it', () {
    // Without it, removing N0B would drop N0B's submission without a word.
    final segmented = SegmentedOperation.from(operation: operation('N0A').data, qsos: const []);
    expect(
      allStationCallsOf(segmented, [
        contact('q1', calls: ['N0A', 'N0B']),
      ]),
      ['N0A', 'N0B'],
    );
  });

  group('freezeStationCallsUpdates', () {
    test('pins unlisted contacts to the calls they were made under', () {
      final updates = freezeStationCallsUpdates(operation('N0A').data, [
        contact('q1'),
        contact('q2', calls: ['N0A']),
      ]);
      expect(updates.map((qso) => qso.uuid), ['q1'], reason: 'a listed contact is never rewritten');
      expect(stationCallsOfOur(asQsonMap(updates.single.data['our'])), ['N0A']);
    });
  });

  group('respreadStationCallsUpdates', () {
    test('a corrected call replaces the typo only where it was', () {
      final updates = respreadStationCallsUpdates(
        [
          contact('typo', calls: ['N0A', 'N0BB'], ourCall: 'N0A'),
          contact('without', calls: ['N0A'], ourCall: 'N0A'),
        ],
        removed: {'N0BB'},
        added: ['N0B'],
        fromMillis: 0,
      );
      expect(
        {for (final qso in updates) qso.uuid: stationCallsOfOur(asQsonMap(qso.data['our']))},
        {
          'typo': ['N0A', 'N0B'],
        },
        reason: 'a contact made while the call was off does not gain it',
      );
    });

    test('a corrected first call stays first, and our.call names it', () {
      // Appended instead, the contact's our.call would become the second call
      // while the contacts listing nothing are restamped to the corrected
      // first — one operation split across two calls in the Logs view.
      final updates = respreadStationCallsUpdates(
        [
          contact('q1', calls: ['K1ABX', 'N0B'], ourCall: 'K1ABX'),
        ],
        removed: {'K1ABX'},
        added: ['K1ABC'],
        fromMillis: 0,
      );
      expect(stationCallsOfOur(asQsonMap(updates.single.data['our'])), ['K1ABC', 'N0B']);
      expect(updates.single.ourCall, 'K1ABC');
    });

    test('a call added outright joins every listed contact', () {
      final updates = respreadStationCallsUpdates(
        [
          contact('q1', calls: ['N0A']),
        ],
        removed: const {},
        added: ['N0C'],
        fromMillis: 0,
      );
      expect(stationCallsOfOur(asQsonMap(updates.single.data['our'])), ['N0A', 'N0C']);
    });

    test('a contact left with no call goes back to following its segment', () {
      final updates = respreadStationCallsUpdates(
        [
          contact('q1', calls: ['N0B'], ourCall: 'N0B'),
        ],
        removed: {'N0B'},
        added: const [],
        fromMillis: 0,
      );
      expect(stationCallsOfOur(asQsonMap(updates.single.data['our'])), isNull);
    });

    test('an earlier segment is left as it was', () {
      expect(
        respreadStationCallsUpdates(
          [
            contact('q1', calls: ['N0B'], at: 500),
          ],
          removed: {'N0B'},
          added: ['N0C'],
          fromMillis: 1000,
        ),
        isEmpty,
      );
    });
  });

  test('withStationCallsOff leaves the station call exactly as stored', () {
    // Respaced, it reads as a changed segment and the save restamps the log.
    final data = withStationCallsOff({'stationCall': 'N0A,N0B'}, {'N0B'});
    expect(data['stationCall'], 'N0A,N0B');
    expect(data[stationCallsOffKey], ['N0B']);
  });

  group('withStationCalls', () {
    test('keeps only off-marks for calls still listed', () {
      // A call removed while off and typed back later must join on the air.
      final data = withStationCalls(operation('N0A, N0B, N0C', off: ['N0B', 'N0C']).data, ['N0A', 'N0C', 'N0D']);
      expect(data['stationCall'], 'N0A, N0C, N0D');
      expect(data[stationCallsOffKey], ['N0C']);
    });

    test('drops the off-list for a single call', () {
      expect(withStationCalls(operation('N0A, N0B', off: ['N0B']).data, ['N0A']).containsKey(stationCallsOffKey), isFalse);
    });
  });
}
