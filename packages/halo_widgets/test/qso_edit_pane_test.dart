// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO edit pane's form reads a callsign lookup's guess for its entity line
// and its faint placeholders. Extensions assemble that guess and nothing
// enforces its types, so a cast on one wrong-typed field throws while the
// pane is built: the operator taps to edit a contact and no pane opens.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show locationForStatedGrid;
import 'package:halo_widgets/src/qso_edit_pane.dart' show buildQsoEditFormDefinition, gridFieldError, ourGridOverrides, theirEntityDisplay;

void main() {
  Map<String, dynamic> formFor(Map<String, dynamic> guess) => buildQsoEditFormDefinition(
    defaultOperatorCall: 'N0DEV',
    ourGridHint: null,
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

  group('ourGridOverrides', () {
    test('writes nothing for a field left as shown, whatever its case', () {
      // The uppercase formatter rewrites the whole field on any keystroke; a
      // case change read as an edit would pin the contact to its own
      // displayed square and drop the finer coordinate behind it.
      expect(ourGridOverrides('FN31PR', 'FN31pr'), isNull);
      expect(ourGridOverrides('', ''), isNull);
    });

    test('a typed locator brings its own center as the pair', () {
      final center = locationForStatedGrid('FN20aa')!;
      // `gridSource` goes too: left, a chase contact's `refs` would go on
      // telling ADIF the operator's square is a park's published one.
      expect(ourGridOverrides('fn20aa', 'FN31pr'), {'grid': 'FN20aa', 'gridSource': null, 'lat': center.latitude, 'lon': center.longitude});
    });

    test('emptied, all three go', () {
      // A grid cleared with its pair left behind would leave the contact
      // placed by a coordinate the operator just took away.
      expect(ourGridOverrides('  ', 'FN31pr'), {'grid': null, 'gridSource': null, 'lat': null, 'lon': null});
    });
  });

  test('a grid field refuses text that names no square, and nothing else', () {
    // An empty field clears the grid, which is the operator's to do; any
    // well-formed length and case is a square.
    for (final ok in ['', '  ', 'FN31', 'fn31pr', 'FN31PR', 'FN31pr44', 'FN31pr44ab']) {
      expect(gridFieldError(ok), isNull, reason: ok);
    }
    // Stored, each would be a square that names no place, and the pair
    // written with it would erase the coordinate the contact had.
    for (final bad in ['FN3', 'FN31p', 'FN31ZZ', 'HELLO', 'SS00']) {
      expect(gridFieldError(bad), 'Needs 4, 6, 8 or 10 characters, like FN31pr', reason: bad);
    }
  });

  test('Our grid hints the place the contact falls back to', () {
    final form = buildQsoEditFormDefinition(
      defaultOperatorCall: '',
      ourGridHint: 'FN31pr',
      defaultPosition: '',
      showPositionField: false,
      their: null,
      guess: null,
      rstPaneKeyOrder: const ['sent', 'rcvd'],
      rstPlaceholder: null,
      powerShown: false,
      composing: true,
      currentMode: 'SSB',
    );
    expect(placeholderOf(form, 'ourGrid'), 'FN31pr');
  });
}
