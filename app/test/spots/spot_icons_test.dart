// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/spot_board.dart';

Map<String, dynamic> _control(String refType, String icon, {String? color, List<String>? alsoHandles}) => {
  'icon': icon,
  'color': ?color,
  'input': {'refType': refType, 'alsoHandles': ?alsoHandles},
};

final _controls = [
  _control('pota', 'pine-tree', color: '#068541'),
  _control('sota', 'image-filter-hdr', color: '#A0522D'),
  _control('wwff', 'flower', color: '#2E7D32'),
  _control('texas-qso-party', 'star-box', alsoHandles: ['qp/tx']),
];

Map<String, dynamic> _spot(List<Map<String, dynamic>> refs, {String? icon, String call = 'KI2D'}) => {
  'their': {'call': call},
  'band': '20m',
  'mode': 'CW',
  'refs': refs,
  'icon': ?icon,
  'spot': {'timeInMillis': 0, 'source': 'test'},
};

void main() {
  group('spotRefIcons', _refIcons);
  group('spotIcons', _spotIcons);
  group('spotIconsWithin', _within);
}

void _refIcons() {
  test('a park and a summit show both icons, in the order the spot names them', () {
    final icons = spotRefIcons(
      _spot([
        {'type': 'sota', 'ref': 'W2/GC-001'},
        {'type': 'pota', 'ref': 'US-1234'},
      ]),
      _controls,
    );
    expect(icons, [(icon: 'image-filter-hdr', color: '#A0522D'), (icon: 'pine-tree', color: '#068541')]);
  });

  // A two-fer — two parks of one program — is still one kind of reference.
  test('two references of one kind show its icon once', () {
    final icons = spotRefIcons(
      _spot([
        {'type': 'pota', 'ref': 'US-1234'},
        {'type': 'pota', 'ref': 'US-5678'},
      ]),
      _controls,
    );
    expect(icons, [(icon: 'pine-tree', color: '#068541')]);
  });

  test('references no installed activity handles share the spot\'s own icon, untinted', () {
    final icons = spotRefIcons(
      _spot([
        {'type': 'iota', 'ref': 'NA-001'},
        {'type': 'pota', 'ref': 'US-1234'},
        {'type': 'bota', 'ref': 'B/G-0001'},
      ], icon: 'bell-ring'),
      _controls,
    );
    expect(icons, [(icon: 'bell-ring', color: null), (icon: 'pine-tree', color: '#068541')]);
  });

  // A source that brands its spots with the activity's own icon would
  // otherwise draw it twice, once tinted and once not.
  test('an icon name is drawn once, with its first reference\'s accent', () {
    final icons = spotRefIcons(
      _spot([
        {'type': 'pota', 'ref': 'US-1234'},
        {'type': 'iota', 'ref': 'NA-001'},
      ], icon: 'pine-tree'),
      _controls,
    );
    expect(icons, [(icon: 'pine-tree', color: '#068541')]);
  });

  test('a spot with no references shows its own icon, else a tower', () {
    expect(spotRefIcons(_spot([], icon: 'bell-ring'), _controls), [(icon: 'bell-ring', color: null)]);
    expect(spotRefIcons(_spot([]), _controls), [(icon: 'radio-tower', color: null)]);
  });

  // Without the reference's code, a claim like `qp/tx` matches nothing and the
  // row draws the unknown-reference icon for a party that is installed.
  test('a reference an activity claims by prefix shows that activity\'s icon', () {
    final icons = spotRefIcons(
      _spot([
        {'type': 'qp', 'ref': 'TX'},
      ]),
      _controls,
    );
    expect(icons, [(icon: 'star-box', color: null)]);
  });
}

String _alerting(String program) => ChaseNotice(program: program, verdict: ChaseVerdict.newRef, alerting: true).key;

void _spotIcons() {
  final parkSpot = _spot([
    {'type': 'pota', 'ref': 'US-1234'},
  ]);
  final key = spotCandidateKey('KI2D', parkSpot);
  const dxcc = ChaseJudgement(program: 'dxcc', verdicts: [ChaseVerdict.newRef]);
  const programs = {
    'dxcc': ChasingProgram(key: 'dxcc', label: 'DXCC', version: 1, editions: ChasingEditions.lifetime, icon: 'earth', color: '#1565C0'),
    'was': ChasingProgram(key: 'was', label: 'WAS', version: 1, editions: ChasingEditions.annual),
  };

  test('a program\'s icon shows where its verdict alerts, and only there', () {
    expect(
      spotJudgementIcons(
        parkSpot,
        notices: {_alerting('dxcc')},
        judgements: {
          key: [dxcc],
        },
        programs: programs,
      ),
      [(icon: 'earth', color: '#1565C0')],
    );
    final quiet = ChaseNotice(program: 'dxcc', verdict: ChaseVerdict.newRef, alerting: false).key;
    expect(
      spotJudgementIcons(
        parkSpot,
        notices: {quiet},
        judgements: {
          key: [dxcc],
        },
        programs: programs,
      ),
      isEmpty,
    );
    // A program that declares no icon has nothing to show.
    const was = ChaseJudgement(program: 'was', verdicts: [ChaseVerdict.newRef]);
    expect(
      spotJudgementIcons(
        parkSpot,
        notices: {_alerting('was')},
        judgements: {
          key: [was],
        },
        programs: programs,
      ),
      isEmpty,
    );
  });

  test('a spot of several operators shows each one\'s scorer icons, each name once', () {
    final pair = _spot(const [], call: 'K1ABC,W2XYZ');
    expect(
      spotScoreIcons(pair, {
        spotCandidateKey('K1ABC', pair): [(icon: 'star', color: '#C62828')],
        spotCandidateKey('W2XYZ', pair): [(icon: 'star', color: null), (icon: 'trophy', color: null)],
      }),
      [(icon: 'star', color: '#C62828'), (icon: 'trophy', color: null)],
    );
  });

  // A POTA scorer marking a new park with POTA's own tree must not put a
  // second tree beside the reference's.
  test('an icon two kinds name is kept by the earlier kind', () {
    final icons = spotIcons(
      parkSpot,
      controls: _controls,
      scoreIcons: {
        key: [(icon: 'pine-tree', color: '#C62828')],
      },
      notices: {_alerting('dxcc')},
      judgements: {
        key: [dxcc],
      },
      programs: programs,
    );
    expect(icons.scores, [(icon: 'pine-tree', color: '#C62828')]);
    expect(icons.judgements, [(icon: 'earth', color: '#1565C0')]);
    expect(icons.refs, isEmpty);
  });
}

SpotIcon _i(String icon) => (icon: icon, color: null);

void _within() {
  test('references alone fill every slot', () {
    final icons = (scores: <SpotIcon>[], judgements: <SpotIcon>[], refs: [_i('a'), _i('b'), _i('c'), _i('d')]);
    expect(spotIconsWithin(icons, 3), [_i('a'), _i('b'), _i('c')]);
  });

  test('every kind there is keeps a slot, however many the others carry', () {
    final icons = (scores: [_i('s1'), _i('s2'), _i('s3')], judgements: [_i('j1')], refs: [_i('r1'), _i('r2')]);
    expect(spotIconsWithin(icons, 3), [_i('s1'), _i('j1'), _i('r1')]);
  });

  test('the slots left over go to the earlier kinds, in order', () {
    final icons = (scores: [_i('s1'), _i('s2')], judgements: <SpotIcon>[], refs: [_i('r1'), _i('r2')]);
    expect(spotIconsWithin(icons, 3), [_i('s1'), _i('s2'), _i('r1')]);
  });
}
