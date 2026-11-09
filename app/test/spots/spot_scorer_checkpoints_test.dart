// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scorer the spots board selects only because a spot names its reference
// type — SOTA on a POTA hunter's board — has no checkpoint of the operation's
// to resume from. Folded cold, it reads and folds the whole log on every
// spots refresh and every logged contact, which on a long log is most of the
// engine's time and what a keystroke's lookup then queues behind. What these
// pin is that such a scorer folds the log once per edit, replays a logged
// contact once, and on a refresh replays nothing — and never resumes from a
// checkpoint it cannot prove.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/extensions/extension_scoring.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/scoring_service.dart';

import '../support/halo_test_support.dart';

class _StubHost implements ExtensionHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records every batch pass and answers it with a sheet that says how many
/// contacts it folded and whether it resumed.
class _FakeExtensions extends ExtensionService {
  final List<({String key, Map<String, dynamic> args})> calls = [];
  bool fails = false;
  bool sheetless = false;

  /// Replace it to stand up a new runtime.
  ExtensionHost? currentHost = _StubHost();

  @override
  ExtensionHost? get host => currentHost;

  @override
  Future<Map<String, dynamic>?> scoreQsos({required String scorerKey, required Map<String, dynamic> args}) async {
    calls.add((key: scorerKey, args: args));
    if (fails) return null;
    if (sheetless) return const {'qsoScores': <String, dynamic>{}};
    final sent = ((args['qsos'] ?? args['qsoUuids']) as List).length;
    final resumed = args['resumeFrom'] as Map?;
    return {
      'qsoScores': const <String, dynamic>{},
      'daySections': const <dynamic>[],
      'operationSummary': const <String, dynamic>{},
      'scoresheet': {'folded': ((resumed?['folded'] as int?) ?? 0) + sent},
      'scoresheetDay': 0,
    };
  }

  @override
  Future<void> start() async {}
}

const Scorer _sota = (key: 'sota', ref: null, fallback: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late _FakeExtensions extensions;
  late ScoringService scoring;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    extensions = _FakeExtensions();
    scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
  });
  tearDown(() async => db.close());

  /// Stamped a few milliseconds apart: the resume rule tells a contact the
  /// checkpoint folded from one logged after it by its stamp.
  Future<Qso> log(Operation operation, int i) async {
    await Future<void>.delayed(const Duration(milliseconds: 3));
    return qsos.add(operation.uuid, {
      'their': {'call': 'K$i'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': DateTime.utc(2026, 7, 15, 12, i).millisecondsSinceEpoch,
    });
  }

  Future<Operation> operationWith(int count) async {
    final created = await operations.create(stationCall: 'N0DEV');
    for (var i = 0; i < count; i++) {
      await log(created, i);
    }
    return (await operations.get(created.uuid))!;
  }

  Future<Map<String, ScoringResume>> pass(Operation operation) async =>
      scoring.candidateResumesFor(operation, await qsos.forOperation(operation.uuid), const [_sota]);

  test('a chasing checkpoint folds only the station and period the view supplies', () async {
    final chasing = Operation(uuid: '', data: const {'stationCall': 'N0DEV'});
    await log(chasing, 0);
    final inPeriod = await log(chasing, 1);

    final first = await scoring.candidateResumesFor(chasing, [inPeriod], const [_sota]);
    expect(first['sota']?.checkpoints['sota']?.sheet, {'folded': 1}, reason: 'a stand-in operation has no stored operation to reload');
    final args = extensions.calls.single.args;
    expect([for (final q in (args['qsos'] as List).cast<Map>()) q['uuid']], [inPeriod.uuid], reason: 'the loose bucket also holds contacts outside this view');
    expect(args.containsKey('qsoUuids'), isFalse, reason: 'the runtime cannot load contacts through an empty operation ID');

    await scoring.candidateResumesFor(chasing, [inPeriod], const [_sota]);
    expect(extensions.calls, hasLength(1), reason: 'a spots refresh reuses the filtered checkpoint');

    final next = await log(chasing, 2);
    final appended = await scoring.candidateResumesFor(chasing, [inPeriod, next], const [_sota]);
    expect(appended['sota']?.checkpoints['sota']?.sheet, {'folded': 2});
    expect([for (final q in (extensions.calls.last.args['qsos'] as List).cast<Map>()) q['uuid']], [next.uuid], reason: 'a newly logged contact replays once');

    final narrowed = await scoring.candidateResumesFor(chasing, [next], const [_sota]);
    expect(narrowed['sota']?.checkpoints['sota']?.sheet, {'folded': 1}, reason: 'switching station or period must discard contacts no longer shown');
    expect(extensions.calls.last.args.containsKey('resumeFrom'), isFalse, reason: 'a checkpoint cannot un-fold a contact');

    final deleted = Qso(uuid: next.uuid, operationUuid: '', data: next.data, deleted: true);
    final withDeleted = await scoring.candidateResumesFor(chasing, [inPeriod, deleted], const [_sota]);
    expect(withDeleted['sota']?.checkpoints['sota']?.sheet, {'folded': 1}, reason: 'Show deleted QSOs must not count removed contacts as worked');
    expect([for (final q in (extensions.calls.last.args['qsos'] as List).cast<Map>()) q['uuid']], [inPeriod.uuid]);

    expect(await scoring.candidateResumesFor(chasing, const [], const [_sota]), isEmpty, reason: 'an empty period must not keep the old worked stations');
  });

  test('a refresh over an unchanged log folds nothing', () async {
    final operation = await operationWith(3);

    final first = await pass(operation);
    expect(extensions.calls, hasLength(1));
    expect((extensions.calls.single.args['qsoUuids'] as List), hasLength(3), reason: 'the first pass folds the whole log');
    expect(extensions.calls.single.args['checkpointKey'], isA<String>(), reason: 'so the runtime holds the sheet');
    expect(first['sota']?.checkpoints['sota']?.sheet, {'folded': 3});
    expect(first['sota']?.tail, isEmpty);

    final second = await pass(operation);
    expect(extensions.calls, hasLength(1), reason: 'the spots moved, the log did not');
    expect(second['sota']?.checkpoints['sota']?.key, first['sota']?.checkpoints['sota']?.key);
  });

  test('a contact logged since is replayed once onto the checkpoint, then not again', () async {
    final operation = await operationWith(3);
    await pass(operation);
    final added = await log(operation, 3);

    final after = await pass(operation);
    expect(extensions.calls, hasLength(2));
    final replay = extensions.calls.last.args;
    expect([for (final q in (replay['qsos'] as List).cast<Map>()) q['uuid']], [added.uuid], reason: 'only the new contact');
    expect(replay['resumeFrom'], {'folded': 3});
    expect(after['sota']?.checkpoints['sota']?.sheet, {'folded': 4});
    expect(after['sota']?.tail, isEmpty, reason: 'the checkpoint moved up to the log');

    await pass(operation);
    expect(extensions.calls, hasLength(2));
  });

  test('a contact edited under the checkpoint folds the whole log again', () async {
    // A checkpoint cannot un-fold a contact: resumed, it would keep judging
    // spots against the call as it was before the edit.
    final operation = await operationWith(3);
    await pass(operation);
    final edited = (await qsos.forOperation(operation.uuid)).first;
    await Future<void>.delayed(const Duration(milliseconds: 3));
    await qsos.update(
      Qso(
        uuid: edited.uuid,
        operationUuid: edited.operationUuid,
        data: {
          ...edited.data,
          'their': {'call': 'W1AW'},
        },
      ),
    );

    await pass(operation);
    expect(extensions.calls, hasLength(2));
    expect(extensions.calls.last.args.containsKey('resumeFrom'), isFalse);
    expect((extensions.calls.last.args['qsoUuids'] as List), hasLength(3));
  });

  test('a new runtime folds the whole log again', () async {
    // Its scorers may not be the ones that folded the checkpoint — an
    // extension updated or switched off and on — and it holds nothing.
    final operation = await operationWith(3);
    await pass(operation);
    extensions.currentHost = _StubHost();
    extensions.runtimeGeneration.value++;

    await pass(operation);
    expect(extensions.calls, hasLength(2));
    expect(extensions.calls.last.args.containsKey('resumeFrom'), isFalse);
  });

  test('a scorer whose pass failed gets no resume, and folds cold', () async {
    final operation = await operationWith(3);
    extensions.fails = true;

    expect(await pass(operation), isEmpty);
  });

  test('a scorer the operation\'s own passes run is left to them', () async {
    // Its checkpoint is missing only while a rescore is due, and that rescore
    // is already folding the whole log; building one here as well would fold
    // it twice to save a single spots pass.
    final created = await operationWith(3);
    await operations.updateLocalData(created.uuid, {
      'scoring': {
        'core': {'scoresheet': const <String, dynamic>{}},
      },
    });
    final operation = (await operations.get(created.uuid))!;

    final resumes = await scoring.candidateResumesFor(operation, await qsos.forOperation(operation.uuid), const [
      (key: 'core', ref: null, fallback: true),
      _sota,
    ]);
    expect(extensions.calls.map((c) => c.key), ['sota']);
    expect(resumes.keys, ['sota']);
  });

  test('a scorer that answers without a sheet is not folded again on every refresh', () async {
    final operation = await operationWith(3);
    extensions.sheetless = true;

    expect(await pass(operation), isEmpty, reason: 'nothing to resume from: it folds cold');
    await pass(operation);
    expect(extensions.calls, hasLength(1));
  });

  test('a failure building the checkpoints costs those scorers their resume, not the pass', () async {
    // Thrown from the builder, it would take every scorer's verdicts with it
    // and leave the board showing ones judged against an older log.
    ErrorReportingService.resetFailureStreaks();
    final asked = <String>[];
    Object? answer(String scorer) => (Object? args) {
      asked.add(scorer);
      return {
        'a': {
          'notices': const <String>[],
          'alerts': const ['duplicate'],
        },
      };
    };
    final service = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'scoring:*:scope': [
          {'key': 'core', 'ok': true, 'value': 'always'},
          {
            'key': 'sota',
            'ok': true,
            'value': {
              'refTypes': ['sota'],
              'huntingRefTypes': ['sota'],
            },
          },
        ],
        'scoring:core:scoreCandidates': answer('core'),
        'scoring:sota:scoreCandidates': answer('sota'),
      }),
    );

    final result = await service.scoreCandidates(
      operation: const {'stationCall': 'N0DEV'},
      operationUuid: 'op-1',
      candidates: {
        'a': {
          'their': {'call': 'W1AW'},
          'refs': [
            {'type': 'sota', 'ref': 'W7W/KG-001'},
          ],
        },
      },
      resumesFor: (_) async => throw StateError('the log could not be read'),
    );

    expect(asked..sort(), ['core', 'sota'], reason: 'every scorer still judges the board');
    expect(result?['a']?['alerts'], ['duplicate']);
    expect(ErrorReportingService.failureStreak('scoring:candidateResumes'), 1, reason: 'reported, once per streak');
  });

  test('a spots pass hands each scorer its own checkpoint and tail', () async {
    // The operation's checkpoints and a spot-only scorer's stand at different
    // points in the log; sent the operation's tail, a spot-only checkpoint
    // already past it would fold those contacts twice.
    final calls = <String, Map<String, dynamic>>{};
    Object? answer(String scorer) => (Object? args) {
      calls[scorer] = (args as Map).cast<String, dynamic>();
      return const <String, dynamic>{};
    };
    final host = FakeExtensionHost({
      'scoring:*:scope': [
        {'key': 'core', 'ok': true, 'value': 'always'},
        {
          'key': 'sota',
          'ok': true,
          'value': {
            'refTypes': ['sota'],
            'huntingRefTypes': ['sota'],
          },
        },
      ],
      'scoring:core:scoreCandidates': answer('core'),
      'scoring:sota:scoreCandidates': answer('sota'),
    });
    final service = ExtensionServiceWithFakeHost(host);
    const tail = [
      {
        'uuid': 'new',
        'their': {'call': 'K9X'},
      },
    ];
    const operationResume = (
      checkpoints: {
        'core': (sheet: {'core': 1}, day: 0, key: 'k-core'),
      },
      tail: tail,
    );
    List<Scorer>? asked;

    await service.scoreCandidates(
      operation: const {'stationCall': 'N0DEV'},
      operationUuid: 'op-1',
      candidates: {
        'a': {
          'their': {'call': 'W1AW'},
          'refs': [
            {'type': 'sota', 'ref': 'W7W/KG-001'},
          ],
        },
      },
      resume: operationResume,
      resumesFor: (scorers) async {
        asked = scorers;
        return {
          'sota': (
            checkpoints: {
              'sota': (sheet: {'sota': 1}, day: 0, key: 'k-sota'),
            },
            tail: const <Map<String, dynamic>>[],
          ),
        };
      },
    );

    expect(asked?.map((s) => s.key), ['sota'], reason: 'only the scorer the operation has no checkpoint for');
    expect(calls['core']?['resumeKey'], 'k-core');
    expect(calls['core']?['qsos'], tail);
    expect(calls['sota']?['resumeKey'], 'k-sota');
    expect(calls['sota']?.containsKey('qsos'), isFalse, reason: 'its checkpoint is already at the end of the log');
  });
}
