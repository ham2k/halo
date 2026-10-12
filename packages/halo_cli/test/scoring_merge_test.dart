// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `halo ext score` against the REAL scorers, because the thing worth pinning
// is that the CLI answers what the app answers (docs/design/contests.md §5.1).
// The merge rules have unit tests in halo_extension_host; what those cannot
// show is whether the shipped extensions actually speak the vocabulary the
// rules read — whether POTA says "worked before, and this one counts" out
// loud, and whether core's contradicting `duplicate` therefore yields.
//
// A slow test for the same reason `runtime_test.dart` is one: mock the
// scorers and it can only prove the merge agrees with the fixtures written
// beside it.

import 'package:halo_cli/src/bundles.dart';
import 'package:halo_cli/src/config.dart';
import 'package:halo_cli/src/runtime.dart';
import 'package:halo_cli/src/scoring.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHost;
import 'package:test/test.dart';

const _day = 1000 * 60 * 60 * 24;
final _at = DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch;

/// A chaser's operation: it activates nothing, so nothing on it names POTA —
/// the log is what selects that scorer. It also credits nothing, which is what
/// keeps POTA from ruling on contacts it scores zero for.
const _operation = {'uuid': 'op-1', 'stationCall': 'N0DEV', 'refs': <Map<String, Object?>>[]};

/// An activation: every contact earns park credit, so POTA has a stake in the
/// ones it clears.
const _activation = {
  'uuid': 'op-1',
  'stationCall': 'N0DEV',
  'refs': [
    {'type': 'potaActivation', 'ref': 'US-0001'},
  ],
};

Map<String, Object?> _qso(String uuid, {required int at, String call = 'W1AW', String band = '20m', String mode = 'SSB', List<String> parks = const []}) => {
  'uuid': uuid,
  'their': {'call': call},
  'band': band,
  'mode': mode,
  'startAtMillis': at,
  'refs': [
    for (final park in parks) {'type': 'pota', 'ref': park},
  ],
};

Map<String, Object?>? _verdictFor(Map<String, Map<String, Object?>> scored, String scorer, String uuid) =>
    ((scored[scorer]?['qsoScores'] as Map?)?[uuid] as Map?)?.cast<String, Object?>();

List<String> _alertsOf(Map<String, Object?>? verdict) => ((verdict?['alerts'] as List?) ?? const []).cast<String>();

void main() {
  late BundleIndex index;
  ExtRuntime? runtime;

  setUpAll(() => index = BundleIndex.load());
  // Nullable, and only stopped if something started: two of these need no
  // runtime at all, and an unconditional stop makes running one of them alone
  // fail in teardown rather than reporting its own result.
  tearDown(() async => runtime?.stop());

  /// Core scoring plus POTA, and nothing else — the pair whose rules disagree.
  Future<ExtRuntime> start({Set<String> only = const {'scoring', 'ham2k-pota'}}) async => runtime = await ExtRuntime.start(
    index: index,
    config: CliConfig(settings: const {}),
    only: only,
  );

  test('the log selects POTA, and core comes last as the fallback', () async {
    await start();
    final scored = await scoreOperation(
      runtime!.host,
      operation: _operation,
      qsos: [
        _qso('a', at: _at, parks: const ['US-1234']),
      ],
    );
    // Keyed by scorer, in priority order: what the app caches, and what an
    // operator comparing the two reads.
    expect(scored.keys, ['ham2k-pota', 'core']);
  });

  // The case this whole change exists for. Worked at a park in the morning;
  // the operator packs up and is worked again bare, same band and mode. Core's
  // call+band+mode rule calls that a duplicate. POTA counts it — and now says
  // so — so the operator must not be told it is a dupe.
  test("core's duplicate yields where POTA has ruled the contact counts", () async {
    await start();
    final log = [
      _qso('at-park', at: _at, parks: const ['US-1234']),
      _qso('packed-up', at: _at + 3600 * 1000),
    ];

    final merged = await scoreOperation(runtime!.host, operation: _activation, qsos: log);
    // The credit is the premise, not a detail: POTA rules on this contact
    // BECAUSE it awarded it park credit, and asserting the outcome without it
    // would pass just as well if POTA had started overruling core for free.
    expect(_verdictFor(merged, 'ham2k-pota', 'packed-up')?['value'], greaterThan(0));
    expect(_alertsOf(_verdictFor(merged, 'core', 'packed-up')), isNot(contains('duplicate')), reason: 'POTA credited this contact; core must not strike it');

    // And the reason it yielded is a RULING, not silence: POTA reports the
    // dupe test it ran, which is what `judgesWorkedBefore` reads.
    expect(_verdictFor(merged, 'ham2k-pota', 'packed-up')?['dupe'], false);
  });

  // The same log on a CHASER's operation, where POTA credits the bare repeat
  // nothing. A scorer that awarded nothing must not take away the only
  // duplicate warning the operator gets — and this is the ordinary case, since
  // most POTA logs are hunting, not activating.
  test('a scorer that credited nothing does not silence core', () async {
    await start();
    final log = [
      _qso('at-park', at: _at, parks: const ['US-1234']),
      _qso('packed-up', at: _at + 3600 * 1000),
    ];

    final merged = await scoreOperation(runtime!.host, operation: _operation, qsos: log);
    // A contact hunting no park is not POTA's to rule on at all, so its
    // verdict is not kept, as in the app's stored log.
    expect(_verdictFor(merged, 'ham2k-pota', 'packed-up'), isNull);
    expect(_alertsOf(_verdictFor(merged, 'core', 'packed-up')), contains('duplicate'));
  });

  // The same log through `--key core`: the raw single-scorer view still shows
  // core's own rule, or the merged answer above would prove nothing about the
  // merge — it could just be core having changed its mind.
  test('--key core still shows core calling it a duplicate, unmerged', () async {
    await start();
    final raw = await scoreWithOneScorer(
      runtime!.host,
      key: 'core',
      operation: _activation,
      qsos: [
        _qso('at-park', at: _at, parks: const ['US-1234']),
        _qso('packed-up', at: _at + 3600 * 1000),
      ],
    );
    final verdict = ((raw['qsoScores'] as Map)['packed-up'] as Map).cast<String, Object?>();
    expect(_alertsOf(verdict), contains('duplicate'));
  });

  // Whoever makes it, the warning has to reach the operator: the merge takes
  // core's `duplicate` away only where another scorer has ruled, and a scorer
  // that rules "duplicate" is still saying duplicate. Asserted across the
  // scorers rather than on core's entry, because which of them speaks is
  // exactly what the merge decides.
  test('a repeat contact is still reported as a duplicate by somebody', () async {
    await start();
    final log = [
      _qso('park', at: _at, call: 'K1ABC', parks: const ['US-1234']),
      _qso('first', at: _at + 60 * 1000, call: 'W2XYZ'),
      _qso('again', at: _at + 120 * 1000, call: 'W2XYZ'),
    ];

    final merged = await scoreOperation(runtime!.host, operation: _operation, qsos: log);
    final alerts = [for (final scorer in merged.keys) ..._alertsOf(_verdictFor(merged, scorer, 'again'))];
    expect(alerts, contains('duplicate'));
  });

  // Core alone reports entities, so its notice has to survive a QSO POTA ruled
  // on — an activation that lost its DXCC pills on every contact would be the
  // cure being worse than the disease.
  test("core's entity notice survives a contact POTA ruled on", () async {
    await start();
    final log = [
      _qso('at-park', at: _at, call: 'DL1ABC', parks: const ['DA-0001']),
      _qso('next-day', at: _at + _day, call: 'DL1ABC'),
    ];

    final merged = await scoreOperation(runtime!.host, operation: _operation, qsos: log);
    final first = _verdictFor(merged, 'core', 'at-park');
    expect(((first?['notices'] as List?) ?? const []), contains('newDXCC'), reason: 'nothing else in the app reports a new entity');
  });

  // The hole a bare "did it answer?" test leaves, against a real contest
  // scorer — the sample CQ WW, which the app never ships but whose band check
  // returns ABOVE its dupe test as the catalog's does: a casual 30m contact
  // gets `invalidBand` and no opinion on whether the station was worked.
  // Core's is then the only dupe rule there is, and it has to survive — the
  // alternative is an operator working 30m during a contest weekend and being
  // told nothing about repeats all weekend.
  test('an off-band contest answer does not silence core', () async {
    if (!index.extensions.any((e) => e.key == 'k2hrc-cqww')) {
      // Built by extensions/build-config.mjs into the fixtures directory,
      // never into the app's assets.
      index.extensions.add(
        const BundleEntry(key: 'k2hrc-cqww', file: '../../../extensions/build/fixtures/k2hrc-cqww.js', name: 'CQ WW DX (sample)', core: false),
      );
    }
    await start(only: const {'scoring', 'k2hrc-cqww'});

    const operation = {
      'uuid': 'op-2',
      'stationCall': 'N0DEV',
      'refs': [
        {'type': 'k2hrcCqww', 'mode': 'SSB', 'zone': '5'},
      ],
    };
    final log = [_qso('warc-1', at: _at, call: 'W3QRP', band: '30m'), _qso('warc-2', at: _at + 60 * 1000, call: 'W3QRP', band: '30m')];

    final merged = await scoreOperation(runtime!.host, operation: operation, qsos: log);
    expect(_alertsOf(_verdictFor(merged, 'k2hrc-cqww', 'warc-2')), contains('invalidBand'));
    expect(_alertsOf(_verdictFor(merged, 'core', 'warc-2')), contains('duplicate'), reason: 'CQ WW ruled on the band, not on whether this station was worked');
  });

  // The rule the app applies to its stored verdicts, so the CLI has to apply
  // it too: a scorer selected only by the log's hunting, answering for a
  // contact hunting none of its references, has its verdict dropped — and
  // with it the ruling that would take core's duplicate off the contact.
  test('a hunt-only scorer\'s verdict on a contact it has no stake in is dropped', () {
    const scopes = {
      'core': 'always',
      'pota': {
        'refTypes': ['potaActivation', 'pota'],
        'huntingRefTypes': ['pota'],
      },
    };
    final qsos = {
      'park': _qso('park', at: _at, parks: ['US-0001']),
      'bare': _qso('bare', at: _at + _day),
    };
    final merged = mergeScoredVerdicts(
      [(key: 'pota', ref: null, fallback: false), (key: 'core', ref: null, fallback: true)],
      {
        'pota': {
          'qsoScores': {
            'park': {
              'notices': ['newRef'],
            },
            'bare': {
              'notices': ['newDay'],
            },
          },
        },
        'core': {
          'qsoScores': {
            'park': {
              'alerts': ['duplicate'],
            },
            'bare': {
              'alerts': ['duplicate'],
            },
          },
        },
      },
      scopes: scopes,
      qsoOf: (uuid) => qsos[uuid],
    );
    expect(_verdictFor(merged, 'pota', 'bare'), isNull);
    expect(_alertsOf(_verdictFor(merged, 'core', 'bare')), ['duplicate']);
    expect(_verdictFor(merged, 'core', 'park'), isNull, reason: 'POTA ruled on the park contact, so core yields there');
  });

  // A deleted `break` row opens no segment: the app never sees deleted rows at
  // all (they are filtered in SQL), so a CLI that honoured one would resolve
  // different boundaries — and therefore select and score differently — from
  // the same file.
  test('a deleted event row is not a segment boundary', () {
    final log = [
      _qso('a', at: _at, parks: const ['US-1234']),
      {
        'uuid': 'break',
        'deleted': true,
        'band': 'event',
        'startAtMillis': _at + 60 * 1000,
        'event': {
          'event': 'break',
          'operation': {'refs': <Map<String, Object?>>[]},
        },
      },
    ];
    expect(segmentsOf(_activation, log), isNull);

    final live = [...log]..[1] = {...log[1], 'deleted': false};
    expect(segmentsOf(_activation, live), hasLength(2));
  });

  // The app never scores a deleted contact — `watchForOperation` filters them
  // in SQL — so a tool that scored the raw file would report a duplicate
  // against a QSO the operator has already deleted, which is precisely the
  // "why does it say that?" this command exists to answer.
  test('a deleted contact is not scored', () async {
    await start();
    final log = [
      _qso('kept', at: _at),
      {..._qso('binned', at: _at + 60 * 1000), 'deleted': true},
    ];

    final merged = await scoreOperation(runtime!.host, operation: _activation, qsos: log);
    expect((merged['core']?['qsoScores'] as Map?)?.keys, ['kept']);
  });

  // One scorer throwing must not cost the operation every other scorer's
  // answer — this is the tool someone reaches for BECAUSE a scorer is
  // misbehaving, so it has to keep reporting the ones that work. A stub host
  // rather than the real runtime: the failure has to be the point of the test,
  // not a race with how fast QuickJS answers.
  test('a scorer that fails is reported in its own place, not instead of the rest', () async {
    final scored = await scoreOperation(
      _StubHost(failing: const {'pota'}),
      operation: _activation,
      qsos: [
        _qso('a', at: _at, parks: const ['US-1234']),
      ],
    );
    expect(scored['pota']?['error'], contains('boom'));
    expect((scored['core']?['qsoScores'] as Map?)?.keys, ['a']);
  });
}

/// Answers `scope` for core and POTA, and `scoreQsos` with a verdict per QSO —
/// except for the keys in [failing], which throw.
class _StubHost implements ExtensionHost {
  final Set<String> failing;
  _StubHost({this.failing = const {}});

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async => [
    {'key': 'core', 'ok': true, 'value': 'always'},
    {
      'key': 'pota',
      'ok': true,
      'value': {
        'refTypes': ['potaActivation', 'pota'],
        'huntingRefTypes': ['pota'],
      },
    },
  ];

  @override
  Future<dynamic> invokeHook(String category, {String? key, required String method, Object? args, Duration timeout = const Duration(seconds: 10)}) async {
    if (failing.contains(key)) throw Exception('boom');
    final qsos = ((args as Map)['qsos'] as List).cast<Map<String, Object?>>();
    return {
      'qsoScores': {
        for (final qso in qsos) qso['uuid'] as String: {'value': 1},
      },
      'daySections': const [],
      'operationSummary': const {},
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
