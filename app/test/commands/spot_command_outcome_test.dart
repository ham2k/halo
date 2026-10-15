// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A spot or RESPOT the Spotting control has already run comes back to
// `handleCommandAction` only to be answered: its failure is what replaces
// the hook's hopeful confirm on the command bar that ran it.
import 'package:flutter_test/flutter_test.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("a panel-run spot's failure is the command's answer, and its success says nothing", () async {
    final services = (await makeHaLoServices()).services;
    final failed = await services.handleCommandAction('sendSpots', {'target': 'self', 'failure': 'pota failed: no alert'});
    expect(failed, (text: 'pota failed: no alert', failed: true), reason: 'null would let "Spotting…" stand for a spot that did not go out');
    expect(await services.handleCommandAction('autoRespot', {'failure': 'Set a frequency first.'}), (text: 'Set a frequency first.', failed: true));
    expect(await services.handleCommandAction('sendSpots', {'target': 'self'}), isNull, reason: 'the source icons already show a spot that went out');
    expect(await services.handleCommandAction('autoRespot', {}), isNull);
  });

  test('SPOTLAST is panel-run too: answered, never posted again here', () async {
    final services = (await makeHaLoServices()).services;
    expect(await services.handleCommandAction('sendSpots', {'target': 'last', 'failure': 'No QSO to spot yet.'}), (text: 'No QSO to spot yet.', failed: true));
    expect(await services.handleCommandAction('sendSpots', {'target': 'last'}), isNull, reason: 'posting it here would spot the station twice');
  });
}
