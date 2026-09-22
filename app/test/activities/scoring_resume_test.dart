// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The live call-info path resumes from the checkpoints a rescore cached instead
// of re-folding the whole log on every keystroke. What these tests pin down is
// the one way that can go wrong silently: a checkpoint resumed over a log it
// did not fold calls the contact just logged "not a duplicate". So the rule
// that decides when a resume is offered is tested for each way the log can
// differ from the checkpoint, the stamp a rescore writes is checked against the
// list it folded, and the hook call is checked for carrying both halves.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/extension_scoring.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/scoring_service.dart';

import '../support/error_reporting_fakes.dart';

class _RecordingHost implements ExtensionHost {
  final List<({String? key, String method, Object? args})> calls = [];
  final Map<String, Object?> answers;
  _RecordingHost([this.answers = const {}]);

  @override
  Future<dynamic> invokeHook(String category, {String? key, required String method, Object? args, Duration timeout = const Duration(seconds: 10)}) async {
    calls.add((key: key, method: method, args: args));
    final answer = answers['$key:$method'];
    if (answer is Exception) throw answer;
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LiveExtensions extends ExtensionService {
  final _RecordingHost recordingHost;
  _LiveExtensions(this.recordingHost);

  @override
  ExtensionHost? get host => recordingHost;

  @override
  Future<Map<String, dynamic>> getScoringScopes() async => const {'core': 'always'};

  @override
  Future<void> start() async {}
}

Qso _contact(String uuid, {required int updatedAt, int? startAt, bool deleted = false, bool event = false}) => Qso(
  uuid: uuid,
  operationUuid: 'op-1',
  deleted: deleted,
  data: {
    'uuid': uuid,
    'their': {'call': 'W1AW'},
    'band': event ? 'event' : '20m',
    'mode': 'SSB',
    'startAtMillis': startAt ?? updatedAt,
    'updatedAtMillis': updatedAt,
  },
);

/// The operation's own stamp as the rescore saw it.
const _operationStamp = 5000;

/// The cache a rescore leaves behind for [folded] (contacts and markers):
/// their digest, the newest stamp among them, the time of the last contact in
/// log order, and the operation's stamp.
Map<String, dynamic> _scoring(List<Qso> folded, {bool stamped = true, int? day, int? operationStamp = _operationStamp}) => {
  'core': {
    'operationSummary': const {},
    'scoresheet': const {'worked': {}},
    'scoresheetDay': ?day,
    if (stamped)
      'checkpoint': {
        'digest': checkpointDigestOf(folded),
        'updatedAtMillis': folded.map((q) => q.updatedAtMillis!).reduce((a, b) => a > b ? a : b),
        'startAtMillis': folded.where((q) => !q.isEvent).map((q) => q.startAtMillis!).reduce((a, b) => a > b ? a : b),
        'operationUpdatedAtMillis': operationStamp,
      },
  },
};

ScoringResume? _resolve(Map<String, dynamic>? scoring, List<Qso> qsos, {String? excludeUuid, int? operationStamp = _operationStamp}) =>
    resolveScoringResume(scoring: scoring, operationUpdatedAtMillis: operationStamp, qsos: qsos, excludeUuid: excludeUuid);

void main() {
  group('resolveScoringResume', () {
    final folded = [_contact('a', updatedAt: 1000), _contact('b', updatedAt: 2000)];

    test('a log exactly as the checkpoint folded it resumes with nothing to replay', () {
      final resume = _resolve(_scoring(folded, day: 86400000), folded);
      expect(resume, isNotNull);
      expect(resume!.tail, isEmpty);
      expect(resume.checkpoints['core'], (sheet: const {'worked': {}}, day: 86400000));
    });

    test('contacts stamped after the checkpoint are the tail, oldest first', () {
      final resume = _resolve(_scoring(folded, day: 86400000), [...folded, _contact('c', updatedAt: 3000), _contact('d', updatedAt: 3500)]);
      expect(resume?.tail.map((q) => q['uuid']), ['c', 'd']);
    });

    // An edit moves a folded contact past the stamp without adding one — the
    // checkpoint already holds its old version and cannot un-fold it.
    test('an edit of a folded contact folds cold', () {
      final edited = [_contact('a', updatedAt: 1000), _contact('b', updatedAt: 2500)];
      expect(_resolve(_scoring(folded), edited), isNull);
    });

    test('a delete folds cold even when nothing else moved', () {
      final withoutB = [_contact('a', updatedAt: 1000), _contact('b', updatedAt: 2500, deleted: true)];
      expect(_resolve(_scoring(folded), withoutB), isNull);
    });

    // An append AND an edit in the same window: the edited contact leaves the
    // folded set, which no longer digests to the checkpoint's value.
    test('an append beside an edit folds cold', () {
      final mixed = [_contact('a', updatedAt: 2500), _contact('b', updatedAt: 2000), _contact('c', updatedAt: 3000)];
      expect(_resolve(_scoring(folded), mixed), isNull);
    });

    // The checkpoint never folded it, so it replays — but only from the end:
    // restored earlier in the log, it would fold out of order.
    test('an undeleted contact replays when it is last in log order, else folds cold', () {
      final restoredLast = [...folded, _contact('z', updatedAt: 2600, startAt: 2500)];
      expect(_resolve(_scoring(folded, day: 86400000), restoredLast)?.tail.map((q) => q['uuid']), ['z']);
      final restoredEarly = [_contact('z', updatedAt: 2600, startAt: 500), ...folded];
      expect(_resolve(_scoring(folded), restoredEarly), isNull);
    });

    test('the contact being edited is inside the sheet, so it folds cold', () {
      expect(_resolve(_scoring(folded), folded, excludeUuid: 'b'), isNull);
    });

    test('deleted rows are neither digested nor replayed', () {
      final withNoise = [...folded, _contact('gone', updatedAt: 9000, deleted: true), _contact('gone-marker', updatedAt: 9500, event: true, deleted: true)];
      final resume = _resolve(_scoring(folded), withNoise);
      expect(resume, isNotNull);
      expect(resume!.tail, isEmpty);
    });

    test('a cache written without a stamp cannot be placed and folds cold', () {
      expect(_resolve(_scoring(folded, stamped: false), folded), isNull);
      expect(_resolve(null, folded), isNull);
      expect(_resolve(const {}, folded), isNull);
    });

    test('a contact with no stamp cannot be placed and folds cold', () {
      final unstamped = [
        _contact('a', updatedAt: 1000),
        Qso(uuid: 'b', operationUuid: 'op-1', data: const {'uuid': 'b', 'band': '20m', 'startAtMillis': 2000}),
      ];
      expect(_resolve(_scoring(folded), unstamped), isNull);
    });

    // A bundle built on an SDK from before the tail existed resumes from the
    // checkpoint and ignores the tail — and only a tail-aware harness returns
    // the day beside its sheet. Nothing to replay: an old harness resumes fine.
    test('a checkpoint without a day is resumed only when there is nothing to replay', () {
      final scoring = {
        ..._scoring(folded),
        'pota': {..._scoring(folded, day: 86400000)['core'] as Map},
      };
      final current = _resolve(scoring, folded);
      expect(current?.checkpoints.keys, containsAll(['core', 'pota']));

      final appended = [...folded, _contact('c', updatedAt: 3000)];
      final withTail = _resolve(scoring, appended);
      expect(withTail?.checkpoints.keys, ['pota']);
      expect(withTail?.tail.map((q) => q['uuid']), ['c']);

      // Every scorer on an old harness: no resume at all, not an empty one.
      expect(_resolve(_scoring(folded), appended), isNull);
    });

    // A scorer folds the operation as well as the log: an activation reference
    // corrected after the pass would leave the next call judged under the old
    // park. The operation's own stamp moves on every save and rides in the
    // checkpoint.
    test('a saved change to the operation folds cold', () {
      expect(_resolve(_scoring(folded), folded, operationStamp: _operationStamp + 1), isNull);
    });

    // Segment markers shape the timeline every contact folds under, so they
    // are part of what the checkpoint folded — in the digest, never the tail.
    test('a segment marker added or edited since the checkpoint folds cold', () {
      final marker = _contact('break', updatedAt: 1500, startAt: 1500, event: true);
      final withMarker = [folded[0], marker, folded[1]];
      expect(_resolve(_scoring(withMarker), withMarker)?.tail, isEmpty);

      final added = [...folded, _contact('start', updatedAt: 3000, startAt: 3000, event: true)];
      expect(_resolve(_scoring(folded, day: 86400000), added), isNull);

      final moved = [folded[0], _contact('break', updatedAt: 1800, startAt: 1500, event: true), folded[1]];
      expect(_resolve(_scoring(withMarker), moved), isNull);
    });

    test('scorers whose stamps disagree are from passes this code does not know: cold', () {
      final scoring = {
        ..._scoring(folded),
        'pota': {
          'scoresheet': const {},
          'checkpoint': {'digest': 1, 'updatedAtMillis': 1000, 'startAtMillis': 1000, 'operationUpdatedAtMillis': _operationStamp},
        },
      };
      expect(_resolve(scoring, folded), isNull);
    });

    // A peer's correction arrives through sync carrying ITS stamp, which can be
    // older than the newest one here. Nothing moved past the stamp; only the digest
    // sees the folded contact change.
    test('a synced edit landing under the newest stamp folds cold', () {
      final corrected = [_contact('a', updatedAt: 1000), _contact('b', updatedAt: 1500, startAt: 2000)];
      expect(_resolve(_scoring(folded), corrected), isNull);
    });

    // The batch pass folds in log order; a replay appends. A contact entered
    // with a manual time before the checkpoint's last would fold out of order.
    test('a tail contact timed before the last folded one folds cold', () {
      final backdated = [...folded, _contact('c', updatedAt: 3000, startAt: 1500)];
      expect(_resolve(_scoring(folded), backdated), isNull);
    });
  });

  group('ScoringService.rescoreOperation', () {
    test('stamps each checkpoint with the digest, newest stamp and last time of the list it folded', () async {
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);
      final operation = await operations.create(stationCall: 'N0DEV');
      // Three rows: two contacts and a break marker. The marker is part of the
      // digest and the newest stamp (the timeline is folded too) but not of the
      // last contact's time.
      final first = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      await qsos.add(operation.uuid, {
        'band': 'event',
        'event': {'event': 'break'},
        'startAtMillis': 1500,
      });
      final second = await qsos.add(operation.uuid, {
        'their': {'call': 'K1ABC'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 2000,
      });

      final host = _RecordingHost({
        'core:scoreQsos': {
          'qsoScores': {
            first.uuid: {'value': 1},
            second.uuid: {'value': 1},
          },
          'daySections': const [],
          'operationSummary': const {},
          'scoresheet': const {
            'worked': {'W1AW': true},
          },
          'scoresheetDay': 0,
        },
      });
      final scored = (await operations.get(operation.uuid))!;
      await ScoringService(extensions: _LiveExtensions(host), qsos: qsos, operations: operations).rescoreOperation(scored);

      final scoring = (await operations.get(operation.uuid))!.localData['scoring'] as Map;
      final core = scoring['core'] as Map;
      final rows = await qsos.forOperation(operation.uuid);
      final newest = rows.map((q) => q.updatedAtMillis!).reduce((a, b) => a > b ? a : b);
      expect(core['checkpoint'], {
        'digest': checkpointDigestOf(rows),
        'updatedAtMillis': newest,
        'startAtMillis': 2000,
        'operationUpdatedAtMillis': scored.updatedAtMillis,
      });
      expect(core['scoresheetDay'], 0);

      // The stamp round-trips: the list as it stands is exactly what the pass
      // folded, so the live path may resume with nothing to replay.
      final resume = resolveScoringResume(
        scoring: scoring.cast<String, dynamic>(),
        operationUpdatedAtMillis: scored.updatedAtMillis,
        qsos: await qsos.forOperation(operation.uuid),
      );
      expect(resume?.tail, isEmpty);
      expect(resume?.checkpoints['core']?.day, 0);
    });
  });

  group('ExtensionService.scoreQso', () {
    final qso = {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
    };
    setUp(ErrorReportingService.resetFailureStreaks);
    tearDown(ErrorReportingService.resetFailureStreaks);

    // Without the recordSuccess on the answering path the streak never clears,
    // so a scorer that broke, recovered and broke again is reported only the
    // first time, and the second outage is invisible for the session.
    test('a scorer that recovers and breaks again is reported again', () async {
      final backend = FakeErrorReportingBackend();
      final broken = _LiveExtensions(_RecordingHost({'core:scoreQso': Exception('scorer blew up')}));
      final working = _LiveExtensions(
        _RecordingHost({
          'core:scoreQso': {'notices': [], 'alerts': []},
        }),
      );
      await withErrorHooks(() async {
        for (final service in [broken, working, broken]) {
          await service.scoreQso(operation: const {'uuid': 'op-1'}, qso: qso);
        }
      }, backend: backend);
      expect(backend.exceptions.length, 2);
    });

    test('a checkpoint reaches its scorer as resumeFrom with its day, and the tail as qsos', () async {
      final host = _RecordingHost({
        'core:scoreQso': {
          'notices': [],
          'alerts': ['duplicate'],
        },
      });
      await _LiveExtensions(host).scoreQso(
        operation: const {'uuid': 'op-1'},
        qso: qso,
        resume: (
          checkpoints: {
            'core': (sheet: const {'worked': {}}, day: 86400000),
          },
          tail: [
            const {
              'uuid': 'c',
              'their': {'call': 'W1AW'},
            },
          ],
        ),
      );
      final args = host.calls.single.args as Map;
      expect(args['resumeFrom'], const {'worked': {}});
      expect(args['resumeDay'], 86400000);
      expect(args['qsos'], [
        const {
          'uuid': 'c',
          'their': {'call': 'W1AW'},
        },
      ]);
    });

    // The harness branches on the KEY's presence: a null `resumeFrom` would
    // resume from nothing, and a tail beside no checkpoint is a fold from the
    // wrong starting point.
    test('without a checkpoint for the scorer none of the three keys is sent, tail or not', () async {
      final host = _RecordingHost({
        'core:scoreQso': {'notices': [], 'alerts': []},
      });
      await _LiveExtensions(host).scoreQso(
        operation: const {'uuid': 'op-1'},
        qso: qso,
        resume: (
          checkpoints: {'pota': (sheet: const {}, day: 0)},
          tail: [
            const {'uuid': 'c'},
          ],
        ),
      );
      final args = host.calls.single.args as Map;
      expect(args.containsKey('resumeFrom'), isFalse);
      expect(args.containsKey('resumeDay'), isFalse);
      expect(args.containsKey('qsos'), isFalse);
    });

    test('a checkpoint with no day sends no resumeDay, and an empty tail no qsos', () async {
      final host = _RecordingHost({
        'core:scoreQso': {'notices': [], 'alerts': []},
      });
      await _LiveExtensions(host).scoreQso(
        operation: const {'uuid': 'op-1'},
        qso: qso,
        resume: (
          checkpoints: {
            'core': (sheet: const {'worked': {}}, day: null),
          },
          tail: const [],
        ),
      );
      final args = host.calls.single.args as Map;
      expect(args['resumeFrom'], const {'worked': {}});
      expect(args.containsKey('resumeDay'), isFalse);
      expect(args.containsKey('qsos'), isFalse);
    });
  });
}
