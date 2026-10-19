// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CallLookupModel on its own — which call an answer is for, and what happens
// to an answer for a call the operator has moved past. The widget suite in
// logging_controls_lookup_test.dart exercises the same rules through the fields;
// these pin the model's contract where a panel would hide which side moved.

import 'dart:async';

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
  String exchange = '';
  bool withLookup = true;

  /// Holds the online pass until completed, for a test that needs the lookup
  /// still in flight while the score lands.
  Completer<void>? onlineGate;

  /// How long the scorer takes to answer — it reads the whole log.
  Duration scoreLatency = Duration.zero;

  Map<String, dynamic> Function(Map<String, dynamic> qso) verdict = (qso) => {
    'alerts': ['dupe'],
    'notices': ['newBand'],
  };
  final operation = const Operation(uuid: 'op', data: {'refs': []});

  /// Offline fetches only — every lookup is two passes, and the online one
  /// is what the tests move the operator past.
  int get offlineFetches => lookups.where((l) => l.contains('offline')).length;

  late final model = CallLookupModel(
    config: () => (
      lookup: withLookup
          ? (call, {required qso, required operation, required online, recentContext = false}) async {
              lookups.add('$call ${online ? 'online' : 'offline'} recent=$recentContext');
              // The online pass takes a beat, as a network does — so a test can
              // move the operator past the call while it is in flight.
              if (online) await (onlineGate?.future ?? Future<void>.delayed(const Duration(milliseconds: 1)));
              return answer(call, online);
            }
          : null,
      workedBefore: (call, {excludingQsoUuid}) async {
        workedBeforeAsked.add('$call excluding=$excludingQsoUuid');
        return [1, 2, 3];
      },
      scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
        final exchange = qso['their']['exchange'] as String?;
        scores.add('${qso['their']['call']}${exchange == null ? '' : ' $exchange'} excluding=$excludeUuid');
        final answer = verdict(qso);
        if (scoreLatency > Duration.zero) await Future<void>.delayed(scoreLatency);
        return answer;
      },
      editingQso: editingQso,
      operation: operation,
    ),
    activeCall: () => call,
    isCallInfoActive: () => call.length >= 3,
    qsoData: (call) => {
      'their': {'call': call, if (exchange.isNotEmpty) 'exchange': exchange},
    },
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
    h.answer = (call, online) => online
        ? null
        : {
            'guess': {'name': 'Offline'},
          };
    h.call = 'W1AW';
    h.model.scheduleLookup();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1));
    expect(h.model.resultFor('W1AW')!['guess']['name'], 'Offline');
    expect(h.resolved, ['W1AW offline']);
    h.model.dispose();
  });

  testWidgets('a call looked up this session comes back from the cache at once, and a reset forgets it', (tester) async {
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
    h.editingQso = const Qso(
      uuid: 'q1',
      operationUuid: 'op',
      data: {
        'their': {'call': 'W1AW'},
      },
    );
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

  group('when the scored pills show', () {
    // The partial calls on the way to the one being typed each get scored, and
    // painting each verdict at every pause is the flashing this holds back.
    testWidgets('a typed call shows nothing until it has stood for 600ms', (tester) async {
      final h = _Harness();
      h.call = 'KB2S';
      h.model.callTyped();
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.scores, ['KB2S excluding=null'], reason: 'scored meanwhile, so the pills are ready when it settles');
      expect(h.model.currentAlertKeys, isEmpty, reason: 'KB2S is only on its way to a call');
      h.call = 'KB2SK';
      h.model.callTyped();
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 599));
      expect(h.model.currentAlertKeys, isEmpty, reason: 'the clock restarts with each keystroke');
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.model.currentAlertKeys, ['dupe']);
      expect(h.model.currentNoticeKeys, ['newBand']);
      h.model.dispose();
    });

    // In a list or a stack the cursor moves between calls already entered;
    // holding each one as the cursor lands on it blanks its pills for nothing.
    testWidgets('a call that does not settle shows its pills as soon as they are scored', (tester) async {
      final h = _Harness();
      h.call = 'KB2SK';
      h.model.callTyped();
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.model.currentAlertKeys, isEmpty);
      h.call = 'W1AW';
      h.model.callTyped(settles: false);
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.model.currentAlertKeys, ['dupe']);
      h.model.dispose();
    });

    // The count shares the pill row: released before the scored pills, it
    // flashes for each partial call and the row reflows when they join it.
    testWidgets('the worked-before count settles with the scored pills', (tester) async {
      final h = _Harness();
      h.call = 'W1AW';
      h.model.callTyped();
      h.model.scheduleLookup();
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.workedBeforeAsked, ['W1AW excluding=null'], reason: 'fetched meanwhile, so it is ready when the call settles');
      expect(h.model.workedBefore, isNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.model.workedBefore, [1, 2, 3]);
      await tester.pump(const Duration(milliseconds: 300));
      h.model.dispose();
    });

    // A US station's state usually arrives with the lookup, and a party scorer
    // reads a missing state as a missing exchange. Released when the lookup
    // lands, the complaint shows on the verdict scored without the state, and
    // the rescore withdraws it a moment later.
    testWidgets('an exchange complaint waits for the verdict on what the lookup brought', (tester) async {
      var stateKnown = false;
      final h = _Harness()
        ..onlineGate = Completer<void>()
        ..verdict = (qso) => {
          'alerts': ['dupe', if (!stateKnown) 'missingExchange'],
        };
      h.call = 'W1AW';
      h.model.callTyped();
      h.model.scheduleLookup();
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 600));
      expect(h.model.currentAlertKeys, ['dupe'], reason: 'a dupe is worth showing early; the complaint waits');
      stateKnown = true;
      h.onlineGate!.complete();
      await tester.pump();
      expect(h.model.currentAlertKeys, ['dupe'], reason: 'the verdict held was scored before the state arrived');
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.model.currentAlertKeys, ['dupe']);
      h.model.dispose();
    });

    testWidgets('a complaint the lookup leaves standing shows once its rescore lands', (tester) async {
      final h = _Harness()
        ..onlineGate = Completer<void>()
        ..verdict = (qso) => {
          'alerts': ['missingExchange'],
        };
      h.call = 'W1AW';
      h.model.callTyped();
      h.model.scheduleLookup();
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 600));
      h.onlineGate!.complete();
      await tester.pump();
      expect(h.model.currentAlertKeys, isEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.model.currentAlertKeys, ['missingExchange']);
      h.model.dispose();
    });

    testWidgets('a lookup that never finishes holds a complaint back for 2s at most', (tester) async {
      final h = _Harness()
        ..onlineGate = Completer<void>()
        ..verdict = (qso) => {
          'alerts': ['invalidExchange'],
        };
      h.call = 'W1AW';
      h.model.callTyped();
      h.model.scheduleLookup();
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 1999));
      expect(h.model.currentAlertKeys, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.model.currentAlertKeys, ['invalidExchange'], reason: 'the operator is about to log it: say so');
      h.model.dispose();
    });

    testWidgets('typing in the exchange re-scores, and holds a complaint until 500ms after the last keystroke', (tester) async {
      final h = _Harness()
        ..withLookup = false
        ..verdict = (qso) => switch (qso['their']['exchange']) {
          'LEW' => {
            'notices': ['newMult'],
          },
          _ => {
            'alerts': ['missingExchange'],
          },
        };
      h.call = 'KB2SKF';
      h.model.callTyped();
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 600));
      expect(h.model.currentAlertKeys, ['missingExchange']);

      h.exchange = 'LE';
      h.model.exchangeEdited();
      expect(h.model.currentAlertKeys, isEmpty, reason: 'the operator is answering it right now');
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.scores.last, 'KB2SKF LE excluding=null', reason: 'the exchange is part of what is scored');
      expect(h.model.currentAlertKeys, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.model.currentAlertKeys, ['missingExchange'], reason: 'they stopped typing on something that does not count');

      h.exchange = 'LEW';
      h.model.exchangeEdited();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.scores.last, 'KB2SKF LEW excluding=null');
      expect(h.model.currentNoticeKeys, ['newMult'], reason: 'news needs no waiting');
      expect(h.model.currentAlertKeys, isEmpty, reason: 'and a key the verdict dropped goes at once');
      await tester.pump(const Duration(milliseconds: 200));
      h.model.dispose();
    });

    // The typing pause can end before the verdict on the edit lands; released
    // on the pause alone, the complaint about the exchange as it was before
    // the edit shows again.
    testWidgets('a slow scorer holds the complaint until the verdict on the edit lands', (tester) async {
      final h = _Harness()
        ..withLookup = false
        ..scoreLatency = const Duration(milliseconds: 400)
        ..verdict = (qso) => switch (qso['their']['exchange']) {
          'LEW' => {
            'notices': ['newMult'],
          },
          _ => {
            'alerts': ['missingExchange'],
          },
        };
      h.call = 'KB2SKF';
      h.model.callTyped();
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(h.model.currentAlertKeys, ['missingExchange']);

      h.exchange = 'LEW';
      h.model.exchangeEdited();
      await tester.pump(const Duration(milliseconds: 500));
      expect(h.model.currentAlertKeys, isEmpty, reason: 'the verdict held is about the exchange before the edit');
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.model.currentNoticeKeys, ['newMult']);
      expect(h.model.currentAlertKeys, isEmpty);
      h.model.dispose();
    });

    // The controls refresh that carries a suggestion lands after the lookup,
    // so the lookup's own rescore may have read the field empty.
    testWidgets('a lookup prefill re-scores, and holds a complaint until that verdict lands', (tester) async {
      final h = _Harness()
        ..withLookup = false
        ..verdict = (qso) => switch (qso['their']['exchange']) {
          'LEW' => {
            'notices': ['newMult'],
          },
          _ => {
            'alerts': ['missingExchange'],
          },
        };
      h.call = 'KB2SKF';
      h.model.callTyped();
      h.model.scheduleScore();
      await tester.pump(const Duration(milliseconds: 600));
      expect(h.model.currentAlertKeys, ['missingExchange']);

      h.exchange = 'LEW';
      h.model.exchangePrefilled();
      expect(h.model.currentAlertKeys, isEmpty, reason: 'the verdict held predates the value now in the field');
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.scores.last, 'KB2SKF LEW excluding=null');
      expect(h.model.currentNoticeKeys, ['newMult']);
      h.model.dispose();
    });
  });
}
