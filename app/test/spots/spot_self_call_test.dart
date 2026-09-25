// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `spotCallForSelfSpot` is where the app decides what callsign a self-spot
// goes out under — the one place the `/TEST` and `/OP<n>` suffixes are
// applied, so that no spot extension has to remember to. Every rule below is
// visible to hunters the moment it is wrong: a Test Operation spotted as a
// real one pulls chasers to a station that isn't there, and two devices of a
// multi-station operation spotting the same bare call collapse into one spot,
// which is the whole reason the identifier exists.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

Map<String, dynamic> op(String stationCall, {String? multiIdentifier}) => {
  'stationCall': stationCall,
  if (multiIdentifier != null) 'local': {'multiIdentifier': multiIdentifier},
};

void main() {
  test('an ordinary operation spots under its own call, untouched', () {
    expect(spotCallForSelfSpot(op('KI2D')), 'KI2D');
  });

  test('a multi-station operation appends this device\'s /OP<n>', () {
    expect(spotCallForSelfSpot(op('KI2D', multiIdentifier: '1')), 'KI2D/OP1');
    expect(spotCallForSelfSpot(op('KI2D', multiIdentifier: '2')), 'KI2D/OP2');
  });

  test('an empty identifier is not a multi-station operation', () {
    // The dialog stores '' rather than removing the key, so the empty case is
    // the one that actually reaches here once an operator clears the field —
    // and `KI2D/OP` would be a spot under a callsign that does not exist.
    expect(spotCallForSelfSpot(op('KI2D', multiIdentifier: '')), 'KI2D');
    expect(spotCallForSelfSpot({'stationCall': 'KI2D', 'local': <String, dynamic>{}}), 'KI2D');
  });

  test('the position is canonicalized on the way out, whatever the row holds', () {
    // The dialog and the POSITION command both store the canonical form, but
    // the air is the last place to catch a row that somehow holds another:
    // `/OP0` and `/OP02` are callsigns no hunter can use.
    expect(spotCallForSelfSpot(op('KI2D', multiIdentifier: '0')), 'KI2D');
    expect(spotCallForSelfSpot(op('KI2D', multiIdentifier: '02')), 'KI2D/OP2');
  });

  test('a position that arrived as a number rather than a string still works', () {
    // It crosses the extension bridge, where a cast would throw inside the
    // spot path and surface as a generic error naming nothing.
    expect(
      spotCallForSelfSpot({
        'stationCall': 'KI2D',
        'local': {'multiIdentifier': 2},
      }),
      'KI2D/OP2',
    );
  });

  test('an operation with no station call at all stays empty', () {
    // Never '/OP1': a suffix on nothing is a malformed call the spot API
    // would accept and hunters could not use.
    expect(spotCallForSelfSpot(op('', multiIdentifier: '1')), '');
  });

  test('both suffixes compose — a multi-station Test Operation keeps /TEST', () {
    // The two rules are independent, and a test session run from several
    // devices is exactly how the multi-station support gets exercised.
    expect(spotCallForSelfSpot(op('KI2D/T', multiIdentifier: '1')), 'KI2D/TEST/OP1');
  });

  test('/TEST reaches every call of a comma-separated station call, /OP<n> only the first', () {
    // app-polo appends the operator identifier to the main call alone,
    // spotting the extra calls (`stationCallPlusArray`) bare; `/TEST` marks
    // the whole session, so every call carries it.
    expect(spotCallForSelfSpot(op('KI2D,W1AW', multiIdentifier: '3')), 'KI2D/OP3,W1AW');
    expect(spotCallForSelfSpot(op('KI2D/T,W1AW/T', multiIdentifier: '3')), 'KI2D/TEST/OP3,W1AW/TEST');
  });
}
