// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Scorer priority: the core scorer runs for every operation, but it is the
// DEFAULT, and wherever another scorer has JUDGED a QSO on the worked-before
// axis, core's own judgement of it is dropped. Its rule is call+band+mode, which knows nothing
// about references — beside an activity it contradicts it, and a station worked
// at a second park would carry POTA's "new reference" and core's "duplicate" at
// once, on one row that can show only one.
//
// Only that axis yields. `newDXCC`, `newState` and `newProvince` come from core
// ALONE — no activity or contest emits them — and contradict nothing, so an
// all-or-nothing drop would cost an activation the entity and state pills for
// every contact it logs.
//
// And only a scorer that actually judged that axis displaces core. Merely
// answering is not it: a contest's validity checks all return above its dupe
// test (`invalidBand`, `invalidCategory`, a VHF test's `missingExchange`, which
// is what it says about EVERY spot candidate), and an activity's `judge`
// returns nothing when its ref filter empties the candidates and the contact
// carries no reference of its own. Treating those as judgements loses the dupe
// warning with nothing put in its place — a spots board with no striking for a
// whole VHF contest.
//
// Per QSO, not per operation: a ref-gated scorer skips whole segments it was
// not running for, and those contacts are exactly the ones that still need
// core. Nothing here may be relaxed into "core is dropped when a contest is
// present" — that leaves a break-and-keep-logging stretch scored by nobody,
// holding whatever stale verdicts its rows already had.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/scoring_service.dart';

/// Answers `scoreQso`/`scoreCandidates` per scorer key from [answers], keyed
/// `<scorerKey>:<method>`. A key mapped to an Exception throws, which is how
/// the live paths see a scorer that failed.
class _StubHost implements ExtensionHost {
  final Map<String, Object?> answers;
  final List<String> asked = [];
  _StubHost([this.answers = const {}]);

  @override
  Future<dynamic> invokeHook(String category, {String? key, required String method, Object? args, Duration timeout = const Duration(seconds: 10)}) async {
    asked.add('$key:$method');
    final answer = answers['$key:$method'];
    if (answer is Exception) throw answer;
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The live paths reach the runtime through the `host` getter, so this needs
/// no method overrides beyond the scopes.
class _LiveExtensions extends ExtensionService {
  final _StubHost stubHost;
  final Map<String, dynamic> scopes;
  _LiveExtensions(this.stubHost, this.scopes);

  @override
  ExtensionHost? get host => stubHost;

  @override
  Future<Map<String, dynamic>> getScoringScopes() async => scopes;

  @override
  Future<void> start() async {}
}

/// [_LiveExtensions] with the two extensions whose short names a pill shows.
class _NamedLiveExtensions extends _LiveExtensions {
  _NamedLiveExtensions(super.stubHost, super.scopes);

  @override
  List<ExtensionInfo> get availableExtensions => const [
    ExtensionInfo(key: 'ham2k-pota', file: 'pota.js', core: false, name: 'Parks on the Air', shortName: 'POTA'),
    ExtensionInfo(key: 'ham2k-paqp', file: 'paqp.js', core: false, name: 'Pennsylvania QSO Party', shortName: 'PAQP'),
  ];
}

const _potaAndCore = {
  'core': 'always',
  'pota': {
    'refTypes': ['potaActivation', 'pota'],
    'huntingRefTypes': ['pota'],
  },
};

const _parkOperationData = {
  'uuid': 'op-live',
  'refs': [
    {'type': 'potaActivation', 'ref': 'US-0001'},
  ],
};

/// A VHF contest running alongside the park, for the case where a scorer
/// answers every candidate without judging any of them.
const _vhfPark = {
  'core': 'always',
  'pota': {
    'refTypes': ['potaActivation', 'pota'],
    'huntingRefTypes': ['pota'],
  },
  'vhf': {
    'refTypes': ['arrl-vhf-tests'],
  },
};

const _vhfParkOperationData = {
  'uuid': 'op-live',
  'refs': [
    {'type': 'arrl-vhf-tests'},
  ],
};

/// Answers the two calls `ScoringService` makes — which scorers exist, and
/// what each one says — at the service's own methods, in the shape they
/// return. What is under test is the priority merge downstream of them, not
/// how a hook's payload becomes that shape.
class _FakeExtensions extends ExtensionService {
  final Map<String, dynamic> scopes;
  final Map<String, Map<String, dynamic>?> answers;
  final List<String> called = [];

  _FakeExtensions({required this.scopes, required this.answers});

  @override
  ExtensionHost? get host => _StubHost();

  @override
  Future<Map<String, dynamic>> getScoringScopes() async => scopes;

  @override
  Future<Map<String, dynamic>?> scoreQsos({required String scorerKey, required Map<String, dynamic> args}) async {
    called.add(scorerKey);
    return answers[scorerKey];
  }

  @override
  Future<void> start() async {}
}

/// One scorer's batch result: a verdict for each uuid in [qsoScores], plus the
/// summaries every scorer reports whether or not its verdicts win.
Map<String, dynamic> _result(Map<String, dynamic> qsoScores, {String? tally}) => {
  'qsoScores': qsoScores,
  'daySections': [
    {'day': 100, 'count': qsoScores.length, 'scores': {}},
  ],
  'operationSummary': {
    ?tally: {'key': tally, 'total': qsoScores.length},
  },
  'scoresheet': {'qsos': qsoScores.length},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  });

  tearDown(() async => db.close());

  /// An operation activating a park, with [count] contacts. [refs] overrides
  /// what it is running, since which scorers get selected follows from it.
  Future<(Operation, List<String>)> parkOperation({
    int count = 2,
    List<Map<String, dynamic>> refs = const [
      {'type': 'potaActivation', 'ref': 'US-0001'},
    ],
  }) async {
    final created = await operations.create(stationCall: 'N0DEV', userTitle: 'Park');
    await operations.saveData(Operation(uuid: created.uuid, data: {...created.data, 'refs': refs}));
    final uuids = <String>[];
    for (var i = 0; i < count; i += 1) {
      final qso = await qsos.add(created.uuid, {
        'their': {'call': 'W1AW/$i'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': DateTime.utc(2026, 7, 15, 12 + i).millisecondsSinceEpoch,
      });
      uuids.add(qso.uuid);
    }
    return ((await operations.get(created.uuid))!, uuids);
  }

  Future<Map<String, dynamic>?> cachedScores(String uuid) async => (await qsos.get(uuid))?.scores;

  group('the batched pass', () {
    test('a QSO another scorer scored keeps only that scorer\'s verdict', () async {
      final (operation, uuids) = await parkOperation();
      final extensions = _FakeExtensions(
        scopes: {
          'core': 'always',
          'pota': {
            'refTypes': ['potaActivation', 'pota'],
            'huntingRefTypes': ['pota'],
          },
        },
        answers: {
          'core': _result({
            // Worked at another park: fresh credit to POTA, a duplicate to
            // core, and only one of the two may reach the row.
            uuids[0]: {
              'value': 0,
              'dupe': true,
              'alerts': ['duplicate'],
            },
            uuids[1]: {
              'value': 1,
              'dupe': false,
              'notices': ['newBand', 'newDXCC'],
            },
          }, tally: 'qsoCount'),
          'pota': _result({
            uuids[0]: {
              'value': 1,
              'notices': ['newRef'],
            },
            uuids[1]: {
              'value': 1,
              'notices': ['newDay'],
            },
          }, tally: 'activation'),
        },
      );

      await ScoringService(extensions: extensions, qsos: qsos, operations: operations).rescoreOperation(operation);

      // `dupe` goes with the alert — a row struck by core while POTA counts the
      // contact states the contradiction a second time — leaving core's entry
      // nothing but its own point contribution, which is its bookkeeping and
      // not a claim about this contact.
      expect((await cachedScores(uuids[0]))?['core'], {'value': 0});
      // POTA called it a new day, so core's `newBand` — its worked-before rule
      // speaking — goes, with the `dupe` flag that says the same thing. The
      // entity notice stays: nothing else in the app reports one.
      expect((await cachedScores(uuids[1]))?['core'], {
        'value': 1,
        'notices': ['newDXCC'],
      });
      expect((await cachedScores(uuids[1]))?.keys, containsAll(['core', 'pota']));
    });

    test('a QSO no other scorer scored keeps the fallback verdict', () async {
      final (operation, uuids) = await parkOperation();
      final extensions = _FakeExtensions(
        scopes: {
          'core': 'always',
          'pota': {
            'refTypes': ['potaActivation', 'pota'],
            'huntingRefTypes': ['pota'],
          },
        },
        answers: {
          'core': _result({
            uuids[0]: {
              'notices': ['newBand'],
            },
            // The stretch after a break that dropped the park ref: POTA folds
            // right past it, so core is all this contact has.
            uuids[1]: {
              'value': 0,
              'dupe': true,
              'alerts': ['duplicate'],
            },
          }, tally: 'qsoCount'),
          'pota': _result({
            uuids[0]: {
              'value': 1,
              'notices': ['newRef'],
            },
          }, tally: 'activation'),
        },
      );

      await ScoringService(extensions: extensions, qsos: qsos, operations: operations).rescoreOperation(operation);

      expect((await cachedScores(uuids[0]))?.keys, ['pota']);
      expect((await cachedScores(uuids[1]))?['core'], {
        'value': 0,
        'dupe': true,
        'alerts': ['duplicate'],
      });
    });

    // A chaser's log: POTA is in only because one contact hunts a park. An
    // activity that still answers for every contact it folds calls a bare one
    // worked yesterday `newDay`; kept, it would silence core's duplicate on a
    // contact POTA has no stake in.
    test('a hunt-only scorer\'s verdict stands only on contacts hunting its references', () async {
      final (operation, uuids) = await parkOperation(refs: const []);
      final hunted = await qsos.add(operation.uuid, {
        'their': {'call': 'K1PRK'},
        'band': '20m',
        'mode': 'SSB',
        'refs': [
          {'type': 'pota', 'ref': 'US-0002'},
        ],
        'startAtMillis': DateTime.utc(2026, 7, 15, 18).millisecondsSinceEpoch,
      });
      final extensions = _FakeExtensions(
        scopes: _potaAndCore,
        answers: {
          'core': _result({
            uuids[0]: {
              'value': 0,
              'dupe': true,
              'alerts': ['duplicate'],
            },
            hunted.uuid: {
              'value': 0,
              'dupe': true,
              'alerts': ['duplicate'],
            },
          }, tally: 'qsoCount'),
          'pota': _result({
            uuids[0]: {
              'value': 0,
              'notices': ['newDay'],
            },
            hunted.uuid: {
              'value': 1,
              'notices': ['newDay'],
            },
          }, tally: 'hunting'),
        },
      );

      await ScoringService(extensions: extensions, qsos: qsos, operations: operations).rescoreOperation((await operations.get(operation.uuid))!);

      expect(extensions.called, contains('pota'), reason: 'the hunted park selects POTA');
      expect(await cachedScores(uuids[0]), {
        'core': {
          'value': 0,
          'dupe': true,
          'alerts': ['duplicate'],
        },
      });
      expect((await cachedScores(hunted.uuid))?['pota'], {
        'value': 1,
        'notices': ['newDay'],
      });
      expect((await cachedScores(hunted.uuid))?['core'], {'value': 0});
    });

    // The same hole as on the live paths, in the stored verdict: a contest that
    // answers `invalidBand` for a casual 30m contact has ruled on the band, not
    // on whether this station was worked before. Core's dupe stands.
    test('a scorer that answered without judging the axis leaves the verdict alone', () async {
      final (operation, uuids) = await parkOperation(
        count: 1,
        refs: const [
          {'type': 'cqww'},
        ],
      );
      final extensions = _FakeExtensions(
        scopes: {
          'core': 'always',
          'cqww': {
            'refTypes': ['cqww'],
          },
        },
        answers: {
          'core': _result({
            uuids[0]: {
              'value': 0,
              'dupe': true,
              'alerts': ['duplicate'],
            },
          }, tally: 'qsoCount'),
          'cqww': _result({
            uuids[0]: {
              'value': 0,
              'alerts': ['invalidBand'],
            },
          }, tally: 'contest'),
        },
      );

      await ScoringService(extensions: extensions, qsos: qsos, operations: operations).rescoreOperation(operation);

      expect((await cachedScores(uuids[0]))?['core'], {
        'value': 0,
        'dupe': true,
        'alerts': ['duplicate'],
      });
    });

    // The batched pass is the only path a `dupe` flag travels: the SDK harness
    // returns notices and alerts alone on the live paths. A scorer that ran its
    // dupe test and cleared the contact has ruled, even saying nothing else.
    test('an explicit not-a-duplicate is a ruling in the stored verdict too', () async {
      final (operation, uuids) = await parkOperation(
        count: 1,
        refs: const [
          {'type': 'cqww'},
        ],
      );
      final extensions = _FakeExtensions(
        scopes: {
          'core': 'always',
          'cqww': {
            'refTypes': ['cqww'],
          },
        },
        answers: {
          'core': _result({
            uuids[0]: {
              'value': 0,
              'dupe': true,
              'alerts': ['duplicate'],
            },
          }, tally: 'qsoCount'),
          'cqww': _result({
            uuids[0]: {'value': 1, 'dupe': false},
          }, tally: 'contest'),
        },
      );

      await ScoringService(extensions: extensions, qsos: qsos, operations: operations).rescoreOperation(operation);

      expect((await cachedScores(uuids[0]))?['core'], {'value': 0});
    });

    test('a scorer that failed scored nothing, so the fallback speaks', () async {
      final (operation, uuids) = await parkOperation(count: 1);
      final extensions = _FakeExtensions(
        scopes: {
          'core': 'always',
          'pota': {
            'refTypes': ['potaActivation', 'pota'],
            'huntingRefTypes': ['pota'],
          },
        },
        answers: {
          'core': _result({
            uuids[0]: {
              'value': 0,
              'dupe': true,
              'alerts': ['duplicate'],
            },
          }, tally: 'qsoCount'),
          // `scoreQsos` reports a failed scorer as null.
          'pota': null,
        },
      );

      await ScoringService(extensions: extensions, qsos: qsos, operations: operations).rescoreOperation(operation);

      expect((await cachedScores(uuids[0]))?['core'], {
        'value': 0,
        'dupe': true,
        'alerts': ['duplicate'],
      });
    });

    // Priority is per-QSO only. The tallies are the operation's QSO count,
    // DXCC and bands, which no contest reports — dropping them with the
    // verdicts would empty the Info pane of an activation.
    test('every scorer\'s summaries are kept, whoever won the QSOs', () async {
      final (operation, uuids) = await parkOperation(count: 1);
      final extensions = _FakeExtensions(
        scopes: {
          'core': 'always',
          'pota': {
            'refTypes': ['potaActivation', 'pota'],
            'huntingRefTypes': ['pota'],
          },
        },
        answers: {
          'core': _result({
            uuids[0]: {
              'notices': ['newDXCC'],
            },
          }, tally: 'qsoCount'),
          'pota': _result({
            uuids[0]: {
              'notices': ['newRef'],
            },
          }, tally: 'activation'),
        },
      );

      await ScoringService(extensions: extensions, qsos: qsos, operations: operations).rescoreOperation(operation);

      final scoring = (await operations.get(operation.uuid))!.localData['scoring'] as Map;
      expect(scoring.keys, containsAll(['core', 'pota']));
      expect(((scoring['core'] as Map)['operationSummary'] as Map).containsKey('qsoCount'), isTrue);
      expect((scoring['core'] as Map)['scoresheet'], isNotNull);
    });
  });

  // The same rule on the two live paths, which is where the operator actually
  // sees it: the call-info pills under the callsign being typed, and the strike
  // marks in the spots list.
  group('the live single-QSO path', () {
    Future<Map<String, dynamic>?> score(Map<String, Object?> answers) => _LiveExtensions(_StubHost(answers), _potaAndCore).scoreQso(
      operation: _parkOperationData,
      qso: {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
      },
    );

    test('the fallback yields its dupe alert to a scorer that judged the axis', () async {
      final result = await score({
        'core:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        // Worked at another park: POTA has ruled on whether this station counts
        // as worked before, and its answer is the one the row states.
        'pota:scoreQso': {
          'notices': ['newRef'],
          'alerts': <String>[],
        },
      });
      expect(result, {
        'notices': ['newRef'],
        'alerts': <String>[],
      });
    });

    // The hole a bare "did it answer?" test leaves. Every contest scorer's
    // validity checks return above its dupe check, so `invalidCategory` is an
    // answer that says nothing about whether this station was worked — and core
    // is then the only scorer that knows.
    test('a scorer that answered without judging the axis leaves the alert alone', () async {
      final result = await score({
        'core:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'pota:scoreQso': {
          'notices': <String>[],
          'alerts': ['invalidCategory'],
        },
      });
      expect(result?['alerts'], ['duplicate', 'invalidCategory']);
    });

    // State-parks' spelling of "worked before, but at a park they hadn't given
    // us": same band, same mode, new park, no dupe flag. Unrecognized, it would
    // leave the row saying `newPark` and `duplicate` at once — the exact
    // contradiction this priority exists to end.
    test('a contest\'s own worked-before notice is recognized', () async {
      final result = await score({
        'core:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'pota:scoreQso': {
          'notices': ['newPark'],
          'alerts': <String>[],
        },
      });
      expect(result, {
        'notices': ['newPark'],
        'alerts': <String>[],
      });
    });

    // `dupe: false` IS a judgement — the scorer ran its dupe test and cleared
    // the contact — so core's contradicting alert still yields.
    test('an explicit not-a-duplicate counts as judging the axis', () async {
      final result = await score({
        'core:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'pota:scoreQso': {'dupe': false, 'notices': <String>[], 'alerts': <String>[]},
      });
      expect(result, {'notices': <String>[], 'alerts': <String>[]});
    });

    test('an entity notice survives, since nothing else in the app reports one', () async {
      final result = await score({
        'core:scoreQso': {
          'notices': ['newBand', 'newDXCC'],
          'alerts': <String>[],
        },
        'pota:scoreQso': {
          'notices': ['newRef'],
          'alerts': <String>[],
        },
      });
      expect(result?['notices'], ['newDXCC', 'newRef']);
    });

    // A scorer that says nothing at all has judged nothing at all.
    test('an empty verdict leaves the fallback speaking in full', () async {
      final result = await score({
        'core:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'pota:scoreQso': {'notices': <String>[], 'alerts': <String>[]},
      });
      expect(result?['alerts'], ['duplicate']);
    });

    test('the fallback scorer speaks when nothing else answered', () async {
      final result = await score({
        'core:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'pota:scoreQso': null,
      });
      expect(result?['alerts'], ['duplicate']);
    });

    // A scorer that threw gave no verdict, so the row would go bare — worse
    // than core's, which at least catches the dupe.
    test('a scorer that failed does not silence the fallback', () async {
      final result = await score({
        'core:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'pota:scoreQso': Exception('scorer blew up'),
      });
      expect(result?['alerts'], ['duplicate']);
    });

    // A park hunted earlier in the log selects POTA for every call typed. A bare
    // call earns it nothing, and its per-day rule would set "New Day" beside the
    // QSO Party's dupe for a station worked yesterday.
    test('a scorer selected only by hunting is not asked about a contact hunting none of its references', () async {
      final host = _StubHost({
        'core:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
      });
      final result = await _LiveExtensions(host, _potaAndCore).scoreQso(
        operation: const {'uuid': 'op-live', 'refs': []},
        qso: {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
        },
        huntedRefTypes: const {'pota'},
      );
      expect(host.asked, ['core:scoreQso']);
      expect(result?['alerts'], ['duplicate']);

      host.asked.clear();
      await _LiveExtensions(host, _potaAndCore).scoreQso(
        operation: const {'uuid': 'op-live', 'refs': []},
        qso: {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'refs': [
            {'type': 'pota', 'ref': 'US-0001'},
          ],
        },
        huntedRefTypes: const {'pota'},
      );
      expect(host.asked, containsAll(['core:scoreQso', 'pota:scoreQso']), reason: 'hunting a park, it is asked');
    });
  });

  // Two scorers that disagree about one QSO — a QSO Party calls it a dupe, the
  // park being activated alongside calls it a new day — make a pill row that
  // reads "Dupe!  New Day", which says nothing an operator can act on. Each
  // pill then names its scorer; when they agree, nothing is named.
  group('naming the scorers that disagree', () {
    const scopes = {
      'core': 'always',
      'ham2k-pota': {
        'refTypes': ['potaActivation', 'pota'],
      },
      'ham2k-paqp': {
        'refTypes': ['pa-qso-party'],
      },
    };
    const operation = {
      'uuid': 'op-live',
      'refs': [
        {'type': 'potaActivation', 'ref': 'US-0001'},
        {'type': 'pa-qso-party', 'location': 'NNJ'},
      ],
    };

    Future<Map<String, dynamic>?> score(Map<String, Object?> answers) => _NamedLiveExtensions(_StubHost(answers), scopes).scoreQso(
      operation: operation,
      qso: {
        'their': {'call': 'W3ABC'},
        'band': '40m',
        'mode': 'SSB',
      },
    );

    test('a dupe beside another scorer\'s notice names both', () async {
      final result = await score({
        'core:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'ham2k-paqp:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
          'dupe': true,
        },
        'ham2k-pota:scoreQso': {
          'notices': ['newDay'],
          'alerts': <String>[],
        },
      });
      expect(result?['sources'], {
        'duplicate': ['PAQP'],
        'newDay': ['POTA'],
      });
      // The plain keys stay as they were: the worked-before pill and the
      // spots board read `duplicate` off them.
      expect(result?['alerts'], ['duplicate']);
      expect(result?['notices'], ['newDay']);
    });

    // Not only worked-before news: a new multiplier beside another scorer's
    // dupe is the same contradiction.
    test('any pill from a scorer that did not call it a dupe is a disagreement', () async {
      final result = await score({
        'ham2k-paqp:scoreQso': {
          'notices': ['newMult'],
          'alerts': <String>[],
        },
        'ham2k-pota:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
          'dupe': true,
        },
      });
      expect(result?['sources'], {
        'duplicate': ['POTA'],
        'newMult': ['PAQP'],
      });
    });

    // POTA crediting a contact it has seen before, with nothing to put on a
    // pill, says so as `dupe: false` — still the opposite of PAQP's dupe.
    test('an explicit not-a-duplicate with no pills is a disagreement', () async {
      final result = await score({
        'ham2k-paqp:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'ham2k-pota:scoreQso': {'notices': <String>[], 'alerts': <String>[], 'dupe': false},
      });
      expect(result?['sources'], {
        'duplicate': ['PAQP'],
      });
    });

    test('scorers that agree on a dupe are not named', () async {
      final result = await score({
        'ham2k-paqp:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'ham2k-pota:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
      });
      expect(result?.containsKey('sources'), isFalse);
    });

    test('a lone scorer\'s dupe is not named', () async {
      final result = await score({
        'ham2k-paqp:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'ham2k-pota:scoreQso': {'notices': <String>[], 'alerts': <String>[]},
      });
      expect(result?.containsKey('sources'), isFalse);
    });

    // Core's own entity pills stand beside any verdict and contradict none.
    test('the fallback is never named', () async {
      final result = await score({
        'core:scoreQso': {
          'notices': ['newDXCC'],
          'alerts': <String>[],
        },
        'ham2k-paqp:scoreQso': {
          'notices': <String>[],
          'alerts': ['duplicate'],
        },
        'ham2k-pota:scoreQso': {
          'notices': ['newDay'],
          'alerts': <String>[],
        },
      });
      expect((result?['sources'] as Map).containsKey('newDXCC'), isFalse);
    });
  });

  group('the live spots path', () {
    Future<Map<String, Map<String, List<String>>>?> scoreWith(Map<String, dynamic> scopes, Map<String, dynamic> operation, Map<String, Object?> answers) =>
        _LiveExtensions(_StubHost(answers), scopes).scoreCandidates(
          operation: operation,
          operationUuid: 'op-live',
          candidates: {
            'spot-1': {
              'their': {'call': 'W1AW'},
              'band': '20m',
              'mode': 'SSB',
            },
            'spot-2': {
              'their': {'call': 'K1ABC'},
              'band': '20m',
              'mode': 'SSB',
            },
          },
        );

    Future<Map<String, Map<String, List<String>>>?> score(Map<String, Object?> answers) => scoreWith(_potaAndCore, _parkOperationData, answers);

    // Per CANDIDATE: a batch is one bridge crossing carrying every spot on
    // screen, so a rule applied per batch would let one park spot decide how
    // every other spot in the list is judged.
    test('the fallback speaks only for the candidates nothing else scored', () async {
      final result = await score({
        'core:scoreCandidates': {
          'spot-1': {
            'notices': <String>[],
            'alerts': ['duplicate'],
          },
          'spot-2': {
            'notices': <String>[],
            'alerts': ['duplicate'],
          },
        },
        'pota:scoreCandidates': {
          'spot-1': {
            'notices': ['newRef'],
            'alerts': <String>[],
          },
        },
      });
      expect(result?['spot-1'], {
        'notices': ['newRef'],
        'alerts': <String>[],
      });
      expect(result?['spot-2'], {
        'notices': <String>[],
        'alerts': ['duplicate'],
      });
    });

    test('an entity notice survives on a candidate another scorer judged', () async {
      final result = await score({
        'core:scoreCandidates': {
          'spot-1': {
            'notices': ['newDXCC'],
            'alerts': ['duplicate'],
          },
          'spot-2': {'notices': <String>[], 'alerts': <String>[]},
        },
        'pota:scoreCandidates': {
          // Worked, but at another park — so the strike goes and the entity
          // pill stays.
          'spot-1': {
            'notices': ['newRef'],
            'alerts': <String>[],
          },
          'spot-2': {'notices': <String>[], 'alerts': <String>[]},
        },
      });
      expect(result?['spot-1'], {
        'notices': ['newDXCC', 'newRef'],
        'alerts': <String>[],
      });
      // Nothing to say from either scorer — the panel gets no entry at all,
      // which is what un-strikes a spot.
      expect(result?.containsKey('spot-2'), isFalse);
    });

    // A VHF test answers `missingExchange` for every candidate on the board,
    // since a spot carries no exchange. Reading that as a judgement would take
    // the striking off the whole board for the length of the contest.
    test('a board answered without a worked-before judgement keeps its striking', () async {
      final result = await scoreWith(_vhfPark, _vhfParkOperationData, {
        'core:scoreCandidates': {
          'spot-1': {
            'notices': <String>[],
            'alerts': ['duplicate'],
          },
          'spot-2': {'notices': <String>[], 'alerts': <String>[]},
        },
        'vhf:scoreCandidates': {
          'spot-1': {
            'notices': <String>[],
            'alerts': ['missingExchange'],
          },
          'spot-2': {
            'notices': <String>[],
            'alerts': ['missingExchange'],
          },
        },
      });
      expect(result?['spot-1']?['alerts'], ['duplicate', 'missingExchange']);
    });
  });
}
