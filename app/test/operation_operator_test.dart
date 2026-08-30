// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// operatorCallFor: who is at the key on THIS device, for an operation that
// several devices may be logging at once, and qsoWithOperator, which is how
// that reaches a contact — a QSO that derived it at export time would name
// whoever happened to be sitting there when the file was written.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/tools/operation_operator.dart';

void main() {
  Operation operation({String? synced, Object? local, String? position}) => Operation(
        uuid: 'u',
        data: {'stationCall': 'K2SUL', if (synced != null) 'operatorCall': synced},
        localData: {
          if (local != null) 'operatorCall': local,
          if (position != null) 'multiIdentifier': position,
        },
      );

  group('operatorCallFor', () {
    test("reads this device's own operator", () {
      expect(operatorCallFor(operation(local: 'KI2D')), 'KI2D');
    });

    test('names nobody when neither device nor operation says', () {
      expect(operatorCallFor(operation()), '');
    });

    // The migration path. An operation created before the operator became
    // device-local carries it in the synced data, and every device that has
    // never set its own must keep naming that operator — otherwise upgrading
    // silently blanks the header on an operation already under way.
    test('falls back to the synced operator while this device has set none', () {
      expect(operatorCallFor(operation(synced: 'KI2D')), 'KI2D');
    });

    test("this device's own operator outranks the synced one", () {
      expect(operatorCallFor(operation(synced: 'KI2D', local: 'W2ABC')), 'W2ABC');
    });

    // The trap the key-presence check exists for. A fallback keyed on the
    // value being EMPTY reads the synced operator back the instant this
    // device clears the field — so the operator deletes the callsign, watches
    // the old one reappear, and has nothing they can type to remove it.
    test('clearing stays cleared, and does not resurrect the synced operator', () {
      expect(operatorCallFor(operation(synced: 'KI2D', local: '')), '');
    });

    test('surrounding space never reaches a callsign', () {
      expect(operatorCallFor(operation(local: '  KI2D  ')), 'KI2D');
      expect(operatorCallFor(operation(synced: '  KI2D  ')), 'KI2D');
    });

    // localData is stored as-is rather than QSON-normalized, so a value that
    // is not a string is reachable here in a way it is not on `data`. The key
    // is still PRESENT, so this must read as "this device set nothing
    // meaningful", never as a reason to fall back to another device's answer.
    test('a non-string local value reads as empty rather than falling back', () {
      expect(operatorCallFor(operation(synced: 'KI2D', local: 42)), '');
    });
  });

  group('qsoWithOperator', () {
    Map<String, dynamic> our(Map<String, dynamic> qso) => (qso['our'] as Map).cast<String, dynamic>();

    test('stamps the operator and the position this device is logging as', () {
      final stamped = qsoWithOperator({'their': {'call': 'W1AW'}}, operation(local: 'KI2D', position: '2'));

      expect(our(stamped), {'operatorCall': 'KI2D', 'multiIdentifier': '2'});
    });

    // The whole point of stamping at log time: the operation's own value moves
    // on when the next operator sits down, and a contact already logged must
    // keep naming the one who made it.
    test('a value already on the QSO wins over the operation', () {
      final stamped = qsoWithOperator(
        {'our': {'operatorCall': 'W2ABC', 'multiIdentifier': '1'}},
        operation(local: 'KI2D', position: '2'),
      );

      expect(our(stamped), {'operatorCall': 'W2ABC', 'multiIdentifier': '1'});
    });

    // Re-saving an edit runs through here again. Anyone can fix a typo in a
    // contact they did not make, and doing so must not reassign it to them.
    test('an empty operator on the QSO is a value, not an absence', () {
      final stamped = qsoWithOperator({'our': {'operatorCall': ''}}, operation(local: 'KI2D'));

      expect(our(stamped)['operatorCall'], '');
    });

    test('the position is stamped in its canonical form', () {
      expect(our(qsoWithOperator({}, operation(position: '02')))['multiIdentifier'], '2');
      // `0` is how POSITION turns the position off — no position, no field.
      expect(qsoWithOperator({}, operation(position: '0')), isNot(contains('our')));
    });

    test('nothing is written when the operation names neither', () {
      expect(qsoWithOperator({'their': {'call': 'W1AW'}}, operation()), {'their': {'call': 'W1AW'}});
    });

    // A break marker has no operator, and stamping one would put a callsign
    // on a row that is not a contact at all.
    test('event rows are left alone', () {
      final marker = {'band': 'event', 'event': {'event': 'break'}};

      expect(qsoWithOperator(marker, operation(local: 'KI2D', position: '2')), marker);
    });

    test('does not mutate the QSO it was given', () {
      final original = {'our': {'grid': 'FN31'}};

      qsoWithOperator(original, operation(local: 'KI2D'));

      expect(original, {'our': {'grid': 'FN31'}});
    });
  });
}
