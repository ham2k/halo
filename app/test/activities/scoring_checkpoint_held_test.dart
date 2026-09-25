// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The checkpoint's name on the wire. A live call carries the whole scoresheet
// across the bridge until the runtime has said it holds that checkpoint; from
// then on the name stands for it — and the one way that can go wrong (a
// runtime that no longer holds what it said it did) is answered with the
// sheet, once, never with a cold fold the operator would pay per keystroke.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/extensions/extension_scoring.dart';
import 'package:ham2k_logger/services/scoring_service.dart';

import '../support/halo_test_support.dart';

const _operation = {'uuid': 'op-1', 'stationCall': 'KI2D'};
const _qso = {
  'their': {'call': 'W1AW'},
  'band': '20m',
  'mode': 'SSB',
};
const _sheet = {'workedByCall': <String, dynamic>{}};
const _resume = (checkpoints: {'core': (sheet: _sheet, day: 86400000, key: 'k1')}, tail: <Map<String, dynamic>>[]);

/// A runtime whose `core` scorer answers every call and, when [holds], says
/// it holds the checkpoint it was named. [calls] keeps every request as sent.
FakeExtensionHost _runtime(List<Map<String, dynamic>> calls, {bool holds = true, bool Function(Map<String, dynamic> args)? missing}) {
  Object? answer(Object? args) {
    final request = (args as Map).cast<String, dynamic>();
    if (missing?.call(request) ?? false) throw ExtensionHostException('$kResumeMissing: ${request['resumeKey']}');
    calls.add(request);
    return {
      'notices': const <String>[],
      'alerts': const <String>['duplicate'],
      if (holds && request['resumeKey'] != null) 'checkpointHeld': true,
    };
  }

  return FakeExtensionHost({
    'scoring:*:scope': [
      {'key': 'core', 'ok': true, 'value': 'always'},
    ],
    'scoring:core:scoreQso': answer,
    'scoring:core:scoreCandidates': (Object? args) {
      final request = (args as Map).cast<String, dynamic>();
      if (missing?.call(request) ?? false) throw ExtensionHostException('$kResumeMissing: ${request['resumeKey']}');
      calls.add(request);
      return {
        for (final candidate in (request['candidates'] as List).cast<Map>())
          candidate['key'] as String: {
            'notices': const <String>[],
            'alerts': const <String>['duplicate'],
          },
        if (holds && request['resumeKey'] != null) kCheckpointHeldKey: true,
      };
    },
    'scoring:core:scoreQsos': (Object? args) {
      final request = (args as Map).cast<String, dynamic>();
      calls.add(request);
      return {
        'qsoScores': const <String, dynamic>{},
        'daySections': const <dynamic>[],
        'operationSummary': const <String, dynamic>{},
        'scoresheet': _sheet,
        'scoresheetDay': 0,
        if (holds && request['checkpointKey'] != null) 'checkpointHeld': true,
      };
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the sheet crosses the bridge until the runtime says it holds the checkpoint, then only its name', () async {
    final calls = <Map<String, dynamic>>[];
    final extensions = ExtensionServiceWithFakeHost(_runtime(calls));

    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);
    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);

    expect(calls, hasLength(2));
    expect(calls[0]['resumeKey'], 'k1');
    expect(calls[0]['resumeFrom'], _sheet, reason: 'the first call carries the sheet');
    expect(calls[1]['resumeKey'], 'k1');
    expect(calls[1].containsKey('resumeFrom'), isFalse, reason: 'the runtime said it holds k1');
    expect(calls[1].containsKey('resumeDay'), isFalse);
  });

  test('a runtime that never says it holds the checkpoint keeps receiving the sheet', () async {
    // A scorer built on an SDK without the cache: naming a checkpoint to it
    // would make it fold cold on every keystroke.
    final calls = <Map<String, dynamic>>[];
    final extensions = ExtensionServiceWithFakeHost(_runtime(calls, holds: false));

    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);
    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);

    expect(calls.map((c) => c.containsKey('resumeFrom')), [true, true]);
  });

  test('a batch pass names the checkpoint it produces, and a live call can then name it', () async {
    final calls = <Map<String, dynamic>>[];
    final extensions = ExtensionServiceWithFakeHost(_runtime(calls));
    final key = checkpointKeyOf(const {'digest': 7, 'updatedAtMillis': 100, 'startAtMillis': 50});

    await extensions.scoreQsos(scorerKey: 'core', args: {'operation': _operation, 'qsos': const [], 'checkpointKey': key});
    await extensions.scoreQso(operation: _operation, qso: _qso, resume: (checkpoints: {'core': (sheet: _sheet, day: 0, key: key)}, tail: const []));

    expect(calls[0]['checkpointKey'], key);
    expect(calls[1]['resumeKey'], key);
    expect(calls[1].containsKey('resumeFrom'), isFalse, reason: 'the pass that produced it said it was held');
  });

  test('a checkpoint the runtime no longer holds is sent once more, with the sheet', () async {
    final calls = <Map<String, dynamic>>[];
    var lost = false;
    final extensions = ExtensionServiceWithFakeHost(_runtime(calls, missing: (args) => lost && !args.containsKey('resumeFrom')));

    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);
    lost = true;
    final result = await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);

    expect(result?['alerts'], ['duplicate'], reason: 'answered, not reported as a scorer failure');
    expect(ErrorReportingService.failureStreak('scoring:core:scoreQso'), 0, reason: 'a refusal the host answers is not a failure of the scorer');
    expect(calls, hasLength(2), reason: 'the refused request never reached the scorer; the resend did');
    expect(calls[1]['resumeFrom'], _sheet);
    // Held again after the resend, so the next call names it.
    lost = false;
    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);
    expect(calls[2].containsKey('resumeFrom'), isFalse);
  });

  test('a spots pass names the checkpoint too, and its answer keeps the hold', () async {
    // Its answer has no field for the flag — the entries are the caller's
    // candidate keys — so the hold rides under a reserved one, and a board
    // that had to resend its sheet is not made to resend it on every pass.
    final calls = <Map<String, dynamic>>[];
    var lost = false;
    final extensions = ExtensionServiceWithFakeHost(_runtime(calls, missing: (args) => lost && !args.containsKey('resumeFrom')));
    Future<Map<String, Map<String, List<String>>>?> board() =>
        extensions.scoreCandidates(operation: _operation, operationUuid: 'op-1', candidates: {'a': _qso}, resume: _resume);

    await board();
    final first = await board();
    expect(first?['a']?['alerts'], ['duplicate']);
    expect(first?.containsKey(kCheckpointHeldKey), isFalse, reason: 'the reserved entry never reaches the panel');
    expect(calls[1].containsKey('resumeFrom'), isFalse, reason: 'held after the first pass');

    lost = true;
    await board();
    expect(calls[2]['resumeFrom'], _sheet, reason: 'resent once');
    lost = false;
    await board();
    expect(calls[3].containsKey('resumeFrom'), isFalse, reason: 'the resend re-established the hold');
  });

  test('a caller naming the checkpoint before last is sent with its sheet, not refused', () async {
    // The runtime holds one checkpoint per operation. A panel that has not
    // yet seen the new one names the old; the host knows the slot moved and
    // sends the sheet outright, sparing the refusal and the resend.
    final calls = <Map<String, dynamic>>[];
    final extensions = ExtensionServiceWithFakeHost(_runtime(calls));
    final newer = (checkpoints: {'core': (sheet: _sheet, day: 86400000, key: 'k2')}, tail: <Map<String, dynamic>>[]);

    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);
    await extensions.scoreQso(operation: _operation, qso: _qso, resume: newer);
    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);

    expect(calls[1]['resumeFrom'], _sheet, reason: 'k2 is new to the runtime');
    expect(calls[2]['resumeFrom'], _sheet, reason: 'k1 is no longer what the runtime holds');
    expect(calls, hasLength(3), reason: 'no refusal, no resend');
  });

  test('a new runtime holds nothing the old one said it did', () async {
    final calls = <Map<String, dynamic>>[];
    final extensions = ExtensionServiceWithFakeHost(_runtime(calls));

    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);
    extensions.runtimeGeneration.value++;
    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);

    expect(calls[1]['resumeFrom'], _sheet, reason: 'the checkpoint is sent again to the new runtime');
  });

  test('what one operation holds says nothing about another', () async {
    final calls = <Map<String, dynamic>>[];
    final extensions = ExtensionServiceWithFakeHost(_runtime(calls));

    await extensions.scoreQso(operation: _operation, qso: _qso, resume: _resume);
    await extensions.scoreQso(operation: const {'uuid': 'op-2', 'stationCall': 'KI2D'}, qso: _qso, resume: _resume);

    expect(calls[1]['resumeFrom'], _sheet);
  });
}
