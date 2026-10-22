// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO edit pane's form reads a callsign lookup's guess for its entity line
// and its faint placeholders. Extensions assemble that guess and nothing
// enforces its types, so a cast on one wrong-typed field throws while the
// pane is built: the operator taps to edit a contact and no pane opens.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/qso_edit_pane.dart' show buildQsoEditFormDefinition, theirEntityDisplay;

void main() {
  Map<String, dynamic> formFor(Map<String, dynamic> guess) => buildQsoEditFormDefinition(
    defaultOperatorCall: 'N0DEV',
    defaultPosition: '',
    showPositionField: false,
    their: const {'call': 'W1AW'},
    guess: guess,
    rstPaneKeyOrder: const ['sent', 'rcvd'],
    rstPlaceholder: '59',
    powerShown: false,
    composing: false,
    currentMode: 'SSB',
  );

  Object? placeholderOf(Map<String, dynamic> form, String key) =>
      (form['elements'] as List).cast<Map<String, dynamic>>().firstWhere((e) => e['key'] == key)['placeholder'];

  test('a wrong-typed guess field leaves its placeholder empty, and the others filled', () {
    final form = formFor({
      'name': 7,
      'city': 'Newington',
      'state': true,
      'entityPrefix': 'K',
      'county': 3,
      'arrlSection': ['CT'],
    });
    expect(placeholderOf(form, 'theirName'), isNull);
    expect(placeholderOf(form, 'theirCity'), 'Newington');
    expect(placeholderOf(form, 'theirState'), isNull);
    expect(placeholderOf(form, 'theirCounty'), isNull);
    expect(placeholderOf(form, 'theirArrlSection'), isNull);
  });

  test('the entity line shows the name alone when the guessed prefix is the wrong type, and nothing for a wrong-typed name', () {
    expect(theirEntityDisplay(null, {'entityName': 'United States', 'entityPrefix': 291}), 'United States');
    expect(theirEntityDisplay(null, {'entityName': 291, 'entityPrefix': 'K'}), isNull);
  });
}
