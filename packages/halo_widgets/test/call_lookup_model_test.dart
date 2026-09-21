// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CallLookupModel on its own — which call an answer is for, and what happens
// to an answer for a call the operator has moved past. The widget suite in
// logging_controls_lookup_test.dart exercises the same rules through the fields;
// these pin the model's contract where a panel would hide which side moved.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/src/logging_controls_lookup.dart';

class _Harness {
  String call = '';
  Qso? editingQso;
  final lookups = <String>[];
  final scores = <String>[];
  final resolved = <String>[];
  final workedBeforeAsked = <String>[];
  int cleared = 0;
  Map<String, dynamic>? Function(String call, bool online) answer = (call, online) => {
        'guess': {'name': online ? 'Online $call' : 'Offline $call'},
      };
  int notifications = 0;
  final operation = const Operation(uuid: 'op', data: {'refs': []});

  /// Offline fetches only — every lookup is two passes, and the online one
  /// is what the tests move the operator past.
  int get offlineFetches => lookups.where((l) => l.contains('offline')).length;

  late final model = CallLookupModel(
    config: () => (
      lookup: (call, {required qso, required operation, required online, recentContext = false}) async {
        lookups.add('$call ${online ? 'online' : 'offline'} recent=$recentContext');
        // The online pass takes a beat, as a network does — so a test can
        // move the operator past the call while it is in flight.
        if (online) await Future<void>.delayed(const Duration(milliseconds: 1));
        return answer(call, online);
      },
      workedBefore: (call, {excludingQsoUuid}) async {
        workedBeforeAsked.add('$call excluding=$excludingQsoUuid');
        return [1, 2, 3];
      },
      scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
        scores.add('${qso['their']['call']} excluding=$excludeUuid');
        return {'alerts': ['dupe'], 'notices': ['newBand']};
      },
      editingQso: editingQso,
      operation: operation,
    ),
    activeCall: () => call,
    isCallInfoActive: () => call.length >= 3,
    qsoData: (call) => {'their': {'call': call}},
    segmented: () => SegmentedOperation.from(operation: operation.data, qsos: const []),
    onResolved: (call, result, phase) => resolved.add('$call ${phase.name}'),
    onCleared: () => cleared++,
  )..addListener(() => notifications++);
}

void main() {
  testWidgets('a lookup runs offline then online, and each pass re-scores and reaches the panel', (tester) async {
    final h = _Harness();
    h.call = 'W1AW';
    h.model.scheduleLookup();
    expect(h.lookups, isEmpty, reason: 'debounced: a keystroke is not a lookup');
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.lookups.first, 'W1AW offline recent=true');
    expect(h.model.lookupFor, 'W1AW');
    expect(h.model.resultFor('W1AW')!['guess']['name'], 'Offline W1AW', reason: 'the online pass is still in flight');
    expect(h.resolved, ['W1AW offline']);
    await tester.pump(const Duration(milliseconds: 1));
    expect(h.lookups.last, 'W1AW online recent=true');
    expect(h.model.resultFor('W1AW')!['guess']['name'], 'Online W1AW');
    expect(h.resolved, ['W1AW offline', 'W1AW online']);
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.model.scoreIsCurrent, isTrue);
    expect(h.model.currentAlertKeys, ['dupe']);
    expect(h.model.currentNoticeKeys, ['newBand']);
    expect(h.workedBeforeAsked, ['W1AW excluding=null']);
    expect(h.model.workedBefore, [1, 2, 3]);
    h.model.dispose();
  });

  testWidgets('an answer for a call the operator has moved past is dropped', (tester) async {
    final h = _Harness();
    h.call = 'W1AW';
    h.model.scheduleLookup();
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.model.lookupFor, 'W1AW');
    // The online pass is in flight; the operator keeps typing.
    h.call = 'W1AWX';
    await tester.pump(const Duration(milliseconds: 1));
    expect(h.model.resultFor('W1AW')!['guess']['name'], 'Offline W1AW', reason: 'the online answer was for another call');
    expect(h.resolved, ['W1AW offline'], reason: 'nothing reaches the panel for a stale call');
    h.model.dispose();
  });

  testWidgets('a failed online pass keeps the offline preview', (tester) async {
    final h = _Harness();
    h.answer = (call, online) => online ? null : {'guess': {'name': 'Offline'}};
    h.call = 'W1AW';
    h.model.scheduleLookup();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1));
    expect(h.model.resultFor('W1AW')!['guess']['name'], 'Offline');
    expect(h.resolved, ['W1AW offline']);
    h.model.dispose();
  });

  testWidgets('a call looked up this session comes back from the cache at once, and a reset forgets it',
      (tester) async {
    final h = _Harness();
    h.call = 'W1AW';
    h.model.scheduleLookup();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1));
    h.call = 'W1';
    h.model.scheduleLookup();
    expect(h.model.lookupFor, isNull, reason: 'not a callsign: the shown result goes');
    expect(h.cleared, greaterThan(0), reason: 'and the panel is told, before the repaint');
    h.call = 'W1AW';
    h.model.scheduleLookup();
    expect(h.model.lookupFor, 'W1AW', reason: 'served from the cache, before any debounce');
    expect(h.resolved.last, 'W1AW cached');
    expect(h.offlineFetches, 1, reason: 'no refetch');

    h.model.reset();
    expect(h.model.lookupFor, isNull);
    expect(h.model.workedBefore, isNull);
    h.model.scheduleLookup();
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.offlineFetches, 2, reason: 'after a reset the same call is fetched again');
    await tester.pump(const Duration(milliseconds: 1));
    h.model.dispose();
  });

  testWidgets('the worked-before answer is keyed on the call and the QSO left out of it', (tester) async {
    final h = _Harness();
    h.call = 'W1AW';
    h.model.refreshWorkedBefore();
    h.model.refreshWorkedBefore();
    await tester.pump();
    expect(h.workedBeforeAsked, ['W1AW excluding=null'], reason: 'the same key is never asked twice');
    expect(h.model.workedBefore, [1, 2, 3]);
    h.editingQso = const Qso(uuid: 'q1', operationUuid: 'op', data: {'their': {'call': 'W1AW'}});
    expect(h.model.workedBefore, isNull, reason: 'opening this call\'s own QSO changes what the count must exclude');
    h.model.refreshWorkedBefore();
    await tester.pump();
    expect(h.workedBeforeAsked.last, 'W1AW excluding=q1');
    h.model.dispose();
  });

  testWidgets('scoring is gated on a plausible callsign, and clears the notices below it', (tester) async {
    final h = _Harness();
    h.call = 'W1AW';
    h.model.scheduleScore();
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.model.currentAlertKeys, ['dupe']);
    h.call = 'NOTE HI';
    h.model.scheduleScore();
    expect(h.model.scoreIsCurrent, isFalse);
    expect(h.model.currentAlertKeys, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.scores, ['W1AW excluding=null'], reason: 'junk input never reaches the hook');
    h.model.dispose();
  });

  testWidgets('a re-lookup for changed refs forgets the cached answer and asks again', (tester) async {
    final h = _Harness();
    h.call = 'W1AW';
    h.model.scheduleLookup();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1));
    h.model.relookupForRefsChanged();
    expect(h.model.lookupFor, isNull);
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.offlineFetches, 2);
    await tester.pump(const Duration(milliseconds: 1));
    h.model.dispose();
  });
}
