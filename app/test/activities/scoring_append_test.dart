// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The batched pass resumes from the checkpoints it cached when the log is
// exactly what they folded plus appended contacts. What these tests pin down
// is when a pass may replay a tail and when it MUST fold the whole log: a
// tail sent over a log the checkpoint did not fold leaves verdicts wrong
// silently, and a full pass never does — so every case below is about the
// boundary, not the saving.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/scoring_service.dart';

class _StubHost implements ExtensionHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers the batched pass from [answer], given the args, and records every
/// call's args per scorer so a test can see what went over.
class _FakeExtensions extends ExtensionService {
  Map<String, dynamic> scopes;
  final FutureOr<Map<String, dynamic>?> Function(String scorerKey, Map<String, dynamic> args) answer;
  final List<({String key, Map<String, dynamic> args})> calls = [];

  _FakeExtensions({required this.scopes, required this.answer});

  @override
  ExtensionHost? get host => _StubHost();

  @override
  Future<Map<String, dynamic>> getScoringScopes() async => scopes;

  @override
  Future<Map<String, dynamic>?> scoreQsos({required String scorerKey, required Map<String, dynamic> args}) async {
    calls.add((key: scorerKey, args: args));
    return answer(scorerKey, args);
  }

  @override
  Future<void> start() async {}
}

/// A harness that folds what it is given: a verdict per contact sent, a day
/// section per pass, and a sheet that names the pass. [withDay] is what a
/// tail-aware harness returns; an older one returns no day.
Map<String, dynamic> _fold(String scorerKey, Map<String, dynamic> args, {bool withDay = true}) {
  final sent = (args['qsos'] as List).cast<Map<String, dynamic>>();
  return {
    'qsoScores': {
      for (final q in sent) q['uuid'] as String: {'value': 1, 'pass': args.containsKey('resumeFrom') ? 'tail' : 'full'},
    },
    'daySections': [
      {
        'day': 100,
        'count': sent.length,
        'scores': {
          'qsoCount': {'key': 'qsoCount', 'total': sent.length},
        },
      },
    ],
    'operationSummary': {
      'qsoCount': {'key': 'qsoCount', 'total': sent.length},
    },
    'scoresheet': {'folded': sent.length, 'resumed': args.containsKey('resumeFrom')},
    if (withDay) 'scoresheetDay': 0,
  };
}

const _core = {'core': 'always'};

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

  Future<Operation> operationWith(int count) async {
    final created = await operations.create(stationCall: 'N0DEV');
    for (var i = 0; i < count; i++) {
      await qsos.add(created.uuid, {
        'their': {'call': 'W1AW/$i'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': DateTime.utc(2026, 7, 15, 12, i).millisecondsSinceEpoch,
      });
    }
    return (await operations.get(created.uuid))!;
  }

  Future<Operation> current(Operation operation) async => (await operations.get(operation.uuid))!;
  Future<Qso> log(Operation operation, int i) => qsos.add(operation.uuid, {
    'their': {'call': 'K$i'},
    'band': '20m',
    'mode': 'SSB',
    'startAtMillis': DateTime.utc(2026, 7, 15, 13, i).millisecondsSinceEpoch,
  });
  List<String> sentUuids(Map<String, dynamic> args) => [for (final q in (args['qsos'] as List).cast<Map<String, dynamic>>()) q['uuid'] as String];

  group('an append replays a tail', () {
    test('the second pass sends only the new contact, with the checkpoint and its day', () async {
      var operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: _core, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);

      await scoring.rescoreOperation(operation, full: true);
      final added = await log(operation, 1);
      operation = await current(operation);
      await scoring.rescoreOperation(operation);

      final second = extensions.calls.last.args;
      expect(sentUuids(second), [added.uuid]);
      expect(second['resumeFrom'], {'folded': 2, 'resumed': false});
      expect(second['resumeDay'], 0);
    });

    test('only the tail\'s verdicts are written; the earlier contacts keep theirs', () async {
      var operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: _core, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation, full: true);
      final earlier = (await qsos.forOperation(operation.uuid)).first;
      expect(earlier.scores?['core']?['pass'], 'full');

      final added = await log(operation, 1);
      operation = await current(operation);
      await scoring.rescoreOperation(operation);

      expect((await qsos.get(added.uuid))?.scores?['core']?['pass'], 'tail');
      expect(
        (await qsos.get(earlier.uuid))?.scores?['core']?['pass'],
        'full',
        reason: 'a fold is forward-only: an append never revises an earlier verdict, and the pass must not blank it',
      );
    });

    test('the day the tail continues sums its count with the cached section; the checkpoint restamps over the whole log', () async {
      var operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: _core, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation, full: true);
      await log(operation, 1);
      operation = await current(operation);
      await scoring.rescoreOperation(operation);

      final core = ((await current(operation)).localData['scoring'] as Map)['core'] as Map;
      expect(core['daySections'], [
        {
          'day': 100,
          'count': 3,
          'scores': {
            'qsoCount': {'key': 'qsoCount', 'total': 1},
          },
        },
      ]);
      expect(core['operationSummary'], {
        'qsoCount': {'key': 'qsoCount', 'total': 1},
      });
      expect(core['scoresheet'], {'folded': 1, 'resumed': true});
      // Stamped over the three rows, so the NEXT append resumes from here.
      expect((core['checkpoint'] as Map)['digest'], checkpointDigestOf(await qsos.forOperation(operation.uuid)));

      final third = await log(operation, 2);
      operation = await current(operation);
      await scoring.rescoreOperation(operation);
      expect(sentUuids(extensions.calls.last.args), [third.uuid]);
    });
  });

  group('the whole log goes over', () {
    // The service, not the caller, knows whether THIS runtime has folded the
    // operation: a checkpoint from an earlier launch or from before an
    // extension changed was written by a scorer that may no longer agree.
    test('on the first pass of a runtime without being asked, and a pass that folds nothing does not spend it', () async {
      var operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: const {}, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      // A checkpoint from a previous launch that reads as a valid resume.
      await scoring.rescoreOperation(operation);
      expect(extensions.calls, isEmpty, reason: 'no scorer selected: nothing folded');

      extensions.scopes = _core;
      await log(operation, 1);
      operation = await current(operation);
      await scoring.rescoreOperation(operation);
      final args = extensions.calls.single.args;
      expect(sentUuids(args).length, 3);
      expect(args.containsKey('resumeFrom'), isFalse);

      final again = await log(operation, 2);
      operation = await current(operation);
      await scoring.rescoreOperation(operation);
      expect(sentUuids(extensions.calls.last.args), [again.uuid], reason: 'now folded fully once, so the next append resumes');
    });

    test('after the runtime generation ticks, even though the checkpoints read as current', () async {
      var operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: _core, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation);
      await log(operation, 1);
      operation = await current(operation);
      await scoring.rescoreOperation(operation);
      expect(sentUuids(extensions.calls.last.args).length, 1);

      extensions.runtimeGeneration.value++;
      await log(operation, 2);
      operation = await current(operation);
      await scoring.rescoreOperation(operation);
      final args = extensions.calls.last.args;
      expect(sentUuids(args).length, 4, reason: 'an extension changed: the sheet the checkpoint holds may no longer agree');
      expect(args.containsKey('resumeFrom'), isFalse);
    });

    test('the live paths resume under the same guard, not from whatever checkpoint is cached', () async {
      // The pills and the spots board resume from the checkpoint in
      // local_data. Handed one written before an extension update, the new
      // scorer replays a tail onto a sheet it may not read — the POTA scorer
      // threw on one missing its operator fields.
      final operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: _core, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation);
      final folded = await current(operation);
      final log = await qsos.forOperation(folded.uuid);
      expect(scoring.liveResumeFor(folded, log), isNotNull, reason: 'folded by this runtime: resume');

      final nextLaunch = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      expect(nextLaunch.liveResumeFor(folded, log), isNull, reason: 'a checkpoint from an earlier launch');

      extensions.runtimeGeneration.value++;
      expect(scoring.liveResumeFor(folded, log), isNull, reason: 'an extension changed since the checkpoint was written');

      await scoring.rescoreOperation(folded);
      expect(scoring.liveResumeFor(await current(folded), log), isNotNull, reason: 'the next full pass re-arms it');
    });

    // A pass writes every scorer's verdict for a contact together; on a tail
    // a scorer that fails would leave the newest contact alone without it.
    test('when a scorer fails on the tail, so the tail contact still gets every verdict', () async {
      var operation = await operationWith(2);
      final scopes = {'core': 'always', 'other': 'always'};
      final extensions = _FakeExtensions(scopes: scopes, answer: (key, args) => key == 'other' && args.containsKey('resumeFrom') ? null : _fold(key, args));
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation);
      final added = await log(operation, 1);
      operation = await current(operation);
      extensions.calls.clear();
      await scoring.rescoreOperation(operation);

      expect(extensions.calls.map((c) => c.key), ['core', 'other', 'core', 'other'], reason: 'the tail pass, then the whole log');
      expect(extensions.calls.last.args.containsKey('resumeFrom'), isFalse);
      final scores = (await qsos.get(added.uuid))?.scores;
      expect(scores?.keys, containsAll(['core', 'other']));
    });

    test('on the first pass after an open, whatever the checkpoints say', () async {
      var operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: _core, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation, full: true);
      await log(operation, 1);
      operation = await current(operation);
      await scoring.rescoreOperation(operation, full: true);

      final args = extensions.calls.last.args;
      expect(sentUuids(args).length, 3);
      expect(args.containsKey('resumeFrom'), isFalse);
    });

    test('after an edit of a folded contact', () async {
      var operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: _core, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation, full: true);
      final edited = (await qsos.forOperation(operation.uuid)).first;
      await qsos.update(
        Qso(
          uuid: edited.uuid,
          operationUuid: edited.operationUuid,
          data: {
            ...edited.data,
            'their': {'call': 'W1AW/X'},
          },
        ),
      );
      await log(operation, 1);
      operation = await current(operation);
      await scoring.rescoreOperation(operation);

      final args = extensions.calls.last.args;
      expect(sentUuids(args).length, 3);
      expect(args.containsKey('resumeFrom'), isFalse);
    });

    test('when nothing the rule can see has moved', () async {
      final operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: _core, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation, full: true);
      await scoring.rescoreOperation(await current(operation));

      final args = extensions.calls.last.args;
      expect(sentUuids(args).length, 2);
      expect(args.containsKey('resumeFrom'), isFalse);
    });

    // A pass writes every scorer's verdict for a contact together. One scorer
    // replaying the tail while another folds the log would leave the earlier
    // contacts with only the folding scorer's verdict.
    test('for every scorer when one of them has no checkpoint', () async {
      var operation = await operationWith(2);
      final scopes = {
        'core': 'always',
        'pota': {
          'refTypes': ['potaActivation', 'pota'],
          'huntingRefTypes': ['pota'],
        },
      };
      final extensions = _FakeExtensions(scopes: scopes, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation, full: true);
      expect(extensions.calls.map((c) => c.key), ['core'], reason: 'nothing hunted yet: pota is not selected');

      // The first park contact selects the pota scorer, which has no checkpoint.
      await qsos.add(operation.uuid, {
        'their': {'call': 'K9PARK'},
        'band': '20m',
        'mode': 'SSB',
        'refs': [
          {'type': 'pota', 'ref': 'US-0001'},
        ],
        'startAtMillis': DateTime.utc(2026, 7, 15, 13).millisecondsSinceEpoch,
      });
      operation = await current(operation);
      extensions.calls.clear();
      await scoring.rescoreOperation(operation);

      expect(extensions.calls.map((c) => c.key).toSet(), {'core', 'pota'});
      for (final call in extensions.calls) {
        expect(sentUuids(call.args).length, 3, reason: '${call.key} must fold the whole log');
        expect(call.args.containsKey('resumeFrom'), isFalse);
      }
    });

    // A harness from before the tail existed returns no day and ignores
    // `qsos` beside `resumeFrom`; sending it a tail would fold nothing.
    test('when the checkpoint came from a harness that returns no day', () async {
      var operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: _core, answer: (key, args) => _fold(key, args, withDay: false));
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation, full: true);
      await log(operation, 1);
      operation = await current(operation);
      await scoring.rescoreOperation(operation);

      final args = extensions.calls.last.args;
      expect(sentUuids(args).length, 3);
      expect(args.containsKey('resumeFrom'), isFalse);
    });
  });

  group('passes on one operation', () {
    // Two passes reading the same stale checkpoint and racing to write would
    // let the slower one persist a sheet the other had superseded.
    test('run one at a time, and the second continues the write it waited for', () async {
      var operation = await operationWith(2);
      final gate = Completer<void>();
      var gated = true;
      final extensions = _FakeExtensions(
        scopes: _core,
        answer: (key, args) async {
          if (gated) await gate.future;
          return _fold(key, args);
        },
      );
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);

      final first = scoring.rescoreOperation(operation);
      await Future<void>.delayed(Duration.zero);
      final added = await log(operation, 1);
      operation = await current(operation);
      final second = scoring.rescoreOperation(operation);
      await Future<void>.delayed(Duration.zero);
      expect(extensions.calls, hasLength(1), reason: 'the second pass waits');

      gated = false;
      gate.complete();
      await Future.wait([first, second]);
      expect(extensions.calls, hasLength(2));
      final args = extensions.calls.last.args;
      expect(sentUuids(args), [added.uuid], reason: 'resumed from the checkpoint the first pass wrote');
      expect(args['resumeFrom'], {'folded': 2, 'resumed': false});
    });

    test('read the operation afresh, so a stale copy from the caller does not replay what is already folded', () async {
      var operation = await operationWith(2);
      final extensions = _FakeExtensions(scopes: _core, answer: _fold);
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      await scoring.rescoreOperation(operation);
      final stale = await current(operation);
      final one = await log(operation, 1);
      await scoring.rescoreOperation(await current(operation));
      expect(sentUuids(extensions.calls.last.args), [one.uuid]);

      final two = await log(operation, 2);
      await scoring.rescoreOperation(stale);
      expect(sentUuids(extensions.calls.last.args), [two.uuid], reason: 'the stale copy still holds the checkpoint before contact one');
    });
  });

  group('mergeDaySections', () {
    test('a continued day keeps the fresh tallies and sums the counts; new days append; earlier days stay', () {
      final merged = mergeDaySections(
        [
          {
            'day': 1,
            'count': 5,
            'scores': {'a': 1},
          },
          {
            'day': 2,
            'count': 2,
            'scores': {'a': 2},
          },
        ],
        [
          {
            'day': 2,
            'count': 1,
            'scores': {'a': 3},
          },
          {
            'day': 3,
            'count': 4,
            'scores': {'a': 4},
          },
        ],
      );
      expect(merged, [
        {
          'day': 1,
          'count': 5,
          'scores': {'a': 1},
        },
        {
          'day': 2,
          'count': 3,
          'scores': {'a': 3},
        },
        {
          'day': 3,
          'count': 4,
          'scores': {'a': 4},
        },
      ]);
    });

    test('nothing cached is just the fresh sections; nothing fresh is the cached ones', () {
      expect(
        mergeDaySections(null, [
          {'day': 1, 'count': 1, 'scores': {}},
        ]),
        [
          {'day': 1, 'count': 1, 'scores': {}},
        ],
      );
      expect(
        mergeDaySections([
          {'day': 1, 'count': 1, 'scores': {}},
        ], null),
        [
          {'day': 1, 'count': 1, 'scores': {}},
        ],
      );
    });
  });
}
