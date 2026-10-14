// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A spot row accents its reference when that reference is new to a chasing
// program (docs/design/claims.md §8). Accenting it for a verdict about
// something else — a new DXCC entity, the other park of a two-park
// activation — points the operator at the wrong thing.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/spot_board.dart';

final _spot = <String, dynamic>{
  'their': {'call': 'K1ABC'},
  'band': '20m',
  'mode': 'CW',
  'refs': [
    {'type': 'pota', 'ref': 'US-0001'},
  ],
};

String _notice(String program, {ChaseVerdict verdict = ChaseVerdict.newRef, bool alerting = true}) =>
    ChaseNotice(program: program, verdict: verdict, alerting: alerting).key;

void main() {
  final key = spotCandidateKey('K1ABC', _spot);
  const pota = ChaseJudgement(program: 'pota', verdicts: [ChaseVerdict.newRef], refs: {'us-0001'});
  const dxcc = ChaseJudgement(program: 'dxcc', verdicts: [ChaseVerdict.newRef], refs: {'291'});

  test('the references a shown new-reference verdict names, upper-cased', () {
    expect(
      spotNewRefs(
        _spot,
        notices: {_notice('pota')},
        judgements: {
          key: [pota, dxcc],
        },
      ),
      {'US-0001'},
    );
  });

  // Outside the Chasing view only alerting verdicts become notices: one the
  // operator does not alert on must not accent the row either.
  // The Chasing view's notices carry every verdict, alerting or not, to order
  // its list. With new references switched off, the call is not accented, so
  // its park must not be either.
  test('a new-reference verdict the operator does not alert on accents nothing', () {
    expect(
      spotNewRefs(
        _spot,
        notices: {_notice('pota', alerting: false)},
        judgements: {
          key: [pota],
        },
      ),
      isEmpty,
    );
  });

  test('a verdict the row does not show accents nothing', () {
    expect(
      spotNewRefs(
        _spot,
        notices: {_notice('dxcc')},
        judgements: {
          key: [pota, dxcc],
        },
      ),
      {'291'},
    );
    expect(
      spotNewRefs(
        _spot,
        notices: const {},
        judgements: {
          key: [pota],
        },
      ),
      isEmpty,
    );
  });

  test('a new band names its reference but is not a new reference', () {
    const band = ChaseJudgement(program: 'pota', verdicts: [ChaseVerdict.newBand], refs: {'US-0001'});
    expect(
      spotNewRefs(
        _spot,
        notices: {_notice('pota')},
        judgements: {
          key: [band],
        },
      ),
      isEmpty,
    );
  });
}
