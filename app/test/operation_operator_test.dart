// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// operatorCallFor: who is at the key on THIS device, for an operation that
// several devices may be logging at once.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/tools/operation_operator.dart';

void main() {
  Operation operation({String? synced, Object? local}) => Operation(
        uuid: 'u',
        data: {'stationCall': 'K2SUL', if (synced != null) 'operatorCall': synced},
        localData: local == null ? const {} : {'operatorCall': local},
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
}
