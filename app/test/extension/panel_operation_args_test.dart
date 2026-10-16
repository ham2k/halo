// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';

void main() {
  // A panel cannot resolve the operator itself: the position is device-local
  // and never crosses the bridge. Passing `operation.data` through unresolved
  // hands it the shared `operatorCall`, which in a multi-station operation is
  // nobody's seat, or a call left over from before positions were used.
  test('a panel is told who is at the key on this device, resolved for its position', () {
    final seated = Operation(
      uuid: 'u',
      data: const {'stationCall': 'K2SUL', 'operatorCall': 'W1OLD', 'operator2': 'B1B'},
      localData: const {'multiIdentifier': '2'},
    );
    expect(operationHookArgs(seated)['operatorCall'], 'B1B');

    final legacy = Operation(uuid: 'u', data: const {'stationCall': 'K2SUL'}, localData: const {'operatorCall': 'KI2D'});
    expect(operationHookArgs(legacy)['operatorCall'], 'KI2D', reason: 'an operation set up while the operator was device-local');

    final unseated = Operation(uuid: 'u', data: const {'stationCall': 'K2SUL', 'operatorCall': 'W1OLD'}, localData: const {'multiIdentifier': '2'});
    expect(operationHookArgs(unseated)['operatorCall'], '', reason: 'an empty seat names nobody, not the stale shared call');
  });
}
