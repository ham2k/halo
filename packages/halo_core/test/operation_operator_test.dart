// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// operatorCallFor: who is at the key, for an operation several devices may be
// logging at once — the operator is the operation's SYNCED data, stored per
// POSITION when this device is in one — and qsoWithOperator, which is how that
// reaches a contact: a QSO that derived it at export time would name whoever
// happened to be sitting there when the file was written.

import 'package:test/test.dart';
import 'package:halo_core/halo_core.dart';


void main() {
  Operation operation({String? synced, String? seated, Object? legacyLocal, String? position}) => Operation(
        uuid: 'u',
        data: {
          'stationCall': 'K2SUL',
          if (synced != null) 'operatorCall': synced,
          if (seated != null) operatorCallKeyFor(position ?? ''): seated,
        },
        localData: {
          if (legacyLocal != null) 'operatorCall': legacyLocal,
          if (position != null) 'multiIdentifier': position,
        },
      );

  group('operatorCallKeyFor', () {
    // The slot has to be derived from the position and nowhere else: a writer
    // that picked its own name would store an operator no reader ever finds.
    test('names the position it belongs to', () {
      expect(operatorCallKeyFor(''), 'operatorCall');
      expect(operatorCallKeyFor('1'), 'operator1');
      expect(operatorCallKeyFor('12'), 'operator12');
    });
  });

  group('operatorCallFor', () {
    test("reads the operation's operator when this device sits in no position", () {
      expect(operatorCallFor(operation(synced: 'KI2D')), 'KI2D');
    });

    test('names nobody when nothing says who is at the key', () {
      expect(operatorCallFor(operation()), '');
    });

    // The whole point of the per-position slots: several operators log one
    // operation under one station call, and each device must name the one in
    // ITS seat rather than converge on a single shared callsign.
    test("reads this position's own operator", () {
      expect(operatorCallFor(operation(position: '2', seated: 'W2ABC')), 'W2ABC');
    });

    // `operatorCall` is the positionless slot and nothing else. A device in a
    // seat reading through to it would show — and stamp — the operator of a
    // device that is not in a seat at all.
    test('a position does not fall back to the positionless operator', () {
      expect(operatorCallFor(operation(position: '2', synced: 'KI2D')), '');
    });

    test('a position reads its own slot, not another seat’s', () {
      final operation = Operation(
        uuid: 'u',
        data: const {'operator1': 'KI2D', 'operator2': 'W2ABC'},
        localData: const {'multiIdentifier': '1'},
      );
      expect(operatorCallFor(operation), 'KI2D');
    });

    // The migration path. An operation logged while the operator was
    // device-local carries it in localData, and must keep naming that
    // operator until something writes the slot — otherwise upgrading silently
    // blanks the header on an operation already under way.
    test('falls back to the legacy device-local operator while no slot exists', () {
      expect(operatorCallFor(operation(legacyLocal: 'KI2D')), 'KI2D');
      expect(operatorCallFor(operation(position: '2', legacyLocal: 'KI2D')), 'KI2D');
    });

    test('the slot outranks the legacy device-local value', () {
      expect(operatorCallFor(operation(synced: 'W2ABC', legacyLocal: 'KI2D')), 'W2ABC');
    });

    // The trap the key-presence check exists for. A fallback keyed on the
    // value being EMPTY reads the legacy local operator back the instant the
    // slot is cleared — so the operator deletes the callsign, watches the old
    // one reappear, and has nothing they can type to remove it.
    test('clearing the slot stays cleared, and does not resurrect the legacy value', () {
      expect(operatorCallFor(operation(synced: '', legacyLocal: 'KI2D')), '');
    });

    test('surrounding space never reaches a callsign', () {
      expect(operatorCallFor(operation(synced: '  KI2D  ')), 'KI2D');
      expect(operatorCallFor(operation(legacyLocal: '  KI2D  ')), 'KI2D');
    });

    // localData is stored as-is rather than QSON-normalized, so a value that
    // is not a string is reachable there in a way it is not on `data`.
    test('a non-string legacy value reads as empty', () {
      expect(operatorCallFor(operation(legacyLocal: 42)), '');
    });
  });

  group('qsoWithOperator', () {
    Map<String, dynamic> our(Map<String, dynamic> qso) => (qso['our'] as Map).cast<String, dynamic>();

    test('stamps the operator of the position this device is logging as', () {
      final stamped = qsoWithOperator({'their': {'call': 'W1AW'}}, operation(position: '2', seated: 'KI2D'));

      expect(our(stamped), {'operatorCall': 'KI2D', 'multiIdentifier': '2'});
    });

    // The whole point of stamping at log time: the seat's operator moves on
    // when the next one sits down, and a contact already logged must keep
    // naming the one who made it.
    test('a value already on the QSO wins over the operation', () {
      final stamped = qsoWithOperator(
        {'our': {'operatorCall': 'W2ABC', 'multiIdentifier': '1'}},
        operation(position: '2', seated: 'KI2D'),
      );

      expect(our(stamped), {'operatorCall': 'W2ABC', 'multiIdentifier': '1'});
    });

    test('an empty operator on the QSO is a value, not an absence', () {
      final stamped = qsoWithOperator({'our': {'operatorCall': ''}}, operation(synced: 'KI2D'));

      expect(our(stamped)['operatorCall'], '');
    });

    // The record already exists — it carries its own uuid. Anyone can open a
    // contact to fix a typo, and a log made before an operator was ever named
    // must not become a log made by whoever opened it. Blank stays blank, in
    // the record and in the export.
    test('a contact already in the log is never stamped', () {
      final existing = {'uuid': 'q1', 'their': {'call': 'W1AW'}};

      expect(qsoWithOperator(existing, operation(position: '2', seated: 'KI2D')), existing);
    });

    test('the position is stamped in its canonical form', () {
      expect(our(qsoWithOperator({}, operation(position: '02')))['multiIdentifier'], '2');
      // `0` is how POSITION turns the position off — no position, no field.
      expect(qsoWithOperator({}, operation(position: '0')), isNot(contains('our')));
    });

    // A seat that names nobody stamps nobody: reading through to the
    // positionless `operatorCall` here would mark every contact this device
    // logs with another operator's callsign — permanently, and in the
    // exported log.
    test('a positionless operator is not stamped onto a seat that names nobody', () {
      final stamped = qsoWithOperator({'their': {'call': 'W1AW'}}, operation(position: '2', synced: 'W1ABC'));

      expect(our(stamped), {'multiIdentifier': '2'});
    });

    test('nothing is written when the operation names neither', () {
      expect(qsoWithOperator({'their': {'call': 'W1AW'}}, operation()), {'their': {'call': 'W1AW'}});
    });

    // A break marker has no operator, and stamping one would put a callsign
    // on a row that is not a contact at all.
    test('event rows are left alone', () {
      final marker = {'band': 'event', 'event': {'event': 'break'}};

      expect(qsoWithOperator(marker, operation(position: '2', seated: 'KI2D')), marker);
    });

    test('does not mutate the QSO it was given', () {
      final original = {'our': {'grid': 'FN31'}};

      qsoWithOperator(original, operation(synced: 'KI2D'));

      expect(original, {'our': {'grid': 'FN31'}});
    });
  });
}
