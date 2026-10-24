// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What working a station would do for a checklist (docs/design/claims.md §8).
// The verdict orders the Chasing view's spots and decides which alert, so a
// wrong one sends the operator after a station they already have, or past
// one they need.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

/// DXCC's three claims for one entity: Mixed, its band, its mode.
List<QsoClaim> _entity(String ref, {String band = '20m', String mode = 'CW', bool guess = false}) => [
  QsoClaim(holder: 'KI2D@291', ref: ref, band: null, mode: null, level: ClaimLevel.worked, guess: guess),
  QsoClaim(holder: 'KI2D@291', ref: ref, band: band, mode: null, level: ClaimLevel.worked, guess: guess),
  QsoClaim(holder: 'KI2D@291', ref: ref, band: null, mode: mode, level: ClaimLevel.worked, guess: guess),
];

Map<String, ClaimLevel> _held(Map<QsoClaim, ClaimLevel> slots) => {for (final MapEntry(:key, :value) in slots.entries) chaseSlotKey(key): value};

void main() {
  group('judgeChaseClaims', () {
    test('a reference with no slot at all is new, and says nothing about its band or mode', () {
      final judged = judgeChaseClaims('dxcc', _entity('339'), const {});
      expect(judged!.verdicts, [ChaseVerdict.newRef]);
      expect(judged.rank, 3);
    });

    // A contact hunting two parks, one new: the spot row accents its park
    // only when that park is the new one, not the one already hunted.
    test('a new reference names the references the checklist lacks, and only those', () {
      List<QsoClaim> park(String ref) => [QsoClaim(holder: 'KI2D', ref: ref, band: null, mode: null, level: ClaimLevel.worked)];
      final held = _held({park('US-0001').single: ClaimLevel.worked});
      expect(judgeChaseClaims('pota', [...park('US-0001'), ...park('US-0002')], held)!.refs, {'US-0002'});
    });

    test('a worked reference on a new band and a new mode is both, at one rank', () {
      final claims = _entity('339');
      final held = _held({claims[0]: ClaimLevel.confirmed, _entity('339', band: '40m', mode: 'PHONE')[1]: ClaimLevel.worked});
      expect(judgeChaseClaims('dxcc', claims, held)!.verdicts, [ChaseVerdict.newBand, ChaseVerdict.newMode]);
      expect(ChaseVerdict.newBand.rank, ChaseVerdict.newMode.rank);
    });

    // A program words its notice by what is new ("DXCC in 80m"), so the
    // judgement says which band and which mode.
    test('a new band and a new mode say which band and mode they are', () {
      final claims = _entity('339', band: '80m', mode: 'PHONE');
      final both = judgeChaseClaims('dxcc', claims, _held({claims[0]: ClaimLevel.confirmed}))!;
      expect((both.band, both.mode), ('80m', 'PHONE'));
      final bandOnly = judgeChaseClaims('dxcc', claims, _held({claims[0]: ClaimLevel.confirmed, claims[2]: ClaimLevel.worked}))!;
      expect((bandOnly.band, bandOnly.mode), ('80m', null));
      expect(judgeChaseClaims('dxcc', claims, const {})!.band, isNull, reason: 'a new reference is about neither');
    });

    test('only the band missing is a new band', () {
      final claims = _entity('339');
      final held = _held({claims[0]: ClaimLevel.confirmed, claims[2]: ClaimLevel.confirmed});
      expect(judgeChaseClaims('dxcc', claims, held)!.verdicts, [ChaseVerdict.newBand]);
    });

    // Every slot filled, one only worked: working the station again is a
    // second chance at the QSL that would confirm it.
    test('every slot filled but one still at worked is unconfirmed', () {
      final claims = _entity('339');
      final held = _held({claims[0]: ClaimLevel.confirmed, claims[1]: ClaimLevel.worked, claims[2]: ClaimLevel.verified});
      expect(judgeChaseClaims('dxcc', claims, held)!.verdicts, [ChaseVerdict.unconfirmed]);
    });

    test('every slot confirmed or better is worked', () {
      final claims = _entity('339');
      final held = _held({for (final claim in claims) claim: ClaimLevel.confirmed});
      expect(judgeChaseClaims('dxcc', claims, held)!.verdicts, [ChaseVerdict.worked]);
    });

    test('a slot held by another holder is not this one\'s', () {
      final mine = _entity('339');
      final portable = [for (final claim in _entity('339')) QsoClaim(holder: 'KI2D@1', ref: claim.ref, band: claim.band, mode: claim.mode, level: claim.level)];
      expect(judgeChaseClaims('dxcc', mine, _held({for (final claim in portable) claim: ClaimLevel.confirmed}))!.verdicts, [ChaseVerdict.newRef]);
    });

    test('a guessed reference is probably new, and a guess among what is not new does not taint it', () {
      expect(judgeChaseClaims('was', _entity('NY', guess: true), const {})!.guess, isTrue);
      final park = _entity('US-0001');
      final guessed = _entity('NY', guess: true);
      final held = _held({for (final claim in guessed) claim: ClaimLevel.confirmed});
      final judged = judgeChaseClaims('mixed', [...park, ...guessed], held)!;
      expect(judged.verdicts, [ChaseVerdict.newRef]);
      expect(judged.guess, isFalse, reason: 'the new reference is the reported one');
    });

    test('a candidate that claims nothing is not judged', () {
      expect(judgeChaseClaims('dxcc', const [], const {}), isNull);
    });
  });

  group('ChaseNotice', () {
    test('a key reads back as the notice it was made from', () {
      const notice = ChaseNotice(program: 'pota', verdict: ChaseVerdict.newBand, guess: true, alerting: true);
      final read = ChaseNotice.tryParse(notice.key)!;
      expect((read.program, read.verdict, read.guess, read.alerting), ('pota', ChaseVerdict.newBand, true, true));
      expect(ChaseNotice.tryParse(const ChaseNotice(program: 'dxcc', verdict: ChaseVerdict.newRef).key)!.alerting, isFalse);
    });

    test('a band or mode reads back too, whatever it holds, and an older key reads without them', () {
      const notice = ChaseNotice(program: 'ham2k-dxcc', verdict: ChaseVerdict.newMode, alerting: true, mode: 'A:B=C');
      final read = ChaseNotice.tryParse(notice.key)!;
      expect((read.program, read.verdict, read.alerting, read.band, read.mode), ('ham2k-dxcc', ChaseVerdict.newMode, true, null, 'A:B=C'));
      expect(ChaseNotice.tryParse(const ChaseNotice(program: 'dxcc', verdict: ChaseVerdict.newBand, band: '80m').key)!.band, '80m');
      final older = ChaseNotice.tryParse('chase:dxcc:newBand:guess:alert')!;
      expect((older.guess, older.alerting, older.band), (true, true, null));
    });

    test("a scorer's own key is not a chasing notice", () {
      for (final key in ['newBand', 'duplicate', 'chase:', 'chase:dxcc', 'chase:dxcc:bogus', 'chase::newRef']) {
        expect(ChaseNotice.tryParse(key), isNull, reason: key);
      }
    });
  });
}
