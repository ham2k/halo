// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How a spot decides to strike itself through. The scoring itself happens in
// the extension runtime (extensions/sdk/src/scoreCandidates.test.ts); what
// these tests pin down is the Dart side's two ways of getting it wrong — asking
// the question about the wrong thing, and reading the answer back against the
// wrong spot.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

Map<String, dynamic> _spot({required String call, double? freq, String? band, String? mode, List<Map<String, dynamic>>? refs}) => {
  'their': {'call': call},
  'freq': ?freq,
  'band': ?band,
  'mode': ?mode,
  'refs': refs ?? const <Map<String, dynamic>>[],
  'spot': {'timeInMillis': 1000, 'source': 'test'},
};

({List<String> notices, List<String> alerts}) _dupe() => (notices: const [], alerts: const ['duplicate']);
({List<String> notices, List<String> alerts}) _notice(String key) => (notices: [key], alerts: const []);

void main() {
  group('spotCandidateKey', () {
    // The key is what dedupes the question. Two sources spotting the same
    // operator on the same band/mode/park is one question, and asking it twice
    // costs a scoresheet copy per extra spot on a busy board.
    test('the same operator on the same band, mode and refs asks once', () {
      final a = _spot(
        call: 'K1ABC',
        band: '20m',
        mode: 'SSB',
        refs: [
          {'type': 'pota', 'ref': 'US-0001'},
        ],
      );
      final b = _spot(
        call: 'K1ABC',
        freq: 14285.5,
        band: '20m',
        mode: 'SSB',
        refs: [
          {'type': 'pota', 'ref': 'US-0001'},
        ],
      );
      expect(spotCandidateKey('K1ABC', a), spotCandidateKey('K1ABC', b));
    });

    // Frequency is deliberately NOT in the key — no scorer judges on it, and
    // including it would ask the same question once per spotted frequency.
    test('a different frequency alone is the same question', () {
      final a = _spot(call: 'K1ABC', freq: 14285.0, band: '20m', mode: 'SSB');
      final b = _spot(call: 'K1ABC', freq: 14290.0, band: '20m', mode: 'SSB');
      expect(spotCandidateKey('K1ABC', a), spotCandidateKey('K1ABC', b));
    });

    // Band and mode are what the core dupe rule turns on, so collapsing them
    // into one key would strike a spot the operator has not worked on that band.
    test('band and mode each split the question', () {
      final base = _spot(call: 'K1ABC', band: '20m', mode: 'SSB');
      expect(spotCandidateKey('K1ABC', base), isNot(spotCandidateKey('K1ABC', _spot(call: 'K1ABC', band: '40m', mode: 'SSB'))));
      expect(spotCandidateKey('K1ABC', base), isNot(spotCandidateKey('K1ABC', _spot(call: 'K1ABC', band: '20m', mode: 'CW'))));
    });

    // Activity scorers judge per hunted reference, so a station spotted at two
    // parks is two questions with two answers.
    test('the reference set splits the question, regardless of its order', () {
      final one = _spot(
        call: 'K1ABC',
        band: '20m',
        mode: 'SSB',
        refs: [
          {'type': 'pota', 'ref': 'US-0001'},
        ],
      );
      final two = _spot(
        call: 'K1ABC',
        band: '20m',
        mode: 'SSB',
        refs: [
          {'type': 'pota', 'ref': 'US-0002'},
        ],
      );
      expect(spotCandidateKey('K1ABC', one), isNot(spotCandidateKey('K1ABC', two)));

      final forwards = _spot(
        call: 'K1ABC',
        band: '20m',
        mode: 'SSB',
        refs: [
          {'type': 'pota', 'ref': 'US-0001'},
          {'type': 'pota', 'ref': 'US-0002'},
        ],
      );
      final backwards = _spot(
        call: 'K1ABC',
        band: '20m',
        mode: 'SSB',
        refs: [
          {'type': 'pota', 'ref': 'US-0002'},
          {'type': 'pota', 'ref': 'US-0001'},
        ],
      );
      expect(spotCandidateKey('K1ABC', forwards), spotCandidateKey('K1ABC', backwards));
    });
  });

  group('spotCandidateQso', () {
    // Activity scoring buckets a contact by floor(startAtMillis / day). A
    // candidate with no timestamp lands on the epoch, which is never any real
    // contact's day — so every already-worked station would come back as
    // `newDay` instead of `duplicate` and nothing would ever strike through.
    test('carries the moment it would be worked', () {
      final qso = spotCandidateQso('K1ABC', _spot(call: 'K1ABC', band: '20m'), now: 1735689600000);
      expect(qso['startAtMillis'], 1735689600000);
    });

    // The compound call of a merged multi-op spot is not a callsign any scorer
    // would recognize, so the candidate carries the ONE operator it is about.
    test('carries the single operator it was built for, not the spot call', () {
      final qso = spotCandidateQso('W2XYZ', _spot(call: 'K1ABC,W2XYZ', band: '20m'), now: 1);
      expect((qso['their'] as Map)['call'], 'W2XYZ');
    });

    // Scorers key their worked-call tables on the raw string and logged calls
    // and modes are always uppercase. POTA passes its API's `activator` and
    // `mode` straight through and SOTA its `activatorCallsign`, so a lower-case
    // spot would never match a station the operator has actually worked — it
    // would simply never strike through, with nothing to show anything is wrong.
    test('uppercases the call and mode a scorer will string-match', () {
      final qso = spotCandidateQso('g4abc/p', _spot(call: 'g4abc/p', band: '20m', mode: 'cw'), now: 1);
      expect((qso['their'] as Map)['call'], 'G4ABC/P');
      expect(qso['mode'], 'CW');
    });

    // The key has to fold the same way, or the panel looks up a verdict under a
    // key the scoring pass never sent.
    test('the key ignores callsign and mode casing', () {
      final lower = _spot(call: 'g4abc/p', band: '20m', mode: 'cw');
      final upper = _spot(call: 'G4ABC/P', band: '20m', mode: 'CW');
      expect(spotCandidateKey('g4abc/p', lower), spotCandidateKey('G4ABC/P', upper));
    });
  });

  group('spotDisplayFlags', () {
    final worked = _spot(call: 'K1ABC', band: '20m', mode: 'SSB');

    test('a duplicate verdict strikes the spot through', () {
      final flags = spotDisplayFlags(worked, scores: {spotCandidateKey('K1ABC', worked): _dupe()});
      expect(flags.worked, isTrue);
    });

    // An unscored spot must render as an ordinary one. Treating "no verdict" as
    // worked would strike the whole board through for the seconds before the
    // first scoring pass lands, and forever if the runtime never comes up.
    test('an unscored spot is not worked', () {
      expect(spotDisplayFlags(worked, scores: const {}).worked, isFalse);
    });

    // The conservative direction, and the reason this is `every` rather than
    // `any`: a merged multi-op spot is one row for several stations, so
    // striking it because one has been worked hides the ones that have not —
    // and a missed contact costs more than a redundant glance.
    test('a multi-op spot is worked only when every operator is', () {
      final multi = _spot(call: 'K1ABC,W2XYZ', band: '20m', mode: 'SSB');
      final oneWorked = {spotCandidateKey('K1ABC', multi): _dupe()};
      expect(spotDisplayFlags(multi, scores: oneWorked).worked, isFalse);

      final bothWorked = {...oneWorked, spotCandidateKey('W2XYZ', multi): _dupe()};
      expect(spotDisplayFlags(multi, scores: bothWorked).worked, isTrue);
    });

    // Alerts and notices are unioned across every scorer, and a scorer reports
    // a QSO as new on an axis only when it is NOT that scorer's duplicate — so
    // both at once means two scorers disagreed. The POTA case: a hunter worked
    // K1ABC at one park, K1ABC is now spotted at another. Core calls it a dupe
    // (same call, band and mode), POTA calls it a new reference. Striking it
    // hides the contact worth making, which is the failure this whole function
    // is written to avoid.
    test('a notice from another scorer un-strikes the spot', () {
      final flags = spotDisplayFlags(
        worked,
        scores: {
          spotCandidateKey('K1ABC', worked): (notices: const ['newRef'], alerts: const ['duplicate']),
        },
      );
      expect(flags.worked, isFalse);
      expect(flags.notices, {'newRef'});
    });

    // Notices only ever add an accent, so they merge across operators where
    // `worked` intersects — a multiplier one operator would bring is still
    // worth flagging on the row.
    test('notices merge across a multi-op spot\'s operators', () {
      final multi = _spot(call: 'K1ABC,W2XYZ', band: '20m', mode: 'SSB');
      final flags = spotDisplayFlags(
        multi,
        scores: {spotCandidateKey('K1ABC', multi): _notice('newBand'), spotCandidateKey('W2XYZ', multi): _notice('newMult')},
      );
      expect(flags.notices, {'newBand', 'newMult'});
    });

    // The verdict is looked up per operator against THIS spot's band/mode/refs.
    // A key built from the compound call would match nothing, leaving every
    // multi-op spot permanently unscored.
    test('a verdict for another band does not reach this spot', () {
      final onForty = _spot(call: 'K1ABC', band: '40m', mode: 'SSB');
      final flags = spotDisplayFlags(onForty, scores: {spotCandidateKey('K1ABC', worked): _dupe()});
      expect(flags.worked, isFalse);
    });

    test('our own station call is flagged as self', () {
      expect(spotDisplayFlags(worked, scores: const {}, ourBaseCalls: {'K1ABC'}).isSelf, isTrue);
      expect(spotDisplayFlags(worked, scores: const {}, ourBaseCalls: {'W9ZZZ'}).isSelf, isFalse);
      expect(spotDisplayFlags(worked, scores: const {}).isSelf, isFalse);
    });

    // The spot carries whatever suffix the spotter heard; the station call
    // may carry none — an exact match leaves KI2D/P untinted for KI2D.
    test('a spot of our base call with an indicator is self', () {
      final portable = _spot(call: 'K1ABC/P', band: '20m', mode: 'SSB');
      expect(spotDisplayFlags(portable, scores: const {}, ourBaseCalls: {'K1ABC'}).isSelf, isTrue);
      expect(spotDisplayFlags(portable, scores: const {}, ourBaseCalls: {'W9ZZZ', 'K1ABC'}).isSelf, isTrue);
      expect(
        spotDisplayFlags(
          _spot(call: 'K1ABCD', band: '20m'),
          scores: const {},
          ourBaseCalls: {'K1ABC'},
        ).isSelf,
        isFalse,
      );
    });

    // Our own call within a merged multi-op spot still identifies the row as
    // ours; the compound never matches the station call directly.
    test('our station call inside a multi-op spot is still self', () {
      final multi = _spot(call: 'K1ABC,W2XYZ', band: '20m', mode: 'SSB');
      expect(spotDisplayFlags(multi, scores: const {}, ourBaseCalls: {'W2XYZ'}).isSelf, isTrue);
    });

    // A call-less spot is a malformed hook result (Spot.their.call is required
    // by the SDK type but nothing enforces it across the bridge). It must not
    // strike itself through on the strength of having no operators to check.
    test('a call-less spot is neither worked nor self', () {
      final flags = spotDisplayFlags(
        _spot(call: '', band: '20m'),
        scores: const {},
        ourBaseCalls: {'K1ABC'},
      );
      expect(flags.worked, isFalse);
      expect(flags.isSelf, isFalse);
    });
  });
}
